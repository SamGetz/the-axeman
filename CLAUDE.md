# CLAUDE.md — The Axeman (Hybrid 2D/3D Cozy Village Builder)

You are the Lead Gameplay Programmer and Technical Engine Architect. The human
user (Sam) is the Creative Director. This file plus the Master Project
Blueprint are your absolute source of truth.

**Engine:** Godot 4.7 (stable) · **Renderer:** Compatibility
(`gl_compatibility`) · **Language:** GDScript only, native nodes only, no
third-party plugins, no invented APIs.

---

## CURRENT PROJECT STATUS (as of 2026-07-29)

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
- **MULTIPLE AUTHORED TREE TYPES (2026-07-27).** Sam added `tree_02` and asked for the
  forest to accept multiple types. The stand now mixes `tree_01` and `tree_02` through the
  data-driven `_TREE_SPECIES` table in `tree_felling.gd`; each row declares a stable id,
  FBX, TreeDef, optional source scale, trunk/bark surface, canopy surface list and
  transformed-mesh ground line.
  Adding another type is one row, not another spawn path. No contract touched.
  - **The mix is deterministic.** Type selection uses a local RNG from `forest_seed` plus
    the stable tree slot, never global `randi()`, so a seed reproduces positions, sizes,
    yaws AND species. Each `TreeTrunk` carries `species_id` / `species_index` with its own
    mesh and TreeDef.
  - **Imported scene transforms are part of the asset.** `tree_02`'s raw mesh is only
    0.078 m high because its FBX carries a 180x transform on the MeshInstance3D. The old
    `MeshUtils.mesh_from_scene()` discarded that node transform. It now accumulates and
    bakes the imported transform into positions, normals and tangents, so `tree_02` stands
    at its authored 14.05 m without a guessed scale override. M4 was re-run because it
    shares this loader: 16/16; slicer 34/34.
  - **Bark is explicit, never inferred from triangle count.** `tree_01` has 2,688 leaf
    triangles against 1,688 bark triangles, so the old "widest surface is bark" guess put
    foliage on the voxel trunk and let leaf density bias its radius. Both rows declare
    `trunk_surface = 0`; TreeTrunk uses that surface for axis/radius/material/UV-density
    measurement while the full mesh still supplies the crown and branch-stop detection.
  - **Roots may sit below grade without burying the gameplay.** Both FBXs extend below
    local y=0. Rows declare `trunk_base_y = 0`; the voxel band, standing collider, picker
    height and stump begin at that transformed ground line rather than the mesh's lowest
    root vertex. `_max_local_y_of` was corrected at the same time: a height fraction is
    converted back to local Y by adding the mesh base, then capped by `band_hi`. Before
    these two fixes, `tree_02`'s entire band/collider sat underground and a 0.5 m aim could
    create cut bookkeeping in empty space.
  - **Gameplay data is deliberately still Pine for both visuals.** Both rows point at
    `pine_tree.tres` because the new asset establishes a visual type but Sam has not
    assigned a different hardness or yield. Point the row at another TreeDef when that
    species call is made; do not infer it from a material name (`tree_02` itself contains
    both `oak_bark` and `pine_lefs` names).
  - New `core/tools/tree_species_smoke.tscn`: **33/33** — both rows/resources, authored
    sizes (14.05 m / 8.61 m), deterministic mixed stand, every seeded yaw/size accepts its
    first blow, explicit bark survives voxelisation, and both meshes lose measured wood
    from a deliberately high 0.5 m aim. Both remain standing after the opening blow and
    fell after 13 repeated blows. `forest_smoke` is **41/41** (its setup now holds
    load failure out until the test's dedicated felling phase, so different crown loads
    cannot invalidate a test that says it is only chopping "a little"); `fps_smoke`
    **14/14** on tree_02. Compatibility-renderer shots confirm the two silhouettes and
    their separate materials coexist, and the built trunk joins at ground correctly.
  - **Legacy numeric-suite note:** `m5_acceptance` is now pinned back to `tree_01` rather
    than whichever type occupies row 0, but the newly supplied `tree_01` geometry is not
    the old bare 0.94 m trunk those exact notch/blow-count assertions were authored
    against: current result **187/197**. The focused geometry, forest, FPS, M4 and slicer
    suites above are green; the 10 old numeric/art-shape assertions need a deliberate
    rebaseline with Sam's current felling tuning, not silent tuning changes in this asset
    integration pass.
- **LANDING-TIMED AUTHORED CANOPY DESPAWN (updated 2026-07-29).** Sam wants branches
  and leaves to remain on the tree throughout its fall, then disappear when the trunk hits
  the ground so bucking shows only the exact authored trunk. The first attempt generated a
  tapered `CylinderMesh` stem; Sam rejected it immediately because it changed the geometry.
  It was removed completely.
  - Each species row now declares `canopy_surfaces`. On failure, `TreeTrunk` copies those
    exact surfaces into one `ShedCanopy`; every surface not declared canopy is copied
    byte-for-byte (positions, normals, tangents, UVs, colours, indices and materials) into
    `WoodyCrown`. `ShedCanopy` is parented to `FallingTree`, follows it across the
    hinge-to-rigid-body hand-off, and is hidden/freed by `_on_trunk_contact` on the landing
    frame. It never enters the bucking slicer.
  - Generator v2.3 exports one mesh with three semantic surfaces. Current `tree_02` imports
    as surface 0 trunk/roots, surface 1 canopy bark (branches/leaders/stubs), and surface 2
    leaves, so its species row declares `canopy_surfaces = [1, 2]`. ~~Legacy `tree_01` still
    has trunk and branches combined on surface 0 and can shed only surface 1 leaves until it
    is regenerated/re-exported with v2.3.~~ **SUPERSEDED 2026-07-29: Sam re-exported
    `tree_01` with v2.3, so it is three surfaces too and its row now declares `[1, 2]`. See
    the third-round fix below — it shipped a day declaring `[1]` against a three-surface
    mesh, which is what kept its leaves on the felled trunk.**
  - **The renewed one-swing regression was stale surface metadata.** After `tree_02` gained
    its third material surface, its row still declared only `[1]`. Surface 2 leaves therefore
    entered `_wood_mesh`, were measured as structural wood overhead, and produced enough
    fictitious bending load to fail on the opening hit. Declaring both `[1, 2]` restores the
    voxel/load path: both types remain standing after their first blow and fell after 13
    repeated blows in `tree_species_smoke`.
  - Verified: `tree_species_smoke` **37/37**, `forest_smoke` **41/41**, and M5
    **187/197**. The M5 result is unchanged from the documented current-art baseline; its
    10 failures are the existing numeric/bucking rebaseline, not canopy, landing, or
    single-hit failures.
