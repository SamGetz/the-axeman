# AGENTS.md — The Axeman (log-cutting game)

You are the Lead Gameplay Programmer and Technical Engine Architect. The human
user (Sam) is the Creative Director. This file plus the Master Project
Blueprint are your absolute source of truth.

**Engine:** Godot 4.7 (stable) · **Renderer:** Compatibility
(`gl_compatibility`) · **Language:** GDScript only, native nodes only, no
third-party plugins, no invented APIs.

---

## THE PIVOT (2026-08-01) — READ THIS FIRST

Sam's direction: *"Time for a big pivot. I want to just focus on the 'chopping
game'. We can remove anything relating to the tree felling game. I want the new
scope of the game to just be a 'number go up' game, where you are a log cutter.
Since the core gameplay of the log cutting already feels awesome, lets clean up
the game and keep the scope around the log cutting game."*

**The tree-felling game (M5) is GONE.** Every file belonging to it — the voxel
wood volume, the hinge fall, the FPS forest player, the stand of trees, the
bucking, the 22 forest/seam dev tools, `m5_acceptance`, `TreeDef`,
`pine_tree.tres` and 53 MB of tree art — was deleted on 2026-08-01. It is all
recoverable from git (see below); it is not coming back unless Sam says so.

**What the game is now:** a cozy "number go up" lumberyard game built around
M4's tactile chopping — a log on a block, click to slice it into firewood, then
turn that satisfying work into stock, fulfilled orders, cash, reputation and a
steadily growing yard. Manual chopping remains the central and most valuable
interaction for the entire game.

**THE PROJECT IS NOW UNDER GIT.** The repo root is
`C:\Users\Sam\Documents\the_axeman\` (the whole thing, not just the Godot
project). Two commits exist:

| Commit | What |
|---|---|
| `29bcd6f` | The full working state *before* the pivot — M1–M5, the forest, all tree art. |
| `38b4425` | The pivot: everything tree-related removed. |

`.godot/` and `*.log` are gitignored. **Commit as you work now** — the safety
net exists, use it. Nothing has been pushed to a remote; there is no remote.

### APPROVED POST-PIVOT DIRECTION (2026-08-01)

Sam approved the full cozy-lumberyard recommendation and the roadmap in
`handoff/08_COZY_LUMBERYARD_ROADMAP.md`:

1. **M6 ore mining is retired from the active roadmap.** Its old spec and live
   data files remain archival until Sam separately asks to delete them. Mining
   must not be implemented as a second action loop.
2. **M7 is re-scoped to lightweight lumberyard progression and orders.** Cash,
   firewood stock, reputation and lifetime wood chopped are the progression
   spine. The yard grows visibly alongside the counters.
3. **M8 is reinterpreted as optional yard staff and logistics.** Staff may
   deliver logs, gather, stack, bundle, ship and run passive secondary
   production. They must never make manual chopping obsolete.
4. **Biomes may return only as wood-supply regions**, not explorable FPS forest
   levels. They unlock species, customers and contracts.
5. **Tone is cozy lumberyard first**, with restrained absurd escalation only
   after the grounded chopping-and-yard fantasy is established.

Exact prices, payout multipliers, timing values and upgrade magnitudes are still
tuning decisions. Do not invent them in code: present them to Sam as resource
values/placeholders and tune with Creative Director sign-off.

### OPEN — cleanup calls, do not invent answers

1. `slice_poc.tscn` still sits in `scenes/3d_action/` — a leftover from the
   2026-07-22 rename, a second harness pointing at `chopping_minigame.tscn` at
   the old 960×540. Harmless, probably wants deleting; not touched in the pivot
   because it is an M4 file, not a tree file.
2. The stale root-level `core/` and `data/` duplicates (see ASSET PIPELINE) had
   `data/tree_def.gd` removed as part of the pivot, because Sam said "any and
   all files relating to the tree game". The rest of that stale mirror is
   untouched, and `handoff/00_OVERVIEW.md` still says not to delete it.

---

## CURRENT PROJECT STATUS (as of 2026-08-01)

Suite results, all re-run after the pivot on the shipping assets:

| Suite | How to run | Result |
|---|---|---|
| M1 | `--quit-after 900 res://core/tests/m1_acceptance.tscn` | **21/21** |
| M2 | `--quit-after 900 res://core/tests/m2_acceptance.tscn` | **21/23** — both failures are the A1 finding below |
| M3 | `--quit-after 900 res://core/tests/m3_acceptance.tscn` | **16/16** |
| M4 | `--quit-after 8000 res://core/tests/m4_acceptance.tscn` | **16/16** |
| Slicer | `-s res://core/tools/test_slicer.gd` | **34/34** |
| Chopping smoke | `--quit-after 8000 res://core/tools/chopping_smoke.tscn` | green |
| Pile smoke | `res://core/tools/pile_smoke.tscn` | **must run NON-headless** — its last check waits out the pile animation, which runs on a real-time clock that uncapped headless frames outrun |

