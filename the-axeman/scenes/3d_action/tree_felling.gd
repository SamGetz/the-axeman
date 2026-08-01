extends Node3D
## FILE: res://scenes/3d_action/tree_felling.gd
## ATTACHES TO: the root Node3D of res://scenes/3d_action/tree_felling.tscn (the
## live M5 mini-game, instanced under main's 3D_World_Root) — and, through that
## scene, of res://scenes/3d_action/tree_felling_harness.tscn (the standalone F6
## feel-test harness, which instances the same scene inside its own viewport).
## Requires the child nodes Player (forest_player.tscn), Fallers and Floor.
##
## M5 — TREE FELLING. One click, one blow, and the tree is felled the way a tree
## is actually felled (Amendment 13; the technique is the USDA Forest Service ax
## manual's, "An Ax to Grind", which Sam supplied):
##
##   1. CUT THE FACE NOTCH. Click one side of the trunk. That side is the way it
##      is going to fall. Every click on that side alternates automatically
##      between the notch's steep ROOF cut and its flatter FLOOR cut, so a run of
##      clicks carves a real V into the fall side. The manual wants that notch
##      "about one-third to one-half of the diameter of the tree when felling
##      strictly with an ax", and the game agrees with it for a reason: until the
##      notch is deep enough, the wood still holding the tree sits on the fall
##      side of the trunk's centre, and a tree cannot topple over its own
##      support. Under-notch and it will sit back on you.
##   2. CUT THE BACK. Click the OTHER side. That is the back cut, and the game
##      places it for you exactly where the manual does — a little higher than
##      the notch ("a minimum of 2 inches higher on the stump"), level, eating
##      straight in toward the notch.
##   3. LEAVE THE HINGE. The wood between the back cut and the notch is the
##      holding wood, and it is the only thing steering the tree. "Cutting
##      through the hinge wood is the single most dangerous thing a novice faller
##      can do." Here it costs you the fall: sever it and the tree goes at once,
##      with nothing left to hold its direction.
##   4. WATCH IT GO. Nothing pushes it. The tree hangs off its hinge and gravity
##      takes it out through the notch, slowly at first because the arm is small,
##      then violently because the arm grows with the angle. Once it is past
##      committing, the trunk becomes a rigid body and lands for real.
##
## THE WOOD IS REAL (Amendment 13). The bottom of the trunk is a voxel volume
## (`WoodVolume`) and a blow subtracts the solid the axe displaces from it. The
## chip that flies past the camera is the wood that left the hole. The notch is
## one continuous pocket, not a stack of bites. The hinge is measured, not
## tracked. And there is no fell condition beyond a loaded beam giving way: after
## every blow each height of the trunk is checked as a section carrying the
## weight above it, in every direction, and the tree comes down at the height and
## in the direction that first runs out of wood.
##
## FIRST PERSON (2026-07-26, handoff/08_FPS_FOREST.md §1-§2). Creative Director:
## *"I want this to be an fps game now, where you walk through a forest and chop down
## trees."* The player WALKS — WASD, mouse look, gravity, `forest_player.gd` — and the
## axe goes wherever the crosshair is. Nothing about the simulation changed to allow
## it: `WoodVolume`, `TreeTrunk`, `HingeFall` and the load model take world planes and
## report measured wood, and never knew where the camera was. What changed is who
## holds the camera and how a blow is aimed (`_aim`). ESC frees the mouse; click to
## take it back. R grows a fresh tree.
##
## The old fixed orbit camera survives as the DEV camera (`player_controlled = false`,
## see `_apply_camera`), because the render-to-PNG shot tools frame every check they
## make by driving it.
##
## Geometry lives in helpers so this file stays about the GAME: wood_volume.gd
## (the field and its mesher), tree_trunk.gd (one tree and where it breaks),
## hinge_fall.gd (the attached half of the fall), fade_out.gd (clearing up).
##
## EVERY tuning value below is a PLACEHOLDER (Directive 3) — authored as @export
## so Sam tunes it live in the inspector, never a hardcoded final. The tree's own
## data (hardness, yields) lives in a TreeDef .tres, per A8.

const _AxeRig := preload("res://scenes/3d_action/axe_rig.gd")
const _PieceAnimator := preload("res://scenes/3d_action/piece_animator.gd")
const _FRAGMENT_PIECE := preload("res://scenes/3d_action/fragment_piece.tscn")
const _BUDGET := preload("res://scenes/3d_action/fragment_physics_budget.gd")
const _LogFlight := preload("res://scenes/3d_action/log_flight.gd")
const _AXE_FBX := preload("res://assets/models/axe_basic/axe_basic.fbx")
## END GRAIN, for the faces the axe opens: a log round with its growth rings, which is
## what cutting ACROSS a trunk exposes. Creative Director's call, 2026-07-25 — "use the
## oak log top texture as the internal wood texture, since we'd see rings if thats how we
## were really cutting it." It is a single disc on a white field, NOT a tiling sheet, so
## the cut faces are mapped as one round centred on the trunk's axis (WoodVolume.
## ring_radius) rather than tiled.
const _TEX_RINGS := preload("res://assets/textures/wood_oak/wood_oak_top_diffColor.jpg")
## LONG GRAIN, for splinters: a splinter is a stick of wood torn out along the grain, so
## its faces are streaks, not rings. Tiling, and it keeps its normal map.
const _TEX_INSIDE := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_diffColor.jpg")
const _TEX_INSIDE_N := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_normals.jpg")

## How many horizontal directions the neck is tested in. The tree falls whichever
## way it first runs out of strength, so this is the resolution of "which way".
## It has to be the volume's own, because the reaches the model compares are
## measured in exactly those directions.
const _DIRS := WoodVolume.SUPPORT_DIRS
## A height counts as "opened up" on a side when its wood no longer reaches this
## far out toward the bark there.
const _OPEN_REACH_FRAC := 0.85

## Tree species table — the one place a tree type is declared, mirroring M4's
## _LOG_SPECIES. `def` is the TreeDef carrying hardness / yields (A8); `model` is
## the mesh it is cut from; `source_scale` normalises the FBX's authored units
## before the shared `tree_scale` tuning is applied; `trunk_surface` identifies
## the bark surface without guessing from triangle count; `canopy_surfaces`
## declares the exact authored surfaces that despawn on landing; `trunk_base_y`
## is the ground line in the transformed mesh, so authored roots may extend
## below it without moving the carveable stem underground. Add a row to add a type.
##
## Imported scene-node transforms are baked by MeshUtils.mesh_from_scene, so this
## is normally 1.0. A row only needs another value for an intentional gameplay
## override on top of the artist's FBX transform.
##
## PLACEHOLDER GAMEPLAY MAPPING: both visual types currently use pine_tree.tres.
## The new asset establishes a visual type, but not a different hardness or
## yield. Point a row at another TreeDef when Sam assigns its gameplay species.
const _TREE_SPECIES: Array[Dictionary] = [
	{
		"id": &"tree_02",
		"model": "res://assets/models/trees_export/tree_02.fbx",
		"def": "res://data/trees/pine_tree.tres",
		"source_scale": 1.0,
		"trunk_surface": 0,
		# Generator v2.3: 0 = trunk/roots, 1 = canopy bark, 2 = leaves.
		"canopy_surfaces": [1, 2],
		"trunk_base_y": 0.0,
	},
	{
		"id": &"tree_01",
		"model": "res://assets/models/trees_export/tree_01.fbx",
		"def": "res://data/trees/pine_tree.tres",
		"source_scale": 1.0,
		"trunk_surface": 0,
		# Generator v2.3: 0 = trunk/roots, 1 = canopy bark, 2 = leaves. This row said
		# `[1]` — correct for the two-surface tree_01 it was written against, and stale
		# from the moment Sam re-exported it with a separate leaf material (2026-07-29).
		# An undeclared surface is treated as WOOD, so surface 2's 6,208 leaf vertices
		# went into `WoodyCrown` and stayed bolted to the felled trunk for good, which is
		# the "leaves don't despawn" Sam reported; they were also measured as structural
		# crown mass. EXACTLY the regression logged for tree_02 when it gained its third
		# surface. Check the surfaces against the asset whenever a tree is re-exported —
		# nothing infers this, and nothing can.
		"canopy_surfaces": [1, 2],
		"trunk_base_y": 0.0,
	},
]

## Force a species for headless tests / dev shots: -1 uses the forest seed's
## deterministic per-slot mix; >=0 pins the _TREE_SPECIES row at that index.
@export var debug_forced_species := -1

# --- the tree ------------------------------------------------------------
@export_group("Tree")
## Uniform gameplay scale applied AFTER each type's source-unit normalisation.
## 1.0 keeps each imported tree at its own authored scene size.
@export var tree_scale := 1.0
## How much of the trunk, up from the butt, is real carveable wood (m) — or ZERO
## for the WHOLE CLEAR TRUNK, butt to the first branches, which is what it ships as.
##
## This used to be a hard 1.3 m of a 7.7 m tree, and everything above it was
## imported mesh that clicks did nothing to. The whole bare stem is carveable now
## (2.2 m on tree_01, found from the mesh — see TreeTrunk._clear_trunk_height), so
## there is no height on the visible trunk where the axe stops working.
##
## It stops at the branches deliberately, and setting this by hand past them is a
## mistake: the voxel field clamps anything wider than the trunk back to the trunk,
## so a band reaching into the crown would delete the branches and leave a pole.
##
## It also starts ABOVE THE ROOT FLARE (2026-07-29), which is the other thing a radial
## voxel field cannot represent — see TreeTrunk._root_flare_height.
@export var band_height := 0.0
## ...and the longest band to build in metres, 0 for uncapped. THIS IS A COST KNOB and
## a PLACEHOLDER (Directive 3) — Sam's number to set.
##
## It exists because the automatic band top is now honest. It used to be stopped by
## whatever crossed the trunk first, which on the current art is a LEAF CARD at 1.1 m,
## so the band was accidentally tiny; measuring the declared trunk surface instead gives
## the true bare stem, which on these trees is 6.7 m. That is choppable in principle and
## far more voxels than the game should pay for: the field is nx*ny*nz and ny comes
## straight off this number. 3.0 m is well past what a player standing on the ground with
## a 1.65 m crosshair can reach, and about a third of the grid a full stem would want.
@export var band_height_max := 3.0
## Voxel size (m). THE resolution knob: smaller carves finer notches and reads
## smoother, and costs a remesh on every blow. 0.055 puts ~17 cells across
## tree_01's trunk, which is enough to read a notch, a back cut and a hinge.
@export_range(0.03, 0.12) var voxel_cell := 0.055
## How far a fresh tree naturally leans, in degrees, in a random direction.
##
## OFF BY DEFAULT, and the reason is worth knowing. A tree only topples once its
## weight hangs out past the wood holding it up, so a leaning tree can be brought
## down with the shallow notch the manual describes ("one-third to one-half of
## the diameter") — provided you notch the side it already leans. An upright one
## has to be notched PAST THE MIDDLE OF THE TRUNK before there is anything for
## gravity to work with, which is what this game does by default: no dice rolls,
## the notch you can see is the whole answer.
##
## Turn it up and felling becomes the real job — read which way the tree wants to
## go, and notch that side. Notch the wrong one and it sits back on you and you
## have to cut the notch deeper to win it round. Every bit of that falls out of
## the load model on its own; nothing here is scripted. It is a difficulty knob,
## not decoration, and it wants a readout before it ships on.
@export_range(0.0, 8.0) var natural_lean_deg := 0.0

# --- the stand -------------------------------------------------------------
@export_group("The stand")
## HOW MANY TREES stand in the forest. 1 is the single tree M5 was built against, and is
## what the headless suites pin — every acceptance check is about one tree's wood.
##
## Each extra tree is CHEAP until it is chopped: a tree is its imported mesh, a pick volume
## and a collider until the player's first blow lands on it, and only then does it become a
## voxel volume (TreeTrunk.preview / build, plan §3a). So this number costs draw calls and
## nodes, not the ~27,000-sample field that would make a forest unshippable.
@export_range(1, 200) var tree_count := 25
## Radius of the stand (m) — trees are scattered inside this, centred on the scene origin.
@export var forest_radius := 25.0
## No two trees stand closer than this (m). It has to clear two trunks plus room to swing,
## or trees interpenetrate and the player cannot get at either.
@export var min_tree_spacing := 4.5
## Nothing grows within this of the player's spawn (m), so the game does not begin with a
## trunk in your face.
@export var spawn_clear_radius := 5.0
## Seed for the scatter. Fixed so the stand is the SAME every run — a forest that reshuffles
## itself makes every measurement and every render shot incomparable. Change it for a
## different forest; there is no randomness anywhere else in the layout.
@export var forest_seed := 20260726
## Trees taper in size across the stand by up to this fraction, so it does not read as one
## tree stamped N times. 0 = every tree identical.
@export_range(0.0, 0.5) var tree_size_variation := 0.18
## How far the ground is tiled out from the middle, in TILES each way — so 3 is a 7x7 grid.
## Capped by `forest_radius`: only as many tiles as the stand actually needs are made. 0
## leaves the single authored patch alone, which is what the single-tree scene wants.
@export_range(0, 8) var ground_tiles := 3
## Beyond this the sun stops casting shadows (m). One DirectionalLight3D shadowing a whole
## forest is a very different proposition from one tree in a clearing; 0 leaves the engine
## default alone.
@export var shadow_distance := 45.0

## How far above its footing a fresh tree bounces in from when it spawns (m).
@export var drop_height := 1.4
## Duration of that bounce-in drop (ms). M4's log drop is 300 ms; a whole tree
## wants a little longer.
@export var drop_time_ms := 420.0
## Grow a fresh tree where the felled one stood, once it clears.
##
## **OFF, because NOTHING REGROWS.** Creative Director's call, 2026-07-26: the forest is a
## finite stand you clear, so a slot the player has emptied stays empty — chopping the stand
## out is meant to be visible progress, and the 2D village is where the loop continues.
##
## It shipped ON by mistake, which is what Sam saw as *"the trees respawn instantly after they
## despawn"*: a felled trunk faded and another tree popped straight back into its place, so the
## stand could never be cleared at all. The DECISION was recorded and the DEFAULT was not
## changed to match it.
##
## Left in place because two dev tools genuinely want it — `felling_smoke` and `felling_spam`
## both need a fresh tree per round and set it themselves, as does `m5_acceptance._test_7`,
## which exists to check that the fall-and-collect loop closes. With it off the board simply
## stays empty until R.
@export var auto_respawn := false

# --- chopping ------------------------------------------------------------
@export_group("Chopping")
## Beat between the axe connecting and the wood letting go (s) — M4 parity, the
## little wind-up that sells the hit. The remesh happens on this beat, inside the
## hit-pause, which is where a few milliseconds of work is invisible.
@export var anticipation_sec := 0.1
## How far one blow drives its cut plane into the wood (m). The notch apex
## advances rather more than this per blow, because the roof and floor cuts
## converge — see `notch_depth`. Smaller = a finer carve and more blows to fell.
@export var bite_depth := 0.065
## The floor cut's bite as a fraction of the roof cut's. The two cuts advance the
## apex by different amounts (they meet at an angle), so this is the trim that
## keeps the notch from drifting up or down the trunk as it deepens.
@export_range(0.3, 2.0) var floor_bite_frac := 1.0
## How much of the trunk's width one blow spans (m).
##
## Wider than the trunk means every blow takes the full face, which is what keeps a notch
## reading as one clean V. NARROWER THAN THE TRUNK CHANGES THE GAME rather than the pace:
## a blow then cuts a CHANNEL through the middle of the face instead of the whole of it,
## and since a blow's slab is always centred on the trunk's own axis, the flanks left
## either side can only be reached by bringing the cut round to face them — with the angle
## of entry, and past that by orbiting the camera to work round the tree.
##
## Measured on tree_01 (0.94 m across): at 0.8 and above a tree fells in ~15 blows; at 0.6
## and below it cannot be felled from one viewpoint at all, however long you chop, because
## the flanks square to the fall line are never in reach. `_warn_cut_span` says so at
## spawn rather than leaving it to be discovered.
@export var cut_span := 1.6
## How far round the trunk a blow can be from a cut already going there and still count
## as the SAME cut (deg). Past it, the blow opens a fresh cut on the face it was aimed
## at instead.
##
## This is `cut_reach`'s companion and it only exists because the player can now WALK.
## `cut_reach` asks "is this blow near that cut in HEIGHT"; this asks "is it on the same
## FACE of the tree". Without it, walking round a trunk and chopping folds the blow into
## the notch on the face now behind the player — because the side a blow is on is
## measured against the camera, and walking swings that right round while the cut stays
## where it was cut. A fixed camera could never expose it.
##
## Too wide and working the flanks of a narrow `cut_span` stops being possible; too
## narrow and a small sidestep leaves the player nicking a fresh cut every blow, which
## PASS 5 already found is how a tree ends up covered in nicks that never fell it.
@export_range(10.0, 90.0) var cut_face_arc_deg := 50.0
## THE OPENING WEDGE, as face angles from horizontal. The first blow on a fresh cut lays
## in both of these at once, because a single cut into a round trunk lifts a sliver of bark
## and reads as a miss. Every blow after it is angled by the player instead.
@export_range(20.0, 80.0) var notch_roof_deg := 45.0
## The lower face of that opening wedge — flatter than the roof.
@export_range(5.0, 45.0) var notch_floor_deg := 16.0
## How thick a slab one blow takes (m) — the kerf the axe opens, at whatever angle the
## blow was aimed at. Was `back_kerf` when a level back cut was the only kerf in the
## game; every cut is a kerf now.
@export var cut_kerf := 0.11
## The steepest a single blow can be angled, in degrees from horizontal, reached when
## the click is a full `cut_reach` above or below the cut it is working. Clicking level
## with the cut goes straight in; above it comes down, below it comes up. This is the
## player's angle control and it is the whole of it.
@export_range(10.0, 80.0) var free_cut_max_deg := 55.0
## How much a cut's kerf WIDENS per metre it has already eaten in.
##
## An axe cannot drive a slot its own width half a metre into a trunk — the notch has to
## open out or the blade binds, which is why an axe-cut notch is a V. It matters here for
## exactly the same reason it matters in the wood: bending is gated on the room the trunk
## has to rotate into, so a cut that stays a narrow slot has nowhere to go and the tree
## sits back on it however long you chop. This makes a run of blows in one place open a
## real mouth on its own, WITHOUT taking the angle back off the player: they can still
## shape it wider or narrower, higher or lower, from where they click.
@export var kerf_flare := 0.35
## How near an existing cut a blow has to land to count as part of it (m).
##
## THIS IS THE WHOLE OF "cut wherever you like". Inside this, a click deepens the cut
## already going there and the axe returns to it; outside it, the click opens a NEW cut
## where the player aimed. Too small and a run of clicks becomes a row of nicks that
## never joins into a notch; too large and the tree is back to having one cut that
## every blow is dragged into, which is what it used to do.
@export var cut_reach := 0.3
## A second, independent ceiling on how high a chop may land, as a fraction of tree
## height. At 1.0 the carveable band is the only limit, which is the point — the
## band already stops at the branches, and that is a real edge in the wood rather
## than an invisible line partway up a trunk that looks identical either side of it.
## Bring it down to put a reach limit on the player as well.
@export_range(0.05, 1.0) var max_cut_height_frac := 1.0
## ...and how far above the PLAYER'S EYES a blow may land, in metres. A faller works at
## chest height; the band is tall so the crown's hand-over sits well above the eyeline
## where nobody looks at it, not so the axe can reach the top of it. Measured against the
## player rather than the tree, so it means the same on a tall trunk and a short one.
## Sam's number (2026-07-30): about 50 cm above head height.
@export var cut_height_above_eye := 0.5
## THE ANGLE OF ENTRY: how far round from facing the trunk head-on the cut comes in,
## in degrees, toward whichever side was struck.
##
## 90 is square-on to the side of the trunk, which is what every cut used to be — the
## notch always faced dead left or dead right and the tree always fell straight across
## the frame. This is the floor and the default, and the player varies it above this by
## WHERE ACROSS THE TRUNK they click: the cut comes in at the angle of the point on the
## trunk they actually pointed at, so clicking out at the silhouette edge cuts square
## from the side (90) and clicking in toward the centre line cuts from further round
## the front, down to this angle. At 30 the tree falls diagonally, well toward the
## camera; raise it toward 90 for the old square-across fall.
@export_range(10.0, 90.0) var entry_angle_deg := 30.0
## How far round from square-on the AXE comes: 0 swings straight in from the side
## of the trunk, 90 from directly in front of the camera. This moves the axe
## only — the notch and the fall stay square to the side, so the wedge reads in
## profile and the tree goes across the frame rather than at the lens.
@export_range(0.0, 80.0) var swing_toward_camera_deg := 32.0
## How many times the inside-wood texture repeats per metre on a cut face.
@export var cut_tex_tile := 3.0
## Bark texture repeats on the carved butt: x around the trunk, y per metre up
## it. LEAVE AT ZERO to match whatever scale the tree's own crown is using — the
## band and the crown are the same trunk, and tiling them differently puts a hard
## line across the tree where one ends and the other begins.
@export var bark_tex_tile := Vector2.ZERO
## HOW DARK FRESHLY CUT WOOD IS, as a tint on the exposed-wood materials (the notch's
## faces, the walls of a cut, the splinters and the break).
##
## PLACEHOLDER per Directive 3 — Sam's number to set, and worth setting live. Both wood
## textures are painted light, and against this scene's sun (`light_energy` 0.75 over
## ambient 0.45, filmic tonemapping) an untinted cut face blows out: MEASURED on a
## shipping-settings chop, 29% of the cut's pixels clipped to pure white, which is why a
## notch read as a flat pale ribbon across the trunk rather than as wood with grain in
## it. White is the one colour that carries no texture at all.
##
## Bark next to it renders around a third of full brightness, so this is set to bring
## fresh wood down into the same range while keeping it clearly lighter than bark, which
## is what a fresh cut looks like.
@export var cut_wood_tint := Color(0.72, 0.66, 0.56)
## VOXELISE EVERY TREE AT SPAWN rather than on its first blow, so that no tree ever
## changes shape or texture under the player. See `_prebuild_stand` for what it costs and
## why it is a switch. PLACEHOLDER per Directive 3.
@export var prebuild_stand := true
## VOXELISE THE ROOT FLARE FROM THE MESH instead of leaving it as an imported piece under
## the band (2026-07-30, Sam: *"worth doing to remove those seams"*).
##
## The band's field is a radial profile — one radius per (level, angle) — which cannot
## describe a buttress you can see daylight under, so the roots used to be a separate
## imported mesh clipped in under the band. That piece's cut rim is the ring round the butt
## of every tree, and it cannot be hidden: whichever of two surfaces is outermost at a
## hand-over shows its own rim, and five arrangements were measured before accepting that.
## With this on there is no hand-over at all — the roots are filled into the SAME field
## from the mesh's own triangles (`WoodVolume._fill_from_mesh`) and the whole trunk comes
## out of one mesher as one surface.
##
## OFF AGAIN (2026-07-31, same day) — it is the direct cause of both things Sam reported
## after playing it: *"The textures on voxel parts of the tree look awful and the game is
## lagging on every hit ... The tree just needs to look like a tree without texture
## issues."* MEASURED, both:
##
##   - LOOK. The flare is the only part of the trunk whose bark is not the artist's. It
##     gets a TRIPLANAR wrap (`WoodVolume.root_mat`) because the band's cylindrical one
##     degenerates on a buttress — and rendered close up it comes out dark and smeared,
##     with a hard banded ring where it meets the wrap at the shoulder. The stem band
##     above it is indistinguishable from the imported mesh; the flare is not.
##   - COST. The grid is a BOX sized to `band_max_radius`, and the flare is 2.7x wider
##     than the stem — so it goes 68,600 -> 234,423 samples (3.4x) to model the bottom
##     17% of the band, and a blow goes from ~56 ms to ~92 ms. Per HIT.
##
## Both are inherent to the approach rather than bugs left to fix: surface nets cannot
## reproduce authored buttress geometry, a fitted wrap cannot reproduce the artist's root
## UVs, and one axis-aligned grid cannot be wide only where the wood is. What would fix it
## is ART — a trunk whose roots are modelled as part of the stem silhouette — not code.
##
## Turning it ON still works and is fully tested (the axe reaches the dirt, the stump
## collider follows the wood, cut faces in the flare are wood not white). It is a switch
## precisely so this is Sam's call rather than mine.
##
## Historical note. It was ON for part of 2026-07-31, which is what Sam asked for twice: *"I still want the player to
## have the option to cut the roots and lower part of the trunk though, this shelf looks
## really bad and just feels like a removal of player agency"* (07-30) and *"I want to be
## able to cut all the way down to the roots on the trunk"* (07-31). The shelf IS the
## uncarveable roots piece — the band's floor sat on top of it, so a cut that went right
## through the stem left the flare standing as a plinth. With the roots in the field there
## is no floor and no plinth: the axe reaches the ground, and the lowest a blow may land
## drops from 0.60/0.80 m to 0.20 m on the two species.
##
## What it cost to turn on, all of it now done: the STUMP collider (a stump cut this low is
## shorter than the old fixed neck band, so the neck became the whole stump and the base
## collider was never built at all — see `TreeTrunk._build_stump_body`), and a blow's face
## probe starting at 2.5x the STEM's radius when the flare reaches 2.8x, which made tree_01
## unchoppable while tree_02 was fine (`_cut_slab` sizes off `band_max_radius` now).
##
## PLACEHOLDER per Directive 3: it costs build time and grid width — the grid goes from
## 35x56x35 to 61x63x61 on tree_02 and 30x56x30 to 71x67x71 on tree_01, because
## `band_max_radius` has to reach the buttresses — so it stays a switch. Turn it off and
## the roots go back to being an imported piece below the band that the axe cannot touch.
@export var voxel_roots := false

