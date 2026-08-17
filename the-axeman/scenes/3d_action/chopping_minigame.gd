
extends Node3D
## Active block owner for `chopping_minigame.tscn` and its standalone harness.
## On-block descendants use scripted pop/tilt motion; completed firewood uses
## physics, validates inventory settlement, then becomes collisionless and sinks.
## The axe contact key owns each runtime plane slice, while GameFeel owns hit
## pause and camera shake. Exported feel values remain provisional.

const _PieceAnimator := preload("res://scenes/3d_action/piece_animator.gd")
const _LevelUpBurst := preload("res://scenes/3d_action/level_up_burst.gd")
const _CoinRewardPool := preload("res://scenes/3d_action/coin_reward_pool.gd")
const _PainterlyVFXDaub := preload("res://assets/shaders/painterly_vfx_daub.gdshader")
const _PainterlyVFXStyle := preload("res://data/painterly_vfx_style_placeholder.tres")
const _SURVIVAL_TUNING := preload("res://data/survival_run_tuning_placeholder.tres")

## Local instrumentation seams used by acceptance and review tools.
signal strike_resolved(did_split: bool)
signal log_completed(species_id: StringName, piece_count: int)
signal block_ready_for_log
## RunDirector resumes boundary countdowns once the next workpiece is genuinely
## ready. Collisionless farewell pieces may still be fading around it.
signal run_log_ready
## Presentation receipts only. XP is already authoritative in RunDirector; these
## let the HUD visually hold and release that value as the receipt orbs arrive.
signal xp_orb_batch_started(amount: int)
signal xp_orb_collected(amount: int, tier: int)
## Cash presentation mirrors the XP receipt flow: the economy settles first,
## then one exact payout is released visually when its pooled coin hits the HUD.
signal coin_batch_started(count: int)
signal coin_collected(amount: int, tier: int)
signal coins_cancelled(count: int)
signal coin_batch_finished

# Species identity comes from `SpeciesTable`; shape selection happens after
# identity so mesh variety never changes species probability.

# --- infrastructure (unchanged geometry/material setup) -------------------
@export var log_height := 0.42            # finished height of a log standing on the block (m)
@export var stump_scale := 0.376         # scales chopping_stump_a so its top sits at the log rest height (~0.5m)
@export var camera_step_deg := 30.0
@export var orbit_time := 0.25
@export_group("XP orbs")
## OFF in tests that count frames rather than watch them; on everywhere else.
@export var orbs_enabled := true
## Shared bounded logarithmic curve. Routine, proc and grain awards all use this
## one source so their exact final XP is visible on the same scale.
@export var xp_pacing_config: XPPacingConfig
## Tiny ON PURPOSE: the burst is ONE event ("all the collecting happens at once"),
## and this exists only so the orbs do not leave on a single identical frame.
@export var orb_stagger := 0.012     # seconds between orbs leaving the block
## Age at which the whole handful lifts off the ground for the player, shared by
## every orb in the burst — the beat they spend lying in the dirt. PLACEHOLDER.
@export var orb_collect_at := 0.85
@export var orb_scatter_radius := 0.32   # smallest ring the burst lands in; widened to clear the stump
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
@export var firewood_toward_cam := 1.0   # bias toward the viewer so finished pieces land in view (m/s)
@export var firewood_tumble := 3.0       # random spin (rad/s)
@export var max_firewood := 40           # hard cap; oldest freed first
@export var firewood_settle_speed := 0.05 # firewood counts as "settled" below this speed (m/s)
@export var firewood_settle_timeout := 1.5  # force-settle after this long even if still drifting (s)
@export var min_firewood_settle_timeout := 0.55 # PLACEHOLDER authored floor

# --- completed-piece rewards ---------------------------------------------
@export_group("Completed piece rewards")
## Reward particles land at the yard floor. This is presentation geometry, not
## a persistent stockpile location.
@export var reward_ground_y := 0.0
## OFF for suites and presentation tools that exercise only the standalone
## gather contract. Production settles each completed piece's prepared cash
## share as soon as its physics handoff completes.
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
@export var scar_width := 0.025         # PLACEHOLDER selected single-hit axe-bite width (m)
@export_range(0.0, 1.0) var scar_length_frac := 0.8   # visible gouge length across the piece's top
@export var scar_lift := 0.004          # receiver lift above the copied top face, avoiding z-fight (m)
@export var scar_colour := Color(0.72, 0.42, 0.12, 1.0)   # PLACEHOLDER fresh torn-fibre midtone
@export var scar_shadow_colour := Color(0.30, 0.12, 0.035, 1.0) # PLACEHOLDER warm recessed wood, not black
@export var scar_highlight_colour := Color(1.0, 0.78, 0.32, 1.0) # PLACEHOLDER lifted fibre edge
@export_range(0.0, 1.0) var scar_opacity := 0.82      # PLACEHOLDER pending single-hit feel test
@export_range(0.0, 4.0) var scar_normal_strength := 3.5 # PLACEHOLDER pending single-hit feel test
@export var debug_split_roll := -1      # -1 = roll for real; 0 = always fail; 1 = always split (tests only)

# --- run-power test seams -------------------------------------------------
@export_group("Run power tests")
@export var debug_force_proc := -1      # -1 = roll for real; 0 = never; 1 = always (tests only)
## Forces the Grain Reader offer roll (does a fresh piece get a gold mark), same
## shape as debug_force_proc. Independent of debug_split_roll/debug_force_proc,
## which govern what happens once a piece already has (or doesn't have) a mark.
@export var debug_force_grain := -1     # -1 = roll for real; 0 = never; 1 = always (tests only)

# --- swing cooldown (what the coffee buys) --------------------------------
## Creative Director call, 2026-08-01: coffee is "5% faster time between swings",
## and Sam chose a REAL cooldown for it to cut into — before this the game had
## none at all and a swing was gated only by the anticipation window.
@export_group("Swing rate")
@export var swing_cooldown := 0.45      # Creative Director call, 2026-08-01
## Hard floor for run-power speed so the axe never loses its authored weight.
## PLACEHOLDER pending the measured tuning session.
@export var min_swing_cooldown := 0.25

# --- audio (hooks; drop a stream in to hear it) ---------------------------
@export_group("Audio")
@export var drop_sfx: AudioStream        # ref: drop.mp3 on log landing
@export var split_sfx: AudioStream       # ref: split sound on each chop
@export var thud_sfx: AudioStream        # a swing that bit but did not split

const _TEX_INSIDE := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_diffColor.jpg")
const _TEX_INSIDE_N := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_normals.jpg")
const _LOG_BARK_SHADER := preload("res://assets/shaders/log_bark_triplanar.gdshader")
const _LOG_END_SHADER := preload("res://assets/shaders/log_end_cap.gdshader")
const _SCAR_NORMAL := preload("res://assets/generated/chopping/axe_scar_normal.png")
const _SCAR_SHADER := preload("res://assets/shaders/axe_scar_projection.gdshader")
const _STUMP_FBX := preload("res://assets/models/chopping_stump_a/chopping_stump_a.fbx")
const _RUN_VFX_CONFIG := preload("res://data/run_vfx_config_placeholder.tres")

## The generated map keeps neutral-normal padding around its damage. These are
## asset-layout facts, not feel tuning: the exports above still describe the
## visible scar, while its receiver expands enough to hold that padding.
const _SCAR_VISIBLE_WIDTH_FRAC := 0.14 # measured relief span in the generated map
const _SCAR_VISIBLE_LENGTH_FRAC := 0.72
const _SCAR_TOP_NORMAL_MIN_DOT := 0.55

const _PICK_LAYER := 1 << 1              # on-block pieces sit on this layer for ray-picking only

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _fallers: Node3D = $Fallers

var _animator := _PieceAnimator.new()
var _pieces_root: Node3D                  # identity-transform parent so piece.position == world
var _finished_firewood_root: Node3D       # inert opaque pieces waiting to sink
var _on_block: Array = []                 # Array[Area3D] — script-animated pieces on the block
var _firewood: Array = []                 # Array[RigidBody3D] — the only physics pieces
## Entries hold one frozen RigidBody3D, every visible GeometryInstance3D under
## it (including projected scars), and age measured in active gameplay seconds.
var _finished_firewood: Array[Dictionary] = []
var _pending: Dictionary = {}             # strike in flight, waiting for the axe's contact key
var _cooldown_left := 0.0                 # seconds until the axe can swing again (what coffee shortens)
var _awaiting_finished_settlement := false # log done; waiting for its firewood to settle
var _finished_batch_age := 0.0            # active-play seconds since this log's final chop
## `get_instance_id()` is unique only inside one Godot process. Manual receipt
## ids are persisted, so a relaunched scene needs a process-external nonce or its
## first logs can collide with saved ids and be mistaken for duplicate rewards.
var _manual_log_session_nonce := int(Time.get_unix_time_from_system() * 1_000_000.0)
var _manual_log_serial := 0
var _current_manual_log_root_id: StringName = &""
var _handled_log_roots: Dictionary = {}
var _hold_chop_active := false
var _hold_screen_pos := Vector2.ZERO
## Claimed loose roots use an explicit, generation-checked presentation handoff.
## The authoritative on-block geometry stays hidden until the visual snapshot has
## lifted, repositioned fully off-screen, and landed on the stump.
var _run_handoff_tween: Tween
var _run_handoff_visual: Node3D
var _run_handoff_piece: Area3D
var _run_handoff_target := Vector3.ZERO
var _run_handoff_mesh: Mesh
var _run_handoff_generation := 0
var _run_handoff_active := false
var _boss_stack_active := false
var _boss_stack_visual_root: Node3D
var _boss_stack_visuals: Dictionary = {}
var _boss_stack_centers: Dictionary = {}
var _boss_stack_drop_tween: Tween
var _camera_base_transform := Transform3D.IDENTITY
var _camera_base_fov := 75.0
var _pivot_base_position := Vector3.ZERO
var _boss_camera_tween: Tween
var _boss_camera_target_y := 0.0
var _chopping_visibility_occluder_count := 0
var _chopping_visibility_hidden_geometry_count := 0

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
var _grain_dark_mat: ShaderMaterial = null
var _grain_glow_mat: ShaderMaterial = null
var _grain_core_mat: ShaderMaterial = null
## Once-per-log latch: a mark is decided at most once per log, win or lose the
## roll, so it never relocates onto a "better" candidate and never stacks a
## second one after the first is taken. Fresh standalone and run descriptors
## reset it through their respective staging paths.
var _grain_offered_this_log := false
var _grain_offer_count_this_log := 0     # debug seam: how many marks actually landed this log
var _last_grain_bonus := 0               # debug seam: XP paid by the most recent gold cut
var _grain_offer_source: StringName = &""
var _restoring_run_log := false

var _source_mesh: Mesh
var _yaw_steps := 0
var _orbit_tween: Tween
var _axe: AxeViewmodel                    # the camera-mounted rig; null only in a scene without one
var _audio: AudioStreamPlayer3D
var _cut_mat: StandardMaterial3D          # cut-face material of the log CURRENTLY on the block
var _cut_mats: Dictionary = {}            # species index -> StandardMaterial3D (built once, reused)
var _bark_mats: Dictionary = {}           # "species index|source material id" -> procedural exterior material
## Whole delivered roots are immutable until a slicer creates new descendants.
## Cache the finite species/variant set so a 50-roots/s wave does not repeatedly
## load, transform, upload, and redress identical imported geometry.
var _run_log_mesh_cache: Dictionary = {}
var _scar_projection_mat: ShaderMaterial  # generated normal-map material shared by persistent scars
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
var _run_director: RunDirector
var _external_log_flow := false
var _current_descriptor: LogDescriptor
var _cut_journal: Array[Dictionary] = []
var _xp_screen_target := Callable()
var _level_up_vfx_queued := false
var _level_up_vfx
var _coin_reward_pool
var _xp_orb_pool_root: Node3D
var _xp_orb_pool: Array[XPOrb] = []
var _queued_xp_bursts: Array[Dictionary] = []
var _render_warmup_nodes: Array[Node] = []
var _splinter_projectile_mesh: BoxMesh
var _grain_cue_config: GrainCueDef
## Disposable run-power presentation/runtime seams. Authoritative ranks, RNG,
## timers, charges, and stacks remain in RunDirector; this scene only applies
## power cuts to the real on-block geometry and renders the orbiting tool state.
var _pending_descriptor_power_cuts := 0
var _pending_descriptor_power_cut_sources: Array[StringName] = []
var _power_cut_context: StringName = &""
var _last_run_power_cuts: Dictionary = {}
var _run_power_orbit_root: Node3D
var _run_power_orbit_axes: Array[Node3D] = []
var _run_power_orbit_angle := 0.0


func _ready() -> void:
	if xp_pacing_config == null:
		xp_pacing_config = GameConfig.current().xp_pacing
	_grain_cue_config = GameConfig.current().grain_cue
	_camera_base_transform = _camera.transform
	_camera_base_fov = _camera.fov
	_pivot_base_position = _pivot.position
	_boss_camera_target_y = _pivot_base_position.y
	GameFeel.register_camera(_camera)
	AudioDirector.register_world_root(self)
	# A cut material must exist before anything can slice; _spawn_fresh_log swaps
	# in the one belonging to whichever species it puts on the block.
	_cut_mat = _cut_mat_for(0)
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 0.9
	_phys_mat.bounce = 0.0

	_pieces_root = Node3D.new()
	_pieces_root.name = "OnBlock"
	add_child(_pieces_root)

	_finished_firewood_root = Node3D.new()
	_finished_firewood_root.name = "FinishedFirewood"
	add_child(_finished_firewood_root)

	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)

	# _source_mesh is deliberately NOT built here: _spawn_fresh_log() below sets it
	# from the species it actually puts on the block, so building one up front only
	# loaded and scaled an FBX for a random species that was thrown away.
	_build_stump()
	_build_smoke_pool()
	_prewarm_vfx_geometry()
	$Floor.physics_material_override = _phys_mat
	_build_axe()
	_spawn_fresh_log()


## Main binds this to the HUD's live progress-edge position. Harnesses and
## headless scenes leave it empty and retain the camera-centre fallback.
func set_xp_screen_target(provider: Callable) -> void:
	_xp_screen_target = provider


func set_coin_screen_target(provider: Callable) -> void:
	if _coin_reward_pool != null:
		_coin_reward_pool.set_screen_target(provider)


## RunDirector binds after this child has entered the tree. The original local
## spawn remains for standalone feel harnesses; production clears it and stages
## only descriptors claimed by the run.
func bind_run_director(run: RunDirector) -> void:
	_run_director = run
	_external_log_flow = run != null
	if _external_log_flow:
		clear_run_log()
	refresh_run_power_visuals()


func clear_run_log(clear_finished := true) -> void:
	_cancel_run_log_handoff()
	_clear_boss_stack_presentation(true)
	_clear_grain_cue(&"run_reset")
	if not GameState.has_meta_capability(
			MetaUpgradeDef.Capability.CONTINUOUS_HANDOFF):
		_hold_chop_active = false
	for piece: Area3D in _on_block:
		if is_instance_valid(piece):
			piece.queue_free()
	_on_block.clear()
	for body: RigidBody3D in _firewood:
		if is_instance_valid(body):
			body.queue_free()
	_firewood.clear()
	if clear_finished:
		_clear_finished_firewood()
	_animator.clear()
	_pending.clear()
	_awaiting_finished_settlement = false
	_finished_batch_age = 0.0
	_current_descriptor = null
	_current_species = null
	_cut_journal.clear()
	_pending_descriptor_power_cuts = 0
	_pending_descriptor_power_cut_sources.clear()
	_power_cut_context = &""


func build_run_log_mesh(descriptor: LogDescriptor) -> Mesh:
	if descriptor == null:
		return null
	var species_index := SpeciesTable.index_of(descriptor.species_id)
	var species := SpeciesTable.at(species_index)
	if species == null or species.meshes.is_empty():
		return null
	var mesh_index := clampi(descriptor.mesh_index, 0, species.meshes.size() - 1)
	var key := "%d|%d" % [species_index, mesh_index]
	var cached := _run_log_mesh_cache.get(key) as Mesh
	if cached != null:
		return cached
	var mesh := _apply_species_look(
		_center_mesh(_build_split_log(species.meshes[mesh_index])), species_index)
	_run_log_mesh_cache[key] = mesh
	return mesh


## Arena powers use the exact block slicer, material, rough-cut, sliver and
## firewood rules. The plane normal is LOG-LOCAL X or Z. A loose root may have
## rolled onto any face, but its physics pose must never rotate the cut through
## its authored top/bottom axis and create a diagonal piece. Building the plane
## in canonical mesh space makes the resulting wood identical to an upright
## root receiving the same centred cut on the block.
func slice_loose_run_piece(descriptor: LogDescriptor, mesh: Mesh,
		_piece_global_transform: Transform3D, local_axis: Vector3,
		_cut_serial: int) -> Dictionary:
	if descriptor == null or mesh == null:
		return {}
	var axis := Vector3(local_axis.x, 0.0, local_axis.z).normalized()
	if axis.length_squared() <= 0.0001:
		return {}
	# All run meshes and every descendant are recentered after slicing. Applying
	# the block's footprint bias in this identity frame therefore reproduces the
	# upright on-block result without allowing world rotation into the geometry.
	var local_plane := _square_bias(mesh, Transform3D.IDENTITY,
		Plane(axis, 0.0))
	local_plane = _sliver_guard(mesh, local_plane)
	var species_index := SpeciesTable.index_of(descriptor.species_id)
	var cut_material := _cut_mat_for(species_index)
	var result := MeshSlicer.slice(mesh, local_plane, cut_material)
	if result.above == null or result.below == null:
		return {}
	var noise := FastNoiseLite.new()
	noise.seed = descriptor.visual_seed
	noise.frequency = cut_jag_freq
	result.above = MeshUtils.jag_cut(result.above, local_plane, cut_material,
		cut_jag_amount, noise)
	result.below = MeshUtils.jag_cut(result.below, local_plane, cut_material,
		cut_jag_amount, noise)
	var halves: Array[Dictionary] = []
	for half_index: int in range(2):
		var half: ArrayMesh = result.above if half_index == 0 else result.below
		var aabb := half.get_aabb()
		var center := aabb.position + aabb.size * 0.5
		var centered := _translate_mesh(half, -center)
		# Match the block splitter's authored fresh-half push. Both descendants
		# remain under the loose root's physics owner until its one-hit random
		# fragmentation batch is complete.
		var separation := local_plane.normal * half_push \
			* (1.0 if half_index == 0 else -1.0)
		halves.append({
			"mesh": centered,
			"center": center,
			"separation": separation,
			"is_firewood": _mesh_is_firewood(centered),
			"suffix": "a" if half_index == 0 else "b",
		})
	return {"halves": halves, "local_plane": local_plane}