Engine binary: `C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe`.
Godot project: `C:\Users\Sam\Documents\the_axeman\the-axeman\`.

- **M1 (Core Contracts): DONE, signed off.** 21/21. Red errors during tests
  2, 5, 7, 8 are EXPECTED; only `FAIL:` lines are failures.
- **M2 (main scene shell + pixel pipeline): DONE, functionality accepted;
  art direction deferred by Sam.** Known: SpotLight3D `light_projector` gobo
  does not render under gl_compatibility (see Amendment 9 — replaced in the
  chopping scene by an animated shadow-cutout gobo); the game boots to empty
  2D mode by design, and the temp **M key** in `scenes/main.gd` toggles into
  the 3D chopping scene.
- **M3 (GameFeel): code DONE, awaiting Creative Director sign-off.** 16/16.
  GameFeel is the 4th autoload (Amendment 5). Hit-pause overlap guard, trauma
  camera shake (h/v offset), `register_impact`, A7 wiring all verified. Temp
  debug: **H key** in `scenes/main.gd` fires a hit while in 3D mode.
  All pause/shake numbers in `game_feel_config.tres` are still placeholders —
  tune live with Sam.
- **M4 (the chopping game — now THE game): INTEGRATED, awaiting Creative
  Director sign-off.** Sam has said the core cutting "already feels awesome".
  Details below.
- **Autoloads**, in this order: `EventBus`, `InventoryManager`, `GameState`,
  `GameFeel`, then the godot_mcp service autoloads (uid:// refs in
  `project.godot` are normal). `res://core/enums.gd` is class_name only —
  NEVER an autoload.

### M4 — the chopping game

`main.tscn`'s `3D_World_Root` instances
`res://scenes/3d_action/chopping_minigame.tscn` (root Node3D runs
`chopping_minigame.gd`). `chopping_minigame_harness.tscn` is an F6 feel-test
harness that instances the same scene inside a viewport. Enter it from the main
scene with the temp **M key** in `scenes/main.gd` (the A10 2D/3D toggle) until
the real entry flow exists.

- **The slicer is Amendment 6's runtime plane cut.** Each click cuts the log
  along a camera-inferred angle and caps the cut face; sliver cuts round up to
  a minimum piece size. `size_tier` is COMPUTED at slice time, and A3's single
  size test is unchanged.
- **Viewport** is 1280×720 + NEAREST (Amendment 8 — the pixel-art look was
  dropped). See the A1 finding below: what is authored is not what runs.
- **Ground:** `res://assets/models/forest_floor/forest_floor_a.fbx` is instanced
  directly as a child node in `chopping_minigame.tscn` (scale 0.4, Sam-authored
  placement).
- **Inventory wired:** a fully-chopped log deposits its species' item into
  InventoryManager — one `resource_gathered` per finished firewood piece, at the
  batch-collect point (`_begin_stacking`). Wood type is data-driven: `_LOG_SPECIES`
  in `chopping_minigame.gd` maps each log mesh → yield item, built to scale to
  many woods (add a row). CURRENT PLACEHOLDER MAPPING:
  `log_01.fbx`→`oak_log`, `log_02.fbx`→`pine_log` (both still wear the oak inside
  texture — log_02 is pine only to demo per-log yields; remap freely, and
  per-species textures can join the same table later).