# --- the load model --------------------------------------------------------
## NO HIT POINTS. After every blow each height of the band is checked as a beam:
## the weight of everything above it CRUSHES the wood left there and BENDS it
## about whatever moment arm the notch, the back cut and the tree's own lean have
## left. `stress = crush + bend`, 1.0 is failure, and the height and direction
## with the worst stress are where and which way it goes. Everything in it is
## measured off the voxels; only the two strengths are invented, and they are
## GAME numbers — real timber stands on absurdly thin hinges, games should not.
@export_group("Load model")
## Gravity the load model weighs the wood above the cut under (m/s²).
@export var gravity := 9.8
## Wood density (kg/m³) — sets both the load and the falling trunk's mass.
@export var wood_density := 700.0
## Resistance to the straight-down squeeze (kPa). Lower = fells sooner.
@export var crush_strength_kpa := 500.0
## Resistance to the lever trying to fold it over (kPa). Lower = fells sooner.
## This is the one that decides how thin a hinge the tree will stand on.
@export var bend_strength_kpa := 4300.0
## The stress the wood gives way at (1.0 = the model's nominal failure).
@export var fail_stress := 1.0
## How tall the gap between trunk and stump has to be on a side before the tree
## will start to go over that way at all (m). Keep it above `cut_kerf`: a back
## cut on its own is a slot the trunk closes in a few degrees, and a tree that
## can sit back into its own back cut is a tree that never falls forward. A face
## notch opens far wider than this, which is what picks the direction.
@export var topple_min_open := 0.20
## ...and how much more room than that counts as fully free (m).
@export var topple_clearance := 0.15
## The tree only starts visibly leaning once stress passes this.
@export var lean_start_stress := 0.25
## How far it leans by the time the wood gives (deg) — the tell that it is going,
## and which way.
@export var lean_max_deg := 5.0
## Lean ramp shape between lean_start_stress and failure (higher = stays upright
## longer, then goes over sharply at the very end).
@export var lean_curve_exp := 1.6
## Seconds for the lean to ease to its new angle after a blow.
@export var lean_time := 0.3

# --- cracks -----------------------------------------------------------------
## The wood announces the load: each stress threshold crossed fires one CRACK —
## a jolt, a sound, a couple of splinters spat from the compression side.
@export_group("Cracks")
## Stress thresholds that each fire one warning CRACK as they are first crossed.
@export var crack_stress_levels: Array[float] = [0.55, 0.75, 0.92]
## GameFeel trauma per crack (scales up if a single blow crosses several at once).
@export var crack_impact := 0.22
## Splinters spat from the compression side per crack.
@export var crack_chips := 2
## Length of a crack splinter along the grain (m).
@export var crack_chip_len := 0.24
## Thickness of a crack splinter across the grain (m).
@export var crack_chip_thick := 0.035
## Crack splinter launch speed, out of the notch (m/s).
@export var crack_speed := 1.4
## Crack splinter upward launch speed (m/s).
@export var crack_up := 1.8

# --- chop splinters ----------------------------------------------------------
## Every blow SPRAYS, over and above the chunk it takes: thin sticks of fresh
## wood flung out of the cut. Pure FX (they carry no wood off the tree),
## elongated along the grain so they read as split fibres, and fast-settling so
## they do not hog the A12 budget.
@export_group("Chop splinters")
## Thin sticks sprayed per landed blow (0 = off).
@export var chop_splinters := 4
## How long each splinter is along the grain (m).
@export var splinter_stick_len := 0.16
## ...and how thin across the grain (m).
@export var splinter_stick_thick := 0.018
## Splinter launch speed, out of the cut (m/s).
@export var chop_splinter_speed := 2.6
## Splinter upward launch speed (m/s).
@export var chop_splinter_up := 2.0
## Sideways scatter as a fraction of the launch speed.
@export var chop_splinter_spread := 0.6
## Splinters freeze this soon after spawning (s).
@export var splinter_settle := 1.2
## Cubic metres of removed wood one splinter stands for. The wood a blow takes is
## thrown as SPLINTERS rather than as the carved geometry itself — a bite is a thin
## flake, and flakes read as flat discs once they are lying on the ground. This is the
## exchange rate between wood removed and splinters thrown.
@export var splinter_wood_each := 0.0015
## ...however much wood came out at once, never more splinters than this from it. A12
## counts bodies, and a notch wedge popping free is a lot of wood in one moment.
@export var splinter_burst_cap := 8
## The most debris allowed to be lying about at once (0 = no limit).
##
## A12's cap of 24 is on bodies still MOVING, which is the physics cost. This is the
## cost of the ones that have stopped: a draw call and a node each, and they used to
## accumulate for the whole life of a tree — twelve a blow, hundreds of them within a
## minute of steady chopping. Over this, the OLDEST SETTLED piece is BAKED INTO A MULTIMESH
## and its body freed (`_consolidate`) — so the pile stays exactly where the player left it
## for good, and costs one draw call for the whole forest instead of one each.
##
## It used to DELETE the oldest settled piece, which with one tree was survivable and in a
## forest means the pile behind you disappears while you are at the third tree. Sam's call,
## 2026-07-26. PLACEHOLDER per Directive 3 — it now trades how many splinters are still
## SIMULATED against how soon a pile stops being physical.
@export var max_debris := 120

# --- the hinge and the tear --------------------------------------------------
@export_group("Hinge and tear")
## How hard the holding wood resists the first of the fall, as a fraction of the
## torque gravity is putting on it. 0 = it lets go the instant it fails; near 1 =
## it hangs there creaking. This is the whole "nothing, nothing, then it is
## going" beat, so it is the first number to tune by feel.
##
## Was 0.7, which held the tree inside two degrees of upright for the first two
## SECONDS after the wood gave — long enough that nothing appeared to have happened at
## all, which is most of what read as floaty. At 0.3 the creak is still there and the
## tree still starts slow, but it starts visibly.
@export_range(0.0, 0.95) var hinge_hold_frac := 0.3
## How far it has to bend before the last fibre lets go (deg).
@export var hinge_tear_deg := 22.0
## How far over it has to be before the trunk is handed to physics (deg). Below
## about 45 the butt is still over the stump and can catch on it.
@export var free_fall_deg := 58.0
## The least overhang a felled tree is allowed to start with (m). A tree felled
## by pure crushing has no direction of its own; rather than let it stand there
## being crushed, it is given this much lean toward the weakest side so it always
## comes down.
@export var min_topple_arm := 0.06
## How ragged the break faces are (m) — roughened in the voxel field itself, so
## the break is torn geometry rather than a displaced plane.
@export var tear_jag_amount := 0.05
## Noise frequency of that tear (lower = bigger, chunkier tears).
@export var tear_jag_freq := 6.0
## Splinters flung from the hinge as the fibres let go (0 = off).
@export var splinter_count := 10
## Splinter burst launch speed along the fall (m/s).
@export var splinter_speed := 1.7
## Splinter burst upward launch speed (m/s).
@export var splinter_up := 2.3
## Splinter burst random spin (rad/s).
@export var splinter_spin := 8.0
## More splinters spat out while the hinge is still tearing, per second.
@export var tear_splinter_rate := 14.0

# --- the fall (physics half) ---------------------------------------------
## Past `free_fall_deg` the trunk is a genuine RigidBody3D. It is NOT tracked by
## FragmentPhysicsBudget — that budget force-settles the oldest body when over
## cap, which is fragment_piece's contract, and there is only ever one trunk.
@export_group("Fall physics")
## HOW HEAVY THE FALL FEELS. Multiplies gravity for both halves of it — the attached
## rotation about the hinge and the rigid body afterwards.
##
## Above 1.0 this is not physical and it is not pretending to be: a real 7.7 m tree
## takes about four and a half seconds to come down from the moment the hinge goes,
## and Sam's verdict on watching that was that it felt floaty, with nothing falling
## with any intensity. A tree is the biggest thing in this game and it has to read
## like it. Turning this up shortens the fall and raises the speed it lands at, which
## is what the impact is scaled by, so the whole end of the fall gets heavier
## together. 1.0 is honest gravity if that is ever wanted back.
@export var fall_gravity_scale := 2.0
## Linear damping on the falling trunk (higher = more air drag).
@export var trunk_linear_damp := 0.05
## Angular damping while it is still coming down. ZERO on purpose: this is the part of
## the fall that is supposed to be running away with itself, and damping the spin here
## is exactly the "floaty" the whole tree is trying not to be.
@export var trunk_angular_damp := 0.0
## Angular damping the trunk ends up at once it has finished crashing — a perfect
## cylinder rolls forever on flat ground, so this kills the roll and lets the log
## settle where it lands. It is applied `land_slam_time` AFTER the landing, not on
## contact: dropping it on the instant of touch stopped the tree dead at the exact
## frame the player was waiting to see, which is what made a felled tree land like
## a prop being set down. The endless-roll problem it exists for is dealt with
## directly instead, by killing the trunk's spin about its OWN long axis at contact
## (that component is the rolling; the rest is the tree still coming down).
@export var trunk_land_angular_damp := 14.0
## Linear damping the trunk ends up at, on the same delay.
@export var trunk_land_linear_damp := 2.5
## How long the trunk is left to crash about before the damping above comes in (s).
@export var land_slam_time := 0.35
## Ignore trunk contacts for this long after it goes free (s) — it comes down
## through its own splinter burst, and that is not the landing.
@export var impact_grace := 0.15
## GameFeel trauma when the trunk hits the ground (0..1), for a landing at
## `land_impact_speed` or harder. Below that it scales down with the real speed —
## a tree that topples off a low stump and flops over should not shake the screen
## like one that came down from full height.
@export var land_impact := 1.0
## ...or this much if the fallen length is under GameFeelConfig.size_threshold
## (A3).
@export var land_impact_small := 0.45
## The speed (m/s) of the fastest-moving part of the trunk that counts as a
## full-strength landing. Measured at the far tip, because that is the end that
## arrives first and hardest.
##
## A full-height fall of tree_01 arrives at about 23 m/s with `fall_gravity_scale` at
## 2.0, so 18 leaves a full fall comfortably maxed out while still leaving a tree that
## came down off a low stump, or only part of the way, something less than maximum to
## report. Set it near the full-fall speed and only a perfect fall shakes the screen;
## set it low and everything does.
@export var land_impact_speed := 18.0
## Extra slow-motion beat on the landing (s), over and above the standard A11 chop
## pause that comes with any registered impact. The whole fall builds to this one
## frame; scaled by how hard it hit, and A11's counted overlap guard means the
## longest pause in flight is the one that governs.
@export var land_pause := 0.22
## A later slam — the butt crashing down after the top, or a bounce — registers
## once the trunk loses at least this much speed in a single frame (m/s).
@export var secondary_impact_speed := 2.0
## ...and never registers more trauma than this (0..1), so the aftershocks stay
## aftershocks and the landing itself stays the biggest thing that happened.
@export var secondary_impact_max := 0.45
## Minimum gap between two of those (s). Without it a trunk bouncing along could
## report a slam on several frames running, and since each one asks for its own
## slow-motion beat they would chain into one long smear.
@export var secondary_impact_gap := 0.15
## Metres of fallen length per computed size tier (Amendment 6 quantisation).
@export var size_tier_unit := 3.0
## Debris thrown up along the trunk where it lands — the impact you feel. Scaled
## by how hard the landing actually was.
@export var land_debris := 10
## How hard that debris is thrown (m/s).
@export var land_debris_speed := 3.2
## The trunk counts as still once its speed drops below this (m/s).
@export var trunk_settle_speed := 0.25
## ...and its spin below this (rad/s).
@export var trunk_settle_spin := 0.4
## ...both held for this long before it is judged settled (s).
@export var trunk_settle_hold := 0.4
## Give up waiting for the trunk to settle and clear the board anyway (s).
@export var fall_timeout := 10.0

# --- bucking the felled trunk ---------------------------------------------
## THE TREE IS DOWN, AND IT IS STILL A TREE. Bucking is the job after felling: cut
## the trunk across into logs you can carry. Clicks on the trunk where it lies open
## a cross-cut, and when one goes right through, that length of timber comes away as
## its own log and is booked into the inventory.
##
## Cut by the PLANE SLICER, not the voxel field, and that is the whole reason this is
## a few dozen lines rather than a module. A bucking cut is a cross-cut — a plane
## straight through the log — which is the slicer's own case and exactly what M4's
## chopping block does to a round of firewood. Voxels would also mean voxelising the
## crown, and the field clamps anything wider than the trunk back to the trunk, so
## the branches would vanish the moment the tree hit the ground.
@export_group("Bucking")
## Off = the felled trunk just dissolves into the inventory as it used to.
@export var buck_enabled := true
## Blows to cut through the trunk in one place.
@export var buck_blows := 4
## How far a click can drift from the cut in progress and still count as the same
## cut (m). Wider than this and the player has started a new one somewhere else.
@export var buck_spot_tolerance := 0.35
## HOW MANY LOGS A TRUNK IS WORTH. Sam's spec, 2026-07-27: *"the log sizes are soo small. It
## should be roughly 5 logs per tree."*
##
## THIS is the knob, not a length in metres, and that is deliberate: the minimum log is worked
## out from the felled trunk's OWN length (`_min_log()`), so a tall tree gives long logs and a
## short one gives short logs, and both give about this many. It has to be derived now that
## `tree_size_variation` makes the trees different sizes — a fixed metre value would give five
## logs from one tree and three from its neighbour.
##
## tree_01 is 7.7 m, so 5 puts a log at about 1.5 m.
@export_range(2, 12) var buck_target_logs := 5
## Absolute floor on a log (m), whatever `buck_target_logs` works out to. A backstop for a
## sapling, not the main control.
##
## It is not only accuracy: every section is an untracked rigid body, so a floor on how
## short one may be is what stops a patient player making unbounded numbers of them, which
## is A12's concern.
@export var buck_min_length := 0.6
## THE FELLED TRUNK LIES WHERE IT FELL until it has been bucked out — every remaining
## length down under `buck_min_length` — or until the player walks out of the forest.
## Creative Director's call, 2026-07-26, with the move to first person: you are meant
## to be able to turn your back on a tree you have dropped, go and do something else,
## and come back to it.
##
## OFF restores the timed behaviour below, which is what M5 shipped with: the board
## clears `buck_idle_clear` seconds after the player last touched it. The headless
## suites run with it off, because most of them are about the fall and want the board
## to clear itself.
##
## The yield invariant is untouched either way — whenever the trunk does finally go,
## `_collect_yields` pays the balance bucking has not already booked in, so a tree is
## worth exactly its authored `TreeDef.yields` however it was cut up.
@export var trunk_persists := true
## A FELLED TREE LEAVES ITS STUMP STANDING, for good. Creative Director's call, 2026-07-27:
## *"I want the stump to remain."* It is what makes a cleared stand read as cleared, and it keeps
## the collider the standing tree handed over at the break, so a stump is something you walk into
## rather than through. The R key still wipes them, because that is a fresh board.
@export var stumps_persist := true
## Seconds of not being touched before the board gives up and clears. Every blow
## resets it, so the player is never hurried. IGNORED while `trunk_persists` is on.
@export var buck_idle_clear := 5.0
## THE LOGS FLY TO THE PLAYER once the trunk is bucked out, and are banked as they land.
## Creative Director's direction, 2026-07-27: *"the logs can fly towards the character (in a
## similar way to the log chopping game) and then be added to their inventory."* Off = they lie
## where they were cut and the timber is booked in as the board clears, which is what M5 did
## before. All four numbers are PLACEHOLDERS per Directive 3 — see log_flight.gd.
@export var logs_fly_to_player := true
## How long one log takes to reach the player (ms).
@export var log_fly_ms := 460.0
## Spread across a batch so a trunk's worth cascades in rather than arriving as one clump (ms).
@export var log_fly_stagger_ms := 110.0
## How far above the straight line a log arcs on the way (m).
@export var log_fly_arc := 1.1
## How high up the player a log flies to (m) — chest height reads as being caught, ankle height
## reads as being kicked.
@export var log_fly_catch_height := 1.1
## Trauma when a length of trunk finally comes free (0..1).
@export var buck_sever_impact := 0.45
## How hard the two ends kick apart when they part (m/s).
@export var buck_part_speed := 0.8

# --- gear gating ---------------------------------------------------------
@export_group("Gear gate")
## An under-tier hit still thunks (A7 hit -> GameFeel), it just does not cut.
@export var denied_emits_hit := true
## How far a bounced (under-tier) swing travels toward the wood before it stops,
## as a fraction of a full swing.
@export var denied_swing_frac := 0.55

# --- clearing the board ---------------------------------------------------
@export_group("Clearing")
## Beat the felled tree lies there before it starts to dissolve (s).
@export var fade_delay := 0.8
## How long the tree and its chips take to dissolve (s).
@export var fade_time := 0.7

# --- chip physics ---------------------------------------------------------
@export_group("Chip physics")
## Floor on any chip's mass (kg) so a sliver is not flung across the clearing.
@export var min_mass := 0.2
## Linear damping on thrown chips (higher = more air drag).
@export var piece_linear_damp := 0.35
## Angular damping on thrown chips (higher = they stop tumbling sooner).
@export var piece_angular_damp := 1.2
## Launch speed away from the cut for the chunk a blow frees (m/s).
@export var chip_out := 2.4
## ...and upward (m/s).
@export var chip_up := 1.8
## Chip random spin (rad/s).
@export var chip_tumble := 6.0
## A chip freezes this long after spawning if it has not already settled (s).
@export var chip_settle_timeout := 3.0

# --- the player ------------------------------------------------------------
@export_group("Player")
## TRUE = the player walks (WASD, mouse look, gravity — `forest_player.gd`), which is
## what the game is. FALSE makes the player a PUPPET posed by `cam_distance` /
## `cam_height` / `cam_focus_y` / `dev_camera_yaw_deg` below, reproducing the old
## fixed orbit camera exactly.
##
## Everything headless runs with it OFF, and that is not laziness: the dev shot tools
## frame every render-to-PNG check by driving those three numbers, and m5_acceptance
## measures which way a tree fell against the camera's own right-vector. Both need to
## know where the eye is. See forest_player.gd's header.
@export var player_controlled := true
## How far the player can be from the wood and still land a blow (m), measured eye to
## hit point. It has to clear the player's own capsule radius or a tree cannot be
## reached at all; it is what stops a tree being felled from across the clearing.
@export var chop_reach := 3.2

# --- dev camera ------------------------------------------------------------
## ONLY used while `player_controlled` is false. Polar around this scene's origin,
## aimed at a focus height — the camera M5 was built and shot with.
@export_group("Dev camera")
## Camera distance back from the scene origin (m).
@export var cam_distance := 5.0
## Camera height above the ground (m).
@export var cam_height := 1.75
## Height on the tree the camera aims at (m).
@export var cam_focus_y := 1.5
## Which way round the tree it stands (deg). Replaces the old A/D orbit, whose keys
## are now strafe; `debug_orbit_camera()` steps it.
@export var dev_camera_yaw_deg := 0.0

# --- axe ------------------------------------------------------------------
## Axe placement is a GUESS and axe_basic.fbx is an untextured placeholder stick
## — the same caveat M4 carries. Eyeball in F6.
@export_group("Axe")
## Uniform scale on the axe model.
@export var axe_scale := 1.4
## How far back along the approach the swing starts (m).
@export var axe_hover := 0.6
## 0 = the axe comes straight down from above, 1 = flat in from the side.
@export_range(0.0, 1.0) var axe_approach_lean := 0.75
## How far the swing path bows out of a straight line (m) — the arc of the swing.
@export var axe_arc_bulge := 0.3
## Resting (hidden) rotation of the axe between swings, as Euler radians.
@export var axe_hidden_euler := Vector3(0.5, 0.0, 0.15)
## Rotation of the axe at the moment it strikes, as Euler radians (before the
## cut-angle follow is added).
@export var axe_struck_euler := Vector3(-2.0, 0.0, 0.1)
## How much of the cut's angle the axe pose copies (0 = ignore it, 1 = match).
@export_range(0.0, 1.0) var axe_angle_follow := 0.6
## How long the swing takes to travel its arc (s).
@export var swing_time := 0.16

# --- audio (hooks; drop a stream in to hear it) ---------------------------
@export_group("Audio")
## Played on each landed blow.
@export var chop_sfx: AudioStream
## Played on each warning crack (falls back to creak_sfx if empty).
@export var crack_sfx: AudioStream
## Played as the holding wood lets go.
@export var creak_sfx: AudioStream
## Played when the felled trunk hits the ground.
@export var land_sfx: AudioStream

@onready var _player: ForestPlayer = $Player
@onready var _camera: Camera3D = $Player/Head/Camera3D
@onready var _fallers: Node3D = $Fallers
@onready var _floor: StaticBody3D = $Floor   # the ground — the only thing that counts as a landing

var _trunk: TreeTrunk
var _falling: Node3D                      # the attached half of the fall
var _fall_rest_basis := Basis.IDENTITY    # ...and the pose it started that half in
var _hinge: HingeFall
var _fallen: RigidBody3D                  # ...and the free half, once it lets go
var _fallen_length := 0.0
## The shape of the timber coming down, measured at detach and already in the rigid
## body's own frame — see `TreeTrunk.timber_slices`. Empty falls back to one cylinder.
var _fallen_slices: Array[Dictionary] = []
var _animator := _PieceAnimator.new()
var _budget: Node
var _axe: AxeRig
var _audio: AudioStreamPlayer3D
var _cut_mat: StandardMaterial3D            # end grain: the faces the axe opens
var _splinter_mat: StandardMaterial3D       # long grain: the splinters it throws
var _side_mat: StandardMaterial3D           # ...and the walls a chop leaves in a trunk
var _phys_mat: PhysicsMaterial
var _tear_noise := FastNoiseLite.new()

var _tree_def: TreeDef
var _pending: Dictionary = {}             # in-flight blow waiting out anticipation_sec
var _felling := false
var _fall_dir := Vector3.RIGHT
var _landed := false
var _land_at := 0.0                       # _fall_age when it touched down
var _damped := false                      # ...and whether the settle damping is in yet
var _impact_speed := 0.0                  # fastest the tip was going before it hit
var _prev_speed := 0.0                    # ...and last frame's, to spot later slams
var _slam_cool := 0.0                     # ...with a gap enforced between them
var _settled := false
var _collected := false
## ...and how many trees have been booked in over the whole session. `_collected` guards ONE
## tree against double-paying and is reset per felling; this only ever goes up, which is what
## `has_collected()` reports — a flag that is set and cleared inside a single frame cannot be
## observed by a test polling between frames.
var _collect_count := 0
var _hinge_intact := true                 # was there holding wood left when it went?
var _fall_age := 0.0
var _still_for := 0.0
var _tear_debt := 0.0
var _fade_at := -1.0
var _respawn_at := -1.0
var _chips: Array = []
## One splinter mesh per size, shared by every splinter of that size — see _stick_mesh.
var _stick_cache := {}
## Foliage currently separating from a fallen tree. Entries remove themselves
## after their fade; stale references are harmless and pruned on cleanup.
## Authored branch/leaf surfaces remain attached to the falling tree until its
## first ground contact, then disappear on that exact landing frame.
var _attached_canopies: Array[Node3D] = []

