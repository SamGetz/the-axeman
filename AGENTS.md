# AGENTS.md — The Axeman (Hybrid 2D/3D Cozy Village Builder)

You are the Lead Gameplay Programmer and Technical Engine Architect. The human
user (Sam) is the Creative Director. This file plus the Master Project
Blueprint are your absolute source of truth.

**Engine:** Godot 4.7 (stable) · **Renderer:** Compatibility
(`gl_compatibility`) · **Language:** GDScript only, native nodes only, no
third-party plugins, no invented APIs.

---

## CURRENT PROJECT STATUS (as of 2026-07-18)

- **AGENT HANDOFF IN EFFECT: read `handoff/00_OVERVIEW.md` (repo root)
  before doing anything.** The pack (`handoff/00`–`06`) carries environment
  knowledge, per-module build specs for M3–M8, and the ask-Sam lists.
  **If working on M4 slicing, ALSO read `handoff/07_M4_SLICING_POC.md`** —
  the runtime-slicing POC state, the render-to-PNG debug workflow, and the
  Compatibility-renderer material traps.
- **M1 (Core Contracts): DONE, signed off.** 21/21 acceptance
  (`res://core/tests/m1_acceptance.tscn`, F6). Red errors during tests
  2, 5, 7, 8 are EXPECTED; only `FAIL:` lines are failures.
- **M2 (main scene shell + pixel pipeline): DONE, functionality accepted;
  art direction deferred by Sam.** 21/21 acceptance
  (`res://core/tests/m2_acceptance.tscn`). Known: SpotLight3D
  `light_projector` gobo does not render under gl_compatibility (see
  Amendment 9 — replaced in the M4 mini-game scene by an animated
  shadow-cutout gobo); game boots to empty 2D mode by design — M key
  (temp debug in `scenes/main.gd`) toggles into the 3D placeholder scene.