- **Acceptance:** `m4_acceptance.tscn` 16/16 — drives `debug_slice_world` to
  completion, checks inventory deposit == firewood count, per-species yield, one
  hit per slice, the A12 budget. It calls `get_tree().quit()` on finish, so run
  headless with a generous `--quit-after` backstop (e.g. 8000). NOTE: **the
  click-to-chop input layer is still NOT headless-verifiable** — Sam eyeball-tests
  clicking in F5/F6.
- KNOWN: firewood uses the mini-game's own `max_firewood` (40) soft cap for
  feel, not `fragment_physics_budget` (A12's nominal 24) — reconcile at tuning.
- **BUGFIX 2026-07-23 — sliced pieces shaded darker than the uncut log.**
  `MeshSlicer` carried only POSITION/NORMAL/UV across a cut, so
  `SurfaceTool.commit()` regenerated the tangent basis from the cut soup. Both log
  materials (`oak_bark`, `oak_top`) are normal-mapped, and the regenerated basis
  pointed ~90 deg off the FBX-authored one (import has `meshes/ensure_tangents=true`),
  so the normal map was read rotated. `mesh_slicer.gd` now carries ARRAY_TANGENT and
  ARRAY_COLOR through the slice, interpolating both at the cut (handedness/binormal
  sign is per-surface, never lerped); cut caps still use `generate_tangents()` because
  their UVs are built fresh there, and they emit white vertex colours so a
  `vertex_color_use_as_albedo` cut material can't multiply to black.
- **BUGFIX 2026-07-27 — cut-face UVs only ever worked BY ACCIDENT.**
  `MeshSlicer._build_caps` UV'd a cut face as the offset from its centroid **in
  metres**, which lands inside 0..1 only when the piece is about a metre across. The
  `cap_fit_round` argument fits the round to the cut face's OWN measured extent.
  **M4 deliberately keeps the metres mapping**, which is correct for its TILING cut
  material, and the slicer suite asserts exactly that.
- **BUGFIX 2026-07-29 — M4 stopped spawning logs.** `MeshUtils.mesh_from_scene`
  started BAKING the transform authored on an imported FBX's `MeshInstance3D`, and
  the M4 logs carry scales of their own (log_01 33.88x, log_02 31.59x) — so
  `log_scale = 13.0`, authored against the RAW 0.032 m mesh, produced a **14 m log**
  with the camera inside it. `log_scale` is REPLACED by **`log_height` (0.42 m, what
  13.0 gave before)** and the scale is derived per mesh in `_fit_scale()` from its own
  measured height. A bare multiplier means whatever units the artist exported in; a
  target height cannot drift that way again. **Why 16/16 stayed green through it:**
  every M4 check is relative, and a 14 m log slices into two plausible halves exactly
  like a 0.42 m one. It was caught by RENDERING it (`core/tools/shot_runner.tscn`).
- **Winding convention, pinned:** Godot's front face is the CLOCKWISE one — a
  triangle is seen from the side its right-hand-rule normal points AWAY from.
  `MeshUtils.winding_report()` plus checks in `test_slicer` assert the engine's own
  primitive first, so the convention itself is pinned rather than assumed. Getting
  this wrong makes geometry see-through under CULL_BACK, and it is invisible on any
  cut material (every one in the project is CULL_DISABLED).
- **`MeshUtils.plane_to_local` had always rotated the normal the wrong way** (fixed
  2026-07-27). A plane's normal transforms by the TRANSPOSE OF THE FORWARD basis;
  the code read `inv.basis.transposed()`, which for a rotation R evaluates to R, not
  Rᵀ. Identical to correct for any translation-only transform, which is why it
  survived — but M4 ROTATES pieces to their long axis before cutting them, so every
  slice of a turned billet was cutting on a plane rotated the wrong way round since
  M4 shipped. Guarded by 10 checks in `test_slicer` at five yaws including 310.8°.

### Files the chopping game owns

`scenes/3d_action/`: `chopping_minigame.gd/.tscn`, `chopping_minigame_harness.tscn`,
`mesh_slicer.gd`, `mesh_utils.gd`, `fragment_piece.gd/.tscn`,
`fragment_physics_budget.gd`, `piece_animator.gd`, `wood_pile.gd`, `axe_rig.gd`,
`canopy_gobo.gd`.

`core/tools/`: `test_slicer`, `chopping_smoke`, `chop_diag`, `pile_smoke`,
`pile_shot`, `shot_runner`, `jag_shot`, `inspect_log`, `inspect_stump`, `probe_log`.

### OPEN A1 FINDING (pre-existing, NOT fixed, and it has got worse)

`Action_Viewport.size` is authored 1280×720 in `main.tscn` but is **not that at
runtime** — `SubViewportContainer.stretch = true` resizes the child viewport to
the container's rect, and the container follows the project's base canvas
(`display/window/size/viewport_*`). That base canvas is **currently 640×360** in
`project.godot` (with a 1280×720 window override), so the game renders at 640×360
and the canvas_items stretch scales it up 2×. This is why `m2_acceptance` fails
**two** A1 checks now (21/23) where it used to fail one — the documented base was
960×540, so it has been changed in the Project Settings UI since.

Amendment 8's "render at 1:1, no upscale" is therefore not actually happening, and
this is very likely the "still kinda pixelated" Sam reported. Fixing it means either
raising the project base canvas to 1280×720 (a `project.godot` edit — **CLOBBER
TRAP**, walk Sam through the Settings UI) or dropping container stretch and sizing
the viewport in code. Sam's call; it touches A1, so it needs an amendment either way.

---

## OPERATIONAL RULES (summary of blueprint directives)

1. One module at a time, explicit Creative Director sign-off between
   modules. Never start the next module unprompted.
2. **Part A contracts are frozen.** Never add, rename, or retype anything in
   them. If a module genuinely needs a contract change: halt, propose it,
   wait for approval, update CLAUDE.md's amendment log, then resume.
3. Any artistic/mathematical tuning value (forces, timings, stage counts,
   shake amounts) → halt and ask for exact values. Never invent finals;
   placeholders live in `.tres` files, never hardcoded.
4. Verify any uncertain API exists in Godot 4.7 Compatibility before using it.
   Banned outright: real DOF (CameraAttributes), volumetric fog, SDFGI,
   DirectionalLight projectors, runtime mesh booleans/CSG on gameplay
   geometry (except where Amendment 6 permits), runtime volume computation.
5. Every script states its exact `res://` path and the node type it attaches
   to. Every scene states its full node tree.
6. Writes to inventory happen ONLY inside InventoryManager; writes to
   progression ONLY inside GameState (via EventBus signals or their own
   public methods). Everything else queries read-only.

### Lessons this project has paid for repeatedly

- **Assert a positive quantity, not just a bound.** Several checks have passed
  because they measured nothing — an empty list satisfying `INF >= 0.45`, a
  debris cap a short run never reached, a collider that spanned the trunk while
  sitting beside it. If a guard could pass on a game where the feature was
  deleted, it is not a guard.
- **Verify a new guard FAILS without its fix.** Every regression check in this
  project is expected to have been proven that way.
- **Render it.** The three worst bugs in this project's history (the 14 m log,
  the wrongly-rotated cut plane, the see-through geometry) were invisible to
  every numeric test and obvious in a single PNG. `core/tools/shot_runner.tscn`
  is the pattern.
