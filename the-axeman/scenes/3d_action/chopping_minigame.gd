
extends Node3D
## FILE: res://scenes/3d_action/chopping_minigame.gd
## ATTACHES TO: the root Node3D of res://scenes/3d_action/chopping_minigame.tscn
## (the live M4 mini-game, instanced under main's 3D_World_Root) AND of
## res://scenes/3d_action/chopping_minigame_harness.tscn (the standalone F6
## feel-test harness, which instances chopping_minigame.tscn inside its own
## viewport). Both need the child nodes CameraPivot/Camera3D, Fallers, and Floor.
##
## This is the shipping M4 chopping mini-game (renamed 2026-07-22 from slice_poc.gd
## once the POC was feel-approved and folded in — no reason left to carry the POC
## name on the live script). When a log is fully chopped and its firewood settles,
## each finished piece is deposited into InventoryManager as the log species'
## yield item (A7 resource_gathered — see res://data/species_table.tres and
## _begin_stacking).
##
## Amendment-6 SLICING PROOF-OF-CONCEPT, re-architected (2026-07-19) to match the
## reference firewood chopper's FEEL, not just its fall rules. The reference is
## an ANIMATION-DRIVEN game: only firewood thrown to the pile uses physics; every
## piece that stays on the block, and every nearby piece a strike jostles, is
## moved by a scripted pop/tilt animator (see piece_animator.gd). The earlier POC
## made everything a RigidBody, which is why it felt floaty and needed a pile of
## physics band-aids (mass-by-volume, damp tuning, a slide-off assist). Those are
## gone now — stays are script-animated.
##
## The chop loop, lifted from the reference:
##   1. Click a piece on the block. If it's too thin along the current cut axis,
##      the camera snaps 90 deg to the perpendicular (long) axis instead of cutting
##      — forcing firewood-sized chunks rather than shaving off slivers.
##   2. The camera-mounted axe plays its overhead swing. The wood splits ON THE
##      ANIMATION'S OWN CONTACT KEY (see axe_viewmodel.gd), so the break lands on
##      the frame the blade bites however the swing is re-timed in the editor.
##   3. On the split: camera shake + hit-pause fire via EventBus.action_hit_
##      registered (GameFeel owns both). Each half is judged independently:
##        * volume <= min_vol OR aspect > aspect_limit -> FIREWOOD (physics, thrown
##          toward the pile) ;  otherwise -> STAYS on the block (script-animated).
##   4. Every on-block piece pops away from the cut in a radial shockwave with
##      distance falloff + staggered delay; a hull-separation solver keeps them
##      from overlapping and inside the stump footprint.
##   5. A fresh log drops in when everything is chopped (R also forces a fresh log).
##
## Camera orbits in fixed 30-deg steps (A/D or arrows).
##
## EVERY tuning value below is a PLACEHOLDER carried over from the reference
## (converted from its internal inches via ld=0.0254 m/in). Directive 4: authored
## as @export, never a hardcoded final — tune live with Sam in F6.

const _PieceAnimator := preload("res://scenes/3d_action/piece_animator.gd")
const _WoodPile := preload("res://scenes/3d_action/wood_pile.gd")
const _ManualLogOutcome := preload("res://data/manual_log_outcome.gd")
const _GRAIN_CUE_CONFIG := preload("res://data/grain_cue.tres")

## Local instrumentation seams. They do not cross the 2D/3D EventBus boundary:
## the pacing probe observes this scene directly while a measured play session
## is running, and shipping systems do not depend on either signal.
signal strike_resolved(did_split: bool)
signal log_completed(species_id: StringName, piece_count: int)
## M7C instrumentation: a named proc completed. Presentation is the local
## ProcBurst spawned at the actual result; this signal never grows a second
## banner/announcement path.
signal bonus_proc_announced(proc_id: StringName, cuts: int)
## Receipt for one manual completed-log XP transaction. This is local
## instrumentation/presentation data; GameState remains the only XP writer.
signal manual_xp_awarded(base_xp: int, bonus_xp: int, proc_id: StringName)
## Receipt for one permanent gold grain mark being cut. Local instrumentation
## only, same shape as manual_xp_awarded — GameState.add_xp is still the only
## write, this just lets presentation/tests observe the transaction happened.
signal grain_read_awarded(bonus_xp: int)

# --- log species ---------------------------------------------------------
## THE SPECIES TABLE LIVES IN DATA NOW: res://data/species_table.tres, schema in
## res://data/species_def.gd, read through SpeciesTable's static helpers.
##
## Until 2026-08-02 this was a `_LOG_SPECIES` const right here — three rows of
## dictionary literal. It moved the day Sam named all 25 woods of the finished
## game, for two reasons a three-row const never had to answer:
##   - twenty-five rows of literal do not belong in a gameplay script; and
##   - the YARD HUD has to list species to let the player choose one, and it is
##     2D-side (A9) — it must never import this file to find out what wood is.
##
## Nothing about how a species is USED changed. A row is still picked first and a
## SHAPE second, so a wood with six authored meshes never turns up more often
## than a wood with one; `yield_item` is still what a finished piece deposits;
## `inside_tex`/`inside_normal`/`inside_tint` still describe the cut face, which
## is generated here at runtime and is not the FBX's business.
##
## WHICH wood turns up is no longer random. The player chooses it in the yard and
## GameState owns that choice — see _pick_species_index().

# --- infrastructure (unchanged geometry/material setup) -------------------
@export var log_height := 0.42            # finished height of a log standing on the block (m)
@export var stump_scale := 0.376         # scales chopping_stump_a so its top sits at the log rest height (~0.5m)
@export var camera_step_deg := 30.0
@export var orbit_time := 0.25
@export_group("XP orbs")
## OFF in tests that count frames rather than watch them; on everywhere else.
@export var orbs_enabled := true
## Orbs = sqrt(xp) * density, clamped. PLACEHOLDERS per Directive 3 — the shape
## matters more than the numbers: a log worth 8 and one worth 56,000 must both
## read as "a handful", so the count grows sub-linearly and is capped.
@export var orb_density := 2.2
@export var orb_count_min := 5
@export var orb_count_max := 16
## Tiny ON PURPOSE: the burst is ONE event ("all the collecting happens at once"),
## and this exists only so the orbs do not leave on a single identical frame.
@export var orb_stagger := 0.012     # seconds between orbs leaving the block
## Age at which the whole handful lifts off the ground for the player, shared by
## every orb in the burst — the beat they spend lying in the dirt. PLACEHOLDER.
@export var orb_collect_at := 0.85
@export var orb_scatter_radius := 0.32   # smallest ring the burst lands in; widened to clear the stump
## A gold grain cut pays much bigger than a routine log, and its orb burst has to
## visibly outsize the routine ceiling above or the payout doesn't read as a lot
## of XP. Same curve (sqrt(xp) * orb_density), just a raised, separate clamp.
@export var grain_orb_count_min := 14
@export var grain_orb_count_max := 28
@export_group("")

@export var debug_forced_species := -1   # -1 = whatever the player picked; >=0 forces a species_table.tres LADDER INDEX (headless tests + shots)
@export var debug_forced_mesh := -1      # -1 = random shape within the species; >=0 forces one (tests + species_shot)

# --- fall classification (the reference rule) -----------------------------
@export_group("Classification")
@export var min_piece_size := 0.06       # sliver guard: min thickness of a cut-off piece (m)
@export var min_vol := 0.018             # volume floor (m^3): below this a piece is firewood
@export var aspect_limit := 3.0          # above this max/min extent ratio a piece is firewood
@export var width_depth_ratio := 0.35     # a cut piece's width (along the cut) is kept >= this * its depth, so chunks stay square instead of flat slabs (0 = off, click-exact cuts)

# --- chop feel (the animation-driven core; reference values) --------------
@export_group("Chop feel")
## Seconds between the click and the wood coming apart WHEN THERE IS NO AXE
## VIEWMODEL in the scene. With one — which is every shipping path since
## 2026-08-02 — the animation's own contact key decides that moment instead, so
## this is only what a stripped-down test harness falls back to.
@export var anticipation_sec := 0.1
@export var jostle_radius := 0.381       # ref 15in: falloff radius for the shockwave that jostles nearby pieces
@export var half_push := 0.0254          # ref 1in: how far the two fresh halves pop apart from the cut
@export var jostle_push := 0.0127        # ref Zu=0.5in: max outward nudge on a nearby piece (x falloff)
@export var pop_height := 0.0508         # ref 2in: how high a jostled piece hops
@export var delay_ref_dist := 0.6096     # ref 24in: distance that maps to a full `stagger_ms` of delay (ripple)
@export var stagger_ms := 150.0          # ref: max stagger so the shockwave ripples outward, not all at once
@export var sep_gap := 0.0127            # ref Qu=0.5in: gap the separation solver keeps between piece hulls
@export_range(0.0, 1.5) var clamp_radius_frac := 1.0  # pieces are kept within this fraction of the stump radius
@export var fresh_yaw_deg := 2.0         # ref: small random yaw (+/-) on a freshly split half
@export var min_cut_width := 0.127       # only reorient to a long axis while it's at least this thick (m); below this the piece is small enough to just cut
@export var cross_axis_turn_deg := 90.0  # cut axis too short -> snap camera this far to the perpendicular (long) axis so cuts make firewood chunks
@export var long_axis_bias := 1.15       # snap to the perpendicular axis when it is more than this * the axis you'd cut (hysteresis; 1.0 = always cut the strictly longer axis)
@export var drop_height := 0.25          # compact spawn-in: visible drop without a high floating beat

# --- cut face (roughen the split so it's cloven wood, not a laser cut) -----
@export_group("Cut face")
@export var cut_jag_amount := 0.01       # how far cut-face verts wobble along the cut normal (m); 0 = perfectly clean cut
@export var cut_jag_freq := 12.0         # spatial frequency of the jaggedness (higher = finer/rougher grain)

# --- firewood physics (the ONLY physics pieces) ---------------------------
@export_group("Firewood physics")
@export var wood_density := 700.0        # mass = density * AABB volume (floored)
@export var min_mass := 0.2              # mass floor so slivers aren't flung by heavier pieces
@export var piece_linear_damp := 0.35
@export var piece_angular_damp := 1.2
@export var firewood_out := 1.6          # outward (from cut) launch speed (m/s)
@export var firewood_up := 1.2           # upward launch speed (m/s)
@export var firewood_toward_cam := 1.0   # bias toward the viewer so the pile forms in front (m/s)
@export var firewood_tumble := 3.0       # random spin (rad/s)
@export var max_firewood := 40           # hard cap; oldest freed first
@export var firewood_settle_speed := 0.05 # firewood counts as "settled" below this speed (m/s)
@export var firewood_settle_timeout := 1.5  # force-stack after this long even if still drifting (s)

# --- pile (fully-chopped firewood is gathered into an arc pile; reference QC) --
@export_group("Pile")
@export var pile_radius := 1.524         # ref 60in: arc radius the pile sits on
@export var pile_arc_span_deg := 230.0
@export var pile_start_angle_deg := 320.0
@export var pile_slot_spacing := 0.127   # ref XC = 5in
@export var pile_tier_depth := 0.4572    # ref 18in: outward step per tier
@export var pile_max_height := 0.4572    # ref 18in
@export var pile_ground_y := 0.0         # world y the pile rests on (our floor top = 0)
@export var pile_jitter := 0.0254        # ref 1in: random slide along the arc
@export var pile_apex_extra := 0.3048    # ref 12in: arc height of a flung piece
@export var pile_fly_ms := 500.0         # travel takes this * 1.6
@export var pile_stagger_ms := 300.0     # cascade spread across the batch
## Creative Director call, 2026-08-01: the pile builds to 50 pieces and is then
## HAULED AWAY — the whole load flies off screen and the yard starts a fresh
## stack. It doubles as A12's ceiling on how many pile meshes exist at once.
## The export remains as a TEST SEAM (the acceptance suite fills a three-piece
## load), but production inherits the one capacity owned with the pile state.
@export var max_pile_pieces := GameState.YARD_PILE_CAPACITY
@export var haul_distance := 9.0         # how far a hauled piece flies before it is dropped (m)
@export var haul_rise := 2.2             # how high it arcs on the way out (m)
@export var haul_ms := 700.0             # travel time per piece
@export var haul_stagger_ms := 600.0     # spread across the load, so it leaves as a wave

## The yard buys every piece the moment it lands on the pile (Creative Director
## call, 2026-08-01 — "as soon as the pieces enter the pile, they should be
## converted to their cash value"). OFF for the M4 suite, which tests the chopping
## game's yield contract — that a finished piece deposits stock — and would
## otherwise be watching the economy sell that stock out from under it.
@export var auto_sell := true

# --- axe ------------------------------------------------------------------
## THE AXE IS A CAMERA VIEWMODEL AND ITS MOTION LIVES IN AN ANIMATION, not here
## (2026-08-02, Creative Director call: *"the animation feels clunky and I want a
## little more create control over it. It should look as if the axe is being
## over-head swung from where the camera."*). The rig is authored in
## chopping_minigame.tscn under CameraPivot/Camera3D — see axe_viewmodel.gd for
## the node tree — and the swing is res://data/axe_swing_lib.tres, editable in the
## animation editor. The old code-built world-space `AxeRig` is deleted.
##
## Nothing about the swing's shape or timing is exported here on purpose: two
## owners for one motion is how the game ended up splitting logs while the axe was
## still in the air (`swing_time` was 1.0 s in the scene, `anticipation_sec` 0.1 s).
@export_group("Axe")
## Belt-and-braces only: the strike is resolved by the animation's contact key
## (see _on_axe_contact). This is how long after the swing STARTS the mini-game
## gives up waiting for that key and resolves anyway, as a fraction of the swing's
## own length — so a `swing` re-keyed without a contact key still chops, badly,
## instead of soft-locking the game with a strike that never lands.
@export var strike_timeout_slack := 1.35