## An off-block power has already completed this root synchronously. Release its
## random real descendants as individual physics bodies so they fall apart at
## the impact location, present the authoritative cash/XP there, then retire
## each settled piece through the normal opaque hold/sink lifecycle.
func retire_off_block_finished_log(body: RigidBody3D,
		completion_receipt: Dictionary = {},
		world_position := Vector3.ZERO) -> void:
	if body == null or not is_instance_valid(body):
		return
	var reward_position := body.global_position if world_position == Vector3.ZERO \
		else world_position
	var xp_total := maxi(0, int(completion_receipt.get("xp_total", 0)))
	var cash_total := maxi(0, int(completion_receipt.get("cash_total", 0)))
	if xp_total > 0:
		_burst_xp_orbs(xp_total,
			to_local(reward_position + Vector3.UP * 0.12), false)
	if cash_total > 0 and _coin_reward_pool != null:
		_coin_reward_pool.begin_burst(reward_position + Vector3.UP * 0.06,
			1, to_global(Vector3(0.0, reward_ground_y, 0.0)).y,
			orb_scatter_radius, orb_collect_at, orb_stagger)
		_coin_reward_pool.queue_payout(cash_total)
	var inherited_linear := body.linear_velocity
	var inherited_angular := body.angular_velocity
	var visuals: Array[MeshInstance3D] = []
	var released_visual_ids: Array[int] = []
	for child: Node in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			visuals.append(child as MeshInstance3D)
	for visual: MeshInstance3D in visuals:
		var fragment := RigidBody3D.new()
		fragment.name = "OffBlockFinishedPiece"
		fragment.contact_monitor = true
		fragment.max_contacts_reported = 4
		fragment.continuous_cd = true
		fragment.physics_material_override = _phys_mat
		fragment.linear_damp = piece_linear_damp
		fragment.angular_damp = piece_angular_damp
		var size := visual.mesh.get_aabb().size
		fragment.mass = maxf(wood_density * size.x * size.y * size.z, min_mass)
		_fallers.add_child(fragment)
		fragment.global_transform = visual.global_transform
		visual.reparent(fragment)
		visual.transform = Transform3D.IDENTITY
		visual.name = "Mesh"
		released_visual_ids.append(visual.get_instance_id())
		fragment.set_meta("mesh_ref", visual.mesh)
		fragment.set_meta("projection_offset",
			visual.get_meta("projection_offset", Vector3.ZERO))
		var collision := CollisionShape3D.new()
		collision.shape = MeshUtils.box_shape(visual.mesh)
		fragment.add_child(collision)
		fragment.body_entered.connect(_on_firewood_body_entered.bind(fragment))
		var outward := fragment.global_position - reward_position
		outward.y = 0.0
		if outward.length_squared() <= 0.0001:
			var angle := TAU * float(visual.get_instance_id() % 997) / 997.0
			outward = Vector3(cos(angle), 0.0, sin(angle))
		else:
			outward = outward.normalized()
		# These pieces are already on the yard floor. Give them only a restrained
		# outward tip—never the block firewood's upward launch—so the root visibly
		# falls apart in place instead of exploding across the ring.
		fragment.linear_velocity = inherited_linear + outward \
			* _SURVIVAL_TUNING.off_block_fragment_out_speed
		fragment.angular_velocity = inherited_angular \
			+ Vector3.UP.cross(outward) \
			* _SURVIVAL_TUNING.off_block_fragment_tumble_speed
		_finished_firewood.append({
			"body": fragment,
			"geometry": _finished_geometry(fragment),
			"settling": true,
			"settle_age": 0.0,
			"age": 0.0,
			"start_y": fragment.global_position.y,
		})
	# Keep the now-empty owner alive until the destruction flash finishes;
	# its tween owns the shared overlay material used by the released fragments.
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta("released_visual_ids", released_visual_ids)
	body.reparent(_finished_firewood_root, true)
	var cleanup := create_tween()
	cleanup.tween_interval(0.16)
	cleanup.tween_callback(Callable(self,
		"_free_finished_empty_root").bind(body.get_instance_id()))


func _free_finished_empty_root(body_id: int) -> void:
	var body := instance_from_id(body_id) as RigidBody3D
	if body != null and is_instance_valid(body):
		var raw_ids: Variant = body.get_meta("released_visual_ids", [])
		if raw_ids is Array:
			for raw_id: Variant in raw_ids:
				var visual := instance_from_id(int(raw_id)) as MeshInstance3D
				if visual != null and is_instance_valid(visual):
					visual.material_overlay = null
		body.queue_free()


func stage_run_log(descriptor: LogDescriptor, hop_from_arena: bool) -> void:
	if descriptor == null or not descriptor.is_valid():
		return
	# A new root may arrive while the previous root's landed billets are still in
	# their floor-sink. Clear only the active workpiece, never that farewell.
	clear_run_log(false)
	# External run flow stages every descriptor here. The successful-offer latch
	# belongs to one root and must never suppress Grain Reader on the next root.
	_grain_offered_this_log = false
	_grain_offer_count_this_log = 0
	_current_descriptor = descriptor
	_current_species = SpeciesTable.by_id(descriptor.species_id)
	var species_index := SpeciesTable.index_of(descriptor.species_id)
	_cut_mat = _cut_mat_for(species_index)
	_source_mesh = build_run_log_mesh(descriptor)
	_cut_noise.seed = descriptor.visual_seed
	var half_h := _source_mesh.get_aabb().size.y * 0.5
	var rest_y := _stump_top_y + half_h
	var node := _make_stay_piece(_source_mesh, Vector3(0.0, rest_y, 0.0),
		0.0, true, Vector3.ZERO, &"root")
	_pending_descriptor_power_cuts = maxi(0,
		int(descriptor.get("pending_power_cuts")))
	_pending_descriptor_power_cut_sources.clear()
	var raw_cut_sources: Variant = descriptor.get("pending_power_cut_sources")
	if raw_cut_sources is Array:
		for raw_source: Variant in raw_cut_sources:
			if _pending_descriptor_power_cut_sources.size() \
					>= _pending_descriptor_power_cuts:
				break
			if raw_source is String or raw_source is StringName:
				var source := StringName(raw_source)
				if source != &"":
					_pending_descriptor_power_cut_sources.append(source)
	# Saves from before source attribution still contain valid deferred cuts.
	# Those legacy cuts execute first under the neutral `precut` presentation.
	while _pending_descriptor_power_cut_sources.size() \
			< _pending_descriptor_power_cuts:
		_pending_descriptor_power_cut_sources.push_front(&"precut")
	var pending_scars := maxi(0, int(descriptor.get("pending_power_scars")))
	for scar_index: int in range(pending_scars):
		var scar_normal := Vector3.RIGHT.rotated(Vector3.UP,
			TAU * float(scar_index) / maxf(1.0, float(pending_scars)))
		node.set_meta("scars", _scars_on(node) + 1)
		_add_scar(node, node.global_position, scar_normal)
	descriptor.set("pending_power_cuts", 0)
	descriptor.set("pending_power_cut_sources", [])
	descriptor.set("pending_power_scars", 0)
	var landed := Callable(self, "_on_log_landed").bind(_source_mesh)
	if hop_from_arena and descriptor.has_transfer_pose():
		# The old arena body was hidden synchronously before queue_free. Keep this
		# authoritative replacement hidden too and fly a visual snapshot instead;
		# legacy partially cut roots therefore do not turn whole during delivery.
		node.visible = false
		var handoff_visual := _build_run_handoff_visual(descriptor, _source_mesh)
		handoff_visual.global_position = descriptor.transfer_from
		handoff_visual.quaternion = descriptor.transfer_rotation
		var target := to_global(Vector3(0.0, rest_y, 0.0))
		var offscreen_y := _vertical_handoff_offscreen_y(
			descriptor.transfer_from, target, handoff_visual)
		_start_run_log_handoff(node, handoff_visual, descriptor.transfer_from,
			descriptor.transfer_rotation, target, offscreen_y, _source_mesh)
	else:
		_animator.animate_drop(node, rest_y + drop_height, rest_y, landed, 300.0)
		_try_show_grain_cue(node)


## A scheduled boss is presented as five real-sized roots already committed to
## the chopping block. Only the top root enters `_on_block`; the lower four are
## opaque, non-pickable stack geometry until promoted in place.
func stage_boss_log_stack(raw_descriptors: Array) -> void:
	var descriptors: Array[LogDescriptor] = []
	for raw: Variant in raw_descriptors:
		if raw is LogDescriptor and (raw as LogDescriptor).is_valid():
			descriptors.append(raw as LogDescriptor)
	if _run_director == null or descriptors.size() \
			!= _run_director.tuning.boss_stack_log_count:
		return
	clear_run_log(false)
	_boss_stack_active = true
	_ensure_boss_stack_visual_root()
	var stack_top := _stump_top_y
	for index: int in range(descriptors.size()):
		var descriptor := descriptors[index]
		var mesh := build_run_log_mesh(descriptor)
		if mesh == null:
			continue
		var height := mesh.get_aabb().size.y
		var center_y := stack_top + height * 0.5
		_boss_stack_centers[descriptor.id] = center_y
		stack_top += height + _run_director.tuning.boss_stack_gap
		if index < descriptors.size() - 1:
			_add_boss_stack_visual(descriptor, mesh, center_y)
	var active := descriptors[-1]
	var active_mesh := build_run_log_mesh(active)
	if active_mesh == null or not _boss_stack_centers.has(active.id):
		clear_run_log(false)
		return
	_configure_boss_stack_descriptor(active, active_mesh)
	var rest_y := float(_boss_stack_centers[active.id])
	_track_boss_camera(rest_y)
	var node := _make_stay_piece(active_mesh, Vector3(0.0, rest_y, 0.0),
		0.0, true, Vector3.ZERO, &"root")
	var drop_seconds := 0.3
	_boss_stack_visual_root.position.y = drop_height
	_boss_stack_drop_tween = create_tween()
	_boss_stack_drop_tween.tween_property(_boss_stack_visual_root,
		"position:y", 0.0, drop_seconds).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	var landed := Callable(self, "_on_log_landed").bind(active_mesh)
	_animator.animate_drop(node, rest_y + drop_height, rest_y, landed,
		drop_seconds * 1000.0)
	_try_show_grain_cue(node)


func stage_next_boss_stack_log(descriptor: LogDescriptor) -> void:
	if not _boss_stack_active or descriptor == null or not descriptor.is_valid():
		return
	_finish_boss_stack_drop()
	var visual := _boss_stack_visuals.get(descriptor.id) as MeshInstance3D
	var rest_y := float(_boss_stack_centers.get(descriptor.id, _stump_top_y))
	if is_instance_valid(visual):
		rest_y = visual.global_position.y
		_boss_stack_visuals.erase(descriptor.id)
		visual.queue_free()
	var mesh := build_run_log_mesh(descriptor)
	if mesh == null:
		return
	_configure_boss_stack_descriptor(descriptor, mesh)
	_track_boss_camera(rest_y)
	var node := _make_stay_piece(mesh, Vector3(0.0, rest_y, 0.0),
		0.0, true, Vector3.ZERO, &"root")
	_try_show_grain_cue(node)
	# The root was visible in this exact slot throughout the previous chop. It is
	# already landed, so promotion releases gameplay without replaying a drop.
	if _external_log_flow:
		run_log_ready.emit()


func restore_boss_log_stack(raw_remaining: Array) -> void:
	_clear_boss_stack_presentation(false)
	_boss_stack_active = true
	_ensure_boss_stack_visual_root()
	var stack_top := _stump_top_y
	for raw: Variant in raw_remaining:
		if not (raw is LogDescriptor):
			continue
		var descriptor := raw as LogDescriptor
		var mesh := build_run_log_mesh(descriptor)
		if mesh == null:
			continue
		var height := mesh.get_aabb().size.y
		var center_y := stack_top + height * 0.5
		_boss_stack_centers[descriptor.id] = center_y
		_add_boss_stack_visual(descriptor, mesh, center_y)
		stack_top += height + _run_director.tuning.boss_stack_gap
	if _current_descriptor != null and _source_mesh != null:
		var active_center_y := stack_top + _source_mesh.get_aabb().size.y * 0.5
		_boss_stack_centers[_current_descriptor.id] = active_center_y
		_track_boss_camera(active_center_y)


func end_boss_log_stack() -> void:
	_clear_boss_stack_presentation(true)


func _configure_boss_stack_descriptor(descriptor: LogDescriptor,
		mesh: Mesh) -> void:
	_clear_grain_cue(&"piece_changed")
	_grain_offered_this_log = false
	_grain_offer_count_this_log = 0
	_current_descriptor = descriptor
	_current_species = SpeciesTable.by_id(descriptor.species_id)
	var species_index := SpeciesTable.index_of(descriptor.species_id)
	_cut_mat = _cut_mat_for(species_index)
	_source_mesh = mesh
	_cut_noise.seed = descriptor.visual_seed
	_cut_journal.clear()
	_pending_descriptor_power_cuts = 0
	_pending_descriptor_power_cut_sources.clear()
	_power_cut_context = &""


func _ensure_boss_stack_visual_root() -> void:
	if is_instance_valid(_boss_stack_visual_root):
		return
	_boss_stack_visual_root = Node3D.new()
	_boss_stack_visual_root.name = "BossLogStack"
	add_child(_boss_stack_visual_root)


func _add_boss_stack_visual(descriptor: LogDescriptor, mesh: Mesh,
		center_y: float) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Stack_%s" % descriptor.id
	visual.mesh = mesh
	visual.position = Vector3(0.0, center_y, 0.0)
	visual.set_meta("descriptor_id", descriptor.id)
	_boss_stack_visual_root.add_child(visual)
	_boss_stack_visuals[descriptor.id] = visual


func _finish_boss_stack_drop() -> void:
	if _boss_stack_drop_tween != null and _boss_stack_drop_tween.is_valid():
		_boss_stack_drop_tween.custom_step(INF)
	_boss_stack_drop_tween = null
	if is_instance_valid(_boss_stack_visual_root):
		_boss_stack_visual_root.position.y = 0.0


func _clear_boss_stack_presentation(restore_camera: bool) -> void:
	if _boss_stack_drop_tween != null and _boss_stack_drop_tween.is_valid():
		_boss_stack_drop_tween.kill()
	_boss_stack_drop_tween = null
	if is_instance_valid(_boss_stack_visual_root):
		_boss_stack_visual_root.queue_free()
	_boss_stack_visual_root = null
	_boss_stack_visuals.clear()
	_boss_stack_centers.clear()
	_boss_stack_active = false
	if restore_camera:
		# `_track_boss_camera` accepts the world height that should occupy the
		# screen centre. Feed it the base camera's authored centre-line height so
		# the resulting pivot returns exactly to `_pivot_base_position.y`.
		_track_boss_camera(_pivot_base_position.y \
			+ _camera_center_height_at_stump())


## Boss framing follows only the currently exposed top root. Distance and FOV
## stay at ordinary gameplay values; clearing a layer eases the pivot downward.
func _track_boss_camera(root_center_y: float) -> void:
	if _camera == null or _pivot == null:
		return
	if _boss_camera_tween != null and _boss_camera_tween.is_valid():
		_boss_camera_tween.kill()
	_camera.transform = _camera_base_transform
	_camera.fov = _camera_base_fov
	var lift_fraction := 0.0
	var transition_seconds := 0.4
	if _run_director != null and _run_director.tuning != null:
		lift_fraction = _run_director.tuning.boss_stack_camera_lift_fraction
		transition_seconds = _run_director.tuning.boss_stack_camera_transition_seconds
	# The pivot's authored base height is not the camera's screen-centre height:
	# the camera sits above and looks down at the stump. Remove that exact
	# centre-line offset so a full 1.0 lock puts the exposed root's real centre in
	# the viewport centre instead of leaving its top above the frame.
	var fully_centered_y := root_center_y - _camera_center_height_at_stump()
	_boss_camera_target_y = lerpf(_pivot_base_position.y, fully_centered_y,
		clampf(lift_fraction, 0.0, 1.0))
	var target_position := _pivot_base_position
	target_position.y = _boss_camera_target_y
	_boss_camera_tween = create_tween().set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS)
	_boss_camera_tween.tween_property(_pivot, "position", target_position,
		maxf(0.001, transition_seconds)).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)


func _camera_center_height_at_stump() -> float:
	var origin := _camera_base_transform.origin
	var forward := -_camera_base_transform.basis.z.normalized()
	if absf(forward.z) <= 0.000001:
		return 0.0
	var distance_to_stump_plane := -origin.z / forward.z
	return origin.y + forward.y * distance_to_stump_plane


func _boss_active_log_is_visible() -> bool:
	if _camera == null or _camera.get_viewport() == null or _on_block.is_empty():
		return false
	var visible := _camera.get_viewport().get_visible_rect().grow(-12.0)
	for piece: Area3D in _on_block:
		if not is_instance_valid(piece):
			continue
		var mesh := piece.get_meta("mesh_ref", null) as Mesh
		if mesh == null:
			return false
		var bounds := mesh.get_aabb()
		for x_side: int in range(2):
			for y_side: int in range(2):
				for z_side: int in range(2):
					var point := piece.global_transform * (bounds.position + Vector3(
						bounds.size.x * float(x_side),
						bounds.size.y * float(y_side),
						bounds.size.z * float(z_side)))
					if _camera.is_position_behind(point) or not visible.has_point(
							_camera.unproject_position(point)):
						return false
	return true