- **`godot --headless --path . --check-only -s res://<script>` is one second**
  and settles whether a parse error is cascading. (Autoload identifiers read as
  "not found" under `--check-only`; that is expected, not an error.)
- **Physics CPU is not trustworthy headless.** `await physics_frame` measures
  wall clock, and headless still ticks at the project rate whatever the load.
- **A `Packed*Array` stored inside an `Array` is a VALUE.** `arr[j]` hands back a
  COPY, so appending to it in place writes into a temporary.
- **Measure art against its vertices, not against rays.** A ray keeps whichever
  of several coincident surfaces it happens to hit.

---

## FROZEN CONTRACTS — QUICK REFERENCE

(Full text is the Master Blueprint; this is the operative summary. If the
blueprint document is in the repo, it wins on any discrepancy.)

- **A1 pipeline:** SubViewport 1280×720 (amended from 960×540, Amendment 8,
  2026-07-22 — matches window resolution 1:1, no upscale factor),
  SubViewportContainer stretch=true + NEAREST filter (briefly tried LINEAR in
  Amendment 8, reverted the same day — at 1:1 scale there's no mismatch for
  NEAREST to pixelate, and LINEAR's interpolation read as a soft "bloom" next to
  bright highlights). `Action_Viewport.msaa_3d = 4x` (per-viewport override, NOT
  the project-wide MSAA setting which stays off — smooths jagged geometry edges
  without blurring; verified supported under Compatibility since Godot 4.3).
  `anisotropic_filtering_level = 3` on `Action_Viewport` (sharpens ground
  texture at grazing angles). `scaling_3d_mode` left at default Bilinear —
  FSR/FSR2 are NOT supported under the Compatibility renderer, verified via
  Godot docs; do not set it to FSR(1)/FSR2(2). Project stretch canvas_items/
  keep, no screen-space AA. Fake DOF = pre-blurred background texture/plane.
  Sun gobo = SpotLight3D with animated `light_projector` (superseded for the
  chopping scene by Amendment 9). Stop-motion feel = AnimationPlayer with
  discrete/stepped keyframes only. **See the OPEN A1 FINDING above — what is
  authored here is not what runs.**