# --- splitting: a swing can FAIL and leave a scar -------------------------
## Creative Director call, 2026-08-01: *"we should make sure the player doesn't
## split through every time guaranteed, they should leave a scar on the log if
## they fail a hit. The stat increase works towards easier spliting, higher tier
## logs have a harder % to break through."*
##
## The model Sam chose is a ROLL WITH A PITY BONUS made visible as scars: each
## failed swing marks the piece and makes the NEXT swing into it more likely to
## go through, so a stubborn log always gives eventually and you can read how
## close it is by looking at it. Every number here is a PLACEHOLDER except the two
## 5% steps Sam named.
@export_group("Splitting")
@export var default_split_chance := 0.7   # for a species row that names none
## Each scar already on a piece adds this to the next swing's odds. This is the
## pity counter — it is what stops a bad run of luck from stalling the game.
@export var scar_bonus := 0.15
## How much easier a SMALL piece is than the whole log it came from. 1.0 = a tiny
## billet is a near-certain split; 0.0 = size is irrelevant and a last small chunk
## resists exactly as hard as the fresh log did.
@export_range(0.0, 1.0) var size_relief := 0.2
## The ceiling, however strongly learned Strength and equipment weight the roll:
## a swing is never a certainty, which is the whole point of the mechanic.
@export_range(0.5, 1.0) var max_split_chance := 0.95
## Shake for a swing that bit but did not split — smaller than a real hit, and
## with NO hit-pause, so a successful split keeps the time-stop to itself.
@export var fail_impact := 0.25
@export var scar_width := 0.014         # thickness of the line a failed swing leaves (m)
@export_range(0.0, 1.0) var scar_length_frac := 0.8   # how far the line runs across the piece's top
@export var scar_lift := 0.004          # how far above the top face the line is laid, so it never z-fights (m)
@export var scar_colour := Color(0.20, 0.13, 0.09, 0.55)   # a soft mark, not a black bar
@export var debug_split_roll := -1      # -1 = roll for real; 0 = always fail; 1 = always split (tests only)

# --- procs (M7C: named chance-driven events off a successful split) --------
@export_group("Procs")
## Belt-and-braces safety cap on EXTRA cuts one swing's continuation chain may
## ever perform, independent of any node's own learned chain_cap — the M7C
## fairness contract requires both a learned AND a global stop ("the learned
## cap, the global safety cap, or the absence of useful geometry, whichever
## comes first"). PLACEHOLDER per Directive 3.
@export var global_proc_chain_cap := 3
@export var debug_force_proc := -1      # -1 = roll for real; 0 = never; 1 = always (tests only)
## Forces the grain_read OFFER roll (does a fresh piece get a gold mark), same
## shape as debug_force_proc. Independent of debug_split_roll/debug_force_proc,
## which govern what happens once a piece already has (or doesn't have) a mark.
@export var debug_force_grain := -1     # -1 = roll for real; 0 = never; 1 = always (tests only)

# --- swing cooldown (what the coffee buys) --------------------------------
## Creative Director call, 2026-08-01: coffee is "5% faster time between swings",
## and Sam chose a REAL cooldown for it to cut into — before this the game had
## none at all and a swing was gated only by the anticipation window.
@export_group("Swing rate")
@export var swing_cooldown := 0.45      # Creative Director call, 2026-08-01
@export var coffee_step := 0.05         # Sam's 5%, compounding per level
## Hard floor shared by skills and permanent equipment so the axe never loses
## its authored weight. PLACEHOLDER pending the measured tuning session.
@export var min_swing_cooldown := 0.25

# --- audio (hooks; drop a stream in to hear it) ---------------------------
@export_group("Audio")
@export var drop_sfx: AudioStream        # ref: drop.mp3 on log landing
@export var split_sfx: AudioStream       # ref: split sound on each chop
@export var thud_sfx: AudioStream        # a swing that bit but did not split

const _TEX_INSIDE := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_diffColor.jpg")
const _TEX_INSIDE_N := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_normals.jpg")
const _STUMP_FBX := preload("res://assets/models/chopping_stump_a/chopping_stump_a.fbx")

const _PICK_LAYER := 1 << 1              # on-block pieces sit on this layer for ray-picking only

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _fallers: Node3D = $Fallers

var _animator := _PieceAnimator.new()
var _pile := _WoodPile.new()
var _pieces_root: Node3D                  # identity-transform parent so piece.position == world
var _pile_root: Node3D                    # frozen stacked firewood proxies live here
var _haul_root: Node3D                    # a load on its way out of the yard; NOT part of the pile any more
var _on_block: Array = []                 # Array[Area3D] — script-animated pieces on the block
var _firewood: Array = []                 # Array[RigidBody3D] — the only physics pieces
var _pending: Dictionary = {}             # strike in flight, waiting for the axe's contact key
var _cooldown_left := 0.0                 # seconds until the axe can swing again (what coffee shortens)
var _stacking := false                    # firewood is flying into the pile
var _awaiting_stack := false              # log done; waiting for firewood to settle before stacking
var _await_since := 0.0                   # sec timestamp the wait began
var _staged_log: Dictionary = {}          # Handcart's one prepared next log; never inventory or automation
## M7C precision guard: the player's own request to suppress bonus cuts on the
## current work, with no penalty and no fairness spend. Input binding is an
## unresolved Creative Director decision (brief item 10), so the only entry
## point today is debug_set_precision_guard() — the same shape as every other
## debug_* seam in this file until Sam picks the real control.
var _precision_guard := false
var _last_double_strike_cuts := -1        # debug seam: cuts by the most recent continuation attempt
var _last_proc_burst_color := Color.TRANSPARENT   # debug seam: color of the most recent ProcBurst
var _manual_log_serial := 0
var _handled_log_roots: Dictionary = {}
var _last_quick_study_bonus := 0
var _last_quick_study_root_id: StringName = &""

## Technique grain opportunity: one preflighted local cut plane tied to one
## current on-block piece, with the world mark owned here so every lifecycle
## edge tears down the same state. PERMANENT — nothing here ages it out; it only
## ever clears via a real lifecycle edge (see _clear_grain_cue's callers).
var _grain_target: Area3D = null
var _grain_target_mesh: Mesh = null
var _grain_local_plane := Plane()
var _grain_local_anchor := Vector3.ZERO
var _grain_marks: Array[MeshInstance3D] = []
var _grain_last_clear_reason: StringName = &""
var _grain_candidate_dirty := false
var _grain_line_mesh: ArrayMesh = null
var _grain_dark_mat: StandardMaterial3D = null
var _grain_glow_mat: StandardMaterial3D = null
var _grain_core_mat: StandardMaterial3D = null
## Once-per-log latch: a mark is decided at most once per log, win or lose the
## roll, so it never relocates onto a "better" candidate and never stacks a
## second one after the first is taken. Reset only in _spawn_fresh_log.
var _grain_offered_this_log := false
var _grain_offer_count_this_log := 0     # debug seam: how many marks actually landed this log
var _last_grain_bonus := 0               # debug seam: XP paid by the most recent gold cut

var _source_mesh: Mesh
var _yaw_steps := 0
var _orbit_tween: Tween
var _axe: AxeViewmodel                    # the camera-mounted rig; null only in a scene without one
var _audio: AudioStreamPlayer3D
var _cut_mat: StandardMaterial3D          # cut-face material of the log CURRENTLY on the block
var _cut_mats: Dictionary = {}            # species index -> StandardMaterial3D (built once, reused)
var _bark_mats: Dictionary = {}           # "species index|source material id" -> re-skinned duplicate (see _apply_species_look)
var _specimens: Dictionary = {}           # species index -> Array[ArrayMesh]: stand-in firewood for a REBUILT pile
var _scar_meshes: Dictionary = {}         # species index -> ArrayMesh: the gouge a failed swing leaves
var _smoke_root: Node3D                    # landing puff pool; built before play to keep allocations off impact
var _smoke_puffs: Array[MeshInstance3D] = []
var _smoke_age := PackedFloat32Array()
var _smoke_duration := PackedFloat32Array()
var _smoke_start_pos: Array[Vector3] = []
var _smoke_end_pos: Array[Vector3] = []
var _smoke_start_scale: Array[Vector3] = []
var _smoke_end_scale: Array[Vector3] = []
var _phys_mat: PhysicsMaterial
var _cut_noise := FastNoiseLite.new()    # drives the jagged displacement of cut faces
var _stump_top_y := 0.5
var _stump_radius := 0.4
var _current_species: SpeciesDef = null   # the species of the log currently on the block; drives the yield item


func _ready() -> void:
	GameFeel.register_camera(_camera)
	# A cut material must exist before anything can slice; _spawn_fresh_log swaps
	# in the one belonging to whichever species it puts on the block.
	_cut_mat = _cut_mat_for(0)
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 0.9
	_phys_mat.bounce = 0.0

	_pieces_root = Node3D.new()
	_pieces_root.name = "OnBlock"
	add_child(_pieces_root)

	_pile_root = Node3D.new()
	_pile_root.name = "Pile"
	add_child(_pile_root)
	# A hauled load is reparented out of the pile the instant it is handed over, so
	# the next stack can start building underneath it without the two ever sharing
	# a node or a slot.
	_haul_root = Node3D.new()
	_haul_root.name = "Haul"
	add_child(_haul_root)
	_configure_pile()

	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)

	# _source_mesh is deliberately NOT built here: _spawn_fresh_log() below sets it
	# from the species it actually puts on the block, so building one up front only
	# loaded and scaled an FBX for a random species that was thrown away.
	_build_stump()
	_build_smoke_pool()
	GameState.building_tiers_changed.connect(_refresh_equipment_effects)
	GameState.skill_level_changed.connect(_on_grain_progression_changed)
	_refresh_equipment_effects()
	$Floor.physics_material_override = _phys_mat
	_build_axe()
	_spawn_fresh_log()

	# The pile on screen is a view of GameState's yard pile, so the yard you come
	# back to is the yard you left.
	#
	# This connection is what makes a LOADED SAVE show its pile at all: a child's
	# _ready runs before its parent's, so this scene is built before main.gd has
	# read the save off disk, and the pile it builds in _spawn_fresh_log above is
	# necessarily empty. The load lands moments later and this rebuilds on it.
	GameState.yard_pile_changed.connect(_on_yard_pile_changed)


func _on_grain_progression_changed(skill_id: StringName, _new_level: int) -> void:
	if skill_id != &"quick_study":
		return
	_refresh_grain_availability()


## Only ever CLEARS. A live mark is a rolled, once-per-log event, not a display
## of what the player currently owns — losing the skill (or the modifier that
## grants it) takes an unspent mark away, but gaining it never retroactively
## places one on whatever happens to be on the block; the next piece-creation
## event is the earliest a fresh offer can be rolled.
func _refresh_grain_availability() -> void:
	if not _grain_cue_enabled():
		_clear_grain_cue(&"skill_unavailable")


func _exit_tree() -> void:
	_clear_grain_cue(&"block_exit")
	GameFeel.unregister_camera()


func _process(delta: float) -> void:
	_animator.update()
	_update_grain_cue()
	_update_log_smoke(delta)

	if _cooldown_left > 0.0:
		_cooldown_left -= delta

	# The FAILSAFE, not the normal path: the axe's contact key resolves the strike
	# (_on_axe_contact). This only fires if that key never arrives — an animation
	# re-keyed without one, or no viewmodel in the scene at all — because a pending
	# strike that never resolves blocks every further click and stops the game dead.
	if not _pending.is_empty():
		_pending.timer -= delta
		if _pending.timer <= 0.0:
			_resolve_pending()

	if _awaiting_stack and _firewood_settled():
		_begin_stacking()

	# The load on its way out is animated independently of the stack coming in, so
	# the player can chop through a haul-away instead of waiting for it.
	if _pile.is_hauling:
		_pile.update_haul()

	if _stacking:
		_pile.update()
		if not _pile.is_animating:
			_stacking = false
			# The last piece of the load has landed and been paid for. If that
			# filled the yard, the whole pile leaves now — before the next log
			# drops, so the fresh stack starts on clear ground.
			if GameState.get_yard_pile_count() >= max_pile_pieces:
				_haul_away()
			_spawn_fresh_log(false)   # keep the pile; grow it with the next log


func _configure_pile() -> void:
	_pile.radius = pile_radius
	_pile.arc_span = deg_to_rad(pile_arc_span_deg)
	_pile.start_angle = deg_to_rad(pile_start_angle_deg)
	_pile.slot_spacing = pile_slot_spacing
	_pile.tier_depth_spacing = pile_tier_depth
	_pile.max_height = pile_max_height
	_pile.ground_y = pile_ground_y
	_pile.jitter = pile_jitter
	_pile.apex_extra = pile_apex_extra
	_pile.fly_duration = pile_fly_ms
	_pile.stagger = pile_stagger_ms
	_pile.haul_distance = haul_distance
	_pile.haul_rise = haul_rise
	_pile.haul_duration = haul_ms
	_pile.haul_stagger = haul_stagger_ms


# ------------------------------------------------- the yard's stockpile (M7A)
## The pile the player can SEE is the work they have done since the last load left
## the yard — GameState's yard pile, one mesh per piece.
##
## The firewood itself is NOT in it: the yard buys each piece the moment it lands
## (Creative Director call, 2026-08-01), so by the time a piece is stacked it has
## already been paid for. The pile is therefore a record of work, not of property,
## which is why it lives in GameState next to the lifetime counter rather than
## being derived from InventoryManager.
##
## REBUILT, not maintained. A rebuild is instant and total: the arc packing in
## wood_pile.gd is deterministic and has no notion of removing one piece from the
## middle of a stack, and faking one would leave pieces resting on nothing.
##
## Deliberately NOT called while a batch is flying in. Freshly cut pieces are the
## real sliced meshes and they animate into the pile; rebuilding on top of that
## would swap them for stand-ins mid-flight and throw away the best moment in the
## game.
func _rebuild_pile_from_yard() -> void:
	if _stacking or _awaiting_stack:
		return
	for c in _pile_root.get_children():
		_pile_root.remove_child(c)
		c.queue_free()
	_pile.reset()

	for species_index: int in _interleave(_pile_plan()):
		var meshes: Array = _specimens_for(species_index)
		if meshes.is_empty():
			continue
		var node := MeshInstance3D.new()
		node.mesh = meshes[randi() % meshes.size()]
		_pile_root.add_child(node)
		_pile.place_settled(node)


## How many pieces of each species to stack, from GameState's yard pile. Capped at
## `max_pile_pieces`, scaled down together so the mix on show still reflects the
## mix that was cut — the cap only bites on a save written before it was lowered,
## since a live pile is hauled away the moment it reaches it.
func _pile_plan() -> Dictionary:
	var yard := GameState.get_yard_pile()
	var counts: Dictionary = {}
	var total := 0
	var list := SpeciesTable.all()
	for i in range(list.size()):
		var item: StringName = &"" if list[i] == null else list[i].yield_item
		if item == &"":
			continue
		var n := int(yard.get(item, 0))
		if n <= 0:
			continue
		counts[i] = n
		total += n
	if total <= max_pile_pieces:
		return counts
	var scaled: Dictionary = {}
	for i: int in counts:
		scaled[i] = maxi(1, int(floor(float(counts[i]) * float(max_pile_pieces) / float(total))))
	return scaled