# --- bucking (the felled trunk, lying there, being cut into logs) ----------
var _bucking := false
var _logs: Array = []                     # every length the trunk has been cut into
var _log_radius := 0.4                    # the trunk's radius, kept for their colliders
var _buck_target: RigidBody3D = null      # the length the current run of blows is on
var _buck_at := 0.0                       # ...and where along it (its own local Y)
var _buck_hits := 0                       # ...and how many blows have landed there
var _buck_idle := 0.0
var _logs_paid := 0                       # yields already booked in by bucking
var _flight := _LogFlight.new()           # logs on their way to the player
## STUMPS. A felled tree leaves its stump standing for good (Sam's call, 2026-07-27) — it is
## what makes a cleared stand look cleared. Tracked so the R key can still wipe the board.
var _stumps: Array[TreeTrunk] = []

# --- the trees ------------------------------------------------------------
## EVERY TREE IN THE STAND. `_trunk` below is whichever one the axe is working, not
## "the tree" — it is set from the aim ray on each blow.
var _trees: Array[TreeTrunk] = []
var _cleared_at := Vector3.ZERO   ## where the last felled tree stood, for auto_respawn
var _tiles: Array[Node3D] = []    ## the duplicated ground patches (the authored one is not here)
var _ground_span := 0.0           ## one tile's footprint (m), measured at load
## What the DEV camera orbits, in this scene's own space. Zero (the origin) is where the
## single tree stands, which is what every shot tool and acceptance check is framed on.
var _dev_camera_anchor := Vector3.ZERO
## Settled splinters, baked. Mesh -> MultiMeshInstance3D; see `_consolidate`. Keyed by mesh
## because a MultiMesh draws ONE mesh, and the game only has three splinter sizes — so this
## is three instances for a whole forest however many trees have come down.
var _piles: Dictionary = {}
## ...and the transforms in each, mesh -> Array[Transform3D]. Kept here rather than read back
## out of the MultiMesh, because growing a MultiMesh reallocates and wipes it — see
## `_consolidate` for the two ways that went wrong.
var _pile_used: Dictionary = {}
var _warned_span := false         ## _warn_cut_span is once per GAME, not once per tree

# --- the cuts, as the player has left them ---------------------------------
## THE CUT STATE IS PER TREE and lives on the trunk (`trunk.cut`, see
## tree_cut_state.gd). It used to be five bare variables here — `_cut().sites`, `_cut().site`,
## `_cut().face_side`, `_cut().face_dir` — which was correct for exactly as long as there was one
## tree. With a stand to walk through, chopping tree B would have inherited tree A's cut
## sites and its committed fall direction, silently and without an error anywhere.
##
## `_cut()` is the accessor, and it hands back the state of the tree currently being
## worked. Everything below reads it through that; nothing keeps its own copy.


# ------------------------------------------------------------------ setup
func _ready() -> void:
	# The player owns the camera now; GameFeel still only ever writes h_offset /
	# v_offset on it, which are frustum shifts and compose with mouse look.
	GameFeel.register_camera(_camera)
	_player.active = player_controlled
	# A10: walking back out to the 2D village must not leave the cursor captured.
	EventBus.minigame_exited.connect(_on_minigame_exited)
	_cut_mat = StandardMaterial3D.new()
	_cut_mat.albedo_texture = _TEX_RINGS
	_cut_mat.roughness = 1.0
	# CULL_DISABLED matches M4: a fresh cut face must never vanish when the piece
	# is viewed from the far side.
	_cut_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The ring texture is one disc on a white field, and the mesher maps the trunk's
	# cross-section onto it directly. CLAMP so a face that strays a little outside the
	# trunk's radius takes the edge of the round rather than wrapping a second ring set
	# round it.
	_cut_mat.texture_repeat = false
	# ...and brought down out of the clipping range — see `cut_wood_tint`.
	_cut_mat.albedo_color = cut_wood_tint
	# A splinter is long grain, not end grain, so it keeps the streaky inside wood.
	_splinter_mat = StandardMaterial3D.new()
	_splinter_mat.albedo_texture = _TEX_INSIDE
	_splinter_mat.normal_enabled = true
	_splinter_mat.normal_texture = _TEX_INSIDE_N
	_splinter_mat.normal_scale = 1.0
	_splinter_mat.roughness = 1.0
	_splinter_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_splinter_mat.albedo_color = cut_wood_tint
	# ...and the SAME WOOD on the near-vertical walls a chop leaves in the side of a
	# trunk, which are long grain for exactly the same reason a splinter is: they run
	# down the length of the stem rather than across it. Its own material rather than
	# the splinters', because the mesher bakes the mapping into the UVs it generates
	# and must not have it scaled again (the same rule `_cut_mat` follows) while
	# `_splinter_mat.uv1_scale` is driven by `cut_tex_tile` in `_spawn_stand`.
	_side_mat = _splinter_mat.duplicate() as StandardMaterial3D
	_side_mat.uv1_scale = Vector3.ONE
	_tear_noise.frequency = tear_jag_freq
	_tear_noise.seed = 71

	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 0.9
	_phys_mat.bounce = 0.0
	$Floor.physics_material_override = _phys_mat
	# The ground is its own layer, and it is the one thing everything collides with.
	$Floor.collision_layer = TreeTrunk.GROUND_LAYER
	$Floor.collision_mask = 0
	_fit_ground_collider()

	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)

	_budget = _BUDGET.new()
	_budget.name = "FragmentBudget"
	add_child(_budget)

	_limit_shadows()
	_build_axe()
	_apply_camera()
	_spawn_stand()


func _exit_tree() -> void:
	GameFeel.unregister_camera()


## Left the forest (A7/A10). The player stops driving and the mouse goes back to the
## 2D village. This scene listens only — A7 is untouched, M5 still emits nothing but
## `action_hit_registered` and `resource_gathered`.
func _on_minigame_exited() -> void:
	if _player != null and is_instance_valid(_player):
		_player.release_mouse()
	# Walking out is the other way a felled trunk stops persisting: the timber the
	# player left lying in the clearing is booked in as they go, so leaving can never
	# lose them what the tree was authored to yield.
	if _bucking:
		_end_bucking()


## Make the ground the players see the ground things land ON.
##
## The scene's authored floor is a 60x2 m box whose top face is exactly y = 0,
## while `forest_floor_a` is a sculpted mesh sitting between y = 0.005 and
## y = 0.034 — so every splinter, chip and felled trunk was coming to rest 5 to 34
## mm UNDER the visible dirt. A splinter is 18 mm thick, so the deeper part of that
## range swallowed them whole, and it read as debris that had not settled properly.
## A collider taken off the floor mesh itself cannot disagree with the art.
##
## The box stays, untouched, as a backstop: its top face is 5 mm below the mesh's
## lowest point, so anything that ever slips past the triangles still stops within
## a splinter's thickness of the ground instead of falling to the void.
func _fit_ground_collider() -> void:
	var vis := get_node_or_null("forest_floor_a")
	if vis == null:
		return   # a harness or test scene without the art: the box alone will do
	_tile_ground(vis as Node3D)
	var faces := PackedVector3Array()
	var to_floor := _floor.global_transform.affine_inverse()
	# Every tile, not just the authored one — `_tile_ground` has already put the copies in
	# by the time this runs, and a tile the player can walk onto but not stand on is worse
	# than no tile at all.
	for tile in _ground_tiles():
		for mi in _mesh_instances(tile):
			if mi.mesh == null:
				continue
			var xform := to_floor * mi.global_transform
			for v in mi.mesh.get_faces():
				faces.append(xform * v)
	if faces.size() < 3:
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	# Both sides collide. Which way a trimesh face blocks depends on its winding,
	# and this is imported art nobody is going to police the winding of — a ground
	# plane that only stops things from underneath would be a very confusing bug.
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.name = "GroundSurface"
	cs.shape = shape
	_floor.add_child(cs)


## TILE THE GROUND OUT TO COVER THE STAND (plan §4). `forest_floor_a` is ONE patch — Sam's
## live scale 0.8 makes it about 16 m across — which was plenty for a camera bolted to one
## tree and is not plenty for a 50 m stand you walk through. The alternative to tiling is
## scaling one patch up, which stretches the texture until the ground reads as mud.
##
## The authored tile is left exactly where Sam put it and duplicated on its own footprint,
## so its scale and its 5 mm lift stay the artist's decision. The BOX BACKSTOP under it all
## is kept and is deliberately not resized to the grid: it is what stops debris leaving the
## world, and it is sized in the .tscn.
func _tile_ground(src: Node3D) -> void:
	if src == null or ground_tiles <= 0:
		return
	var span := _footprint(src)
	if span <= 0.01:
		push_warning("tree_felling: ground tile has no measurable footprint; not tiling.")
		return
	_ground_span = span
	var reach := ceili(maxf(forest_radius + span, 1.0) / span)
	reach = mini(reach, ground_tiles)
	for ix in range(-reach, reach + 1):
		for iz in range(-reach, reach + 1):
			if ix == 0 and iz == 0:
				continue   # the authored tile is already there
			var tile := src.duplicate() as Node3D
			tile.name = "forest_floor_%d_%d" % [ix, iz]
			add_child(tile)
			tile.transform = src.transform
			tile.position = src.position + Vector3(ix * span, 0.0, iz * span)
			_tiles.append(tile)


## The horizontal size of one ground tile, in WORLD metres — its own scale included, since
## that is what the tiles have to be spaced by.
func _footprint(src: Node3D) -> float:
	var box := AABB()
	var first := true
	for mi in _mesh_instances(src):
		if mi.mesh == null:
			continue
		var b := (src.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return 0.0
	var s := src.scale
	return maxf(box.size.x * s.x, box.size.z * s.z)


## Cap how far the sun casts shadows (plan §5). Shadowing one tree in a clearing and
## shadowing a whole stand are different jobs, and the far trees do not need to cast — you
## cannot see the ground under them from here.
func _limit_shadows() -> void:
	if shadow_distance <= 0.0:
		return
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun == null:
		return
	sun.directional_shadow_max_distance = shadow_distance


func _ground_tiles() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var src := get_node_or_null("forest_floor_a") as Node3D
	if src != null:
		out.append(src)
	for t in _tiles:
		if is_instance_valid(t):
			out.append(t)
	return out


func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_mesh_instances(child))
	return out


func _build_axe() -> void:
	_axe = _AxeRig.new()
	_axe.hidden_euler = axe_hidden_euler
	_axe.struck_euler = axe_struck_euler
	_axe.hover = axe_hover
	_axe.swing_time = swing_time
	_axe.denied_stop_frac = denied_swing_frac
	add_child(_axe)
	_axe.setup(_AXE_FBX, axe_scale)


## STAND THE WHOLE FOREST UP. Assumes the board is already clear — _clear_board() does
## that, either instantly (R) or by fading.
##
## Cheap by construction: `_plant` gives every tree its imported mesh, a pick volume and a
## collider, and NOT a voxel field. `tree_count == 1` reproduces M5's single tree at the
## origin exactly, which is what every headless suite and every shot tool is framed on.
func _spawn_stand() -> void:
	_reset_fall_state()
	_clear_stumps()
	# The CUT STATE is not reset here any more, and must not be: it belongs to a tree
	# (`trunk.cut`), and a tree that is about to be built has a fresh one already. Resetting
	# it from here would reach through `_cut()` into whichever OTHER tree happened to be the
	# active one — which in a stand is a tree the player has been working on.

	# The mesher bakes the mapping into the UVs it generates (the cut faces are one log
	# round, positioned on this trunk's axis), so the material must not scale them.
	_cut_mat.uv1_scale = Vector3.ONE
	_splinter_mat.uv1_scale = Vector3(cut_tex_tile, cut_tex_tile, 1.0)

	var placed := _scatter_positions()
	for i in range(placed.size()):
		var t := _plant(placed[i], i)
		if t == null:
			continue
		# Only the first tree bounces in. A whole stand dropping out of the sky at once is
		# a different effect entirely, and not one anybody asked for; the rest are simply
		# already standing there, which is what a forest looks like.
		if i == 0 and placed.size() == 1:
			_animator.animate_drop(t, drop_height, 0.0, Callable(), drop_time_ms)
	# THE TREE THE PLAYER STARTS NEXT TO IS BUILT NOW, not on its first blow.
	#
	# Lazy building is what makes a stand affordable (§3a), but the tree in front of the
	# player at load is one the game already knows will be chopped — deferring it only
	# guarantees that the very first swing of the session is the one that pays the ~35 ms.
	# Building it here costs one build at load, which is exactly what M5 has always done.
	#
	# It is also what keeps "the tree" meaning something before anything has been struck:
	# the acceptance suite, the shot tools and `trunk()` all ask.
	_engage(_nearest_tree())
	_prebuild_stand()


## VOXELISE EVERY TREE NOW, so that no tree ever changes under the player.
##
## Sam, 2026-07-30: *"when the player strikes the wood, there is a small lag, then the
## texture of the tree rotates ... there doesn't need to be a sleight of hand texture swap
## if we can avoid it."* There does not, and this is how it is avoided.
##
## A previewed tree is its imported mesh; a built one is the authored roots, a voxel band
## surface-netted off a signed-distance field, and the clipped crown. Those are two
## different surfaces of the same trunk — the band is round where the import is a 16-sided
## prism, its normals come from the field's gradient rather than from the artist, and its
## bark is a measured cylindrical wrap rather than a per-facet unwrap. Measured, the bark
## lands within 4 degrees (tree_01) and 8 degrees (tree_02) of the artist's own mapping, so
## it is not a wrong texture — but it IS a different surface, and swapping it in at the
## moment of the first blow is a visible pop with a stall in front of it. Doing it before
## the player has ever seen the tree means there is nothing to pop.
##
## THIS IS PLAN §3a's TRADE, MADE THE OTHER WAY, and the numbers are the reason it needs an
## export rather than a deletion. MEASURED on the shipping 25-tree stand
## (`core/tools/eager_build_probe.tscn`): **4.5 s and ~58 MB** to build them all, ~190 ms a
## tree. That is a real cost and it lands at forest entry, where the stand is already
## spawning — but it is far too big to hide inside a frame, so it cannot be amortised into
## the walk. Turn this OFF to get §3a's behaviour back (one tree built at load, the rest on
## their first blow), and note that `band_height_max` is the knob that moves both numbers:
## the field is nx*ny*nz and ny comes straight off it.
##
## PLACEHOLDER per Directive 3 — whether the forest costs a beat at entry or a hitch at
## every tree is Sam's call, and `prebuild_stand` is where it is made.
func _prebuild_stand() -> void:
	if not prebuild_stand:
		return
	for t in _trees:
		if is_instance_valid(t) and t.is_preview():
			# NOT `_engage`: that also makes the tree the ACTIVE one, and the active tree
			# must stay the one the player is standing at.
			t.build(t.source_mesh, _cut_mat, band_height, voxel_cell,
				cut_tex_tile, bark_tex_tile, _side_mat)


## BOOK IN AND CLEAR THE TRUNK ALREADY LYING ON THE GROUND, if there is one.
##
## Called when a new tree starts to fall, because only one felled trunk carries bucking state.
## THE YIELD INVARIANT IS THE POINT: whatever bucking has not already paid for is paid here, so
## a tree is worth exactly its authored `TreeDef.yields` whether the player bucked it out, part
## bucked it, or walked off and dropped another tree on top of it.
func _finalise_felled_timber() -> void:
	if not _bucking and _logs.is_empty():
		return
	_bucking = false
	_buck_target = null
	_buck_hits = 0
	# Its logs fly to the player too, rather than quietly fading — the player earned them, and
	# seeing them arrive is the whole point of the flight. `_release_timber` settles the yield at
	# launch, so this trunk is paid for whatever happens to the new one.
	if not _release_timber():
		_collect_yields()
		for log_body in _logs:
			if is_instance_valid(log_body):
				(log_body as RigidBody3D).freeze = true
				FadeOut.run(log_body, fade_time)
	_logs.clear()
	_logs_paid = 0
	_collected = false
	_fallen = null
	_falling = null
	_hinge = null
	_clear_attached_canopies()


## Take the stumps away too. A FRESH BOARD only (R, or a respawned stand) — a felling leaves
## its stump standing, which is the whole point of `stumps_persist`.
func _clear_stumps() -> void:
	for stump in _stumps:
		if is_instance_valid(stump):
			stump.queue_free()
	_stumps.clear()


## FORGET THE TREE THAT JUST CAME DOWN, so the axe is free for the next one.
##
## THIS IS WHY A SECOND TREE COULD NOT BE CHOPPED. All of it used to live inside
## `_spawn_stand`, which is correct for a board that always replaces its one tree and wrong
## the moment there is a stand and nothing regrows: `_felling` is set when a tree starts over
## and was only ever cleared by spawning a fresh board, so with `auto_respawn` off it stayed
## true for the rest of the session — and `_on_click` refuses every blow while it is set,
## because one tree falls at a time. The player felled their first tree and the axe went dead.
##
## Called when the felled tree and its wreckage leave the board, and by `_spawn_stand` for a
## fresh one. It is deliberately about THE FALL and never touches a tree's cut state, which
## belongs to the tree.
func _reset_fall_state() -> void:
	_clear_attached_canopies()
	_pending = {}
	_felling = false
	_hinge_intact = true
	_reset_landing_state()
	_collected = false
	_bucking = false
	_buck_target = null
	_buck_hits = 0
	_buck_idle = 0.0
	_logs_paid = 0
	_logs.clear()
	_fall_age = 0.0
	_still_for = 0.0
	_tear_debt = 0.0
	_fade_at = -1.0
	_respawn_at = -1.0
	_falling = null
	_fallen = null
	_hinge = null


## THE LANDING BOOKKEEPING FOR ONE FALL. Split out of `_reset_fall_state` because it has
## to run at the START OF EVERY FALL as well, and the rest of that function must not:
## it clears the fade, the respawn, the bucking and `_felling` itself, all of which
## `_begin_fell` is in the middle of setting up or deliberately leaving alone.
##
## THIS IS WHY THE SECOND TREE OF A SESSION KEPT ITS LEAVES. `_reset_fall_state` is
## reached from exactly two places — a fresh board, and the fade that follows a trunk
## being bucked out. The stand ships `trunk_persists` on and nothing regrows, so a
## player who fells a tree and walks off to the next one without bucking the first out
## never reaches either. `_landed` and `_settled` were therefore still true from the
## PREVIOUS tree when the next one started to fall, and both of the functions that run a
## landing bail on exactly those flags:
##
##   - `_on_trunk_contact` returns on `if _landed`, so `_clear_attached_canopies()` never
##     ran — the felled trunk lay on the ground with its branches and leaves still on it,
##     which is what Sam reported — and the landing had no impact, no slow-motion beat
##     and no kicked-up debris either;
##   - `_watch_fallen` returns on `or _settled`, so the trunk was never damped, never
##     frozen, `_begin_bucking()` never ran (the second tree could not be cut into logs
##     at all), and `_felling` was never cleared at the settle.
##
## MEASURED before the fix, felling three trees in the shipping stand without bucking:
## tree 1 shed its canopy and went to bucking; trees 2 and 3 kept theirs and never
## started bucking. Same family as the "felling one tree killed the axe" bug — per-fall
## state that only a fresh board reset — and this is the rest of that family.
func _reset_landing_state() -> void:
	_landed = false
	_land_at = 0.0
	_damped = false
	_impact_speed = 0.0
	_prev_speed = 0.0
	_slam_cool = 0.0
	_settled = false


## WHERE THE TREES STAND. A seeded rejection scatter: pick a point in the stand, keep it if
## it is `min_tree_spacing` from every tree already placed and outside `spawn_clear_radius`.
##
## Seeded from `forest_seed` through a LOCAL RandomNumberGenerator, never the global `randi`,
## so the layout is identical every run and cannot be perturbed by anything else in the game
## drawing a random number. A forest that reshuffles itself makes every measurement and
## every render shot incomparable with the last.
##
## With `tree_count == 1` this returns the origin, which is exactly where M5's single tree
## has always stood — so the whole suite and every shot tool keep framing the same tree.
func _scatter_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if tree_count <= 1:
		out.append(Vector3.ZERO)
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed
	var spawn := _player.global_position if _player != null and is_instance_valid(_player) \
		else Vector3.ZERO
	spawn.y = 0.0
	# Bounded tries, not "until we have enough": a spacing the stand cannot physically hold
	# would otherwise spin here for ever. Falling short is reported rather than hidden.
	var tries := 0
	while out.size() < tree_count and tries < tree_count * 200:
		tries += 1
		# Square-root radius, or a uniform pick in (angle, radius) crowds the middle.
		var a := rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * forest_radius
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if p.distance_to(spawn) < spawn_clear_radius:
			continue
		var ok := true
		for q in out:
			if p.distance_to(q) < min_tree_spacing:
				ok = false
				break
		if ok:
			out.append(p)
	if out.size() < tree_count:
		push_warning(("tree_felling: only %d of %d trees fit in a %.0f m stand at %.1f m "
			+ "spacing. Raise forest_radius or lower min_tree_spacing.") % [
			out.size(), tree_count, forest_radius, min_tree_spacing])
	return out


## Stand one tree up at `where` — CHEAPLY. It is its imported mesh, a pick volume and a
## collider until the first blow lands on it (see TreeTrunk.preview and `_engage`).
func _plant(where: Vector3, index: int) -> TreeTrunk:
	var species_index := _pick_species_index(index)
	var species := _TREE_SPECIES[species_index]
	var def := load(species.def) as TreeDef
	if def == null:
		push_error("tree_felling: '%s' is not a TreeDef — falling back to defaults." % species.def)
		def = TreeDef.new()
	# Size varied per tree, seeded off the same forest seed and the tree's index so it is
	# stable run to run. Baked into the MESH, exactly as the lean is, and for the same
	# reason: a scaled NODE would put the voxel band in a scaled frame.
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed + index * 7919
	var scale_i: float = tree_scale * float(species.get("source_scale", 1.0))
	if index > 0 and tree_size_variation > 0.0:
		scale_i *= 1.0 + rng.randf_range(-tree_size_variation, tree_size_variation)
	var mesh := _lean_mesh(MeshUtils.scaled(MeshUtils.mesh_from_path(species.model), scale_i))

	var t := TreeTrunk.new()
	t.name = "Tree%d" % index
	t.tear_amount = tear_jag_amount
	t.tear_noise = _tear_noise
	t.def = def
	t.species_id = species.id
	t.species_index = species_index
	t.trunk_surface = int(species.get("trunk_surface", -1))
	for surface in species.get("canopy_surfaces", []):
		t.canopy_surfaces.append(int(surface))
	t.trunk_base_y = float(species.get("trunk_base_y", -INF))
	t.voxel_roots = voxel_roots
	t.band_height_max = band_height_max
	add_child(t)
	t.position = where
	# Each tree faces a different way, so one mesh does not read as one mesh. Yaw only —
	# a tilted tree is what `natural_lean_deg` is for and it belongs in the mesh.
	if index > 0:
		t.rotation.y = rng.randf() * TAU
	if not t.preview(mesh, band_height, voxel_cell):
		push_error("tree_felling: could not stand up '%s'." % species.model)
		t.queue_free()
		return null
	_trees.append(t)
	return t


## MAKE THIS TREE THE ONE THE AXE IS WORKING, and build its wood if this is the first blow
## it has ever taken.
##
## The build is ~30-40 ms (the same cost a blow's carve and remesh already pay) and it
## happens INSIDE the click, before `anticipation_sec` — which is where the existing
## per-blow cost already hides, at the moment of impact, under the A11 hit-pause. Paying it
## per tree on first contact rather than for the whole stand at load is plan §3a.
func _engage(trunk: TreeTrunk) -> bool:
	if trunk == null or not is_instance_valid(trunk):
		return false
	_trunk = trunk
	_tree_def = trunk.def if trunk.def != null else _tree_def
	if trunk.is_built():
		return true
	if not trunk.build(trunk.source_mesh, _cut_mat, band_height, voxel_cell,
			cut_tex_tile, bark_tex_tile, _side_mat):
		push_error("tree_felling: could not build wood for '%s'." % trunk.name)
		return false
	_warn_cut_span()
	return true