- **FIXED 2026-07-29 (third round) — THE CUTS WERE INVISIBLE AND THE LEAVES NEVER WENT.**
  Sam: *"when I cut the tree, the voxel 'chunks' dont seem to be getting taken out, they seem
  to be getting cut, but visually I am not seeing any change"* and *"when the leaves touch the
  ground they arent despawning"*. Four separate causes, two per symptom, all reproduced and
  measured before anything was changed. No contract touched.
  - **NOTE ON THE ART: Sam re-exported `tree_01.fbx` mid-session (13:14).** It is now a 13.59 m
    tree of radius 0.906 with THREE generator-v2.3 surfaces, where it was an 8.13 m tree of
    radius 0.638 with two. Every number below is against the asset now on disk. An m5 run from
    before that swap is not comparable with one from after it.
  - **THE CUT WAS REAL AND NOBODY COULD SEE IT — MEASURED: nine blows took 0.139 m³ out of
    tree_01 and changed ZERO pixels on screen.** Rendered before/after at eye height under
    gl_compatibility, then differenced. Two independent causes stacked:
    - **THE ROOT FLARE ATE THE BAND.** `TreeTrunk._clear_trunk_height` scans up the mesh in
      10 cm bins for the first thing wider than `radius * _BRANCH_TOL` and calls that the
      branches. The current art splays at the butt far past that line — **tree_01 to 1.56x the
      trunk radius in the very first bin, tree_02 to 1.77x across its first three** — where the
      ORIGINAL tree_01 only reached 1.14x and sat comfortably under it. So the scan stopped at
      bin 0, `maxf(0, _MIN_BAND)` collapsed the band to **0.9 m on every tree in the forest**,
      and the crown's imported mesh (clipped just below the band top) covered nearly all of it.
      Fixed structurally, not by moving the tolerance — 1.8 would clear tree_02's flare and walk
      straight through a real branch cluster too. The contiguous over-limit run STARTING AT BIN
      0 is taken as flare and skipped, because a branch has bare stem under it by definition;
      the skip is bounded by the trunk's own `radius` above `band_lo` (a flare reaches up about
      as far as it reaches out), so it scales with the tree and adds no tuning number. An EMPTY
      bin continues the run rather than ending it: these trunks are prisms with vertices only at
      their ring heights. Bands now: **tree_02 0.9 -> 3.90 m, tree_01 0.9 -> 1.60 m**.
    - **AND THE AIM WAS CLAMPED INTO THE STRIP THE CROWN COVERS.** `_CROWN_OVERLAP` clips the
      crown 2.5 cells (0.14 m) BELOW `band_hi` and laps it down over the band's rim — deliberate,
      it is the 2026-07-25 fix for the ring of daylight round an uncut trunk — so the top 0.14 m
      of ANY band is behind the crown by construction. `_max_local_y_of` clamped to `band_hi`,
      and a standing player's crosshair sits at eye height (1.65 m), so on any tree whose band
      ends near that the blow was placed in exactly that hidden strip. **This half is scale-free
      and bites a 3.9 m band the same as a 0.9 m one** — it is why the flare fix alone did not
      cure Sam's newly re-exported tree_01, whose branches genuinely start at 1.6 m. New public
      `TreeTrunk.crown_base()` is the top of the wood that is DRAWN, and the clamp uses it.
      After: 1,555-1,905 pixels change per eye-height notch, render-verified on both types.
  - **THE LEAVES: the SECOND tree of a session ran no landing at all.** `_reset_fall_state`
    is reached from exactly two places — a fresh board, and the fade that follows a trunk being
    BUCKED OUT — and the stand ships `trunk_persists` on with nothing regrowing. A player who
    fells a tree and walks off to the next one without bucking the first reaches NEITHER, so
    `_landed` and `_settled` were still true from the previous tree when the next one fell, and
    both functions that run a landing bail on exactly those flags: `_on_trunk_contact` returned
    on `if _landed` (no `_clear_attached_canopies`, no impact, no slow-motion beat, no kicked-up
    debris) and `_watch_fallen` returned on `or _settled` (never damped, never frozen,
    **`_begin_bucking()` never ran — the second tree could not be cut into logs at all**).
    MEASURED before the fix, three trees felled in the shipping stand without bucking: tree 1
    shed its canopy and went to bucking, trees 2 and 3 kept theirs and never started. Same
    family as the "felling one tree killed the axe for the whole session" bug — per-fall state
    that only a fresh board reset — and this is the rest of that family. New
    `_reset_landing_state()` holds exactly those seven variables and is called at the start of
    every fall, AFTER `_finalise_felled_timber()` (which reads the bucking state it must not
    disturb); `_reset_fall_state` now calls it too rather than duplicating it.
    - **BACKSTOP, and keep it:** `_clear_attached_canopies()` also runs at the settle in
      `_watch_fallen`. A settled trunk is a trunk that is down, so it is the same moment
      `_on_trunk_contact` means — a no-op in the ordinary case and the only call when no
      contact was ever reported, which happens for real: `fall_timeout` settles a trunk that
      never stopped moving, and a tree that hangs up on a neighbour can come to rest under the
      safety net's 60-degree tilt. The next thing that happens to that trunk is BUCKING, which
      would otherwise cut its leaves up.
  - **AND `tree_01`'s SPECIES ROW WAS STALE — the same regression logged above for tree_02,
    on the other tree.** Sam's re-export gave tree_01 a separate `pine_lefs` leaf surface, so it
    now has three surfaces, while its row still declared `canopy_surfaces = [1]`. An UNDECLARED
    surface is treated as WOOD: surface 2's **6,208 leaf vertices** went into `WoodyCrown`,
    stayed bolted to the felled trunk for good, were measured as structural crown mass, and were
    fed through the bucking slicer. Row corrected to `[1, 2]`. **This is now twice, so there is
    a tool for it:** `core/tools/tree_surfaces.gd/.tscn` prints every surface of every declared
    type against the FBX on disk and names any that is undeclared. **Run it after any tree is
    re-exported** — surfaces are named BY INDEX, nothing infers them, and nothing about the
    running game shows the mistake.
  - **`_fallen_length` WAS MEASURED OFF THE LEAVES, and declaring them correctly is what
    exposed it.** `TreeTrunk.detach_above` set it from `_aabb.end.y`, the WHOLE source mesh —
    fine for exactly as long as every tree's foliage stopped where its wood did. tree_01's
    authored trunk tops out at **8.82 m while its leaf cards reach 13.59 m**, so a 7.4 m piece
    of timber reported itself as 12.8 m. Everything sized off that length was sized off leaves:
    the falling trunk's collision cylinder, the tip speed the landing impact scales by, the line
    of debris the landing kicks up, the A3 size tier, and `_min_log` — which divides it by
    `buck_target_logs`, so Sam's own "about five logs, never coins" rule produced **two logs and
    a remainder of 1.66 m against its own stated 2.56 m minimum**. It now measures the union of
    the meshes actually coming down (`freed`, under their own transforms), which is the timber
    and only the timber. Six m5 bucking checks went from red to green on that one line.
  - **NEW REGRESSION GUARDS, and both were verified to FAIL without their fix** (the project's
    own repeated lesson about checks that pass because they measured nothing):
    - `tree_species_smoke` (**37 -> 43**) now asserts, per ASSET, that an eye-height blow is
      placed at or below `crown_base()` — i.e. in wood that is drawn — and that there is real
      trunk under it, plus that the band still stops below the crown. It asserts the CLAMP, not
      a band length, because the hidden-strip half of the bug is scale-free. New test seam
      `debug_max_cut_height(trunk)`.
    - `forest_smoke` (**41 -> 47**) fells TWO trees in its own game with `trunk_persists` on and
      the first left lying there, and asserts each sheds its canopy and reaches bucking. It
      needs its OWN game — the existing felling phase bucks its victim out, which resets the
      very state this is about. Confirmed: with the fix reverted, round 1 passes and round 2
      fails both checks, which is exactly Sam's report.
  - **Suites:** M1 21/21, M3 16/16, M4 16/16, slicer 34/34, `felling_smoke` 11/11, `fps_smoke`
    14/14, `tree_species_smoke` 43/43, `forest_smoke` 47/47. **M5 is 184/197 against a
    same-day, same-asset baseline of 186/197** taken by reverting all four fixes — so this is
    **one check repaired** ("a blow well away from it opens a SECOND cut"), **two newly red**,
    and one known flake. **M5 IS NOT DETERMINISTIC: two identical runs gave 17 and 18
    failures**, differing on "every settled piece of debris is resting on something" and on the
    shortest-length value at the centimetre. Do not read ±1 as a regression.
  - **THE TWO NEWLY-RED M5 CHECKS ARE STALE YARDSTICKS, NOT GAMEPLAY, and they want Sam's
    call rather than a silent edit.** Both compare a level against the BAND as a whole, which
    stops meaning anything once the band is tall enough to contain the trunk's own taper —
    exactly the failure already logged for the "one continuous notch" check, which was fixed by
    comparing each level to its OWN uncut baseline. These two never were. Measured on an
    UNTOUCHED tree_01: sections run **2.94 m² at the butt down to 1.72 m² at 1.54 m**, so
    `full_area()` (the median) is 2.209 while the level at 0.5 m is 2.263, and `holding_area()`
    (the minimum) is 1.691 up at the band top rather than at any cut. So "the low cut is still
    there" and "...and takes wood out of the trunk" now measure taper. **The fell condition is
    unaffected** — it is stress (crush + bend) per level against the load standing on that
    level, never area against the band, and `holding_area()` is only ever reported through
    `holding_wood()`, never used as a condition. `forest_smoke` already carries a comment saying
    this comparison is unreliable. Every felling check in every suite passes.
  - **STILL NOT EYEBALL-VERIFIED BY SAM.** Render-verified under gl_compatibility: the notch
    visible at eye height on both types, the felled trunk lying in the stand as clean timber
    with no leaves on it.
  - **OPEN, and it is Sam's to decide: tree_01's authored trunk is 8.82 m of a 13.59 m tree**,
    so ~4.7 m of its height is leaf cards with no wood in them. Bucking now correctly divides
    the 7.4 m of timber, which at `buck_target_logs = 5` gives shorter logs than tree_02's.
    Nothing is broken; the two types simply carry very different amounts of wood for their
    height. Also unchanged from before: `pine_tree.tres` yields 4 `pine_log` against a
    `buck_target_logs` of 5, and the shipping `tree_felling.tscn` still has `cut_span = 0.50`,
    which cannot fell either trunk (`_warn_cut_span` says so at spawn).