## Round-robin the plan into one sequence, so a yard holding two species stacks as
## a mixed pile rather than as two solid blocks. Which piece went on the pile first
## is not recoverable from a count, and a blended pile reads as wood accumulated
## over many logs, which is what it is.
func _interleave(plan: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var left := plan.duplicate()
	while not left.is_empty():
		for i: int in left.keys():
			out.append(i)
			left[i] = int(left[i]) - 1
			if int(left[i]) <= 0:
				left.erase(i)
	return out


## Stand-in firewood for a species, built once and cached.
##
## Built by SLICING that species' own log exactly the way the first two clicks on
## it would — two centre cuts into a quarter column, jagged cut faces, the
## species' own bark and inside grain. A box would have been cheaper and would
## have looked like a box next to the real pieces; this way a restored pile and a
## chopped one are made of the same thing. Lazy, so a species the player owns none
## of never loads its FBX at all.
func _specimens_for(species_index: int) -> Array:
	if _specimens.has(species_index):
		return _specimens[species_index]
	var out: Array = []
	var row := SpeciesTable.at(species_index)
	var paths := PackedStringArray() if row == null else row.meshes
	var mat := _cut_mat_for(species_index)
	# Two shapes is enough variety for a pile; six would be six FBX loads for
	# pieces that are mostly buried in the stack.
	for p_idx in range(mini(2, paths.size())):
		# Tinted like the log it came off, or a stand-in species' pile would be
		# oak-coloured next to the oak-coloured billets it just chopped.
		var whole := _apply_species_look(
			MeshUtils.centered(_build_split_log(paths[p_idx])), species_index)
		var billet := _quarter(whole, mat)
		if billet != null:
			out.append(billet)
	_specimens[species_index] = out
	return out


## Two centre cuts through a standing log -> a quarter column, which is what the
## chopping game's own early splits produce. Returns null if either cut degenerates
## (a mesh the plane misses), rather than a half-cut lump.
## NOTE it calls MeshUtils.jag_cut with the SPECIMEN'S material rather than going
## through _jag_cut(): that helper roughens whatever surface matches `_cut_mat`, the
## material of the log currently ON THE BLOCK, and a specimen for any other species
## would come back perfectly smooth (see the caching note on _cut_mat_for).
func _quarter(whole: ArrayMesh, mat: StandardMaterial3D) -> ArrayMesh:
	_cut_noise.frequency = cut_jag_freq
	var plane_x := Plane(Vector3.RIGHT, 0.0)
	var first := MeshSlicer.slice(whole, plane_x, mat)
	if first.below == null:
		return null
	var half := MeshUtils.jag_cut(first.below, plane_x, mat, cut_jag_amount, _cut_noise)
	var plane_z := Plane(Vector3.FORWARD, 0.0)
	var second := MeshSlicer.slice(half, plane_z, mat)
	if second.below == null:
		return null
	return MeshUtils.centered(
		MeshUtils.jag_cut(second.below, plane_z, mat, cut_jag_amount, _cut_noise))


## The yard pile changed under us — a save loaded, or a haul-away emptied it.
##
## The pieces THIS scene adds one at a time as they land also come through here,
## and must not trigger anything: the count check below is what tells the two
## apart. If the pile on screen already shows what GameState says it holds, there
## is nothing to rebuild, and a landing piece is by definition already shown.
func _on_yard_pile_changed(total: int) -> void:
	if _stacking or _awaiting_stack:
		return
	if _pile_root.get_child_count() == mini(total, max_pile_pieces):
		return
	_rebuild_pile_from_yard()


## A piece has come to rest on the pile. This is the moment the yard pays for it
## (Sam's call: converted to cash on entering the pile, never sold by hand), and
## the moment it starts counting toward the load that gets hauled away.
##
## The sale goes through Market like any other, so the price table stays the one
## place a piece's worth is decided and Directive 6 still holds — the stock leaves
## through InventoryManager and the cash arrives through GameState.
func _on_piece_landed(item_id: StringName) -> void:
	GameState.add_to_yard_pile(item_id, 1)
	if not auto_sell:
		return
	# Orders always pays through the unlimited Market first, then credits a
	# matching contract. Unmatched work therefore follows the original path.
	if Orders.settle_piece(item_id) <= 0:
		# Priced at nothing, or nothing in stock to sell: the piece still stacks,
		# so the yard never eats wood it did not pay for.
		push_warning("chopping_minigame: '%s' landed on the pile but could not be sold." % item_id)


## The load is full: the whole pile leaves the yard in a staggered wave while the
## player carries on chopping into the empty space it left.
func _haul_away() -> void:
	if _pile.is_hauling:
		return
	var load_out: Array = []
	for c in _pile_root.get_children():
		_pile_root.remove_child(c)
		_haul_root.add_child(c)
		load_out.append(c)
	if not load_out.is_empty():
		GameState.record_haul_away()
	_pile.reset()
	GameState.clear_yard_pile()
	_pile.start_hauling(load_out)


## True once every live firewood body has (nearly) stopped, or the wait times out.
func _firewood_settled() -> bool:
	if Time.get_ticks_msec() / 1000.0 - _await_since >= firewood_settle_timeout:
		return true
	for f in _firewood:
		if is_instance_valid(f) and (f as RigidBody3D).linear_velocity.length() > firewood_settle_speed:
			return false
	return true


## Gather the settled firewood into script-animated proxies and fly them into the
## pile (reference _startStacking): each physics body is baked to a frozen proxy at
## its landed transform, then the pile animates it into its arc slot.
func _begin_stacking() -> void:
	_awaiting_stack = false
	_stage_next_log()
	var proxies: Array = []
	for f in _firewood:
		if not is_instance_valid(f):
			continue
		var body := f as RigidBody3D
		var src: MeshInstance3D = body.get_node_or_null("Mesh")
		if src == null or src.mesh == null:
			body.queue_free()
			continue
		var proxy := MeshInstance3D.new()
		proxy.mesh = src.mesh
		_pile_root.add_child(proxy)
		proxy.global_transform = body.global_transform
		proxies.append(proxy)
		body.queue_free()
	_firewood.clear()

	if proxies.is_empty():
		_spawn_fresh_log(false)
		return

	# COLLECT (A7): the log is fully chopped and its firewood has settled, so
	# each finished piece deposits one unit of the log's species into inventory.
	# This is the single batch-collect point (it mirrors the retired authored
	# block's collect semantics); unregistered ids are errored+ignored by
	# InventoryManager, so an empty/typo yield is safe.
	var yield_item: StringName = &"" if _current_species == null else _current_species.yield_item
	if yield_item != &"":
		for _p in proxies:
			EventBus.resource_gathered.emit(yield_item, 1)
	log_completed.emit(&"" if _current_species == null else _current_species.id, proxies.size())

	# NOTE the experience is NOT awarded here. It is per log, not per piece, and it
	# is paid at the final split — see the tail of _perform_split.

	_stacking = true
	# Each piece pays out as it comes to rest, so the cash ticks up in the same
	# cascade the player is watching land.
	_pile.start_stacking(proxies, Callable(), _on_piece_landed.bind(yield_item))


## The finished MANUAL log's one root XP transaction. Quick Study is resolved
## once against the base award through ProcResolver; its bonus is folded into
## this single GameState write and can therefore never recurse as a new event.
##
## EXPERIENCE IS PER LOG, NOT PER PIECE (Creative Director call, 2026-08-02: the
## orbs drop "when the log is finally split"). ONE award, fired from the split that
## empties the block — the same instant the orbs burst, so the number going up and
## the thing on screen are one event rather than two.
##
## Gated on `auto_sell` with the cash payout: that flag means "the yard's payouts
## are live", and M4's suite switches it off because it is testing the YIELD
## contract and must not have the economy moving underneath it.
func _award_log_xp() -> void:
	if not auto_sell or _current_species == null:
		return
	_manual_log_serial += 1
	var root_id := StringName("manual_log_%d_%d" % [get_instance_id(), _manual_log_serial])
	_resolve_log_xp(_ManualLogOutcome.new(
		root_id, _ManualLogOutcome.Source.MANUAL, true, false, _current_species.xp_reward))


func _resolve_log_xp(outcome: RefCounted) -> int:
	_last_quick_study_bonus = 0
	_last_quick_study_root_id = &""
	_last_proc_burst_color = Color.TRANSPARENT
	if outcome == null or not outcome.completed or outcome.is_bonus_event \
			or outcome.root_event_id == &"" or outcome.base_xp <= 0:
		return 0
	if _handled_log_roots.has(outcome.root_event_id):
		return 0
	# A completed root is consumed before source eligibility is considered. A
	# restored/automated id cannot be resubmitted later wearing a "manual" label.
	_handled_log_roots[outcome.root_event_id] = true
	if not outcome.is_manual_root_completion():
		return 0

	var base: int = outcome.base_xp
	var awarded := base
	var fired_proc: StringName = &""
	var rank := SkillTree.get_level(&"quick_study")
	var proc_def: ProcDef = M7CContent.procs().by_id(&"quick_study") if M7CContent.procs() != null else null
	if rank > 0 and proc_def != null \
			and proc_def.eligibility == ProcDef.Eligibility.MANUAL_LOG_COMPLETION \
			and ProcResolver.should_proc(proc_def, debug_force_proc, rank):
		var multiplier := _manual_xp_multiplier(proc_def)
		awarded = maxi(base, int(round(float(base) * multiplier)))
		_last_quick_study_bonus = awarded - base
		if _last_quick_study_bonus > 0:
			fired_proc = proc_def.id

	_last_quick_study_root_id = outcome.root_event_id
	GameState.add_xp(awarded)
	_burst_xp_orbs(awarded)
	manual_xp_awarded.emit(base, _last_quick_study_bonus, fired_proc)

	if fired_proc != &"":
		var branch := SkillTree.branch_for_proc(fired_proc)
		_last_proc_burst_color = branch.color if branch != null else Color.WHITE
		# In open air above the block, never depth-occluded inside the finished log.
		ProcBurst.spawn(self, Vector3(0.0, _stump_top_y + 0.18, 0.0), _last_proc_burst_color)
		bonus_proc_announced.emit(fired_proc, 1)
	return awarded


func _manual_xp_multiplier(proc_def: ProcDef) -> float:
	for modifier: GameplayModifierDef in proc_def.modifiers:
		if modifier != null \
				and modifier.kind == GameplayModifierDef.Kind.MANUAL_XP \
				and modifier.operation == GameplayModifierDef.Operation.MULTIPLY:
			return maxf(1.0, modifier.magnitude)
	return 1.0


## The green orbs, Minecraft-style: they pop off the block and are drawn into the
## player (Creative Director call, 2026-08-02).
##
## THE XP IS ALREADY BANKED by the time these spawn, and deliberately so — see
## xp_orb.gd. Quitting during the second of flight must not cost the player the log
## they just chopped. The orbs are the receipt, not the payment.
##
## They burst, bounce on the floor beside the block and lie there a beat before
## being drawn in (Creative Director call, 2026-08-02) — so the stump's own radius
## and the yard floor go with them, and they land NEAR the log rather than on it.
##
## HOW MANY is a curve, not a ratio: a log worth 8 XP and one worth 56,000 both
## have to read as "a handful", so the count grows with the LOG's worth but is
## clamped hard. Tying one orb to one XP would bury the late game in confetti.
##
## `from`/`count_min`/`count_max` default to the routine log-completion burst
## (stump centre, orb_count_min..orb_count_max); the gold grain reward
## (_award_grain_bonus) passes the cut point and the raised grain_orb_count_*
## ceiling so its payout visibly outsizes an ordinary log's.
func _burst_xp_orbs(amount: int, from := Vector3(0.0, _stump_top_y + 0.12, 0.0),
		count_min := orb_count_min, count_max := orb_count_max) -> void:
	if not orbs_enabled or _camera == null or amount <= 0:
		return
	var count := clampi(int(round(sqrt(float(amount)) * orb_density)), count_min, count_max)
	for i in range(count):
		var orb := XPOrb.new()
		orb.name = "XPOrb%d" % i
		add_child(orb)
		orb.setup(from, _camera, float(i) * orb_stagger, orb_scatter_radius,
			pile_ground_y, _stump_radius, orb_collect_at)


# --------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT: _orbit(-1)
			KEY_D, KEY_RIGHT: _orbit(1)
			KEY_R: _spawn_fresh_log()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(event.position)


func _on_click(screen_pos: Vector2) -> void:
	if not _pending.is_empty():
		return   # one strike resolves at a time (matches reference _pendingSplit gate)
	if _axe != null and _axe.is_swinging():
		return   # mid-swing, including the recovery: you only have the one axe
	if _cooldown_left > 0.0:
		return   # still getting the axe back up — this is what the coffee shortens
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = _PICK_LAYER
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not (hit.collider in _on_block):
		return
	var piece: Area3D = hit.collider

	# A permanent gold grain mark already carries its own preflighted, VALID cut
	# candidate — clicking it cuts EXACTLY along that line, and never consumes
	# the click on a forced camera turn (Creative Director call, 2026-08-04: the
	# earlier ephemeral cue's forced 90-deg turn was what made taking the
	# opportunity feel bad — "the brief pop doesn't feel good when you get auto
	# turned"). This MUST come before the cross-axis check below, which would
	# otherwise spend the click reorienting the camera instead of cutting the
	# mark on exactly the pieces most likely to trip it.
	if piece == _grain_target and _grain_plane_is_valid():
		var grain_world_plane := MeshUtils.plane_to_world(_grain_local_plane, piece.global_transform)
		var grain_world_point: Vector3 = piece.global_transform * (
			_grain_local_plane.normal * _grain_local_plane.d)
		_swing_axe(grain_world_point, grain_world_plane.normal, screen_pos)
		_cooldown_left = current_swing_cooldown()
		_pending = {
			"piece": piece, "world_point": grain_world_point, "normal": grain_world_plane.normal,
			"dir": _dir_from_normal(grain_world_plane.normal), "timer": _strike_timeout(),
			"grain_plane": _grain_local_plane,
		}
		return

	var normal := _camera.global_transform.basis.x
	normal.y = 0.0
	if normal.length() < 0.0001:
		return
	normal = normal.normalized()
	# Always cut the LONGER horizontal axis. Cutting the short axis of a piece
	# whose depth is bigger only shaves it into a flat slab (which then flies off);
	# cutting the long axis is what squares it up. So if the perpendicular axis is
	# meaningfully longer than the one we'd cut here, snap the camera 90 deg to face
	# it instead. The bias adds hysteresis so near-square pieces don't ping-pong,
	# and we only reorient while the long axis is still big enough to be worth it.
	var cross := _camera.global_transform.basis.z
	cross.y = 0.0
	if not piece.get_meta("is_whole_log", false) and cross.length() > 0.0001:
		cross = cross.normalized()
		var along := _piece_extent_along(piece, normal)
		var across := _piece_extent_along(piece, cross)
		if across > along * long_axis_bias and across >= min_cut_width:
			var half_w := get_viewport().get_visible_rect().size.x * 0.5
			_turn_cross_axis(-1 if screen_pos.x < half_w else 1)
			return
	var world_point: Vector3 = hit.position
	_swing_axe(world_point, normal, screen_pos)
	_cooldown_left = current_swing_cooldown()
	_pending = {
		"piece": piece, "world_point": world_point, "normal": normal,
		"dir": _dir_from_normal(normal), "timer": _strike_timeout(),
	}


func _orbit(dir: int) -> void:
	_yaw_steps += dir
	_tween_pivot(deg_to_rad(_yaw_steps * camera_step_deg), orbit_time)


## Snap the camera ~90 deg (rounded to whole `camera_step_deg` steps so it stays on
## the orbit grid) so the swing crosses the piece's long axis. Forces firewood-
## sized chopping once a chunk is thin along the current cut direction.
func _turn_cross_axis(sign_dir: int) -> void:
	var steps := int(round(cross_axis_turn_deg / camera_step_deg))
	if steps == 0:
		steps = 1
	_yaw_steps += steps * sign_dir
	_tween_pivot(deg_to_rad(_yaw_steps * camera_step_deg), orbit_time)


func _tween_pivot(target_y: float, t: float) -> void:
	if _orbit_tween != null and _orbit_tween.is_valid():
		_orbit_tween.kill()
	_orbit_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_orbit_tween.tween_property(_pivot, "rotation:y", target_y, t)


# ------------------------------------------------- does the swing go through?
## Resolve one landed swing: either the wood cleaves, or the axe bites and leaves
## a scar. THE ROLL LIVES HERE AND NOT IN _perform_split ON PURPOSE — _perform_split
## means "cut this piece" and is what `debug_slice_world` and the whole M4 suite
## drive, so those keep testing geometry rather than luck.
##
## Deliberately does NOT clear a live grain cue just because a DIFFERENT piece was
## struck — the mark is PERMANENT and stays wherever it is until it is taken or a
## real lifecycle edge removes it (see _clear_grain_cue's callers); chopping
## around the yard must not sweep away an opportunity sitting on another piece.
func _resolve_strike(piece: Area3D, world_point: Vector3, normal: Vector3, dir_enum: int,
		local_override: Variant = null) -> bool:
	if _roll_splits(piece):
		piece.set_meta("scars", 0)
		var split := _perform_split(piece, world_point, normal, dir_enum, local_override)
		strike_resolved.emit(split)
		if split:
			# M7C: the ONLY call site. A continuation cut lands through
			# _perform_split directly, never back through _resolve_strike, so a
			# root swing can never spawn a second root event — see
			# _attempt_double_strike.
			_attempt_double_strike(normal, dir_enum)
		return split

	# It bit, it did not go through. Mark the wood and make the next swing into
	# this piece more likely — the pity bonus, worn where the player can see it.
	piece.set_meta("scars", _scars_on(piece) + 1)
	_add_scar(piece, world_point, normal)
	# Shake WITHOUT the hit-pause: a split keeps the time-stop to itself, so the
	# two outcomes feel different before the player has read a single number.
	GameFeel.register_impact(fail_impact, false)
	_play_sfx(thud_sfx)
	strike_resolved.emit(false)
	return false


# ------------------------------------------------------- M7C: Double Strike
## After a primary split lands, maybe cut a second, real billet with the same
## swing. Bounded by the LEARNED cap (the node's own ProcDef.chain_cap) AND the
## GLOBAL safety cap, and stops the moment there is no useful geometry left —
## "whichever comes first" (M7C brief). Every iteration preflights the
## candidate plane BEFORE rolling: a proc is never even asked for on a cut that
## could not execute, so a fired proc can never fail to land and an unfired
## roll never shows up as an announcement.
##
## THE ANNOUNCEMENT IS A COLOURED VFX AT THE CUT, NOT A TEXT BANNER (Creative
## Director call, 2026-08-04 — see ProcBurst). It fires once per EXECUTED cut,
## scaling with the completed result exactly like the fairness contract
## requires, never with the rolled intention.
func _attempt_double_strike(normal: Vector3, dir_enum: int) -> void:
	_last_double_strike_cuts = 0
	if _precision_guard and not _double_strike_safe_in_precision():
		return   # suppressed: no target lookup, no roll, no fairness spend
	if SkillTree.get_level(&"double_strike") <= 0:
		return
	var proc_def: ProcDef = M7CContent.procs().by_id(&"double_strike") if M7CContent.procs() != null else null
	if proc_def == null:
		return
	var cap := mini(proc_def.chain_cap, global_proc_chain_cap)
	var cuts := 0
	while cuts < cap:
		var target := _pick_double_strike_target()
		if target == null:
			break   # no useful geometry left on the block — stop, do not roll
		var point: Vector3 = target.global_position
		if not _double_strike_preflight(target, point, normal):
			break   # this target cannot take the cut either — stop, do not roll
		if not ProcResolver.should_proc(
				proc_def, debug_force_proc, SkillTree.get_level(&"double_strike")):
			break   # rolled and it did not fire — the chain ends here
		# Measured BEFORE the cut, from the target while it is still valid —
		# _perform_split frees it. Spawn point is raised above the piece's
		# TOP surface, in open air: `point` itself is the piece's volumetric
		# centre, and a burst starting there is inside solid wood and
		# depth-occluded — exactly the failure-scar bug ("drawn outward, not
		# carved in") in a new coat of paint. Caught by actually rendering it.
		var burst_mesh: Mesh = target.get_meta("mesh_ref")
		var burst_height: float = burst_mesh.get_aabb().size.y if burst_mesh != null else 0.2
		var burst_point := point + Vector3.UP * (burst_height * 0.5 + 0.05)
		if not _perform_split(target, point, normal, dir_enum):
			break   # belt-and-braces: preflight said yes but the real cut refused
		cuts += 1
		var branch := SkillTree.branch_for_proc(proc_def.id)
		_last_proc_burst_color = branch.color if branch != null else Color.WHITE
		ProcBurst.spawn(self, burst_point, _last_proc_burst_color)
	_last_double_strike_cuts = cuts
	if cuts > 0:
		bonus_proc_announced.emit(&"double_strike", cuts)


## Does an owned modifier explicitly make Double Strike safe during precision
## work? Only Steady Continuation grants this today (M7C brief: "unless an
## owned modifier explicitly makes them safe").
func _double_strike_safe_in_precision() -> bool:
	return SkillTree.get_level(&"steady_continuation") > 0


## Deterministic continuation target: the largest on-block piece by measured
## volume. `_on_block` only ever holds live, script-animated stays — never a
## settling firewood piece, a frozen pile piece, or an unrelated pile mesh —
## so any entry here already satisfies the fairness contract's "does not
## select settling, frozen, already-consumed, or unrelated pile pieces".
func _pick_double_strike_target() -> Area3D:
	var best: Area3D = null
	var best_vol := -1.0
	for p: Area3D in _on_block:
		if not is_instance_valid(p):
			continue
		var mesh: Mesh = p.get_meta("mesh_ref")
		if mesh == null:
			continue
		var s := mesh.get_aabb().size
		var vol := s.x * s.y * s.z
		if vol > best_vol:
			best_vol = vol
			best = p
	return best


## Pure trial: does a candidate world plane through `piece` produce two valid
## halves? Mirrors _perform_split's own plane-building exactly (square bias,
## world-to-local, sliver guard) but stops before any mutation — nothing is
## queue_free'd, nothing joins _on_block, no signal fires. Kept as a separate
## trial rather than a refactor of _perform_split so the well-tested M4 cut
## path is never touched by an M7C change.
func _double_strike_preflight(piece: Area3D, world_point: Vector3, normal: Vector3) -> bool:
	var mesh: Mesh = piece.get_meta("mesh_ref")
	if mesh == null:
		return false
	var xform := piece.global_transform
	var world_plane := Plane(normal, normal.dot(world_point))
	world_plane = _square_bias(mesh, xform, world_plane)
	var local_plane := _plane_to_local(world_plane, xform)
	local_plane = _sliver_guard(mesh, local_plane)
	var res := MeshSlicer.slice(mesh, local_plane, _cut_mat)
	return res.above != null and res.below != null


## Test/debug seam only — the real control is an unresolved Creative Director
## decision (M7C brief item 10). Mirrors this file's existing debug_* pattern.
func debug_set_precision_guard(enabled: bool) -> void:
	_precision_guard = enabled


func debug_last_double_strike_cuts() -> int:
	return _last_double_strike_cuts


func debug_last_proc_burst_color() -> Color:
	return _last_proc_burst_color


func debug_last_quick_study_bonus() -> int:
	return _last_quick_study_bonus


func debug_last_quick_study_root_id() -> StringName:
	return _last_quick_study_root_id


## Acceptance/tool seam over the exact live completion transaction. String ids
## keep callers from fabricating the typed enum directly; unknown sources are
## rejected as restored/non-eligible work.
func debug_award_log_xp_event(source_id: StringName, root_id: StringName,
		completed: bool, is_bonus_event: bool, base_xp: int) -> int:
	var source := _ManualLogOutcome.Source.RESTORED
	match source_id:
		&"manual": source = _ManualLogOutcome.Source.MANUAL
		&"automation": source = _ManualLogOutcome.Source.AUTOMATION
		&"restored": source = _ManualLogOutcome.Source.RESTORED
	return _resolve_log_xp(_ManualLogOutcome.new(
		root_id, source, completed, is_bonus_event, base_xp))


# ------------------------------------------ M7C Technique: grain opportunity
##
## REWORKED 2026-08-04 (Creative Director call): the earlier version was an
## EPHEMERAL cue that forced a 90-degree camera turn on exactly the pieces it
## could appear on, and cleared itself ~150-300ms after being shown — "the brief
## pop doesn't feel good when you get auto turned". It is now a PERMANENT mark,
## occasionally rolled onto a fresh piece, that cuts without ever consuming the
## cross-axis turn (see _on_click) and always goes through when taken (see
## _roll_splits) — see _award_grain_bonus for what taking it pays.
##
## THE OFFER IS A REAL PROC (`grain_read` in proc_table.tres), rolled through the
## same ProcResolver every other named chance-driven event in this file uses, so
## it inherits bounded-dry-streak fairness and the debug_force_grain seam for
## free — same shape as Double Strike and Quick Study. It is rolled once per
## fresh ON-BLOCK PIECE (Eligibility.MANUAL_PIECE_OFFER), preflighted BEFORE the
## roll exactly like Double Strike ("a proc is never even asked for on a cut
## that could not execute"), and LATCHES OFF for the rest of the current log the
## moment one placement succeeds — a mark neither relocates to a new "current"
## piece nor stacks a second one onto the same log.
func _grain_cue_enabled() -> bool:
	return SkillTree.get_level(&"quick_study") >= int(_GRAIN_CUE_CONFIG.minimum_skill_rank) \
		and SkillTree.owns_modifier(
			GameplayModifierDef.Kind.GRAIN_CUE, GameplayModifierDef.Operation.ENABLE)


func _grain_proc_def() -> ProcDef:
	return M7CContent.procs().by_id(&"grain_read") if M7CContent.procs() != null else null


func _try_show_grain_cue(target: Area3D) -> void:
	if not _grain_cue_enabled() or target == null or not is_instance_valid(target):
		return
	if _grain_target != null or _grain_offered_this_log:
		return   # decided once per log — a mark neither relocates nor stacks
	var mesh: Mesh = target.get_meta("mesh_ref")
	if mesh == null:
		return
	var normal := _camera.global_transform.basis.x
	normal.y = 0.0
	if normal.length() < 0.0001:
		return
	normal = normal.normalized()
	var point := target.global_position
	var world_plane := Plane(normal, normal.dot(point))
	world_plane = _square_bias(mesh, target.global_transform, world_plane)
	var local_plane := _sliver_guard(mesh, _plane_to_local(world_plane, target.global_transform))

	# Preflight BEFORE rolling, same fairness discipline as Double Strike: a rare
	# offer is never spent on a piece too small to actually carry the mark.
	if not _slice_preflight_ok(mesh, local_plane):
		return
	var proc_def := _grain_proc_def()
	if proc_def == null:
		return
	if not ProcResolver.should_proc(
			proc_def, debug_force_grain, SkillTree.get_level(&"quick_study")):
		return

	_grain_target = target
	_grain_target_mesh = mesh
	_grain_local_plane = local_plane
	_grain_candidate_dirty = false
	_grain_offered_this_log = true
	_grain_offer_count_this_log += 1

	# The sliver guard may shift the precomputed plane away from the requested
	# centre. Place the mark on that FINAL plane, never on the earlier intention.
	var candidate_world_point: Vector3 = target.global_transform * (
		local_plane.normal * local_plane.d)
	var top_y := target.global_position.y + mesh.get_aabb().size.y * 0.5 \
		+ float(_GRAIN_CUE_CONFIG.surface_lift)
	var world_anchor := Vector3(candidate_world_point.x, top_y, candidate_world_point.z)
	_grain_local_anchor = target.to_local(world_anchor)
	_build_grain_top_mark(target, world_anchor, world_plane.normal)


func _grain_plane_is_valid() -> bool:
	if _grain_target == null or not is_instance_valid(_grain_target) \
			or not (_grain_target in _on_block):
		return false
	var mesh: Mesh = _grain_target.get_meta("mesh_ref")
	if mesh == null or mesh != _grain_target_mesh:
		return false
	return _slice_preflight_ok(mesh, _grain_local_plane)


## A real MeshSlicer preflight: does cutting `mesh` along `local_plane` leave two
## halves that both keep a useful horizontal footprint beyond the authored
## tolerance? Validation only — running it never cuts anything. Split out of
## _grain_plane_is_valid so _try_show_grain_cue can preflight a CANDIDATE plane
## before it is ever stored as `_grain_target`/`_grain_local_plane`.
func _slice_preflight_ok(mesh: Mesh, local_plane: Plane) -> bool:
	var result := MeshSlicer.slice(mesh, local_plane, _cut_mat)
	if result.above == null or result.below == null:
		return false
	var tolerance: float = _GRAIN_CUE_CONFIG.candidate_tolerance
	for half: Mesh in [result.above, result.below]:
		var size := half.get_aabb().size
		if minf(size.x, size.z) <= tolerance:
			return false
	return true


## Three raised unshaded quads on the piece's TOP surface, parented to the piece
## so they move with it: a dark outline (readable on pale bark), a wide additive
## glow (the "glowing" in "glowing gold line"), and a solid gold core. GOLD IS
## AUTHORED, not read from SkillTree.branch_for_proc() — this is a world marker
## naming an opportunity, not a proc announcement, and must read as its own
## thing next to the Technique-green ProcBurst the reward fires on top of it.
func _build_grain_top_mark(target: Area3D, world_anchor: Vector3, normal: Vector3) -> void:
	var line_dir := Vector3.UP.cross(normal).normalized()
	var length := maxf(
		_piece_extent_along(target, line_dir) * float(_GRAIN_CUE_CONFIG.mark_length_fraction),
		float(_GRAIN_CUE_CONFIG.mark_dark_width))
	var mats := _grain_mark_materials()
	var layers := [
		{"name": "GrainMarkDark", "width": _GRAIN_CUE_CONFIG.mark_dark_width, "material": mats[0]},
		{"name": "GrainMarkGlow", "width": _GRAIN_CUE_CONFIG.mark_glow_width, "material": mats[1]},
		{"name": "GrainMarkGold", "width": _GRAIN_CUE_CONFIG.mark_core_width, "material": mats[2]},
	]
	for i in range(layers.size()):
		var layer: Dictionary = layers[i]
		var mark := MeshInstance3D.new()
		mark.name = layer.name
		mark.mesh = _grain_unit_line_mesh()
		mark.material_override = layer.material
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target.add_child(mark)
		mark.global_transform = Transform3D(
			Basis(line_dir * length, Vector3.UP.cross(line_dir) * float(layer.width), Vector3.UP),
			world_anchor + Vector3.UP * (float(i) * float(_GRAIN_CUE_CONFIG.layer_lift)))
		_grain_marks.append(mark)


func _grain_unit_line_mesh() -> ArrayMesh:
	if _grain_line_mesh != null:
		return _grain_line_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, -0.5, 0.0)
	var b := Vector3(0.5, -0.5, 0.0)
	var c := Vector3(0.5, 0.5, 0.0)
	var d := Vector3(-0.5, 0.5, 0.0)
	for triangle: Array in [[a, b, c], [a, c, d]]:
		for vertex: Vector3 in triangle:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(vertex.x, vertex.y) + Vector2(0.5, 0.5))
			st.add_vertex(vertex)
	_grain_line_mesh = st.commit()
	return _grain_line_mesh