- Autoloads registered in this order: `EventBus`, `InventoryManager`,
  `GameState` (uid:// refs in project.godot are normal), then the
  godot_mcp service autoloads. `res://core/enums.gd` is class_name only —
  NEVER an autoload.
- **M3 (GameFeel): code DONE, awaiting Creative Director sign-off.** 16/16
  acceptance (`res://core/tests/m3_acceptance.tscn`; awaits timers — run
  headless with `--quit-after 600`). GameFeel registered as 4th autoload
  (Amendment 5, logged below). Hit-pause overlap guard, trauma camera shake
  (h/v offset), `register_impact`, A7 wiring all verified. Placeholder scene
  root now has `placeholder_action_scene.gd` (camera hand-off). Temp debug:
  H key in `scenes/main.gd` fires a hit while in 3D mode (feel test).
  All pause/shake numbers in `game_feel_config.tres` are still placeholders
  — tune live with Sam.
- **M4 (runtime-slicing firewood mini-game): INTEGRATED into the main game,
  awaiting Creative Director sign-off.** (2026-07-22) The Amendment-6 slicer —
  which Sam feel-approved in the `slice_poc` harness — is now the live M4
  mini-game. `main.tscn`'s `3D_World_Root` instances the new
  `res://scenes/3d_action/chopping_minigame.tscn` (root Node3D runs
  `chopping_minigame.gd`; the standalone `chopping_minigame_harness.tscn` is
  just an F6 feel-test harness that instances the same scene inside a
  viewport). Enter the mini-game with the temp **M key** in `scenes/main.gd`
  (the A10 2D/3D toggle) until M7 supplies the real 2D entry. Viewport bumped
  to 960×540 (Amendment 7), then to 1280×720 + LINEAR filter (Amendment 8,
  pixel-art look dropped) in `main.tscn` + the harness + m2_acceptance.
  - **Renamed 2026-07-22:** `slice_poc.gd`→`chopping_minigame.gd`,
    `slice_poc.tscn`→`chopping_minigame_harness.tscn`,
    `core/tools/poc_smoke.*`→`core/tools/chopping_smoke.*`. Sam's call: once
    the POC was feel-approved and folded in, the shipping script/tests
    shouldn't carry a "POC" name. Pure rename, no logic changed.
  - **Ground: `res://assets/models/forest_floor/forest_floor_a.fbx`
    instanced directly** as a child node in `chopping_minigame.tscn` (scale
    0.4, Sam-authored placement) — replaces the old flat-color placeholder
    plane. The earlier code-driven approach (extracting a `Mesh` from the FBX
    and assigning it to an empty `Ground` MeshInstance3D in
    `chopping_minigame.gd`) was removed as redundant/superseded; the `Ground`
    node itself was deleted from the scene.
  - **Inventory wired (full M4):** a fully-chopped log deposits its species'
    item into InventoryManager — one `resource_gathered` per finished firewood
    piece, at the batch-collect point (`_begin_stacking`). Wood type is
    data-driven: `_LOG_SPECIES` in `chopping_minigame.gd` maps each log mesh →
    yield item, built to scale to many woods (add a row). CURRENT PLACEHOLDER
    MAPPING: `log_01.fbx`→`oak_log`, `log_02.fbx`→`pine_log` (both still wear
    the oak inside texture — log_02 is pine only to demo per-log yields; remap
    freely, and per-species textures can join the same table later).
  - Acceptance REWRITTEN for the slicer path: `m4_acceptance.tscn` 16/16
    (drives `debug_slice_world` to completion, checks inventory deposit ==
    firewood count, per-species yield, one hit per slice, A12 budget). It calls
    `get_tree().quit()` on finish — run headless with a generous `--quit-after`
    backstop (e.g. 8000). NOTE: the click-to-chop input layer itself is still
    NOT headless-verifiable — Sam eyeball-tests clicking in F5/F6.
  - **Retired + DELETED** (Amendment 6 authored-pieces path): `chopping_block.*`,
    `placeholder_action_scene.*` (orphaned M2), `slice_piece.gd` (unused),
    `data/fragments/pine_chain.tres`, `core/tools/build_pine_chain.gd`, and the
    `slice_poc.tscn*.tmp` editor turd. KEPT (reserved for M5/M6 per Amendment 6):
    `fragment_piece.*`, `fragment_physics_budget.gd`, `FragmentDef`. Dev shot
    tools repointed to `chopping_minigame.tscn`.
  - KNOWN: firewood uses the mini-game's own `max_firewood` (40) soft cap for
    feel, not `fragment_physics_budget` (A12's nominal 24) — reconcile at tuning.
  - **BUGFIX 2026-07-23 — sliced pieces shaded darker than the uncut log** (Sam
    reported "the material reacts differently with the light"). `MeshSlicer`
    carried only POSITION/NORMAL/UV across a cut, so `SurfaceTool.commit()`
    regenerated the tangent basis from the cut soup. Both log materials
    (`oak_bark`, `oak_top`) are normal-mapped, and the regenerated basis pointed
    ~90 deg off the FBX-authored one (import has `meshes/ensure_tangents=true`),
    so the normal map was read rotated — the end grain lost its warm highlight
    and went flat. `mesh_slicer.gd` now carries ARRAY_TANGENT and ARRAY_COLOR
    through the slice, interpolating both at the cut (handedness/binormal sign is
    per-surface, never lerped); cut caps still use `generate_tangents()` because
    their UVs are built fresh there, and now emit white vertex colours so a
    `vertex_color_use_as_albedo` cut material can't multiply to black. COLOR is
    carried for the same reason even though today's log FBXs export none — every
    log material sets `vertex_color_use_as_albedo = true` and the ASSET PIPELINE
    prefers vertex colours, so it would have bitten the moment Sam exports them.
    Regression-guarded by 4 new checks in `core/tools/test_slicer.gd` (now 14/14,
    verified to fail if the tangent carry is removed). No contract touched.
- **M5 (tree felling): REBUILT on voxel wood, awaiting Creative Director
  sign-off.** (2026-07-24, **Amendment 13**.) Sam's direction: *"the game
  generally feels very bad ... I want this game to feel visceral. The gameplay of
  single clicks is good, its just the simulation and how the tree is felled /
  simulated that I dont like"*, with the USDA Forest Service ax manual ("An Ax to
  Grind", `fs.usda.gov/t-d/pubs/htmlpubs/htm99232823/page04.htm`) supplied as the
  reference to borrow from. The single-click input is KEPT. Everything under it
  was replaced. 102 acceptance checks
  (`res://core/tests/m5_acceptance.tscn`; it `get_tree().quit()`s when finished,
  so run headless with a generous **`--quit-after 90000`** — that flag counts
  FRAMES, not seconds, and headless runs uncapped).
  - **THE WOOD IS A VOXEL VOLUME.** `wood_volume.gd` (`WoodVolume`) holds the
    bottom `band_height` (1.3 m) of the trunk as a signed-distance field, built
    from the tree's own radial profile, and re-surfaces it with SURFACE NETS
    after every blow. A blow subtracts the convex solid the axe displaces. The
    crown above the band keeps its imported mesh (clipped off once at build with
    MeshSlicer — which is now the only thing MeshSlicer does in M5).
    WHY: a plane cut removes a half-space and cannot carve a concave pocket, so
    the old code split the trunk into thin horizontal SLABS and took a convex
    bite out of each. Every M5 complaint traced back to that workaround — bites
    landed in whichever slab the click snapped to, remnant bands stuck out as
    floating disks, thickness had to be inferred from cross-section probes, and
    the fall had to be shoved because there was no real hinge to pivot on. None
    of it survives. The notch is ONE continuous pocket; the hinge is the wood
    actually left between the two cuts; the chip that flies past the camera IS
    the wood that left the hole (meshed off the removed voxels); and wood the
    player cuts free falls off on its own (`remove_floating`, a flood fill from
    the ground), so no piece of this tree can ever be left floating.
  - **THE LOOP IS THE MANUAL'S METHOD, from single clicks.** Click a side of the
    trunk: that opens the FACE NOTCH there and commits the tree to falling that
    way. Blows on that side alternate roof/floor cuts by themselves and carve a
    real drop-notch (the OPENING blow drives both faces at once, so the first
    click visibly opens the notch instead of shaving bark). Click the OTHER side
    and that is the BACK CUT — level, placed automatically `back_rise` (0.05 m,
    the manual's "minimum of 2 inches higher on the stump") above the notch and
    eating straight toward it. What is left between them is the HOLDING WOOD.
    ~9 blows to notch, ~7 to back-cut, 16 to fell a pine.
  - **NO HIT POINTS; the fell condition is a loaded beam.** After every blow each
    height of the band is measured as a section carrying the weight above it:
    `stress = crush + bend`, crush = W/area, bend = W·arm·c/I, every term off
    voxel-measured area, centroid, second moments and MEASURED reaches (16
    directions, `WoodVolume.SUPPORT_DIRS`). The reaches are measured rather than
    estimated from the moments because the model constantly compares a hinge (a
    strip) against a trunk (a disc), and a shape-calibrated estimate is right for
    one and wrong for the other. Evaluated in every horizontal direction; the
    worst height and direction is where and which way it goes.
    `crush_strength_kpa` / `bend_strength_kpa` are GAME numbers.
  - **WHY IT FALLS TOWARD THE NOTCH — and it is not a rule anywhere.** Bending is
    GATED on the room the trunk has to rotate that way: the vertical gap between
    trunk and stump on that side (`_void_height`). A face notch is a wedge with a
    wide open mouth; a level back cut is a slot one kerf tall that the trunk
    closes in a few degrees and then bears on the stump. THAT difference is the
    manual's reason for putting the back cut higher than the notch, and it is the
    whole direction mechanic. CRUSHING is deliberately NOT gated — being squashed
    needs no room to fall into — so a tree with nowhere to go still comes down,
    just crushed and unsteered instead of hinged over.
  - **Consequences, all emergent, none of them scripted:** a face notch alone
    does NOT fell a tree (the manual's whole point); an upright tree has to be
    notched PAST THE MIDDLE of the trunk before there is anything for gravity to
    topple it about; under-notch it and it stands there while the back cut eats
    the wood out from under it and it collapses with nothing steering it
    ("Cutting through the hinge wood is the single most dangerous thing a novice
    faller can do"); and good technique is both faster and controlled (16 blows
    against 18).
  - **`natural_lean_deg` (default 0) is the difficulty knob.** A LEANING tree can
    be brought down with the shallow notch the manual describes ("about
    one-third to one-half of the diameter") — provided you notch the side it
    already leans; notch the wrong side and it sits back on you and you have to
    cut the notch deeper to win it round. Baked into the MESH at spawn, not the
    node (a tilted node would fight the spawn animation and put the voxel band in
    a tilted frame). Left OFF by default so the base game is deterministic and
    the notch you can see is the whole answer. It wants a readout before it
    ships on.
  - **THE FALL IS SIMULATED IN BOTH HALVES.** `hinge_fall.gd` (`HingeFall`) runs
    the first `free_fall_deg` (58°): the tree is still ATTACHED and rotates about
    the real hinge line under `τ = m·g·arm(θ)`, resisted by holding wood that
    tears over `hinge_tear_deg`. At θ = 0 that arm is whatever the notch and the
    lean left hanging out past the hinge — so the fall starts on its own, from
    the cut, with no impulse anywhere. It is tiny, which is why the first second
    is agonising, and it grows with sin(θ), which is why the end is violent.
    Nothing about that curve is authored. Then it becomes a `RigidBody3D`
    carrying exactly the motion it already had, lands and settles.
    This SUPERSEDES the old "spin it about the hinge axis and let Jolt sort it
    out" release (Amendment 11's implementation, not its principle): a rigid body
    spun off a stump slid, jammed on the stump at ~25° and had to be nursed with
    a fake shove. Attached rotation cannot do any of those things.
  - New / replaced files: `scenes/3d_action/wood_volume.gd` (NEW),
    `scenes/3d_action/hinge_fall.gd` (NEW), `tree_trunk.gd` (REWRITTEN — the
    voxel band plus the crown), `tree_felling.gd` (REWRITTEN — the technique, the
    load model, the fall), `mesh_utils.gd` (+`rotated()`),
    `core/tests/m5_acceptance.gd` (REWRITTEN),
    `core/tools/{felling_smoke,tree_shot,probe_tree}.gd` (REWRITTEN —
    `probe_tree` now dumps the voxel field as ASCII, so the notch can be READ
    instead of squinted at in a render). Nothing was deleted: `MeshSlicer`,
    `FragmentDef`, `fragment_piece` and `fragment_physics_budget` are all still
    in use.
  - **Cost:** ~30-40 ms per blow for carve + remesh + load model. That lands
    inside `anticipation_sec` and the A11 hit-pause — i.e. at the exact moment of
    impact, where it is invisible. `voxel_cell` (0.055, about 17 cells across the
    trunk) is the quality/speed knob.
  - KNOWN, and do not remove it: `_cut_overlap()`. Subtracting a convex solid
    pushes each sample out only to the NEAREST FACE of that solid, so a sample on
    the boundary between two blows ends up on the surface of both and stays
    half-solid for ever. Untreated, a back cut leaves a stack of half-density
    films behind it, the measured section never drops, and the tree will not fall
    however long you chop. One cell of overlap fixes it, and it is what an axe
    does anyway (the next blow starts inside the last one's kerf).
  - KNOWN, minor: the band's bark UVs are cylindrical and their SCALE is matched
    to the crown's automatically (`TreeTrunk._bark_density`), so the band top is
    not a hard line; the texture PHASE still jumps there, which reads as a bark
    feature rather than a seam. Set `bark_tex_tile` non-zero to override.
  - **Everything numeric in `tree_felling.gd` is a placeholder** (all `@export`,
    grouped in the inspector). Verified by render-to-PNG under gl_compatibility
    (`core/tools/tree_shot.tscn`): the notch reads as a real drop-notch in
    profile, the fall hinges over and then goes, the stump ends cleanly at a torn
    break with the notch still carved into it, and the felled trunk lies flat
    beside it. **Live feel is NOT eyeball-verified by Sam yet** — cut cadence,
    blow counts, fall timing and camera are not headless-verifiable.
  - CONTRACTS: A2 was already superseded for trees by Amendment 10; A3, A7, A12
    and TreeDef are all untouched.
- **M5 PASS 2 (2026-07-25): the whole trunk is choppable, the landing hits, the
  debris settles, and the felled trunk gets BUCKED into logs.** Sam's direction:
  *"have another look at the physics to make sure the falling feels visceral and
  impactful. Make the whole tree choppable and have the splinters settling on the
  ground accurately. Correct the transparency issue on the tree as well, you can
  see through the choppable part to the backside."* Sam chose "standing trunk +
  buck the fallen one" when asked what "the whole tree" should mean. 130 acceptance
  checks (was 102), five consecutive clean runs; **`--quit-after 400000`**. No
  contract touched — every number below is an `@export` placeholder per Directive 3.
  - **THE TRANSPARENCY BUG WAS INVERTED WINDING, and it was in every triangle the
    voxel mesher ever made.** Godot's front face is the CLOCKWISE one — a triangle
    is seen from the side its right-hand-rule normal points AWAY from (the engine's
    own `SurfaceTool.generate_normals` computes `-(RHR)` as the facing direction).
    `WoodVolume._quad`/`_block_quad` wound the opposite way, so the carved butt's
    outer skin was culled and you looked through it at the inside of the far wall.
    MEASURED, not guessed: every triangle of Godot's BoxMesh, of `tree_01.fbx` and
    of `forest_floor_a.fbx` has RHR opposing its shading normal; the band had 3474
    of 3474 agreeing. It survived the Amendment 13 render-to-PNG check because a
    hollow trunk still has a trunk's silhouette, and only the bark showed it —
    `_cut_mat` is CULL_DISABLED, so the notch drew both sides and looked fine.
    `MeshSlicer._build_caps` had the same error, invisible because every cut
    material in the project is CULL_DISABLED. Both fixed; guarded by
    `MeshUtils.winding_report()` plus checks in m5_acceptance and test_slicer
    (17/17), which assert the engine's own primitive first so the convention itself
    is pinned.
  - **The carveable band is now the WHOLE CLEAR TRUNK**, found from the mesh rather
    than hard-coded: `TreeTrunk._clear_trunk_height()` bins vertices by height and
    stops at the first bin reaching past `radius * 1.25`, which is tree_01's first
    branch cluster — 2.3 m against the old 1.3 m of a 7.7 m tree. `band_height` is
    now 0 = auto (an explicit metre value still caps it) and `max_cut_height_frac`
    is 1.0, so nothing invisible limits where the axe works. It deliberately stops
    at the branches: the field clamps anything wider than the trunk back to the
    trunk, so a band reaching into the crown would delete the branches.
  - **Cost of that: 1.40x per blow for 1.77x more trunk**, after two optimisations
    in the same pass. `remove_floating` no longer floods the whole volume from the
    ground every blow — only wood beside the fresh cut can have come loose, so it
    seeds from the carve's own changed box (recorded as `_cut_lo`/`_cut_hi`) and
    early-exits as soon as a flood reaches the ground: 21.5 -> 4.8 ms. `_void_height`
    was O(levels² × dirs) per blow and is precomputed once (`_void_table`).
    `level_stats`' 16-direction reach test now skips interior samples (exact — an
    extreme point is always on the boundary). **`build_mesh` (~25-39 ms) is now the
    dominant cost and rebuilds the ENTIRE band when a blow touches ~4 of 43 levels
    — chunking it is the next real win** and is spawned as its own task. Absolute
    ms on the headless box drift ±30% run to run; trust the ratios.
    - TRAP, cost a debugging round: an early-exiting flood leaves its component only
      PARTLY labelled, and those labels then fence in the next seed, which cannot
      reach the ground and concludes a piece of the standing trunk came loose — one
      cut handed back 24 fragments of a column that was still standing. Hence
      `_HELD`: a flood that bails marks its whole trail, and a later flood touching
      that mark knows the answer immediately. Do not remove it.
  - **THE LANDING.** The trunk used to have its damping slammed to the settling
    values on the very frame it touched down, so it stopped dead at the exact moment
    the player was waiting for — a felled tree landed like a prop being set down.
    Now only the spin about its own long axis is killed on contact (that component is
    the endless cylinder roll; the rest is the tree still coming down) and the heavy
    damping arrives `land_slam_time` later. Impact strength is scaled by the real
    speed of the trunk's TIP (measured the frame before contact — by the time a
    contact is reported the solver has taken the speed away), which is 15.2 m/s for a
    full-height fall against a `land_impact_speed` of 9.0. The landing also gets its
    own longer slow-motion beat on top of the standard A11 chop pause (`land_pause`;
    A11's counted overlap guard composes them), and later slams — the butt crashing
    down, a bounce — register off a sharp drop in tip speed, since `body_entered`
    fires once per body and the ground is one body.
  - **DEBRIS THAT HAS SETTLED IS RESTING ON SOMETHING.** Freezing is how a body is
    retired here and it used to freeze the piece exactly where it was — right when it
    fell asleep on the ground, wrong the two other times it happens: the settle
    timeout runs on a clock whether or not the piece has landed, and A12's budget
    force-settles the oldest ACTIVE body whenever a new one would break the 24-cap,
    which M5 does constantly (five bodies a blow; the hinge tear spits fourteen a
    second). Splinters were being frozen mid-flight and left hanging around the
    stump. `fragment_piece._come_to_rest()` sweeps the piece down onto whatever is
    under it, and CONFIRMS it for six seconds afterwards because the thing it landed
    on can leave (the trunk rotating past). Three separate causes, all fixed:
    - Pieces whose convex hull **Jolt refused to build** ("suitable initial triangle
      ... area was too small") had NO COLLIDER AT ALL and fell straight through the
      world. Jolt shrinks a hull by its 0.04 m margin first, so a one-voxel chip or
      an 18 mm splinter collapses. Under `_MIN_HULL_THICKNESS` a piece now gets a
      BoxShape3D, which is a Jolt primitive and needs no margin.
    - The ground was a flat box topped at y = 0 while `forest_floor_a` is a sculpted
      mesh sitting at y = 0.005..0.034, so everything came to rest up to 34 mm under
      the visible dirt — deeper than a splinter is thick. `_fit_ground_collider()`
      builds a ConcavePolygonShape3D off the floor mesh at load; the box stays as a
      backstop. `backface_collision = true` on purpose: which way a trimesh face
      blocks depends on winding nobody is going to police on imported art.
    - Bodies spawned inside the stump are occasionally pushed out DOWNWARDS by the
      solver and then fall for ever. They now delete themselves below `void_y`, and
      `_MAX_DROP` is 5 m not 20 — with 20 m the confirm sweep "landed" an escaped
      splinter on other falling debris ten metres down and marched it to y = -80.
  - **BUCKING (`buck_*` exports, M5's own scope item).** The felled trunk now lies
    there and clicks cut it across into logs; one length comes free per cut and is
    booked in as it does. Cut with the PLANE SLICER, not the voxel field — a
    cross-cut IS a plane cut, which is the slicer's own case (and M4's), whereas
    voxelising the crown would clamp the branches away the moment the tree landed.
    Amendment 10 already permits the slicer for M5, so no new permission is needed.
    - **Yield rule, and Sam can overturn it:** a bucked length emits one
      `resource_gathered` as it comes off (M4's rule), and `_collect_yields()`
      deducts what bucking already paid. So a tree is worth EXACTLY its authored
      `TreeDef.yields` however it is cut up — buck it fully and the fade adds
      nothing, leave it whole and the fade pays the lot. Bucking sets the pace of
      the reward, never its size. Asserted in acceptance.
    - `buck_min_length` is enforced on the click path as well as the test seam:
      every section is an untracked rigid body, so without a floor a patient player
      could make unbounded numbers of them, which is A12's concern.
  - KNOWN, and it is a test seam not the game: **`debug_fell()` fires every blow
    inside a single frame and the tree then never falls.** The click path and
    m5_acceptance both put a frame between blows. Anything driving M5 headlessly
    should do the same; `debug_fell` wants either fixing or deleting.
  - KNOWN: m5_acceptance's "one continuous notch" check compared each level against
    the band's MEDIAN area, which read tree_01's own 3% taper at 1.9 m as a chop
    that was never made once the band got tall enough to reach it. It compares each
    level against its own uncut baseline now.
- **M5 PASS 3 (2026-07-25, same day): the default seam is gone, cuts can go anywhere,
  the fall has weight, and the debris is splinters that ignore the tree.** Sam's
  direction after looking at pass 2: *"It looks like there is a slice that comes in by
  default, breaking the illusion"* (with a screenshot of a ring round an uncut trunk);
  *"when the user cuts one point along the Y axis, they can no longer cut from any other
  point, the user should be allowed to cut however they want"*; *"the physics of the tree
  falling are also feeling very 'floaty', nothing in falling with any intensity"*; and
  *"the chunks that fall on to the ground can just be splinters (because the ones that
  are created currently look like flat disks) and make sure they dont interact with the
  large part of the tree... we are making small piles of splinters that the large part
  of the tree will not interact with, but the splinters will interact with the other
  splinters."* 147 acceptance checks (was 130), four consecutive clean runs. No contract
  touched.
  - **THE RING WAS A GAP, not a cap.** Surface nets puts a cell's dual vertex at the
    average of its edge crossings, and the top row of CELLS is the one below the grid's
    last sample row — so the band's geometry stops about half a cell short of `band_hi`
    (17 mm at cell 0.055) even though the field is solid all the way up. The crown was
    clipped exactly AT `band_hi`, so a slit of daylight ran right round the trunk.
    Proved by rendering the band top close up (a bright line, and stripping the crown's
    cut cap changed nothing), then fixed by clipping the crown `_CROWN_OVERLAP` = 2.5
    cells LOWER so its bark laps over the band's open rim — which also buries the
    slicer's cap where it was always meant to be. `_measure_upper` now subtracts the
    overlap slab, measured off the band's own levels, so the crown's weight is not
    counted twice. Re-rendered to confirm the line is gone; the faint texture
    discontinuity that remains is the already-known bark UV phase jump.
  - **THE PLAYER CUTS WHEREVER THEY LIKE.** The single notch and single back cut are
    now a LIST of cut sites (`_sites`), one per place the axe is working. A blow within
    `cut_reach` (0.3 m) of a cut deepens it and the axe returns to it; a blow anywhere
    else opens a new cut where the player aimed. The first cut anywhere still commits
    the fall side, and a back cut still gets the manual's `back_rise` placement — but
    only when there is a notch within reach to eat toward; on its own it goes exactly
    where it was aimed. `notch_depth()`/`back_depth()` report the DEEPEST of each, and
    `cut_count()`/`notch_height()`/`back_cut_height()` are the new public seams (the
    tests and `probe_tree` were reading `_notch_y`/`_back_y` directly and were moved
    over).
  - **THE FALL HAS WEIGHT: `fall_gravity_scale` (2.0) multiplies gravity for BOTH
    halves** — the attached hinge rotation and the rigid body after it — with
    `hinge_hold_frac` 0.7 -> 0.3 and `trunk_angular_damp` 0.3 -> 0.0. Measured, tree_01
    from full height: first visible movement (10 deg) 2.75 s -> **1.60 s**, on the
    ground 4.45 s -> **2.80 s**, tip speed at impact 15.6 -> **23.1 m/s**. Most of what
    read as floaty was the first two seconds, in which the old hold kept the tree inside
    two degrees of upright — nothing appeared to have happened at all. Above 1.0 this is
    frankly not physical and says so in the inspector; 1.0 is honest gravity if it is
    ever wanted back. `land_impact_speed` raised 9 -> 18 so a full fall still maxes the
    impact out while a partial one has somewhere to scale from.
  - **DEBRIS IS SPLINTERS, AND IT IGNORES THE TIMBER.** A blow's removed wood was
    thrown as the carved geometry itself — honest, and it looked wrong, because a bite is
    a thin flake and flakes lie on the ground as flat discs. Now the VOLUME removed is
    converted into splinters (`splinter_wood_each` m³ each, `splinter_burst_cap` per
    burst), which also means nothing meshes the removed voxels at all any more —
    `TreeTrunk.chop(..., want_meshes := false)` and a null-material fast path in
    `_extract_island`. Collision is split four ways (constants on `TreeTrunk`, used
    everywhere): `GROUND_LAYER` the floor, `TIMBER_LAYER` the stump / falling trunk /
    bucked logs, `DEBRIS_LAYER` the splinters. Debris collides with the ground and with
    other debris and passes straight THROUGH the timber, which Sam explicitly asked for
    and is happy to see clip. The bucking ray is masked to timber only, or a splinter
    lying on the log would swallow the click.
    - Follow-up caught by rendering it: a piece force-settled mid-tumble kept its pose,
      and when that pose was "on end" the result was splinters standing upright in the
      dirt like nails, several per felling. `fragment_piece._lay_down()` now tips an
      elongated piece over before seating it — a stick balanced on its end would fall,
      so it is the physical answer too. Pieces that fell asleep on their own are left
      exactly as the solver left them.
- **M5 PASS 4 (2026-07-25, same day): the crown stays attached, and the cutting is
  properly free-form.** Sam: *"The part above the voxel doesnt connect properly and often
  times just slides off before the cut is finished. The cutting also needs to be totally
  free form, you should be able to cut anywhere on the voxel, the angle can be variable,
  we're just trying to make the user have the highest level of agency here."* 149
  acceptance checks (was 147), repeat-verified. No contract touched.
  - **THE CROWN WAS SLIDING OFF BECAUSE THE LEAN PIVOTED ON THE CUT.** `set_lean` swings
    only the crown (the butt is voxels and must never move, or the tree stops looking
    rooted) and it pivoted at the height the wood was failing — where a real tree bends.
    That swings the crown's BASE sideways by `(crown base - pivot) x sin(lean)`. With the
    old 1.3 m band and a low cut that was ~7 cm and passed for bark relief; now the crown
    starts at 2.16 m, and the same 5 degrees moved its base **14.5 cm** across a trunk
    0.47 m in radius — the crown visibly slid off the carved butt, part way through
    chopping, since the lean tracks stress. It now pivots on the crown's own base
    (`_crown_base`), so the joint cannot move at all and the crown just tips. Guarded:
    acceptance measures the crown's base offset under load (0.0000 m).
  - **THE CUT IS FREE-FORM: no scripted notch, no alternation, no privileged sides.**
    Each blow builds its own solid — a slab `cut_kerf` thick at the blade's angle, driven
    `bite_depth` in from wherever the wood's surface currently is. There is no notch/back
    cut distinction left in the geometry at all; a cut is a cut, and what it becomes is
    whatever the player drives into it. `_face_blow`/`_back_blow`/`_face_cut`/`_apex_world`
    are gone, replaced by `_cut_blow`/`_cut_slab`.
    - **The ANGLE is how far above or below the cut the click lands**, mapped through
      `cut_reach` to ±`free_cut_max_deg` (55°). Click level with the cut and it goes
      straight in; click high in it and the axe comes down; click low and it comes up.
      Continuous, and it costs no extra input — the player is already choosing a point.
      Verified by render: three cuts at three heights, each shaped by aim.
    - The opening blow still lays in a two-angle wedge (the manual's own notch angles),
      because one cut into a round trunk lifts a sliver of bark and reads as a miss.
      That is the only help left.
  - **TRAP, and it cost two rounds: a widening kerf widens nothing if the blow only cuts
    the advancing shell.** The kerf has to open out as a cut deepens (`kerf_flare`) or an
    axe would be driving a slot its own width half a metre into a trunk — and it matters
    mechanically, not just visually, because bending is gated on the room the trunk has
    to rotate into. But the blow's solid originally spanned only `face - overlap .. face +
    bite`, so the wood newly inside the wider kerf but nearer the SURFACE was never
    touched: the cut bored in at its original height, the mouth never opened, the void
    stayed pinned at exactly `cut_kerf` and the tree crushed where it stood instead of
    hinging (0.110 m against a `topple_min_open` of 0.20, every blow). The solid now
    reaches back out past the bark, re-cutting the whole gullet each blow — the field is
    already air there, and only samples that actually stop being wood count as removed.
    With that, the notch mouth opens 0.11 -> 0.275 m over nine blows and the tree hinges
    over properly again.
  - **Blow counts moved and they are Sam's to set:** a pine now fells in ~12 (9 notch + 3
    back) against ~16, hinge intact, the fall controlled. `back_bite` still governs cuts
    coming in behind the fall side, for the manual's reason — keep it well under the
    hinge thickness or one blow takes a tree from safely standing to hinge-severed.
    `kerf_flare` (0.35) is the new knob and it applies only on the fall side: a back cut
    is driven toward an opening that already exists, and flaring it eats the holding wood
    vertically and severs the hinge.
  - **One documented emergent behaviour weakened, honestly:** an under-notched tree used
    to come down with NOTHING steering it. It is now allowed a little steering, because
    once the holding wood is a sliver there is genuinely nothing left sticking out toward
    the fall side. The manual's lesson is intact and is now measured as cost —
    acceptance asserts the under-notched tree needs **14 back-cut blows against 6** and
    cuts **72% of the diameter against 33%**.
- **M5 PASS 5 (2026-07-25, same day): the ANGLE OF ENTRY is the player's, and the wood
  the axe opens is END GRAIN.** Sam, after tuning the cut settings live: *"I want the cut
  to not happen on just the full left or full right (which is happening now) I want to
  control the original angle of entry as well (we can set it by default as 30 degrees to
  whichever side is being cut)"* and *"use the oak log top texture as the internal wood
  texture, since we'd see rings if thats how we were really cutting it."* 157 acceptance
  checks (was 149). No contract touched.
  - **`entry_angle_deg` (30) — how far round from HEAD-ON a cut comes in.** 90 is
    square-on to the side, which is what every cut used to be: the notch faced dead left
    or dead right and the tree always fell straight across the frame. It is the floor and
    the default, and the player varies it above that by WHERE ACROSS THE TRUNK they click
    — the cut enters at the angle of the point they actually pointed at, so the silhouette
    edge cuts square from the side and a click in toward the centre line comes round the
    front. Threaded through the strike as `azimuth`; `debug_blow(side, y, edge)` takes the
    click position as its third argument. At 30 the tree falls diagonally toward the
    viewer, which is a real change of look — raise it toward 90 for the old fall.
    - **The fall line is set by the FIRST cut and the back cut is MIRRORED through it.**
      Cuts on the fall side keep the player's angle blow after blow (so a notch can be
      swept round the face); a cut behind comes in opposite whatever angle is being worked.
      It cannot simply take the click's own angle: a back cut 30 degrees the other side of
      head-on sits 60 degrees from the notch instead of 180, there is no holding wood
      between them, and the tree never fells at all. That is what happened on the first
      wiring — 58 acceptance checks went red at once.
  - **END GRAIN on the cut faces.** `WoodVolume.ring_radius` maps every cut face by
    projecting the trunk's cross-section straight onto the texture, centred on the trunk's
    own axis and scaled so the bark ring in the image lands on the bark. It cannot be a
    tiling projection: `wood_oak_top_diffColor.jpg` is a single log round on a white field,
    and tiling it three to the metre gives a grid of little discs. `texture_repeat` is off
    for the same reason. SPLINTERS keep the old streaky `wood_oak_inside` on their own
    material (`_splinter_mat`) — a splinter is a stick torn out along the grain, so its
    faces are long grain, not rings. Render-verified: the rings sit concentric on the
    trunk's centre in the notch and on the stump.
  - **A REAL BUG Sam's tuning exposed, worth remembering: a site the player cannot find
    again.** With `cut_reach` at 0.01 every back blow opened a NEW cut — 41 sites in 49
    blows, so the tree collected nicks that never joined into a notch and never fell.
    `back_rise` places a back cut 5 cm above the notch it eats toward, so the site sits
    5 cm from the click that made it, and `_site_at` matched on the site's position only.
    Sites now also record the height that was AIMED at and match on either.
  - **KNOWN, and it now warns: `cut_span` narrower than the trunk changes the game.** A
    blow's slab is centred on the trunk's axis, so a narrow span cuts a CHANNEL through the
    middle of the face and leaves flanks either side that can only be reached by bringing
    the cut round with the angle of entry — and past that by orbiting the camera. Measured
    on tree_01 (0.94 m across): **0.8 m and above fells in ~15 blows; 0.6 and below cannot
    be felled from one viewpoint at all**, however long you chop. Sam's live value is 0.50,
    so `_warn_cut_span()` says so once per tree at spawn rather than leaving it to be
    discovered. `m5_acceptance._make_game` now PINS `cut_span`/`cut_reach`/`entry_angle_deg`
    alongside gravity and the bite, for the reason that helper already existed.
- **M5 PASS 6 (2026-07-25, same day): THE BACK CUT IS GONE. Every blow is head-on, on
  the side the player can see.** Sam: *"I dont like the way striking the opposite end of
  the tree feels. all the cuts should be like the head on cut. No 'opposite side cutting'
  where you cant see what is happening."* 154 acceptance checks (was 157 — three were
  specifically about the back cut). No contract touched.
  - **`_cut_dir` now always returns `_side_dir(side, azimuth)`** — outward from the trunk
    toward the point that was clicked, always in the camera-facing hemisphere. Nothing is
    ever driven in from behind the trunk, where the trunk itself hid the most consequential
    cut in the game.
  - **WHAT REPLACES THE MANUAL'S TWO-CUT TECHNIQUE is the simpler thing that was always
    underneath it: chop a notch and the tree falls into it.** The holding wood is whatever
    is left BEHIND the notch — which is what holding wood is — and the tree comes over when
    that cannot carry it. **No part of the load model changed to allow this.** It never
    cared how many cuts there were or where they came from, only what wood was left at each
    height and which way it had room to go. That is the payoff of Amendment 13's "measure
    the wood, do not track the technique": the technique could be deleted and the
    simulation did not notice.
  - Measured (pinned settings, tree_01): **11 blows on one head-on cut**, notch 83% through
    the diameter at failure, holding wood 0.084 m², **hinge intact — a controlled fall**,
    going over toward the notch (dot 0.97), landing at 18.5 m/s and settled in 2.4 s.
  - RETIRED: `back_bite`, `back_rise`, `back_depth()`, `back_cut_height()`, and the
    `back_rise` auto-placement in `_open_site` (nothing is repositioned on the player's
    behalf now that every cut is one they can see). `notch_depth()` / `notch_height()` now
    report the deepest cut ANYWHERE rather than the deepest on the fall side.
    `notch_roof_deg`/`notch_floor_deg` survive as the OPENING WEDGE's two angles.
    `kerf_flare` applies to every cut now — they are all notches.
  - **CONSEQUENCE Sam should know: the tree now falls toward the viewer**, because it falls
    into a notch that by definition faces the camera. `entry_angle_deg` is the knob and it
    still spans the full range — at 90 the cut is square-on to the silhouette edge (still
    perfectly visible, it is the trunk's profile) and the tree falls across the frame as it
    used to; at the default 30 it comes down diagonally toward the player.
  - `core/tools/felling_smoke.gd` now PINS the same settings `m5_acceptance._make_game`
    does. It did not, so it was reporting on Sam's live `cut_span` of 0.50 — which cannot
    fell a tree — and read as six regressions that were not there.
  - **Still NOT eyeball-verified by Sam:** all of passes 2-6's feel. Render-verified: the
    seam, the splinter piles, simultaneous cuts, the crown join, the notch profile, the
    angled entry, the end-grain rings, and both halves of the face cutting head-on.
- **M5 PASS 7 (2026-07-26): the band/crown join stops reading as two objects, and a blow
  costs half what it did.** Sam's direction: *"the voxel area and non-voxel area look
  disconnected. It may be worth having the whole tree set as a voxel object, and just
  limit how high the user can cut instead"* and *"the simulation tends to get a little
  heavy when the user is spam clicking the tree, look in to making the code run faster"*.
  Triaged first, with numbers, and the whole-tree-voxel option was put to Sam with its
  price and NOT taken — Sam approved fixing the seam instead. 154 acceptance checks still
  pass (unchanged), M4 16/16, slicer 17/17. M2 is 22/23, which is the pre-existing
  `Action_Viewport` A1 finding above and nothing to do with this pass. No contract touched.
  - **WHY NOT VOXELISE THE WHOLE TREE.** Measured: tree_01's AABB is 1.84 x 7.72 x 2.06,
    so at the shipping cell (0.055) a whole-tree grid is **262,558 samples against the
    band's 26,875 — 9.8x**, and it would replace a static imported crown with several
    thousand triangles re-uploaded every blow. The blocker is not the cost though: the
    field is a RADIAL PROFILE, one radius per (level, angle) about the trunk axis, which
    cannot represent a branch at all — that is what `_PROFILE_CLAMP` exists for. It would
    need a real mesh->SDF voxeliser and a cell fine enough for branches a few cm thick,
    which is far worse than 9.8x, and the answer would still be radial blobs where the
    branches are. A hybrid always has a seam somewhere; the fix is making the two
    surfaces AGREE at it. `core/tools/felling_profile.gd` prints the grid arithmetic if
    it is ever worth revisiting at a coarser cell.
  - **THE SEAM WAS FOUR THINGS ON ONE LINE, and rendering the band and the crown
    SEPARATELY at the same camera (`core/tools/seam_layers.gd`) is what separated them.**
    The line Sam could see is the CROWN'S BOTTOM RIM, visible because the band was
    uniformly wider than the crown and poked out past it.
    - **The band was wider because the profile was a histogram.** `_radial_profile` binned
      every edge CROSSING by whatever angle it happened to land at and kept the widest per
      bin. These trees are prisms — tree_01's trunk is **16-sided** — and 24 bins do not
      divide 16, so some bins caught a facet CORNER and some only a facet FLAT. Measured
      wobble against the source silhouette: **+/-14.2 mm on a 471 mm radius, in both
      directions round the ring.** Replaced by `_build_profile`, which assembles each
      level's cross-section as real SEGMENTS and casts one ray per bin at exactly the
      angle `_profile_at` reads it back at, with `_PROFILE_BINS` raised 24 -> 64. Now
      **+/-9.5 mm and consistently INSIDE the source** — the residual is voxel
      quantisation and it no longer straddles. Build-time cost only.
    - **The bark was at the wrong SCALE, not just the wrong phase.** `_bark_density`
      matched a single isotropic texel density, which is only right if the artist's
      mapping is isotropic and tree_01's is stretched — so the band's bark came out
      visibly coarser than the crown's. `_build_profile` now carries the source's UVs to
      every (level, bin) hit, `_fit_bark_uv` reads the mapping's scale and phase off them
      (by MEDIAN of differences, because u wraps a full period somewhere round every ring
      and one outlier must not move the answer), and `_finish_uv_table` unwraps that into
      a table the band READS ITS UVs OUT OF. The fit alone got the scale right (2.97 per
      turn against the source's 3.0) but drifted about a tenth of a repeat in phase,
      because a prism is unwrapped facet by facet and u is piecewise linear — the table
      reproduces the kinks. `bark_tex_tile` still overrides, and drops the table with it.
    - **The band now ducks under the crown over the lap** (`WoodVolume.rim_inset/_lo/_hi`,
      set from `TreeTrunk._RIM_INSET_CELLS` = 0.5). The two surfaces can never agree
      exactly, so rather than hope, the band's RENDERED radius is pulled in inside the
      crown's overlap and the crown wins everywhere. **Rendering only — `_d` is untouched,
      so the load model still measures the wood that is really there.**
    - Consequence: the visible transition moved DOWN from `band_hi` to `_crown_base`,
      because the band no longer occludes the crown through the lap. That is correct.
    - What is LEFT is a soft tonal line at the join, from the crown's imported normals
      against the band's SDF-gradient ones. At gameplay distance it is not findable
      (`seam_1_whole.png`); at 2.2 m it is a faint tone step. Not chased further.
  - **PERFORMANCE: ~40-70 ms per blow -> ~26-40 ms, and it no longer creeps.**
    `core/tools/felling_profile.gd` breaks a blow into its parts; `core/tools/
    felling_spam.gd` drives four trees at the fastest rate the input path allows and
    shows the cost is FLAT (first chop into fresh wood: 33.2 ms on tree 0, 33.5 ms on
    tree 3) with node counts identical per tree.
    - **`level_stats` is incremental.** A level is measured from the samples at its own
      level and nowhere else (`_edge_sample` looks sideways, never up or down), so
      everything that writes `_d` now marks the levels it wrote (`_dirty_levels`) and only
      those are remeasured. **Full remeasure 10.4 ms; a blow now pays ~4 ms** (an angled
      cut genuinely spans ~14 of 43 levels — a 45-degree slab across a 0.94 m trunk is
      most of a metre tall). Through `TreeTrunk.sections()` this took **`_evaluate` from
      11.2 ms to 0.92 ms**. `build_mesh`'s clip path deliberately does NOT invalidate: it
      restores the field byte for byte, and the stump's collider must be measured off the
      wood the notch left.
    - **The remesh is CHUNKED** (`WoodVolume.CHUNK_CELLS` = 8, `chunk_mesh`,
      `take_dirty_chunks`). `TreeTrunk._band_mi` is now a Node3D parent of chunk
      MeshInstance3Ds; the break frees them and puts a single `_stump_mi` in their place.
      **~16 ms whole-band -> ~10 ms chunked**, and on real hardware it is worth more than
      that ratio because only the changed chunks re-upload their vertex buffers.
      `band_mesh()` is now a test/dev seam that REBUILDS the whole band — do not call it
      per frame.
    - **Two cheap caches that mattered more than they look.** `_cell_uv` and `_cell_ang`
      are filled in `_eval_cell` (which only runs for cells whose field changed) instead
      of per vertex per remesh: `_quad` was running four `atan2` calls on every bark quad
      purely to decide the texture seam, ~2400 a remesh. **Remesh 18-25 ms -> 15-16 ms**
      before chunking.
    - **The opening blow no longer remeshes twice.** `_cut_blow` lays in two slabs at the
      manual's notch angles; `TreeTrunk.chop(..., defer_remesh)` + `finish_chop()` surface
      them once. **First blow 64-71 ms -> ~33 ms.** BOTH slabs defer and the finish is
      unconditional, so a slab that happens to carve nothing cannot leave the band a blow
      behind the field it is measured from.
    - **A12's budget stopped being O(n) per spawn.** It answered "how many are active?" by
      walking every body it had ever been handed, behind a `filter` that allocated a fresh
      array each time — and M5 spawns ~12 bodies a blow and never retired one. Measured:
      **0.29 ms per spawn at 100 tracked, 0.95 ms at 850** — the game getting heavier the
      longer Sam chopped, which is precisely what was reported. A body now leaves the hot
      list when it emits `settled`, so that list is bounded by the cap and the common case
      is one size comparison. `active_count()`/`tracked_count()` mean exactly what they
      did (m4_acceptance's `tracked_count() == 30` still holds).
    - **Debris is bounded.** `max_debris` (120, `@export` placeholder per Directive 3)
      retires the OLDEST SETTLED piece, so nothing vanishes in front of the player. A12's
      24 is a cap on bodies still MOVING and says nothing about how many stopped ones
      accumulate. Splinter meshes are now SHARED (three sizes in the whole game, each was
      rebuilding a BoxMesh into a fresh ArrayMesh per splinter), and
      `fragment_piece` calls `set_physics_process(false)` once it is settled and has
      finished confirming what it is resting on — that was ~150 scripted calls per physics
      tick by the end of a felling.
    - MEASURED AND REVERTED, do not retry: clearing `_emit`'s three grid-sized vertex-slot
      arrays by walking `_active` (~3000 writes) instead of `fill(-1)` (~80,000) is
      **SLOWER**. `fill` is one native memset; an interpreted loop is not.
    - NOT trustworthy headless, and not claimed: physics CPU. `await physics_frame`
      measures wall clock (headless still ticks at the project rate, so it reads ~16.7 ms
      whatever the load) and `Performance.TIME_PHYSICS_PROCESS` comes back inconsistent on
      a free-wheeling run. `felling_spam.gd` reports node and body counts instead and
      leaves the millisecond judgement to real hardware.
  - **TRAP worth remembering: a `Packed*Array` stored inside an `Array` is a VALUE.**
    `segs[j]` hands back a COPY, so appending to it in place writes into a temporary. It
    emptied every level's cross-section, the profile fell through to its last-resort
    `max_radius * 0.5`, and tree_01 came out as a uniform 0.27 m pole. Read, append, write
    back — and `_edge_cross` writes to a MEMBER (`_cross_buf`) for the same reason.
  - New dev tools, all following the `core/tools/` pattern:
    `felling_profile` (per-blow cost breakdown + the whole-tree grid arithmetic),
    `felling_spam` (sustained spam clicking), `seam_shot` (the join at several framings),
    `seam_layers` (band and crown rendered separately — this is what diagnosed the seam),
    `seam_probe` (band vs source radius and the bark UV fit), `crop_shot` (magnify a
    region of a saved shot).
  - **Still NOT eyeball-verified by Sam:** everything above is render-verified and
    headless-measured. The blow cadence and the join want a live look in F5/F6.
- **FIRST PERSON — STEP 2 OF `handoff/08_FPS_FOREST.md` IS BUILT (2026-07-26,
  Amendment 14). ONE TREE, ON FOOT. Awaiting Creative Director sign-off, and it wants a
  LIVE look before anything else is built on it — that is the whole point of stopping
  here.** Sam: *"I want this to be an fps game now, where you walk through a forest and
  chop down trees."* Sam's §0 decisions, taken before any code: the forest is **the 3D
  biome you walk into** (so A9/A10/A7 and the 2D village all survive, and this is an M5
  re-scope, not a new module); the A1 viewport fix goes through the **Settings UI**;
  **stop after the plan's step 2** and play it; and felled trunks **persist until
  bucked**. 182 acceptance checks (was 154), M1 21/21, M3 16/16, M4 16/16 — M2 is 22/23,
  which is the pre-existing A1 finding below and nothing to do with this pass. **`--quit-after
  600000`** for M5 now. No contract touched; every number below is an `@export`
  placeholder per Directive 3.
  - **THE SIMULATION DID NOT CHANGE, and that was the plan's central claim holding up.**
    `WoodVolume`, `TreeTrunk`, `HingeFall` and the load model take world planes and
    report measured wood; they never knew where the camera was. What changed is who
    holds the camera and how a blow is aimed.
  - **NEW: `scenes/3d_action/forest_player.tscn` + `.gd` (`ForestPlayer`).**
    CharacterBody3D -> Body (capsule) + Head -> Camera3D. WASD, mouse look, gravity,
    `move_and_slide`, mouse captured (ESC frees it, a click takes it back — and that
    click is SPENT recapturing, or it would swing the axe at whatever the crosshair was
    resting on). Mask is `GROUND_LAYER | TIMBER_LAYER`; layer is 0, so nothing is
    stopped by the player — a tree that can crush you is a design decision, not a
    collision-layer one. Debris is deliberately excluded (Sam's own call that splinters
    pass through timber; a hundred of them shoving the player about is all cost).
  - **THE DEV CAMERA IS HOW THE RENDER-TO-PNG WORKFLOW SURVIVED.** `player_controlled =
    false` makes the player a PUPPET posed by `cam_distance`/`cam_height`/`cam_focus_y`/
    `dev_camera_yaw_deg`, reproducing the old fixed orbit camera exactly — so
    `tree_shot`, `seam_shot`, `seam_layers`, `seam_probe`, `probe_tree`,
    `felling_smoke`, `felling_spam` and `felling_profile` all keep framing their shots
    the way they did, at about a dozen call sites. They pin it explicitly, as they
    already pin gravity and `cut_span`. **`m5_acceptance` pins it too**, for the reason
    that helper exists: nearly every check measures which way a tree went against the
    camera's own right-vector, and a suite that had to discover where a player was
    standing would measure something different every run. `_orbit`/`_yaw_steps`/
    `camera_step_deg`/`orbit_time` and the A/D keybinds are GONE (A/D is strafe);
    `debug_orbit_camera()` and `debug_stand_at()` replace them.
  - **AIM IS A RAYCAST, NOT SCREEN SPACE — and the plan was right that the naive port
    fails silently.** `_side_from_screen` compared the click's x against the trunk's
    unprojected x and called anything inside 2 px a tie, falling back to the side already
    being cut. **At a crosshair pointed at a trunk those two numbers are always within a
    pixel or two**, so passing the viewport centre to the old code would have collapsed
    BOTH the choice of side and `entry_angle_deg` into their tie-break, with everything
    still appearing to work. Everything now comes off the 3D hit point: a ray from the
    camera's centre against `TreeTrunk.PICK_LAYER` (renamed from `_PICK_LAYER`; the pick
    `Area3D` was built for this at M4 and had never been used), and `_decompose()` reads
    the side and the entry azimuth off the hit's horizontal offset from the trunk axis —
    the exact inverse of `_side_dir`. `_aim_point`/`_side_from_screen`/`_entry_edge` are
    deleted. Two things fall out for free: the ray strikes the trunk's NEAR surface, so
    PASS 6's "never cut round the back" is now geometry rather than a rule; and
    `debug_blow(side, y, edge)` is UNCHANGED, because `side` and `edge` were always
    camera-relative, not screen-relative — which is why 154 checks passed with no edits.
  - **NEW `chop_reach` (3.2 m):** you have to walk up to a tree. Nothing bounded this
    before, because the camera could not move.
  - **A REAL FIRST-PERSON BUG the walk measurement caught, and it could not have shown
    up before: a cut site remembers the world direction it was opened at, but `_site_at`
    matched on height and CAMERA-RELATIVE side only.** Walking round a trunk keeps
    handing back the same `side = +1` while the world direction behind it swings right
    round — so a player who walked to the far side and chopped had the blow folded into
    the notch on the face now BEHIND them, cutting wood they could not see. New
    `cut_face_arc_deg` (50) gates a match on the blow's own cut direction agreeing with
    the site's; past it the blow opens a fresh cut on the face it was aimed at. Threaded
    through `_impact_point`, `_preview_angle` and `_land_blow`.
  - **FELLED TRUNKS PERSIST (`trunk_persists`, on).** The trunk lies where it fell until
    it has been BUCKED OUT (nothing left over `buck_min_length`) or the player walks out
    of the forest (`minigame_exited` — M5 still only listens, A7 untouched). Never a
    timer; `buck_idle_clear` is ignored while it is on. **The PASS 2 yield invariant is
    intact**: whenever it does go, `_collect_yields` pays the balance bucking has not
    already booked, so a tree is worth exactly its authored `TreeDef.yields` however it
    was cut up. Asserted both ways in `_test_15`.
  - **A SECOND BUG, and it is the reason `core/tools/fps_smoke.gd` now exists: a
    STANDING tree had no collider at all.** Only the STUMP ever got one, and only once
    the tree was already down — a standing trunk never needed one, because nothing in
    the game could move. The player walked straight through the tree they were chopping.
    `TreeTrunk._build_standing_body()` puts one cylinder on the bare stem (TIMBER_LAYER,
    so splinters still pass through), freed in `detach_above` — it must not outlive the
    standing tree, or the fall would jam on an invisible pillar. **The acceptance suite
    could never have caught this**, because it runs the player as a puppet on purpose;
    hence a separate smoke tool that runs the game `player_controlled = true` and checks
    the things only a real CharacterBody3D can be wrong about (gravity, the trimesh
    ground, walking, being stopped by timber). 12/12. Run it after anything that touches
    the player or the collision layers.
  - **`cut_span` RE-MEASURED ON FOOT, and the plan's optimism was WRONG — see the note
    below the M5 passes.** `felling_spam.gd` grew a walk phase (plan §6) that fells the
    same tree standing still and walking round it, at four spans.
  - **New dev tool:** `core/tools/fps_smoke.gd/.tscn` — the player as a player.
    `godot --headless --path . --quit-after 60000 res://core/tools/fps_smoke.tscn`.
  - **Where to PLAY it:** `res://scenes/3d_action/tree_felling_harness.tscn` (F6), which
    now carries a crosshair and the first-person controls. `main.tscn` still instances
    the M4 chopping mini-game and was deliberately NOT rewired — that is the forest's
    entry flow and belongs with §3/§4, not with this pass.
  - Still NOT eyeball-verified by Sam: all of it. The click layer has never been
    headless-verifiable, and mouse look and walking least of all.
- **THE FOREST — `handoff/08_FPS_FOREST.md` §3, §4 AND §5 ARE BUILT (2026-07-26,
  Amendment 15). A STAND OF 25 YOU WALK THROUGH. Awaiting Creative Director sign-off.**
  Sam, after playing the single-tree FPS pass ("that works pretty well"): *"Now I want to
  see how it goes with more trees in a scene"*, plus the min-log-size fix below. Sam's
  three §0/§5 decisions, taken before any code: settled debris **consolidates to
  MultiMesh**; the stand is **~25 trees over ~50 m**; and **nothing regrows** — it is a
  finite stand you clear. 197 M5 acceptance checks (was 182) + a new
  `core/tools/forest_smoke.tscn` at 37/37, fps_smoke 14/14, felling_smoke 11/11,
  slicer 34/34 (was 17/17),
  M1 21/21, M3 16/16, M4 16/16.
  M2 is 22/23 — the pre-existing A1 finding, unrelated.
  - **THE PER-TREE STATE MOVED, and this was the item the plan called "the single most
    error-prone in it" (§3b).** `_sites`, `_site`, `_face_side`, `_face_dir`,
    `_last_stress`, `_last_thickness`, `_next_crack`, `_lean` and `_lean_tween` were bare
    variables on the game node — correct for exactly as long as there was one tree. They
    now live in **`scenes/3d_action/tree_cut_state.gd` (`TreeCutState`)**, one per trunk as
    `trunk.cut`, reached through `_cut()` (which returns the ACTIVE tree's, and is never
    null). Without it, chopping tree B inherits tree A's notch, its committed fall line and
    its crack progression, with no error anywhere — tree B would simply already have a
    notch facing a way nobody chose. `TreeTrunk` declares `cut`, `source_mesh` and `def`
    and never reads the latter two, documented as such.
    - **THE ONE PIECE THAT IS LIVE is the lean tween**, and it needed more than moving: a
      tween keeps writing while the player walks off and chops something else, so reading
      the active tree from inside the callback would tip the tree the player is now
      standing at. `_apply_lean` takes its trunk and fall direction **bound at the moment
      the tween is made**.
  - **VOXELS ARE BUILT LAZILY (§3a, "the whole ballgame").** `TreeTrunk.preview()` stands a
    tree up as its imported mesh + pick volume + collider and NO field; `build()` upgrades
    it in place on the first blow. Both go through the same `_measure()`, so a preview and
    a build agree on radius, band and crown base — otherwise the collider and pick volume
    would jump the instant a tree was first struck. **MEASURED: a 25-tree stand is up in
    ~1.18 s with exactly ONE tree voxelised**, asserted in forest_smoke (if it ever reads
    25, the design has been undone).
    - **EXCEPTION, and it is a rule not a special case: the tree the player starts next to
      is built at LOAD.** Deferring it only guarantees that the very first swing of the
      session pays the ~35 ms. It is also what keeps `trunk()` meaning something before
      anything has been struck — the whole acceptance suite and every shot tool ask.
  - **AIM PICKS WHICHEVER TREE THE RAY HIT (§3c).** `_aim` returns the trunk with the
    point; `_trunk_for_picker` maps the pick collider back to its tree (linear over the
    stand on purpose — once per click, tens of trees). `_decompose` and `_max_local_y` take
    their trunk explicitly rather than assuming the active one, because the crosshair can
    land on a tree that has never been touched.
  - **ONE TREE FALLS AT A TIME (§3d, the plan's own recommendation).** Blows elsewhere are
    refused while one is going over. `_felling`/`_falling`/`_hinge`/`_fallen`/`_logs` stay
    single-instance; making the fall re-entrant is a large job for very little.
  - **THE GROUND IS TILED (§4).** `forest_floor_a` is one ~16 m patch; the stand is 50 m
    across. `_tile_ground` duplicates the AUTHORED tile on its own measured footprint
    (`ground_tiles` = 3, capped by `forest_radius`), so Sam's scale and 5 mm lift stay the
    artist's decision, and `_fit_ground_collider` builds the trimesh off **every** tile.
    The box backstop is kept — it is what stops debris leaving the world. Verified by ray:
    every tree has ground under it, and the tiling reaches the stand's edge in all 8
    directions. `shadow_distance` (45 m) caps the sun, per §5.
  - **SEEDED SCATTER.** `_scatter_positions` is a rejection sample through a LOCAL
    `RandomNumberGenerator` off `forest_seed` — never the global `randi`, so the layout is
    identical every run and cannot be perturbed by anything else drawing a random number.
    Asserted: same seed, same stand. Bounded tries, and falling short of `tree_count` is
    warned rather than hidden. Per-tree yaw and size (`tree_size_variation`) are seeded the
    same way; size is baked into the MESH, as the lean already was, because a scaled NODE
    would put the voxel band in a scaled frame.
  - **A12: SETTLED DEBRIS IS BAKED, NOT DELETED** — Sam's call, and A12's own text
    anticipates it ("long-term piles may consolidate to MultiMesh"). `_consolidate` takes a
    settled splinter's transform into a `MultiMeshInstance3D` and frees the body, script and
    collider. **Keyed by MESH**, and since `_stick_mesh` shares three splinter sizes across
    the whole game, that is **three piles for a whole forest** however many trees come
    down — measured at 54 splinters in 1 pile. It used to DELETE the oldest settled piece,
    which with one tree was survivable and in a forest means the pile behind you disappears
    while you are at the third tree.
    - **TRAP, and it took three attempts: `MultiMesh.instance_count` REALLOCATES and wipes
      every transform in the buffer.** Reading `buffer`, resizing and writing it back is
      rejected by Godot for a size mismatch. Allocating capacity in blocks and tracking the
      filled count with `visible_instance_count` left every transform at IDENTITY. What works
      is keeping the transforms in a plain `Array` on this file and rewriting the whole
      MultiMesh each batch — O(pile) per batch, and a batch only happens when debris goes over
      `max_debris`.
    - **`MultiMesh.set_instance_transform` DOES NOT ROUND-TRIP UNDER THE HEADLESS RENDERER.**
      Verified in isolation: a fresh MultiMesh in a headless run reads every instance back as
      identity, because the storage lives in a RenderingServer that is stubbed out. So a
      headless check written against `get_instance_transform` can only ever fail, and two of
      the three attempts above were being diagnosed against a measurement that could not
      work. `debug_pile_transforms()` therefore reports the array this file holds — the data
      being fed in, which is where the bug actually was — and that the MultiMesh draws it is a
      RENDER check. File this next to "physics CPU is not trustworthy headless".
    - **`max_debris` is a SOFT cap and always was**, two ways: it only retires SETTLED
      pieces (so nothing vanishes out of the air), and it runs on SPAWN (so nothing prunes
      after the last blow). The true bound is `max_debris + splinter_burst_cap`, and that is
      what forest_smoke asserts — tightly, so a leak would show as growth.
  - **NOTHING REGROWS** (Sam's call). `auto_respawn` survives for the single-tree harness
    and the suite, and now replants the slot the felled tree left (`_cleared_at`) rather
    than re-scattering the stand. `_clear_board` takes the felled tree and its wreckage and
    **nothing else** — the rest of the forest is still standing and the player may be
    looking straight at it.
  - **THE BIG FIND OF THIS PASS: `MeshUtils.plane_to_local` HAS ALWAYS ROTATED THE NORMAL
    THE WRONG WAY, and only a rotated node could ever show it.** A plane's normal transforms
    by the TRANSPOSE OF THE FORWARD basis — for `p_world = B * p_local + t`, substituting into
    `n . p = d` gives `n_local = B^T n_world`. The code read `inv.basis.transposed()`, which
    for a rotation R evaluates to **R, not R^T**: the rotation applied backwards. Identical to
    correct for any translation-only transform, which is every transform it had ever been
    handed — the slicer's mesh children sit at offsets, and every tree in M5 stood unrotated
    at the world origin.
    - **The stand gave each tree a random yaw and it broke chopping outright.** At 310 degrees
      the blow's cut planes came out ~98 degrees off, the convex solid the axe displaces
      missed the trunk completely, and **not one voxel was ever removed** — while the cut
      site's `depth` counter climbed anyway, because `_cut_slab` adds the bite whether or not
      the carve found wood. A yawed tree therefore reported a notch going 16% -> 24% -> 32%
      -> 71% deep, with the trunk untouched, and never fell however long it was chopped.
    - Fixed to `xform.basis.transposed()`. Guarded by 10 new checks in
      `core/tools/test_slicer.gd` (**now 27/27**) which assert, at five yaws including 310.8,
      that a point on the world plane lands on the local plane and that SIDEDNESS is
      preserved — the thing a convex carve actually depends on. Same lesson as the winding
      convention: verify the maths against the engine, not against the one case where it
      cannot be wrong.
    - **IT WAS NEVER M5-ONLY. `chopping_minigame.gd` calls it too** (via its own
      `_plane_to_local` wrapper), and M4 ROTATES pieces to their long axis before cutting
      them — so every slice of a turned piece of firewood has been cutting on a plane rotated
      the wrong way round since M4 shipped. M4's 16 checks never caught it because they assert
      piece EXTENTS and volumes, and a wrongly-oriented cut through a roughly-square billet
      still produces two plausible halves. Re-verified at 16/16 after the fix.
  - **A second, smaller one alongside it: `axis_xz` is the trunk's centre line in the TREE's
    own space, and three call sites added it to `global_position` without rotating it.** Also
    harmless while every tree stood at the origin unrotated. `_trunk_centre` had always done
    it correctly; `_impact_point`, `_decompose` and `debug_stand_at_tree` had not. New
    `TreeTrunk.axis_point(local_y)` is now the only way to ask where a trunk is.
  - **BOTH WERE FOUND BY RENDERING, and no existing check could have found either.** Shot 5
    and shot 6 of `forest_shot` — before and after eight blows — came out pixel-identical.
    forest_smoke was green the whole time, because every assertion was about cut COUNT and cut
    DEPTH, which are bookkeeping. Worse, the check added to catch it (`holding_area() <
    full_area()`) ALSO passed vacuously, because `full_area` is the median section and
    `holding_area` the minimum, and tree_01 tapers 3% — so an untouched tree satisfies it.
    The guard that actually works measures the wood volume before and after
    (`WoodVolume.volume()`).
  - **THREE VACUOUS TESTS CAUGHT AND FIXED, all mine, all the same shape: a check that
    passes because it measured nothing.** The coin check read log lengths AFTER bucking had
    cleared the board (empty list, `INF >= 0.45`, green). The debris check ran at the
    shipping `max_debris` of 120, which a few blows never reach, so consolidation never ran
    (0 baked into 0 piles, asserted "<= 4", green). And the first debris attempt chopped ONE
    tree hard, which fells it — and a felling fades the clearing and takes its splinters,
    so it measured a board that had just been swept. **Assert a positive quantity, not just
    a bound.**
  - **Still NOT eyeball-verified by Sam.** Render-verified (`core/tools/forest_shot.tscn`):
    the stand at eye level, across, and from above; the tiled ground with no visible seam;
    a trunk close up; and a notch cut in a forest.
  - **ART OBSERVATION, not a bug: `tree_01.fbx` has no crown or foliage** — it is a bare
    trunk with branch stubs and a flat sawn top. With one tree that read as a placeholder;
    with 25 it reads as a clear-cut of poles rather than a forest. The random yaw does buy
    real variety, because the source trunk has a slight lean of its own. Sam's call.
  - New dev tools: `core/tools/forest_smoke.gd/.tscn` (the stand as a stand — identity,
    spacing, the seed, lazy build, ground coverage, debris piles) and
    `core/tools/forest_shot.gd/.tscn` (render the forest).
- **THE STUMP REMAINS AND THE LOGS FLY TO THE PLAYER (2026-07-27).** Creative Director's
  direction: *"After the tree has been cut in to logs, I want the stump to remain - the logs can
  fly towards the character (in a similar way to the log chopping game) and then be added to
  their inventory."* 197 M5 acceptance checks (was 189). No contract touched; every number is an
  `@export` placeholder per Directive 3.
  - **`stumps_persist` (on).** `_clear_board` used to fade the whole `TreeTrunk`, stump included.
    A broken trunk is now kept and moved onto `_stumps` instead — with the collider
    `_build_standing_body` handed over at the break, so a stump is something you walk INTO. It is
    what makes a cleared stand read as cleared, which matters now that nothing regrows. Only on
    a FADE: the R key means a fresh board and takes the stumps with it (`_clear_stumps`).
  - **NEW `scenes/3d_action/log_flight.gd` (`LogFlight`).** Same idea as M4's `wood_pile.gd` — a
    physics body is baked to a frozen proxy at its resting transform and script-animated,
    staggered so a batch cascades — but the destination is a MOVING PLAYER, so none of the pile's
    deterministic slot packing applies and it is its own small helper. Scripted, not physics, for
    `piece_animator`'s reason: a thrown rigid body goes where the solver sends it and a
    collectible has to ARRIVE. **The target is re-read every frame**, because the player walks
    and a log launched at where they used to be would sail past them. Real-time clock
    (`Time.get_ticks_msec`) like the pile and the animator, so an A11 hit-pause cannot corrupt a
    collect in progress.
  - **THE YIELD IS SETTLED AT LAUNCH; ONLY THE EMISSION IS DEFERRED.** `_release_timber()` works
    out everything still owed on the tree, deals it across the flying logs one unit each with any
    remainder on the last, and marks the tree paid — then each log emits its own units as it
    lands. So **what flies is a receipt, not a promise**: nothing in the air can be disturbed by
    a second tree being felled, the player walking out of the forest, or the board being wiped
    with R. The PASS 2 invariant is exactly as strong as it was — a tree is worth its authored
    `TreeDef.yields` however it was cut up — and a half-bucked trunk whose three lengths fly
    still pays for the whole tree.
  - Both paths that give a trunk up go through it: bucked out (`_end_bucking`) and superseded by
    a new felling (`_finalise_felled_timber`). `_end_bucking` still runs the ordinary fade
    afterwards, because that is what moves the stump onto `_stumps`, tidies `_trees` and resets
    the fall state — already tested, and `_collect_yields` no-ops once the flight has settled.
  - **`logs_fly_to_player` is pinned OFF in `m5_acceptance._make_game`**, and `_test_17` turns it
    on. Not laziness: the flight defers the emission by its travel time, and most checks in that
    suite read the inventory the moment they see a tree collect — six of them went red on a
    correct game until the pin went in. Same pattern as `trunk_persists`.
  - **A TEST-PLACEMENT LESSON, and the second time this exact shape has bitten in two days:** the
    first version of these checks was appended INSIDE forest_smoke's existing felling block,
    which had already bucked that trunk out — so it measured a half-consumed tree and reported
    "1 of 4" yield and "0 stumps". A whole-lifecycle check needs its OWN game. It lives in
    m5_acceptance (`_test_17`), because stumps and log flight are not forest-specific.
- **FIXED 2026-07-27 (second round), both reported by Sam from screenshots of the live game:**
  - **NOTHING REGROWS — and it shipped doing the opposite.** Sam: *"the trees respawn instantly
    after they despawn."* Sam's own §0 decision was a finite stand you clear, it was written up
    in Amendment 15, and `auto_respawn` was left DEFAULTING TO TRUE — so a felled trunk faded
    and another tree popped straight into its slot, and the stand could never be cleared at all.
    **The decision was recorded and the default was never changed to match it.** Now `false`;
    `felling_smoke` and `felling_spam` (which need a fresh tree per round) and
    `m5_acceptance._test_7` set it themselves. forest_smoke asserts the stand gets one tree
    SMALLER and that nothing has grown back in the slot.
  - **FLOATING CHIPS OF WOOD, and it was the MultiMesh baking doing it.** `is_settled()` goes
    true the instant a piece is retired, which is BEFORE `fragment_piece`'s confirm loop has
    finished checking that whatever it came to rest on is still there. Baking is PERMANENT — it
    reads the transform once and frees the body — so it froze exactly the poses that loop exists
    to correct, most obviously a splinter retired while bedded INTO the falling trunk: it cannot
    move down, reports itself perfectly settled, and is left hanging once the trunk rotates
    away. **Invisible while the cap DELETED the oldest settled piece**, which is what it did
    before Amendment 15. New `fragment_piece.is_at_rest()` (settled AND out of confirms) is what
    `_retire_old_debris` now bakes on.
    - **AND WAITING FOR IT BROKE THE CAP, which the tests caught immediately.** The confirm
      window is 8 x 0.75 s = SIX SECONDS, which a player chopping hard fills many times over —
      debris went to 157 bodies against a 24 bound. `_retire_old_debris` is now two passes:
      properly at-rest pieces first, then, still over cap, the OLDEST SETTLED ones via
      `fragment_piece.force_at_rest()`, which **sweeps one last time** before giving up the
      watch. So a piece whose support has already gone is still put down; what a forced piece
      trades away is noticing a support that leaves LATER. Bound is tight again at exactly
      `max_debris + splinter_burst_cap`.
  - **CUT LOG TEXTURES WERE WRONG, and the mapping only ever worked BY ACCIDENT.** Sam: *"when
    the logs are cut the textures are all wrong."* `MeshSlicer._build_caps` UV'd a cut face as
    the offset from its centroid **in metres** — so it lands inside 0..1 only when the piece is
    about a metre across. tree_01's ~0.5 m radius made that true by luck; `tree_size_variation`
    then took trunks to 0.61 m, the UVs ran off the disc, and since `_cut_mat` is a SINGLE
    growth-ring round on a WHITE field with `texture_repeat` off, the overshoot clamped to
    white. Measured before/after: `u -0.14..1.03` -> `u 0.07..0.86`.
    - New `cap_fit_round` argument fits the round to the cut face's OWN measured extent, rather
      than to a radius handed in — because a cut that catches the crown takes the branches with
      it and that cross-section reaches far past the trunk. M5's bucking and the crown clip pass
      it; **M4 keeps the metres mapping, which is correct for its TILING cut material** and is
      asserted as such.
    - Guarded by 8 new checks in `core/tools/test_slicer.gd` (**now 34/34**): a fitted cap's UVs
      stay inside the round at radius 0.15, 0.5 and 1.4 AND fill it, and the default mapping is
      still in metres. **Nothing measured cap UVs before this** — which is why a mapping that
      only worked at one size survived from M4.
- **FIXED 2026-07-27, both reported by Sam after playing the stand:**
  - **FELLING ONE TREE KILLED THE AXE FOR THE WHOLE SESSION.** Sam: *"when you cut / fell one
    tree, you can no longer cut any of the others."* `_felling` means "a tree is going over
    right now" and it was only ever cleared by SPAWNING A FRESH BOARD — correct while the board
    always replaced its one tree, and dead wrong in a stand where nothing regrows and a felled
    trunk PERSISTS: the flag stayed set for the rest of the session, and `_on_click` refuses
    every blow while it is. It is now cleared where it should always have been — the moment the
    fall is over (`_watch_fallen`'s settle) — and the rest of the per-fall state moved out of
    `_spawn_stand` into `_reset_fall_state()`.
    - **NOTHING COVERED IT, and that is the interesting part.** Every forest_smoke check chopped
      without felling; m5_acceptance fells constantly but with `tree_count = 1` and
      `auto_respawn`, so a fresh board always came along and cleared the flag. **It took a
      stand AND a felling AND no respawn together**, and no suite combined all three.
      forest_smoke now does: fell a tree, assert the axe is free, then chop a different tree
      and assert the blow removes real wood. 34/34.
    - CONSEQUENCE, and it is the honest limit rather than a decision: **only ONE felled trunk
      is tracked at a time**, because the bucking state (which length, how many logs paid) is
      single-instance. Felling a second tree finalises the first — `_finalise_felled_timber()`
      books its remaining yields and clears it, so the yield invariant holds. A felled trunk
      therefore persists until you fell another, not for ever. Making several independently
      buckable means moving the buck state onto the trunk exactly as `TreeCutState` moved the
      cut state — the same shape of job as plan §3b, and not a small one.
    - `has_collected()` is now backed by a monotonic `_collect_count`, because a flag set and
      cleared inside one frame cannot be observed by a test polling between frames.
  - **LOGS WERE FAR TOO SHORT, and `buck_min_length` was the wrong KIND of knob.** Sam: *"the
    log sizes are soo small. It should be roughly 5 logs per tree."* The 0.45 m value was
    measured off the M4 chopping-block round — which is a piece of FIREWOOD, not a bucked
    length off a felled trunk. New **`buck_target_logs` (5)** is the knob, and the minimum log
    is derived per tree as `_fallen_length / buck_target_logs` (floored at `buck_min_length`,
    now 0.6 as a sapling backstop). Derived rather than a metre value because
    `tree_size_variation` makes the trees different sizes — a fixed number would give five logs
    from one tree and three from its neighbour. **The count needs no tracking**: a trunk `L`
    long whose minimum piece is `L/n` cannot come apart into more than `n`. Measured: tree_01
    now bucks into 4-5 lengths of 1.4-1.8 m against the old 0.45 m coins.
    - **OPEN, and it is Sam's data: `pine_tree.tres` yields 4 `pine_log` while
      `buck_target_logs` is 5**, so the fifth log books nothing (`_pay_for_log` caps at the
      authored amount). The yield invariant is intact and deliberate — a tree is worth what it
      is authored to be worth however it is cut up — but the two numbers now visibly disagree
      and Sam may want them aligned. TreeDef field values are Sam's per A8/Directive 3.
- **BUCKED LENGTHS ARE LOGS, NEVER COINS (2026-07-26).** Sam: *"when a player chops a
  felled tree in to logs, it should only ever split in to logs roughly the size of the ones
  we chop in the game, so there is a min log size (right now you can cut tiny disks and
  that's just not accurate)."* `buck_min_length` already existed **and was tested against
  the length going IN, never against the two coming OUT** — so any section over the minimum
  could be cut a centimetre from its end. The floor is now on the RESULT: `_is_cuttable`
  needs two minimums to cut at all, and `_buck_cut_at` CLAMPS a cut aimed nearer than one
  minimum to an end (clamped, not refused — matching M4's own `min_piece_size` snap, because
  a click that does nothing reads as broken). Routed through those two helpers everywhere,
  including `debug_buck`, `_bucked_out` and `debug_next_bucking_log` — that last one matters,
  because a "worth cutting" test that disagreed with the cut rule would leave a persisting
  trunk that never clears. **`buck_min_length` retuned 0.7 -> 0.45, MEASURED not picked**:
  `log_01.fbx` imports at 0.033 m and `chopping_minigame.log_scale` is 13.0, so the firewood
  the player splits on the block is ~0.43 m — the old 0.7 was longer than the log it was
  meant to produce. Placeholder per Directive 3. New `_test_16` asserts no cut ever leaves
  anything under the minimum (shortest measured: exactly 0.45 m, the clamp working).
- **`cut_span` 0.50 CANNOT FELL tree_01, and walking does not rescue it (measured
  2026-07-26).** `handoff/08_FPS_FOREST.md` §2 reasoned that an FPS player can walk
  round the trunk so PASS 5's "cannot be felled from one viewpoint" no longer applies,
  and that Sam's live 0.50 "may become perfectly playable". **It does not.**
  `felling_spam.gd`'s walk phase, tree_01 (0.94 m across), pinned settings:
  `1.60 m` 11 blows standing / 23 walking · `0.80 m` 13 / 22 · **`0.50 m` NEVER FELL /
  NEVER FELL** · **`0.35 m` NEVER FELL / NEVER FELL** (150 blows each, cut reporting 100%
  of the diameter). The cause is geometry, not viewpoint: a 0.5 m channel cut from every
  side hollows the middle out and leaves a SHELL, and a shell of that section still
  carries the tree. Walking costs MORE blows at every span, because a cut on a new face
  is a new cut rather than a deeper one — `cut_face_arc_deg` working as intended.
  `_warn_cut_span()` now says exactly this. **Sam's live `tree_felling.tscn` still has
  `cut_span = 0.50`, so the shipping scene currently cannot fell its own tree** — it
  wants raising to 0.80+ or the trunk narrowing. Sam's number to set (Directive 3).
- **M6 (ore mining) is next** — spec in `handoff/04_M6_ORE_MINING.md`. It keeps
  A2's authored fracture (Amendment 10 covers trees only). Do not start without
  explicit go-ahead.
- **OPEN A1 FINDING (2026-07-23, not M5's doing, not fixed):**
  `Action_Viewport.size` is authored 1280×720 in `main.tscn` but is **960×540 at
  runtime** — `SubViewportContainer.stretch = true` resizes the child viewport
  to the container's rect, and the container follows the project's 960×540 base
  canvas (`display/window/size/viewport_*`). So Amendment 8's "render at 1:1,
  no upscale" is not actually happening: the game still renders 960×540 and the
  canvas_items stretch scales it to the 1280×720 window. This is very likely the
  "still kinda pixelated" Sam reported during Amendment 8, and it is why
  `m2_acceptance` fails its one A1 size check (22/23 — every other M2 check
  passes). It was NOT previously diagnosed; the earlier session blamed live
  editing of the scene. Fixing it means either raising the project base canvas
  to 1280×720 (a `project.godot` edit — CLOBBER TRAP, walk Sam through the
  Settings UI) or dropping container stretch and sizing the viewport in code.
  Sam's call; it touches A1, so it needs an amendment either way.
- Sam is authoring M4/M5 art in Maya in parallel (see ASSET PIPELINE below).

## OPERATIONAL RULES (summary of blueprint directives)

1. One module at a time (M1→M8), explicit Creative Director sign-off between
   modules. Never start the next module unprompted.
2. **Part A contracts are frozen.** Never add, rename, or retype anything in
   them. If a module genuinely needs a contract change: halt, propose it,
   wait for approval, update this file's amendment log, then resume.
3. Any artistic/mathematical tuning value (forces, timings, stage counts,
   shake amounts) → halt and ask for exact values. Never invent finals;
   placeholders live in `.tres` files, never hardcoded.
4. Verify any uncertain API exists in Godot 4.7 Compatibility before using it.
   Banned outright: real DOF (CameraAttributes), volumetric fog, SDFGI,
   DirectionalLight projectors, runtime mesh booleans/CSG on gameplay
   geometry, runtime volume computation.
5. Every script states its exact `res://` path and the node type it attaches
   to. Every scene states its full node tree.
6. Writes to inventory happen ONLY inside InventoryManager; writes to
   progression ONLY inside GameState (via EventBus signals or their own
   public methods). Everything else queries read-only.

## FROZEN CONTRACTS — QUICK REFERENCE

(Full text is the Master Blueprint; this is the operative summary. If the
blueprint document is in the repo, it wins on any discrepancy.)

- **A1 pipeline:** SubViewport 1280×720 (amended from 960×540, Amendment 8,
  2026-07-22 — matches window resolution 1:1, no upscale factor),
  SubViewportContainer stretch=true + NEAREST filter (briefly tried LINEAR in
  Amendment 8, reverted same day — at 1:1 scale there's no mismatch for NEAREST
  to pixelate, and LINEAR's interpolation read as a soft "bloom" next to bright
  highlights). `Action_Viewport.msaa_3d = 4x` (per-viewport override, NOT the
  project-wide MSAA setting which stays off — smooths jagged geometry edges
  without blurring; verified supported under Compatibility since Godot 4.3).
  `anisotropic_filtering_level = 3` on `Action_Viewport` (sharpens ground
  texture at grazing angles). `scaling_3d_mode` left at default Bilinear —
  FSR/FSR2 are NOT supported under the Compatibility renderer, verified via
  Godot docs; do not set it to FSR(1)/FSR2(2). Project stretch canvas_items/
  keep, no screen-space AA. Fake DOF = pre-blurred background texture/plane.
  Sun gobo = SpotLight3D with animated `light_projector` angled as sun proxy.
  Stop-motion feel = AnimationPlayer with discrete/stepped keyframes only (unaffected by
  Amendment 8 — that's animation cadence, not render resolution).
- **A2 destructibles:** pre-authored fracture states only. Trees: 4 quadrants
  × N cut depths (default 3), mesh swap + `structural_integrity` decrement.
- **A3 size rule:** the ONLY size test anywhere is
  `piece.size_tier > GameFeelConfig.size_threshold`.
- **A4 folders:** `res://core/`, `res://data/`, `res://scenes/2d_management/`,
  `res://scenes/3d_action/`, `res://assets/`.
- **A6 enums** (in `res://core/enums.gd`, class_name `Enums`):
  `ChopDirection{LEFT,RIGHT,UP,DOWN}`,
  `ItemCategory{RAW_WOOD,MINERAL,GEM,REFINED}`, `ToolType{AXE,PICKAXE}`,
  `Biome{PINE_FOREST,MAHOGANY_FOREST,MOSSY_QUARRY,VOLCANIC_CAVERN}`.
- **A7 EventBus signals (exact, frozen):** `resource_gathered(StringName,int)`,
  `building_upgraded(StringName,int)`, `environment_unlocked(Enums.Biome)`,
  `action_hit_registered(Vector3,int,Enums.ChopDirection)`,
  `gear_upgraded(Enums.ToolType,int)`, `minigame_entered(Enums.Biome)`,
  `minigame_exited()`. Unregistered `resource_id`s are errored and ignored by
  InventoryManager.
- **A9 root hierarchy:** `Main(Node)` → `UI_Canvas(CanvasLayer,layer 0)` →
  `SubViewportContainer` → `Action_Viewport(SubViewport 1280×720)` →
  `3D_World_Root(Node3D)`; sibling `UI_Overlay(CanvasLayer,layer 2)` for ALL
  gameplay UI. Never put gameplay UI inside UI_Canvas.
- **A10:** in 2D mode: `Action_Viewport.render_target_update_mode =
  UPDATE_DISABLED` and `3D_World_Root.process_mode = PROCESS_MODE_DISABLED`.
  Restore on `minigame_entered`.
- **A11 hit-pause:** `Engine.time_scale = 0.05`, restore via
  `get_tree().create_timer(duration, true, false, true)` (ignore_time_scale
  = true). Guard overlapping pauses (counter/single owner) so time_scale
  never sticks low. All 2D production Timers set `ignore_time_scale = true`.
- **A12 physics:** freeze settled fragments (freeze=true, STATIC) on sleep or
  settle timeout; hard cap 24 active rigid bodies per mini-game (oldest
  settled freeze first); long-term piles may consolidate to MultiMesh.

## APPROVED AMENDMENT LOG (Creative Director signed off in chat)

1. **FragmentDef gains `sub_fragments: Array[FragmentDef]`** (recursive).
   Empty = leaf (collectible; `yield_item`/`yield_amount` read only then).
   Non-empty = re-choppable; a successful hit swaps the piece for its
   sub_fragments. Chain depth per species = hit count (size-based
   difficulty). Splits start 2-way; multi-way later is data-only.
2. **InventoryManager exposes local signal
   `inventory_changed(item_id: StringName, new_count: int)`** — fires on
   every count change including consumption, so M7 UI updates live without
   polling. Local signal, NOT added to EventBus (does not cross the 2D/3D
   boundary; A7 untouched).
3. **Non-increasing tier "upgrades" are warned and ignored** by GameState
   (gear and buildings). Revisit only if intentional downgrades become a
   design feature.
4. **Cost lists aggregate duplicate ids before affordability checks**
   (prevents partial-consume exploits). `remove_items` is atomic: all or
   nothing.
6. **Runtime mesh slicing permitted for the M4 firewood chopping mini-game**
   (Path B, Creative Director choice). An explicit exception to Directive 4's
   ban on runtime mesh booleans/CSG AND to A2's "pre-authored fracture states
   only" — SCOPED TO M4 ONLY. Trees (M5) and ore (M6) keep pre-authored
   fracture under A2 unless separately amended. The slicer plane-cuts the log
   along a camera-inferred angle on each click and caps the cut face; sliver
   cuts are rounded up to a minimum piece size. **A3 is unchanged** — a
   runtime-sliced piece gets its `size_tier` COMPUTED (quantized from measured
   dimensions) at slice time instead of authored, and the sole size test
   everywhere remains `piece.size_tier > GameFeelConfig.size_threshold`.
   Consequence: the authored pine chain (`pine_chain.tres`, `build_pine_chain
   .gd`) is retired from M4 (FragmentDef itself stays, used by M5/M6). The
   reusable M4 pieces (fragment_piece, fragment_physics_budget, collect->
   inventory flow, GameFeel wiring, scene shell) are kept.
5. **GameFeel added as the 4th autoload** (`res://core/game_feel.gd`,
   registered after GameState, before the godot_mcp services). Rationale:
   A11 hit-pause is process-wide `Engine.time_scale` state that needs a
   single owner for the overlap guard, and M4–M6 all consume it. EventBus /
   A7 untouched — `register_impact()` is a public method, not a signal;
   GameFeel only *listens* to existing A7 signals
   (`action_hit_registered`, `minigame_exited`). Autoload order is now
   EventBus, InventoryManager, GameState, GameFeel, then the MCP services.
7. **A1 pipeline viewport increased from 640×360 to 960×540** (Creative Director
   call, 2026-07-22). NEAREST filter and stretch mode unchanged; only the
   internal render resolution increased by 50% to reduce pixelation. Window
   render scale remains at 1280×720 (2×).
8. **A1 pipeline dropped the pixel-art render entirely** (Creative Director
   call, 2026-07-22 — "the pixelated look isnt feeling right"). `Action_Viewport`
   raised 960×540 → 1280×720 (now matches the window 1:1, no upscale factor at
   all). Filter was briefly changed NEAREST → LINEAR same day, but Sam then
   reported a slight "bloom" on everything in the mini-game — LINEAR's
   interpolation softening edges next to bright sunlit highlights — so it was
   reverted to NEAREST (which stays crisp with zero blur now that render size
   == display size 1:1; the old blockiness only happened because the *old*
   960×540 render was being upscaled). Net Amendment 8 result: 1280×720 +
   NEAREST. Changed in `main.tscn`, `chopping_minigame_harness.tscn`, and
   `m2_acceptance.gd`'s A1 assertions. Project's base design canvas
   (`display/window/size/viewport_width/height`, 960×540, used for 2D UI
   stretch layout) is UNCHANGED — this amendment is scoped to the 3D
   Action_Viewport only. Fake DOF / stop-motion keyframe feel (A1's other
   clauses) are unaffected.
   - **Follow-up same day:** Sam reported the full-res render still looked
     "kinda pixelated" — actually two separate issues. (1) `Action_Viewport`
     had reverted to 960×540 mid-session (Sam was live-editing the SubViewport
     inspector in the open Godot editor; confirmed by re-reading `main.tscn`
     mid-turn and watching the value change twice) — re-set to 1280×720.
     (2) Sam's live editing had also set `scaling_3d_mode = 1` (FSR) and
     `msaa_3d = 1` directly on `Action_Viewport` — verified via Godot docs
     that FSR/FSR2 upscaling is NOT supported under the Compatibility
     renderer (only Bilinear + Nearest are), so `scaling_3d_mode` was reset to
     default Bilinear. `msaa_3d` IS supported under Compatibility (since
     Godot 4.3) and is the correct fix for jagged geometry edges (visible on
     the horizon/roofline in Sam's screenshot) without introducing blur —
     kept as a per-viewport override at 4x (`Viewport.MSAA_4X`), same on both
     `main.tscn` and `chopping_minigame_harness.tscn`. Also kept
     `anisotropic_filtering_level = 3` (Sam's addition, sharpens the ground
     texture at grazing angles — legitimate and renderer-agnostic).
     `m2_acceptance.gd`'s A1 checks updated: project-wide MSAA default stays
     asserted OFF (unchanged), with new checks that `Action_Viewport.msaa_3d`
     is 4x and `anisotropic_filtering_level` is 3.
9. **A1's sun-gobo clause replaced, scoped to the M4 chopping mini-game scene**
   (Creative Director call, 2026-07-22 — Sam supplied
   `images/lightmaps/leaves_gobo_tilable.jpg` and asked for it wired up).
   `handoff/00_OVERVIEW.md` had flagged this exact swap ("replacing
   SpotLight3D `light_projector` with animated shadow-casting cutout
   geometry is an A1 amendment — propose to Sam first") since the M2
   renderer-trap finding that `light_projector` does not visibly render
   under gl_compatibility; Sam raising it with the asset in hand counts as
   that go-ahead. Implementation: new `CanopyGobo` (MeshInstance3D,
   `res://scenes/3d_action/canopy_gobo.gd`) in `chopping_minigame.tscn` — a
   `QuadMesh` hung above the scene with `cast_shadow =
   SHADOW_CASTING_SETTING_SHADOWS_ONLY` (invisible itself, shadow only) and a
   custom `ShaderMaterial` (`res://assets/shaders/canopy_gobo.gdshader`,
   the project's first hand-written shader) that alpha-scissors the leaf
   texture's inverse luminance — bright gaps in the source photo become
   transparent, dark leaf/branch silhouette becomes the opaque occluder, so
   the sibling `DirectionalLight3D` (now `shadow_enabled = true`, was false)
   casts a real dappled-leaf shadow onto the ground. Sway is a discrete
   UV-offset random walk driven by an `AnimationPlayer` with
   `Animation.UPDATE_DISCRETE` (A1's stop-motion/stepped-keyframe rule, not a
   smooth scroll). Texture copied to
   `res://assets/textures/leaves_gobo_tilable.jpg` (same
   convert/copy-in pattern as `background_blurred.jpg`). All of `canopy_gobo.gd`'s
   tuning values (`canopy_size`, `canopy_height`, `tile_scale`,
   `alpha_scissor_threshold`, `sway_amount`, `sway_step_sec`,
   `sway_positions`) are PLACEHOLDERS per Directive 3 — picked to be
   reasonable, not final; tune live with Sam in F6.
   **Not yet eyeball-verified** — alpha-scissor cutout shadows are a basic,
   long-supported Compatibility-renderer technique (unlike the banned
   DOF/SDFGI/volumetrics/projector features), but per this project's own
   precedent (the original gobo failure was only caught by Sam's F5/F6
   eyeball test, not headless), this needs a live look before it counts as
   confirmed working. Scoped to the M4 chopping-minigame scene only — A1's
   language elsewhere and the placeholder/M2 scenes are untouched.
   - **Follow-up same day:** Sam reported the sway "so so steppy" after
     seeing it live. The discrete `Animation.UPDATE_DISCRETE` track (an
     intentional nod to A1's stop-motion/stepped-keyframe rule) was snapping
     instantly between UV-offset waypoints every `sway_step_sec`, which read
     as a jarring pop rather than a stepped-animation feel. Changed to a
     continuously-interpolated track (`Animation.INTERPOLATION_CUBIC`) so the
     gobo drifts smoothly between the same random waypoints instead —
     a further deliberate, scoped exception to A1's stepped-keyframe clause
     for this one effect, same rationale as the light_projector swap itself.
     `canopy_gobo.gd`'s `_build_sway_animation()` updated; no other files
     touched. Still a placeholder — `sway_amount`/`sway_step_sec`/
     `sway_positions` tune the drift distance/speed/loop length live in F6.

10. **Runtime mesh slicing extended to M5 tree felling** (Creative Director
    direction, 2026-07-23: *"we can use the same cutting feel as the
    chopping_minigame, but convert it in to a tree felling game. The player
    makes horizontal cuts to the tree - trying to make a wedge so that it can
    fall over"*). This SUPERSEDES **A2's "pre-authored fracture states only …
    Trees: 4 quadrants × N cut depths, mesh swap"** for trees, and widens
    Amendment 6's slicing exception from "M4 ONLY" to **M4 + M5**. Ore (M6)
    keeps A2's authored fracture unless separately amended.
    Consequences, all deliberate:
    - `TreeDef.quadrant_stage_meshes` is now UNUSED (left empty in
      `pine_tree.tres`). **TreeDef itself is untouched** — still frozen, still
      the home of `biome` / `hardness_level` / `integrity_per_cut` / `yields`,
      which all drive M5. No field was added, renamed or retyped; the M5-only
      tuning that has no home in TreeDef lives as `@export` on
      `tree_felling.gd`, exactly as M4's does on `chopping_minigame.gd`.
    - `structural_integrity` survives as a data-driven budget and a fell
      condition, but the DEFAULT fell condition is geometric (the wedge). A2's
      12-cut shape (4 × 3) informed the placeholder numbers.
    - A3 is unchanged: a felled trunk's `size_tier` is COMPUTED at runtime
      (Amendment 6's quantisation rule), and the only size test anywhere is
      still `size_tier > GameFeelConfig.size_threshold`.
    - A7 is untouched — M5 adds no signals and emits only
      `action_hit_registered` and `resource_gathered`.
    - Directive 4's ban on runtime mesh booleans/CSG stands everywhere else.

11. **The M5 tree fall is a real physics simulation, and trees have no hit
    points** (Creative Director direction, 2026-07-23: *"I still want this to
    feel somewhat realistic, I dont know if that sudo health system works in our
    favor, we want the tree to follow physics when it falls"*). Two changes,
    both scoped to M5:
    - **SUPERSEDES the M5 handoff's** *"the fall is NOT physics simulation of a
      tree mesh hierarchy … Do NOT use a physics joint for the fall itself"*.
      The part above the break becomes a `RigidBody3D` with a cylinder collider,
      is spun toward the notch, and is then simply simulated — it topples off
      the stump, lands and settles under Jolt. The scripted-hinge implementation
      (`tree_faller.gd`) is DELETED. Directive 4's ban is on runtime mesh
      booleans/CSG and on the banned RENDERER features; it never covered rigid
      bodies, and A12 still governs how many are active (the trunk is one body
      and is deliberately not budget-tracked — `FragmentPhysicsBudget`
      force-settles the oldest over cap, which is `fragment_piece`'s contract;
      the chips it does track are the burst that matters).
    - **The `structural_integrity` budget is removed from M5 entirely.** The
      fell condition is purely the wood left at the worst cut
      (`min_thickness`), and the tree leans further as that thins. Consequently
      `TreeDef.integrity_per_cut` is now unused for trees, exactly as
      `quadrant_stage_meshes` already is. **TreeDef is still untouched** — no
      field added, renamed or retyped; `biome`, `hardness_level` (the gear gate)
      and `yields` still drive M5. If ore (M6) wants an integrity budget it is
      still there for it.
    A3, A7 and A12 are all unaffected.

12. **M5 fell condition is a measured LOAD MODEL, and the break is a torn-fibre
    tear** (Creative Director approved 2026-07-24: *"lets do both"* to the
    proposed pair, *"yep thats good"* to load-based early failure, *"notch
    only"* for fall direction, *"ship every number"*). Supersedes Amendment 11's
    "once that neck is under min_thickness the hinge tears" as the SOLE fell
    condition: the neck now fails when `stress = crush + bend >= fail_stress`,
    computed per cut from measured mesh volume/centroid/cross-sections;
    `min_thickness` remains only as a backstop floor. The break additionally
    shatters a collar of real trunk wood into splinters (some standing on the
    stump, the rest thrown as A12-tracked chips) and tears both break faces.
    Contracts untouched: no TreeDef fields (strengths and all tear/crack tuning
    are `@export` placeholders on `tree_felling.gd` per Directive 3), no new
    signals (cracks use GameFeel.register_impact + local audio), fall direction
    still the notch (volume-weighted cut directions), A3/A7/A12 unaffected. The
    only non-trunk mesh introduced is the crack debris splinter (a thin stick of
    cut-face material) — deliberate: cracks open fibres without removing wood.

13. **M5's wood becomes a VOXEL VOLUME, and a tree is felled by the manual's
    method** (Creative Director direction, 2026-07-24: *"I think it might be
    worth checking out a new (possibly voxel based) approach to the chopping. The
    game generally feels very bad. I want this game to feel visceral ... Borrow
    what you can, the game play of single clicks is good, its just the simulation
    and how the tree is felled / simulated that I dont like"*, with the USDA
    Forest Service ax manual "An Ax to Grind" supplied as the reference). Scoped
    to M5. Three parts:
    - **The geometry.** The bottom `band_height` of a trunk is a signed-distance
      VOXEL field (`res://scenes/3d_action/wood_volume.gd`), re-surfaced with
      surface nets after every blow; a blow subtracts the convex solid the axe
      displaces. This REPLACES Amendment 10's use of the runtime plane-slicer for
      M5's carving — the slicer now only clips the crown off at the band top, and
      Amendment 10's exception is otherwise moot for trees. It is not a new
      exception to Directive 4: Directive 4 bans runtime mesh booleans/CSG and
      the banned RENDERER features, and Amendment 6 already opened runtime
      geometry for the chopping games; this is a better implementation of the
      same permission, not a wider one. M4 and M6 are untouched — M4 keeps the
      slicer, ore keeps A2's authored fracture.
      Consequence: no piece of a tree can be left floating, because wood the
      player cuts free is detected (flood fill from the ground) and falls off.
    - **The method.** One click, one blow, exactly as before. WHICH SIDE decides
      everything: the first click opens the face notch there and commits the fall
      direction, further clicks on that side alternate the notch's roof and floor
      cuts, and a click on the far side is the back cut — placed automatically
      the manual's two inches above the notch. The wood between them is the
      holding wood. Cut through it and the tree goes with nothing steering it.
    - **The fall.** Its first ~58° is the trunk still ATTACHED, rotating about
      the real hinge line under gravity alone
      (`res://scenes/3d_action/hinge_fall.gd`), with the holding wood tearing;
      then it becomes a RigidBody3D carrying the motion it already had. This
      SUPERSEDES Amendment 11's IMPLEMENTATION (spin a freed rigid body about the
      hinge and let the solver sort it out) while keeping its principle in full —
      the fall is simulated, not animated, and trees have no hit points. The
      scripted-hinge ban Amendment 11 lifted stays lifted.
    Amendment 12's principle is kept and its arithmetic is rebuilt on measured
    voxel sections: the fell condition is still a loaded beam (crush + bend) with
    warning cracks and a lean that telegraphs the fall, and `min_thickness` is
    gone entirely rather than surviving as a floor. Amendment 12's "fall
    direction is NOTCH ONLY" is now EMERGENT rather than hardcoded — bending is
    gated on the room the notch has opened, so a properly notched tree goes where
    the notch points and an under-notched one collapses where it stands.
    Contracts untouched: A2 (already superseded for trees), A3, A7, A12 and
    TreeDef. No new signals; every tuning value is an `@export` placeholder per
    Directive 3.

14. **THE GAME IS FIRST PERSON, and the forest is the 3D biome you walk into**
    (Creative Director direction, 2026-07-26: *"I want this to be an fps game now, where
    you walk through a forest and chop down trees"*, with the §0 decisions in
    `handoff/08_FPS_FOREST.md` answered the same day). Scoped to M5's action scene.
    - **THE 2D VILLAGE SURVIVES, and so does every frozen contract.** Sam's choice of
      the plan's cheap answer: the forest is simply the 3D biome you enter, so
      `minigame_entered(Biome)` fires when you walk in and `minigame_exited()` when you
      leave, exactly as they do today. **A9, A10 and A7 are untouched** — the FPS player
      lives inside `3D_World_Root` under `Action_Viewport` where the mini-game already
      was, no signal is added or changed, and M5 still emits only
      `action_hit_registered` and `resource_gathered`. **M7/M8 and the blueprint are
      unaffected.** This is therefore a RE-SCOPE OF M5, not a new module, and the module
      order (M6 next) still means what it meant.
    - **A1 is untouched by this amendment.** The `Action_Viewport` base-canvas fix is
      the pre-existing OPEN A1 FINDING and is being done by Sam through the Project
      Settings UI (the `project.godot` clobber trap); when it lands, `m2_acceptance`
      goes 22/23 -> 23/23 with no code change, because its A1 assertion already demands
      1280x720. If A1's text is ever to be reworded, that is its own amendment.
    - **A11/M3 unaffected, and verified rather than assumed.** GameFeel writes only
      `h_offset`/`v_offset`, which are frustum shifts, so the trauma shake composes with
      mouse look instead of fighting it. Asserted in `m5_acceptance._test_14`: an impact
      shakes the camera while its global transform is left exactly alone.
    - **A12 is NOT amended and does not need to be yet.** The plan flagged that "24
      active rigid bodies per mini-game" was written for one tree on one stump — true,
      and it becomes a real question at §3/§4 with many trees. This pass ships ONE tree,
      so the budget means what it always meant. Do not start §3 without that amendment.
    - **Felled trunks persist until bucked** (Sam's call). Implementation and the
      preserved yield invariant are in the M5 status block above; no contract is
      involved, `trunk_persists` is an `@export` placeholder per Directive 3.
    - A2 (already superseded for trees by Amendment 10), A3, A4, A6, A8 and TreeDef are
      all untouched. Directive 4's bans are untouched. No new autoload.
    - **STOP POINT, and it is deliberate** (plan §7, Sam's choice): §1 and §2 against the
      existing single tree. §3 (many trees), §4 (forest and ground) and §5 (budget) are
      NOT built and must not be started without sign-off, because they only pay off if
      the answer to "does chopping feel good in first person?" is yes.

15. **A12 IS RESTATED FOR A WORLD, and settled debris CONSOLIDATES TO MULTIMESH**
    (Creative Director direction, 2026-07-26: *"Now I want to see how it goes with more
    trees in a scene"*, with the debris question answered the same day). This is the
    amendment Amendment 14 said §3 must not start without. Scoped to M5's action scene.
    - **"24 active rigid bodies PER MINI-GAME" now reads "per action scene".** The forest IS
      the mini-game — one `tree_felling.gd`, one `FragmentPhysicsBudget` — so the number is
      unchanged and means what it always meant. It holds in a stand for a reason rather than
      by luck: **one tree falls at a time** (plan §3d), so the bodies in motion at any moment
      are still one tree's worth.
    - **A12's own "long-term piles may consolidate to MultiMesh" is now DONE rather than
      anticipated.** A settled splinter gives up its RigidBody3D, collider and script and
      keeps only a transform in a `MultiMeshInstance3D`. This REPLACES `max_debris`'s old
      behaviour of DELETING the oldest settled piece: with one tree that was survivable, and
      in a forest it means the pile behind you disappears while you are at the third tree.
      Piles now persist for good and cost one draw call each, bounded by the number of
      splinter MESHES in the game (three), not by trees felled.
    - **`max_debris` is now a cap on SIMULATED debris, not on debris.** It is soft by design
      in two ways — it only retires settled pieces, and it runs on spawn — so the true bound
      is `max_debris + splinter_burst_cap`. Asserted in `core/tools/forest_smoke.gd`.
    - A12's other clauses (freeze settled fragments on sleep or settle timeout, oldest
      settled first) are untouched. `fragment_piece` and `fragment_physics_budget` are
      unchanged.
    - **A1, A2, A3, A4, A6, A7, A8, A9, A10, A11 and TreeDef are all untouched.** The forest
      is still the 3D biome you walk into (Amendment 14): it lives inside `3D_World_Root`
      under `Action_Viewport`, no signal is added or changed, and M5 still emits only
      `action_hit_registered` and `resource_gathered`. Directive 4's bans are untouched. No
      new autoload. `TreeCutState` is a new RefCounted, not a contract.
    - **Nothing regrows** and the stand is finite (Sam's call); **bucked lengths have a
      minimum size** measured off M4's own firewood log. Both are in the status block above;
      neither touches a contract, and every number is an `@export` placeholder per
      Directive 3.
    - **STOP POINT.** §3, §4 and §5 are built against a 25-tree stand. It wants a LIVE look
      before anything is built on it, for the same reason Amendment 14 stopped where it did.

## LOCKED ITEM IDS (res://data/item_registry.tres)

`pine_log, oak_log, mahogany_log, stone, copper_ore, iron_ore, amethyst,
ruby, sapphire, wood_board, copper_ingot, iron_nail`

Known data flag (unresolved, decide at M7): blueprint's M7 example mentions
"Mahogany Boards" but the registry defines generic "Wood Boards". Ask Sam
whether boards become per-species before writing M7 upgrade data.

## ASSET PIPELINE (Sam → Maya → FBX → Godot)

- Format: **FBX** (native Godot 4.3+ importer). Y-up on export; Maya cm vs
  Godot m — fix scale once in Godot's FBX import dock (or export at 0.01).
  Freeze transforms + delete history before export.
- Style: flat-shaded low-poly, vertex colors preferred over textures,
  hard edges fine, silhouettes readable at the 960×540 viewport.
- Fragment pivots at the piece's landing/contact point (predictable A12
  physics).
- Approved Pine chop chain (template for later species), 4 hits, 5 leaf
  pieces, 9 meshes: `pine_log_full`(t5) → `half_a`(t4)+`half_b`(t1-leaf) →
  `qtr_a`(t3)+`qtr_b`(t1-leaf) → `8th_a`(t2)+`8th_b`(t1-leaf) →
  `16th_a`(t1-leaf)+`16th_b`(t1-leaf). All leaves yield `pine_log`. All
  splits visibly asymmetrical. Plus: `chopping_stump.fbx`,
  `axe_handheld.fbx`, pre-baked `background_blurred.png` (blur baked in DCC,
  not in-engine).

## MODULE ORDER & ONE-LINE SCOPE

M1 core contracts ✅ (pending sign-off) · M2 main scene shell + pixel
pipeline + placeholder stump/gobo/fake-DOF scene · M3 GameFeel (hit-pause,
noise shake, `register_impact`) · M4 firewood chopping block · M5 tree
felling (wedge notch cuts per Amendment 10, gear gating, hinge fall,
bucking to logs) · M6 ore mining · M7 2D
management (inventory UI, buildings, refining, upgrades) · M8 villager
overlays (hi-res portraits on UI_Overlay, morale production multiplier,
formula: `effective_seconds = base_seconds / (role_bonus * morale_factor)`).