func _build_run_handoff_visual(descriptor: LogDescriptor,
		fallback_mesh: Mesh) -> Node3D:
	var root := Node3D.new()
	root.name = "RunLogHandoff"
	_pieces_root.add_child(root)
	if descriptor.has_transfer_visuals():
		for index: int in range(descriptor.transfer_visual_meshes.size()):
			var visual := MeshInstance3D.new()
			visual.name = "HandoffPiece%d" % (index + 1)
			visual.mesh = descriptor.transfer_visual_meshes[index]
			visual.transform = descriptor.transfer_visual_transforms[index]
			if index < descriptor.transfer_visual_projection_offsets.size():
				var projection_offset := \
					descriptor.transfer_visual_projection_offsets[index]
				visual.set_meta("projection_offset", projection_offset)
				visual.set_instance_shader_parameter(
					&"projection_offset", projection_offset)
			if index < descriptor.transfer_visual_overlays.size():
				visual.material_overlay = descriptor.transfer_visual_overlays[index]
			root.add_child(visual)
	elif fallback_mesh != null:
		var visual := MeshInstance3D.new()
		visual.name = "HandoffPiece"
		visual.mesh = fallback_mesh
		root.add_child(visual)
	return root


func _start_run_log_handoff(piece: Area3D, visual: Node3D, start: Vector3,
		start_rotation: Quaternion, target: Vector3, offscreen_y: float,
		mesh: Mesh) -> void:
	_cancel_run_log_handoff()
	_run_handoff_generation += 1
	var generation := _run_handoff_generation
	_run_handoff_active = true
	_run_handoff_visual = visual
	_run_handoff_piece = piece
	_run_handoff_target = target
	_run_handoff_mesh = mesh
	var timing := _vertical_handoff_timing(
		_run_director.tuning.block_hop_seconds)
	var lift_duration := timing.x * timing.y
	var drop_duration := timing.x * (1.0 - timing.y)
	_run_handoff_tween = create_tween()
	_run_handoff_tween.tween_method(
		Callable(self, "_move_run_log_handoff_lift").bind(
			visual, start, offscreen_y, start_rotation),
		0.0, 1.0, lift_duration).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	_run_handoff_tween.tween_callback(
		Callable(self, "_reposition_run_log_handoff").bind(
			generation, visual, target, offscreen_y))
	_run_handoff_tween.tween_interval(
		_run_director.tuning.block_handoff_hidden_hold_seconds)
	_run_handoff_tween.tween_method(
		Callable(self, "_move_run_log_handoff_drop").bind(
			visual, target, offscreen_y),
		0.0, 1.0, drop_duration).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	_run_handoff_tween.tween_callback(
		Callable(self, "_complete_run_log_handoff").bind(
			generation, piece, visual, target, mesh))


func _move_run_log_handoff_lift(progress: float, visual: Node3D,
		start: Vector3, offscreen_y: float,
		start_rotation: Quaternion) -> void:
	if not is_instance_valid(visual):
		return
	visual.global_position = Vector3(start.x,
		lerpf(start.y, offscreen_y, clampf(progress, 0.0, 1.0)), start.z)
	visual.quaternion = start_rotation.slerp(
		Quaternion.IDENTITY, clampf(progress, 0.0, 1.0))


func _reposition_run_log_handoff(generation: int, visual: Node3D,
		target: Vector3, offscreen_y: float) -> void:
	if generation != _run_handoff_generation \
			or not _run_handoff_active or not is_instance_valid(visual):
		return
	visual.global_position = Vector3(target.x, offscreen_y, target.z)
	visual.quaternion = Quaternion.IDENTITY


func _move_run_log_handoff_drop(progress: float, visual: Node3D,
		target: Vector3, offscreen_y: float) -> void:
	if not is_instance_valid(visual):
		return
	visual.global_position = Vector3(target.x,
		lerpf(offscreen_y, target.y, clampf(progress, 0.0, 1.0)), target.z)
	visual.quaternion = Quaternion.IDENTITY


func _complete_run_log_handoff(generation: int, piece: Area3D,
		visual: Node3D, target: Vector3, mesh: Mesh) -> void:
	if generation != _run_handoff_generation or not _run_handoff_active:
		return
	_run_handoff_active = false
	_run_handoff_tween = null
	if is_instance_valid(visual):
		visual.visible = false
		visual.queue_free()
	if not is_instance_valid(piece) or piece not in _on_block:
		_clear_run_handoff_refs()
		return
	piece.global_position = target
	piece.quaternion = Quaternion.IDENTITY
	piece.visible = false
	_on_log_landed(mesh)
	# Pending arrival cuts can synchronously complete this root and stage another
	# one. That replacement owns a newer generation; never reveal or clear its
	# nodes from the stale completion frame.
	if generation != _run_handoff_generation:
		return
	# Deferred splits can replace `piece` synchronously. Reveal the surviving
	# authoritative descendants only after the handoff snapshot is gone.
	for landed_piece: Area3D in _on_block:
		if is_instance_valid(landed_piece):
			landed_piece.visible = true
	if not _on_block.is_empty():
		_try_show_grain_cue(_on_block[0])
	_clear_run_handoff_refs()


func _finish_active_run_handoff() -> void:
	if not _run_handoff_active:
		return
	var generation := _run_handoff_generation
	var piece := _run_handoff_piece
	var visual := _run_handoff_visual
	var target := _run_handoff_target
	var mesh := _run_handoff_mesh
	if _run_handoff_tween != null and _run_handoff_tween.is_valid():
		_run_handoff_tween.kill()
	_complete_run_log_handoff(generation, piece, visual, target, mesh)


func _cancel_run_log_handoff() -> void:
	_run_handoff_generation += 1
	_run_handoff_active = false
	if _run_handoff_tween != null and _run_handoff_tween.is_valid():
		_run_handoff_tween.kill()
	if is_instance_valid(_run_handoff_visual):
		_run_handoff_visual.visible = false
		_run_handoff_visual.queue_free()
	_clear_run_handoff_refs()


func _clear_run_handoff_refs() -> void:
	_run_handoff_tween = null
	_run_handoff_visual = null
	_run_handoff_piece = null
	_run_handoff_target = Vector3.ZERO
	_run_handoff_mesh = null


## Lengthen the source-side rise without speeding up or otherwise altering the
## already-authored drop. Returns (total duration, effective lift fraction).
func _vertical_handoff_timing(base_duration: float) -> Vector2:
	var authored_fraction := clampf(
		_run_director.tuning.block_handoff_lift_fraction, 0.001, 0.999)
	var lift_duration := base_duration * authored_fraction \
		* _run_director.tuning.block_handoff_lift_time_multiplier
	var drop_duration := base_duration * (1.0 - authored_fraction)
	var total_duration := maxf(0.001, lift_duration + drop_duration)
	return Vector2(total_duration, lift_duration / total_duration)


func _move_run_log_vertical_handoff(progress: float, node: Node3D,
		start: Vector3, target: Vector3, offscreen_y: float,
		lift_fraction: float, start_rotation: Quaternion) -> void:
	if not is_instance_valid(node):
		return
	node.global_position = _vertical_handoff_position(progress, start, target,
		offscreen_y, lift_fraction)
	var rotation_progress := clampf(progress / maxf(0.001, lift_fraction),
		0.0, 1.0)
	node.quaternion = start_rotation.slerp(Quaternion.IDENTITY,
		rotation_progress)


## Two visible vertical legs with one hidden reposition. The source X/Z remains
## exact throughout the lift. Once the log is above frame, it snaps horizontally
## over the block while still invisible, then keeps the target X/Z for its drop.
func _vertical_handoff_position(progress: float, start: Vector3,
		target: Vector3, offscreen_y: float, lift_fraction: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var split := clampf(lift_fraction, 0.001, 0.999)
	if t < split:
		var lift_t := t / split
		return Vector3(start.x,
			lerpf(start.y, offscreen_y, 1.0 - pow(1.0 - lift_t, 2.0)),
			start.z)
	var drop_t := (t - split) / (1.0 - split)
	return Vector3(target.x,
		lerpf(offscreen_y, target.y, drop_t * drop_t), target.z)


func _vertical_handoff_offscreen_y(start: Vector3, target: Vector3,
		visual: Node3D = null) -> float:
	var step := maxf(0.5, _run_director.tuning.arrival_height)
	var height := maxf(start.y, target.y) + step
	# The camera and viewport are live production authorities here. Walk upward
	# until the complete upright silhouette—not merely its pivot—clears both ends
	# of the hidden reposition.
	for _sample: int in range(64):
		var source_top := Vector3(start.x, height, start.z)
		var target_top := Vector3(target.x, height, target.z)
		var source_clear := _handoff_point_is_above_frame(source_top) \
			if visual == null else _handoff_visual_is_above_frame(
				visual, source_top, Quaternion.IDENTITY)
		var target_clear := _handoff_point_is_above_frame(target_top) \
			if visual == null else _handoff_visual_is_above_frame(
				visual, target_top, Quaternion.IDENTITY)
		if source_clear and target_clear:
			return height
		height += step
	push_warning("Run-log handoff could not prove full silhouette clearance; " \
		+ "using the highest bounded sample")
	return height


func _handoff_visual_is_above_frame(visual_root: Node3D,
		root_position: Vector3, root_rotation: Quaternion) -> bool:
	if visual_root == null or not is_instance_valid(visual_root):
		return false
	var root_inverse := visual_root.global_transform.affine_inverse()
	var root_basis := Basis(root_rotation)
	var found_mesh := false
	for raw_node: Node in visual_root.find_children(
			"*", "MeshInstance3D", true, false):
		var mesh_visual := raw_node as MeshInstance3D
		if mesh_visual == null or mesh_visual.mesh == null:
			continue
		found_mesh = true
		var visual_in_root := root_inverse * mesh_visual.global_transform
		var aabb := mesh_visual.mesh.get_aabb()
		for corner_index: int in range(8):
			var corner := Vector3(
				aabb.end.x if (corner_index & 1) != 0 else aabb.position.x,
				aabb.end.y if (corner_index & 2) != 0 else aabb.position.y,
				aabb.end.z if (corner_index & 4) != 0 else aabb.position.z)
			var world_corner := root_position \
				+ root_basis * (visual_in_root * corner)
			if not _handoff_point_is_above_frame(world_corner):
				return false
	return found_mesh


func _handoff_point_is_above_frame(point: Vector3) -> bool:
	if _camera == null or _camera.get_viewport() == null:
		return false
	if _camera.is_position_behind(point):
		return true
	var screen := _camera.unproject_position(point)
	var margin := float(
		_run_director.tuning.block_handoff_offscreen_margin_pixels)
	return screen.y <= -margin


## Execute authored run-power cuts through the same MeshSlicer path as a manual
## swing. Automatic cuts never roll reliability and never recursively start a
## second power chain; they are already the resolved effect of a chosen power.
func apply_run_power_cuts(power_id: StringName, count: int,
		mode: StringName = &"largest", present_each_cut := true) -> int:
	if count == 0 or _on_block.is_empty():
		_last_run_power_cuts[power_id] = 0
		return 0
	var targets: Array[Area3D] = []
	if mode in [&"sweep", &"all"]:
		for piece: Area3D in _on_block:
			if is_instance_valid(piece):
				targets.append(piece)
	var limit := count if count > 0 else maxi(1, targets.size())
	var executed := 0
	var previous_context := _power_cut_context
	_power_cut_context = power_id
	while executed < limit and not _on_block.is_empty():
		var target: Area3D = null
		if not targets.is_empty():
			while not targets.is_empty() and (not is_instance_valid(targets[0]) \
					or targets[0] not in _on_block):
				targets.pop_front()
			if not targets.is_empty():
				target = targets.pop_front()
		else:
			target = _pick_double_strike_target()
		if target == null:
			break
		var normal := _camera.global_transform.basis.x
		normal.y = 0.0
		if normal.length_squared() < 0.0001:
			normal = Vector3.RIGHT
		normal = normal.normalized()
		var point := target.global_position
		if not _bonus_cut_preflight(target, point, normal):
			var cross := Vector3(-normal.z, 0.0, normal.x)
			if not _bonus_cut_preflight(target, point, cross):
				if mode in [&"sweep", &"all"]:
					continue
				break
			normal = cross
		var mesh: Mesh = target.get_meta("mesh_ref")
		var burst_height := mesh.get_aabb().size.y if mesh != null else 0.2
		var burst_point := point + Vector3.UP * (burst_height * 0.5 + 0.05)
		if not _perform_split(target, point, normal, _dir_from_normal(normal)):
			break
		executed += 1
		if present_each_cut:
			present_run_power_trigger(power_id, burst_point, executed)
	_power_cut_context = previous_context
	_last_run_power_cuts[power_id] = executed
	return executed


## Finish the current block root through repeated real MeshSlicer cuts. This is
## intentionally progress-driven instead of a guessed cut count: each successful
## cut advances the production geometry, and an unsliceable target stops cleanly.
func complete_run_power_log(power_id: StringName,
		mode: StringName = &"largest", present_each_cut := true) -> int:
	var executed := 0
	while not _on_block.is_empty():
		var applied := apply_run_power_cuts(power_id, 1, mode,
			present_each_cut)
		if applied <= 0:
			break
		executed += applied
	_last_run_power_cuts[power_id] = executed
	return executed


func _apply_pending_descriptor_power_cuts() -> void:
	var cuts := _pending_descriptor_power_cuts
	var sources := _pending_descriptor_power_cut_sources.duplicate()
	_pending_descriptor_power_cuts = 0
	_pending_descriptor_power_cut_sources.clear()
	while sources.size() < cuts:
		sources.push_front(&"precut")
	for index: int in range(mini(cuts, sources.size())):
		if _on_block.is_empty():
			break
		apply_run_power_cuts(sources[index], 1, &"largest")


func present_run_power_trigger(power_id: StringName, world_position: Vector3,
		amount: int = 1) -> void:
	var event_name := "" if amount <= 1 else "×%d" % amount
	var action_value := 0.0
	var action_travel_value := 0.0
	var action_variant := 0
	if power_id == &"crosscut_sweep":
		action_value = _scaled_power_area(_run_power_effect(
			ProgressionEffectDef.Kind.CROSSCUT_SWEEP_WIDTH))
		if _run_director != null:
			var state := _run_director.get_run_power_runtime_state()
			action_travel_value = maxf(action_value,
				float(state.get("effective_boundary_radius", 0.0)) * 2.0)
			var counts: Variant = state.get("trigger_counts", {})
			if counts is Dictionary:
				var completed := int((counts as Dictionary).get(
					String(power_id), (counts as Dictionary).get(power_id, 1)))
				action_variant = maxi(0, completed - 1) % 2
	elif power_id in [&"earthshaker", &"powder_keg", &"kindling_chain",
			&"stump_pulse", &"sawblade_halo", &"timber_burst"]:
		var area_kind := ProgressionEffectDef.Kind.EARTHSHAKER_RADIUS
		match power_id:
			&"powder_keg":
				area_kind = ProgressionEffectDef.Kind.POWDER_KEG_RADIUS
			&"kindling_chain":
				area_kind = ProgressionEffectDef.Kind.KINDLING_CHAIN_RANGE
			&"sawblade_halo":
				area_kind = ProgressionEffectDef.Kind.SAWBLADE_HALO_RADIUS
			&"timber_burst":
				area_kind = ProgressionEffectDef.Kind.TIMBER_BURST_RADIUS
			&"stump_pulse":
				if _run_director != null:
					action_value = _scaled_power_area(float(
						_run_director.get_run_power_runtime_state().get(
							"effective_boundary_radius", 0.0)))
		if action_value <= 0.0:
			action_value = _scaled_power_area(_run_power_effect(area_kind))
	RunPowerBurst.spawn_for_id(self, world_position, power_id, event_name,
		null, true, action_value, action_variant, action_travel_value)
	if amount > 0:
		AudioDirector.play_world(&"proc_mastery", world_position)


## One readable splinter leaves the successful block strike and lands at the
## selected loose root. The gameplay cuts have already resolved atomically; this
## short flight only makes their source-to-target relationship visible.
func present_splinter_volley(source_position: Vector3,
		target_position: Vector3, amount: int) -> void:
	var projectile := MeshInstance3D.new()
	projectile.name = "SplinterProjectile"
	var vfx := _RUN_VFX_CONFIG as RunVfxConfig
	projectile.mesh = _shared_splinter_projectile_mesh()
	projectile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	projectile.set_meta("splinter_source", source_position)
	projectile.set_meta("splinter_target", target_position)
	projectile.set_meta("splinter_count", amount)
	add_child(projectile)
	var raised_source := source_position + Vector3.UP \
		* vfx.splinter_projectile_height
	var raised_target := target_position + Vector3.UP \
		* vfx.splinter_projectile_height
	projectile.global_position = raised_source
	if raised_source.distance_squared_to(raised_target) > 0.000001:
		projectile.look_at(raised_target, Vector3.UP)
	var travel_seconds := maxf(0.05, vfx.generic_duration)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(projectile, "global_position", raised_target,
		travel_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_finish_splinter_projectile").bind(
		projectile, target_position, amount))


func _shared_splinter_projectile_mesh() -> BoxMesh:
	if _splinter_projectile_mesh != null:
		return _splinter_projectile_mesh
	var vfx := _RUN_VFX_CONFIG as RunVfxConfig
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _run_power_color(&"splinter_volley").lerp(
		Color.WHITE, vfx.splinter_projectile_white_mix)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = vfx.splinter_projectile_emission_energy
	_splinter_projectile_mesh = BoxMesh.new()
	_splinter_projectile_mesh.size = vfx.splinter_projectile_size
	_splinter_projectile_mesh.material = material
	return _splinter_projectile_mesh