## Lazily built and cached: only one gold mark is ever live at a time and its
## colour is fixed authored data, unlike ProcBurst's per-branch colour cache.
func _grain_mark_materials() -> Array:
	if _grain_core_mat == null:
		_grain_dark_mat = StandardMaterial3D.new()
		_grain_dark_mat.albedo_color = Color(0.015, 0.02, 0.015, 0.98)
		_grain_dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_grain_dark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_grain_dark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		_grain_core_mat = StandardMaterial3D.new()
		_grain_core_mat.albedo_color = _GRAIN_CUE_CONFIG.mark_color
		_grain_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_grain_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_grain_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		# ADDITIVE, and its texture fades COLOUR to black, not just alpha — the
		# "square exp bubble" lesson XPOrb's halo already paid for (see its
		# header): an additive surface adds its RGB to whatever is behind it, so
		# fading only alpha leaves a hard-edged card. _update_grain_pulse breathes
		# this material's own albedo_color alpha every frame.
		_grain_glow_mat = StandardMaterial3D.new()
		_grain_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_grain_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_grain_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_grain_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_grain_glow_mat.albedo_texture = _grain_glow_texture()
		_grain_glow_mat.albedo_color = Color(1.0, 1.0, 1.0, _GRAIN_CUE_CONFIG.glow_pulse_min)
	return [_grain_dark_mat, _grain_glow_mat, _grain_core_mat]