## Put one tree back where the last felled one stood. `auto_respawn` only, which in
## practice means the single-tree harness and the acceptance suite: Sam's forest is a finite
## stand you clear, so nothing regrows in it.
func _replant_cleared() -> void:
	var t := _plant(_cleared_at, 0)
	if t == null:
		return
	# Built straight away, for the same reason the tree the player starts next to is: this
	# one is replacing a tree they just felled and are standing over.
	_engage(t)
	_animator.animate_drop(t, drop_height, 0.0, Callable(), drop_time_ms)


## The tree nearest the player, built or not. What "the tree" means when nothing is being
## chopped — the tests, the shot tools and the HUD all want a sensible answer.
func _nearest_tree() -> TreeTrunk:
	var best: TreeTrunk = null
	var best_d := INF
	var eye := _player.global_position if _player != null and is_instance_valid(_player) \
		else Vector3.ZERO
	for t in _trees:
		if not is_instance_valid(t):
			continue
		var d := t.global_position.distance_to(eye)
		if d < best_d:
			best_d = d
			best = t
	return best


## Say so if `cut_span` has been dialled below what can actually sever this trunk.
##
## A blow's slab is centred on the trunk's axis, so a span narrower than the trunk leaves
## flanks either side that no amount of chopping from one viewpoint will reach — the tree
## simply never falls, with no clue as to why. That is a nasty thing to leave a tuning
## value able to do silently, so it is called out once per tree.
## Say so if `cut_span` has been dialled below what can actually sever this trunk.
##
## A blow's slab is centred on the trunk's axis, so a span narrower than the trunk leaves
## flanks either side that no amount of chopping will reach — the tree simply never falls,
## with no clue as to why. That is a nasty thing to leave a tuning value able to do
## silently, so it is called out once per tree.
##
## RE-MEASURED ON FOOT, 2026-07-26, and the FPS plan's guess was WRONG. Plan §2 reasoned
## that "an FPS player can walk around the trunk, so that premise no longer holds and
## 0.50 may become perfectly playable". `core/tools/felling_spam.gd`'s walk phase fells
## the same tree standing still and walking right round it, at four spans, and says
## otherwise (tree_01, 0.94 m across, pinned settings):
##
##   1.60 m  11 blows standing   23 walking
##   0.80 m  13 blows standing   22 walking
##   0.50 m  NEVER FELL          NEVER FELL   (150 blows each, cut 100% of the diameter)
##   0.35 m  NEVER FELL          NEVER FELL
##
## Walking does not rescue it, and the reason is geometry rather than viewpoint: cutting
## a 0.5 m channel from every direction hollows the middle out of the trunk and leaves a
## SHELL, and a shell of that section still carries the tree comfortably. The old "from
## one viewpoint" wording was wrong about the cause and right about the outcome. Walking
## does cost MORE blows at every span, because a cut on a new face is a new cut rather
## than a deeper one — which is `cut_face_arc_deg` working as intended.
##
## Sam's live value is 0.50. It is a value that cannot fell tree_01, and this is what
## says so.
func _warn_cut_span() -> void:
	# Once per GAME, not once per tree: a stand of 25 would otherwise say the same thing
	# 25 times and bury everything else in the log.
	if _warned_span or not _has_tree() or cut_span >= _trunk.diameter * 0.85:
		return
	_warned_span = true
	push_warning(("tree_felling: cut_span %.2f m is narrower than this %.2f m trunk. A blow "
		+ "cuts a channel through the middle of the face rather than the whole of it, and "
		+ "cutting that channel from every side hollows the trunk out into a shell that "
		+ "still holds the tree up. MEASURED 2026-07-26 on foot: at 0.50 m and below "
		+ "tree_01 does not come down in 150 blows, standing still OR walking right round "
		+ "it. Above about %.2f m it fells normally.") % [
		cut_span, _trunk.diameter, _trunk.diameter * 0.85])


## Tip the tree a couple of degrees before it is stood up, about its own butt so
## it stays in the ground.
##
## THIS IS THE MECHANIC, not decoration. A perfectly upright tree is balanced on
## its own holding wood: cut a notch and a back cut and the wood left in the
## middle is still under the trunk's centre of mass, so it has nothing to topple
## about and will sit back rather than fall — which is the real problem a faller
## reads a tree for, and the reason the manual has you pick the direction of fall
## before you swing. Whichever way it leans is the way it wants to be notched;
## notch the other side and you have to cut past the centre of the trunk to win.
##
## Baked into the MESH rather than the node: the node's transform belongs to the
## spawn animation, and a tilted node would put the voxel band in a tilted frame
## for no gain.
func _lean_mesh(mesh: Mesh) -> Mesh:
	if natural_lean_deg <= 0.0 or mesh == null:
		return mesh
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0.0, sin(a))
	var aabb := mesh.get_aabb()
	var pivot := Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)
	return MeshUtils.rotated(mesh,
		Basis(Vector3.UP.cross(dir).normalized(), deg_to_rad(natural_lean_deg)), pivot)


## Take THE FELLED TREE and its wreckage off the board. `fade` dissolves it (the end of a
## felling) — otherwise it goes instantly (the R key).
##
## WITH A STAND, this clears the tree that was being worked and NOTHING ELSE. The rest of
## the forest is still standing there and the player may be looking straight at it; the
## stump, the trunk, its bucked lengths and its splinters are what go.
func _clear_board(fade: bool) -> void:
	_cut().kill_lean()
	_clear_attached_canopies()
	var doomed: Array[Node3D] = []
	if _trunk != null and is_instance_valid(_trunk):
		# Remember the slot, so `auto_respawn` (the single-tree harness) can put a tree
		# back exactly where the last one stood. With Sam's "a finite stand you clear",
		# nothing regrows in the forest and this is simply never read.
		_cleared_at = _trunk.position
		_trees.erase(_trunk)
		# THE STUMP STAYS. Sam's call, 2026-07-27: the tree is gone, the stump is not, and a
		# stand full of stumps is what a stand you have cleared looks like. It keeps the
		# collider `_build_standing_body` handed over at the break, so a stump is still
		# something you walk into rather than through.
		#
		# Only on a FADE (the end of a felling). The R key clears the board outright and means
		# it, so it takes the stumps with it — see `_clear_stumps`.
		if fade and stumps_persist and _trunk.has_broken():
			_stumps.append(_trunk)
		else:
			doomed.append(_trunk)
	if _falling != null and is_instance_valid(_falling):
		doomed.append(_falling)
	if _fallen != null and is_instance_valid(_fallen):
		_fallen.freeze = true
		doomed.append(_fallen)
	for log_body in _logs:
		# The bucked lengths, if the trunk was cut up. `_fallen` is the first entry
		# while it is still whole, so it must not be added twice.
		if is_instance_valid(log_body) and log_body != _fallen:
			(log_body as RigidBody3D).freeze = true
			doomed.append(log_body)
	for body in _chips:
		if is_instance_valid(body):
			# A chip that dissolves mid-roll looks like a bug; stop them dead so
			# the whole clearing fades as one still image.
			(body as RigidBody3D).freeze = true
			doomed.append(body)
	_trunk = null
	_falling = null
	_fallen = null
	_hinge = null
	_chips.clear()
	_logs.clear()
	if not fade:
		# A hard wipe (R). Anything in flight was PAID FOR AT LAUNCH, so dropping it loses the
		# player nothing — see _release_timber.
		_flight.clear()
	_bucking = false
	_buck_target = null
	_animator.clear()

	for node in doomed:
		if fade:
			FadeOut.run(node, fade_time)
		else:
			node.queue_free()


## THE CUT STATE OF THE TREE THE AXE IS WORKING (`tree_cut_state.gd`).
##
## Never null: a game with no tree in front of the player still gets asked for
## `notch_depth()` by the tests and the HUD, and answering "nothing has been cut" is
## correct. The scratch state is deliberately thrown away rather than kept — writing into
## it can never leak onto a real tree.
func _cut() -> TreeCutState:
	if _trunk != null and is_instance_valid(_trunk):
		return _trunk.cut
	return TreeCutState.new()


## A tree that exists AND was assembled — build() can bail on a mesh it cannot
## stand up, and there is nothing to chop if it did.
func _has_tree() -> bool:
	return _trunk != null and is_instance_valid(_trunk) and _trunk.is_built()


## Pick a type from the forest seed and this tree's stable slot, never from the
## global random stream. A stand therefore keeps the same species composition
## across runs just as it keeps the same positions, sizes and yaws.
func _pick_species_index(tree_index: int) -> int:
	if debug_forced_species >= 0 and debug_forced_species < _TREE_SPECIES.size():
		return debug_forced_species
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed + tree_index * 104729 + 31
	return rng.randi_range(0, _TREE_SPECIES.size() - 1)


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	_animator.update()
	_flight.update()
	# ONCE A FRAME, not once per chip. Retiring is a pass over the whole debris list that
	# can rewrite a MultiMesh, and a blow spawns about a dozen chips — so running it from
	# `_spawn_chip` did that whole pass twelve times for one blow's worth of debris, and
	# the blows where it fired were the 300 ms spikes in `felling_profile`. The cap is a
	# SOFT one by design (see `_retire_old_debris`), so a frame's grace changes nothing.
	_retire_old_debris()
	if not player_controlled:
		# The DEV camera, and only then. Re-applied every frame rather than once, so
		# the three camera numbers can be dragged in the inspector while the game is
		# running — which is how the shot tools have always framed their renders.
		_apply_camera()

	if not _pending.is_empty():
		_pending.timer -= delta
		if _pending.timer <= 0.0:
			var pd := _pending
			_pending = {}
			_land_blow(pd.side, pd.local_y, pd.world_point, pd.azimuth)

	_step_hinge(delta)
	_watch_fallen(delta)

	# The felled trunk waits to be bucked. Left to persist it waits indefinitely and
	# only goes once there is nothing left long enough to cut; otherwise it gives up
	# on the player after `buck_idle_clear` of not being touched.
	if _bucking:
		_buck_idle += delta
		if _bucked_out():
			_end_bucking()
		elif not trunk_persists and _buck_idle >= buck_idle_clear:
			_end_bucking()

	# The felled tree lies there a beat, then dissolves INTO the inventory — the
	# timber is booked in as it starts to go, so the deposit and the tree fading
	# away read as the same moment. The next tree bounces in once it has gone.
	if _fade_at >= 0.0:
		_fade_at -= delta
		if _fade_at < 0.0:
			_fade_at = -1.0
			_clear_board(true)
			_collect_yields()
			# THE AXE IS FREE AGAIN. Order matters: the yields are booked in off the state
			# this then clears (`_logs_paid`, `_collected`), so it goes last.
			_reset_fall_state()
			_respawn_at = fade_time

	if _respawn_at >= 0.0:
		_respawn_at -= delta
		if _respawn_at < 0.0:
			_respawn_at = -1.0
			# REGROWTH, and Sam's answer to it was "a finite stand you clear" — so nothing
			# comes back in a forest. `auto_respawn` survives for the single-tree harness and
			# the acceptance suite, which need a fresh tree to check the loop closes, and it
			# replants the slot the felled tree left rather than re-scattering the stand.
			if auto_respawn:
				_replant_cleared()


## The attached half of the fall: the trunk rotating about its own hinge under
## its own weight, with the last of the holding wood tearing. Nothing is pushing
## it — see hinge_fall.gd.
func _step_hinge(delta: float) -> void:
	if _hinge == null or _falling == null or not is_instance_valid(_falling):
		return
	var rot := _hinge.step(delta, gravity * fall_gravity_scale)
	_falling.global_transform = Transform3D(rot * _fall_rest_basis, _hinge.pivot)
	# Fibres let go all the way over: a steady spray from the hinge until it is
	# torn right through.
	if not _hinge.torn():
		_tear_debt += tear_splinter_rate * delta
		while _tear_debt >= 1.0:
			_tear_debt -= 1.0
			_spit_hinge_splinter()
	if _hinge.done():
		_go_free()


## Wait for the fallen trunk to stop moving, then freeze it and start the fade.
##
## Also the only place the trunk's speed is watched, and that watching does real
## work: the tip speed carried into the landing is what scales the impact, and a
## sharp drop in it is a collision — which is how the butt crashing down after the
## top, and any bounce on the way, get to register at all. `body_entered` fires
## once per body and the ground is one body, so on its own it reports exactly one
## of the several bangs a tree makes on its way to lying still.
func _watch_fallen(delta: float) -> void:
	if _fallen == null or not is_instance_valid(_fallen) or _settled:
		return
	_fall_age += delta
	var speed := _tip_speed()
	_slam_cool = maxf(_slam_cool - delta, 0.0)
	if not _landed:
		# Carried into _on_trunk_contact: by the time a contact is reported the
		# solver has already taken the speed away, so the frame before it is the
		# only honest measure of how hard the tree arrived.
		_impact_speed = maxf(_impact_speed, speed)
	elif _slam_cool <= 0.0 and _prev_speed - speed >= secondary_impact_speed:
		if _register_slam(_prev_speed - speed, secondary_impact_max) > 0.0:
			_slam_cool = secondary_impact_gap
	_prev_speed = speed

	# Once the crashing is over, damp it down hard: a perfect cylinder rolls
	# forever otherwise. Delayed rather than done on contact, so the slam is
	# allowed to happen first.
	if _landed and not _damped and _fall_age - _land_at >= land_slam_time:
		_damped = true
		_fallen.angular_damp = trunk_land_angular_damp
		_fallen.linear_damp = trunk_land_linear_damp

	var still: bool = _fallen.linear_velocity.length() < trunk_settle_speed \
		and _fallen.angular_velocity.length() < trunk_settle_spin
	# Safety net for the landing: if it has gone right over and stopped moving it
	# is down, whether or not a contact report reached us (the splinter burst can
	# crowd the contact slots).
	if not _landed and still and _trunk_tilt_deg() >= 60.0:
		_on_trunk_contact(_floor)
	_still_for = _still_for + delta if (still and _landed) else 0.0
	if _still_for >= trunk_settle_hold or _fall_age >= fall_timeout:
		_settled = true
		_fallen.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		_fallen.freeze = true
		# ...AND THE CANOPY GOES WITH IT, whatever route got us here. A settled trunk is a
		# trunk that is down, so this is the same moment `_on_trunk_contact` means; it is
		# a second call in the ordinary case (the list is emptied, so it costs nothing) and
		# the only one when the landing was never registered. It CAN be: `fall_timeout`
		# settles a trunk that never stopped moving, and a tree that hangs up on a
		# neighbour in the stand can come to rest under the safety net's 60-degree tilt
		# with no contact ever reported. Without this the leaves stay on it for good, and
		# the next thing that happens to that trunk is bucking, which would cut them up.
		_clear_attached_canopies()
		# THE AXE IS FREE THE MOMENT THE FALL IS OVER, and this is where that has to happen.
		#
		# `_felling` means "a tree is going over RIGHT NOW" — that is the whole of what §3d
		# asks for, one fall at a time. It used to be cleared only when a fresh board was
		# spawned, which was fine while the board always replaced its one tree and is wrong in
		# a stand where nothing regrows and a felled trunk PERSISTS until bucked: the flag
		# stayed set, `_on_click` refuses every blow while it is, and the player's axe went
		# dead for the rest of the session after their first tree. Reported by Sam.
		_felling = false
		_pending = {}
		if buck_enabled:
			_begin_bucking()
		else:
			_fade_at = fade_delay


## How fast the far tip of the trunk is travelling (m/s) — linear motion plus what
## the spin adds out at the end. The tip is the part that arrives first and hardest
## and it is what the eye is following, so it, not the centre of mass, is the
## measure of a landing: a tree pivoting over about its butt has a centre of mass
## barely moving while the top is coming down like a hammer.
func _tip_speed() -> float:
	if _fallen == null or not is_instance_valid(_fallen):
		return 0.0
	var tip := _fallen.global_transform * Vector3(0.0, _fallen_length, 0.0)
	var r := tip - _fallen.global_position
	return (_fallen.linear_velocity + _fallen.angular_velocity.cross(r)).length()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	# WASD belongs to the player now, so the old A/D orbit is gone with it — see
	# _apply_camera for where the orbit went.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_R:
			_clear_board(false)
			_spawn_stand()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_click()


## CLICK TO CHOP. One click, one blow, at WHATEVER THE CROSSHAIR IS ON.
##
## The click no longer carries a screen position, because in first person there is
## only ever one: the middle. Where on the tree the blow lands, which side of it the
## axe comes from and the ANGLE OF ENTRY all come off the 3D point the player is
## looking at (see `_aim`).
func _on_click() -> void:
	if _bucking and _buck_click():
		return   # a felled trunk is under the crosshair; clicks cut it into logs
	if _felling or not _pending.is_empty():
		# ONE TREE FALLS AT A TIME (plan §3d, and its recommendation): a blow on another
		# tree is refused while one is going over. Making the fall re-entrant is a large
		# job for very little — the player is watching the tree they just felled.
		return
	var aim := _aim()
	if not aim.ok:
		return   # not looking at wood, or standing too far off to reach it
	var trunk: TreeTrunk = aim.trunk
	if _animator.is_animating(trunk):
		return   # still bouncing into place
	# THE FIRST BLOW BUILDS THE WOOD (plan §3a). Until now this tree has been a cheap
	# imported mesh; `_engage` turns it into a voxel volume. Doing that for a whole stand
	# at load is the thing that would make a forest unshippable.
	if not _engage(trunk):
		return
	_begin_strike(aim.side, aim.local_y, aim.azimuth)


# --------------------------------------------------------------------- aim
## WHAT THE PLAYER IS LOOKING AT, and everything a blow needs taken off it:
## `{ok, point, local_y, side, azimuth}`.
##
## THIS IS THE FIRST-PERSON AIM (plan §2, Option A — cut where you look), and it
## replaces the screen-space arithmetic wholesale. The old path compared the click's
## `screen_pos.x` against the trunk's unprojected x and treated anything inside 2 px
## as a tie; at a crosshair pointed straight at a trunk those two numbers are ALWAYS
## within a pixel or two, so side selection and `entry_angle_deg` would both have
## collapsed to their tie-break — and the angle of entry is precisely what M5 PASS 5
## exists to give the player.
##
## The 3D hit point answers both questions better than the screen ever did:
##   - the ray strikes the trunk's NEAR surface, so the cut is always on the side the
##     player can see, which is Sam's rule from PASS 6 falling out of the geometry
##     rather than being enforced on top of it;
##   - the horizontal offset of that point from the trunk's axis IS the entry
##     azimuth — how far round from head-on the wood was pointed at.
func _aim() -> Dictionary:
	var miss := {"ok": false, "point": Vector3.ZERO, "local_y": 0.0,
		"side": 0, "azimuth": deg_to_rad(entry_angle_deg), "trunk": null}
	if _player == null or not is_instance_valid(_player):
		return miss
	var ray := _player.aim_ray()
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (chop_reach + 1.0))
	# The pick volume is an AREA (TreeTrunk._build_picker), so bodies are off and
	# areas are on — the stump's own collider must not swallow the aim.
	q.collision_mask = TreeTrunk.PICK_LAYER
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return miss
	# WHICHEVER TREE THE RAY HIT. Each trunk carries its own pick volume, so with a stand
	# to walk through this is the whole of "which tree am I chopping" — the ray answers it,
	# rather than the game assuming there is only one.
	var trunk := _trunk_for_picker(hit.collider)
	if trunk == null:
		return miss
	var point: Vector3 = hit.position
	if point.distance_to(_player.eye_position()) > chop_reach:
		return miss   # too far to swing at

	# The height, clamped to the carveable band exactly as the old axis-segment aim
	# clamped it — so looking up the crown still chops at the top of the band rather
	# than doing nothing.
	#
	# UNBUILT trees have no band yet (§3a: the voxels are only built when the first blow
	# lands), so the clamp is deferred — `_land_blow` re-clamps once the wood exists.
	var local_y := point.y - trunk.global_position.y
	if trunk.is_built():
		local_y = clampf(local_y, _min_local_y_of(trunk), _max_local_y_of(trunk))

	var res := _decompose(point, trunk)
	return {"ok": true, "point": point, "local_y": local_y,
		"side": res.side, "azimuth": res.azimuth, "trunk": trunk}


## Which tree owns this pick collider, or null. Linear over the stand on purpose: it runs
## once per click, and a stand is tens of trees, not thousands.
func _trunk_for_picker(collider: Object) -> TreeTrunk:
	if collider == null:
		return null
	for t in _trees:
		if is_instance_valid(t) and t.picker() == collider:
			return t
	return null


## Split a point on the trunk into the two things a cut is made of: WHICH SIDE of the
## trunk it is on, and how far round from head-on it sits.
##
## This is the exact inverse of `_side_dir`, which builds a cut direction as
## `right * side * sin(azimuth) + toward_camera * cos(azimuth)`. So the side is the
## sign of the offset along the camera's right, and the sine of the azimuth is how
## much of the offset lies along it. Nothing is invented: it is where on the round
## trunk the player actually pointed.
func _decompose(world_point: Vector3, trunk: TreeTrunk) -> Dictionary:
	# The tree's OWN committed fall side, not the active tree's — the aim ray can land on
	# any tree in the stand, including one that has never been touched.
	var committed: int = trunk.cut.face_side
	var fallback := {"side": (committed if committed != 0 else 1),
		"azimuth": deg_to_rad(entry_angle_deg)}
	# Through the trunk's own transform: the stand yaws every tree, so the centre line is
	# not `global_position` plus an unrotated local offset. See TreeTrunk.axis_point.
	var off := world_point - trunk.axis_point()
	off.y = 0.0
	if off.length() < 0.0001:
		return fallback   # dead on the axis (the pick cylinder's end cap, from above)
	off = off.normalized()
	var right := _camera.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.0001:
		return fallback
	right = right.normalized()
	var across := off.dot(right)
	# A tie — looking straight down the centre line — keeps the fall where it already
	# is, so a dead-centre aim can never flip a committed tree.
	var side := (committed if committed != 0 else 1) if absf(across) < 0.001 \
		else (1 if across > 0.0 else -1)
	return {"side": side, "azimuth": _entry_azimuth(absf(across))}


## The entry azimuth an aim implies: the angle of the point on the trunk that was
## pointed at, measured from head-on, never rounder to the front than
## `entry_angle_deg`. `edge` is 0 on the centre line and 1 at the silhouette.
func _entry_azimuth(edge: float) -> float:
	return maxf(asin(clampf(edge, 0.0, 1.0)), deg_to_rad(entry_angle_deg))


func _max_local_y() -> float:
	return _max_local_y_of(_trunk)


## The highest a cut can land on a GIVEN tree. Per-trunk now that there is a stand of
## them: they are not all the same size, and the aim ray can hit any one of them.
##
## IT STOPS AT THE WOOD THE PLAYER CAN SEE, not at the top of the field. The crown's
## imported mesh laps down over the band's rim by `_CROWN_OVERLAP` cells (0.14 m at the
## shipping cell), deliberately, so the join has no slit of daylight in it — which means
## the top 0.14 m of the band is BEHIND the crown and a notch carved there cannot be seen
## at all. This clamp is what an eye-height crosshair hits: a standing player looks at a
## trunk somewhere around 1.65 m, and on any tree whose branches start near that height
## the aim is clamped, so it was landing in exactly that hidden strip. Wood came out, the
## load model saw it, the screen did not change — Sam's "they seem to be getting cut, but
## visually I am not seeing any change", and the half of it that survived giving the band
## its proper height back.
func _max_local_y_of(trunk: TreeTrunk) -> float:
	if trunk == null or not is_instance_valid(trunk) or not trunk.is_built():
		return INF
	# A height fraction becomes a LOCAL Y only after adding the mesh's base.
	# The original tree happened to start near y=0, hiding the distinction.
	# Both current FBXs extend below zero; using only `height * fraction`
	# therefore allowed a cut site above a short voxel band (tree_02 ends at
	# y=0.44) where bookkeeping advanced but there was no wood to carve.
	var cap := minf(trunk.band_lo + trunk.height * max_cut_height_frac, trunk.crown_base())
	# ...AND NO HIGHER THAN THE PLAYER CAN REASONABLY SWING (2026-07-30, Sam's call: "cap
	# the aim at ~50cm above head height"). A faller works at chest height; the band is
	# three metres tall because the crown's hand-over wants to sit well above the eyeline
	# where nobody looks at it, NOT because the axe should reach the top of it.
	#
	# Measured against the PLAYER, not against the tree, so it means the same thing on a
	# tall trunk and a short one — and converted into this trunk's local frame, because a
	# tree stands on the ground wherever the scatter put it.
	if _player != null and is_instance_valid(_player):
		var eye := _player.global_position.y + _player.eye_height
		cap = minf(cap, eye + cut_height_above_eye - trunk.global_position.y)
	return cap