- **A2 destructibles:** pre-authored fracture states only. (Its trees clause is
  moot — the tree game is gone. Ore, if it is ever built, still falls under it.)
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
  settle timeout; hard cap 24 active rigid bodies per action scene (oldest
  settled freeze first); long-term piles may consolidate to MultiMesh.

---

## APPROVED AMENDMENT LOG (Creative Director signed off in chat)

Amendments 10–15 governed the tree-felling game and are **RETIRED with it** —
they are preserved in git at `29bcd6f` and in this file's history, and they no
longer describe any code in the project. They are summarised at the bottom for
anyone reading old commits.

1. **FragmentDef gains `sub_fragments: Array[FragmentDef]`** (recursive).
   Empty = leaf (collectible; `yield_item`/`yield_amount` read only then).
   Non-empty = re-choppable; a successful hit swaps the piece for its
   sub_fragments. Chain depth per species = hit count (size-based
   difficulty). Splits start 2-way; multi-way later is data-only.
2. **InventoryManager exposes local signal
   `inventory_changed(item_id: StringName, new_count: int)`** — fires on
   every count change including consumption, so UI updates live without
   polling. Local signal, NOT added to EventBus (does not cross the 2D/3D
   boundary; A7 untouched).
3. **Non-increasing tier "upgrades" are warned and ignored** by GameState
   (gear and buildings). Revisit only if intentional downgrades become a
   design feature.
4. **Cost lists aggregate duplicate ids before affordability checks**
   (prevents partial-consume exploits). `remove_items` is atomic: all or
   nothing.
5. **GameFeel added as the 4th autoload** (`res://core/game_feel.gd`,
   registered after GameState, before the godot_mcp services). Rationale:
   A11 hit-pause is process-wide `Engine.time_scale` state that needs a
   single owner for the overlap guard. EventBus / A7 untouched —
   `register_impact()` is a public method, not a signal; GameFeel only
   *listens* to existing A7 signals (`action_hit_registered`,
   `minigame_exited`). Autoload order is EventBus, InventoryManager,
   GameState, GameFeel, then the MCP services.
6. **Runtime mesh slicing permitted for the firewood chopping mini-game**
   (Path B, Creative Director choice). An explicit exception to Directive 4's
   ban on runtime mesh booleans/CSG AND to A2's "pre-authored fracture states
   only". The slicer plane-cuts the log along a camera-inferred angle on each
   click and caps the cut face; sliver cuts are rounded up to a minimum piece
   size. **A3 is unchanged** — a runtime-sliced piece gets its `size_tier`
   COMPUTED (quantized from measured dimensions) at slice time instead of
   authored, and the sole size test everywhere remains
   `piece.size_tier > GameFeelConfig.size_threshold`.
   Consequence: the authored pine chain (`pine_chain.tres`,
   `build_pine_chain.gd`) is retired. FragmentDef itself stays.
   *(Amendment 10 later widened this to trees; with that retired, it reads as
   chopping-only again.)*