## A soft-edged glow across the WIDTH of the line only, constant along its
## length: the unit line mesh's WIDTH axis maps to UV.v (see
## _grain_unit_line_mesh), so a vertical gradient reads as a neon-tube glow
## rather than a hard bar. Fades to Color(0,0,0,0) at both edges — colour AND
## alpha together — never alpha-only, for the exact reason ProcBurst's spark
## texture and XPOrb's halo texture do the same.
func _grain_glow_texture() -> GradientTexture2D:
	var c: Color = _GRAIN_CUE_CONFIG.mark_color
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(c.r, c.g, c.b, 1.0),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 64
	return tex


func _update_grain_cue() -> void:
	if _grain_target == null:
		return
	if not is_instance_valid(_grain_target) or not (_grain_target in _on_block) \
			or _grain_target.get_meta("mesh_ref") != _grain_target_mesh:
		_clear_grain_cue(&"invalid")
		return
	if _grain_candidate_dirty:
		_grain_candidate_dirty = false
		if not _grain_plane_is_valid():
			_clear_grain_cue(&"invalid")
			return
	_update_grain_pulse()


## The mark is GLOWING, not static — its additive layer breathes between the
## authored min/max on a plain sine of wall-clock time. Cosmetic only, so it
## rides real time rather than Engine.time_scale, which A11's hit-pause drives to
## near-zero for a beat on every real split.
func _update_grain_pulse() -> void:
	if _grain_glow_mat == null:
		return
	var period := maxf(0.05, float(_GRAIN_CUE_CONFIG.glow_pulse_period_sec))
	var t := float(Time.get_ticks_msec()) / 1000.0
	var k := 0.5 + 0.5 * sin(t * TAU / period)
	_grain_glow_mat.albedo_color.a = lerpf(
		float(_GRAIN_CUE_CONFIG.glow_pulse_min), float(_GRAIN_CUE_CONFIG.glow_pulse_max), k)


func _clear_grain_cue(reason: StringName) -> void:
	var had_cue := _grain_target != null or not _grain_marks.is_empty()
	for mark: MeshInstance3D in _grain_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_grain_marks.clear()
	_grain_target = null
	_grain_target_mesh = null
	_grain_local_anchor = Vector3.ZERO
	_grain_candidate_dirty = false
	if had_cue:
		_grain_last_clear_reason = reason


func _pick_grain_target(candidates: Array) -> Area3D:
	var best: Area3D = null
	var best_volume := -1.0
	for candidate in candidates:
		if not is_instance_valid(candidate) or not (candidate in _on_block):
			continue
		var mesh: Mesh = candidate.get_meta("mesh_ref")
		if mesh == null:
			continue
		var size := mesh.get_aabb().size
		var volume := size.x * size.y * size.z
		if volume > best_volume:
			best_volume = volume
			best = candidate
	return best


## The reward for taking the mark: a Technique-green ProcBurst plus a big XP
## payout, banked before the orbs that carry it erupt from the SAME point the
## mark was cut — never the stump centre — so a gold cut visibly outsizes a
## routine log award. `burst_point` is measured by the caller from the piece's
## SETTLED transform, in open air above its top surface (never inside the solid
## wood — the failure-scar bug, "drawn outward, not carved in", in new paint).
##
## THE VFX READS TECHNIQUE GREEN, NOT GOLD — Quick Study is the node that grants
## the mechanic, and a proc's announcement colour is always its branch's, per the
## 2026-08-04 ProcBurst convention. Gold stays the mark's own identity; green is
## this event's.
func _award_grain_bonus(burst_point: Vector3) -> void:
	_last_grain_bonus = 0
	if _current_species == null:
		return
	var proc_def := _grain_proc_def()
	if proc_def == null:
		return
	# The multiplier is authored data on the proc (proc_table.tres), read through
	# the same generic helper Quick Study's log-completion bonus uses — never a
	# literal "3.0" in code.
	var multiplier := _manual_xp_multiplier(proc_def)
	var bonus := maxi(1, int(round(float(_current_species.xp_reward) * multiplier)))
	_last_grain_bonus = bonus
	GameState.add_xp(bonus)
	_burst_xp_orbs(bonus, burst_point, grain_orb_count_min, grain_orb_count_max)

	var branch := SkillTree.branch_for_proc(&"quick_study")
	var color := branch.color if branch != null else Color.WHITE
	_last_proc_burst_color = color
	ProcBurst.spawn(self, burst_point, color)
	grain_read_awarded.emit(bonus)


func debug_has_grain_cue() -> bool:
	return _grain_target != null and is_instance_valid(_grain_target)


func debug_grain_plane_valid() -> bool:
	return _grain_plane_is_valid()


func debug_grain_top_mark_count() -> int:
	var count := 0
	for mark: MeshInstance3D in _grain_marks:
		if is_instance_valid(mark):
			count += 1
	return count


func debug_grain_cue_color() -> Color:
	return _GRAIN_CUE_CONFIG.mark_color if _grain_target != null else Color.TRANSPARENT


func debug_invalidate_grain_candidate() -> void:
	if _grain_target == null or _grain_target_mesh == null:
		return
	var size := _grain_target_mesh.get_aabb().size
	_grain_local_plane.d += maxf(size.x, size.z) + float(_GRAIN_CUE_CONFIG.candidate_tolerance) * 2.0
	_grain_candidate_dirty = true


func debug_grain_clear_reason() -> StringName:
	return _grain_last_clear_reason


func debug_last_grain_bonus() -> int:
	return _last_grain_bonus


## How many times a gold mark has actually been PLACED on the current log (not
## how many times a roll was attempted) — the direct assertion that the latch
## stops after one, rather than inferring it from absence.
func debug_grain_offer_count() -> int:
	return _grain_offer_count_this_log


## Render-tool seam: force a gold mark onto the current on-block piece for a
## screenshot, bypassing the rarity roll and the once-per-log latch. The cue is
## PERMANENT now, so unlike its predecessor this no longer needs to fake-hold an
## animation alive against a settle-based expiry — there is none left to outlive.
func debug_hold_grain_cue() -> void:
	var target := _pick_grain_target(_on_block)
	if target == null:
		return
	_clear_grain_cue(&"shot_hold")
	_grain_offered_this_log = false
	var forced := debug_force_grain
	debug_force_grain = 1
	_try_show_grain_cue(target)
	debug_force_grain = forced


## The odds that ONE swing cleaves `piece`, all in one place:
##   the wood's own resistance, made easier as the piece gets smaller,
##   + the scars already in it, + learned Strength effects, + axe weighting,
##   capped so a swing is never a certainty.
func split_chance_for(piece: Area3D) -> float:
	var base: float = default_split_chance if _current_species == null else _current_species.split_chance

	# Size relief: a fresh log is the full fight, a small billet much less of one.
	# Measured against the log this piece came from, so it is a fraction of THIS
	# log rather than an absolute size that a bigger species would fail.
	var frac := _size_fraction(piece)
	base += (1.0 - base) * (1.0 - frac) * size_relief

	base += float(_scars_on(piece)) * scar_bonus
	# Strength owns player capability; the cash axe only weights ordinary
	# reliability. Separate queries prevent equipment from granting a skill id.
	base += SkillTree.total_effect(SkillNodeDef.Effect.SPLIT_STRENGTH)
	base += Shop.total_effect(UpgradeDef.Effect.SPLIT_RELIABILITY)
	return clampf(base, 0.0, max_split_chance)


func _roll_splits(piece: Area3D) -> bool:
	if debug_split_roll == 0:
		return false
	if debug_split_roll == 1:
		return true
	# GOLD SWINGS ALWAYS SPLIT (Creative Director call, 2026-08-04) — checked
	# AFTER the debug forces above, so a suite can still force a failure on
	# unmarked wood, or force one on marked wood too, without this bypass
	# fighting the test seam for the strongest say.
	if piece == _grain_target:
		return true
	return randf() < split_chance_for(piece)


func _scars_on(piece: Area3D) -> int:
	return int(piece.get_meta("scars", 0))


## This piece's volume as a fraction of the whole log's, by AABB — cheap, and the
## slicer's pieces are chunky enough for a box to rank them correctly. Returns 1.0
## if the source log is unknown, so an unmeasurable piece is treated as the full
## fight rather than a free one.
func _size_fraction(piece: Area3D) -> float:
	var mesh: Mesh = piece.get_meta("mesh_ref")
	if mesh == null or _source_mesh == null:
		return 1.0
	var s := mesh.get_aabb().size
	var w := _source_mesh.get_aabb().size
	var whole := w.x * w.y * w.z
	if whole <= 0.0001:
		return 1.0
	return clampf((s.x * s.y * s.z) / whole, 0.0, 1.0)


## The mark a failed swing leaves: a thin line ACROSS THE TOP OF THE LOG, along
## the cut the axe was trying to make.
##
## Creative Director call, 2026-08-01: *"It would need to be on the top, the line
## in the direction the camera is facing from where the player clicked."* That is
## the honest place for it — the log stands on the block and the axe comes down on
## its top face, so the bite belongs on the top, not on the side the click ray
## happened to enter through (which is where the first version put it).
##
## The line runs along `UP x normal`. `normal` is the camera's own right vector
## (see _on_click), so the cut plane contains the camera's forward — and the line
## the plane leaves on the top face runs away from the viewer, exactly the line the
## split would have opened.
##
## It is a child of the piece, so it turns with it and dies with it. A piece that
## finally splits takes its marks with it and the two fresh halves start clean —
## which is correct, since the cleave went straight through them.
func _add_scar(piece: Area3D, world_point: Vector3, normal: Vector3) -> void:
	var line_dir := Vector3.UP.cross(normal)
	if line_dir.length() < 0.001:
		return
	line_dir = line_dir.normalized()

	var mesh: Mesh = piece.get_meta("mesh_ref")
	if mesh == null:
		return
	# Pieces on the block are only ever yawed, so the mesh's own height still gives
	# the top face, and the click's x/z give where along it the axe came down.
	var top_y := piece.global_position.y + mesh.get_aabb().size.y * 0.5
	var length := maxf(_piece_extent_along(piece, line_dir) * scar_length_frac, scar_width)

	var scar := MeshInstance3D.new()
	scar.mesh = _scar_mesh()
	piece.add_child(scar)
	# Built as a unit quad and stretched here, so one cached mesh serves a line of
	# any length on any piece.
	scar.global_transform = Transform3D(
		Basis(line_dir * length, Vector3.UP.cross(line_dir) * scar_width, Vector3.UP),
		Vector3(world_point.x, top_y + scar_lift, world_point.z))