## THE LOWEST A BLOW IS ALLOWED TO LAND (local Y) — far enough above the band's floor for
## a whole notch to fit under it.
##
## A notch is a WEDGE, and the room it opens is counted as the run of heights whose wood
## no longer reaches the bark (`_void_height`). Cut too near the bottom of the band and
## the wedge's lower half falls off the end of the field — where the wood is the tree's
## authored root flare, which is real timber the trunk would come down on, so stopping the
## run there is right. What is wrong is letting the player aim somewhere that can never
## open up. MEASURED on tree_01 before this clamp: a cut at `band_lo + 0.05` reached 100%
## of its own section, then took forty more blows removing 6 mm³ between them with the
## opening stuck at 0.220 m and the stress plateaued at 0.78 — a tree that cannot be
## felled, from an aim the crosshair reaches by looking slightly down.
##
## The margin is `topple_min_open`, which is not a new number: it is exactly the opening
## the load model already demands before a tree may hinge at all, so the lowest cut the
## player can aim is the lowest one that can work. Capped at a quarter of the band so a
## short band is not clamped out of existence.
func _min_local_y_of(trunk: TreeTrunk) -> float:
	if trunk == null or not is_instance_valid(trunk) or not trunk.is_built():
		return -INF
	return trunk.band_lo + minf(topple_min_open, (trunk.band_hi - trunk.band_lo) * 0.25)


# ------------------------------------------------------------------ strike
## Start a swing. Gear gating (A8/M5) is resolved HERE, before the anticipation:
## an axe below the tree's hardness_level bounces off — the swing plays short,
## nothing is cut, and the tree is not marked.
func _begin_strike(side: int, local_y: float, azimuth := PI * 0.5) -> void:
	var impact := _impact_point(side, local_y, azimuth)
	var tier := GameState.get_tool_tier(Enums.ToolType.AXE)
	_aim_axe(side, _preview_angle(side, local_y, azimuth), azimuth)
	if tier < _tree_def.hardness_level:
		_axe.swing_denied(impact)
		if denied_emits_hit:
			EventBus.action_hit_registered.emit(impact, tier, _dir_from_side(side))
		return
	_axe.swing(impact)
	_pending = {"side": side, "local_y": local_y, "world_point": impact,
		"azimuth": azimuth, "timer": anticipation_sec}


## Where the axe lands and the A7 hit is reported. Once the notch exists the axe
## goes to the notch (or to the back cut) rather than to the cursor — chasing the
## cursor is what used to scatter cuts up and down the trunk.
func _impact_point(side: int, local_y: float, azimuth := PI * 0.5) -> Vector3:
	var y := local_y
	if _cut().face_side != 0:
		var near := _site_at(side, local_y, _cut_dir(side, azimuth))
		if near >= 0:
			# The axe goes back to the cut it is working — but only when the click was
			# near it. Click somewhere else and the axe goes there instead, which is
			# the whole point of being allowed to cut wherever you like.
			y = _cut().sites[near].y
	y = clampf(y, _min_local_y_of(_trunk), _max_local_y())
	return _trunk.axis_point(y) + _cut_dir(side, azimuth) * _trunk.radius


## Which way THIS cut opens: outward from the trunk toward the point on it that was
## clicked. ALWAYS on the side facing the camera — there is no such thing as cutting from
## behind the tree any more.
##
## Sam's call, 2026-07-25: *"I dont like the way striking the opposite end of the tree
## feels. all the cuts should be like the head on cut. No 'opposite side cutting' where you
## cant see what is happening."* A cut driven in from behind the trunk is hidden by the
## trunk, and the player was being asked to judge the most consequential cut in the game
## with the wood in the way.
##
## SO THE BACK CUT IS GONE, and with it the manual's two-cut technique. What replaces it is
## the simpler thing that was always underneath: chop a notch and the tree falls into it.
## The holding wood is whatever is left BEHIND the notch — which is what holding wood is —
## and the tree comes over when the notch has eaten far enough through the trunk that the
## rest cannot carry it. None of the load model changed to allow this; it never cared how
## many cuts there were, only what wood was left and which way it had room to go.
func _cut_dir(side: int, azimuth: float) -> Vector3:
	return _side_dir(side, azimuth)


## The horizontal direction of one side of the trunk. `azimuth` is measured from head-on:
## 90 degrees is square-on to the side of the trunk (what every cut used to be), smaller
## angles come round toward the front. See `entry_angle_deg`.
func _side_dir(side: int, azimuth := PI * 0.5) -> Vector3:
	var right := _camera.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized() * float(sign(side) if side != 0 else 1)
	var toward_cam := _camera.global_position - _trunk.global_position
	toward_cam.y = 0.0
	if toward_cam.length() < 0.0001:
		return right
	var out := right * sin(azimuth) + toward_cam.normalized() * cos(azimuth)
	return out.normalized() if out.length() > 0.0001 else right


## The direction the AXE travels in: the struck side, turned back toward the
## viewer, so the swing reads as one thrown by somebody standing where the camera
## is rather than a cut appearing square-on.
func _swing_dir(side: int, azimuth := PI * 0.5) -> Vector3:
	var toward_cam := _camera.global_position - _trunk.global_position
	toward_cam.y = 0.0
	if toward_cam.length() < 0.0001:
		toward_cam = Vector3.BACK
	# The axe travels along the cut it is making. The extra turn toward the camera is
	# scaled by how square-on the cut already is, so a square cut still gets the full
	# `swing_toward_camera_deg` it always did, and a cut that already comes round the
	# front is not turned twice into a swing from behind the player's head.
	var a := deg_to_rad(swing_toward_camera_deg) * (azimuth / (PI * 0.5))
	return (_cut_dir(side, azimuth) * cos(a) + toward_cam.normalized() * sin(a)).normalized()


## The cut angle the axe pose should follow for the blow about to land, taken from the
## cut it is going to land on.
func _preview_angle(side: int, local_y: float, azimuth := PI * 0.5) -> float:
	if _cut().face_side != 0 and side != _cut().face_side:
		return 0.0                                  # a back cut comes in level
	var i := _site_at(side, local_y, _cut_dir(side, azimuth))
	if i < 0:
		return deg_to_rad(notch_roof_deg)   # a fresh cut opens with the manual's wedge
	return _blow_angle(i, local_y)


## Point the swing along the blow: yawed to face the trunk from the side it came
## from, leaned between an overhead chop and a flat swing, bowed out so the head
## sweeps round, and tilted to follow the cut.
func _aim_axe(side: int, angle: float, azimuth := PI * 0.5) -> void:
	var from_dir := _swing_dir(side, azimuth)
	_axe.yaw = atan2(from_dir.x, from_dir.z)
	_axe.approach = Vector3.UP.lerp(from_dir, axe_approach_lean).normalized()
	_axe.hover = axe_hover
	_axe.arc_bulge = axe_arc_bulge
	_axe.arc_dir = from_dir
	_axe.hidden_euler = axe_hidden_euler
	_axe.struck_euler = axe_struck_euler + Vector3(angle * axe_angle_follow, 0.0, 0.0)


# ------------------------------------------------------------------- cuts
## THE BLOW LANDS, AND IT LANDS WHERE THE PLAYER PUT IT.
##
## One click, one blow, exactly as before — but nothing about the cut is scripted any
## more. Where you click sets the height, which side you click sets the direction the
## axe comes from, and how far above or below the cut you click sets the ANGLE the
## blade goes in at. Nothing is snapped to a notch, nothing alternates on your behalf,
## and there is no privileged "notch side" or "back cut side": a cut is a cut.
##
## Sam's direction, 2026-07-25: *"The cutting also needs to be totally free form, you
## should be able to cut anywhere on the voxel, the angle can be variable, we're just
## trying to make the user have the highest level of agency here."*
##
## The manual's method is still exactly available — chop down at the top of a notch,
## up at the bottom of it, then level in from behind — and it is still the fastest way
## to fell a tree, because the load model rewards it. It is now the player doing it
## rather than the game.
func _land_blow(side: int, local_y: float, world_point: Vector3,
		azimuth := PI * 0.5) -> bool:
	if _felling or not _has_tree():
		return false
	if _cut().face_side == 0:
		# The first cut anywhere on the tree commits which way it is going — at the
		# angle it was driven in at, not merely to the left or the right.
		_cut().face_side = side
		_cut().face_dir = _side_dir(side, azimuth)   # ...and that is the fall line
	var i := _site_at(side, local_y, _cut_dir(side, azimuth))
	if i < 0:
		i = _open_site(side, local_y, azimuth)
	if i < 0:
		return false
	_cut().site = i
	var res := _cut_blow(i, local_y)
	if not res.ok:
		# Nothing left to take there. That is not a jam — it means the wood has
		# been cut through, so ask the tree what it is doing about it.
		_check_wood()
		return false

	_throw_wood(res.volume, res.chip_pos)
	for piece in res.freed:
		_throw_wood(piece.volume, piece.world_pos, true)
	_spray_chop_splinters(world_point)

	# A7: the ONLY hit path, exactly as M4 does it — GameFeel turns this into the
	# camera shake and the A11 hit-pause. M5 adds no signals (A7 untouched).
	EventBus.action_hit_registered.emit(
		world_point, GameState.get_tool_tier(Enums.ToolType.AXE), _dir_from_side(side))
	_play(chop_sfx)

	_check_wood()
	return true


## The cut nearest `local_y` on `side` that this blow counts as part of, or -1 if the
## player is working somewhere new. `cut_reach` is the whole of what makes a run of
## clicks add up to one cut instead of a row of nicks.
## `dir` is the direction THIS blow would cut in; a site facing some other way round
## the trunk is not the same cut however close it is in height. Zero skips that test,
## for callers that only want "is there a cut roughly here".
func _site_at(side: int, local_y: float, dir := Vector3.ZERO) -> int:
	var best := -1
	var best_d := cut_reach
	var arc := cos(deg_to_rad(cut_face_arc_deg))
	for i in range(_cut().sites.size()):
		if _cut().sites[i].side != side:
			continue
		# WHICH WAY ROUND THE TRUNK the cut faces, which matters the moment the player
		# can WALK. `side` is camera-relative, so walking round a tree keeps handing back
		# the same +1 while the world direction behind it swings right round; without
		# this test a player who moved to the far side and chopped would have the blow
		# folded into the notch they opened on the face now BEHIND them, cutting wood
		# they cannot see. It never came up with a camera that orbited in fixed steps
		# around a tree the player could not approach.
		if dir.length() > 0.0001 and dir.dot(_cut().sites[i].dir as Vector3) < arc:
			continue
		# Matched on where the player AIMED as well as on where the cut ended up: a cut near
		# the ends of the band is clamped, so a site can sit some way from the click that
		# made it, and matching on its position alone means the same click can never find it
		# again. At a small `cut_reach` that is fatal — every blow opens a fresh cut and the
		# tree ends up covered in nicks that never join into a notch.
		var d: float = minf(absf((_cut().sites[i].aim as float) - local_y),
			absf((_cut().sites[i].y as float) - local_y))
		if d <= best_d:
			best_d = d
			best = i
	return best


## Start a fresh cut where the player aimed. A cut records only where it is, which way
## the axe comes from, and how far in it has got — the ANGLE belongs to each blow, not
## to the cut, which is what lets one cut be widened into a notch of any shape.
func _open_site(side: int, local_y: float, azimuth := PI * 0.5) -> int:
	# Exactly where it was asked for. Nothing is repositioned on the player's behalf now
	# that every cut is one they can see.
	var y: float = clampf(local_y, _min_local_y_of(_trunk), _max_local_y())
	_cut().sites.append({
		"side": side, "y": y, "aim": local_y, "dir": _cut_dir(side, azimuth),
		"depth": 0.0, "angle": 0.0, "opened": false,
	})
	return _cut().sites.size() - 1


## THE ANGLE OF ONE BLOW, from where the click landed relative to the cut it is working.
##
## Click above the cut and the axe comes down into it; click below and it comes up;
## click dead on and it goes straight in level. The further off-centre, the steeper —
## right up to `free_cut_max_deg` at the edge of `cut_reach`. That is the whole of the
## angle control, and it costs no extra input: the player is already choosing a point
## on the trunk.
func _blow_angle(i: int, local_y: float) -> float:
	if cut_reach <= 0.0:
		return 0.0
	var t: float = clampf((local_y - (_cut().sites[i].y as float)) / cut_reach, -1.0, 1.0)
	return deg_to_rad(t * free_cut_max_deg)


## ONE BLOW: the wood the axe displaces, taken out of the trunk.
##
## The solid is a slab `cut_kerf` thick at the blade's angle, driven `bite_depth` in from
## wherever the wood's surface currently IS along the swing — which is why a cut advances
## on its own. The same aim lands further in every time because the face has receded, and
## nothing has to remember how deep it had got.
##
## The first blow on a fresh cut takes TWO slabs, angled apart. A single cut into a round
## trunk lifts out a sliver of bark and reads as a miss, so the opening blow makes a real
## mouth for the following ones to work in — the one piece of help that survives, and the
## angles it uses are the manual's own notch angles.
func _cut_blow(i: int, local_y: float) -> Dictionary:
	var angle := _blow_angle(i, local_y)
	_cut().sites[i].angle = angle
	if not _cut().sites[i].opened:
		_cut().sites[i].opened = true
		# One remesh for the pair, not one each: surfacing the band is the single most
		# expensive thing a blow does, and the first of these two slabs is immediately
		# superseded by the second.
		# BOTH are deferred and the remesh is done here unconditionally. Letting the
		# second slab do it would leave the band stale on the day that slab happens to
		# carve nothing and returns early — the geometry would then be a blow behind the
		# field it is measured from.
		var a := _cut_slab(i, deg_to_rad(notch_roof_deg), true)
		var b := _cut_slab(i, -deg_to_rad(notch_floor_deg), true)
		_trunk.finish_chop()
		return _merge(a, b)
	return _cut_slab(i, angle)


## Carve one slab of wood at `angle` from horizontal, into the cut at site `i`.
## `defer_remesh` leaves the band unsurfaced for a following slab to finish — see
## `_cut_blow`, which lays in two at once when a cut is first opened.
func _cut_slab(i: int, angle: float, defer_remesh := false) -> Dictionary:
	var out_dir: Vector3 = _cut().sites[i].dir           # horizontal, out of the trunk
	var inward := -out_dir
	var c := _trunk_centre(_cut().sites[i].y)
	# Where the wood starts along this swing. Probed from well clear of the trunk, so a
	# cut that has already eaten in is met at its own face rather than at the bark.
	# ...and from outside the WIDEST wood the band holds, not outside the stem. With the
	# root flare in the field (`voxel_roots`) the butt reaches up to 2.8x the stem's radius,
	# so a probe starting at 2.5x began INSIDE the wood: `first_solid` reported a face out
	# where it started, the slab was built entirely outside the trunk, and the blow removed
	# nothing at all. `band_max_radius` is the measurement that covers both.
	var reach: float = maxf(_trunk.radius, _trunk.band_max_radius)
	var probe := _trunk.surface_along(c + out_dir * (reach * 2.5), inward, reach * 3.5)
	var face: Vector3 = probe.point if probe.hit else c + out_dir * _trunk.radius
	# Keep the blade on the height the cut is working, whatever the probe found.
	face.y = _cut().sites[i].y
	var lat := Vector3.UP.cross(inward).normalized()
	# The blade's plane, tilted `angle` about the lateral axis: 0 is a level kerf,
	# positive comes down into the wood, negative comes up under it.
	var blade := Vector3.UP.rotated(lat, angle).normalized()
	var lap := _cut_overlap()
	var bite := bite_depth
	var depth: float = inward.dot(face) + bite
	# The kerf opens out as the cut goes in — see kerf_flare. Every cut gets it now: they
	# are all notches, and a notch has to have a mouth or there is no room for the trunk
	# to rotate into it.
	var kerf: float = cut_kerf + (_cut().sites[i].depth as float) * kerf_flare
	var planes: Array[Plane] = [
		Plane(blade, blade.dot(face) + kerf * 0.5),              # the slab's top face
		Plane(-blade, -(blade.dot(face) - kerf * 0.5)),          # ...and its bottom
		Plane(inward, depth),                                   # as deep as the blow goes
		# ...and it reaches back out PAST THE BARK, not merely to just outside the face
		# it is cutting. The kerf widens as the cut deepens, and a solid that only spans
		# the advancing shell widens nothing: the wood newly inside the wider kerf but
		# nearer the surface is never touched, so the cut bores in at its original height
		# and the notch never opens a mouth. That leaves the trunk no room to rotate into
		# and the tree crushes where it stands instead of hinging over — which is what it
		# did. Re-cutting the whole gullet each blow costs a bigger scan and nothing else:
		# the field is already air there, and only samples that actually stop being wood
		# are counted as removed.
		Plane(-inward, -(inward.dot(c) - reach * 1.4)),
		Plane(lat, lat.dot(c) + cut_span * 0.5),
		Plane(-lat, -(lat.dot(c) - cut_span * 0.5)),
	]
	_cut().sites[i].depth = (_cut().sites[i].depth as float) + bite
	var half := Vector3(reach * 1.6,
		kerf * 0.5 + bite * 2.0 + voxel_cell * 2.0, reach * 1.6)
	return _trunk.chop(planes, AABB(c - half + Vector3(0.0, face.y - c.y, 0.0), half * 2.0),
		false, defer_remesh)


## Merge two carves made by one blow — the volumes add, and any freed wood from either
## comes away.
func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	if not b.ok:
		return a
	if not a.ok:
		return b
	var freed: Array = []
	freed.append_array(a.freed)
	freed.append_array(b.freed)
	var a_bigger: bool = a.volume >= b.volume
	var big: Dictionary = a if a_bigger else b
	# The smaller of the two still left the tree; hand it over as freed wood so it is
	# thrown rather than quietly deleted.
	var small: Dictionary = b if a_bigger else a
	freed.append({"mesh": null, "world_pos": small.chip_pos, "volume": small.volume})
	return {"ok": true, "volume": a.volume + b.volume, "chip": big.chip,
		"chip_pos": big.chip_pos, "freed": freed}


## How far each blow re-cuts where the last one stopped.
##
## Not cosmetic, and not a fudge — it is what the voxel field needs to be told.
## Subtracting a convex solid pushes each sample out to the nearest FACE of that
## solid, so a sample sitting exactly on the boundary between two blows ends up
## on the surface of both and stays half-solid forever. Untreated, a cut leaves a
## stack of half-density films behind it, the measured section never drops, and the
## tree will not fall however long you chop. One cell of overlap puts those samples a
## full cell clear of the wood, which is what an axe does anyway: the next blow starts
## inside the last one's kerf.
func _cut_overlap() -> float:
	return voxel_cell * 1.2


func _trunk_centre(local_y: float) -> Vector3:
	return _trunk.axis_point(local_y)


## A6 ChopDirection means what it says: swings come in from the player's left or
## right, so the reported direction is the side the axe swung from.
func _dir_from_side(side: int) -> int:
	return Enums.ChopDirection.RIGHT if side >= 0 else Enums.ChopDirection.LEFT


# ------------------------------------------------------------- the verdict
## Ask the wood what it is doing. Every height of the band is a beam carrying the
## weight above it; the worst of them, in the worst direction, is the tree's
## state. Nothing else fells it — there is no budget and no hit points.
func _check_wood() -> void:
	var v := _evaluate()
	if v.is_empty():
		return
	_cut().last_stress = v.stress
	_cut().last_thickness = v.get("thickness", INF)
	_fire_cracks(v)
	if v.stress >= fail_stress:
		_begin_fell(v)
		return
	_fall_dir = v.dir
	_tween_lean(_lean_for_stress(v.stress), lean_time)


## The load model. For each height and each of `_DIRS` horizontal directions:
##   crush = weight above / area of wood left / crush strength
##   bend  = weight above x moment arm / section modulus / bend strength, and
##           only as far as there is room to bend that way (see below)
## The arm is the real one — the horizontal distance from the wood that is
## holding the tree up to the mass it is holding — so the notch shifting the
## remaining wood off-centre, the tree's own lean, and the lean it takes on as it
## gives way all feed it, and all push the same way. Section modulus comes from
## the measured second moment via the radius of gyration, which is exact for the
## rectangle a hinge actually is.
##
## THE ROOM TO BEND is what makes the notch decide the direction, and it is the
## reason the manual's back cut is HIGHER than the notch rather than level with
## it. Rotating toward the notch is free: the notch has been chopped out all the
## way down past its floor, so there is nothing under the trunk on that side. Any
## other way, the trunk immediately bears back down on the stump — the back cut
## simply closes and the tree sits there. So the bend is gated on how far the
## wood BELOW the break has been cut back in that direction, which is a thing
## that can be measured. Under-notch a tree and it does exactly what an
## under-notched tree does: nothing, until you go back and cut the notch deeper.
##
## CRUSHING IS NOT GATED, and that matters. Wanting somewhere to fall is a
## condition on bending over; being squashed flat is not. A tree left standing on
## a sliver with nowhere to go still fails — it just fails by collapsing where it
## stands rather than hinging over, with nothing steering it and nothing to warn
## the player first. That is what an under-notched tree does, and it is the
## difference `controlled` reports.
##
## Returns { stress, dir (world), y (local), area, thickness, controlled, pivot
## (local), com (local), volume } — empty if there is nothing to say.
func _evaluate() -> Dictionary:
	if not _has_tree():
		return {}
	var secs := _trunk.sections()
	if secs.size() < 3:
		return {}
	var gx := _trunk.global_transform
	var severed: float = _trunk.full_area() * 0.01
	var best := {}
	var best_stress := -1.0
	# Room-to-fall for every height in every direction, worked out once. Asking for
	# it per (height, direction) walks the band each time, which is fine over the
	# 1.3 m band this started as and is the single biggest cost per blow now that the
	# band covers the whole trunk — it grows as the SQUARE of the band's height.
	var voids := _void_table(secs)
	for j in range(1, secs.size() - 1):
		var e: Dictionary = secs[j]
		var sec_local := Vector3(_trunk.axis_xz.x + e.cx, e.y, _trunk.axis_xz.y + e.cz)
		var com_local := Vector3(_trunk.axis_xz.x + e.load_cx, e.load_cy,
			_trunk.axis_xz.y + e.load_cz)
		var weight: float = e.load_volume * wood_density * gravity
		if weight <= 0.0:
			continue
		var area: float = maxf(e.area, severed * 0.05)
		var sec_world := gx * sec_local
		var com_world := gx * com_local
		if e.area <= severed:
			# Cut clean through. Nothing is holding it and nothing is steering
			# it: it comes down now, whichever way it happens to be leaning.
			return _collapse(gx, sec_world, com_world, sec_local, com_local, e, INF)
		var crush: float = weight / area / (crush_strength_kpa * 1000.0)
		var sup: PackedFloat32Array = e.sup
		# Being crushed needs no room to fall into, so it is judged first and on
		# its own. If nothing beats it, the tree collapses rather than hinges.
		if crush > best_stress:
			best_stress = crush
			best = _collapse(gx, sec_world, com_world, sec_local, com_local, e, crush)
		for t in range(_DIRS):
			# The trunk's own x/z frame, so the measured reaches line up with the
			# direction being tested; the arm is still taken in world space.
			var ang := TAU * float(t) / float(_DIRS)
			var ul := Vector3(cos(ang), 0.0, sin(ang))
			var u := gx.basis * ul
			u.y = 0.0
			if u.length() < 0.0001:
				continue
			u = u.normalized()
			var arm := (com_world - sec_world).dot(u)
			if arm <= 0.0:
				continue
			var iu := _second_moment(e, ul, area)
			if iu <= 0.0:
				continue
			# Room to bend this way: how tall the gap is between the trunk and the
			# stump on that side of the tree.
			var gate := clampf(((voids[t] as PackedFloat32Array)[j] - topple_min_open)
				/ maxf(topple_clearance, 0.001), 0.0, 1.0)
			if gate <= 0.0:
				continue
			# Z = I / c, with c the MEASURED distance from the centroid out to
			# the extreme fibre. Exact for the strip a hinge is and for the disc
			# an uncut trunk is, which an estimate off the moments is not — and
			# the two get compared to each other constantly here.
			var cu: float = e.cx * ul.x + e.cz * ul.z
			var c: float = maxf(sup[t] - cu, _trunk.volume().cell * 0.5)
			var bend: float = gate * arm * weight * c / iu / (bend_strength_kpa * 1000.0)
			var stress: float = crush + bend
			if stress > best_stress:
				best_stress = stress
				best = {"stress": stress, "dir": u, "y": e.y, "area": e.area,
					"controlled": true,
					"pivot": sec_local, "com": com_local, "volume": e.load_volume,
					# How thick the holding wood measures across the fall line:
					# its reach one way plus its reach the other.
					"thickness": maxf(sup[t] + sup[(t + _DIRS / 2) % _DIRS], 0.0)}
	if best.is_empty():
		# Nothing is overhanging anything it has room to fall into: an untouched
		# tree, or one that has been under-notched and is sitting back on itself.
		var mid: Dictionary = secs[secs.size() / 2]
		return {"stress": 0.0, "dir": _fall_dir, "y": mid.y, "area": mid.area,
			"thickness": INF, "controlled": false,
			"pivot": Vector3(_trunk.axis_xz.x, mid.y, _trunk.axis_xz.y),
			"com": Vector3(_trunk.axis_xz.x, mid.load_cy, _trunk.axis_xz.y),
			"volume": mid.load_volume}
	return best