func _finish_splinter_projectile(projectile: MeshInstance3D,
		target_position: Vector3, amount: int) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()
	present_run_power_trigger(&"splinter_volley", target_position, amount)


func present_run_power_acquisition(power_id: StringName,
		world_position: Vector3, rank: int, quality: int) -> void:
	var quality_name := RunOfferTuning.quality_display_name(quality)
	var event_name := "R%d" % maxi(1, rank)
	if not quality_name.is_empty():
		event_name += " · %s" % quality_name.to_upper()
	RunPowerBurst.spawn_for_id(self, world_position, power_id, event_name,
		RunOfferTuning.color_for_quality(quality))
	AudioDirector.play_world(&"proc_mastery", world_position)


func _run_power_color(power_id: StringName) -> Color:
	# Runtime proc color is a neutral power-system accent. Rare/Epic color now
	# belongs exclusively to the rolled quality of an acquisition card.
	return Color(0.42, 0.88, 0.34, 1.0)


func refresh_run_power_visuals(suppress_grain_roll := false) -> void:
	if not suppress_grain_roll:
		_refresh_grain_availability()
	var desired := maxi(0, int(round(_run_power_effect(
		ProgressionEffectDef.Kind.ORBITING_AXE_COUNT))))
	if _run_power_orbit_root == null:
		_run_power_orbit_root = Node3D.new()
		_run_power_orbit_root.name = "RunPowerOrbitingAxes"
		add_child(_run_power_orbit_root)
	while _run_power_orbit_axes.size() > desired:
		var old: Node3D = _run_power_orbit_axes.pop_back()
		if is_instance_valid(old):
			old.queue_free()
	while _run_power_orbit_axes.size() < desired:
		var axe := _build_run_power_orbiting_axe(
			_run_power_orbit_axes.size())
		_run_power_orbit_root.add_child(axe)
		_run_power_orbit_axes.append(axe)


func _build_run_power_orbiting_axe(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "WhirlingAxe%d" % (index + 1)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.045, 0.34, 0.045)
	handle.mesh = handle_mesh
	handle.position.y = -0.10
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.12, 0.045, 1.0)
	handle.material_override = wood
	root.add_child(handle)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.28, 0.12, 0.055)
	head.mesh = head_mesh
	head.position = Vector3(0.08, 0.08, 0.0)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.34, 0.64, 0.88, 1.0)
	steel.metallic = 0.55
	steel.roughness = 0.34
	head.material_override = steel
	root.add_child(head)
	return root


func _update_run_power_orbits(delta: float) -> void:
	if _run_power_orbit_axes.is_empty():
		return
	_run_power_orbit_angle = fmod(_run_power_orbit_angle + delta * 2.4, TAU)
	var count := _run_power_orbit_axes.size()
	for index: int in range(count):
		var axe := _run_power_orbit_axes[index]
		if not is_instance_valid(axe):
			continue
		var angle := _run_power_orbit_angle + TAU * float(index) / float(count)
		var orbit_radius := _scaled_power_area(0.82)
		axe.position = Vector3(cos(angle) * orbit_radius,
			_stump_top_y + 0.48 + sin(angle * 2.0) * 0.06,
			sin(angle) * orbit_radius)
		axe.rotation = Vector3(0.0, -angle, angle * 1.7)


func _run_power_effect(kind: ProgressionEffectDef.Kind) -> float:
	return 0.0 if _run_director == null else _run_director.get_effect(kind)


func _scaled_power_area(base_size: float) -> float:
	if _run_director != null and _run_director.has_method("scale_power_area"):
		return float(_run_director.call("scale_power_area", base_size))
	return maxf(0.0, base_size)


func _momentum_stacks() -> int:
	if _run_director == null or not _run_director.has_method(
			"get_run_power_runtime_state"):
		return 0
	var state: Dictionary = _run_director.call("get_run_power_runtime_state")
	return maxi(0, int(state.get("momentum_stacks", 0)))


func debug_last_run_power_cuts(power_id: StringName) -> int:
	return maxi(0, int(_last_run_power_cuts.get(power_id, 0)))


func debug_orbiting_axe_count() -> int:
	return _run_power_orbit_axes.size()


## Freeze the run at a canonical transaction boundary before a disk snapshot.
## Hazards are already paused by RunDirector. An uncontacted swing is cancelled;
## a completed log finishes its authoritative inventory/cash/Earth settlement so
## restoring cannot duplicate or lose rewards.
func prepare_for_suspend() -> void:
	# A tween cannot be serialized. Canonicalize the claimed root onto the block
	# before the save is assembled so restore never strands an airborne pose.
	_finish_active_run_handoff()
	_finish_boss_stack_drop()
	_settle_xp_presentations()
	_pending.clear()
	if _axe != null and _axe.is_swinging():
		if _axe.has_method("cancel_swing"):
			_axe.call("cancel_swing")
	_animator.finish_for(_on_block)
	_apply_pending_descriptor_power_cuts()
	if _awaiting_finished_settlement:
		_settle_finished_firewood(false)
	# Completed-piece visuals are intentionally not persisted. Their rewards are
	# canonical now, so a restore starts visually clean rather than replaying an
	# already-paid farewell.
	_clear_finished_firewood()
	if _coin_reward_pool != null and _coin_reward_pool.has_method("settle_all"):
		_coin_reward_pool.settle_all()


## Run XP is already safe in RunDirector. At a suspend boundary, canonically
## deliver every outstanding visual share so a restored attempt neither loses a
## receipt nor replays one from before the save.
func _settle_xp_presentations() -> void:
	for orb: XPOrb in _xp_orb_pool:
		if is_instance_valid(orb) and orb.is_processing():
			orb.settle_immediately(false)
	for burst: Dictionary in _queued_xp_bursts:
		var amount := maxi(0, int(burst.get("amount", 0)))
		if amount > 0:
			xp_orb_collected.emit(amount, int(burst.get("tier", 0)))
	_queued_xp_bursts.clear()


## A new run has a different presentation authority. Stale orbs are returned
## silently; the HUD's run-identity reset paints the new authoritative total.
func cancel_xp_presentations() -> void:
	_queued_xp_bursts.clear()
	for orb: XPOrb in _xp_orb_pool:
		if not is_instance_valid(orb):
			continue
		if orb.is_processing() or orb.get_parent() != _xp_orb_pool_root:
			orb.cancel_collection()
			if is_instance_valid(_xp_orb_pool_root) \
					and orb.get_parent() != _xp_orb_pool_root:
				orb.reparent(_xp_orb_pool_root)


func cancel_reward_presentations() -> void:
	cancel_xp_presentations()
	if _coin_reward_pool != null and _coin_reward_pool.has_method("cancel_all"):
		_coin_reward_pool.cancel_all()


func to_run_save_dict() -> Dictionary:
	# Autosave is observational. The authoritative root already waits, hidden, at
	# its exact landing transform while the separate presentation snapshot flies;
	# serialize that canonical root without touching the live tween or emitting
	# run_log_ready. Explicit suspend calls prepare_for_suspend() first when it
	# intentionally needs to finish all presentation before leaving the scene.
	if _current_descriptor == null or _on_block.is_empty():
		return {"transitioning": true}
	var pieces: Array[Dictionary] = []
	for piece: Area3D in _on_block:
		pieces.append({
			"id": StringName(piece.get_meta("stable_piece_id", &"")),
			"transform": piece.global_transform,
			"projection_offset": piece.get_meta("projection_offset", Vector3.ZERO),
			"scar_records": _scar_records_on(piece),
		})
	return {
		"transitioning": false,
		"handoff_active": _run_handoff_active,
		"descriptor": _current_descriptor.to_dict(),
		"cut_journal": _cut_journal.duplicate(true),
		"pieces": pieces,
		"grain_offered": _grain_offered_this_log,
		"grain_offer_count": _grain_offer_count_this_log,
		"grain_cue": _grain_cue_save_dict(),
		"pending_power_cuts": _pending_descriptor_power_cuts,
		"pending_power_cut_sources": _serialized_power_cut_sources(
			_pending_descriptor_power_cut_sources),
	}


func restore_run_save_dict(data: Dictionary) -> void:
	if data.is_empty() or bool(data.get("transitioning", false)):
		clear_run_log()
		call_deferred("_emit_block_ready")
		return
	var descriptor_data: Variant = data.get("descriptor", {})
	if not (descriptor_data is Dictionary):
		call_deferred("_emit_block_ready")
		return
	var descriptor := LogDescriptor.from_save_dict(descriptor_data)
	var restored_handoff := bool(data.get("handoff_active", false))
	# Staging and journal replay normally probe Grain Reader on fresh pieces.
	# Restore reconstructs the saved mark and must not spend another RNG roll.
	_restoring_run_log = true
	stage_run_log(descriptor, false)
	_animator.finish_for(_on_block)
	_cut_journal.clear()
	var journal: Variant = data.get("cut_journal", [])
	if journal is Array:
		for raw: Variant in journal:
			if raw is Dictionary and _replay_cut(raw):
				_cut_journal.append((raw as Dictionary).duplicate(true))
	var saved_pieces: Variant = data.get("pieces", [])
	if saved_pieces is Array:
		for raw: Variant in saved_pieces:
			if not (raw is Dictionary):
				continue
			var piece := _piece_by_stable_id(StringName(raw.get("id", "")))
			if piece == null:
				continue
			piece.global_transform = raw.get("transform", piece.global_transform)
			piece.set_meta("projection_offset",
				raw.get("projection_offset", Vector3.ZERO))
			_restore_scar_records(piece, raw.get("scar_records", []), Vector3.ZERO)
	_grain_offered_this_log = bool(data.get("grain_offered", false))
	_grain_offer_count_this_log = maxi(0,
		int(data.get("grain_offer_count", 1 if _grain_offered_this_log else 0)))
	_pending_descriptor_power_cuts = maxi(0,
		int(data.get("pending_power_cuts", 0)))
	_pending_descriptor_power_cut_sources.clear()
	var raw_cut_sources: Variant = data.get("pending_power_cut_sources", [])
	if raw_cut_sources is Array:
		for raw_source: Variant in raw_cut_sources:
			if _pending_descriptor_power_cut_sources.size() \
					>= _pending_descriptor_power_cuts:
				break
			if raw_source is String or raw_source is StringName:
				var source := StringName(raw_source)
				if source != &"":
					_pending_descriptor_power_cut_sources.append(source)
	while _pending_descriptor_power_cut_sources.size() \
			< _pending_descriptor_power_cuts:
		_pending_descriptor_power_cut_sources.push_front(&"precut")
	_clear_grain_cue(&"restored")
	_restore_grain_cue(data.get("grain_cue", {}))
	_restoring_run_log = false
	if _pending_descriptor_power_cuts > 0 or restored_handoff:
		call_deferred("_finish_restored_run_log", restored_handoff)


## An autosave may observe a claimed root while only its presentation snapshot is
## airborne. Restore canonicalizes that unpersistable flight to the already-saved
## landing transform, applies the exact pending cuts once, then releases boundary
## timers only if a choppable root survived those arrival cuts.
func _finish_restored_run_log(restored_handoff: bool) -> void:
	_apply_pending_descriptor_power_cuts()
	if restored_handoff and not _on_block.is_empty() \
			and not _awaiting_finished_settlement:
		run_log_ready.emit()