## The mark itself: a 1x1 quad, laid flat and stretched to length by _add_scar,
## in one soft dark tone shared by every wood.
##
## Creative Director calls, both learned the hard way. *"I am having a hard time
## seeing the scar, it can just be a dark color as well, so no need to have it
## match every log"* retired a prettier two-tone version that wore each species'
## own inside grain and was much harder to see. Then *"the line is way too dark,
## it should just be a soft-indicator of failure"* — so it is translucent now,
## a thin mark where the axe failed to punch through rather than a black bar.
##
## UNSHADED on purpose: a lit material dims into dark bark exactly where the mark
## matters most. And it is laid just PROUD of the surface, never carved into it —
## geometry cannot subtract from a surface, and the first version sank a notch into
## the log and rendered completely invisible behind the bark in front of it.
## (Godot's Decal node, the obvious tool, does not render under Compatibility.)
func _scar_mesh() -> ArrayMesh:
	if _scar_meshes.has(0):
		return _scar_meshes[0]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Winding is deliberately not fussed over: the material is CULL_DISABLED (see
	# the winding note in CLAUDE.md), so a mark cannot end up see-through whichever
	# way its triangles happen to wind.
	var a := Vector3(-0.5, -0.5, 0.0)
	var b := Vector3(0.5, -0.5, 0.0)
	var c := Vector3(0.5, 0.5, 0.0)
	var d := Vector3(-0.5, 0.5, 0.0)
	for tri: Array in [[a, b, c], [a, c, d]]:
		for i in range(3):
			var v: Vector3 = tri[i]
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(v.x, v.y) + Vector2(0.5, 0.5))
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = scar_colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	_scar_meshes[0] = mesh
	return mesh


func _species_index_of(row: SpeciesDef) -> int:
	if row == null:
		return 0
	var i := SpeciesTable.index_of(row.id)
	return i if i >= 0 else 0


## Seconds the player must wait between swings, after the coffee. Compounding, so
## each cup is 5% off what the last one left rather than 5% off the original.
func current_swing_cooldown() -> float:
	# COMPOUNDING, which is why this asks the tree for LEVELS rather than for a
	# summed magnitude: ten levels of 5% off is 40% of the original wait, not
	# zero. Only the caller knows what its number means.
	var level := SkillTree.total_levels(SkillNodeDef.Effect.SWING_SPEED)
	var after_skill := swing_cooldown * pow(1.0 - coffee_step, float(level))
	var equipment := clampf(Shop.total_effect(UpgradeDef.Effect.SWING_RECOVERY), 0.0, 0.9)
	return maxf(min_swing_cooldown, after_skill * (1.0 - equipment))


# --------------------------------------------------------------- slicing
## Split the given on-block piece by a world plane through `world_point` with the
## given cut `normal`. Fires shake/pause/SFX, realises the two halves (firewood ->
## physics, chunky -> stays), and runs the radial shockwave over the block.
##
## `local_override`, when supplied, is the piece's OWN local cut plane — the
## permanent gold grain mark's already-preflighted candidate — and SKIPS
## `_square_bias`/`_plane_to_local`/`_sliver_guard` entirely. Those exist to bias
## an arbitrary click toward a square, valid cut; re-running them on a plane that
## was already biased once at offer time could walk the cut off the mark it drew.
## The override is read AFTER `_animator.finish_for([piece])` snaps the piece to
## its resting transform, since the piece may still be mid-hop when its mark is
## taken.
func _perform_split(piece: Area3D, world_point: Vector3, normal: Vector3, dir_enum: int,
		local_override: Variant = null) -> bool:
	# The reward is tied to the PIECE, not to how the cut arrived — a manual click
	# on the mark and an automated Double Strike continuation that happens to land
	# on it both pay out, exactly once, right here before the piece is freed.
	var is_grain_cut := piece == _grain_target

	# A slice must run on a settled mesh — snap any in-flight hop first.
	_animator.finish_for([piece])
	var mesh: Mesh = piece.get_meta("mesh_ref")
	var xform := piece.global_transform
	var local_plane: Plane
	if local_override != null:
		local_plane = local_override
		var override_world_plane: Plane = MeshUtils.plane_to_world(local_plane, xform)
		world_point = xform * (local_plane.normal * local_plane.d)
		normal = override_world_plane.normal
	else:
		var world_plane := Plane(normal, normal.dot(world_point))
		world_plane = _square_bias(mesh, xform, world_plane)   # keep footprints square, not flat slabs
		local_plane = _plane_to_local(world_plane, xform)
		local_plane = _sliver_guard(mesh, local_plane)

	var res := MeshSlicer.slice(mesh, local_plane, _cut_mat)
	if res.above == null or res.below == null:
		return false
	# Roughen the fresh cut faces so the split reads as cloven wood, not a laser cut.
	res.above = _jag_cut(res.above, local_plane)
	res.below = _jag_cut(res.below, local_plane)

	# A7: this is the ONLY hit path — GameFeel turns it into shake + hit-pause.
	# (Reference fires triggerShake right here, inside performSplit.)
	EventBus.action_hit_registered.emit(
		world_point, GameState.get_tool_tier(Enums.ToolType.AXE), dir_enum)
	_play_sfx(split_sfx)

	if is_grain_cut:
		# Open air above the piece's TOP surface, never at its volumetric centre
		# (inside solid wood, depth-occluded) — the exact failure-scar lesson
		# _attempt_double_strike's own burst point already applies.
		var burst_height: float = mesh.get_aabb().size.y if mesh != null else 0.2
		var burst_point: Vector3 = piece.global_position + Vector3.UP * (burst_height * 0.5 + 0.05)
		_award_grain_bonus(burst_point)
		_clear_grain_cue(&"consumed")

	_on_block.erase(piece)
	piece.queue_free()

	var new_stays: Array = []
	for half: ArrayMesh in [res.above, res.below]:
		var out_sgn := 1.0 if half == res.above else -1.0
		var node := _realise_half(half, xform, normal * out_sgn)
		if node != null:
			new_stays.append(node)

	_apply_shockwave(world_point, new_stays)
	if not new_stays.is_empty():
		_try_show_grain_cue(_pick_grain_target(new_stays))

	# Log fully chopped (nothing choppable left): wait for the firewood to settle,
	# then gather it into the pile and spawn a fresh log.
	if _on_block.is_empty():
		_awaiting_stack = true
		_await_since = Time.get_ticks_msec() / 1000.0
		# THE XP LANDS ON THE SPLIT ITSELF, not when the firewood has settled
		# (Creative Director call, 2026-08-02: *"pop out the moment the final piece
		# is split, so all the collecting happens at once"*). The settle wait is up
		# to `firewood_settle_timeout` long, so awarding at _begin_stacking put the
		# reward a beat behind the swing that earned it, and the orbs then arrived
		# on their own instead of inside the same burst of activity as the pieces
		# flying to the pile.
		_award_log_xp()
	return true


## Classify a freshly-sliced half and realise it. Returns the stay node, or null
## if it became firewood (physics).
func _realise_half(half: ArrayMesh, parent_xform: Transform3D, out_dir: Vector3) -> Area3D:
	var aabb := half.get_aabb()
	var c := aabb.position + aabb.size * 0.5
	var centered := _translate_mesh(half, -c)
	var world_pos := parent_xform * c

	var s := centered.get_aabb().size
	var vol := s.x * s.y * s.z
	# Fly-off (firewood) is judged on the HORIZONTAL footprint only — the un-cut
	# height (Y) is ignored, so a tall-but-still-wide piece doesn't fly off just for
	# being tall. It detaches when it's small (volume) or its footprint is a flat
	# slab (x:z aspect). With long-axis-forced cuts the footprint stays square, so
	# in practice pieces fly off by volume once they're a proper small chunk.
	var horiz_mx := maxf(s.x, s.z)
	var horiz_mn := maxf(minf(s.x, s.z), 0.0001)
	var is_firewood := vol <= min_vol or (horiz_mx / horiz_mn) > aspect_limit

	if is_firewood:
		_spawn_firewood(centered, world_pos, out_dir)
		return null
	var yaw := deg_to_rad(randf_range(-fresh_yaw_deg, fresh_yaw_deg))
	return _make_stay_piece(centered, world_pos, yaw)


## The radial "shockwave": every on-block piece pops away from the cut point, with
## distance falloff (near = big hop, far = none) and a staggered delay so it
## ripples outward. A hull-separation solver then de-overlaps the desired resting
## spots and keeps them inside the stump footprint before the hops are dispatched.
func _apply_shockwave(cut_point: Vector3, new_stays: Array) -> void:
	var cut2 := Vector2(cut_point.x, cut_point.z)
	var entries: Array = []
	for p: Area3D in _on_block:
		var pc := Vector2(p.position.x, p.position.z)
		var radial := pc - cut2
		var dist := radial.length()
		var dir2: Vector2
		if dist < 0.0001:
			var ang := randf() * TAU
			dir2 = Vector2(cos(ang), sin(ang))
		else:
			dir2 = radial / dist

		var push: float
		var pop: float
		var tilt: float
		var delay: float
		if p in new_stays:
			push = half_push; pop = pop_height; tilt = 1.0; delay = 0.0
		else:
			var u := maxf(0.0, 1.0 - dist / jostle_radius)
			push = jostle_push * u
			if push < 0.0005:
				continue   # too far to feel the strike — leave it resting
			pop = pop_height * u
			tilt = u
			delay = clampf(dist / delay_ref_dist, 0.0, 1.0) * stagger_ms

		entries.append({
			"piece": p, "hull": _hull2d(p.get_meta("mesh_ref"), p.quaternion),
			"dx": pc.x + dir2.x * push, "dz": pc.y + dir2.y * push,
			"pop": pop, "tilt": tilt, "delay": delay, "yaw": p.rotation.y,
		})

	_separate(entries, current_work_radius() * clamp_radius_frac, sep_gap)

	for e: Dictionary in entries:
		var p: Area3D = e.piece
		var cur := Vector2(p.position.x, p.position.z)
		var d := Vector2(e.dx, e.dz) - cur
		_animator.animate(p, Vector3(d.x, 0.0, d.y), d.length(), e.pop, e.delay, e.tilt, e.yaw)


## Slice the first on-block piece by a WORLD plane, synchronously (no anticipation
## delay). Used by dev shots / poc_smoke.
func debug_slice_world(world_plane: Plane) -> bool:
	if _on_block.is_empty():
		return false
	var piece: Area3D = _on_block[0]
	var wp := world_plane.project(piece.global_position)
	return _perform_split(piece, wp, world_plane.normal, _dir_from_normal(world_plane.normal))


## Like debug_slice_world, but goes through the ROLL — so it can fail, scar the
## piece and leave it whole. This is the headless seam for the split mechanic;
## `debug_split_roll` forces the outcome so a test never depends on luck.
## Returns true if the wood actually split.
func debug_swing_world(world_plane: Plane, point_offset := Vector3.ZERO) -> bool:
	if _on_block.is_empty():
		return false
	var piece: Area3D = _on_block[0]
	# On the SURFACE, not on the plane through the middle of the piece. A real
	# click lands where the ray hits the wood, and a scar placed at the projected
	# centre would be buried inside the log — which is exactly how the first render
	# of this mechanic came out invisible.
	# The point only has to lie ON THE CUT PLANE: the mark is drawn where that plane
	# crosses the top face, so there is no surface to hunt for.
	var wp := world_plane.project(piece.global_position) + point_offset
	return _resolve_strike(piece, wp, world_plane.normal, _dir_from_normal(world_plane.normal))


## Scars currently worn by the piece on the block (the pity counter, and what the
## shot tools and tests count).
func debug_scar_count() -> int:
	if _on_block.is_empty():
		return 0
	return _scars_on(_on_block[0])


func debug_split_chance() -> float:
	if _on_block.is_empty():
		return 0.0
	return split_chance_for(_on_block[0])


func debug_has_staged_log() -> bool:
	return not _staged_log.is_empty()


# ------------------------------------------------------- piece factories
func _make_stay_piece(centered_mesh: Mesh, world_pos: Vector3, yaw: float, is_whole_log := false) -> Area3D:
	var piece := Area3D.new()
	piece.collision_layer = _PICK_LAYER
	piece.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = centered_mesh
	piece.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = centered_mesh.create_convex_shape()
	piece.add_child(cs)
	_pieces_root.add_child(piece)
	piece.position = world_pos
	piece.quaternion = Quaternion(Vector3.UP, yaw)
	piece.set_meta("mesh_ref", centered_mesh)
	piece.set_meta("is_whole_log", is_whole_log)
	_on_block.append(piece)
	return piece


func _spawn_firewood(centered_mesh: Mesh, world_pos: Vector3, out_dir: Vector3) -> void:
	var body := RigidBody3D.new()
	body.physics_material_override = _phys_mat
	body.linear_damp = piece_linear_damp
	body.angular_damp = piece_angular_damp
	body.continuous_cd = true
	var vs := centered_mesh.get_aabb().size
	body.mass = maxf(wood_density * vs.x * vs.y * vs.z, min_mass)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = centered_mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = centered_mesh.create_convex_shape()
	body.add_child(cs)
	_fallers.add_child(body)
	body.global_position = world_pos

	var out := Vector3(out_dir.x, 0.0, out_dir.z)
	if out.length() > 0.0001:
		out = out.normalized()
	var to_cam := _camera.global_transform.basis.z   # points from scene toward the viewer
	to_cam.y = 0.0
	if to_cam.length() > 0.0001:
		to_cam = to_cam.normalized()
	body.linear_velocity = out * firewood_out + Vector3.UP * firewood_up + to_cam * firewood_toward_cam
	body.angular_velocity = Vector3(
		randf_range(-firewood_tumble, firewood_tumble),
		randf_range(-firewood_tumble, firewood_tumble),
		randf_range(-firewood_tumble, firewood_tumble))

	_firewood.append(body)
	while _firewood.size() > max_firewood:
		var old = _firewood.pop_front()
		if is_instance_valid(old):
			old.queue_free()


# --------------------------------------------------- separation solver (qC)
## Port of the reference's qC: 5 relaxation passes that (a) pull each piece's
## desired centre back inside the stump radius and (b) push overlapping piece
## hulls apart, using 2D convex-hull SAT in the ground plane.
func _separate(entries: Array, radius: float, gap: float) -> void:
	for _iter in range(5):
		var moved := false
		for e: Dictionary in entries:
			var k := _clamp_to_radius(e.hull, e.dx, e.dz, radius)
			if k.hit:
				e.dx += k.v.x; e.dz += k.v.y; moved = true
		for i in range(entries.size()):
			for j in range(i + 1, entries.size()):
				var a: Dictionary = entries[i]
				var b: Dictionary = entries[j]
				var g := _overlap(a.hull, a.dx, a.dz, b.hull, b.dx, b.dz, gap)
				if g.hit:
					a.dx -= g.v.x * 0.5; a.dz -= g.v.y * 0.5
					b.dx += g.v.x * 0.5; b.dz += g.v.y * 0.5
					moved = true
		if not moved:
			break


func _clamp_to_radius(hull: PackedVector2Array, dx: float, dz: float, r: float) -> Dictionary:
	var max_u := 0.0
	var ax := 0.0
	var az := 0.0
	for p in hull:
		var ex := p.x + dx
		var ez := p.y + dz
		var l := sqrt(ex * ex + ez * ez)
		var u := l - r
		if u > max_u and l > 1e-6:
			max_u = u; ax = ex / l; az = ez / l
	if max_u > 0.0:
		return {"hit": true, "v": Vector2(-ax * max_u, -az * max_u)}
	return {"hit": false, "v": Vector2.ZERO}