## The tree failing WITHOUT a hinge: cut clean through, or simply crushed where
## it stands. There is no holding wood to steer it, so it goes whichever way it
## is already leaning — which is the point the manual is making when it calls
## cutting through the hinge the most dangerous thing a novice can do.
func _collapse(gx: Transform3D, sec_world: Vector3, com_world: Vector3,
		sec_local: Vector3, com_local: Vector3, e: Dictionary, stress: float) -> Dictionary:
	var best_dir := _fall_dir
	var best_arm := -INF
	var best_t := 0
	for t in range(_DIRS):
		var ang := TAU * float(t) / float(_DIRS)
		var u := gx.basis * Vector3(cos(ang), 0.0, sin(ang))
		u.y = 0.0
		if u.length() < 0.0001:
			continue
		u = u.normalized()
		var arm := (com_world - sec_world).dot(u)
		if arm > best_arm:
			best_arm = arm
			best_dir = u
			best_t = t
	var sup: PackedFloat32Array = e.sup
	return {"stress": stress, "dir": best_dir, "y": e.y, "area": e.area,
		"controlled": false,
		"thickness": maxf(sup[best_t] + sup[(best_t + _DIRS / 2) % _DIRS], 0.0),
		"pivot": sec_local, "com": com_local, "volume": e.load_volume}


## How tall the gap is between the trunk and the stump on side `t`, around the
## break — the room the trunk has to rotate that way before it comes down on the
## wood underneath it.
##
## Counted as the run of consecutive heights whose wood does not reach out to the
## bark on that side. A face notch is a wedge with a wide open mouth, so on the
## notch side that run is most of the notch's height; a level back cut is a slot
## a kerf tall and nothing more. THAT difference, and not the tree's balance, is
## what makes a notched tree fall toward its notch — and it is why the manual has
## the back cut sitting higher than the notch rather than level with it.
func _void_height(secs: Array[Dictionary], j: int, t: int) -> float:
	var n := 0
	var k := j
	while k >= 0 and _is_open(secs, k, t):
		n += 1
		k -= 1
	k = j + 1
	while k < secs.size() and _is_open(secs, k, t):
		n += 1
		k += 1
	return float(n) * _trunk.volume().cell


## Has the axe opened side `t` up at level `k`? Judged against what that level's wood
## reached BEFORE anything was cut, not against the trunk's overall radius — see
## TreeTrunk.base_reach for what a single global threshold does to a tapering band.
func _is_open(secs: Array[Dictionary], k: int, t: int) -> bool:
	var reach: float = (secs[k].sup as PackedFloat32Array)[t]
	var base := _trunk.base_reach(k)
	var was: float = base[t] if t < base.size() else _trunk.radius
	return reach < was * _OPEN_REACH_FRAC


## `_void_height` for every height in every direction, in two passes per direction
## instead of one walk of the band per question asked.
##
## The load model asks for this once per height per direction, and each answer used
## to re-walk the band — so the cost went as the square of how tall the band is. That
## was affordable when the band was a 1.3 m stub at the foot of the tree and is not
## now that it is the whole trunk. The runs are the same runs: `down[j]` counts the
## open heights ending at j on the way down, `up[j]` the ones starting above it, and
## the answer is their sum, exactly as the loops above produce it.
func _void_table(secs: Array[Dictionary]) -> Array:
	var cell := _trunk.volume().cell
	var n := secs.size()
	var out: Array = []
	var open := PackedByteArray()
	open.resize(n)
	for t in range(_DIRS):
		for j in range(n):
			open[j] = 1 if _is_open(secs, j, t) else 0
		# Runs upward, so up_from[j] is the open run starting AT j.
		var up_from := PackedInt32Array()
		up_from.resize(n + 1)
		up_from[n] = 0
		for j in range(n - 1, -1, -1):
			up_from[j] = (up_from[j + 1] + 1) if open[j] != 0 else 0
		var col := PackedFloat32Array()
		col.resize(n)
		var down := 0
		for j in range(n):
			down = (down + 1) if open[j] != 0 else 0
			# `down` includes j itself; the upward run is taken from j+1, which is
			# what the two loops in _void_height do.
			col[j] = float(down + up_from[j + 1]) * cell
		out.append(col)
	return out


## Second moment of a section's area about the horizontal axis perpendicular to
## `ul`, through its own centroid — the stiffness the bend is working against.
func _second_moment(e: Dictionary, ul: Vector3, area: float) -> float:
	var cu: float = e.cx * ul.x + e.cz * ul.z
	return e.mxx * ul.x * ul.x + 2.0 * e.mxz * ul.x * ul.z \
		+ e.mzz * ul.z * ul.z - area * cu * cu


## The room the trunk has to fall a given way, for the tuning and test seams: how
## tall the gap between trunk and stump is on that side, in metres. Compare it
## against `topple_min_open` — under that, the tree cannot go that way at all.
## Direction index matches WoodVolume.SUPPORT_DIRS; use `dir_index_of` to turn a
## world direction into one.
func topple_room(dir_index: int) -> float:
	if not _has_tree():
		return 0.0
	var secs := _trunk.sections()
	if secs.size() < 3:
		return 0.0
	var y: float = (_cut().sites[_cut().site].y as float) if _cut().site >= 0 and _cut().site < _cut().sites.size() 		else (_trunk.band_lo + _trunk.band_hi) * 0.5
	var j := clampi(_trunk.volume().level_of(y), 1, secs.size() - 2)
	return _void_height(secs, j, posmod(dir_index, _DIRS))


## The direction slot a world direction falls in.
func dir_index_of(world_dir: Vector3) -> int:
	if not _has_tree():
		return 0
	var l := _trunk.global_transform.basis.inverse() * world_dir
	l.y = 0.0
	if l.length() < 0.0001:
		return 0
	return posmod(int(round(atan2(l.z, l.x) / TAU * float(_DIRS))), _DIRS)


## How far a tree under `stress` leans: nothing under `lean_start_stress`, then a
## `lean_curve_exp` ramp up to `lean_max_deg` at failure. This is the tell — it
## says both that the tree is going and, crucially, which way, so a tree about to
## sit back on the player says so before it does it.
func _lean_for_stress(stress: float) -> float:
	if stress <= lean_start_stress:
		return 0.0
	var t := clampf((stress - lean_start_stress) / maxf(fail_stress - lean_start_stress, 0.001),
		0.0, 1.0)
	return deg_to_rad(lean_max_deg) * pow(t, lean_curve_exp)


## The wood announces the load: each time the stress climbs past another
## threshold, one audible CRACK — a jolt and a couple of splinters spat from the
## compression side. One crack per blow however many thresholds it crossed, and
## each threshold fires only once per tree.
func _fire_cracks(v: Dictionary) -> void:
	var crossed := 0
	while _cut().next_crack < crack_stress_levels.size() and v.stress >= crack_stress_levels[_cut().next_crack]:
		_cut().next_crack += 1
		crossed += 1
	if crossed == 0:
		return
	GameFeel.register_impact(minf(crack_impact * crossed, 1.0))
	_play(crack_sfx if crack_sfx != null else creak_sfx)
	var neck := _trunk.global_transform * (v.pivot as Vector3) \
		+ (v.dir as Vector3) * (_trunk.radius * 0.4)
	for i in range(crack_chips):
		var body = _spawn_chip(_stick_mesh(crack_chip_thick, crack_chip_len), neck + Vector3(
			randf_range(-0.06, 0.06), randf_range(-0.05, 0.05), randf_range(-0.06, 0.06)))
		body.linear_velocity = (v.dir as Vector3) * crack_speed * randf_range(0.6, 1.2) \
			+ Vector3.UP * crack_up * randf_range(0.7, 1.2)
		body.angular_velocity = _tumble()
		_chips.append(body)


# ------------------------------------------------------------------- fall
## The wood has given way. Hand the part above the break to the hinge: it stays
## attached and rotates about the holding wood, driven by nothing but the weight
## hanging out past it.
func _begin_fell(v: Dictionary) -> void:
	if _felling or not _has_tree():
		return
	# ONE FELLED TRUNK IS TRACKED AT A TIME. A trunk left lying there (`trunk_persists`) keeps
	# the bucking state — which length is being cut, how many logs it has paid for — and there
	# is exactly one of those. So felling a SECOND tree finalises the first: its remaining
	# timber is booked in and it goes.
	#
	# CONSEQUENCE Sam should know, and it is the honest limit of this pass rather than a
	# decision: a felled trunk persists until you fell another one, not for ever. Making
	# several felled trunks independently buckable means moving the bucking state onto the
	# trunk the way `TreeCutState` moved the cut state, which is the same shape of job as
	# plan §3b and not a small one.
	_finalise_felled_timber()
	# EVERY FALL STARTS WITH ITS OWN LANDING BOOKKEEPING. After `_finalise_felled_timber`,
	# which reads the bucking state this must not disturb. See `_reset_landing_state` for
	# what a stale `_landed` / `_settled` does to the tree now going over.
	_reset_landing_state()
	_felling = true
	_pending = {}
	_fall_dir = v.dir
	# CONTROLLED means it went over on a hinge, toward a notch that gave it room.
	# Crushed flat or cut clean through, there is nothing steering it.
	_hinge_intact = bool(v.get("controlled", false))
	_cut().kill_lean()

	var part := _trunk.detach_above(v.y, v.pivot)
	if (part.meshes as Array).is_empty():
		return
	var canopy := part.get("canopy") as MeshInstance3D

	var pivot_world: Vector3 = part.pivot_world
	_fall_rest_basis = _trunk.global_transform.basis
	_falling = Node3D.new()
	_falling.name = "FallingTree"
	_fallers.add_child(_falling)
	_falling.global_transform = Transform3D(_fall_rest_basis, pivot_world)
	for mi: MeshInstance3D in part.meshes:
		var keep := mi.transform
		if mi.get_parent() != null:
			mi.get_parent().remove_child(mi)
		_falling.add_child(mi)
		mi.transform = Transform3D(keep.basis, keep.origin + (part.offset as Vector3))
	_attach_canopy(canopy, part.offset)

	var mass: float = maxf((part.volume as float) * wood_density, 1.0)
	var com_world := _trunk.global_transform * (v.com as Vector3)
	_hinge = HingeFall.new()
	_hinge.setup(pivot_world, _fall_dir, com_world, mass, part.length)
	_hinge.tear_angle = deg_to_rad(hinge_tear_deg)
	_hinge.release_angle = deg_to_rad(free_fall_deg)
	# A tree failing in pure compression has no direction of its own. Give it the
	# least overhang that guarantees it comes down rather than standing there.
	var arm0 := _hinge.r0.dot(_hinge.fall_dir)
	if arm0 < min_topple_arm:
		_hinge.r0 += _hinge.fall_dir * (min_topple_arm - arm0)
		arm0 = min_topple_arm
	# The holding wood fights the first of it, then tears. Zero once it has been
	# cut through — that is the whole cost of losing the hinge. Measured against the
	# SAME gravity the fall runs at, or `hinge_hold_frac` would silently mean a
	# different fraction every time `fall_gravity_scale` moved.
	_hinge.hold = (hinge_hold_frac * mass * gravity * fall_gravity_scale * arm0) \
		if _hinge_intact else 0.0

	_fallen_length = part.length
	_fallen_slices = part.get("slices", [] as Array[Dictionary])
	_fall_age = 0.0
	_still_for = 0.0
	_tear_debt = 0.0
	_play(creak_sfx)
	_burst_splinters(pivot_world)


## Keep the authored canopy surfaces aligned with the timber throughout both
## halves of the fall. `_go_free` moves every MeshInstance3D child onto the
## RigidBody3D, so this stays attached across the hinge-to-physics hand-off.
func _attach_canopy(canopy: MeshInstance3D, pivot_offset: Vector3) -> void:
	if canopy == null:
		return
	var keep := canopy.transform
	_falling.add_child(canopy)
	canopy.transform = Transform3D(keep.basis, keep.origin + pivot_offset)
	_attached_canopies.append(canopy)


## Remove branches and leaves on the landing frame. Hiding first guarantees
## they cannot render for one extra deferred-free frame.
func _clear_attached_canopies() -> void:
	for canopy in _attached_canopies:
		if canopy != null and is_instance_valid(canopy):
			canopy.visible = false
			canopy.queue_free()
	_attached_canopies.clear()


## Past committing: the trunk stops being attached and becomes a rigid body,
## carrying exactly the motion it already had so the hand-over is seamless.
func _go_free() -> void:
	if _falling == null or not is_instance_valid(_falling):
		return
	var body := RigidBody3D.new()
	body.name = "FallenTrunk"
	_fallers.add_child(body)
	body.global_transform = _falling.global_transform
	for child in _falling.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi: MeshInstance3D = child
		var keep := mi.transform
		_falling.remove_child(mi)
		body.add_child(mi)
		mi.transform = keep

	_fit_trunk_collider(body)

	body.mass = maxf(_hinge.mass, min_mass)
	body.physics_material_override = _phys_mat
	body.linear_damp = trunk_linear_damp
	body.angular_damp = trunk_angular_damp
	body.gravity_scale = fall_gravity_scale
	body.collision_layer = TreeTrunk.TIMBER_LAYER
	body.collision_mask = TreeTrunk.TIMBER_MASK
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 16
	body.can_sleep = false
	body.body_entered.connect(_on_trunk_contact)
	body.angular_velocity = _hinge.axis * _hinge.omega
	body.linear_velocity = _hinge.velocity_at(body.global_position)

	_falling.queue_free()
	_falling = null
	_hinge = null
	_fallen = body


## THE FALLING TRUNK'S COLLIDER FOLLOWS THE WOOD.
##
## It used to be ONE cylinder of the trunk's radius, on the body's local Y axis, running
## from the origin to `_fallen_length`. Every part of that is right except the assumption
## underneath it: that the timber is a straight column standing on the body's origin. The
## origin is the HINGE — the failing section's centroid, which a deep notch drags to the
## back of the remaining wood — and the generator leans and wanders every trunk it makes on
## top of that. MEASURED on tree_02: the wood's own centre line sat 0.46 m off that axis at
## the butt and 3.08 m off at the tip, against a cylinder radius of 0.49, so the wood was
## outside the collider at EVERY height and the woody crown had nothing under it at all —
## it settled at world y -2.76..0.19, entirely below the floor. Sam, 2026-07-30: "when a
## tree falls, the top half penetrates through the floor."
##
## So the shape is measured instead of assumed: a stack of cylinders on the timber's own
## measured centre line, each with its own measured radius, from
## `TreeTrunk.timber_slices`. A dozen shapes in one compound body — no extra rigid bodies,
## so A12's budget is untouched.
##
## The single cylinder survives as a fallback for a trunk that reports no slices at all,
## because no collider is the one outcome worse than an approximate one.
func _fit_trunk_collider(body: RigidBody3D) -> void:
	if _fallen_slices.is_empty():
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = _trunk.radius if _has_tree() else 0.4
		cyl.height = maxf(_fallen_length, 0.05)
		cs.shape = cyl
		cs.position = Vector3(0.0, _fallen_length * 0.5, 0.0)
		body.add_child(cs)
		return
	for s in _fallen_slices:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(s.radius, 0.02)
		# Exactly the slab's own height, so the stack's union is exactly the timber's
		# span — `_log_span` reads this back and bucking is gated on it.
		cyl.height = maxf(s.height, 0.02)
		cs.shape = cyl
		var c: Vector2 = s.centre
		cs.position = Vector3(c.x, s.y, c.y)
		body.add_child(cs)


## First real contact after it is free is the tree hitting something — the
## ground, usually. It is already well over by then, so anything counts, but the
## grace beat keeps it from calling its own splinter burst the landing.
##
## THIS IS THE PAYOFF FRAME. Everything before it is the tree taking its time, so
## the landing is given the weight the fall earned: trauma and slow-motion scaled
## by the speed the tip actually arrived at, debris scaled with them, and — the
## part that was missing — the trunk left free to finish crashing instead of being
## damped to a halt on the instant of touch.
func _on_trunk_contact(_other: Node) -> void:
	if _landed or _fall_age < impact_grace:
		return
	_landed = true
	_land_at = _fall_age
	_clear_attached_canopies()
	if _fallen != null and is_instance_valid(_fallen):
		# Take out ONLY the spin about the trunk's own length. That component is a
		# cylinder rolling on flat ground and it never stops on its own; every other
		# component is the tree still coming down, and killing that was what made
		# the landing feel like nothing. The heavy damping follows in
		# `land_slam_time` (see _watch_fallen).
		var along := _fallen.global_transform.basis.y.normalized()
		var w := _fallen.angular_velocity
		_fallen.angular_velocity = w - along * along.dot(w)
	var hit := _register_slam(_impact_speed, 1.0)
	_play(land_sfx)
	_throw_land_debris(hit)


## Report a bang to GameFeel, scaled by how fast the wood was moving when it
## stopped. Returns the strength it used (0..1) so the caller can size its own FX
## off the same number.
##
## A11 note: `register_impact` already brings a standard chop-length hit-pause with
## it. The landing wants a longer one, so it asks for a second pause on top —
## GameFeel counts overlapping pauses and only restores time_scale when the LAST
## one expires, so the two compose into one beat the length of the longer.
func _register_slam(speed: float, ceiling: float) -> float:
	# A3: the ONLY size test anywhere is size_tier > GameFeelConfig.size_threshold.
	var tier := _size_tier(_fallen_length)
	var full: float = land_impact if tier > GameFeel.config.size_threshold else land_impact_small
	var hard := clampf(speed / maxf(land_impact_speed, 0.001), 0.0, 1.0)
	var strength := minf(full * hard, ceiling)
	if strength <= 0.0:
		return 0.0
	GameFeel.register_impact(strength)
	if land_pause > 0.0:
		GameFeel.hit_pause(land_pause * strength)
	return strength


## The ground jumping: a line of debris kicked up along the length of the trunk
## where it came down, as much of it as the landing deserved. Pure FX, on the A12
## budget with everything else.
func _throw_land_debris(strength := 1.0) -> void:
	var count := int(round(float(land_debris) * clampf(strength, 0.0, 1.0)))
	if count <= 0 or _fallen == null or not is_instance_valid(_fallen):
		return
	var along := _fallen.global_transform.basis.y
	var base := _fallen.global_position
	for i in range(count):
		var t := float(i) / float(maxi(count - 1, 1))
		var p := base + along * (t * _fallen_length) + Vector3(
			randf_range(-0.3, 0.3), 0.05, randf_range(-0.3, 0.3))
		var body = _spawn_chip(_stick_mesh(splinter_stick_thick * 1.4, splinter_stick_len),
			p, splinter_settle)
		body.linear_velocity = Vector3(randf_range(-0.5, 0.5), 1.0,
			randf_range(-0.5, 0.5)).normalized() \
			* land_debris_speed * strength * randf_range(0.5, 1.2)
		body.angular_velocity = _tumble()
		_chips.append(body)


func _trunk_tilt_deg() -> float:
	if _fallen == null or not is_instance_valid(_fallen):
		return 0.0
	return rad_to_deg(_fallen.global_transform.basis.y.angle_to(Vector3.UP))


## Quantised size tier for a runtime-cut piece (Amendment 6: computed from
## measured dimensions instead of authored). Tier 1 is the smallest.
func _size_tier(length: float) -> int:
	if size_tier_unit <= 0.0:
		return 1
	return maxi(1, int(length / size_tier_unit) + 1)


## Ease the tree's lean to `target` radians, pivoted at the wood that is holding
## it up.
## BOUND TO ITS OWN TREE, not to whichever tree is active when it ticks.
##
## This is the one piece of per-tree state that is LIVE: a tween keeps running and keeps
## writing while the player walks off and starts chopping something else. Reading the
## active tree from inside the callback would lean the wrong trunk — the tree the player
## is now standing at would tip over as a tree behind them lost its holding wood. So the
## trunk is captured at the moment the tween is made, and `_fall_dir` with it.
func _tween_lean(target: float, duration: float) -> void:
	if not _has_tree():
		return
	var trunk := _trunk
	trunk.cut.kill_lean()
	trunk.cut.lean_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	trunk.cut.lean_tween.tween_method(
		_apply_lean.bind(trunk, _fall_dir), trunk.cut.lean, target, duration)


## `Callable.bind` appends its arguments, so the tween's interpolated value arrives first
## and the tree it belongs to second.
func _apply_lean(angle: float, trunk: TreeTrunk, dir: Vector3) -> void:
	if trunk == null or not is_instance_valid(trunk):
		return
	trunk.cut.lean = angle
	# Only a STANDING tree leans. A tree already going over is `HingeFall`'s, and a lean
	# written into it would fight the fall.
	if trunk.is_built() and not trunk.has_broken() and not (trunk == _trunk and _felling):
		trunk.set_lean(angle, dir)


# ---------------------------------------------------------------- bucking
## The trunk has come to rest. It is now a log lying in the clearing, and clicks cut
## it up rather than doing nothing until it dissolves.
func _begin_bucking() -> void:
	_clear_attached_canopies()
	_bucking = true
	_buck_idle = 0.0
	_buck_target = null
	_buck_hits = 0
	_logs = [_fallen]
	if _has_tree():
		_log_radius = _trunk.radius


## A blow on the felled trunk. Which LENGTH was hit and WHERE along it is the whole
## input: a run of blows in one place cuts through there, and clicking somewhere else
## starts a fresh cut instead of adding to the old one.
func _buck_click() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var ray := _player.aim_ray()
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (chop_reach + 1.0))
	# Timber only, or a splinter lying on the log would swallow the click.
	q.collision_mask = TreeTrunk.TIMBER_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not _logs.has(hit.collider):
		return false   # the ground, a chip, or thin air: nothing to cut
	var body: RigidBody3D = hit.collider
	var point: Vector3 = hit.position
	if point.distance_to(_player.eye_position()) > chop_reach:
		return false   # stand over the log to buck it
	# A length already down to firewood size is finished — see _is_cuttable.
	if not _is_cuttable(body):
		return false
	# Along the log's own length. The sections all run up their local +Y, because
	# that is how _go_free re-origined the trunk when it let go of the stump.
	# CLAMPED so the cut cannot leave a coin: see _buck_cut_at.
	var along: float = _buck_cut_at(body, body.to_local(point).y)

	var tier := GameState.get_tool_tier(Enums.ToolType.AXE)
	if tier < _tree_def.hardness_level:
		_axe.swing_denied(point)
		if denied_emits_hit:
			EventBus.action_hit_registered.emit(point, tier, Enums.ChopDirection.DOWN)
		return false

	if body != _buck_target or absf(along - _buck_at) > buck_spot_tolerance:
		_buck_target = body
		_buck_at = along
		_buck_hits = 0
	_buck_hits += 1
	_buck_idle = 0.0

	# The axe comes straight down on a log on the ground, which is what bucking is.
	_axe.yaw = atan2(dir.x, dir.z)
	_axe.approach = Vector3.UP
	_axe.arc_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_axe.swing(point)
	# A6: the swing comes DOWN onto the log rather than in from either side.
	EventBus.action_hit_registered.emit(point, tier, Enums.ChopDirection.DOWN)
	_play(chop_sfx)
	_spray_buck_splinters(point, body)

	if _buck_hits >= maxi(buck_blows, 1):
		_sever(body, _buck_at)
	return true