7. **A1 pipeline viewport increased from 640×360 to 960×540** (Creative Director
   call, 2026-07-22). NEAREST filter and stretch mode unchanged; only the
   internal render resolution increased by 50% to reduce pixelation. Window
   render scale remains at 1280×720 (2×).
8. **A1 pipeline dropped the pixel-art render entirely** (Creative Director
   call, 2026-07-22 — "the pixelated look isnt feeling right"). `Action_Viewport`
   raised 960×540 → 1280×720 (now matches the window 1:1, no upscale factor at
   all). Filter was briefly changed NEAREST → LINEAR the same day, but Sam then
   reported a slight "bloom" on everything — LINEAR's interpolation softening
   edges next to bright sunlit highlights — so it was reverted to NEAREST.
   Net result: 1280×720 + NEAREST. The project's base design canvas
   (`display/window/size/viewport_*`, used for 2D UI stretch layout) was
   deliberately left alone — **which is exactly what the OPEN A1 FINDING above
   is about.**
   - **Follow-up:** FSR/FSR2 upscaling is NOT supported under the Compatibility
     renderer (only Bilinear + Nearest), so `scaling_3d_mode` stays at default
     Bilinear. `msaa_3d` IS supported under Compatibility (since Godot 4.3) and
     is the correct fix for jagged geometry edges without blur — kept as a
     per-viewport override at 4x. `anisotropic_filtering_level = 3` kept
     (Sam's addition, sharpens the ground at grazing angles).
9. **A1's sun-gobo clause replaced, scoped to the chopping mini-game scene**
   (Creative Director call, 2026-07-22 — Sam supplied
   `images/lightmaps/leaves_gobo_tilable.jpg`). `light_projector` does not
   visibly render under gl_compatibility. Implementation: `CanopyGobo`
   (MeshInstance3D, `res://scenes/3d_action/canopy_gobo.gd`) in
   `chopping_minigame.tscn` — a `QuadMesh` hung above the scene with
   `cast_shadow = SHADOW_CASTING_SETTING_SHADOWS_ONLY` (invisible itself, shadow
   only) and a custom `ShaderMaterial`
   (`res://assets/shaders/canopy_gobo.gdshader`, the project's first
   hand-written shader) that alpha-scissors the leaf texture's inverse
   luminance — bright gaps in the source photo become transparent, dark leaf
   silhouette becomes the opaque occluder, so the sibling `DirectionalLight3D`
   casts a real dappled-leaf shadow onto the ground. All of `canopy_gobo.gd`'s
   tuning values are PLACEHOLDERS per Directive 3.
   - **Follow-up same day:** Sam reported the sway "so so steppy". The discrete
     `Animation.UPDATE_DISCRETE` track was snapping between UV-offset waypoints
     and read as a pop rather than a stepped-animation feel. Changed to
     `Animation.INTERPOLATION_CUBIC` so the gobo drifts smoothly between the same
     random waypoints — a further deliberate, scoped exception to A1's
     stepped-keyframe clause for this one effect.

### Retired amendments (tree game only — see git `29bcd6f`)

10. Runtime mesh slicing extended to tree felling; superseded A2 for trees.
11. The tree fall is a real physics simulation; trees have no hit points.
12. The fell condition is a measured load model; the break is a torn-fibre tear.
13. The wood becomes a VOXEL VOLUME, felled by the USDA ax manual's method.
14. The game becomes first person; the forest is the 3D biome you walk into.
15. A12 restated for a world; settled debris consolidates to MultiMesh.

Amendment 15's MultiMesh clause is the only part with lasting value: **A12's own
"long-term piles may consolidate to MultiMesh" was proven out**, and its traps
are worth knowing if the chopping game's firewood pile ever needs it —
`MultiMesh.instance_count` REALLOCATES and wipes every transform, and
`set_instance_transform` DOES NOT ROUND-TRIP under the headless renderer (the
storage lives in a stubbed-out RenderingServer), so a headless check written
against `get_instance_transform` can only ever fail.

---

## LOCKED ITEM IDS (res://data/item_registry.tres)

`pine_log, oak_log, mahogany_log, stone, copper_ore, iron_ore, amethyst,
ruby, sapphire, wood_board, copper_ingot, iron_nail`

Known data flag (unresolved): the blueprint's management example mentions
"Mahogany Boards" but the registry defines generic "Wood Boards". Ask Sam
whether boards become per-species before writing any upgrade data.

---

## ASSET PIPELINE (Sam → Maya → FBX → Godot)

- Format: **FBX** (native Godot 4.3+ importer). Y-up on export; Maya cm vs
  Godot m — fix scale once in Godot's FBX import dock (or export at 0.01).
  Freeze transforms + delete history before export.
- **`MeshUtils.mesh_from_scene` BAKES the transform authored on an imported
  FBX's `MeshInstance3D`** into positions, normals and tangents. So an FBX that
  carries a 30× node scale arrives at 30× — size things by a target height
  (`chopping_minigame.log_height`), never by a bare multiplier. This is exactly
  what broke log spawning on 2026-07-29.
- Style: flat-shaded low-poly, vertex colors preferred over textures,
  hard edges fine, readable silhouettes.
- Fragment pivots at the piece's landing/contact point (predictable A12
  physics).