func _serialized_power_cut_sources(sources: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for source: StringName in sources:
		out.append(String(source))
	return out


func _grain_cue_save_dict() -> Dictionary:
	if _grain_target == null or not is_instance_valid(_grain_target) \
			or _grain_target not in _on_block or _grain_target_mesh == null:
		return {}
	var stable_piece_id := StringName(
		_grain_target.get_meta("stable_piece_id", &""))
	if stable_piece_id == &"" or _grain_offer_source != &"grain_reader":
		return {}
	return {
		"target_piece_id": String(stable_piece_id),
		"local_plane": _grain_local_plane,
		"local_anchor": _grain_local_anchor,
		"source": String(_grain_offer_source),
	}


func _restore_grain_cue(raw: Variant) -> void:
	if not (raw is Dictionary) or not _grain_offered_this_log:
		return
	var saved := raw as Dictionary
	var raw_plane: Variant = saved.get("local_plane", null)
	var raw_anchor: Variant = saved.get("local_anchor", null)
	if not (raw_plane is Plane) or not (raw_anchor is Vector3):
		return
	var source := StringName(saved.get("source", ""))
	if source != &"grain_reader":
		return
	var target := _piece_by_stable_id(StringName(
		saved.get("target_piece_id", "")))
	if target == null:
		return
	var mesh: Mesh = target.get_meta("mesh_ref")
	if mesh == null:
		return
	_grain_target = target
	_grain_target_mesh = mesh
	_grain_local_plane = raw_plane as Plane
	_grain_local_anchor = raw_anchor as Vector3
	_grain_offer_source = source
	_grain_candidate_dirty = false
	if not _grain_plane_is_valid():
		_clear_grain_cue(&"invalid_restore")
		return
	var world_plane := MeshUtils.plane_to_world(
		_grain_local_plane, target.global_transform)
	_build_grain_top_mark(target, target.to_global(_grain_local_anchor),
		world_plane.normal)


func _emit_block_ready() -> void:
	block_ready_for_log.emit()


func _replay_cut(entry: Dictionary) -> bool:
	var parent_id := StringName(entry.get("piece_id", ""))
	var piece := _piece_by_stable_id(parent_id)
	var local_plane: Plane = entry.get("local_plane", Plane())
	if piece == null:
		return false
	var mesh: Mesh = piece.get_meta("mesh_ref")
	var result := MeshSlicer.slice(mesh, local_plane, _cut_mat)
	if result.above == null or result.below == null:
		return false
	result.above = _jag_cut(result.above, local_plane)
	result.below = _jag_cut(result.below, local_plane)
	var inherited_projection: Vector3 = piece.get_meta("projection_offset", Vector3.ZERO)
	_on_block.erase(piece)
	piece.queue_free()
	for half_index in range(2):
		var half: ArrayMesh = result.above if half_index == 0 else result.below
		var aabb := half.get_aabb()
		var center := aabb.position + aabb.size * 0.5
		var centered := _translate_mesh(half, -center)
		if _mesh_is_firewood(centered):
			continue
		_make_stay_piece(centered, Vector3.ZERO, 0.0, false,
			inherited_projection + center,
			StringName("%s/%s" % [parent_id, "a" if half_index == 0 else "b"]))
	return true


func _piece_by_stable_id(id: StringName) -> Area3D:
	for piece: Area3D in _on_block:
		if StringName(piece.get_meta("stable_piece_id", &"")) == id:
			return piece
	return null


func _mesh_is_firewood(mesh: Mesh) -> bool:
	var size := mesh.get_aabb().size
	var volume := size.x * size.y * size.z
	var horizontal_max := maxf(size.x, size.z)
	var horizontal_min := maxf(minf(size.x, size.z), 0.0001)
	return volume <= min_vol or horizontal_max / horizontal_min > aspect_limit


## Build every procedural VFX mesh/material cache during the initial scene load,
## while the startup screen still covers the yard. Smoke, coins and the heavier
## level-up effect own complete node pools; short-lived effects reuse warmed resources.
func _prewarm_vfx_geometry() -> void:
	XPOrb.prewarm()
	_xp_orb_pool_root = Node3D.new()
	_xp_orb_pool_root.name = "XPOrbPool"
	add_child(_xp_orb_pool_root)
	# Prewarm the authored maximum once. XP is authoritative before presentation,
	# so overlapping batches may queue visually but can never lose progression.
	var capacity := xp_pacing_config.orb_pool_capacity if xp_pacing_config != null else 32
	for i in range(maxi(capacity, 1)):
		var orb := XPOrb.new()
		orb.name = "XPOrb%d" % i
		_xp_orb_pool_root.add_child(orb)
		orb.prepare_for_pool()
		orb.collected.connect(_on_pooled_xp_orb_collected.bind(orb))
		_xp_orb_pool.append(orb)
	_level_up_vfx = _LevelUpBurst.create_prewarmed(self, maxf(0.3, _stump_radius * 1.08))
	_coin_reward_pool = _CoinRewardPool.new()
	_coin_reward_pool.name = "CoinRewardPool"
	add_child(_coin_reward_pool)
	_coin_reward_pool.initialize(_camera)
	_coin_reward_pool.set_stump_collider(
		get_node_or_null("StumpBody/StumpCollision") as CollisionShape3D,
		_stump_radius)
	_coin_reward_pool.batch_started.connect(coin_batch_started.emit)
	_coin_reward_pool.coin_collected.connect(coin_collected.emit)
	_coin_reward_pool.coins_cancelled.connect(coins_cancelled.emit)
	_coin_reward_pool.batch_finished.connect(coin_batch_finished.emit)
	_shared_splinter_projectile_mesh().get_rid()
	_grain_unit_line_mesh().get_rid()
	for material: Material in _grain_mark_materials():
		material.get_rid()
	_SCAR_NORMAL.get_rid()
	_scar_projection_material().get_rid()


## Called by Main only while the opaque startup screen is still on top. These
## nodes are already resident; briefly making one instance of every surface
## drawable moves renderer pipeline compilation off the first chop/level frame.
func begin_initial_vfx_render_warmup() -> void:
	var warm_position := Vector3(0.0, _stump_top_y + 0.2, 0.0)
	if _level_up_vfx != null:
		_level_up_vfx.show_for_render_warmup(warm_position)
	if _coin_reward_pool != null:
		_coin_reward_pool.show_for_render_warmup(warm_position + Vector3.RIGHT * 0.12)
	if not _xp_orb_pool.is_empty():
		_xp_orb_pool[0].show_for_render_warmup(warm_position + Vector3.LEFT * 0.12)

	# Run powers can each carry a distinct shader and several use a solid action
	# silhouette. Submit every variant once behind the opaque startup screen so a
	# first in-run trigger never pays renderer pipeline compilation.
	var power_table := SurvivorsContent.run_powers()
	if power_table != null:
		var power_index := 0
		for definition: RunPowerDef in power_table.powers:
			if definition == null:
				continue
			var action := definition.id in [&"flying_wedge", &"crosscut_sweep",
				&"maul_drop", &"earthshaker", &"powder_keg",
				&"kindling_chain", &"stump_pulse", &"sawblade_halo",
				&"timber_burst"]
			var node := RunPowerBurst.spawn(self,
				warm_position + Vector3(float(power_index % 9) * 0.02,
					float(power_index / 9) * 0.02, 0.0), definition, "", null,
				action, 2.0, 0, 4.0)
			_render_warmup_nodes.append(node)
			power_index += 1


func end_initial_vfx_render_warmup() -> void:
	if _level_up_vfx != null:
		_level_up_vfx.hide_render_warmup()
	if _coin_reward_pool != null:
		_coin_reward_pool.hide_render_warmup()
	if not _xp_orb_pool.is_empty():
		_xp_orb_pool[0].hide_render_warmup()
	for node: Node in _render_warmup_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_render_warmup_nodes.clear()


## Called by YardHUD only after the final XP orb has visibly completed the bar.
## GameState still banks XP and its reward before the flight so a quit cannot
## lose progression; this method owns only the delayed celebration.
func present_level_gain(_level: int) -> void:
	# One award can cross several levels synchronously. Coalesce that transaction
	# into one stronger readable celebration instead of stacking identical lights.
	if _level_up_vfx_queued:
		return
	_level_up_vfx_queued = true
	_spawn_level_up_vfx.call_deferred()


func _spawn_level_up_vfx() -> void:
	_level_up_vfx_queued = false
	if not is_inside_tree() or _level_up_vfx == null:
		return
	# The effect surrounds the workpiece footprint at the top of the stump. It is
	# presentation only; the level was already awarded by GameState.
	_level_up_vfx.play_at(Vector3(0.0, _stump_top_y + 0.025, 0.0))
	AudioDirector.play_ui(&"level_up")


## A live mark reflects the current run power. Losing the effect clears the mark;
## gaining it waits for the next eligible piece-creation event.
func _refresh_grain_availability() -> void:
	if not _grain_cue_enabled():
		_clear_grain_cue(&"skill_unavailable")
	elif _run_power_effect(ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE) > 0.0 \
			and _grain_target == null and not _grain_offered_this_log:
		_try_show_grain_cue(_pick_grain_target(_on_block))


func _exit_tree() -> void:
	_clear_grain_cue(&"block_exit")
	AudioDirector.unregister_world_root(self)
	GameFeel.unregister_camera()


func _visibility_tuning() -> SurvivalRunTuning:
	if _run_director != null and _run_director.tuning != null:
		return _run_director.tuning
	return _SURVIVAL_TUNING as SurvivalRunTuning


## Open an invisible camera tunnel through loose roots and finished billets. The
## active Area3D pieces are never candidates and are force-restored to opaque on
## every pass, so their own split geometry cannot make itself disappear.
func _update_active_log_visibility_guard(delta: float = 0.0,
		snap := false) -> void:
	_force_active_log_opaque()
	var active_bounds := _active_log_screen_bounds()
	var count := 0
	var hidden_geometry_count := 0
	var arena := get_node_or_null("LooseLogArena")
	if arena != null:
		for candidate: Node in arena.get_children():
			if not (candidate is LooseLogBody):
				continue
			var body := candidate as Node3D
			var occludes := not active_bounds.is_empty() \
				and _node_occludes_active_log(body, active_bounds)
			if occludes:
				count += 1
			hidden_geometry_count += _set_visibility_tunnel_state(
				body, occludes, delta, snap)
	for raw_body: Variant in _firewood:
		var body := raw_body as RigidBody3D
		if not is_instance_valid(body):
			continue
		var occludes := not active_bounds.is_empty() \
			and _node_occludes_active_log(body, active_bounds)
		if occludes:
			count += 1
		hidden_geometry_count += _set_visibility_tunnel_state(
			body, occludes, delta, snap)
	for entry: Dictionary in _finished_firewood:
		var body := entry.get("body") as RigidBody3D
		if not is_instance_valid(body):
			continue
		var occludes := not active_bounds.is_empty() \
			and _node_occludes_active_log(body, active_bounds)
		if occludes:
			count += 1
		hidden_geometry_count += _set_visibility_tunnel_state(
			body, occludes, delta, snap)
	_chopping_visibility_occluder_count = count
	_chopping_visibility_hidden_geometry_count = hidden_geometry_count
	# A defensive second pass makes the invariant independent of future candidate
	# list changes or parent relationships.
	_force_active_log_opaque()


func _set_visibility_tunnel_state(root: Node3D, occludes: bool,
		delta: float, snap: bool) -> int:
	if root == null or not is_instance_valid(root) \
			or _root_contains_active_piece(root):
		return 0
	var arena := get_node_or_null("LooseLogArena")
	var loose_body := root as LooseLogBody
	if loose_body != null and arena != null:
		if occludes and arena.has_method(&"ensure_individual_visual"):
			arena.call(&"ensure_individual_visual", loose_body)
		elif not occludes and loose_body.batched_visual:
			return 0
	var tuning := _visibility_tuning()
	var hidden_value := tuning.chopping_visibility_tunnel_transparency \
		if tuning != null else 1.0
	var restore_speed := tuning.chopping_visibility_tunnel_restore_speed \
		if tuning != null else 10.0
	var meshes := _cached_visibility_meshes(root)
	var hidden_count := 0
	for mesh_instance: MeshInstance3D in meshes:
		if occludes:
			# The tunnel opens in the same frame as the obstruction. A fade-in could
			# still cover the block during the exact high-pressure moment it protects.
			mesh_instance.transparency = hidden_value
		else:
			mesh_instance.transparency = 0.0 if snap else move_toward(
				mesh_instance.transparency, 0.0,
				restore_speed * maxf(0.0, delta))
		if mesh_instance.transparency >= hidden_value - 0.001:
			hidden_count += 1
	if not occludes and loose_body != null and hidden_count == 0 \
			and arena != null and arena.has_method(&"try_batch_visual"):
		arena.call(&"try_batch_visual", loose_body)
	return hidden_count


func _root_contains_active_piece(root: Node) -> bool:
	for raw_piece: Variant in _on_block:
		var piece := raw_piece as Node
		if piece == null or not is_instance_valid(piece):
			continue
		if root == piece or root.is_ancestor_of(piece) \
				or piece.is_ancestor_of(root):
			return true
	return false


func _force_active_log_opaque() -> void:
	for raw_piece: Variant in _on_block:
		var piece := raw_piece as Node
		if piece == null or not is_instance_valid(piece):
			continue
		var meshes: Array[MeshInstance3D] = []
		_collect_visibility_meshes(piece, meshes)
		for mesh_instance: MeshInstance3D in meshes:
			mesh_instance.transparency = 0.0


func _active_log_screen_bounds() -> Dictionary:
	var roots: Array[Node3D] = []
	for raw_piece: Variant in _on_block:
		var piece := raw_piece as Node3D
		if is_instance_valid(piece) and piece.visible:
			roots.append(piece)
	var bounds := _screen_bounds_for_roots(roots)
	if bounds.is_empty():
		return bounds
	var tuning := _visibility_tuning()
	var margin := tuning.chopping_visibility_screen_margin \
		if tuning != null else 8.0
	bounds["rect"] = (bounds.get("rect") as Rect2).grow(margin)
	return bounds


func _node_occludes_active_log(root: Node3D,
		active_bounds: Dictionary) -> bool:
	if root == null or not is_instance_valid(root) or not root.visible:
		return false
	var local_bounds := _visibility_local_bounds(root)
	if local_bounds.size.length_squared() <= 0.000001:
		return false
	var centre := root.global_transform * (local_bounds.position \
		+ local_bounds.size * 0.5)
	if _camera.is_position_behind(centre):
		return false
	var basis := root.global_transform.basis
	var scale_max := maxf(basis.x.length(),
		maxf(basis.y.length(), basis.z.length()))
	var radius := local_bounds.size.length() * 0.5 * scale_max
	var centre_distance := _camera.global_position.distance_to(centre)
	# A candidate whose nearest corner is behind the active log's farthest corner
	# cannot hide any part of it. Using the far edge here deliberately favours a
	# harmless tunnel false-positive over losing even a sliver of the workpiece.
	if centre_distance - radius \
			>= float(active_bounds.get("far_distance", 0.0)) - 0.01:
		return false
	# A conservative projected bounding sphere needs three projections instead of
	# recursively projecting eight corners for every mesh of every loose root.
	var screen_centre := _camera.unproject_position(centre)
	var camera_basis := _camera.global_transform.basis
	var screen_right := _camera.unproject_position(
		centre + camera_basis.x.normalized() * radius)
	var screen_up := _camera.unproject_position(
		centre + camera_basis.y.normalized() * radius)
	var pixel_radius := maxf(screen_centre.distance_to(screen_right),
		screen_centre.distance_to(screen_up)) * 1.05
	var candidate_rect := Rect2(screen_centre - Vector2.ONE * pixel_radius,
		Vector2.ONE * pixel_radius * 2.0)
	var active_rect := active_bounds.get("rect") as Rect2
	return candidate_rect.intersects(active_rect, true)


func _cached_visibility_meshes(root: Node3D) -> Array[MeshInstance3D]:
	var cached: Variant = root.get_meta(&"visibility_meshes") \
		if root.has_meta(&"visibility_meshes") else null
	if cached is Array:
		var valid := true
		for raw_mesh: Variant in cached:
			if not is_instance_valid(raw_mesh):
				valid = false
				break
		if valid:
			return cached as Array[MeshInstance3D]
	var meshes: Array[MeshInstance3D] = []
	_collect_visibility_meshes(root, meshes)
	root.set_meta(&"visibility_meshes", meshes)
	return meshes


func _visibility_local_bounds(root: Node3D) -> AABB:
	var cached: Variant = root.get_meta(&"visibility_local_bounds") \
		if root.has_meta(&"visibility_local_bounds") else null
	if cached is AABB:
		return cached as AABB
	var found := false
	var bounds := AABB()
	var root_inverse := root.global_transform.affine_inverse()
	for instance: MeshInstance3D in _cached_visibility_meshes(root):
		if instance.mesh == null:
			continue
		var mesh_bounds := instance.mesh.get_aabb()
		var to_root := root_inverse * instance.global_transform
		for corner_index: int in range(8):
			var corner := to_root * Vector3(
				mesh_bounds.end.x if (corner_index & 1) != 0 else mesh_bounds.position.x,
				mesh_bounds.end.y if (corner_index & 2) != 0 else mesh_bounds.position.y,
				mesh_bounds.end.z if (corner_index & 4) != 0 else mesh_bounds.position.z)
			if not found:
				bounds = AABB(corner, Vector3.ZERO)
				found = true
			else:
				bounds = bounds.expand(corner)
	if found:
		root.set_meta(&"visibility_local_bounds", bounds)
	return bounds


func _screen_bounds_for_roots(roots: Array) -> Dictionary:
	if _camera == null or _camera.get_viewport() == null:
		return {}
	var min_screen := Vector2(INF, INF)
	var max_screen := Vector2(-INF, -INF)
	var near_distance := INF
	var far_distance := 0.0
	var found := false
	for raw_root: Variant in roots:
		var root := raw_root as Node
		if root == null or not is_instance_valid(root):
			continue
		var meshes: Array[MeshInstance3D] = []
		_collect_visibility_meshes(root, meshes)
		for mesh_instance: MeshInstance3D in meshes:
			if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
				continue
			var aabb := mesh_instance.mesh.get_aabb()
			for corner_index: int in range(8):
				var corner := Vector3(
					aabb.end.x if (corner_index & 1) != 0 else aabb.position.x,
					aabb.end.y if (corner_index & 2) != 0 else aabb.position.y,
					aabb.end.z if (corner_index & 4) != 0 else aabb.position.z)
				var world_corner := mesh_instance.global_transform * corner
				if _camera.is_position_behind(world_corner):
					continue
				var screen := _camera.unproject_position(world_corner)
				min_screen.x = minf(min_screen.x, screen.x)
				min_screen.y = minf(min_screen.y, screen.y)
				max_screen.x = maxf(max_screen.x, screen.x)
				max_screen.y = maxf(max_screen.y, screen.y)
				var corner_distance := _camera.global_position.distance_to(
					world_corner)
				near_distance = minf(near_distance, corner_distance)
				far_distance = maxf(far_distance, corner_distance)
				found = true
	if not found:
		return {}
	return {
		"rect": Rect2(min_screen, max_screen - min_screen),
		"near_distance": near_distance,
		"far_distance": far_distance,
	}


func _collect_visibility_meshes(node: Node,
		out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_visibility_meshes(child, out)


func debug_chopping_visibility_state() -> Dictionary:
	_update_active_log_visibility_guard(0.0, true)
	var active_max_transparency := 0.0
	for raw_piece: Variant in _on_block:
		var piece := raw_piece as Node
		if piece == null or not is_instance_valid(piece):
			continue
		var meshes: Array[MeshInstance3D] = []
		_collect_visibility_meshes(piece, meshes)
		for mesh_instance: MeshInstance3D in meshes:
			active_max_transparency = maxf(active_max_transparency,
				mesh_instance.transparency)
	var dome_state: Dictionary = {}
	var arena := get_node_or_null("LooseLogArena")
	if arena != null and arena.has_method(
			&"debug_chopping_visibility_dome_state"):
		dome_state = arena.call("debug_chopping_visibility_dome_state")
	return {
		"occluder_count": _chopping_visibility_occluder_count,
		"tunnel_hidden_geometry_count": \
			_chopping_visibility_hidden_geometry_count,
		"active_max_transparency": active_max_transparency,
		"active_self_hidden": active_max_transparency > 0.001,
		"active_piece_count": _on_block.size(),
		"dome": dome_state,
	}


func _process(delta: float) -> void:
	_animator.update()
	_update_active_log_visibility_guard(delta)
	_update_grain_cue()
	_update_log_smoke(delta)
	_update_run_power_orbits(delta)
	_update_finished_piece_sink(delta)

	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _hold_chop_active and GameState.has_meta_capability(
			MetaUpgradeDef.Capability.HOLD_TO_CHOP) and _pending.is_empty() \
			and (_axe == null or not _axe.is_swinging()) and _cooldown_left <= 0.0:
		_on_click(_hold_screen_pos)

	# The FAILSAFE, not the normal path: the axe's contact key resolves the strike
	# (_on_axe_contact). This only fires if that key never arrives — an animation
	# re-keyed without one, or no viewmodel in the scene at all — because a pending
	# strike that never resolves blocks every further click and stops the game dead.
	if not _pending.is_empty():
		_pending.timer -= delta
		if _pending.timer <= 0.0:
			_resolve_pending()

	if _awaiting_finished_settlement:
		_finished_batch_age += delta
		if _firewood_settled():
			_settle_finished_firewood()


func _firewood_settled() -> bool:
	var settle_limit := maxf(min_firewood_settle_timeout,
		firewood_settle_timeout)
	# This clock advances only from _process while chopping is enabled. A pause or
	# title-screen suspension therefore cannot consume the landing window and
	# freeze billets in mid-air on the first resumed frame.
	if _finished_batch_age >= settle_limit:
		return true
	for f in _firewood:
		if is_instance_valid(f) and (f as RigidBody3D).linear_velocity.length() > firewood_settle_speed:
			return false
	return true


## Retire a completed log's physics pieces in place. Rewards settle immediately,
## and the same sliced meshes (including scar projections) start their slow
## floor-sink on the next gameplay frame. The latch is cleared before any
## inventory/cash call so process and suspend cannot settle the batch twice.
func _settle_finished_firewood(emit_handoff := true) -> void:
	if not _awaiting_finished_settlement:
		return
	_awaiting_finished_settlement = false
	var finished_bodies: Array[RigidBody3D] = []
	for raw_body: Variant in _firewood:
		if not is_instance_valid(raw_body) or not (raw_body is RigidBody3D):
			continue
		var body := raw_body as RigidBody3D
		var source_mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			body.queue_free()
			continue
		# A billet can finish resting on another billet without touching Floor.
		# Give it its one impact cue before retiring physics; the metadata latch
		# keeps real floor contacts from playing twice.
		_play_firewood_impact_sfx(body)
		_retire_finished_body(body)
		finished_bodies.append(body)
	_firewood.clear()
	if _coin_reward_pool != null:
		_coin_reward_pool.trim_unpaid_to_count(finished_bodies.size())

	var species_id: StringName = &"" if _current_species == null else _current_species.id
	var yield_item: StringName = &"" if _current_species == null else _current_species.yield_item
	if yield_item != &"":
		for _body: RigidBody3D in finished_bodies:
			# Standalone chopping retains the original gather contract. Production
			# already has one root receipt in RunDirector and settles its prepared
			# per-piece cash shares below.
			if _run_director == null:
				EventBus.resource_gathered.emit(yield_item, 1)

	# Reward settlement is intentionally independent from the visual sink. Each
	# body carries its own exact-once latch before the authority call.
	for body: RigidBody3D in finished_bodies:
		_settle_finished_piece(body, yield_item)
		var geometry := _finished_geometry(body)
		_finished_firewood.append({
			"body": body,
			"geometry": geometry,
			"top_offset": _finished_geometry_top_offset(body, geometry),
			"age": _finished_batch_age,
			"start_y": body.global_position.y,
		})
	log_completed.emit(species_id, finished_bodies.size())

	# XP was awarded at the final split. The block may accept the next root now;
	# sinking pieces are collisionless presentation and never delay gameplay.
	if not emit_handoff:
		_current_descriptor = null
		return
	if _external_log_flow:
		block_ready_for_log.emit()
	else:
		_spawn_fresh_log(false)


func _retire_finished_body(body: RigidBody3D) -> void:
	body.freeze = true
	body.sleeping = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.collision_layer = 0
	body.collision_mask = 0
	body.contact_monitor = false
	body.max_contacts_reported = 0
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	if body.get_parent() != _finished_firewood_root:
		body.reparent(_finished_firewood_root, true)
	for geometry: GeometryInstance3D in _finished_geometry(body):
		geometry.transparency = 0.0
		geometry.visible = true


func _settle_finished_piece(body: RigidBody3D, item_id: StringName) -> void:
	if not is_instance_valid(body) \
			or bool(body.get_meta("finished_piece_settled", false)):
		return
	# Latch before any signal or inventory call: a zero payout is valid and must
	# never be mistaken for evidence that settlement did not happen.
	body.set_meta("finished_piece_settled", true)
	if not auto_sell:
		return
	var payout := _run_director.settle_completed_piece(item_id) \
		if _run_director != null and item_id != &"" else 0
	if payout > 0 and _coin_reward_pool != null:
		_coin_reward_pool.queue_payout(payout)
	elif _coin_reward_pool != null:
		_coin_reward_pool.cancel_next_unpaid()


func _finished_geometry(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	_collect_finished_geometry(root, out)
	return out


func _collect_finished_geometry(node: Node,
		out: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		out.append(node as GeometryInstance3D)
	for child: Node in node.get_children():
		_collect_finished_geometry(child, out)


## Once physics retires, the collisionless rigid-body owner immediately moves
## downward at a data-backed rate until every visible vertex is below the yard
## floor. Camera-tunnel transparency remains an independent presentation layer.
func _update_finished_piece_sink(delta: float) -> void:
	var hold_seconds := float(_SURVIVAL_TUNING.finished_piece_hold_seconds)
	var sink_speed := maxf(0.001,
		float(_SURVIVAL_TUNING.finished_piece_sink_speed))
	for index in range(_finished_firewood.size() - 1, -1, -1):
		var entry: Dictionary = _finished_firewood[index]
		var body := entry.get("body") as RigidBody3D
		if not is_instance_valid(body):
			_finished_firewood.remove_at(index)
			continue
		if bool(entry.get("settling", false)):
			var settle_age := float(entry.get("settle_age", 0.0)) \
				+ maxf(0.0, delta)
			if settle_age >= firewood_settle_timeout \
					or (settle_age >= min_firewood_settle_timeout \
					and body.linear_velocity.length() <= firewood_settle_speed):
				_play_firewood_impact_sfx(body)
				_retire_finished_body(body)
				entry["settling"] = false
				entry["settle_age"] = settle_age
				entry["age"] = 0.0
				entry["start_y"] = body.global_position.y
				var geometry := _finished_geometry(body)
				entry["geometry"] = geometry
				entry["top_offset"] = _finished_geometry_top_offset(body, geometry)
			else:
				entry["settle_age"] = settle_age
			_finished_firewood[index] = entry
			continue
		var age := float(entry.get("age", 0.0)) + maxf(0.0, delta)
		var previous_age := float(entry.get("age", 0.0))
		var sink_delta := maxf(0.0, age - maxf(previous_age, hold_seconds))
		if sink_delta > 0.0:
			body.global_position.y -= sink_speed * sink_delta
		var top_offset := float(entry.get("top_offset", INF))
		if not is_finite(top_offset):
			var geometry: Array = entry.get("geometry", []) as Array
			top_offset = _finished_geometry_top_offset(body, geometry)
			entry["top_offset"] = top_offset
		if age > hold_seconds \
				and body.global_position.y + top_offset < reward_ground_y:
			body.queue_free()
			_finished_firewood.remove_at(index)
		else:
			entry["age"] = age
			_finished_firewood[index] = entry


## Finished bodies only translate while sinking. Cache their highest vertex once
## when physics retires instead of recursively walking geometry and transforming
## every AABB corner on every frame of the sink.
func _finished_geometry_top_offset(body: RigidBody3D,
		geometry: Array) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0
	var top_y := body.global_position.y
	for raw_geometry: Variant in geometry:
		var instance := raw_geometry as MeshInstance3D
		if instance == null or not is_instance_valid(instance) \
				or instance.mesh == null:
			continue
		var aabb := instance.mesh.get_aabb()
		for corner_index: int in range(8):
			var corner := Vector3(
				aabb.end.x if (corner_index & 1) != 0 else aabb.position.x,
				aabb.end.y if (corner_index & 2) != 0 else aabb.position.y,
				aabb.end.z if (corner_index & 4) != 0 else aabb.position.z)
			top_y = maxf(top_y, (instance.global_transform * corner).y)
	return top_y - body.global_position.y


func _clear_finished_firewood() -> void:
	for entry: Dictionary in _finished_firewood:
		var body := entry.get("body") as RigidBody3D
		if is_instance_valid(body):
			body.queue_free()
	_finished_firewood.clear()
	if _finished_firewood_root != null:
		for child: Node in _finished_firewood_root.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				child.queue_free()


func debug_finished_piece_state() -> Dictionary:
	var min_age := INF
	var max_age := 0.0
	var max_sink_distance := 0.0
	var max_transparency := 0.0
	var geometry_count := 0
	var collision_shape_count := 0
	var enabled_collision_count := 0
	var settling_count := 0
	for entry: Dictionary in _finished_firewood:
		if bool(entry.get("settling", false)):
			settling_count += 1
		var age := float(entry.get("age", 0.0))
		min_age = minf(min_age, age)
		max_age = maxf(max_age, age)
		var body := entry.get("body") as RigidBody3D
		if is_instance_valid(body):
			max_sink_distance = maxf(max_sink_distance,
				float(entry.get("start_y", body.global_position.y))
					- body.global_position.y)
			for child: Node in body.get_children():
				if child is CollisionShape3D:
					collision_shape_count += 1
					if not (child as CollisionShape3D).disabled:
						enabled_collision_count += 1
		var geometry_nodes: Array = entry.get("geometry", [])
		for raw_geometry: Variant in geometry_nodes:
			var geometry := raw_geometry as GeometryInstance3D
			if is_instance_valid(geometry):
				geometry_count += 1
				max_transparency = maxf(max_transparency,
					geometry.transparency)
	return {
		"count": _finished_firewood.size(),
		"geometry_count": geometry_count,
		"collision_shape_count": collision_shape_count,
		"enabled_collision_count": enabled_collision_count,
		"settling_count": settling_count,
		"min_age": 0.0 if _finished_firewood.is_empty() else min_age,
		"max_age": max_age,
		"max_sink_distance": max_sink_distance,
		"max_transparency": max_transparency,
	}


## The finished manual log's one root XP transaction. Experience is per log,
## not per piece (Creative Director call, 2026-08-02: the
## orbs drop "when the log is finally split"). ONE award, fired from the split that
## empties the block — the same instant the orbs burst, so the number going up and
## the thing on screen are one event rather than two.
##
## Gated on `auto_sell` with the cash payout: that flag means "the yard's payouts
## are live", and chopping_acceptance switches it off because it tests the yield
## contract and must not have the economy moving underneath it.
func _award_log_xp(automatic := false) -> void:
	if not auto_sell or _current_species == null:
		return
	_manual_log_serial += 1
	var root_id := _current_descriptor.id \
		if _current_descriptor != null and _current_descriptor.id != &"" \
		else StringName("manual_log_%d_%d_%d" % [
			_manual_log_session_nonce, get_instance_id(), _manual_log_serial])
	_current_manual_log_root_id = root_id
	var base_xp := _current_species.xp_reward
	if _run_director != null and _current_descriptor != null:
		base_xp = _run_director.xp_reward_for(_current_descriptor)
	if automatic:
		# A power cut owns this completion. Commit the same exact root receipt and
		# presentation, but never route through manual-only procs/signals.
		var automatic_xp := _run_director.award_root_xp(
			_current_descriptor, base_xp) if _run_director != null \
				and _current_descriptor != null else 0
		if automatic_xp > 0:
			_burst_xp_orbs(automatic_xp,
				Vector3(0.0, _stump_top_y + 0.12, 0.0), false)
		return
	_resolve_log_xp(root_id, base_xp)


func _resolve_log_xp(root_event_id: StringName, base_xp: int) -> int:
	if root_event_id == &"" or base_xp <= 0:
		return 0
	var handled_id: StringName = root_event_id
	if _run_director != null and _run_director.get_run_id() != &"":
		handled_id = StringName("%s::%s" % [
			_run_director.get_run_id(), root_event_id])
	if _handled_log_roots.has(handled_id):
		return 0
	# A completed root is consumed before source eligibility is considered. A
	# restored/automated id cannot be resubmitted later wearing a "manual" label.
	# Root ids repeat from one attempt to the next, so the run identity is part of
	# this local exact-once key without changing the descriptor's descendant path.
	_handled_log_roots[handled_id] = true
	var awarded := base_xp
	if _run_director != null:
		if _current_descriptor == null \
				or root_event_id != _current_descriptor.id:
			return 0
		awarded = _run_director.award_root_xp(_current_descriptor, awarded)
	else:
		return 0
	# A completed log keeps its final wood-impact cue silent and does not layer
	# the generic XP-launch cue over it. Other reward sources still use that cue.
	_burst_xp_orbs(awarded, Vector3(0.0, _stump_top_y + 0.12, 0.0), false)
	return awarded


## The green orbs, Minecraft-style: they pop off the block and are drawn into the
## live fill edge of the XP bar.
##
## THE XP IS ALREADY AUTHORITATIVE by the time these spawn, and deliberately so — see
## xp_orb.gd. Quitting during the second of flight must not cost the player the log
## they just chopped. The orbs are the receipt, not the payment.
##
## They burst, bounce on the floor beside the block and lie there a beat before
## being drawn in (Creative Director call, 2026-08-02) — so the stump's own radius
## and the yard floor go with them, and they land NEAR the log rather than on it.
##
## Count is logarithmic in the exact final award. At the cap, scale and halo
## reach keep larger jackpots visibly stronger without allocating more nodes.
func _burst_xp_orbs(amount: int, from := Vector3(0.0, _stump_top_y + 0.12, 0.0),
		play_launch_audio := true) -> void:
	if not orbs_enabled or _camera == null or amount <= 0:
		return
	xp_orb_batch_started.emit(amount)
	if not _launch_xp_orb_burst(amount, from, play_launch_audio):
		var reward_config := GameConfig.current().reward_bursts
		_queued_xp_bursts.append({
			"amount": amount,
			"from": from,
			"play_launch_audio": play_launch_audio,
			"tier": reward_config.tier_for_amount(
				RewardBurstConfig.Kind.XP, amount),
		})


## Launch one complete presentation receipt using however many pooled nodes are
## currently free. Re-denominating the token plan keeps the collected shares
## equal to the authoritative award even when overlapping bursts occupy part of
## the pool.
func _launch_xp_orb_burst(amount: int, from: Vector3,
		play_launch_audio: bool) -> bool:
	var config := xp_pacing_config if xp_pacing_config != null else XPPacingConfig.new()
	var shares := config.orb_shares_for_xp(amount)
	var desired_count := shares.size()
	var acquired: Array[XPOrb] = []
	for _index: int in range(desired_count):
		var orb := _acquire_xp_orb()
		if orb == null:
			break
		acquired.append(orb)
	if acquired.is_empty():
		return false
	var count := acquired.size()
	var reward_config := GameConfig.current().reward_bursts
	var tokens := reward_config.plan_tokens(RewardBurstConfig.Kind.XP, amount, count)
	var cap_growth := config.capped_burst_growth(amount)
	var visual_scale := 1.0 + cap_growth * config.capped_scale_growth
	var halo_scale := 1.0 + cap_growth * config.capped_intensity_growth
	if play_launch_audio:
		AudioDirector.play_reward(&"xp", reward_config.tier_for_amount(
			RewardBurstConfig.Kind.XP, amount), &"launch")
	for i in range(count):
		var orb := acquired[i]
		var token: Dictionary = tokens[i]
		orb.setup(from, _camera, float(i) * orb_stagger, orb_scatter_radius,
			reward_ground_y, _stump_radius, orb_collect_at,
			int(token.amount), _xp_screen_target,
			visual_scale, halo_scale, int(token.tier))
	return true


func _acquire_xp_orb() -> XPOrb:
	for orb: XPOrb in _xp_orb_pool:
		if orb.get_parent() == _xp_orb_pool_root and orb.is_available():
			orb.reparent(self)
			return orb
	return null


func _on_pooled_xp_orb_collected(amount: int, tier: int, orb: XPOrb) -> void:
	xp_orb_collected.emit(amount, tier)
	_return_xp_orb_to_pool.call_deferred(orb)


func _return_xp_orb_to_pool(orb: XPOrb) -> void:
	if is_instance_valid(orb) and is_instance_valid(_xp_orb_pool_root) \
			and orb.get_parent() != _xp_orb_pool_root:
		orb.reparent(_xp_orb_pool_root)
	if not _queued_xp_bursts.is_empty():
		_drain_queued_xp_bursts.call_deferred()


func _drain_queued_xp_bursts() -> void:
	while not _queued_xp_bursts.is_empty():
		var burst: Dictionary = _queued_xp_bursts.front()
		if not _launch_xp_orb_burst(int(burst.get("amount", 0)),
				burst.get("from", Vector3.ZERO),
				bool(burst.get("play_launch_audio", true))):
			return
		_queued_xp_bursts.pop_front()


# --------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT: _orbit(-1)
			KEY_D, KEY_RIGHT: _orbit(1)
			KEY_R:
				if not _external_log_flow:
					_spawn_fresh_log()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_hold_chop_active = true
			_hold_screen_pos = event.position
			_on_click(event.position)
		else:
			_hold_chop_active = false
	elif event is InputEventMouseMotion and _hold_chop_active:
		_hold_screen_pos = event.position


func _on_click(screen_pos: Vector2) -> void:
	if _orbit_tween != null and _orbit_tween.is_valid() and _orbit_tween.is_running():
		return
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
## means "cut this piece" and is what `debug_slice_world` and chopping_acceptance
## drive, so those keep testing geometry rather than luck.
##
## Deliberately does NOT clear a live grain cue just because a DIFFERENT piece was
## struck — the mark is PERMANENT and stays wherever it is until it is taken or a
## real lifecycle edge removes it (see _clear_grain_cue's callers); chopping
## around the yard must not sweep away an opportunity sitting on another piece.
##
## `is_bonus` marks a run-power repeat swing. Bonus swings cannot recursively
## trigger another run-power sequence.
func _resolve_strike(piece: Area3D, world_point: Vector3, normal: Vector3, dir_enum: int,
		local_override: Variant = null, is_bonus: bool = false) -> bool:
	var split: bool
	var run_sequence_cuts := 0
	if _roll_splits(piece):
		split = _perform_split(piece, world_point, normal, dir_enum, local_override)
		strike_resolved.emit(split)
		if split and not is_bonus:
			run_sequence_cuts = 1
			run_sequence_cuts += _attempt_run_double_chop()
			if _run_director != null and _run_director.has_method(
					"trigger_splinter_volley"):
				_run_director.call("trigger_splinter_volley", world_point)
	else:
		# It bit, it did not go through. Mark the wood and make the next swing
		# into this piece more likely — the pity bonus, worn where the player
		# can see it.
		piece.set_meta("scars", _scars_on(piece) + 1)
		_add_scar(piece, world_point, normal)
		# Shake WITHOUT the hit-pause: a split keeps the time-stop to itself, so
		# the two outcomes feel different before the player has read a number.
		GameFeel.register_impact(fail_impact, false)
		_play_sfx(thud_sfx)
		AudioDirector.play_world(&"wood_thud", world_point)
		strike_resolved.emit(false)
		split = false

	if not is_bonus:
		run_sequence_cuts += _attempt_run_follow_up(piece, normal, dir_enum)
		if _run_director != null and _run_director.has_method(
				"on_manual_strike_resolved"):
			_run_director.call("on_manual_strike_resolved", split, world_point,
				run_sequence_cuts)
	return split


## Deep Bite and the other passive reliability powers alter the root swing;
## Double Chop is different: its SET count is a guaranteed number of additional
## real MeshSlicer cuts after a successful manual strike, from rank one onward.
func _attempt_run_double_chop() -> int:
	var count := maxi(0, int(round(_run_power_effect(
		ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS))))
	if count <= 0:
		return 0
	var block_cuts := apply_run_power_cuts(&"double_chop", count, &"largest")
	var spilled_cuts := 0
	var remaining := maxi(0, count - block_cuts)
	if remaining > 0 and _run_director != null and _run_director.has_method(
			"destroy_run_power_logs"):
		spilled_cuts = maxi(0, int(_run_director.call("destroy_run_power_logs",
			&"double_chop", remaining, Vector3.ZERO, &"endangered")))
	var total_cuts := block_cuts + spilled_cuts
	if total_cuts > 0 and _run_director != null and _run_director.has_method(
			"record_run_power_trigger"):
		_run_director.call("record_run_power_trigger", &"double_chop",
			Vector3(0.0, _stump_top_y, 0.0), total_cuts, block_cuts <= 0)
	# Only immediate cuts belong to this manual sequence for Earthshaker. Spilled
	# work becomes a real cut when that loose descriptor reaches the block.
	return block_cuts


## Follow-Up is one saved-RNG roll per landed manual swing. When it fires, the
## authored depth is the number of repeat swings; each repeat rolls ordinary
## reliability and may scar instead of cleave, but cannot recurse into another
## run-power chain because `is_bonus` is true.
func _attempt_run_follow_up(piece: Area3D, normal: Vector3, dir_enum: int) -> int:
	var chance := clampf(_run_power_effect(
		ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE), 0.0, 1.0)
	var depth := maxi(0, int(round(_run_power_effect(
		ProgressionEffectDef.Kind.FOLLOW_UP_DEPTH))))
	if chance <= 0.0 or depth <= 0 or _run_director == null:
		return 0
	var fires := debug_force_proc == 1
	if debug_force_proc < 0 and _run_director.has_method("roll_run_power_chance"):
		fires = bool(_run_director.call(
			"roll_run_power_chance", &"follow_up", chance))
	if not fires:
		return 0
	var split_count := 0
	var repeat_count := 0
	var preferred := piece
	for repeat_index: int in range(depth):
		var target := _pick_bonus_target(preferred)
		preferred = null
		if target == null:
			break
		var point := target.global_position
		if not _bonus_cut_preflight(target, point, normal):
			break
		var mesh: Mesh = target.get_meta("mesh_ref")
		var height := mesh.get_aabb().size.y if mesh != null else 0.2
		var burst_point := point + Vector3.UP * (height * 0.5 + 0.05)
		_swing_axe(point, normal)
		repeat_count += 1
		if _resolve_strike(target, point, normal, dir_enum, null, true):
			split_count += 1
		present_run_power_trigger(&"follow_up", burst_point, repeat_index + 1)
	if repeat_count > 0 and _run_director.has_method(
			"record_run_power_trigger"):
		_run_director.call("record_run_power_trigger", &"follow_up",
			piece.global_position if is_instance_valid(piece) else Vector3.ZERO,
			repeat_count, false)
	return split_count


## A repeat swing gives the just-struck piece first refusal, then falls back to
## the deterministic largest remaining block piece.
func _pick_bonus_target(preferred: Area3D) -> Area3D:
	if preferred != null and is_instance_valid(preferred) and preferred in _on_block:
		return preferred
	return _pick_double_strike_target()


## Deterministic continuation target: the largest on-block piece by measured
## volume. `_on_block` only ever holds live, script-animated stays — never a
## settling or fading firewood piece — so any entry here already satisfies the
## requirement that repeat swings never select settling or consumed pieces.
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
## queue_free'd, nothing joins _on_block, and no signal fires.
func _bonus_cut_preflight(piece: Area3D, world_point: Vector3, normal: Vector3) -> bool:
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


# ------------------------------------------------ Grain Reader opportunity
##
## Grain Reader rolls once per fresh on-block piece. A successful mark is
## permanent until cut, never forces a camera turn, and latches off for the rest
## of that root so marks cannot relocate or stack.
func _grain_cue_enabled() -> bool:
	return _run_power_effect(ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE) > 0.0


func _try_show_grain_cue(target: Area3D) -> void:
	if _restoring_run_log:
		return
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
	var run_chance := clampf(_run_power_effect(
		ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE), 0.0, 1.0)
	if run_chance <= 0.0:
		return
	var offered := debug_force_grain == 1
	if debug_force_grain < 0 and _run_director != null \
			and _run_director.has_method("roll_run_power_chance"):
		offered = bool(_run_director.call(
			"roll_run_power_chance", &"grain_reader", run_chance))
	if not offered:
		return

	_grain_target = target
	_grain_target_mesh = mesh
	_grain_local_plane = local_plane
	_grain_candidate_dirty = false
	_grain_offered_this_log = true
	_grain_offer_count_this_log += 1
	_grain_offer_source = &"grain_reader"

	# The sliver guard may shift the precomputed plane away from the requested
	# centre. Place the mark on that FINAL plane, never on the earlier intention.
	var candidate_world_point: Vector3 = target.global_transform * (
		local_plane.normal * local_plane.d)
	var top_y := target.global_position.y + mesh.get_aabb().size.y * 0.5 \
		+ float(_grain_cue_config.surface_lift)
	var world_anchor := Vector3(candidate_world_point.x, top_y, candidate_world_point.z)
	_grain_local_anchor = target.to_local(world_anchor)
	_build_grain_top_mark(target, world_anchor, world_plane.normal)
	AudioDirector.play_world(&"grain_cue", world_anchor)


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
	var tolerance: float = _grain_cue_config.candidate_tolerance
	for half: Mesh in [result.above, result.below]:
		var size := half.get_aabb().size
		if minf(size.x, size.z) <= tolerance:
			return false
	return true


## Three raised pigment slashes on the piece's TOP surface, parented to the piece
## so they move with it: a dark edge (readable on pale bark), a breathing warm
## middle and a solid gold core. GOLD IS
## Gold is authored identity for the world opportunity, independent of the run
## power's trigger burst.
func _build_grain_top_mark(target: Area3D, world_anchor: Vector3, normal: Vector3) -> void:
	var line_dir := Vector3.UP.cross(normal).normalized()
	var length := maxf(
		_piece_extent_along(target, line_dir) * float(_grain_cue_config.mark_length_fraction),
		float(_grain_cue_config.mark_dark_width))
	var mats := _grain_mark_materials()
	var layers := [
		{"name": "GrainMarkDark", "width": _grain_cue_config.mark_dark_width, "material": mats[0]},
		{"name": "GrainMarkGlow", "width": _grain_cue_config.mark_glow_width, "material": mats[1]},
		{"name": "GrainMarkGold", "width": _grain_cue_config.mark_core_width, "material": mats[2]},
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
			world_anchor + Vector3.UP * (float(i) * float(_grain_cue_config.layer_lift)))
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
## colour is fixed authored data.
func _grain_mark_materials() -> Array:
	if _grain_core_mat == null:
		_grain_dark_mat = _grain_paint_material(
			Color(0.012, 0.015, 0.010, 0.98), 0.04, 41.0)
		var mark: Color = _grain_cue_config.mark_color
		_grain_glow_mat = _grain_paint_material(
			mark.lerp(Color.WHITE, 0.14),
			float(_grain_cue_config.glow_pulse_min), 47.0)
		_grain_core_mat = _grain_paint_material(mark, 1.0, 53.0)
	return [_grain_dark_mat, _grain_glow_mat, _grain_core_mat]


func _grain_paint_material(color: Color, opacity: float,
		seed: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _PainterlyVFXDaub
	material.set_shader_parameter("dark_color", Color(
		color.r * 0.26, color.g * 0.20, color.b * 0.14, 0.94))
	material.set_shader_parameter("mid_color", Color(
		color.r, color.g, color.b, 0.96))
	material.set_shader_parameter("light_color", color.lerp(Color.WHITE, 0.44))
	material.set_shader_parameter("shape_mode", 1)
	material.set_shader_parameter("billboard_enabled", false)
	material.set_shader_parameter("dry_amount", _PainterlyVFXStyle.grain_dry_amount)
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("seed", seed)
	return material


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


## The middle pigment pass breathes between the authored min/max on a plain sine
## of wall-clock time. Cosmetic only, so it
## rides real time rather than Engine.time_scale, which hit-pause drives to
## near-zero for a beat on every real split.
func _update_grain_pulse() -> void:
	if _grain_glow_mat == null:
		return
	var period := maxf(0.05, float(_grain_cue_config.glow_pulse_period_sec))
	var t := float(Time.get_ticks_msec()) / 1000.0
	var k := 0.5 + 0.5 * sin(t * TAU / period)
	_grain_glow_mat.set_shader_parameter("opacity", lerpf(
		float(_grain_cue_config.glow_pulse_min),
		float(_grain_cue_config.glow_pulse_max), k))


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
	_grain_offer_source = &""
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


## The reward for taking a Grain Reader mark is banked before its receipt orbs
## erupt from the exact cut point, never from the stump centre.
func _award_grain_bonus(burst_point: Vector3) -> void:
	_last_grain_bonus = 0
	if _current_species == null:
		return
	var multiplier := _run_power_effect(
		ProgressionEffectDef.Kind.GRAIN_BONUS_XP_MULTIPLIER)
	if multiplier <= 0.0:
		return
	var base_xp := _current_species.xp_reward
	if _current_descriptor != null:
		var yards := SurvivorsContent.yards()
		var yard := yards.by_id(_current_descriptor.yard_id) \
			if yards != null else null
		var reward := yard.reward_for_species(_current_descriptor.species_id) \
			if yard != null else null
		if reward != null:
			base_xp = reward.xp_reward
	var bonus := maxi(1, int(round(float(base_xp) * multiplier)))
	_last_grain_bonus = bonus
	bonus = _run_director.award_xp(bonus) if _run_director != null else 0
	_last_grain_bonus = bonus
	_burst_xp_orbs(bonus, burst_point)

	if _run_director != null \
			and _run_director.has_method("record_run_power_trigger"):
		_run_director.call("record_run_power_trigger", &"grain_reader",
			burst_point, 1, true)
	AudioDirector.play_world(&"precision_success", burst_point)


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
	return _grain_cue_config.mark_color if _grain_target != null else Color.TRANSPARENT


func debug_invalidate_grain_candidate() -> void:
	if _grain_target == null or _grain_target_mesh == null:
		return
	var size := _grain_target_mesh.get_aabb().size
	_grain_local_plane.d += maxf(size.x, size.z) + float(_grain_cue_config.candidate_tolerance) * 2.0
	_grain_candidate_dirty = true


func debug_grain_clear_reason() -> StringName:
	return _grain_last_clear_reason


func debug_last_grain_bonus() -> int:
	return _last_grain_bonus


func debug_grain_offer_source() -> StringName:
	return _grain_offer_source


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
	var handling := SurvivorsContent.wood_handling().by_species_id(
		&"" if _current_species == null else _current_species.id)
	if handling != null:
		base += handling.fresh_split_modifier

	# Size relief: a fresh log is the full fight, a small billet much less of one.
	# Measured against the log this piece came from, so it is a fraction of THIS
	# log rather than an absolute size that a bigger species would fail.
	var frac := _size_fraction(piece)
	var profile_size_relief := 1.0 if handling == null else handling.size_relief_multiplier
	base += (1.0 - base) * (1.0 - frac) * size_relief * profile_size_relief

	var profile_scar_bonus := 1.0 if handling == null else handling.scar_bonus_multiplier
	base += float(_scars_on(piece)) * (scar_bonus * profile_scar_bonus \
		+ _run_power_effect(ProgressionEffectDef.Kind.SCAR_RELIABILITY))
	base += _run_power_effect(ProgressionEffectDef.Kind.SPLIT_RELIABILITY)
	base += float(_momentum_stacks()) * _run_power_effect(
		ProgressionEffectDef.Kind.MOMENTUM_RELIABILITY_PER_STACK)
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


## The mark a failed swing leaves: a generated normal-map gouge projected ACROSS
## THE TOP OF THE STRUCK PIECE, along the cut the axe was trying to make.
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
## Compatibility does not render Decal nodes. Instead `_scar_projection_mesh`
## copies only the struck mesh's upward-facing triangles, gives them scar-local
## UVs and lifts that receiver by `scar_lift`. No side or neighbouring piece is
## eligible to receive the projection.
##
## The record is stored in the piece's local mesh space. When that geometry is
## sliced, `_scar_records_for_split` passes the record into every descendant it
## still overlaps and `_restore_scar_records` rebases it around the new mesh
## centre. This is physical damage, not a transient child-node effect: an
## adjacent cut may clip the scar, but it cannot erase the surviving part.
func _add_scar(piece: Area3D, world_point: Vector3, normal: Vector3) -> void:
	var line_dir := Vector3.UP.cross(normal)
	if line_dir.length() < 0.001:
		return
	line_dir = line_dir.normalized()

	var mesh: Mesh = piece.get_meta("mesh_ref")
	if mesh == null:
		return
	# A scar must be authored against settled mesh-space, otherwise the record
	# would freeze a transient hop/tilt and drift when PieceAnimator lands it.
	_animator.finish_for([piece])
	var local_origin := piece.to_local(world_point)
	local_origin.y = mesh.get_aabb().end.y
	var local_line_dir := piece.global_transform.basis.inverse() * line_dir
	local_line_dir.y = 0.0
	if local_line_dir.length() < 0.001:
		return
	local_line_dir = local_line_dir.normalized()

	var visible_length := maxf(
		_piece_extent_along(piece, line_dir) * scar_length_frac, scar_width)
	var record := {
		"local_origin": local_origin,
		"local_line_dir": local_line_dir,
		"receiver_length": visible_length / _SCAR_VISIBLE_LENGTH_FRAC,
		"receiver_width": scar_width / _SCAR_VISIBLE_WIDTH_FRAC,
		"counts_for_pity": true,
	}
	var projection := _scar_projection_for(piece, record)
	if projection == null:
		return
	var records := _scar_records_on(piece)
	records.append(record)
	piece.set_meta("scar_records", records)


func _scar_records_on(piece: Node3D) -> Array:
	var records: Variant = piece.get_meta("scar_records", [])
	return records.duplicate(true) if records is Array else []


func _scar_projection_for(piece: Node3D, record: Dictionary) -> MeshInstance3D:
	var projection_mesh := _scar_projection_mesh(piece.get_meta("mesh_ref"), record)
	if projection_mesh == null:
		return null
	var projection := MeshInstance3D.new()
	projection.name = "ScarProjection_%d" % piece.get_child_count()
	projection.mesh = projection_mesh
	piece.add_child(projection)
	return projection


## Build a receiver from the piece's ACTUAL top triangles. UVs are planar in the
## scar's own local axes; fragments outside 0..1 are transparent in the shader.
## Using the cut mesh itself as the mask is what prevents a rectangular decal
## from spilling over a rounded top, down bark, or onto an adjacent billet.
func _scar_projection_mesh(source: Mesh, record: Dictionary) -> ArrayMesh:
	if source == null:
		return null
	var origin: Vector3 = record.get("local_origin", Vector3.ZERO)
	var line_dir: Vector3 = record.get("local_line_dir", Vector3.FORWARD)
	line_dir.y = 0.0
	if line_dir.length() < 0.001:
		return null
	line_dir = line_dir.normalized()
	var across_dir := Vector3.UP.cross(line_dir).normalized()
	var receiver_length := maxf(float(record.get("receiver_length", scar_width)), 0.0001)
	var receiver_width := maxf(float(record.get("receiver_width", scar_width)), 0.0001)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := 0
	for surface in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		var normals := PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			normals = arrays[Mesh.ARRAY_NORMAL]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		var element_count := indices.size() if not indices.is_empty() else vertices.size()
		for start in range(0, element_count - 2, 3):
			var ia := indices[start] if not indices.is_empty() else start
			var ib := indices[start + 1] if not indices.is_empty() else start + 1
			var ic := indices[start + 2] if not indices.is_empty() else start + 2
			if ia >= vertices.size() or ib >= vertices.size() or ic >= vertices.size():
				continue
			var a := vertices[ia]
			var b := vertices[ib]
			var c := vertices[ic]
			if not _scar_triangle_faces_up(a, b, c, normals, ia, ib, ic):
				continue

			var triangle_uvs: Array[Vector2] = []
			var uv_min := Vector2(INF, INF)
			var uv_max := Vector2(-INF, -INF)
			for vertex: Vector3 in [a, b, c]:
				var delta := vertex - origin
				var uv := Vector2(
					delta.dot(across_dir) / receiver_width + 0.5,
					delta.dot(line_dir) / receiver_length + 0.5)
				triangle_uvs.append(uv)
				uv_min = uv_min.min(uv)
				uv_max = uv_max.max(uv)
			if uv_max.x < 0.0 or uv_min.x > 1.0 or uv_max.y < 0.0 or uv_min.y > 1.0:
				continue

			for i in range(3):
				st.set_normal(Vector3.UP)
				st.set_uv(triangle_uvs[i])
				st.set_color(Color.WHITE)
				st.add_vertex([a, b, c][i] + Vector3.UP * scar_lift)
				added += 1

	if added == 0:
		return null
	st.generate_tangents()
	var projection := st.commit()
	projection.surface_set_material(0, _scar_projection_material())
	return projection


func _scar_triangle_faces_up(a: Vector3, b: Vector3, c: Vector3,
		normals: PackedVector3Array, ia: int, ib: int, ic: int) -> bool:
	if normals.size() > maxi(ia, maxi(ib, ic)):
		var average := normals[ia] + normals[ib] + normals[ic]
		if average.length() > 0.001:
			return average.normalized().dot(Vector3.UP) >= _SCAR_TOP_NORMAL_MIN_DOT
	# Godot's triangle convention winds the geometric cross opposite its shading
	# normal (pinned by test_slicer's winding check), hence c×b here.
	var face := (c - a).cross(b - a)
	return face.length() > 0.000001 \
		and face.normalized().dot(Vector3.UP) >= _SCAR_TOP_NORMAL_MIN_DOT


func _scar_projection_material() -> ShaderMaterial:
	if _scar_projection_mat != null:
		return _scar_projection_mat
	_scar_projection_mat = ShaderMaterial.new()
	_scar_projection_mat.shader = _SCAR_SHADER
	_scar_projection_mat.set_shader_parameter("scar_normal", _SCAR_NORMAL)
	_scar_projection_mat.set_shader_parameter("scar_tint",
		Vector3(scar_colour.r, scar_colour.g, scar_colour.b))
	_scar_projection_mat.set_shader_parameter("scar_shadow",
		Vector3(scar_shadow_colour.r, scar_shadow_colour.g, scar_shadow_colour.b))
	_scar_projection_mat.set_shader_parameter("scar_highlight",
		Vector3(scar_highlight_colour.r, scar_highlight_colour.g, scar_highlight_colour.b))
	_scar_projection_mat.set_shader_parameter("scar_opacity", scar_opacity)
	_scar_projection_mat.set_shader_parameter("normal_strength", scar_normal_strength)
	return _scar_projection_mat


## Seconds the player must wait between swings after current run-power effects.
func current_swing_cooldown() -> float:
	var recovery := _run_power_effect(ProgressionEffectDef.Kind.SWING_RECOVERY)
	recovery += float(_momentum_stacks()) * _run_power_effect(
		ProgressionEffectDef.Kind.MOMENTUM_SPEED_PER_STACK)
	recovery = clampf(recovery, 0.0, 0.8)
	return maxf(min_swing_cooldown, swing_cooldown * (1.0 - recovery))


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
	# Snapshot the physical marks before the owner is replaced. The normal-map
	# receivers themselves are disposable; these mesh-local records are what the
	# two newly sliced descendants inherit.
	var inherited_scar_records := _scar_records_on(piece)
	var inherited_projection_offset: Vector3 = piece.get_meta(
		"projection_offset", Vector3.ZERO)
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
	var stable_piece_id: StringName = piece.get_meta("stable_piece_id", &"root")
	if _current_descriptor != null:
		_cut_journal.append({
			"piece_id": String(stable_piece_id),
			"local_plane": local_plane,
		})
	# Roughen the fresh cut faces so the split reads as cloven wood, not a laser cut.
	res.above = _jag_cut(res.above, local_plane)
	res.below = _jag_cut(res.below, local_plane)

	# This is the only hit path; GameFeel turns it into shake and hit-pause.
	# (Reference fires triggerShake right here, inside performSplit.)
	EventBus.action_hit_registered.emit(world_point)
	_play_sfx(split_sfx)
	AudioDirector.play_world(&"wood_split", world_point)

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
	for half_index in range(2):
		var is_above := half_index == 0
		var half: ArrayMesh = res.above if is_above else res.below
		var out_sgn := 1.0 if is_above else -1.0
		var descendant_scars := _scar_records_for_split(
			inherited_scar_records, local_plane, is_above)
		var node := _realise_half(
			half, xform, normal * out_sgn, descendant_scars,
			inherited_projection_offset,
			StringName("%s/%s" % [stable_piece_id, "a" if is_above else "b"]))
		if node != null:
			new_stays.append(node)

	_apply_shockwave(world_point, new_stays)
	if not new_stays.is_empty():
		_try_show_grain_cue(_pick_grain_target(new_stays))

	# Log fully chopped (nothing choppable left): wait for the firewood to settle,
	# settle its rewards, then leave the landed pieces in place for their farewell.
	if _on_block.is_empty():
		_awaiting_finished_settlement = true
		_finished_batch_age = 0.0
		if auto_sell and _coin_reward_pool != null and not _firewood.is_empty():
			# Coins erupt from the same final cut as XP, then wait near the stump
			# until the shared XP/coin collection beat calls both reward waves home.
			_coin_reward_pool.begin_burst(
				world_point + Vector3.UP * 0.06, _firewood.size(), reward_ground_y,
				_stump_radius, orb_collect_at, orb_stagger)
		# THE XP LANDS ON THE SPLIT ITSELF, not when the firewood has settled
		# (Creative Director call, 2026-08-02: *"pop out the moment the final piece
		# is split, so all the collecting happens at once"*). The settle wait is up
		# to `firewood_settle_timeout` long, so awarding during piece settlement put the
		# reward a beat behind the swing that earned it, and the orbs then arrived
		# on their own instead of inside the same burst of activity as the pieces
		# landing around the block.
		_award_log_xp(_power_cut_context != &"")
		# Commit the root's fixed purse after its coin batch and exact XP receipt are
		# registered. The HUD trails authority until those tokens arrive, while a
		# stage clear or suspend can never lose part of a completed root payout.
		if auto_sell and _run_director != null and _current_descriptor != null:
			var completed_descriptor := _current_descriptor
			var reward_piece_count := mini(_firewood.size(),
				_CoinRewardPool.CAPACITY)
			if _power_cut_context != &"" and _run_director.has_method(
					"complete_automatic_active_log"):
				_run_director.call("complete_automatic_active_log",
					completed_descriptor, reward_piece_count, _power_cut_context)
			else:
				_run_director.complete_manual_log(completed_descriptor,
					reward_piece_count)
			if _run_director.has_method("on_root_completed"):
				_run_director.call("on_root_completed",
					completed_descriptor, world_point)
	return true


## Duplicate the visual record to both geometric descendants so either can keep
## the surviving clipped relief. Its pity contribution belongs to exactly one
## side of the split, preventing one physical failed hit from becoming two
## mechanical bonuses when the scar itself straddles the new edge.
func _scar_records_for_split(records: Array, local_plane: Plane, is_above: bool) -> Array:
	var descendants: Array = []
	for source_record: Dictionary in records:
		var record := source_record.duplicate(true)
		var origin: Vector3 = record.get("local_origin", Vector3.ZERO)
		var origin_is_above := local_plane.distance_to(origin) >= 0.0
		record["counts_for_pity"] = bool(record.get("counts_for_pity", true)) \
			and origin_is_above == is_above
		descendants.append(record)
	return descendants


func _restore_scar_records(piece: Node3D, records: Array, source_center: Vector3) -> void:
	var accepted: Array = []
	var pity_count := 0
	for source_record: Dictionary in records:
		var record := source_record.duplicate(true)
		var local_origin: Vector3 = record.get("local_origin", Vector3.ZERO)
		record["local_origin"] = local_origin - source_center
		if _scar_projection_for(piece, record) == null:
			continue
		accepted.append(record)
		if bool(record.get("counts_for_pity", true)):
			pity_count += 1
	piece.set_meta("scar_records", accepted)
	piece.set_meta("scars", pity_count)


## Classify a freshly-sliced half and realise it. Returns the stay node, or null
## if it became firewood (physics). Scar records are rebased from the slicer's
## parent-local coordinates to the new centered mesh in either outcome.
func _realise_half(half: ArrayMesh, parent_xform: Transform3D, out_dir: Vector3,
		inherited_scar_records: Array = [],
		inherited_projection_offset: Vector3 = Vector3.ZERO,
		stable_piece_id: StringName = &"") -> Area3D:
	var aabb := half.get_aabb()
	var c := aabb.position + aabb.size * 0.5
	var centered := _translate_mesh(half, -c)
	var world_pos := parent_xform * c
	var projection_offset := inherited_projection_offset + c

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
		_spawn_firewood(
			centered, world_pos, out_dir, inherited_scar_records, c,
			projection_offset)
		return null
	var yaw := deg_to_rad(randf_range(-fresh_yaw_deg, fresh_yaw_deg))
	var piece := _make_stay_piece(centered, world_pos, yaw, false,
		projection_offset, stable_piece_id)
	_restore_scar_records(piece, inherited_scar_records, c)
	return piece


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


func debug_total_scar_projection_count() -> int:
	var count := 0
	for piece: Area3D in _on_block:
		for child in piece.get_children():
			if child is MeshInstance3D and child.name.begins_with("ScarProjection"):
				count += 1
	return count


func debug_total_scar_pity_count() -> int:
	var count := 0
	for piece: Area3D in _on_block:
		count += _scars_on(piece)
	return count


func debug_split_chance() -> float:
	if _on_block.is_empty():
		return 0.0
	return split_chance_for(_on_block[0])


## World-space centre of the actual chopping block. LooseLogArena must not
## assume the whole minigame lives at world origin when steering Yard Magnet.
func yard_magnet_target_world_position() -> Vector3:
	return to_global(Vector3.ZERO)


## Floor-level origin used by LooseLogArena's full-height protection capsule.
func chopping_visibility_dome_base_world_position() -> Vector3:
	return to_global(Vector3.ZERO)


## The centre remains the visual destination, but a physical loose body must
## stop outside this solid cylinder before its vertical handoff begins.
func yard_magnet_stump_collision_radius() -> float:
	return current_work_radius()


# ------------------------------------------------------- piece factories
## Object-space bark must survive MeshSlicer's descendant recentering. Both live
## exterior shaders declare this per-instance value at the same explicit index,
## so one write covers the bark and authored-end surfaces on the MeshInstance.
func _set_log_projection_offset(instance: MeshInstance3D, offset: Vector3) -> void:
	if instance == null:
		return
	instance.set_instance_shader_parameter(&"projection_offset", offset)


func _make_stay_piece(centered_mesh: Mesh, world_pos: Vector3, yaw: float,
		is_whole_log := false,
		projection_offset: Vector3 = Vector3.ZERO,
		stable_piece_id: StringName = &"") -> Area3D:
	var piece := Area3D.new()
	piece.collision_layer = _PICK_LAYER
	piece.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = centered_mesh
	_set_log_projection_offset(mi, projection_offset)
	piece.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = MeshUtils.box_shape(centered_mesh)
	piece.add_child(cs)
	_pieces_root.add_child(piece)
	piece.position = world_pos
	piece.quaternion = Quaternion(Vector3.UP, yaw)
	piece.set_meta("mesh_ref", centered_mesh)
	piece.set_meta("is_whole_log", is_whole_log)
	piece.set_meta("projection_offset", projection_offset)
	if stable_piece_id == &"":
		stable_piece_id = StringName("piece_%d" % piece.get_instance_id())
	piece.set_meta("stable_piece_id", stable_piece_id)
	_on_block.append(piece)
	return piece
func _spawn_firewood(centered_mesh: Mesh, world_pos: Vector3, out_dir: Vector3,
		inherited_scar_records: Array = [], source_center := Vector3.ZERO,
		projection_offset: Vector3 = Vector3.ZERO) -> void:
	var body := RigidBody3D.new()
	# A finished billet gets one impact cue at its first contact with the yard
	# floor. Contact monitoring is disabled again in the callback so later
	# settling/bounces cannot turn the pitched-down chop into a noisy rattle.
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_firewood_body_entered.bind(body))
	body.physics_material_override = _phys_mat
	body.linear_damp = piece_linear_damp
	body.angular_damp = piece_angular_damp
	body.continuous_cd = true
	var vs := centered_mesh.get_aabb().size
	body.mass = maxf(wood_density * vs.x * vs.y * vs.z, min_mass)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = centered_mesh
	_set_log_projection_offset(mi, projection_offset)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = MeshUtils.box_shape(centered_mesh)
	body.add_child(cs)
	_fallers.add_child(body)
	body.global_position = world_pos
	body.set_meta("mesh_ref", centered_mesh)
	body.set_meta("projection_offset", projection_offset)
	_restore_scar_records(body, inherited_scar_records, source_center)

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


func _on_firewood_body_entered(other_body: Node, firewood: RigidBody3D) -> void:
	if other_body != $Floor:
		return
	_play_firewood_impact_sfx(firewood)


func _play_firewood_impact_sfx(firewood: RigidBody3D) -> void:
	if not is_instance_valid(firewood) \
			or bool(firewood.get_meta("ground_impact_sfx_played", false)):
		return
	firewood.set_meta("ground_impact_sfx_played", true)
	firewood.set_deferred("contact_monitor", false)
	AudioDirector.play_world(&"piece_land", firewood.global_position)


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
## Spawn a fresh log. `clear_finished` = true also clears earlier farewell pieces
## (the standalone R debug key); ordinary auto-respawn leaves them to finish.
func _spawn_fresh_log(clear_finished := true) -> void:
	_clear_grain_cue(&"piece_changed")
	# A brand new log is a brand new roll — the once-per-log latch belongs to
	# THIS log, never the one that just left the block.
	_grain_offered_this_log = false
	_grain_offer_count_this_log = 0
	if not GameState.has_meta_capability(
			MetaUpgradeDef.Capability.CONTINUOUS_HANDOFF):
		_hold_chop_active = false
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
	_awaiting_finished_settlement = false
	_finished_batch_age = 0.0
	if clear_finished:
		_clear_finished_firewood()

	# Select the next log's species — the species is what this log will yield,
	# and what its exposed end-grain looks like when it is cut.
	var species_index := _pick_species_index()
	_current_species = SpeciesTable.at(species_index)
	_cut_mat = _cut_mat_for(species_index)
	_source_mesh = _apply_species_look(
		_center_mesh(_build_split_log(_pick_mesh(_current_species))), species_index)

	var half_h := _source_mesh.get_aabb().size.y * 0.5
	var rest_y := _stump_top_y + half_h
	var node := _make_stay_piece(_source_mesh, Vector3(0.0, rest_y, 0.0), 0.0, true)
	var landed := Callable(self, "_on_log_landed").bind(_source_mesh)
	var duration := 300.0
	_animator.animate_drop(node, rest_y + drop_height, rest_y, landed, duration)
	_try_show_grain_cue(node)


func _on_log_landed(mesh: Mesh) -> void:
	_play_drop_sfx()
	AudioDirector.play_world(&"log_drop", Vector3(0.0, _stump_top_y, 0.0))
	_spawn_log_smoke(mesh)
	_apply_pending_descriptor_power_cuts()
	# Deferred power cuts can finish the descriptor the instant it lands. That
	# completion deliberately pauses boundary danger through settlement/handoff;
	# do not immediately undo it with a stale "ready" signal for an empty block.
	if _external_log_flow and not _on_block.is_empty() \
			and not _awaiting_finished_settlement:
		run_log_ready.emit()


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
	return _stump_radius


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
	# Run-power speed changes the whole swing while preserving the authored base.
	var base := maxf(current_swing_cooldown(), 0.001)
	_axe.set_speed(clampf(swing_cooldown / base, 0.25, 4.0))
	AudioDirector.play_world(&"axe_whoosh", world_point)
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


## Dress every imported log exterior in the procedural mapping strategy approved
## in the material lab:
##
##   - the bark/body slot samples species bark in object-space triplanar mapping;
##   - every authored trunk/branch-end slot keeps one centred non-repeating disc;
##   - MeshSlicer's third material remains the existing fresh-inside strategy.
##
## Explicit species paths win. Empty paths preserve the imported oak/birch art,
## so those bespoke sets are promoted into the same mapping without being
## replaced. `bark_tint` remains only as a defensive legacy fallback for future
## incomplete rows; the current terrestrial table no longer relies on it.
##
## Materials are cached per (species, source material) because imported resources
## are shared by reference. The cached ShaderMaterials also stay distinct from
## `_cut_mat`, preserving MeshUtils.jag_cut's fresh-face identity check.
func _apply_species_look(mesh: ArrayMesh, species_index: int) -> ArrayMesh:
	var row := SpeciesTable.at(species_index)
	if row == null:
		return mesh

	for si in range(mesh.get_surface_count()):
		var src := mesh.surface_get_material(si)
		if src == null:
			continue
		var key := "%d|%d" % [species_index, src.get_instance_id()]
		if not _bark_mats.has(key):
			var slot := _slot_name(src)
			var is_top := slot.contains("top") if not slot.is_empty() else si == 1
			if slot.is_empty():
				push_warning("chopping_minigame: log material %d has no name; assuming %s by surface order."
					% [si, "end" if is_top else "bark"])

			var tex_path: String = row.top_tex if is_top else row.bark_tex
			var tex: Texture2D = null
			if not tex_path.is_empty():
				tex = load(tex_path) as Texture2D
				if tex == null:
					push_warning("chopping_minigame: %s texture '%s' did not load; using the imported albedo."
						% [row.id, tex_path])
			if tex == null:
				tex = _source_albedo(src)
			if tex == null:
				push_warning("chopping_minigame: %s %s slot has no usable albedo; keeping its source material."
					% [row.id, "end" if is_top else "bark"])
				continue

			var material := ShaderMaterial.new()
			material.resource_name = slot if not slot.is_empty() else (
				"log_top" if is_top else "log_bark")
			var tint := row.bark_tint if tex_path.is_empty() else Color.WHITE
			if is_top:
				material.shader = _LOG_END_SHADER
				material.set_shader_parameter(&"end_texture", tex)
				material.set_shader_parameter(&"end_tint", tint)
			else:
				material.shader = _LOG_BARK_SHADER
				material.set_shader_parameter(&"bark_texture", tex)
				material.set_shader_parameter(&"bark_tint", tint)
				material.set_shader_parameter(
					&"projection_scale", row.bark_projection_scale)
			_bark_mats[key] = material
		if _bark_mats.has(key):
			mesh.surface_set_material(si, _bark_mats[key])
	return mesh


## The imported material's own name (`oak_bark` / `oak_top`), lowercased. Godot
## binds an EXTERNAL .tres beside the FBX when the names match, so the useful name
## can live on either the resource or its file — check both.
func _slot_name(mat: Material) -> String:
	if not mat.resource_name.is_empty():
		return mat.resource_name.to_lower()
	return mat.resource_path.get_file().get_basename().to_lower()


## Imported oak/birch rows intentionally omit explicit exterior paths. Extract
## their painted albedo so they receive the same projection without replacing art.
func _source_albedo(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		var shader_mat := mat as ShaderMaterial
		var bark := shader_mat.get_shader_parameter(&"bark_texture") as Texture2D
		if bark != null:
			return bark
		return shader_mat.get_shader_parameter(&"end_texture") as Texture2D
	return null


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
## imports at 0.032 m tall, so 13x gave the ~0.42 m round the block and the cut
## thresholds are sized for. Then MeshUtils.mesh_from_
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
## so chopping_acceptance and every shot tool drive an exact wood without touching
## progression.
func _pick_species_index() -> int:
	if debug_forced_species >= 0 and debug_forced_species < SpeciesTable.count():
		return debug_forced_species
	return 0


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


func debug_boss_stack_state() -> Dictionary:
	var visual_positions: Dictionary = {}
	for raw_id: Variant in _boss_stack_visuals:
		var visual := _boss_stack_visuals[raw_id] as MeshInstance3D
		if is_instance_valid(visual):
			visual_positions[String(raw_id)] = visual.global_position
	return {
		"active": _boss_stack_active,
		"pending_visual_count": _boss_stack_visuals.size(),
		"visual_positions": visual_positions,
		"camera_fov": _camera.fov if _camera != null else 0.0,
		"camera_base_fov": _camera_base_fov,
		"camera_position": _camera.global_position if _camera != null else Vector3.ZERO,
		"camera_local_position": _camera.position if _camera != null else Vector3.ZERO,
		"camera_pivot_y": _pivot.position.y if _pivot != null else 0.0,
		"camera_base_pivot_y": _pivot_base_position.y,
		"camera_base_local_position": _camera_base_transform.origin,
		"camera_target_pivot_y": _boss_camera_target_y,
		"camera_transition_seconds": \
			_run_director.tuning.boss_stack_camera_transition_seconds \
			if _run_director != null else 0.0,
		"camera_tracking": _boss_camera_tween != null \
			and _boss_camera_tween.is_valid(),
		"active_log_visible": _boss_active_log_is_visible() \
			if _boss_stack_active else true,
		"cuttable_count": _on_block.size(),
		"current_descriptor_id": String(
			_current_descriptor.id if _current_descriptor != null else &""),
	}