## Cut one length of trunk in two, right through, at `along` on its local Y.
##
## Every mesh the section carries is sliced by the same plane — the carved butt, the
## crown with its branches, whatever it has — and the two halves are rebuilt as their
## own bodies. The slicer preserves per-surface materials and caps the cut face with
## the inside-wood material, so a bucked end looks like a sawn end.
func _sever(body: RigidBody3D, along: float) -> void:
	var above: Array[MeshInstance3D] = []
	var below: Array[MeshInstance3D] = []
	for child in body.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi: MeshInstance3D = child
		if mi.mesh == null:
			continue
		# The plane is in the BODY's frame; each mesh sits at its own offset inside
		# that, so it has to be restated in the mesh's frame before slicing.
		var local := MeshUtils.plane_to_local(Plane(Vector3.UP, along), mi.transform)
		# END GRAIN on the sawn end, mapped the same way the voxel band maps its cut faces:
		# `_cut_mat` is a SINGLE growth-ring round on a white field, not a tiling sheet, so the
		# cap's UVs have to be normalised by the log's own radius. Without it they are offsets in
		# METRES, which only lands inside the round when the piece is about a metre across —
		# true of tree_01's ~0.5 m radius by accident, and false as soon as
		# `tree_size_variation` made trunks bigger, at which point the cut end clamped to the
		# white field around the disc. Sam: "when the logs are cut the textures are all wrong."
		var res := MeshSlicer.slice(mi.mesh, local, _cut_mat, true)
		if res.above == null or res.below == null:
			# The plane missed this mesh entirely: it belongs wholly to one side.
			var side := above if MeshUtils.center_of(mi.mesh).y > local.d else below
			side.append(_clone_mesh(mi, mi.mesh))
			continue
		above.append(_clone_mesh(mi, res.above))
		below.append(_clone_mesh(mi, res.below))
	if above.is_empty() or below.is_empty():
		_buck_hits = 0   # nothing to cut here after all; let the player try elsewhere
		return

	var xform := body.global_transform
	var up := _new_log(xform, above, along, true)
	var down := _new_log(xform, below, along, false)
	_logs.erase(body)
	body.queue_free()
	_buck_target = null
	_buck_hits = 0

	# One length of timber, booked in as it comes free — M4's rule, one
	# resource_gathered per finished piece. Capped at what the tree is authored to
	# yield, so bucking paces the reward rather than inventing more of it.
	_pay_for_log()
	var world := xform * Vector3(0.0, along, 0.0)
	GameFeel.register_impact(buck_sever_impact)
	_play(crack_sfx if crack_sfx != null else chop_sfx)
	_burst_splinters(world)
	if up != null:
		up.linear_velocity = xform.basis.y * buck_part_speed
	if down != null:
		down.linear_velocity = -xform.basis.y * buck_part_speed


## One length of bucked trunk as its own body, carrying the meshes handed to it.
func _new_log(xform: Transform3D, meshes: Array[MeshInstance3D], _along: float,
		_upper: bool) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "BuckedLog"
	_fallers.add_child(body)
	body.global_transform = xform
	var span := Vector2(INF, -INF)
	for mi in meshes:
		body.add_child(mi)
		var box := mi.transform * mi.mesh.get_aabb()
		span.x = minf(span.x, box.position.y)
		span.y = maxf(span.y, box.end.y)
	if span.x > span.y:
		body.queue_free()
		return null
	# The section's own share of the timber's measured shape. Every bucked section keeps
	# the frame the whole trunk had — `_new_log` copies the parent's global transform and
	# the meshes keep their local ones — so the slices measured at detach still apply, and
	# a length off the leaning top of a trunk gets a collider under its own wood rather
	# than under the axis the trunk was re-origined on. See `_fit_trunk_collider`.
	var full_h := maxf(span.y - span.x, 0.05)
	var used := _fit_log_collider(body, span)
	if not used:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = _log_radius
		cyl.height = full_h
		cs.shape = cyl
		cs.position = Vector3(0.0, (span.x + span.y) * 0.5, 0.0)
		body.add_child(cs)
	body.mass = maxf(PI * _log_radius * _log_radius * full_h * wood_density, min_mass)
	body.physics_material_override = _phys_mat
	body.collision_layer = TreeTrunk.TIMBER_LAYER
	body.collision_mask = TreeTrunk.TIMBER_MASK
	# Already on the ground, so it gets the settling damping straight away rather
	# than the in-flight values — a bucked log should drop where it is cut.
	body.linear_damp = trunk_land_linear_damp
	body.angular_damp = trunk_land_angular_damp
	body.continuous_cd = true
	_logs.append(body)
	return body


## Give a bucked section the slabs of the timber's measured shape that fall inside it.
## False if none do, and the caller puts a plain cylinder there instead.
func _fit_log_collider(body: RigidBody3D, span: Vector2) -> bool:
	var any := false
	for s in _fallen_slices:
		var y: float = s.y
		var h: float = s.height
		# Any slab that OVERLAPS this section, then clipped to it below — so the wood is
		# covered right up to the sawn end and neither half carries collision past it.
		if y + h * 0.5 <= span.x or y - h * 0.5 >= span.y:
			continue
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(s.radius, 0.02)
		# ...but clipped to the section, so a slab straddling the kerf does not stick
		# out past the end of the log it was given to.
		var lo := maxf(y - h * 0.5, span.x)
		var hi := minf(y + h * 0.5, span.y)
		if hi - lo < 0.01:
			continue
		cyl.height = hi - lo
		cs.shape = cyl
		var c: Vector2 = s.centre
		cs.position = Vector3(c.x, (lo + hi) * 0.5, c.y)
		body.add_child(cs)
		any = true
	return any


## How long a bucked length is (m), off its own collider — the UNION of every cylinder in
## it, because a length of timber now carries a STACK of them following its own centre
## line rather than one on the body's axis (see `_fit_trunk_collider`). Reading only the
## first would report half a metre for a six-metre trunk, and bucking is gated on this.
func _log_length(body: RigidBody3D) -> float:
	var span := _log_span(body)
	return INF if span.x > span.y else span.y - span.x


## Where a bucked length starts and ends along its OWN local Y. A section's collider is
## centred on the wood it actually contains, which is not the body's origin — every
## section after the first inherits the origin the whole trunk had.
func _log_span(body: RigidBody3D) -> Vector2:
	var lo := INF
	var hi := -INF
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs != null and cs.shape is CylinderShape3D:
			var h: float = (cs.shape as CylinderShape3D).height
			lo = minf(lo, cs.position.y - h * 0.5)
			hi = maxf(hi, cs.position.y + h * 0.5)
	return Vector2(-INF, INF) if lo > hi else Vector2(lo, hi)


## CAN THIS LENGTH BE CUT AT ALL? Only if there is room for a REAL LOG on both sides of
## the kerf — so it has to be at least two logs long.
##
## Creative Director's call, 2026-07-26: *"when a player chops a felled tree in to logs,
## it should only ever split in to logs roughly the size of the ones we chop in the game,
## so there is a min log size (right now you can cut tiny disks and that's just not
## accurate)."*
##
## `buck_min_length` already existed and was checked — but against the length going IN,
## never against the two lengths coming OUT. So a 1 m section passed the test and could
## then be cut 5 cm from its end, which is where the coins came from. The floor has to be
## on the RESULT of a cut, not on its input.
func _is_cuttable(body: RigidBody3D) -> bool:
	return _log_length(body) >= _min_log() * 2.0


## THE MINIMUM LOG for the trunk currently on the ground (m) — its whole length divided by
## `buck_target_logs`, floored at `buck_min_length`.
##
## Dividing is what makes the count come out right. A trunk `L` long with a minimum of `L/n`
## cannot be cut into more than `n` pieces, because every piece has to be at least that long —
## so the target is an upper bound the geometry enforces, not a counter anything has to track.
##
## Measured off `_fallen_length`, the length recorded when the trunk let go of its stump, so it
## is this tree's own size rather than a number that happens to suit tree_01.
func _min_log() -> float:
	var whole: float = _fallen_length if _fallen_length > 0.01 else 0.0
	if whole <= 0.01:
		return buck_min_length
	return maxf(whole / float(maxi(buck_target_logs, 1)), buck_min_length)


## The nearest place on `body` a cut may actually land, given the click asked for `along`.
##
## CLAMPED rather than refused, matching what M4's chopping block already does with its
## own `min_piece_size` (chopping_minigame.gd's `_snap_cut`): a click near the end of a log
## reads as "cut near the end", and a dead click that does nothing reads as a broken game.
## So the axe takes the nearest cut that leaves a log on both sides.
func _buck_cut_at(body: RigidBody3D, along: float) -> float:
	var span := _log_span(body)
	var m := _min_log()
	return clampf(along, span.x + m, span.y - m)


## A copy of `src`'s node keeping its transform, wearing `mesh`.
func _clone_mesh(src: MeshInstance3D, mesh: Mesh) -> MeshInstance3D:
	var out := MeshInstance3D.new()
	out.mesh = mesh
	out.transform = src.transform
	return out


## Thrown out of a bucking kerf: sideways off the log rather than out of a standing
## trunk, because the axe is coming down onto it.
func _spray_buck_splinters(point: Vector3, body: RigidBody3D) -> void:
	if chop_splinters <= 0:
		return
	var along := body.global_transform.basis.y
	for i in range(chop_splinters):
		var jitter := Vector3(randf_range(-0.05, 0.05), 0.02, randf_range(-0.05, 0.05))
		var piece = _spawn_chip(_stick_mesh(splinter_stick_thick, splinter_stick_len),
			point + jitter, splinter_settle)
		piece.linear_velocity = along * chop_splinter_speed * randf_range(-1.0, 1.0) \
			+ Vector3.UP * chop_splinter_up * randf_range(0.7, 1.2) \
			+ Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
		piece.angular_velocity = _tumble()
		_chips.append(piece)


## Is there anything left of the felled trunk worth cutting? Every length under
## `buck_min_length` means the player has bucked it out and there is nothing more to
## do with it — which is what ends a persisting trunk instead of a timer.
##
## An empty log list counts as bucked out so a trunk can never be stranded on the
## board by a section going missing.
func _bucked_out() -> bool:
	for body in _logs:
		if is_instance_valid(body) and _is_cuttable(body):
			return false
	return true


## Take the trunk away and pay the balance. Reached either because it has been bucked
## right out, because the player left the forest, or — with `trunk_persists` off —
## because nobody has touched it for a while.
func _end_bucking() -> void:
	if not _bucking:
		return
	_bucking = false
	_buck_target = null
	# The logs leave first — they fly to the player and bank themselves as they land — and then
	# the board clears as it always did. It goes through the SAME fade path either way: that is
	# what moves the stump onto `_stumps`, tidies `_trees` and resets the fall state, and it is
	# already tested. `_release_timber` has settled the yield, so `_collect_yields` no-ops.
	_release_timber()
	_fade_at = fade_delay


## THE LOGS FLY TO THE PLAYER AND ARE BANKED AS THEY LAND. Creative Director's direction,
## 2026-07-27: *"the logs can fly towards the character (in a similar way to the log chopping
## game) and then be added to their inventory."*
##
## Returns true when it took the timber; false when there was nothing to take, or when
## `logs_fly_to_player` is off and the caller should fall back to the old fade-and-collect.
##
## THE YIELD IS SETTLED HERE, AT LAUNCH, and only the EMISSION is deferred to each log landing.
## That is deliberate: the accounting is then finished the instant the trunk is given up, so it
## cannot be disturbed by anything that happens while the logs are in the air — a second tree
## being felled, the player walking out of the forest, or the board being wiped with R. What
## flies is a receipt, not a promise.
##
## So the PASS 2 invariant is exactly as strong as it was: a tree is worth its authored
## `TreeDef.yields` however it was cut up. Every unit still owed is dealt out across the logs
## that are flying — one each, with any remainder riding on the last — so a half-bucked trunk
## whose three lengths fly still pays the whole tree.
func _release_timber() -> bool:
	if not logs_fly_to_player or _tree_def == null:
		return false
	# What is still owed on this tree, as a flat list of one-unit payments.
	var units: Array = []
	for f: FragmentDef in _tree_def.yields:
		if f == null or not f.is_leaf() or f.yield_item == &"":
			continue
		var owed: int = f.yield_amount - (_logs_paid if f == _yield_leaf() else 0)
		for i in range(maxi(owed, 0)):
			units.append(f.yield_item)

	var proxies: Array[Node3D] = []
	for body in _logs:
		if not is_instance_valid(body):
			continue
		var rb: RigidBody3D = body
		for child in rb.get_children():
			var mi := child as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			# A frozen PROXY at the log's resting pose, exactly as M4 bakes its firewood before
			# flying it to the pile: the body and its collider go, and what flies is scripted.
			var proxy := MeshInstance3D.new()
			proxy.mesh = mi.mesh
			_fallers.add_child(proxy)
			proxy.global_transform = mi.global_transform
			proxies.append(proxy)
		rb.queue_free()
	_logs.clear()

	if proxies.is_empty():
		# Nothing to fly. The tree is still worth what it is worth.
		_collect_yields()
		return false

	# Deal the payments out over the logs, remainder on the last — so the total emitted is
	# exactly what was owed whether there are more logs than units or fewer.
	var payloads: Array = []
	for i in range(proxies.size()):
		payloads.append([])
	for i in range(units.size()):
		(payloads[mini(i, proxies.size() - 1)] as Array).append(units[i])

	# Settled NOW, so nothing in flight is owed anything.
	var leaf := _yield_leaf()
	if leaf != null:
		_logs_paid = leaf.yield_amount
	_collected = true
	_collect_count += 1

	_flight.fly_ms = log_fly_ms
	_flight.stagger_ms = log_fly_stagger_ms
	_flight.arc_height = log_fly_arc
	for i in range(proxies.size()):
		_flight.launch(proxies[i], _player_catch_point, payloads[i], i, _on_log_landed)
	return true


## Where a flying log is aimed — re-read every frame by `log_flight.gd`, because the player
## walks and a log launched at where they used to be would sail past them.
func _player_catch_point() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return global_position + Vector3.UP * log_fly_catch_height
	return _player.global_position + Vector3.UP * log_fly_catch_height


## One log has reached the player: bank what it was carrying (A7 `resource_gathered`, through
## InventoryManager as always — an unregistered id is errored and ignored there).
func _on_log_landed(payload: Variant) -> void:
	for item: StringName in (payload as Array):
		EventBus.resource_gathered.emit(item, 1)
	_play(chop_sfx)


func _yield_leaf() -> FragmentDef:
	for f: FragmentDef in _tree_def.yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			return f
	return null


## Book in one bucked log, if the tree has any timber left to give.
func _pay_for_log() -> void:
	var leaf := _yield_leaf()
	if leaf == null or _logs_paid >= leaf.yield_amount:
		return
	_logs_paid += 1
	EventBus.resource_gathered.emit(leaf.yield_item, 1)


# ----------------------------------------------------------------- timber
## The single collect point (A7 resource_gathered), mirroring M4's batch collect.
## Writes go through InventoryManager only — an unregistered id is errored and
## ignored there, so a typo in the .tres is safe.
##
## Whatever BUCKING already paid for is deducted, so a tree yields exactly what it is
## authored to yield however it was cut up: buck it into every log it has and the
## fade adds nothing, leave it whole and the fade pays the lot. Bucking sets the pace
## of the reward, never its size.
func _collect_yields() -> void:
	if _collected:
		return
	_collected = true
	_collect_count += 1
	for f: FragmentDef in _tree_def.yields:
		if f != null and f.is_leaf() and f.yield_item != &"":
			var owed: int = f.yield_amount - (_logs_paid if f == _yield_leaf() else 0)
			if owed > 0:
				EventBus.resource_gathered.emit(f.yield_item, owed)


# ---------------------------------------------------------------- physics
## The wood a blow took, thrown out of the cut as SPLINTERS.
##
## It used to throw the carved geometry itself — the actual voxels that left the hole,
## which was a nice idea and looked wrong: a bite is a thin flake off the face of a
## cut, so what landed on the ground was a scatter of flat discs. Creative Director's
## call, 2026-07-25: "the chunks that fall on to the ground can just be splinters".
## So the volume removed is converted into a handful of splinters instead, and nothing
## meshes the removed voxels at all any more, which also takes the chip surfacing out
## of every blow.
func _throw_wood(volume: float, world_pos: Vector3, freed := false) -> void:
	if volume <= 0.0 or not _has_tree():
		return
	var out := world_pos - _trunk.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.0001 else _cut().face_dir
	var side := Vector3.UP.cross(out).normalized()
	var speed := chip_out * (0.6 if freed else 1.0)
	for i in range(_splinters_for(volume)):
		var jitter := Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06),
			randf_range(-0.06, 0.06))
		var body = _spawn_chip(_stick_mesh(splinter_stick_thick, splinter_stick_len),
			world_pos + jitter, splinter_settle)
		body.linear_velocity = out * speed * randf_range(0.7, 1.3) \
			+ side * speed * chop_splinter_spread * randf_range(-1.0, 1.0) \
			+ Vector3.UP * chip_up * randf_range(0.7, 1.2)
		body.angular_velocity = _tumble()
		_chips.append(body)


## How many splinters a given volume of removed wood is worth. One rule for both a
## blow's bite and a whole wedge popping out of the notch, so a bigger piece of wood
## makes a bigger spray — capped, because A12 counts bodies and the notch wedge is a
## lot of wood at once.
func _splinters_for(volume: float) -> int:
	if splinter_wood_each <= 0.0:
		return 1
	return clampi(int(round(volume / splinter_wood_each)), 1, splinter_burst_cap)


## Spray a handful of thin splinters out of a fresh cut — the tearing read on
## every blow, over and above the chunk the carve already threw. Pure FX.
func _spray_chop_splinters(world_point: Vector3) -> void:
	if chop_splinters <= 0 or not _has_tree():
		return
	var out := world_point - _trunk.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.0001 else _cut().face_dir
	var side := Vector3.UP.cross(out).normalized()
	for i in range(chop_splinters):
		var jitter := Vector3(randf_range(-0.05, 0.05), randf_range(-0.06, 0.06),
			randf_range(-0.05, 0.05))
		var body = _spawn_chip(_stick_mesh(splinter_stick_thick, splinter_stick_len),
			world_point + jitter, splinter_settle)
		body.linear_velocity = out * chop_splinter_speed * randf_range(0.6, 1.2) \
			+ side * chop_splinter_speed * chop_splinter_spread * randf_range(-1.0, 1.0) \
			+ Vector3.UP * chop_splinter_up * randf_range(0.6, 1.2)
		body.angular_velocity = _tumble()
		_chips.append(body)


## The burst thrown at the moment the wood gives.
func _burst_splinters(at: Vector3) -> void:
	var perp := Vector3.UP.cross(_fall_dir).normalized()
	for i in range(splinter_count):
		var jitter := Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.18),
			randf_range(-0.1, 0.1))
		var shard = _spawn_chip(_stick_mesh(splinter_stick_thick, splinter_stick_len),
			at + jitter, splinter_settle)
		shard.linear_velocity = _fall_dir * splinter_speed * randf_range(0.5, 1.1) \
			+ perp * splinter_speed * randf_range(-0.5, 0.5) \
			+ Vector3.UP * splinter_up * randf_range(0.75, 1.25)
		shard.angular_velocity = Vector3(
			randf_range(-splinter_spin, splinter_spin),
			randf_range(-splinter_spin, splinter_spin),
			randf_range(-splinter_spin, splinter_spin))
		_chips.append(shard)


## One fibre letting go, while the hinge is still tearing.
func _spit_hinge_splinter() -> void:
	if _hinge == null:
		return
	var p := _hinge.pivot + Vector3(randf_range(-0.2, 0.2), randf_range(-0.05, 0.1),
		randf_range(-0.2, 0.2))
	var body = _spawn_chip(_stick_mesh(splinter_stick_thick * 0.8, splinter_stick_len * 0.8),
		p, splinter_settle)
	body.linear_velocity = _fall_dir * randf_range(0.4, 1.6) \
		+ Vector3.UP * randf_range(0.6, 2.0)
	body.angular_velocity = _tumble()
	_chips.append(body)


## A thin stick of fresh cut-face wood, long along the grain (Y) — a splinter.
##
## SHARED, not built per splinter. There are only ever three sizes of these in the whole
## game (a chop splinter, a crack splinter, the smaller one the hinge spits) and they
## were each being rebuilt from a fresh BoxMesh into a fresh ArrayMesh every time one was
## thrown — a hundred and fifty identical meshes per felling, each its own GPU buffer.
## One mesh per size is also one buffer per size for the renderer to bind.
func _stick_mesh(thick: float, along: float) -> ArrayMesh:
	var key := Vector2(thick, along)
	var cached: ArrayMesh = _stick_cache.get(key)
	if cached != null:
		return cached
	var b := BoxMesh.new()
	b.size = Vector3(thick, along, thick)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.surface_get_arrays(0))
	out.surface_set_material(0, _splinter_mat)
	_stick_cache[key] = out
	return out


func _tumble() -> Vector3:
	return Vector3(randf_range(-chip_tumble, chip_tumble),
		randf_range(-chip_tumble, chip_tumble), randf_range(-chip_tumble, chip_tumble))


## One thrown piece (Amendment 6 path through fragment_piece), mass scaled by
## volume so a sliver is not flung across the clearing, and registered with the
## A12 budget — the chips are the burst that budget exists for.
func _spawn_chip(mesh: Mesh, world_pos: Vector3, settle := -1.0):
	var body = _FRAGMENT_PIECE.instantiate()
	_fallers.add_child(body)
	body.setup_mesh(mesh, settle if settle > 0.0 else chip_settle_timeout)
	body.physics_material_override = _phys_mat
	body.linear_damp = piece_linear_damp
	body.angular_damp = piece_angular_damp
	body.continuous_cd = true
	# Debris hits the ground and other debris, and passes THROUGH the tree. Sam's
	# call: the splinters are here to make small piles, and letting a hundred and
	# fifty of them fight a falling trunk buys nothing but jitter.
	body.collision_layer = TreeTrunk.DEBRIS_LAYER
	body.collision_mask = TreeTrunk.DEBRIS_MASK
	var s := mesh.get_aabb().size
	body.mass = maxf(wood_density * s.x * s.y * s.z * 0.5, min_mass)
	body.global_position = world_pos
	_budget.track(body)
	# NOT `_retire_old_debris()` — see `_retire_old_debris`. It is a whole-list pass that
	# may rewrite a MultiMesh, and calling it once per chip ran it a dozen times a blow
	# for one blow's worth of new debris. The callers run it once, after the burst.
	return body


## Keep the total amount of debris on the ground bounded.
##
## A12 caps bodies still in MOTION at 24, which is the physics cost; it says nothing
## about how many settled ones may accumulate, and M5 makes about twelve a blow and
## never removed one until the tree faded. A player working at one blow every tenth of
## a second builds hundreds of frozen bodies and hundreds of mesh instances inside a
## minute, and every one of them still costs a draw and (until it stops processing) a
## script call per physics tick.
##
## The oldest SETTLED piece goes first, so nothing is ever pulled out of the air in front
## of the player — and it is not deleted, it is BAKED (see `_consolidate`).
func _retire_old_debris() -> void:
	if max_debris <= 0 or _chips.size() <= max_debris:
		return
	var over := _chips.size() - max_debris
	var baked: Array = []
	var keep: Array = []

	# PASS ONE: pieces that are properly AT REST — settled AND out of confirms.
	#
	# `is_settled()` goes true the moment a piece is retired, which is BEFORE
	# `fragment_piece`'s confirm loop has finished checking that whatever it came to rest on is
	# still there. Baking is PERMANENT (it reads the transform once and frees the body), so
	# baking on `is_settled()` froze exactly the poses that loop exists to correct — most
	# obviously a splinter retired while it was bedded INTO the falling trunk: it cannot move
	# down, reports itself perfectly settled, and is left hanging in the air once the trunk has
	# rotated away. Sam saw it as floating chips of wood. It was invisible while the cap DELETED
	# the oldest settled piece, because a bad pose was thrown away before it could be looked at.
	for piece in _chips:
		if not is_instance_valid(piece):
			continue
		if over > 0 and piece.is_at_rest():
			over -= 1
			baked.append(piece)
			continue
		keep.append(piece)

	# PASS TWO: still over, so lean on the merely-settled ones — OLDEST FIRST, and each is made
	# to sweep itself down one last time before it is made permanent (`force_at_rest`).
	#
	# Without this the cap is not a cap at all: the confirm window is six seconds, which a player
	# chopping hard will fill many times over, and debris piled up to 157 bodies against a 24
	# bound. Forcing trades the ability to notice a support that leaves LATER for the slot, and
	# keeps the re-sweep that fixes the case which actually shows.
	if over > 0:
		for i in range(keep.size()):
			if over <= 0:
				break
			var piece = keep[i]
			if not is_instance_valid(piece) or not piece.is_settled():
				continue
			piece.force_at_rest()
			over -= 1
			baked.append(piece)
			keep[i] = null
		var kept: Array = []
		for piece in keep:
			if piece != null:
				kept.append(piece)
		keep = kept

	_chips = keep
	_consolidate(baked)