func _overlap(ha: PackedVector2Array, ax: float, az: float,
		hb: PackedVector2Array, bx: float, bz: float, gap: float) -> Dictionary:
	var axes := _edge_normals(ha)
	axes.append_array(_edge_normals(hb))
	var best := INF
	var best_axis := Vector2.ZERO
	var found := false
	for u: Vector2 in axes:
		var sa := _project(ha, ax, az, u)
		var db := _project(hb, bx, bz, u)
		var smin := sa.x - gap * 0.5
		var smax := sa.y + gap * 0.5
		var overlap := minf(smax - db.x, db.y - smin)
		if overlap <= 0.0:
			return {"hit": false, "v": Vector2.ZERO}   # a separating axis exists -> no overlap
		if overlap < best:
			best = overlap; best_axis = u; found = true
	if not found:
		return {"hit": false, "v": Vector2.ZERO}
	if best_axis.x * (bx - ax) + best_axis.y * (bz - az) < 0.0:
		best_axis = -best_axis
	return {"hit": true, "v": best_axis * best}


func _edge_normals(hull: PackedVector2Array) -> Array:
	var out: Array = []
	var n := hull.size()
	for i in range(n):
		var a := hull[i]
		var b := hull[(i + 1) % n]
		var dx := b.x - a.x
		var dz := b.y - a.y
		var l := sqrt(dx * dx + dz * dz)
		if l > 1e-8:
			out.append(Vector2(-dz / l, dx / l))
	return out