- Live art in `res://assets/models/`: `axe_basic`, `chopping_stump_a`,
  `forest_floor`, `logs_export` (log_01…log_05). `trees_export` was deleted in
  the pivot.
- On disk:

| Path | What |
|---|---|
| `C:\Users\Sam\Documents\the_axeman\` | **Repo root — now a git repo.** CLAUDE.md, handoff pack, source images, Maya files. |
| `...\the_axeman\the-axeman\` | **The Godot project.** Everything shipped goes here. |
| `...\the_axeman\core\`, `...\data\` | **Stale duplicates** of the M1 drop. Canonical copies are inside `the-axeman\`. Sam has not approved deleting these (only `data/tree_def.gd` went, in the pivot). |
| `...\the_axeman\maya_working\models\` | Sam's Maya sources + FBX exports. Copy FBX into `res://assets/models/` when needed; never reference `maya_working` from the project. |
| `C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe` | The engine binary. |

---

## MODULE ORDER & SCOPE — APPROVED COZY LUMBERYARD ROADMAP

The binding post-pivot roadmap is
`handoff/08_COZY_LUMBERYARD_ROADMAP.md`. In order:

1. **M1–M4:** existing contracts, shell, GameFeel and chopping. Preserve and
   finish Creative Director tuning/sign-off.
2. **M5:** tree felling — deleted and retired.
3. **M6:** ore mining — retired from the active roadmap. Archival files may
   stay, but nothing builds from `04_M6_ORE_MINING.md`.
4. **M7A:** first cozy progression slice — always-available basic buyer, three
   authored orders, cash, firewood stock, lifetime chopped, five tangible
   upgrades, one unlockable wood species and a visibly growing stockpile.
5. **M7B:** craftsmanship and expanded lumberyard — reputation, cut-quality
   bonuses, size/species orders, customer families and meaningful yard/axe/
   supply/transport upgrades. Imperfect pieces always remain sellable.
6. **M8:** optional yard staff/logistics — support the work around chopping;
   never replace chopping as the highest-value active play.
7. **Post-M8 candidates:** wood-supply regions and secondary workshop products.
   These are expansions, not permission to start them before M7/M8 sign-off.

The old `05_M7_MANAGEMENT.md` and `06_M8_VILLAGERS.md` are historical inputs,
not build specs. Their replacement scope lives in the cozy roadmap. Continue to
use `02_M4_CHOPPING_BLOCK.md` and `07_M4_SLICING_POC.md` for the live chopping
implementation and render/debug traps.