## BAKE SETTLED SPLINTERS INTO A MULTIMESH AND FREE THE BODIES (Creative Director's call,
## 2026-07-26; A12's own text anticipates it — "long-term piles may consolidate to
## MultiMesh").
##
## Why it is needed at all: A12's 24 is a cap on bodies still MOVING, which is physics cost,
## and says nothing about how many stopped ones pile up. M5 makes about twelve splinters a
## blow. With ONE tree that was survivable, and `max_debris` handled it by DELETING the
## oldest settled piece — which in a forest means the pile behind you quietly disappears
## while you are at the third tree. Sam does not want that, and rightly.
##
## So a settled piece gives up its RigidBody3D, its collider and its script, and keeps only
## a transform in a MultiMesh. Nothing is drawn per piece any more and nothing is simulated;
## a pile costs one draw call, and it stays where the player left it for good.
##
## One MultiMesh PER SPLINTER MESH, because a MultiMesh draws one mesh — and M5 only ever
## makes three sizes of splinter in the whole game (`_stick_mesh` shares them), so this is
## three instances for a whole forest, not one per pile. They live on the game node rather
## than on a tree, so a pile survives the tree that made it being cleared away.
func _consolidate(pieces: Array) -> void:
	if pieces.is_empty():
		return
	# Group by the mesh each piece is wearing: same mesh, same MultiMesh.
	var by_mesh: Dictionary = {}
	for piece in pieces:
		if not is_instance_valid(piece):
			continue
		var mesh := _piece_mesh(piece)
		if mesh == null:
			piece.queue_free()
			continue
		if not by_mesh.has(mesh):
			by_mesh[mesh] = []
		(by_mesh[mesh] as Array).append(piece.global_transform)
		piece.queue_free()

	for mesh: Mesh in by_mesh:
		var xforms: Array = by_mesh[mesh]
		var mmi: MultiMeshInstance3D = _piles.get(mesh)
		if mmi == null or not is_instance_valid(mmi):
			mmi = MultiMeshInstance3D.new()
			mmi.name = "SettledDebris%d" % _piles.size()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = 0
			mmi.multimesh = mm
			# The pile is set dressing on the ground; nothing needs to cast off it and
			# shadow-casting a few thousand sticks is pure cost.
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_piles[mesh] = mmi
		# GROWN IN BLOCKS, with `visible_instance_count` doing the work.
		#
		# `instance_count` REALLOCATES and wipes every transform already in the buffer, so a
		# pile cannot simply be resized once per batch — and the obvious repair (read `buffer`,
		# resize, write it back) does not work either: Godot rejects a buffer whose size does
		# not match the one already there, so the earlier splinters were silently being lost to
		# identity while the instance COUNT still went up. A check that counted instances saw
		# nothing wrong.
		#
		# So capacity is allocated in blocks and only re-allocated when one fills, with the
		# existing transforms read back through `get_instance_transform` (never the buffer) and
		# rewritten. `visible_instance_count` then says how many of the block are real, which
		# makes appending a single `set_instance_transform` and no copying at all.
		# Kept in a plain Array and rewritten whole, which is the only version of this that is
		# actually correct.
		#
		# Two cleverer attempts failed, both silently. Reading `buffer`, resizing and writing it
		# back is rejected by Godot for a size mismatch. Allocating capacity in blocks and
		# tracking how much is filled with `visible_instance_count` left every transform at
		# IDENTITY — so a pile kept its exact COUNT while its whole contents sat in a heap at
		# the scene origin. Both passed a check that counted instances, which is why
		# forest_smoke now asserts the TRANSFORMS.
		#
		# Rewriting whole is O(pile) per batch, and a batch only happens when debris goes over
		# `max_debris`. That is a few thousand writes now and then, against a bug that put the
		# entire forest's splinters in one pile at the origin.
		var mm2 := mmi.multimesh
		var kept: Array = _pile_used.get(mesh, [])
		for x in xforms:
			kept.append(x)
		_pile_used[mesh] = kept
		mm2.instance_count = kept.size()
		for i in range(kept.size()):
			mm2.set_instance_transform(i, kept[i] as Transform3D)


## The mesh a settled splinter is wearing, so it can be grouped with its own kind.
func _piece_mesh(piece: Node) -> Mesh:
	for child in piece.get_children():
		var mi := child as MeshInstance3D
		if mi != null and mi.mesh != null:
			return mi.mesh
	return null


## How many splinters have been baked into piles. Test/dev seam for the A12 rule: the point
## is that they persist, so it has to be possible to count them.
func settled_debris_count() -> int:
	var n := 0
	for mesh in _piles:
		if is_instance_valid(_piles[mesh]):
			n += (_pile_used.get(mesh, []) as Array).size()
	return n


## Where every baked splinter ended up (world). Test seam, and it exists because counting
## instances is not enough — an early version of `_consolidate` kept the exact COUNT while
## putting the whole forest's splinters in one heap at the origin.
##
## It reports the transforms THIS FILE HOLDS, not the ones in the MultiMesh, and that is
## deliberate rather than lazy: **MultiMesh.set_instance_transform does not round-trip under
## the headless renderer** — a fresh MultiMesh in a headless run reads every instance back as
## identity, because the storage lives in a RenderingServer that is stubbed out. So a headless
## check against `get_instance_transform` can only ever fail. What is verifiable here is the
## data being fed in, which is where the bug was; that the MultiMesh then draws it is a
## RENDER check (`core/tools/forest_shot.gd`).
## What is ACTUALLY IN THE MULTIMESH: `[instance_count, visible, non-identity, furthest]`.
## Only meaningful under a real renderer — see debug_pile_transforms for why. Used by
## `forest_shot`, which runs with opengl3, to confirm the piles really draw where they fell.
func debug_pile_gpu() -> Array:
	var count := 0
	var vis := 0
	var placed := 0
	var furthest := 0.0
	for mesh in _piles:
		var mmi: MultiMeshInstance3D = _piles[mesh]
		if not is_instance_valid(mmi) or mmi.multimesh == null:
			continue
		count += mmi.multimesh.instance_count
		if mmi.visible:
			vis += mmi.multimesh.instance_count
		for i in range(mmi.multimesh.instance_count):
			var o := (mmi.multimesh.get_instance_transform(i) as Transform3D).origin
			if o.length() > 0.01:
				placed += 1
				furthest = maxf(furthest, o.length())
	return [count, vis, placed, furthest]


func debug_pile_transforms() -> Array:
	var out: Array = []
	for mesh in _piles:
		if not is_instance_valid(_piles[mesh]):
			continue
		out.append_array(_pile_used.get(mesh, []) as Array)
	return out


## How many MultiMesh piles exist. Bounded by the number of SPLINTER MESHES in the game
## (three), not by how many trees have been felled — which is the whole point.
func settled_pile_count() -> int:
	var n := 0
	for mesh in _piles:
		if is_instance_valid(_piles[mesh]):
			n += 1
	return n


# ----------------------------------------------------------------- camera
## THE DEV CAMERA. Polar around this scene's origin, aimed at a focus height — the
## exact camera M5 was built, tuned and render-verified with, reproduced by posing the
## player as a puppet.
##
## It exists so the render-to-PNG workflow survives first person. `core/tools/
## tree_shot.gd`, `seam_shot.gd` and `seam_layers.gd` frame every shot they take by
## setting `cam_distance` / `cam_height` / `cam_focus_y` at about a dozen call sites,
## and that loop is the only thing that has ever caught a rendering bug in this
## project (the inverted winding, the default seam, the upright splinters, the
## band/crown join). Deleting these exports along with the orbit would have broken all
## of it silently. Only runs while `player_controlled` is false.
func _apply_camera() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var yaw := deg_to_rad(dev_camera_yaw_deg)
	var back := Vector3(sin(yaw), 0.0, cos(yaw)) * cam_distance
	# WHAT THE DEV CAMERA ORBITS. The scene origin, which is where the single tree stands —
	# so every shot tool and every acceptance check frames exactly what it always did. With
	# a stand, `debug_stand_at_tree` moves the anchor to the tree being looked at, because
	# orbiting the middle of a forest points the camera at whatever happens to be there.
	var anchor := global_position + _dev_camera_anchor
	# The player's origin is its FEET and the camera sits `eye_height` above them, so
	# the eye is dropped by that much to land at `cam_height` — otherwise every shot
	# the tools take would be framed 1.65 m higher than the number asked for.
	var feet := anchor + back + Vector3.UP * (cam_height - _player.eye_height)
	_player.place(feet, anchor + Vector3(0.0, cam_focus_y, 0.0))


# ------------------------------------------------------------------ audio
func _play(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.play()


# ------------------------------------------------------- test/shot seams
## Drive one blow without the mouse or the anticipation delay. `side` is +1 for the
## screen-right face of the trunk and -1 for the left, and `local_y` is where on the
## trunk it lands — which, exactly as with a click, sets both the height of the cut and
## (once a cut is going there) the ANGLE of the blade, from how far off the cut's own
## height it is. So a caller shapes a notch the same way a player does: aim high in it
## to chop down, low in it to chop up.
func debug_blow(side := 1, local_y := INF, edge := -1.0) -> bool:
	if _felling or not _has_tree():
		return false
	# The live click path refuses while the tree is still bouncing in; the test
	# seam has no reason to wait, but it MUST NOT cut a tree that is still moving
	# — the cut is aimed in world space, so a blow landing mid-drop would carve
	# somewhere else entirely.
	_animator.finish_for([_trunk])
	var y: float = (_trunk.band_lo + 0.45) if local_y == INF else local_y
	# `edge` stands in for where across the trunk's face a click landed (0 = the centre
	# line, 1 = the silhouette edge); -1 asks for the default entry angle.
	var az := _entry_azimuth(edge) if edge >= 0.0 else deg_to_rad(entry_angle_deg)
	return _land_blow(side, y, _impact_point(side, y, az), az)


## Fell the tree by the book: notch one side until it is `notch_frac` of the way
## through, then cut the back until the wood gives. Returns the blows it took.
func debug_fell(notch_frac := 0.6, max_blows := 60, local_y := INF) -> int:
	var n := 0
	while not _felling and n < max_blows and notch_depth() < notch_frac:
		if not debug_blow(1, local_y) and not _felling:
			break
		n += 1
	while not _felling and n < max_blows:
		if not debug_blow(-1, local_y) and not _felling:
			break
		n += 1
	return n


## Fire the axe swing without a click, so the dev shot tools can catch it
## mid-strike and check its placement.
func debug_swing_axe(side := 1) -> void:
	if _axe == null or not _has_tree():
		return
	_aim_axe(side, _preview_angle(side, _trunk.band_lo + 0.45))
	_axe.swing(_impact_point(side, _trunk.band_lo + 0.45))


## How deep the deepest cut has been driven, as a fraction of the trunk diameter.
##
## Under a half the wood still holding the tree sits on the fall side of centre, and a
## tree cannot topple over its own support — so it sits back instead of going over. That
## is not a rule written anywhere; it is what the load model says, and it is the reason a
## notch has to be taken past the middle of the trunk before anything happens.
func notch_depth() -> float:
	if _cut().face_side == 0 or not _has_tree():
		return 0.0
	var deepest := 0.0
	for i in range(_cut().sites.size()):
		deepest = maxf(deepest, _cut().sites[i].depth as float)
	return clampf(deepest / maxf(_trunk.diameter, 0.01), 0.0, 1.0)


## How many separate cuts the player has going on this tree. One per place the axe has
## been working — the player is free to open as many as they like, anywhere.
func cut_count() -> int:
	return _cut().sites.size()


## Height of the DEEPEST cut (m, local), or INF if nothing has been cut. This is where the
## tree breaks, because it is where the least wood is left.
func notch_height() -> float:
	var best := INF
	var deepest := -INF
	for i in range(_cut().sites.size()):
		var d: float = _cut().sites[i].depth
		if d > deepest:
			deepest = d
			best = _cut().sites[i].y
	return best


## How much wood is left BEHIND the deepest cut — the HOLDING WOOD, in metres. MEASURED,
## not inferred from where the cuts were aimed: it is the
## thickness of the rectangle with the same area and the same stiffness as the
## section the tree is actually standing on.
func hinge_thickness() -> float:
	return _cut().last_thickness


## Wood still holding the tree up (m²) — the honest answer to "how much is left".
func holding_wood() -> float:
	return _trunk.holding_area() if _has_tree() else INF


## The load model's verdict after the latest blow. 1.0 is failure. THIS is the
## fell condition; nothing else can bring the tree down.
func last_stress() -> float:
	return _cut().last_stress


func crack_count() -> int:
	return _cut().next_crack


## False when the player cut clean through the holding wood — the manual's
## cardinal sin. There is then nothing steering the fall and it goes at once.
func hinge_was_intact() -> bool:
	return _hinge_intact


## True while the tree is hanging off its hinge, rotating but still attached.
func is_hinging() -> bool:
	return _hinge != null and _falling != null and is_instance_valid(_falling)


## How far over it has gone (deg), attached or free.
## How fast the trunk's tip was travelling when it hit (m/s) — what the landing's
## trauma and slow-motion beat were scaled by. Test/tuning seam.
func debug_impact_speed() -> float:
	return _impact_speed


## How long the timber that came off the stump measures (m) — the span bucking,
## `_min_log`, the A3 size tier, the tip speed and the landing debris line are all
## measured off. Test/diagnostic seam.
func debug_fallen_length() -> float:
	return _fallen_length


## True while the felled trunk is lying there waiting to be cut into logs.
func is_bucking() -> bool:
	return _bucking


## How many separate lengths the felled trunk has been cut into (1 = uncut).
func log_count() -> int:
	var n := 0
	for l in _logs:
		if is_instance_valid(l):
			n += 1
	return n


## Logs booked into the inventory by bucking so far.
func logs_paid() -> int:
	return _logs_paid


## Drive one bucking blow without the mouse: on the length at index `log_index`, at
## `along` up its own local Y (INF = its middle). Returns false if there is nothing
## to cut there.
func debug_buck(log_index := 0, along := INF) -> bool:
	if not _bucking or log_index < 0 or log_index >= _logs.size():
		return false
	var body: RigidBody3D = _logs[log_index]
	if not is_instance_valid(body):
		return false
	# THE MIDDLE OF THE LENGTH by default. This used to read a CollisionShape3D's own
	# `position.y`, which meant the middle only while a length carried exactly one
	# cylinder; the collider is a STACK now (see `_fit_trunk_collider`) and the last
	# child is the slab at the far END, so the default cut went to the tip and clamped
	# against `buck_min_length` instead of halving the log.
	var span := _log_span(body)
	if is_inf(span.x) or not _is_cuttable(body):
		return false
	var y: float = _buck_cut_at(body, (span.x + span.y) * 0.5 if along == INF else along)
	var tier := GameState.get_tool_tier(Enums.ToolType.AXE)
	if tier < _tree_def.hardness_level:
		return false
	if body != _buck_target or absf(y - _buck_at) > buck_spot_tolerance:
		_buck_target = body
		_buck_at = y
		_buck_hits = 0
	_buck_hits += 1
	_buck_idle = 0.0
	EventBus.action_hit_registered.emit(body.global_transform * Vector3(0.0, y, 0.0),
		tier, Enums.ChopDirection.DOWN)
	if _buck_hits >= maxi(buck_blows, 1):
		_sever(body, y)
	return true


func fall_tilt_deg() -> float:
	if _hinge != null:
		return _hinge.tilt_deg()
	return _trunk_tilt_deg()


func is_felling() -> bool:
	return _felling


## True once the trunk is a live rigid body — the fall is simulated, not
## animated, in both halves, but this is the free half.
func is_falling_physically() -> bool:
	return _fallen != null and is_instance_valid(_fallen)


func has_landed() -> bool:
	return _landed


func has_settled() -> bool:
	return _settled


func has_collected() -> bool:
	return _collect_count > 0


func lean_deg() -> float:
	return rad_to_deg(_cut().lean)


func chip_count() -> int:
	return _chips.size()


## Which way the NOTCH faces — the fall line the first cut's angle of entry committed the
## tree to. `fall_direction()` is what the load model actually chose; on a controlled fall
## the two agree.
func notch_direction() -> Vector3:
	return _cut().face_dir


func fall_direction() -> Vector3:
	return _fall_dir


func face_side() -> int:
	return _cut().face_side


func trunk() -> TreeTrunk:
	return _trunk


## The camera the game is seen through — the PLAYER's, at eye height. Was
## `get_node("CameraPivot/Camera3D")` at half a dozen call sites in the tests and dev
## tools; it is a seam now so the rig can move again without hunting for them.
func camera() -> Camera3D:
	return _camera


func player() -> ForestPlayer:
	return _player


## Step the DEV camera round the tree (deg). Replaces the A/D orbit for the shot
## tools; A and D are strafe now.
func debug_orbit_camera(degrees: float) -> void:
	dev_camera_yaw_deg += degrees
	if not player_controlled:
		_apply_camera()


## Put the player on the ground `distance` metres from the tree at `degrees` round it,
## looking at `focus_y` up the trunk — the walk-round-the-tree move, without the walk.
## Test/dev seam: it is how `felling_spam`'s walk phase and any future acceptance check
## get to a different side of a trunk without simulating three seconds of WASD.
##
## Goes through the DEV CAMERA exports rather than posing the player directly: while
## `player_controlled` is false `_apply_camera()` re-poses the player every frame, so
## a direct `place()` would be undone before the next blow landed.
## `across` shifts what the crosshair is pointed at sideways off the trunk's centre
## line (m, positive to the player's right) — the ONE thing a first-person player
## still controls freely and the thing plan §2 warned would be lost, so it has to be
## drivable headlessly.
func debug_stand_at(degrees: float, distance := 3.0, focus_y := 0.6, across := 0.0) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	dev_camera_yaw_deg = degrees
	cam_distance = distance
	cam_height = _player.eye_height
	cam_focus_y = focus_y
	# Back to orbiting the origin: this seam works in degrees round the scene centre, and a
	# leftover anchor from `debug_stand_at_tree` would silently offset every shot after it.
	_dev_camera_anchor = Vector3.ZERO
	_apply_camera()
	if absf(across) > 0.0001:
		# Re-aim off the centre line from where _apply_camera just put the player. It
		# runs again next frame and would undo this, so anything reading the aim must
		# do it before the frame turns over — which is what debug_aim() is for.
		var right := _camera.global_transform.basis.x
		right.y = 0.0
		if right.length() > 0.0001:
			_player.place(_player.global_position,
				global_position + Vector3(0.0, focus_y, 0.0) + right.normalized() * across)


## What the crosshair is on right now, as `_aim()` reports it. Test/dev seam: it is the
## only way to check the first-person aim headlessly, since the click layer itself is
## not headless-verifiable.
func debug_aim() -> Dictionary:
	return _aim()


## EVERY TREE IN THE STAND. Test/dev seam — `core/tools/forest_smoke.gd` is the only thing
## that checks the forest, because m5_acceptance is pinned to one tree.
func debug_trees() -> Array:
	var out: Array = []
	for t in _trees:
		if is_instance_valid(t):
			out.append(t)
	return out


## The registered visual tree types. Test/dev seam for the data-driven species
## table; callers get a deep copy so they cannot mutate the live declaration.
func debug_species_catalog() -> Array:
	return _TREE_SPECIES.duplicate(true)


func debug_nearest_tree() -> TreeTrunk:
	return _nearest_tree()


## The highest a blow can land on a given tree — the clamp an eye-height crosshair runs
## into. Test seam: it is the only way to check, per asset, that a cut is placed in wood
## the player can actually see rather than in the strip the crown laps over.
func debug_max_cut_height(trunk: TreeTrunk) -> float:
	return _max_local_y_of(trunk)


## ...and the LOWEST. With the roots in the field the band starts at the dirt, so this is
## what says whether the player can actually work down into the flare. Test seam.
func debug_min_cut_height(trunk: TreeTrunk) -> float:
	return _min_local_y_of(trunk)


## The load model's whole verdict, not just its stress — which height it picked, what is
## left there, which way it would go and whether it would be a hinge or a collapse.
## Diagnostic seam: `last_stress()` alone cannot tell a tree that is about to hinge over
## from one that is about to be cut clean through, and those are very different failures.
func debug_evaluate() -> Dictionary:
	return _evaluate()


## Make a tree the active one and build its wood, WITHOUT striking it. Test seam: it is how a
## caller measures a tree's wood before and after a blow, which is the only honest way to
## check that a blow removed any.
func debug_engage(trunk: TreeTrunk) -> bool:
	return _engage(trunk)


## Stand the player in front of a GIVEN tree, at the dev camera's own distance. The walk,
## without the walk — `debug_stand_at` works in degrees round the scene origin, which means
## nothing once there is more than one tree to stand at.
func debug_stand_at_tree(trunk: TreeTrunk, distance := 2.6, focus_y := 0.5) -> void:
	if trunk == null or not is_instance_valid(trunk) or _player == null:
		return
	var at := trunk.axis_point()
	# Straight along +Z from the tree, so the camera's right-vector is +X exactly as the
	# dev camera's is at yaw 0 — every check that reads `side` depends on that.
	_player.place(at + Vector3(0.0, 0.0, distance), at + Vector3(0.0, focus_y, 0.0))
	# The dev camera re-poses the player every frame from these, so they have to agree or
	# the next frame puts it back at the origin.
	dev_camera_yaw_deg = 0.0
	cam_distance = distance
	cam_height = _player.eye_height
	cam_focus_y = focus_y
	_dev_camera_anchor = at


## Drive one blow at a NAMED tree, engaging it (and so building its wood) first. `debug_blow`
## always works on whichever tree is active; this is how a caller picks.
func debug_chop_tree(trunk: TreeTrunk, side := 1, local_y := INF) -> bool:
	if not _engage(trunk):
		return false
	return debug_blow(side, local_y)


## Index of a felled length still long enough to buck, or -1 once the trunk is bucked
## right out. Test/dev seam: `_logs` is reindexed every time a section comes free, so a
## caller cutting a whole trunk up cannot just count.
func debug_next_bucking_log() -> int:
	for i in range(_logs.size()):
		if is_instance_valid(_logs[i]) and _is_cuttable(_logs[i]):
			return i
	return -1


## How many logs are in the air on their way to the player. Test/dev seam — the flight is
## scripted and real-time, so a test has to be able to wait for it.
func logs_in_flight() -> int:
	return _flight.count()


## The stumps standing in the stand. Test/dev seam: "the stump remains" is the requirement, and
## counting them is how it is checked.
func stump_count() -> int:
	var n := 0
	for stump in _stumps:
		if is_instance_valid(stump):
			n += 1
	return n


## The minimum log length for the trunk on the ground (m) — `buck_target_logs` worth of it, or
## the `buck_min_length` floor. Test/dev seam: it is what "no coins" has to be measured against,
## and it is not a bare export any more.
func min_log_length() -> float:
	return _min_log()


## True once there is nothing left of the felled trunk worth cutting. Test seam onto
## the rule that ends a persisting trunk.
func is_bucked_out() -> bool:
	return _bucking and _bucked_out()


## Every bucked length's length (m). Test seam for the minimum-log rule: the assertion
## worth making is about what is lying on the ground, not about one cut.
func debug_log_lengths() -> Array:
	var out: Array = []
	for body in _logs:
		if is_instance_valid(body):
			out.append(_log_length(body))
	return out


## Where a bucked length starts and ends on its own local Y. Test seam — a section's
## collider is not centred on its body origin, so a test cannot guess the ends.
func debug_log_span(log_index := 0) -> Vector2:
	if log_index < 0 or log_index >= _logs.size() or not is_instance_valid(_logs[log_index]):
		return Vector2.ZERO
	return _log_span(_logs[log_index])


func fallen_trunk() -> RigidBody3D:
	return _fallen


func tree_def() -> TreeDef:
	return _tree_def