func _project(hull: PackedVector2Array, ox: float, oz: float, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in hull:
		var e := (p.x + ox) * axis.x + (p.y + oz) * axis.y
		lo = minf(lo, e)
		hi = maxf(hi, e)
	return Vector2(lo, hi)


# --------------------------------------------------------------- geometry
## 2D convex hull (ground plane) of a piece's mesh, rotated by its current
## orientation and centred on its origin. Reference VC().
func _hull2d(mesh: Mesh, q: Quaternion) -> PackedVector2Array:
	return MeshUtils.hull2d(mesh, q)


## World-space extent of a piece measured along `world_normal`. Reference pT().
func _piece_extent_along(piece: Area3D, world_normal: Vector3) -> float:
	var mesh: Mesh = piece.get_meta("mesh_ref")
	if mesh == null:
		return INF   # unmeasurable -> never reorient the camera for it
	var e := MeshUtils.extent_along(mesh, world_normal, piece.global_transform)
	return e.y - e.x


func _dir_from_normal(normal: Vector3) -> int:
	return Enums.ChopDirection.RIGHT if normal.x >= 0.0 else Enums.ChopDirection.LEFT


# ----------------------------------------------------------------- setup
## Spawn a fresh log. `reset_pile` = true clears the accumulated pile too (the R
## debug key); the auto-respawn after stacking keeps the pile so it grows.
func _spawn_fresh_log(reset_pile := true) -> void:
	_clear_grain_cue(&"piece_changed")
	# A brand new log is a brand new roll — the once-per-log latch belongs to
	# THIS log, never the one that just left the block.
	_grain_offered_this_log = false
	_grain_offer_count_this_log = 0
	for p in _on_block:
		if is_instance_valid(p):
			p.queue_free()
	_on_block.clear()
	for f in _firewood:
		if is_instance_valid(f):
			f.queue_free()
	_firewood.clear()
	_animator.clear()
	_pending = {}
	if reset_pile:
		_staged_log = {}
	_awaiting_stack = false
	_stacking = false

	if reset_pile:
		for c in _pile_root.get_children():
			c.queue_free()
		_pile.reset()
		# The pile is a view of the yard, not of the log on the block (see
		# _rebuild_pile_from_yard), so clearing it means rebuilding it — otherwise
		# an R-key reset would look like the yard had been robbed.
		_rebuild_pile_from_yard()

	# Select the next log's species — the species is what this log will yield,
	# and what its exposed end-grain looks like when it is cut.
	var species_index := _pick_species_index()
	var chosen := SpeciesTable.at(species_index)
	var using_cart: bool = (
		not _staged_log.is_empty()
		and chosen != null
		and _staged_log.get("species_id", &"") == chosen.id
	)
	if using_cart:
		_current_species = _staged_log.species
		_cut_mat = _staged_log.cut_mat
		_source_mesh = _staged_log.mesh
	else:
		_current_species = chosen
		_cut_mat = _cut_mat_for(species_index)
		_source_mesh = _apply_species_look(
			_center_mesh(_build_split_log(_pick_mesh(_current_species))), species_index)
	_staged_log = {}

	var half_h := _source_mesh.get_aabb().size.y * 0.5
	var rest_y := _stump_top_y + half_h
	var node := _make_stay_piece(_source_mesh, Vector3(0.0, rest_y, 0.0), 0.0, true)
	var landed := Callable(self, "_on_log_landed").bind(_source_mesh)
	if using_cart:
		var reduction := clampf(Shop.total_effect(UpgradeDef.Effect.DELIVERY_TIME), 0.0, 0.8)
		var duration := maxf(100.0, 300.0 * (1.0 - reduction))
		_animator.animate_drop(node, rest_y + drop_height, rest_y, landed, duration)
	else:
		_animator.animate_drop(node, rest_y + drop_height, rest_y, landed)
	_try_show_grain_cue(node)


func _on_log_landed(mesh: Mesh) -> void:
	_play_drop_sfx()
	_spawn_log_smoke(mesh)


## Build all smoke geometry/materials before the first log lands. Creating six
## procedural meshes, materials, nodes and RenderingServer resources inside the
## contact callback caused the visible landing hitch; the hot path below now
## only resets values in a six-slot animation pool on these native nodes.
func _build_smoke_pool() -> void:
	_smoke_root = Node3D.new()
	_smoke_root.name = "LogSpawnSmoke"
	add_child(_smoke_root)
	var shared_mesh := SphereMesh.new()
	shared_mesh.radius = 0.07
	shared_mesh.height = 0.14
	shared_mesh.radial_segments = 6
	shared_mesh.rings = 3
	for i in range(6):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.82, 0.78, 0.70, 1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var puff := MeshInstance3D.new()
		puff.name = "Puff%d" % i
		puff.mesh = shared_mesh
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible = false
		_smoke_root.add_child(puff)
		_smoke_puffs.append(puff)
		_smoke_age.append(-1.0)
		_smoke_duration.append(0.0)
		_smoke_start_pos.append(Vector3.ZERO)
		_smoke_end_pos.append(Vector3.ZERO)
		_smoke_start_scale.append(Vector3.ONE)
		_smoke_end_scale.append(Vector3.ONE)


## A small randomized low-poly dust/smoke ring at the block surface makes the
## in-place arrival feel grounded. All geometry/materials are reused from pool.
func _spawn_log_smoke(mesh: Mesh) -> void:
	if mesh == null or _smoke_root == null:
		return
	var footprint := mesh.get_aabb().size
	# Clear the log silhouette so at least the side puffs remain readable from
	# the fixed chopping camera, including when nearby equipment is installed.
	var radius := maxf(0.20, maxf(footprint.x, footprint.z) * 0.65)
	for i in range(6):
		# One puff per loose sector preserves a ring while keeping repeated log
		# arrivals from looking stamped out by a particle machine.
		var angle := TAU * (float(i) + randf_range(-0.32, 0.32)) / 6.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var radius_scale := randf_range(0.74, 1.12)
		var start_radius := radius * randf_range(0.82, 1.18)
		var duration := randf_range(0.27, 0.42)
		var puff := _smoke_puffs[i]
		# Keep the brief puff opaque. Alpha-blended particles disappeared against
		# the lit stump on Compatibility; these pale faceted chunks read clearly
		# and vanish through motion/scale instead of a transparency fade.
		var shade := randf_range(-0.055, 0.04)
		var material := puff.material_override as StandardMaterial3D
		material.albedo_color = Color(0.82 + shade, 0.78 + shade, 0.70 + shade, 1.0)
		puff.position = direction * start_radius + Vector3(0, _stump_top_y + randf_range(0.018, 0.042), 0)
		var start_scale := randf_range(0.50, 0.78) * radius_scale
		puff.scale = Vector3(start_scale, start_scale * randf_range(0.78, 1.20), start_scale)
		puff.visible = true
		var travel := randf_range(0.055, 0.12)
		var lift := randf_range(0.035, 0.085)
		var end_scale := randf_range(1.08, 1.52) * radius_scale
		_smoke_age[i] = 0.0
		_smoke_duration[i] = duration
		_smoke_start_pos[i] = puff.position
		_smoke_end_pos[i] = puff.position + direction * travel + Vector3.UP * lift
		_smoke_start_scale[i] = puff.scale
		_smoke_end_scale[i] = Vector3.ONE * end_scale


## Manual interpolation avoids constructing Tween/Tweener objects on the exact
## frame the log contacts the block. The six packed slots are allocated once.
func _update_log_smoke(delta: float) -> void:
	for i in range(_smoke_puffs.size()):
		if _smoke_age[i] < 0.0:
			continue
		_smoke_age[i] += delta
		var t := clampf(_smoke_age[i] / _smoke_duration[i], 0.0, 1.0)
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		var puff := _smoke_puffs[i]
		puff.position = _smoke_start_pos[i].lerp(_smoke_end_pos[i], eased)
		puff.scale = _smoke_start_scale[i].lerp(_smoke_end_scale[i], eased)
		if t >= 1.0:
			puff.visible = false
			_smoke_age[i] = -1.0


## Prepare one mesh while the completed log is already waiting/stacking. It is
## not placed, counted, paid or interactable until _spawn_fresh_log consumes it.
func _stage_next_log() -> void:
	if Shop.get_level(GameState.UPGRADE_HANDCART) <= 0 or not _staged_log.is_empty():
		return
	var species_index := _pick_species_index()
	var species := SpeciesTable.at(species_index)
	if species == null:
		return
	var mat := _cut_mat_for(species_index)
	var mesh := _apply_species_look(
		_center_mesh(_build_split_log(_pick_mesh(species))), species_index)
	_staged_log = {
		"species_id": species.id,
		"species": species,
		"cut_mat": mat,
		"mesh": mesh,
	}


func _build_stump() -> void:
	var raw := _load_stump_mesh()
	var aabb := raw.get_aabb()
	var s := stump_scale
	var scaled := _scaled_mesh(raw, s)
	var mi := MeshInstance3D.new()
	mi.name = "StumpMesh"
	mi.mesh = scaled
	var cx := (aabb.position.x + aabb.size.x * 0.5) * s
	var cz := (aabb.position.z + aabb.size.z * 0.5) * s
	mi.position = Vector3(-cx, -aabb.position.y * s, -cz)
	add_child(mi)

	_stump_top_y = aabb.size.y * s
	_stump_radius = maxf(aabb.size.x, aabb.size.z) * 0.5 * s

	var body := StaticBody3D.new()
	body.name = "StumpBody"
	body.physics_material_override = _phys_mat
	var cs := CollisionShape3D.new()
	cs.name = "StumpCollision"
	var cyl := CylinderShape3D.new()
	cyl.radius = _stump_radius
	cyl.height = _stump_top_y
	cs.shape = cyl
	cs.position = Vector3(0, _stump_top_y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func current_work_radius() -> float:
	return _stump_radius * (1.0 + Shop.total_effect(UpgradeDef.Effect.WORK_RADIUS))


func _refresh_equipment_effects() -> void:
	var cs: CollisionShape3D = get_node_or_null("StumpBody/StumpCollision")
	if cs != null and cs.shape is CylinderShape3D:
		(cs.shape as CylinderShape3D).radius = current_work_radius()


# ------------------------------------------------------------------- axe
## The rig is AUTHORED IN THE SCENE now, under the camera, so all this does is find
## it and subscribe to the frame the blade bites. Built in code it could not be
## keyframed, which is the whole point of the 2026-08-02 rebuild.
##
## A missing anchor is a WARNING, not an error: the mini-game still plays (the
## strike falls back to `anticipation_sec`), because a scene stripped down for a
## test should not have to carry a viewmodel to chop wood.
func _build_axe() -> void:
	_axe = _camera.get_node_or_null("AxeViewmodelAnchor") as AxeViewmodel
	if _axe == null:
		push_warning("chopping_minigame: no AxeViewmodelAnchor under the camera — "
			+ "swinging invisibly, strikes resolve on anticipation_sec.")
		return
	_axe.contact.connect(_on_axe_contact)


## Swing the axe at `world_point`. `screen_pos` is where the player clicked, and is
## only used to lean the rig that way — the motion itself is the authored animation
## and does not chase the impact point around. Defaults let dev tools call
## _swing_axe() with no args.
func _swing_axe(world_point := Vector3(0.0, _stump_top_y, 0.0), _normal := Vector3.RIGHT,
		screen_pos := Vector2(-1.0, -1.0)) -> void:
	if _axe == null:
		return
	# The upgrade speeds up the SWING, not a dead wait after it. `swing_cooldown` is
	# the authored rate and current_swing_cooldown() is what the skill tree has
	# bought it down to, so the ratio is exactly what the player paid for.
	var base := maxf(current_swing_cooldown(), 0.001)
	_axe.set_speed(clampf(swing_cooldown / base, 0.25, 4.0))
	_axe.swing(_aim_from_screen(screen_pos, world_point))


## Where to lean the swing, as -1..1 from the centre of the frame. Prefers the
## actual click; falls back to projecting the impact point, so a dev tool or a
## headless caller that has no mouse position still aims at the wood.
func _aim_from_screen(screen_pos: Vector2, world_point: Vector3) -> Vector2:
	var rect := get_viewport().get_visible_rect().size
	var p := screen_pos
	if p.x < 0.0 or p.y < 0.0:
		if _camera == null or _camera.is_position_behind(world_point):
			return Vector2.ZERO
		p = _camera.unproject_position(world_point)
	if rect.x <= 0.0 or rect.y <= 0.0:
		return Vector2.ZERO
	# y is flipped: screen y grows downward, aim y is up-positive like the camera's.
	return Vector2(p.x / rect.x * 2.0 - 1.0, 1.0 - p.y / rect.y * 2.0)


## The animation reached the frame the blade bites. THIS is when the wood breaks.
func _on_axe_contact() -> void:
	_resolve_pending()


## Resolve whatever strike is in flight, exactly once. Clears `_pending` FIRST so
## the failsafe in _process and the contact key can never both spend the same
## strike, whichever of them gets there.
func _resolve_pending() -> void:
	if _pending.is_empty():
		return
	var pd := _pending
	_pending = {}
	if is_instance_valid(pd.piece) and pd.piece in _on_block:
		var split := _resolve_strike(
			pd.piece, pd.world_point, pd.normal, pd.dir, pd.get("grain_plane", null))
		if not split and _axe != null:
			_axe.bounce()


## How long a strike may stay in flight before the failsafe spends it. Comfortably
## past the animation's own contact key, so a swing that is merely slow (hit-pause,
## a frame spike) is never cut short.
func _strike_timeout() -> float:
	if _axe == null:
		return anticipation_sec
	var t := _axe.contact_time()
	if t < 0.0:
		# No contact key in the animation at all. Fall back to the swing's length so
		# the wood at least breaks somewhere inside the motion rather than instantly.
		return maxf(_axe.swing_duration(), anticipation_sec)
	return t * strike_timeout_slack


# --------------------------------------------------------------- audio
func _play_drop_sfx() -> void:
	_play_sfx(drop_sfx)


func _play_sfx(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()


# --------------------------------------------------------------- materials
func _make_planar(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## The cut-face material for a species, built once and cached.
##
## Cached rather than rebuilt per log for a reason beyond speed: MeshUtils.jag_cut
## identifies which surface of a freshly sliced piece is the CUT one by comparing
## `material == _cut_mat` by reference. Handing out a fresh instance per log would
## leave any piece cut before the swap unroughenable.
func _cut_mat_for(species_index: int) -> StandardMaterial3D:
	if _cut_mats.has(species_index):
		return _cut_mats[species_index]
	var row := SpeciesTable.at(species_index)
	# Paths, not preloaded Textures, so a row reads the same way as its "mesh".
	var albedo := _tex_or("" if row == null else row.inside_tex, _TEX_INSIDE)
	var normal := _tex_or("" if row == null else row.inside_normal, _TEX_INSIDE_N)
	var mat := _make_planar(albedo)
	mat.normal_enabled = true
	mat.normal_texture = normal
	mat.normal_scale = 1.0
	mat.albedo_color = Color.WHITE if row == null else row.inside_tint
	_cut_mats[species_index] = mat
	return mat


## Dress a log in its species' own skin.
##
## THE GEOMETRY IS SHARED AND THE SKIN IS NOT (Creative Director call,
## 2026-08-02). Sam named 25 woods and there are two authored log SHAPES sets
## (oak and birch), so most species stand on the oak FBXs — but a species with
## its own painted textures is bound to them here and stops looking like oak at
## all. Two ways in, in order of preference:
##
##   1. `bark_tex` / `top_tex` — the species' OWN painted skin. This is the real
##      answer and it is where every row should end up.
##   2. `bark_tint` — a colour multiplied over whatever art the log already
##      wears. The stand-in for a wood Sam has not painted yet: identical logs
##      would make the wood selector meaningless, since the player picks a wood
##      and the block has to look like it changed.
##
## A species using neither is left completely alone, which is what oak and birch
## want — they ARE the imported art.
##
## THE MATERIAL MUST BE DUPLICATED, and this is the trap worth naming: an
## imported FBX's materials are shared by REFERENCE — MeshUtils.transformed_by
## carries `surface_get_material` straight across, and mesh_from_path re-reads
## the same imported resource every time. Writing to one would not dress this
## log; it would repaint that FBX's material for the whole process, so every
## species sharing the art would drift to whichever wood was loaded last, and the
## change would outlive the log. Duplicates are cached per (species, source
## material) for the same reason `_cut_mat_for` caches: a fresh instance per log
## would be a fresh material per log for the renderer to track.
##
## Safe against the `jag_cut` reference test, which finds a cut face by comparing
## `material == _cut_mat`: neither slot here is ever the cut material.
func _apply_species_look(mesh: ArrayMesh, species_index: int) -> ArrayMesh:
	var row := SpeciesTable.at(species_index)
	if row == null:
		return mesh
	var tinted := row.bark_tint != Color.WHITE
	if not tinted and row.bark_tex.is_empty() and row.top_tex.is_empty():
		return mesh                       # this species already IS the imported art

	for si in range(mesh.get_surface_count()):
		var src := mesh.surface_get_material(si)
		if src == null:
			continue
		var key := "%d|%d" % [species_index, src.get_instance_id()]
		if not _bark_mats.has(key):
			var dup := src.duplicate() as BaseMaterial3D
			if dup == null:
				continue                  # a non-BaseMaterial3D (a shader) — leave it be

			# WHICH SLOT IS THIS? Every log FBX in the project carries exactly two
			# material slots named `oak_bark` and `oak_top` (verified with
			# core/tools/inspect_materials.gd), so the name is what tells the side
			# of the log from its authored end. Falling back to surface order
			# rather than skipping keeps a future FBX with different slot names
			# looking like SOMETHING, and says so out loud.
			var slot := _slot_name(src)
			var is_top := slot.contains("top") if not slot.is_empty() else si == 1
			if slot.is_empty():
				push_warning("chopping_minigame: log material %d has no name; assuming %s by surface order."
					% [si, "end" if is_top else "bark"])

			var tex_path: String = row.top_tex if is_top else row.bark_tex
			var normal_path: String = row.top_normal if is_top else row.bark_normal
			if not tex_path.is_empty():
				var tex: Texture2D = load(tex_path) as Texture2D
				if tex == null:
					push_warning("chopping_minigame: %s texture '%s' did not load; keeping the imported one."
						% [row.id, tex_path])
				else:
					dup.albedo_texture = tex
					# The species brought its own albedo, so the imported wood's
					# normal map no longer describes this surface — see the note on
					# SpeciesDef.bark_normal for why clearing beats inheriting.
					var nrm: Texture2D = load(normal_path) as Texture2D if not normal_path.is_empty() else null
					dup.normal_enabled = nrm != null
					dup.normal_texture = nrm

					# AND THE OAK MATERIAL'S SHADING COMES OFF WITH IT. `oak_bark`
					# and `oak_top` both carry `vertex_color_use_as_albedo` plus a
					# 0.906 grey, so the log's baked vertex-colour shading and that
					# grey multiply over whatever albedo is bound. Oak's own texture
					# was painted to sit under them; Sam's species textures are
					# painted with their own light and crevice shadow already in
					# them, so inheriting both multiplied a second set of shadows on
					# top and Eastern White Pine came out nearly black. A species
					# that paints its own skin gets that skin rendered as painted.
					dup.vertex_color_use_as_albedo = false
					dup.albedo_color = Color.WHITE

					# Bark only: the end is one painted disc the UVs already fit.
					if not is_top and row.bark_uv_scale != 1.0:
						dup.uv1_scale = Vector3(row.bark_uv_scale, row.bark_uv_scale, 1.0)

			# The stand-in tint applies ONLY to slots this species did not paint.
			# That matters while an art drop is half-finished: Balsam Fir arrived
			# with bark and no end grain, and tinting its real bark to match the
			# oak end it is still borrowing would be repainting the good art to
			# match the placeholder. MULTIPLY, never assign — a tint is a filter
			# over whatever art is there.
			if tinted and tex_path.is_empty():
				dup.albedo_color = dup.albedo_color * row.bark_tint
			_bark_mats[key] = dup
		mesh.surface_set_material(si, _bark_mats[key])
	return mesh


## The imported material's own name (`oak_bark` / `oak_top`), lowercased. Godot
## binds an EXTERNAL .tres beside the FBX when the names match, so the useful name
## can live on either the resource or its file — check both.
func _slot_name(mat: Material) -> String:
	if not mat.resource_name.is_empty():
		return mat.resource_name.to_lower()
	return mat.resource_path.get_file().get_basename().to_lower()


## Load a texture path, falling back to `fallback` when the row omits it or the
## path does not resolve (a typo must not leave a piece with an untextured cut).
func _tex_or(path: String, fallback: Texture2D) -> Texture2D:
	if path.is_empty():
		return fallback
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("chopping_minigame: inside texture '%s' did not load; using the default." % path)
		return fallback
	return tex


func _build_split_log(variant_path := "") -> ArrayMesh:
	var mesh := _load_log_mesh(variant_path)
	return _scaled_mesh(mesh, _fit_scale(mesh))


## Scale factor that brings ANY authored log mesh to `log_height`.
##
## This used to be a bare `log_scale` multiplier (13.0), which only meant
## anything against the raw units the FBX happened to be modelled in — log_01
## imports at 0.032 m tall, so 13x gave the ~0.42 m round the block, the cut
## thresholds and the pile spacing are all sized for. Then MeshUtils.mesh_from_
## scene started BAKING the transform authored on the FBX's MeshInstance3D
## (2026-07-27, for tree_02's 180x node scale) — and these logs carry ~33.9x
## (log_01) and ~31.6x (log_02) of their own. The same 13.0 then produced a
## 14 m log standing on the block with the camera inside it: no log appeared to
## spawn at all, and nothing errored.
##
## Deriving the scale from the mesh's own measured height cannot drift that way
## again, whatever an artist exports at, and it sizes both species alike.
func _fit_scale(mesh: Mesh) -> float:
	var h := mesh.get_aabb().size.y
	if h <= 0.0001:
		push_warning("chopping_minigame: log mesh has no height; leaving it unscaled")
		return 1.0
	return log_height / h


# --------------------------------------------------------------- helpers
func _plane_to_local(world_plane: Plane, xform: Transform3D) -> Plane:
	return MeshUtils.plane_to_local(world_plane, xform)


## Bias the cut so neither resulting piece is a flat slab. The cut plane is pushed
## in from the clicked edge until the thinner side's width (along the cut normal)
## is at least `width_depth_ratio` of the piece's depth (its extent perpendicular
## to the cut). If the piece is too small to split that squarely, this falls back
## to a centre cut (even halves) — the same trick the reference uses to keep
## firewood chunks roughly square rather than thin planks. `width_depth_ratio` = 0
## disables it (cuts land exactly where clicked).
func _square_bias(mesh: Mesh, xform: Transform3D, world_plane: Plane) -> Plane:
	if width_depth_ratio <= 0.0:
		return world_plane
	var n := world_plane.normal
	var cross := Vector3(-n.z, 0.0, n.x)      # perpendicular horizontal axis (the "depth" direction)
	if cross.length() < 0.0001:
		return world_plane
	cross = cross.normalized()
	var n_lo := INF
	var n_hi := -INF
	var c_lo := INF
	var c_hi := -INF
	for si in range(mesh.get_surface_count()):
		var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for p in v:
			var w := xform * p
			var dn := w.dot(n)
			var dc := w.dot(cross)
			n_lo = minf(n_lo, dn); n_hi = maxf(n_hi, dn)
			c_lo = minf(c_lo, dc); c_hi = maxf(c_hi, dc)
	var width := n_hi - n_lo
	var depth := c_hi - c_lo
	var min_w := maxf(min_piece_size, depth * width_depth_ratio)
	min_w = minf(min_w, width * 0.5)          # too small to split squarely -> centre cut
	var o := clampf(world_plane.d, n_lo + min_w, n_hi - min_w)
	return Plane(n, o)


## Roughen a fresh cut face. Every vertex lying ON the cut plane is pushed along
## the normal by value noise, so the flat cut becomes cloven wood. The cap face and
## the side-wall rim share exact vertex positions and get the SAME displacement, so
## no cracks open between them. The cut surface (material == _cut_mat) is rebuilt as
## a soup with fresh flat normals so the bumps actually shade; the bark/end surfaces
## keep their normals (only their rim vertices nudge).
func _jag_cut(mesh: ArrayMesh, plane: Plane) -> ArrayMesh:
	_cut_noise.frequency = cut_jag_freq
	return MeshUtils.jag_cut(mesh, plane, _cut_mat, cut_jag_amount, _cut_noise)


func _sliver_guard(mesh: Mesh, local_plane: Plane) -> Plane:
	var aabb := mesh.get_aabb()
	var n := local_plane.normal
	var lo := INF
	var hi := -INF
	for cx in [aabb.position.x, aabb.position.x + aabb.size.x]:
		for cy in [aabb.position.y, aabb.position.y + aabb.size.y]:
			for cz in [aabb.position.z, aabb.position.z + aabb.size.z]:
				var d := n.dot(Vector3(cx, cy, cz))
				lo = minf(lo, d)
				hi = maxf(hi, d)
	var o := local_plane.d
	if hi - o < min_piece_size:
		o = hi - min_piece_size
	elif o - lo < min_piece_size:
		o = lo + min_piece_size
	return Plane(n, o)


func _center_mesh(src: Mesh) -> ArrayMesh:
	return MeshUtils.centered(src)


func _scaled_mesh(src: Mesh, s: float) -> ArrayMesh:
	return MeshUtils.scaled(src, s)


func _translate_mesh(src: Mesh, offset: Vector3) -> ArrayMesh:
	return MeshUtils.translated(src, offset)


## Which species the next log will be.
##
## THE PLAYER CHOOSES THIS (Creative Director call, 2026-08-02 — the wood on the
## block is picked in the yard, not rolled). It used to be `randi() % size`, which
## by 2026-08-02 would have handed out Lignum Vitae — the last wood on the ladder
## — on the player's very first log, for free, at 2600 a piece.
##
## GameState owns the choice, and its getter already resolves a save that predates
## the selector, a deleted species or a choice a retuned ladder put back out of
## reach, so there is nothing to validate here. `debug_forced_species` still wins,
## so M4's suite and every shot tool drive an exact wood without touching
## progression.
func _pick_species_index() -> int:
	if debug_forced_species >= 0 and debug_forced_species < SpeciesTable.count():
		return debug_forced_species
	var index := SpeciesTable.index_of(GameState.get_selected_species())
	return index if index >= 0 else 0


## Which authored log SHAPE of that species turns up. Picked separately from the
## species so log variety never changes how often a wood appears.
func _pick_mesh(species: SpeciesDef) -> String:
	if species == null or species.meshes.is_empty():
		push_error("chopping_minigame: species '%s' lists no meshes." % ("?" if species == null else species.id))
		return ""
	if debug_forced_mesh >= 0 and debug_forced_mesh < species.meshes.size():
		return species.meshes[debug_forced_mesh]
	return species.meshes[randi() % species.meshes.size()]


func _load_log_mesh(variant_path := "") -> Mesh:
	if variant_path.is_empty():
		variant_path = _pick_mesh(SpeciesTable.at(_pick_species_index()))
	return MeshUtils.mesh_from_path(variant_path)


func _load_stump_mesh() -> Mesh:
	return MeshUtils.mesh_from_scene(_STUMP_FBX)


# ------------------------------------------------------- test/shot seams
func piece_count() -> int:
	return _on_block.size() + _firewood.size()


func cuttable_count() -> int:
	return _on_block.size()