- **FIXED 2026-07-29 (fourth round) — THE BARK TORE, THE ROOTS VANISHED, AND THE TRUNK
  DEFORMED HIGHER UP. All three were the voxel band being measured off geometry that is
  not the trunk.** Sam: *"huge uv tearing / the roots dissapear when I start cutting the
  trees ... also when I try to cut the trees a little higher up it looks like I cant cut
  them properly and there is some geom deformation that looks kinda buggy"*. Every cause
  was reproduced and measured before anything changed. **M5 is 191/197** against the
  documented same-asset baseline of 184; `tree_species_smoke` 43/43, `forest_smoke` 47/47,
  `fps_smoke` 14/14, `felling_smoke` 11/11, slicer 34/34, M4 16/16. No contract touched;
  every number is an `@export` placeholder per Directive 3.
  - **THE PROFILE WAS MEASURED OFF THE WHOLE MESH, and that is the root of all three.**
    `WoodVolume._build_profile` cast one ray per angular bin at every level, over EVERY
    surface, and kept the FARTHEST hit. That was safe while a tree's non-trunk geometry
    stayed clear of the band. The current generator's trees are not: leaf cards droop to
    1.11 m (tree_02) and 1.88 m (tree_01), and roots arch out of the butt. So the band was
    measured against foliage and roots in preference to the stem. It now takes the DECLARED
    TRUNK SURFACE only (`build(..., surfaces)`), exactly as `trunk_surface` already governed
    the bark material and the radius.
  - **THE TEARING was the leaf atlas's and the roots' UVs being fed to `_fit_bark_uv`.**
    MEASURED on tree_01 at 0.10 m: u swept **0.332 -> 3.075** round one ring where a full
    turn is 0.82, with adjacent samples 0.425 apart against a nominal 0.026 — sixteen times
    the correct step, which is a texture wrapping several times between two vertices. Above
    the flare it was already clean (0.157). After the fix the fitted turn is **-1.000 and
    -0.992** (i.e. exactly one wrap, as authored) and the worst adjacent step is 0.036-0.062
    at mid-band. Render-verified: the smeared streaky skirt round the bottom of every trunk
    is gone.
  - **THE ROOTS: a radial field cannot hold a root, so the band now STARTS ABOVE THE FLARE
    and the wood below stays the tree's own authored mesh.** The field is one radius per
    (level, angle) about the trunk axis; four or five buttresses arching out of a butt have
    no expression in that, so `_PROFILE_CLAMP` flattened them into a smooth skirt — the
    roots, gone the instant the tree was first struck — and everything below `band_lo` was
    discarded outright, because the crown clip kept only what was ABOVE it. Now the trunk
    surface is sliced at BOTH ends: `Roots` below (never carved, never measured as load),
    the band between, `Crown` above. `WoodVolume` gained `rim_base_lo/hi` so the roots lap
    over the band's lower rim exactly as the crown laps over its upper one.
    - The flare top is found by `_root_flare_height`, and it is measured AGAINST THE LOCAL
      TAPER, not against the radius: these trunks run 2.8x their band radius at the butt
      down to 1.0x with no step anywhere, so "wider than `_BRANCH_TOL` x radius" has no
      fixed answer — measure the radius over the band and the flare swallows the taper
      below it, measure it lower and the flare disappears. Two-pass estimates just made the
      two definitions converge on each other and put the band's floor at 1.1 m. A height is
      flare when it is wider than the wood 0.2 m ABOVE it (`_TAPER_LOOK`), which needs no
      radius at all. Gives **0.6 m (tree_01) and 0.4 m (tree_02)**.
  - **"CAN'T CUT HIGHER UP" WAS A LEAF CARD STOPPING THE BAND.** `_clear_trunk_height`
    scanned the whole mesh for the first thing wider than a trunk, so tree_02's foliage at
    1.11 m ended the band there — **1.1 m of band on a 13.9 m tree**, its top 0.14 m behind
    the crown by construction, and `_max_local_y_of` clamps the crosshair to `crown_base()`,
    so every blow aimed above 0.96 m landed at 0.96 m. Restricted to the trunk surface, the
    stem is 6.7 m of clear wood on both types, and the band is bounded by the new
    **`band_height_max` (3.0 m, a COST knob and Sam's number)** rather than by whatever
    crossed the trunk first. Bands are now **0.6..3.6 and 0.4..3.4**.
  - **THE DEFORMATION HIGHER UP WAS THE GRID BEING CENTRED ON THE BUTT.** `axis_xz` came
    from `_base_axis` at the butt, and the generator leans and wanders every trunk it makes
    — so three metres up the stem has moved 0.4 m sideways on a 0.5 m radius and **the axis
    is outside the wood**. The profile is cast FROM that axis, so rays pointing the other
    way miss the trunk entirely, `_fill_profile_gaps` fills the misses from their
    neighbours, and the top of the band swells: tree_02's section went **0.455 m² -> 1.011
    m² in one step**. `_recentre_on_band` puts the axis on the stem's own centre at the
    middle of the band; the sections now taper monotonically to the top (1.315 -> 0.453 and
    1.206 -> 0.412) and the grid needed shrinks from nx 40 to nx 30.
    - `_base_axis` also averaged over the lowest 5% of the AABB, which is the FOLIAGE's —
      0.61 m on tree_01, i.e. the entire root flare. It uses 5% of the stem now.
  - **CUT FACES WERE BLOWN OUT WHITE, and nothing had ever measured them.** `ring_radius`
    was `trunk.radius`, but `_cut_mat` is a single growth-ring disc on a WHITE field with
    `texture_repeat` off — so anything mapped past its edge clamps to that white, and a
    notch is a bite at the PERIMETER, which is exactly the part that overflowed. Fitted to
    `WoodVolume.profile_max_radius` (the widest wood in the band) instead. Same bug and same
    fix as the slicer's `cap_fit_round` (2026-07-27); this path was simply never checked.
  - **THE WIDTH SCAN IS NOW REAL CROSS-SECTIONS, not binned vertices.** These trunks are
    lofted prisms with rings a metre apart, so a vertex histogram had values at the ring
    heights and NOTHING between — thirteen of tree_01's first twenty bins were empty, and
    the rest held a passing root TIP as often as a trunk ring. Every scan built on it
    inherited that. `_width_bins` cuts the mesh at each height instead and reports both the
    width and where the stem's centre is, which is what the flare scan, the branch scan, the
    radius, the grid extent (`_band_max_radius`) and the colliders all actually need.
  - **THE YARDSTICKS HAD TO FOLLOW, and this is the third time in this project.**
    `holding_area()` was the plain minimum section over the band — which on a three-metre
    band is the TOP OF THE BAND on a tree nobody has touched, so an untouched tree reported
    a notch two thirds of the way through, `_notch_to` stopped before cutting anything, and
    the tree could never be felled. It is measured per level against that level's own uncut
    area now (`_base_area`, captured at build), as `notch_depth_frac` and the stump
    collider's carve scan are. Same shape as the "one continuous notch" fix of 2026-07-25.
    - **The load model's `_void_height` had the same disease and it mattered more.** "Has
      this side been opened up?" tested the measured reach against `radius * 0.85` — ONE
      number for a band the trunk tapers threefold over, so it is above the real width at
      the band top (every level reads as already open, in every direction, untouched) and
      below it at the butt (no cut, however deep, ever reads as open; the tree refuses to
      hinge and has to be crushed). Now against `TreeTrunk.base_reach(j)`, the level's own
      uncut reach.
  - **A CUT AT THE VERY BOTTOM OF THE BAND COULD NOT FELL THE TREE, and the player could
    aim there.** A notch is a wedge and the room it opens is the run of heights whose wood
    no longer reaches the bark; cut too near the floor and the wedge's lower half falls off
    the end of the field. MEASURED at `band_lo + 0.05`: 100% of its own section cut, then
    **forty more blows removing 6 mm³ between them**, opening stuck at 0.220 m, stress
    plateaued at 0.78. New `_min_local_y_of` keeps the aim `topple_min_open` above the floor
    — not a new number, but exactly the opening the load model already demands before a tree
    may hinge, so the lowest aimable cut is the lowest one that can work. After: fells at
    0.65/1.05/1.65 m in **16 / 14 / 12 blows**, more wood lower down, stress ~1.9 at failure.
  - **A PARSE ERROR COST AN HOUR OF TESTING, and it is worth remembering how.** A duplicate
    local (`base`) in `_build_stump_body` stopped `tree_trunk.gd` registering its
    `class_name`, which cascaded to `tree_felling.gd` and everything downstream — and the
    suites did not report it as a failure, they reported plausible-looking WRONG RESULTS
    against a script that never loaded. `godot --headless --path . --check-only -s
    res://<script>` is one second and settles it. (Autoload identifiers are "not found"
    under `--check-only`; that is expected, not an error.)
  - **STILL OPEN, and all four are Sam's numbers (Directive 3) — I did not touch them:**
    - **`lean_start_stress` (0.25) is now too high and the fall's only warning is gone.**
      MEASURED at a 60% notch: stress **0.09**. The curve is very flat until the end —
      0.05 (4 blows), 0.14 (8), 1.92 (12, fells). Three of the six remaining M5 failures are
      this one value. Wants lowering to about 0.08-0.12 on current numbers.
    - `band_height_max` = 3.0 m is a placeholder chosen to comfortably cover a 1.65 m
      crosshair looking up and down. It is the dominant cost knob: the field is nx*ny*nz and
      ny comes straight off it. Per-blow carve+remesh measures ~43 ms.
    - The shipping `tree_felling.tscn` still has `cut_span = 0.50`, which cannot fell either
      trunk (`_warn_cut_span` says so at spawn). Unchanged from before this pass.
    - Two M5 checks want a deliberate rebaseline rather than a silent edit: "it broke at the
      cut" (0.66 m against a cut at 0.80, tolerance 0.12 — the break is inside the angled
      cut's own span, so this is the tolerance, not the break) and "taking far more blows"
      (14 against 7). **I did not chase why `hinge_thickness()` reports 1.100 m** on a trunk
      whose local width there is ~1.29 m; the fall itself is correct in every other check
      and in render, but that number says the failing level is a nearly-uncut one and it
      deserves a look.
  - **RENDER-VERIFIED under gl_compatibility** (`core/tools/butt_shot.gd/.tscn`, NEW — the
    foot of a tree before and after the band replaces it, and after cuts at three heights,
    which is the tool for exactly this class of bug): roots intact and correctly textured on
    both types, bark continuous and untorn from root to crown, cuts landing and clearly
    visible at 0.4 m, 1.65 m and 3.2-3.4 m, end grain reading as rings rather than white.
    **Still NOT eyeball-verified by Sam.**
- **FIXED 2026-07-30 (second round) — THE TREE NO LONGER CHANGES UNDER THE PLAYER.
  `prebuild_stand`.** Sam, after the grain fix below: *"when the player strike the wood,
  there is a small lag, then the texture of the tree rotates ... I dont mind if the stump
  gets cut, the player should be able to cut it anyway, not an issue. There doesnt need to
  be a slight of hand texture swap if we can avoid it."* M5 **193/197** (unchanged — the
  six documented pre-existing failures), `forest_smoke` 46/46, `tree_species_smoke` 43/43,
  `fps_smoke` 14/14, `felling_smoke` 11/11. No contract touched.
  - **IT IS NOT A WRONG TEXTURE, AND THAT IS WHY IT SURVIVED FOUR ROUNDS OF LOOKING AT
    TEXTURES.** New dense measurement (`bark_uv_probe`, now sampling every trunk-TRIANGLE
    CENTROID rather than the mesh's vertices — these prisms have rings a metre apart, so
    the band held only 26 vertices and "the mapping is exact" was concluded from those):
    the band's bark sits **4 degrees round the trunk from the artist's on tree_01 and 8 on
    tree_02**. That is not a rotation anybody could see. What Sam is seeing is the SWAP:
    a previewed tree is its imported mesh and a built one is roots + voxel band + clipped
    crown, and those are two different surfaces of the same trunk — the band is round
    where the import is a 16-sided prism, and its normals come from the field's gradient
    rather than from the artist. Swapping one for the other at the moment of the first
    blow is a stall followed by a pop, and no amount of UV work can make two different
    surfaces the same surface.
  - **THE FIX IS TO DO IT BEFORE THE PLAYER HAS EVER SEEN THE TREE.** `_prebuild_stand()`
    voxelises every tree at spawn. There is then nothing to pop and nothing to stall: the
    tree the player walks up to is the tree they will chop.
  - **THIS IS PLAN §3a's TRADE MADE THE OTHER WAY, and it costs real money.** MEASURED on
    the shipping 25-tree stand (`core/tools/eager_build_probe.tscn`, NEW): **4.5 s and
    ~58 MB** to build them all, **~190 ms a tree** (not the ~35 ms §3a was written
    against — the band is 3 m tall now). Far too big to hide inside a frame, so it cannot
    be amortised into the walk and has to land at forest entry, where the stand is already
    spawning. `prebuild_stand` is an `@export` PLACEHOLDER per Directive 3: turn it OFF for
    §3a's behaviour, and note that **`band_height_max` (3.0 m) is the knob that moves both
    numbers**, since the field is nx*ny*nz and ny comes straight off it.
  - **THE HAND-OVER RING IS STILL THERE, Sam has circled it, and it is STRUCTURAL. Do not
    try a sixth ramp.** Sam, with the join circled in red: *"I think it might be worth
    doing to remove those seams."* The ring is the roots' cut rim at `_root_top`, and
    LOOKING DOWN ON IT is what makes it a ribbon rather than a line — level with a
    horizontal ring you see an edge, from above you see its whole width, and every earlier
    shot in `bark_ab_shot` was taken level or from further away. It now shoots a `down`
    framing for that reason.
    - **FIVE ARRANGEMENTS MEASURED, ALL TRADE ONE EDGE FOR ANOTHER**, three logged in the
      fifth-round entry below plus, on 2026-07-30: making the roots' cap BARK rather than
      end grain (kept — the sharp join row drops 46% and a sliver of bark beats a sliver of
      bright ring), and **INTERPENETRATION** — ramping the band from OUTSIDE the imported
      piece at its cut rim to INSIDE it deeper under the lap, so the two cross and no rim
      is ever the outermost surface. That last one is the only idea of the five that is
      structurally sound, and it MEASURED WORSE: worst extra horizontal edge **+0.0110
      against the shipping +0.0080**, because the outset needed to bury a rim (a third of
      a cell, to beat a quarter-cell disagreement) is itself a ridge on the side where the
      band stands alone. Reverted in full.
    - **WHY NONE OF THEM CAN WORK, stated once so it is not rediscovered:** surface nets is
      a DUAL method — its vertices sit inside cells, never on the isosurface — so the band
      cannot be made to pass through the imported mesh's rim by construction. Two
      independently generated surfaces must hand over somewhere, and whichever is outermost
      at that height shows its own rim.
    - **A MEASUREMENT TRAP THAT INVALIDATED TWO A/Bs BEFORE IT WAS CAUGHT:**
      `TreeTrunk._remesh()` only rebuilds the chunks a BLOW marked dirty, so changing a
      rendering knob and calling it re-meshes NOTHING and the A/B comes out as two
      identical pictures. `bark_ab_shot._force_remesh` marks every chunk first. Anything
      comparing two rendering settings must do the same.
  - **THE STRUCTURAL FIX IS HALF BUILT AND IS BEHIND `voxel_roots` (OFF).** Sam chose it
    over the cheap alternative and chose to pay for it out of cut height, not out of
    `band_height_max` — I argued against the latter and Sam agreed: the band is tall so the
    CROWN's hand-over sits at 3.46 m, well above the 1.65 m eyeline, and shortening it to
    1.5 m would drop that seam to 1.96 m, i.e. straight into view. It would also free only
    ~29,000 samples against the 262,558 a whole-tree grid wants.
    - **DONE: the roots are voxels, and the seam is gone.** `WoodVolume._fill_from_mesh` +
      `_sweep` fill the field BELOW the flare top from the trunk's own triangles instead of
      from the radial profile — three axis sweeps, each line bucketed by grid footprint,
      taking the min distance and the majority sign, so a buttress you can see daylight
      under survives (which is precisely what one-radius-per-angle cannot do). `TreeTrunk`
      then starts the band at the ground and emits NO Roots piece. **Splicing two fill
      methods inside ONE field creates no seam** — the surface still comes off one mesher;
      the seam only ever came from two separate MESHES.
    - **A REAL BUG IT EXPOSED, and it would have bitten any widening of the band: a blow
      probed for the wood's face from 2.5x the STEM's radius.** The flare reaches 2.8x, so
      the probe started INSIDE the wood, `first_solid` reported a face out where it began,
      the slab was built entirely outside the trunk and the blow removed nothing at all —
      tree_01 became unchoppable while tree_02 was fine. `_cut_slab` now sizes its probe,
      its back plane and its scan box off `band_max_radius`.
    - **NOT DONE, and why it is off: the roots' BARK.** The band's mapping is a cylindrical
      wrap fitted to the stem. On a buttress spreading away from the trunk axis the bearing
      swings wildly while v stays put, so the wrap degenerates into contour banding —
      render-verified, and worse than the seam it removes. The roots need their own
      mapping: TRIPLANAR bark on a third surface, routed by height, which is the same
      machinery `side_mat` already uses to route cut faces. That is the next step and it is
      small; it just is not verified, so the switch ships off.
  - **THE REST OF THE STRUCTURAL JOB, if the trunk above the flare is ever wanted in the
    same field too** — Sam has approved it in principle (*"I dont
    mind if the stump gets cut"* + *"worth doing to remove those seams"*). It means one
    continuous voxel object instead of roots + band + crown, which needs a true mesh->SDF
    voxeliser rather than the radial profile: a radial field is one radius per (level,
    angle) about the trunk axis and cannot represent a root buttress at all — that is what
    `_PROFILE_CLAMP` exists for and why the roots were split off in the first place
    (2026-07-29, fourth round). COSTED: the whole-tree grid is **262,558 samples against
    the band's ~58,000** at the shipping cell, roots need a finer cell than that, and the
    stand already holds ~58 MB with `prebuild_stand` on. It is a pass of its own, not
    something to slip in, and it will want `tree_count` or `voxel_cell` moving to pay for
    it — NOT `band_height_max`, for the reason above.
  - **CUT HEIGHT IS NOW CAPPED AGAINST THE PLAYER, not against the tree.** New
    `cut_height_above_eye` (0.5 m, Sam's number): a blow may not land more than that above
    the player's eyes. Measured against the player so it means the same on a tall trunk and
    a short one, and converted into the trunk's own frame because a tree stands wherever the
    scatter put it. `band_height_max` is deliberately UNCHANGED — the band's height is what
    keeps the crown's hand-over above the eyeline, and it is not the same question as how
    high the axe should reach.
  - **TWO ASSERTIONS UPDATED, deliberately, and both were encoding the lazy build rather
    than a property of the game.** `forest_smoke`'s "only the tree the player starts at is
    voxelised at load" is now "every tree is voxelised at spawn, so none of them changes on
    its first blow"; and its per-tree isolation check asserted `not b.is_built()`, which was
    a proxy — it now asserts **no wood has come out of tree B** (`removed_volume() <= 0`),
    which is the property that actually matters and holds whichever way the switch is set.
- **FIXED 2026-07-31 (later the same day) — THE HIT NO LONGER STUTTERS, AND `voxel_roots`
  IS BACK OFF.** Sam, after playing the entry above: *"The textures on voxel parts of the
  tree look awful and the game is lagging on every hit - this seriously needs to be
  addressed, the cut span doesnt adress this issue. The tree just needs to look like a tree
  without texture issues."* Both complaints traced to the same change — voxelising the root
  flare — and both were reproduced and measured before anything moved. **M5 199/203** (the
  best it has been; the 4 remaining are the documented pre-existing tuning baselines),
  `tree_species_smoke` 53/53, `forest_smoke` 46/46, `fps_smoke` 14/14, `felling_smoke`
  11/11, slicer 34/34, M4 16/16, M1 21/21, M3 16/16. No contract touched.
  - **THE LAG, MEASURED (`core/tools/felling_profile.tscn`), per blow:**
    | config | per blow |
    | --- | --- |
    | `voxel_roots` ON (what Sam played) | **84 - 350 ms**, spikes every few blows |
    | `voxel_roots` OFF | 38 - 102 ms |
    | OFF + the two fixes below | **32 - 50 ms, no spikes at all** |
    At 60 fps a frame is 16.7 ms, so Sam was getting a 5 - 20 frame hitch on every hit. The
    A11 pause cannot hide that; CLAUDE.md's own "~26-40 ms, invisible inside the hit-pause"
    claim had quietly stopped being true.
  - **THE 300 ms SPIKES WERE `_retire_old_debris` RUNNING ONCE PER CHIP.** It is a pass over
    the whole debris list that can rewrite a MultiMesh (O(pile), by design — see Amendment
    15), and `_spawn_chip` called it. A blow spawns about TWELVE chips, so one blow's worth
    of new debris paid for twelve whole-list passes, and once the pile is over `max_debris`
    every one of them bakes. It runs **once a frame** from `_process` now. The cap was always
    SOFT in two ways (it only retires settled pieces, and it ran on spawn), so a frame's
    grace changes nothing — `forest_smoke`'s tight bound still holds.
  - **`FragmentPiece` CACHES ITS COLLISION SHAPES.** `create_convex_shape()` runs a hull
    build per piece, and M5 spawns ~12 chips a blow off a splinter mesh table with THREE
    entries in the whole game — so it rebuilt the same three hulls a dozen times a blow, for
    ever. Now keyed by mesh instance id and shared (a Shape3D is shareable; the per-body part
    is the CollisionShape3D's transform, still set per piece). **Honest note: the clearly
    attributable per-blow win above is the retire change; this one removes real redundant
    work but its effect sits inside the run-to-run noise.** `clear_shape_cache()` exists for
    scenes that build meshes of their own.
  - **THE TEXTURES: it is the ROOT FLARE, and only the root flare.** Rendered close up at
    the butt (`core/tools/butt_shot.tscn`, `_5_bark_closeup`) the band's bark up the STEM is
    indistinguishable from the imported mesh — but the flare comes out dark and smeared with
    a hard banded ring where it meets the wrap at the shoulder. That region is the one part
    of the trunk whose bark is not the artist's: the band's cylindrical wrap degenerates on a
    buttress (the bearing swings through a huge range at almost no change of height), so it
    gets a TRIPLANAR material instead, and triplanar cannot reproduce authored root UVs.
  - **SO `voxel_roots` IS OFF.** It is the cause of both reports: the smeared flare, and a
    grid that goes **68,600 -> 234,423 samples (3.4x)** because the grid is a BOX sized to
    `band_max_radius` and the flare is 2.7x wider than the stem — i.e. it pays for the bottom
    17% of the band with 3.4x the samples, and every part of a blow (carve, remesh, level
    stats, floating check) scales with it.
    - **This reverses the entry below, deliberately and with Sam's newer instruction.** Sam
      asked for root-cutting twice; having played it, Sam asked for the tree to look right
      and the hits not to stutter. Those cannot all be had at once with this approach.
    - **None of the root work is lost or bypassed** — turning the switch ON is still fully
      tested and correct (the axe reaches the dirt, the stump collider follows the wood, cut
      faces in the flare are wood not white). It is a switch precisely so this is Sam's call.
    - **What would actually give Sam all three is ART, not code:** a trunk whose root flare is
      part of the stem's silhouette rather than separate buttresses — then the radial profile
      describes it, the band's own wrap maps it, and the grid needs no extra width. Surface
      nets cannot reproduce authored buttress geometry, a fitted cylindrical wrap cannot
      reproduce the artist's root island UVs, and one axis-aligned grid cannot be wide only
      where the wood is. Sam's call; the generator is Sam's.
  - **The `tree_species_smoke` root checks are GATED ON THE SWITCH rather than deleted**, so
    each asserts what the CONFIGURED game should do: with it on, the axe reaches into the
    flare and the band starts at the dirt; with it off, the flare stays authored mesh and
    every blow lands in the band. Deleting them would have left the ON path uncovered the
    next time it is wanted.
  - **NOT eyeball-verified by Sam.** Render-verified under gl_compatibility: the butt at eye
    level with crisp authored bark and real root geometry, no smear and no banded ring. The
    faint hand-over line at the roots' rim is the KNOWN structural seam (five arrangements
    measured on 2026-07-30, none removed it) and is far subtler than what it replaces.
- **THE AXE REACHES THE ROOTS — `voxel_roots` IS ON (2026-07-31).** *(SUPERSEDED the same day
  by the entry above — the switch is OFF. Everything below still describes what turning it
  back ON does, and all of it still works and is tested.)* Sam: *"I want to be able
  to cut all the way down to the roots on the trunk, get that working"*, and a day earlier
  *"I still want the player to have the option to cut the roots and lower part of the trunk
  though, this shelf looks really bad and just feels like a removal of player agency."* The
  shelf WAS the uncarveable imported roots piece: the voxel band's floor sat on top of the
  root flare, so a cut that went right through the stem left the flare standing as a plinth.
  **M5 198/203** (was 197/203 with the switch off — strictly better; the 5 remaining are the
  documented pre-existing tuning failures). `tree_species_smoke` **53/53** (was 43),
  `forest_smoke` 46/46, `fps_smoke` 14/14, `felling_smoke` 11/11, slicer 34/34, M4 16/16,
  M1 21/21, M3 16/16. No contract touched.
  - **The geometry was already built and switched off** (`WoodVolume._fill_from_mesh` +
    `_sweep`, 2026-07-30): the flare is filled into the SAME field from the trunk's own
    triangles instead of from the radial profile, which cannot describe a buttress you can
    see daylight under. What follows is what it cost to actually turn on. **The lowest a blow
    may land drops from 0.60 m / 0.80 m to 0.20 m on the two species**, and the band's floor
    goes to the dirt.
  - **THE STUMP COLLIDER WAS THE REAL BLOCKER, and it is a general bug the roots merely
    exposed.** `_build_stump_body` was a measured neck cylinder on top of a full-width base
    one, and the neck's height had a MINIMUM of `_NECK_BAND` (0.35 m). Cutting low makes a
    stump SHORTER than that — so the neck became the whole stump, **the base collider was
    never built at all**, and what remained was one small disc sized off the notch's remnant
    and sitting at that remnant's centre. MEASURED: 0.5 m off the trunk's axis on both
    species, with a ray at ankle height passing straight THROUGH at 0.1, 0.2 and 0.4 m. The
    base cylinder was also `radius` — the STEM's — while a stump that is mostly root flare is
    far wider (tree_01: 2.433 m² at the dirt against the stem's 0.82).
    - Replaced by **a stack of slabs following the wood**, level by level, off `sections()` —
      the CARVED field, so the notch is still honoured and a trunk that lands back on the
      stump still sits on the holding wood rather than a disc that was never there. That was
      the neck's whole purpose and it survives as a property of the measurement instead of a
      special case. `_NECK_BAND` is retired; `_STUMP_SLAB` (0.2 m) is a discretisation like
      `_BRANCH_BIN`, not a tuning value. Below the band (roots off) there is no field to read,
      so `timber_slices` measures the source mesh there — which also makes the roots-off stump
      comprehensively better: 4 slabs tracking the flare from r=1.64 at the dirt to r=1.25,
      where it used to be one r=0.51 cylinder.
  - **CUT FACES IN THE FLARE RENDERED AS A FLAT GREY PATCH, and it is the THIRD time this
    mapping has overflowed on a path nobody had measured** (after the slicer's `cap_fit_round`
    on 2026-07-27 and the band's own `ring_radius` on 2026-07-29). `_cut_mat` is a SINGLE
    growth-ring disc on a WHITE field with `texture_repeat` off, so anything mapped past its
    edge clamps to that white; tinted by `cut_wood_tint` that is flat grey. The round was
    fitted to `profile_max_radius`, the widest RADIAL PROFILE — and `voxel_roots` deliberately
    builds the profile from the clear stem only (`_build_profile`'s `skip_below`, so the
    artist's root-island UVs cannot poison the bark fit) while filling the buttresses from the
    mesh. So the fit did not know they existed: **0.67 m against a flare reaching 1.81 m.**
    - **Fixed PER LEVEL** (`WoodVolume.ring_prof` / `ring_at`, filled by `TreeTrunk` from
      `level_stats` before the first remesh, so it is the UNCUT wood and the rings cannot
      breathe as the player chops). One radius cannot serve this band any more, and BOTH ends
      were rendered to prove it: widening the single radius to cover the buttresses fixes the
      grey and leaves a STEM cut using only the inner 41% of the disc, dark and ringless.
    - **This reverses the "MEASURED AND REVERTED, do not retry" note of 2026-07-30**, and the
      reason is honest: that measurement was taken without `voxel_roots`, where the band is
      clear stem tapering ~1.3x and a per-height fit genuinely changed nothing. With the flare
      in the band the range is 2.4x and it is the difference between wood and a grey patch.
    - m5's own ring-centring check was computing its expected UV from the scalar
      `vol.ring_radius` — i.e. from a scale no vertex is mapped with any more. It reads
      `ring_at(vertex.y)` now.
  - **TWO SUITE FAILURES THAT LOOKED LIKE ROOTS REGRESSIONS AND WERE NOT.** Both are logged
    in `handoff/09` §2 as blockers for this switch; both turned out to be the checks.
    - **"a trunk bucks out into about `buck_target_logs` logs (1 cut for a target of 5)."**
      Bucking is PROVABLY IDENTICAL with the switch on and off — `roots_probe` runs the same
      cut sequence both ways and gets the same 3 cuts / 4 lengths. The test drove
      `debug_buck`'s default, which halves a length, and **repeated halving cannot reach the
      target by construction**: with the minimum at L/target, L gives two L/2 and each gives
      two L/4, which is already under twice the minimum. Four pieces maximum for a target of
      five. It passed only because the last halving landed a hair the right side of
      `2 x min_log`, and `voxel_roots` moving the timber from 5.72 m to 6.32 m tipped it. The
      loop now takes **a log off the END each time**, which is how a faller bucks a trunk and
      the only way the spec can be measured, and the assert is on LOGS not cuts.
    - **"...and it is solid timber, not scenery you can walk through."** A ray across the
      trunk's axis at 0.2 m — which stopped meaning what it meant the moment the flare became
      carveable, because the notch that fells the tree now genuinely removes the wood at ankle
      height. It passed through a stump that was solid from the dirt to 0.165 m and would stop
      a walking player dead. **A ray at one height cannot tell "you can walk through this"
      from "there is a notch at exactly that height", and the player is a 1.8 m capsule, not a
      horizontal line.** It is asked with the player's own capsule now.
  - **WHERE THIS SUITE PUTS ITS NOTCH IS NOW DERIVED, not a bare 0.5 m** (`_stem_y`, the
    default for `_notch_to` / `_chop_until_fell`). 0.5 was unambiguous while the flare was
    uncarveable — `band_lo` sat on top of it, so 0.5 was clamped up onto the stem on both
    species anyway. With the axe reaching the roots, 0.5 is INSIDE tree_01's flare, and that
    is a different cut with a different answer (below). The notch goes just above the flare
    now, per asset, because Sam re-exports these trees.
  - **A REAL BEHAVIOUR CHANGE, and it is Sam's to accept or tune: CUTTING INTO THE FLARE GIVES
    AN UNCONTROLLED FALL.** A buttressed section is genuinely much stronger — wide area, large
    second moment — so stress stays low while the player keeps chopping, and the level is cut
    CLEAN THROUGH before the load model fails it: measured on tree_01 at 0.5 m, blow 12 leaves
    0.20 m² at stress 0.35, and three blows later the level is at 0.0019 m² and collapses with
    no hinge. It is realistic (it is the manual's own reason for notching above the flare) and
    it is not a crash — the tree falls, the timber bucks, the yields pay. But **cutting at the
    LOWEST allowed height fells both species with an INTACT hinge** (tree_02 12 blows,
    tree_01 17), so it is specifically the flare's shoulder that behaves this way. The levers
    are `crush_strength_kpa`, `bend_strength_kpa`, `fail_stress` and `bite_depth`, all
    Directive 3 numbers — **I did not touch them.**
  - **The blow's face probe was already fixed for this** (2026-07-30): it started at 2.5x the
    STEM's radius while the flare reaches 2.8x, so it began INSIDE the wood and the slab was
    built entirely outside the trunk — tree_01 became unchoppable while tree_02 was fine.
    `_cut_slab` sizes off `band_max_radius`. **Any future widening of the band must check it.**
  - **Cost, and it is why this stays a switch:** the grid goes from 35x56x35 to 61x63x61 on
    tree_02 and 30x56x30 to 71x67x71 on tree_01, because `band_max_radius` has to reach the
    buttresses. With `prebuild_stand` on, that lands at forest entry.
  - New dev tool: **`core/tools/roots_probe.gd/.tscn`** — runs each species with the switch
    off and then on and reports what differs: band, grid, aim range, the per-level areas and
    reaches the load model reads, a per-blow trace tagged HINGE or COLLAPSE, the break, the
    bucking sequence, and the stump's collider with rays through it. `AIM_AT` at the top picks
    between "as low as the game allows" and a fixed height.
  - New test seams: `TreeTrunk.debug_base_area`/`debug_flare_top`/`timber_slices`,
    `tree_felling.debug_min_cut_height`/`debug_evaluate`, `WoodVolume.ring_at`.
  - **NOT eyeball-verified by Sam.** Render-verified under gl_compatibility
    (`core/tools/butt_shot.tscn`): roots present and carveable with no plinth, a cut in the
    flare reading as wood with grain rather than a grey patch, and stem cuts still showing
    their rings.
- **FIXED 2026-07-30 (third round) — A FELLED TRUNK NO LONGER SINKS THROUGH THE FLOOR. THE
  COLLIDER FOLLOWS THE WOOD.** Sam, live: *"when a tree falls, the top half penetrates
  through the floor."* This was the item `handoff/09_TRUNK_SEAMS_AND_ROOTS.md` §1 flagged as
  "the thing to fix first", diagnosed there to two candidate causes — and **it was neither of
  them.** M5 **197/203** (was 193/199: four new guards, all green; the same six documented
  pre-existing failures). `forest_smoke` 46/46, `tree_species_smoke` 43/43, `fps_smoke` 14/14,
  `felling_smoke` 11/11, slicer 34/34, M4 16/16. No contract touched; nothing tunable added.
  - **THE CAUSE: the falling trunk got ONE cylinder on the body's local Y axis through its
    origin, and the timber is not a straight column standing on that origin.** Two things push
    it off, and they compound:
    - **the body's origin is the HINGE** — `detach_above` re-origins every mesh on the failing
      section's CENTROID, which a deep notch drags to the back of the remaining wood, so the
      wood is off the collider's axis from the butt up (MEASURED: 0.46 m on tree_02, against a
      cylinder radius of 0.49 — already most of a radius before the tree has leaned anywhere);
    - **the generator leans and wanders every trunk it makes**, which is already logged for the
      voxel band's axis, and it keeps going above the band: 3.08 m off that axis by the top of
      tree_02's timber.
  - **MEASURED, and this is the number that settles it: 74.1% of tree_02's timber vertices were
    OUTSIDE the collider, the worst by 2.719 m** (tree_01: 66.3%, worst 1.260 m). So the
    `WoodyCrown` had nothing under it at all and came to rest **2.648 m below the dirt**
    (tree_01: 0.355 m). After the fix: **0.9% / worst 0.009 m, and 0.000 m below the dirt — it
    rests on the ground** (tree_01 0.7% / 0.005 m / 0.000 m).
  - **THE FIX: `TreeTrunk.timber_slices()` reports the timber's shape as a stack of slabs on
    its OWN measured centre line, each with its own measured radius, and `_fit_trunk_collider`
    builds one cylinder per slab.** ~13 shapes in one compound body — no extra rigid bodies, so
    **A12's budget is untouched**. It needs no new measurement pass and no tuning number: the
    per-height centre and width come from the SAME single cross-section scan `_centre_off`
    already comes from (`_width_bins`), which is why `_build_standing_body` was already
    correct — the standing collider has always read `centre_offset(y)`. Only the falling one
    assumed a straight column. `_bin_radius` is that scan's width array, now retained.
    - The radius is deliberately CONSERVATIVE: each slab covers every bin it spans, that bin's
      own centre drift plus that bin's own width. A collider slightly fatter than the wood
      rests a felled trunk a little high; one that misses the wood drops it through the world,
      and only one of those is a bug you can see. Render-verified that it does not read as
      floating (`core/tools/tree_shot.tscn`, `_9_settled`).
  - **BUCKED LENGTHS HAD THE SAME BUG and are fixed the same way.** `_new_log` centred its
    cylinder on x = z = 0 too, and a section off the leaning top of a trunk inherits the whole
    trunk's origin — which is where the 3.08 m of drift lives. `_fit_log_collider` gives each
    section the slabs that fall inside it, clipped to its own sawn ends. The slices stay valid
    across cuts because **every bucked section keeps the frame the whole trunk had** (`_new_log`
    copies the parent's global transform and the meshes keep their local ones), which is the
    same fact `_log_span`'s own comment already rested on.
  - **TWO SEAMS THAT READ THE COLLIDER AS IF IT WERE ONE SHAPE, and the second one is the
    interesting one.** `_log_length`/`_log_span` returned the FIRST cylinder they found — half a
    metre for a six-metre trunk — so they now UNION every cylinder in the body. And
    `debug_buck`'s default cut point was **the LAST `CollisionShape3D`'s own `position.y`**,
    which meant "the middle of the log" only while a length carried exactly one cylinder; with a
    stack it is the slab at the far END, so the default cut went to the tip and clamped against
    `buck_min_length` instead of halving the log. **That cost 3 M5 checks and was the only
    regression the whole change produced** — worth remembering that a collider is now a
    compound, and anything reading one shape out of it is asking the wrong question.
  - **NEW GUARDS in `m5_acceptance`, and all four were verified to FAIL with the fix reverted**
    (66.3% outside, worst 1.260 m, sunk to y -0.493). The check that was already there —
    `_has_shape`, "it has a collider to land on" — is exactly the vacuous kind this project
    keeps getting bitten by: **a cylinder can span the whole trunk and still sit beside it**, so
    it passed throughout. It now measures CONTAINMENT (what fraction of the timber's vertices
    fall outside the collider, and the worst miss in metres) plus, at settle, that the lowest
    wood VERTEX is not below the dirt.
  - **MEASUREMENT TRAP, and it produced a confident wrong answer first: never measure a fallen
    trunk with `xform * mesh.get_aabb()`.** Transforming an AABB gives the box bounding the
    ROTATED BOX, not the rotated mesh, so a horizontal trunk reads as metres deeper than it is.
    The first run of the new probe reported 0.37 m of sinking that was not there. Sample
    VERTICES. (Same family as "26 samples is not a measurement" in handoff/09 §4.)
  - **`core/tools/tree_shot.gd` WAS SILENTLY RENDERING A STANDING TREE, and had been for five
    days.** Its fall shots drove 40 blows at `side = -1` expecting a back cut — but PASS 6
    (2026-07-25) removed the back cut, so a blow on the far side opens a SECOND independent
    notch instead of eating toward the first, and the tree never fell. `_5_hinging`,
    `_6_going`, `_7_over`, `_8_down` and `_9_settled` came out BYTE-IDENTICAL. Fixed to chop
    head-on like every other tool; tags kept so the shots still line up with older ones. **Any
    claim that the fall or the settled trunk was render-verified after 2026-07-25 was resting on
    those frames** — this is the first render of a felled trunk actually on the ground since.
  - **§2 (`voxel_roots`) IS NOT THE SAME BUG, and handoff/09's expectation that "both should go
    together" is disproven.** With the switch on, the falling collider is fine (2.0% / worst
    0.139 m on tree_02, wood above the dirt) and M5 is 194/203 — its two named failures ("bucks
    out into about `buck_target_logs` logs (1 cut for a target of 5)" and "solid timber, not
    scenery you can walk through") are STILL THERE, alongside "there was still holding wood
    when it went" and a hinge measuring 0.000 m. That points at the LOAD MODEL and the STUMP
    under a band that starts at the ground, not at any length or collider. The switch still
    ships OFF, and its own blocker (the roots' bark mapping, handoff/09 §2) is untouched.
  - New dev tool: **`core/tools/trunk_collider_probe.gd/.tscn`** — fells each species and asks
    whether the collider CONTAINS the wood in the body's own frame, then where the lowest wood
    vertex ends up. It swaps the legacy single cylinder back in mid-fall, so the A/B is one run
    and one asset (the `bark_ab_shot` pattern). `VOXEL_ROOTS` at the top measures §2's config.
  - **NOT eyeball-verified by Sam.** Render-verified under gl_compatibility: the felled trunk
    lying on the dirt beside its stump, splinters at the break, canopy correctly shed.
- **FIXED 2026-07-30 — "THE TEXTURE LOOKS DIFFERENT AND IS STRETCHING." IT IS THE CHOP
  CUT, and the fifth-round entry below chased the wrong thing.** Sam, rejecting that
  round: *"It's actually not a hairline at all. It's a significant texture issue and we
  cannot ship unless it is resolved"*, with a close screenshot of a pale streaky ribbon
  wrapped round a trunk. Sam was right and the earlier diagnosis was wrong; what follows
  is what the ribbon actually is. M5 **193/197** (was 191 — two new guards, and the six
  remaining failures are the documented pre-existing ones), `tree_species_smoke` 43/43,
  `forest_smoke` 47/47, `fps_smoke` 14/14, `felling_smoke` 11/11, slicer 34/34, M4 16/16.
  No contract touched.
  - **HOW THE FIFTH ROUND MISSED IT, because the lesson is the reusable part: it measured
    a tree that had never been struck.** `bark_ab_shot` rendered "before and after the band
    replaces the trunk", which is not what Sam said — Sam said *after it is cut*. It also
    framed the butt from 2.6 m looking DOWN from eye height, which foreshortens a 5 cm
    strip into a hairline. Chop the tree and stand where the player stands and the ribbon
    is unmissable. **Reproduce the verb in the report, not the noun.**
  - **THE RIBBON IS THE END-GRAIN PROJECTION ON FACES THAT ARE NOT END GRAIN.**
    `WoodVolume._cut_vertex` maps a cut face by projecting the trunk's cross-section onto
    the HORIZONTAL plane (Amendment-era `ring_radius`, 2026-07-25). That is right for the
    roof and floor of a notch — Sam's "we'd see rings if that's how we were really cutting
    it" — and catastrophic for a face that is nearly VERTICAL, because a vertical surface
    projected onto a horizontal plane has almost no UV variation up its height: one row of
    texels is smeared its whole height. The axis-aligned planar path directly below it,
    written for exactly this and commented *"so a fresh face wears straight grain rather
    than a stretched wrap"*, had been DEAD FOR TREES ever since, because `ring_radius > 0`
    took every face.
    - **The shipping settings are what make it dominant.** `tree_felling.tscn` chops with
      `bite_depth = 0.03` on a `voxel_cell` of 0.055 — barely a voxel deep — so a blow
      leaves a shallow wide scallop that is mostly steep wall and hardly any roof or floor.
      Testing with a 6.5 cm gouge (mostly roof and floor) understated it badly. **Dev tools
      that pin their own tuning must pin the SHIPPING values when the question is "what
      does the player see".**
  - **THE FIX: a cut face wears the grain the axe actually exposed.** `WoodVolume.side_mat`
    is a second cut surface for faces that run ALONG the grain — the near-vertical walls a
    chop leaves down the side of a trunk — mapped by the axis-aligned planar path in
    metres. Cross-cut faces keep the rings. It is the same distinction the game already
    makes for SPLINTERS, which have always had their own long-grain material rather than
    rings, and `_side_mat` is that material with `uv1_scale` reset (the mesher bakes the
    mapping into the UVs, the rule `_cut_mat` already follows).
    - **A quad is routed by its LEAST cross-cut corner, not by the average.** One steep
      corner is enough to smear a quad, and long grain has no failure mode — so an
      ambiguous face goes to the side that cannot be wrong. Measured on a shipping-settings
      chop: 104 of 157 cut vertices take long grain.
    - `_END_GRAIN_TILT` (0.5, i.e. 30 degrees of tilt off horizontal) is the threshold. It
      sits well below the manual's own notch angles and well above a kerf wall.
  - **AND THE FRESH WOOD WAS BLOWING OUT TO WHITE, which is why it read as a smear rather
    than as wood.** MEASURED on a shipping-settings chop before the fix: mean cut-face RGB
    (215, 180, 120) with **29% of its pixels clipped to pure white**. Both wood textures are
    painted light, and this scene runs `light_energy` 0.75 over 0.45 ambient with filmic
    tonemapping. White carries no texture at all, so no amount of correct mapping survives
    it. New **`cut_wood_tint`** (`@export`, PLACEHOLDER per Directive 3 — Sam's to set)
    tints the exposed-wood materials: mean (191, 128, 64), **0% clipped**, and the notch
    now reads as wood with grain in it.
  - **NEW GUARDS in `m5_acceptance`, both verified to fail without their fix:** every
    vertex on the long-grain surface matches the axis-aligned planar mapping **for its own
    normal** (the axis choice is per vertex, not per face — that is what keeps a corner
    between a floor and a wall from stretching either), and **no near-vertical face is left
    on the horizontal ring projection**, which is the property the smear violated. The
    existing ring-centring check was reading `get_surface_count() - 1` and silently
    measured the new surface; it now selects by MATERIAL.
  - MEASURED AND REVERTED, do not retry: fitting the end-grain round PER HEIGHT rather than
    to the widest wood in the band. It is arguably more correct on a band that tapers
    threefold, but it produced no visible change and it breaks the documented
    "`ring_radius` covers the widest wood so no cut face clamps to white" invariant. Not
    worth the invariant without a picture to justify it.
  - **NOT eyeball-verified by Sam.** Render-verified under gl_compatibility
    (`core/tools/bark_ab_shot.tscn`, which now chops with the shipping settings and frames
    the cut from where the player stands, and renders the same cut with the routing
    switched off for a one-run A/B).
- **PARTLY FIXED 2026-07-29 (fifth round) — SUPERSEDED, and mostly a wrong turn. "THE TEXTURE LOOKS DIFFERENT AFTER IT IS CUT."
  It is not the texture. It is the ring where the imported roots mesh hands over to the
  voxel band, and it is a GEOMETRY hand-over, not a mapping error.** Sam, with before/after
  screenshots and two arrows on the line: *"the tree looks fine before its cut, but after it
  is cut the texture looks different and is stretching in some spots"*. Reproduced,
  attributed and measured; one cause removed, the residual understood and documented rather
  than papered over. Suites unchanged: M5 191/197 (the documented same-asset baseline),
  `tree_species_smoke` 43/43, `forest_smoke` 47/47, `fps_smoke` 14/14, `felling_smoke` 11/11,
  slicer 34/34, M4 16/16. No contract touched.
  - **REPRODUCED AND LOCALISED TO ONE PIXEL ROW.** New `core/tools/bark_ab_shot.gd/.tscn`
    renders the SAME tree from the SAME camera before and after the band replaces its trunk
    (a stand of two is planted, because `_spawn_stand` deliberately builds the one the player
    starts next to, so the other one is the only "before" there is). Differencing the pair
    row by row: the whole trunk differs by a flat ~0.02 (the voxel surface is a different
    surface — expected), and **exactly one row carries a hard new edge, at `_root_top`**,
    where the roots' mesh stops and the band begins. Nothing else in the image has an edge
    that the uncut tree does not. That row is Sam's line.
  - **THE BARK MAPPING IS EXACT, and this was worth proving because it is the obvious
    suspect.** New `core/tools/bark_uv_probe.gd/.tscn` compares `WoodVolume`'s fitted wrap
    against **the source mesh's own vertex UVs**, at each vertex's own height and bearing
    (u modulo one texture repeat, since a whole repeat away is the same texel). Result on
    tree_01: **worst |du| and |dv| both 0.000 over every bark vertex in the band.** The
    2026-07-26 fit is doing exactly what it claims. Do not go looking there again.
    - **AND A MEASUREMENT TRAP THAT COST MOST OF A DAY, recorded so nobody repeats it.** The
      first version of that probe measured the source by casting one ray per bearing and
      keeping the FARTHEST hit — the same rule `_build_profile` uses. It reported the trunk's
      u mapping as repeating TWICE round the ring, which is a coherent, plausible reading
      (v repeated on the same period), and a whole sector-aware unwrap was built on it before
      the mesh's own vertices showed the mapping wraps ONCE, cleanly, with a single seam. A
      ray keeps whichever of several coincident surfaces it happens to hit; a vertex is the
      art. **Measure art against its vertices.** The sector work was reverted in full.
  - **WHAT SHIPPED: the roots' cut cap is BARK, not end grain** (`MeshSlicer.slice(stem,
    Plane(UP, _root_top), _bark_mat, true)` in `TreeTrunk.build`). Every other cut face in M5
    is a fresh axe cut and wants growth rings; this one is a seam between two halves of the
    same standing tree and is never meant to read as a cut at all. It is also the one cap
    that is not reliably buried — the band's radius lands on either side of the imported
    wall's by about a quarter of a cell, so on some bearings a sliver of it shows. In
    `_cut_mat` that sliver is a bright ring on a WHITE field against dark bark, which is the
    most legible thing that could possibly be there. **Measured: the sharp join row's excess
    edge drops 0.0127 -> 0.0068 (-46%), worst anywhere in the join band 0.0127 -> 0.0093,
    and the bright sliver is gone from the render.** The crown's cap is left as `_cut_mat`:
    it is the same kind of seam, but it is buried in the shipping arrangement and this pass
    did not measure it — do not change it on the strength of this note alone.
  - **THE RESIDUAL IS INHERENT TO THE HAND-OVER, and three attempts to remove it all made
    the render WORSE. They are listed so they are not tried again:**
    - **Pinning the band's rendered radius to the profile the field was built from.** Moved
      the line without removing it: that profile is sampled at grid LEVELS and the clip plane
      falls between two of them.
    - **Pinning it to the imported piece's own rim vertices** (measured off the sliced mesh,
      exact by construction). Removed the join row outright — and tore the surface for two
      cells around it, because pinning individual surface-nets vertices onto a ring makes
      neighbours that pass and fail the "is this still uncut bark?" guard disagree.
    - **Inverting the bottom ramp** so the band is fully tucked in AT the rim and opens out
      above it, plus the bark cap. Killed the crack and replaced it with the roots' rim
      standing proud as a dark overhang all the way round.
    - **The reason none of them can work is worth stating once:** surface nets is a DUAL
      method — its vertices sit inside cells, not on the isosurface — so the band's surface
      cannot be made to pass through the imported mesh's rim by construction. Two
      independently generated surfaces must hand over somewhere, and whichever is outermost
      at that height shows its rim. Every arrangement trades one visible edge for another.
    - **What would actually remove it is ART, not code: a bark collar or root-flare ridge
      authored at the hand-over height, so the boundary coincides with an edge the eye
      already expects.** `_root_top` is `band_lo + 2.5 cells` and `band_lo` is the top of the
      root flare (`_root_flare_height`), so the generator knows where to put it. Sam's call.
  - **The line survives an UNSHADED render**, which is how the normals were ruled out — it is
    silhouette and occlusion, not the imported mesh's authored normals meeting the band's
    SDF-gradient ones. (That tonal difference is real and is the already-logged crown-join
    finding, but it is not this.)
  - New test seam: `WoodVolume.debug_bark_uv_at(y, ang)`. Nothing measured the fitted mapping
    against the art before this, which is why "the bark is the right SIZE" has twice been
    mistaken for "the bark is right".
  - **NOT eyeball-verified by Sam.** Render-verified under gl_compatibility only.
- **FIXED 2026-07-29 — M4 STOPPED SPAWNING LOGS, and the cause was M5's mesh loader.**
  Sam: *"The chopping minigame no longer is spawning in logs."* Nothing errored and no test
  went red; the block was simply bare. `MeshUtils.mesh_from_scene` started BAKING the
  transform authored on an imported FBX's `MeshInstance3D` (2026-07-27, so `tree_02`'s 180x
  node scale would stand at its authored height without a guessed override) — and the M4 logs
  carry scales of their own: **log_01 33.88x, log_02 31.59x**. `log_scale = 13.0` was authored
  against the RAW mesh (0.032 m tall) and so produced a **14 m log** standing on the block with
  the camera inside it. The bark culls from the inside, so it read as no log at all.
  - `log_scale` is REPLACED by **`log_height` (0.42 m, what 13.0 gave before)** and the scale is
    derived per mesh in `_fit_scale()` from its own measured height. A bare multiplier means
    whatever units the artist exported in; a target height cannot drift that way again, and it
    sizes every species alike. The `log_scale = 13.0` override is gone from
    `chopping_minigame.tscn`. Placeholder per Directive 3 — it restores Sam's existing value's
    effect, it does not re-tune it.
  - **WHY 16/16 STAYED GREEN THROUGH IT:** every M4 check is relative (piece counts, one hit
    per slice, yields, the A12 budget) or measures extents against each other. A 14 m log slices
    into two plausible halves exactly like a 0.42 m one. The same shape as the `plane_to_local`
    find — **it was caught by RENDERING it** (`core/tools/shot_runner.tscn`), which is also how
    it is verified fixed: the round is back on the block and cuts shed firewood onto the pile.
  - The stump and the axe are unaffected — the stump FBX carries no node scale, and `axe_rig`
    instantiates the imported scene rather than pulling a mesh out of it.
  - Re-verified: M4 acceptance **16/16**, `chopping_smoke`, `pile_smoke` 3/3. NOTE `pile_smoke`
    must be run NON-headless as its own docstring says — its last check waits out the pile
    animation, which runs on a real-time clock that uncapped headless frames outrun.
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
  the firewood the player splits on the block is ~0.42 m (`chopping_minigame.log_height`;
  it was `log_scale` 13.0 against a 0.033 m import when this was measured) — the old 0.7 was
  longer than the log it was meant to produce. Placeholder per Directive 3. New `_test_16` asserts no cut ever leaves
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
