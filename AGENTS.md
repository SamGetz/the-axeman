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
| M2 | `--quit-after 900 res://core/tests/m2_acceptance.tscn` | **24/24** — the A1 finding is fixed (Amendment 16) |
| M3 | `--quit-after 900 res://core/tests/m3_acceptance.tscn` | **16/16** |
| M4 | `--quit-after 8000 res://core/tests/m4_acceptance.tscn` | **42/42** |
| M7A | `--quit-after 4000 res://core/tests/m7a_acceptance.tscn` | **94/94** |
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
  chopping scene by an animated shadow-cutout gobo). The game boots into 2D
  management mode by design; since M7A that mode is no longer empty — it shows
  the yard HUD, and its "Go chopping" button is the real entry into the 3D
  scene. **The temp M key is GONE** (2026-08-01).
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
scene with the yard HUD's **"Go chopping"** button, which emits `minigame_entered`
and drives the A10 2D/3D toggle (the temp M key it replaced is gone).

- **The slicer is Amendment 6's runtime plane cut.** Each click cuts the log
  along a camera-inferred angle and caps the cut face; sliver cuts round up to
  a minimum piece size. `size_tier` is COMPUTED at slice time, and A3's single
  size test is unchanged.
- **Viewport** is 1280×720 + NEAREST (Amendment 8 — the pixel-art look was
  dropped), and since Amendment 16 the project base canvas matches, so that IS what renders.
- **Ground:** `res://assets/models/forest_floor/forest_floor_a.fbx` is instanced
  directly as a child node in `chopping_minigame.tscn` (scale 0.4, Sam-authored
  placement).
- **Inventory wired:** a fully-chopped log deposits its species' item into
  InventoryManager — one `resource_gathered` per finished firewood piece, at the
  batch-collect point (`_begin_stacking`). Wood type is data-driven: `_LOG_SPECIES`
  in `chopping_minigame.gd` maps each log mesh → yield item, built to scale to
  many woods (add a row) and many log SHAPES per wood (add a path). CURRENT
  MAPPING: `log_01.fbx`→`oak_log`, `log_02.fbx`→`pine_log` (log_02 is pine only
  to demo per-log yields and still wears oak art — remap freely),
  `birch_log_01..06.fbx`→`birch_log` (six authored shapes, real birch art
  throughout, added 2026-08-01).
- **A row's `meshes` is a LIST on purpose.** Species is picked first, shape
  second, so log variety never changes how often a wood turns up — six birch
  meshes as six rows would have made three quarters of every yard birch.
  `debug_forced_species` / `debug_forced_mesh` force either for tests and shots.
  A row may also carry `inside_tex`/`inside_normal`/`inside_tint` for its cut
  faces; omitted keys fall back to oak.
  Cut materials are cached per species BY DESIGN, not just for speed:
  `MeshUtils.jag_cut` finds a piece's cut surface by comparing
  `material == _cut_mat` **by reference**, so a fresh instance per log would
  leave anything cut before the swap unroughenable.
- `assets/models/logs_export/` also holds `log_2.fbx`, an unused duplicate, and
  `maya_working/` still has unimported `log_03/04/05.fbx`. CLAUDE.md previously
  claimed log_01…log_05 were live; they were not, and are not.
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

### M7A — progression spine (STARTED 2026-08-01, no sign-off yet)

Built ahead of the orders/prices because none of it needed a tuning value or an
asset. Suite: `m7a_acceptance` 85/85.

- **Cash and lifetime wood chopped live in `GameState`.** Cash is an `int`,
  never a float. It leaves the purse ONLY through `try_spend_cash()`, which is
  atomic — a refused purchase changes nothing and emits nothing (Amendment 4's
  all-or-nothing rule, applied to money). `DEFAULT_CASH = 0` is a PLACEHOLDER.
- **`lifetime_wood_chopped` is fed by the existing A7 `resource_gathered`
  signal** — no contract change, no edit to the chopping game. It filters on
  `ItemCategory.RAW_WOOD` rather than a list of wood ids **on purpose**: that
  survives the still-open `*_log` vs `*_firewood` rename, and picks up a new
  species for free. Monotonic by construction — it never sees removals, so
  selling stock cannot un-chop wood. **Revisit at M8:** it counts wood
  *gathered*, so staff who gather wood would be credited to the player.
- **Two LOCAL signals** on GameState — `cash_changed`, `lifetime_wood_chopped_
  changed` — following Amendment 2's precedent exactly: NOT on EventBus, A7
  untouched, they never cross the 2D/3D boundary, and they exist so the M7 UI
  can update without polling.
- **`res://core/save_system.gd` (`class_name SaveSystem`) is NOT an autoload.**
  It is stateless static methods, so it needs nothing an autoload provides, and
  a 5th autoload would have needed an amendment the way GameFeel did. Each
  system serialises ITSELF (`to_save_dict`/`apply_save_dict` on GameState and
  InventoryManager), so Directive 6 is never bypassed — SaveSystem only moves
  dictionaries to and from disk.
- Save file: `user://the_axeman_save.cfg` (ConfigFile — Variants survive
  natively, and it is readable when a save goes wrong). Written to a `.tmp`
  and renamed over the real file, so a crash mid-write cannot truncate a save.
  Versioned; a save from a NEWER build is refused and moved to a `.bak` rather
  than loaded or overwritten.
- **`main.gd` now loads at boot and saves on window close.** It sets
  `get_tree().auto_accept_quit = false` and saves in
  `NOTIFICATION_WM_CLOSE_REQUEST` — the only hook that still sees live state.
  Quitting is unconditional even if the save fails.
- **Autosave: on every inventory change** (Creative Director call, 2026-08-01 —
  "save when something new is added to inventory"). It is **coalesced**: a
  finished log deposits one piece at a time, so a six-piece log fires
  `inventory_changed` six times in one frame; the flush is deferred so the batch
  collapses to a single write. It is connected AFTER main's own load, because
  `apply_save_dict` emits for every item it restores and would otherwise make
  loading immediately trigger a save. It fires on any change, not only additions
  — a sale or an upgrade cost is at least as worth persisting, and filtering to
  increases would leave a sale unsaved until the next chop.
  The coalescing guard is proven to fail without its fix (calling the flush
  directly instead of deferring turns it red).
- `core/tools/save_probe.tscn` drives the save from outside the game (`dump` /
  `seed` / `quit` / `wipe`) — it predates the UI and is still the way to inspect
  a save from outside. Note it is a SCENE, not a `-s` script: a `-s` script
  replaces the main loop and the autoloads are never instantiated.

### M7A — the basic buyer, the yard HUD and the real entry flow (2026-08-01)

The second M7A slice, and again everything in it that needed a tuning value was
pushed into data instead of invented. **Still no sign-off.**

- **`res://data/price_table.gd` + `price_table.tres` (`class_name PriceTable`)**
  holds what the buyer pays per unit. **Creative Director call, 2026-08-01: pine
  2, oak 5, birch 10** — Sam chose the wide spread over a gentle one, so which
  wood you are cutting matters and unlocking a species is a real jump in income.
  `mahogany_firewood` sits at 25 as a PLACEHOLDER above birch; it has no art and
  Sam has not priced it. Nothing in code or in any test asserts a literal price
  (the checks assert price x count), so retuning is a one-line data edit.
  It is a SEPARATE resource and not a field on `ItemDef` because A8 is a frozen
  Part A contract (Directive 2), and because a price is a property of the market,
  not of the object — M7B's reputation and per-customer multipliers layer on top
  of these base values without touching the registry. **An id the table does not
  price is NOT sellable**; it must never fall through to a free sale.
- **`res://core/market.gd` (`class_name Market`) is NOT an autoload**, for the
  same reasons as SaveSystem: no state, and a 5th autoload would need an
  amendment. It is the always-available basic buyer (roadmap pillar 5) — buys any
  priced item, any quantity, any time, no contract to accept.
- **It writes NOTHING itself.** Stock leaves only through
  `InventoryManager.remove_items`, cash arrives only through `GameState.add_cash`,
  so Directive 6 holds: Market decides what a sale IS, the owners perform it.
- **A sale is atomic in both directions, and the ORDER IS LOAD-BEARING:** price
  the whole basket and refuse it entirely if any line is unpriced, then remove the
  stock in ONE aggregated `remove_items`, and only then pay. Paying first and
  failing to collect would mint money from nothing. Both halves are proven to fail
  without their fix (a mixed oak+stone basket part-sells without the per-line
  price check; swapping the order pays for a sale that never happened).
- **`res://scenes/2d_management/yard_hud.tscn/.gd`** is instanced under
  `Main/UI_Overlay` (A9 — gameplay UI never goes in UI_Canvas). It shows cash,
  stock value and lifetime chopped; one sell row per species; "Sell all"; and the
  entry-flow buttons. It updates off `cash_changed`,
  `lifetime_wood_chopped_changed` and `inventory_changed` — never polled, which is
  exactly what Amendment 2 added those local signals for.
- **The stock rows are BUILT FROM DATA at runtime**, from
  `Market.get_sellable_stock()`, so a new wood species appears in the yard the
  moment it has a price and a piece in stock — no scene edit. The rebuild is
  deferred/coalesced for the same reason the autosave is (a six-piece log fires
  six `inventory_changed` in one frame), and that guard is proven to fail without
  its fix too.
- **THE TEMP M KEY IS GONE.** "Go chopping" / "Back to the yard" emit the same A7
  `minigame_entered` / `minigame_exited` the key did, so `main.gd`'s A10 mode
  switch is unchanged and is now driven by the production path. The HUD switches
  its own view off the SIGNALS, not off the clicks.
- **`core/tools/hud_shot.tscn` renders the real main scene to PNGs** (yard,
  chopping, sold) — RUN NON-HEADLESS. Every numeric check here is green on a UI
  that is off-screen or covering the chopping block; this is `shot_runner` applied
  to the 2D side. It stashes the real save for the run.
- **SEEN IN THE SHOTS, Sam's call:** coming back from chopping leaves the last
  rendered 3D frame frozen behind the yard panel (A10 stops the viewport
  rendering, it does not clear it). It reads fine — the yard IS the chopping site
  — but if you want the yard to be its own view, that is a design decision, not a
  bug fix.
### M7A — the stockpile is a VIEW of stock (2026-08-01)

The roadmap's "visibly growing stockpile", built third because it was the only
remaining M7A item that needed no tuning value from Sam.

- **The pile the player can see IS the firewood they own.** `chopping_minigame`
  rebuilds `_pile_root` from `InventoryManager` — so a loaded save shows the yard
  you left, selling firewood SHRINKS the pile, and a new species appears in it the
  moment you own a piece. **Nothing new is saved for it**: stock already persists
  and the pile is derived, so there is no second copy of the truth to drift.
- **Rebuilt, never patched.** `wood_pile.gd`'s arc packing is deterministic and
  has no way to pull one piece out of the middle of a stack, so a change rebuilds
  the whole pile instantly via the new `WoodPile.place_settled()` — which shares
  `_slot_layout`/`_sim_to_world` with the animated path, so a restored pile packs
  exactly like one the player watched being thrown together.
- **NOT rebuilt while a batch is flying in** (`_stacking` / `_awaiting_stack`
  guard). Freshly cut pieces are the REAL sliced meshes and they animate into the
  pile; rebuilding on top of that would swap them for stand-ins mid-flight and
  throw away the best moment in the game. Stock and pile stay in step anyway: a
  rebuild sets the pile to the stock count, and every piece that flies in
  afterwards is one the stock also gained.
- **Stand-in pieces are made by SLICING that species' own log** — two centre cuts
  into a quarter column with jagged cut faces, which is what the first two clicks
  on it would produce. A box would have been cheaper and would have looked like a
  box next to the real pieces. Built lazily and cached per species, so a wood the
  player owns none of never loads its FBX. NOTE it calls `MeshUtils.jag_cut` with
  the SPECIMEN's material, not through `_jag_cut()`, which roughens only what
  matches the log currently on the block.
- **`max_pile_pieces` (120) is a PLACEHOLDER** and the point where "the place
  grows" stops being one mesh per piece: above it the counter keeps climbing and
  the pile does not. If Sam wants it to keep growing, A12/Amendment 15's MultiMesh
  consolidation is the route (and its traps are recorded at the bottom of the
  retired-amendments section).
- Verified by 9 checks in `m7a_acceptance` that count pieces AND look at where
  they are — distinct slots, stacked upward, more than one billet mesh — because
  a pile check that only counted would pass on a build that dropped every piece
  inside the stump. Proven to fail without its fix (unwire `inventory_changed`
  and six of them go red), and RENDERED: `hud_shot` shots 3 and 4 are a 65-piece
  yard and the same yard after a sale.

- Still to do in M7A: three authored orders, five upgrades and an unlockable
  second species. All three are blocked on tuning values (Directive 3).

### Files the chopping game owns

`scenes/3d_action/`: `chopping_minigame.gd/.tscn`, `chopping_minigame_harness.tscn`,
`mesh_slicer.gd`, `mesh_utils.gd`, `fragment_piece.gd/.tscn`,
`fragment_physics_budget.gd`, `piece_animator.gd`, `wood_pile.gd`, `axe_rig.gd`,
`canopy_gobo.gd`.

`scenes/2d_management/`: `yard_hud.gd/.tscn` (the yard HUD, the basic buyer's
front end and the entry flow) — the first thing this folder has ever held.

`core/tools/`: `test_slicer`, `chopping_smoke`, `chop_diag`, `pile_smoke`,
`pile_shot`, `shot_runner`, `hud_shot`, `jag_shot`, `inspect_log`, `inspect_stump`, `probe_log`,
`species_shot` (renders EVERY row of `_LOG_SPECIES`, fresh and cut — run it on any
log drop), `inspect_fbx` (tree/size/material report), `inspect_materials` (the
ACTUAL bound texture per surface — see the material-name trap below).

### A1 FINDING — CLOSED 2026-08-01 (Amendment 16)

**Fixed. `m2_acceptance` is 24/24 for the first time.** Kept here because the
trap will bite again the moment anyone touches the render pipeline.

`Action_Viewport.size` is authored 1280×720 in `main.tscn` but that was **not
what ran** — `SubViewportContainer.stretch = true` resizes the child viewport to
the container's rect, and the container follows the project's base canvas
(`display/window/size/viewport_*`). That base canvas was **640×360**, so the game
rendered at 640×360 and canvas_items stretched it up 2×, which is very likely the
"still kinda pixelated" Sam reported. Amendment 8's "render at 1:1, no upscale"
simply was not happening.

The base canvas is now 1280×720, matching the authored viewport and the window.
`m2_acceptance` now asserts the two are **EQUAL** as well as individually
correct — the moment they diverge again, the authored size is fiction and the
check goes red rather than silently passing. Note the old base-canvas check
expected 960×540 (Amendment 7) and had never been updated for Amendment 8, so it
was failing for a stale reason on top of the real one.

---

## OPERATIONAL RULES (summary of blueprint directives)

1. One module at a time, explicit Creative Director sign-off between
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
- **Run every `godot --path .` from `the-axeman\`, not from the repo root.** The
  repo root has no `project.godot`, so the engine quietly falls back to the
  project manager: it prints its banner, runs NOTHING, and exits 0 (or segfaults
  headless). A whole suite "passing silently" or "crashing" is this, not your
  code. `--verbose` gives it away — it loads editor settings and never loads a
  project.
- **A new `class_name` is invisible until the project is rescanned.** A headless
  run does not refresh `.godot/global_script_class_cache.cfg`, so a brand-new
  global class reads as "Identifier not declared" everywhere it is used. Run
  `godot --headless --path . --import` once after adding one.
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

16. **A1's base canvas raised 640×360 → 1280×720** (Creative Director call,
    2026-08-01 — Sam: "fix that"). This is the fix for the long-standing A1
    FINDING above: `display/window/size/viewport_*` in `project.godot` is what
    the stretched `SubViewportContainer` actually sizes `Action_Viewport` to, so
    the authored 1280×720 was fiction and the game rendered at 640×360 upscaled
    2×. Base canvas, `Action_Viewport` and the window are now all 1280×720 —
    Amendment 8's "1:1, no upscale" is finally true. Window size overrides left
    in place (now redundant, harmless, and explicit about intent). Everything
    else in A1 is untouched: stretch mode stays `canvas_items`/`keep`, the
    container stays `stretch = true` + NEAREST, `msaa_3d` stays a 4× per-viewport
    override, `scaling_3d_mode` stays Bilinear.
    - **CLOBBER TRAP, still live:** this was a direct `project.godot` edit. If
      the Godot editor is open when the file is edited by hand, the editor
      overwrites it on its next save. Close or reopen the editor after any such
      edit and re-run `m2_acceptance` to confirm.
    - `m2_acceptance` now asserts the base canvas and `Action_Viewport.size` are
      **equal**, not merely each correct, so a future divergence goes red instead
      of quietly reintroducing a hidden upscale.

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

`pine_firewood, oak_firewood, birch_firewood, mahogany_firewood, stone,
copper_ore, iron_ore, amethyst, ruby, sapphire, wood_board, copper_ingot,
iron_nail`

**RENAMED 2026-08-01, Creative Director call ("we can call it firewood").** The
four wood ids were `*_log`, which meant chopping a log *yielded logs* — the wrong
noun to build an economy on. They are now `*_firewood`, display names to match
("Oak Firewood"). `birch_firewood` was added the same day with Sam's birch art;
it is no longer pending.

There are deliberately **no `*_log` items**. Logs are not inventory today — they
spawn on the block and are consumed by chopping. The roadmap's "log supply"
upgrade family is about what spawns, not about a stored resource. If logs ever
need to be stock (staff delivering them, say), add the ids then.

Nothing in any test suite asserts this list — it is enforced by this document
alone. The rename touched no logic at all, because `lifetime_wood_chopped`
filters on `ItemCategory.RAW_WOOD` rather than on names.

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
- **MATERIAL-NAME TRAP.** Godot's scene importer binds an EXTERNAL material when
  it finds a `.tres` beside the source file whose name matches the FBX's material
  slot. `assets/models/logs_export/` contains `oak_bark.tres` and `oak_top.tres`,
  and every log FBX so far carries slots of exactly those names — so a new
  species can silently inherit the OAK look even though Godot extracted its own
  embedded textures to disk. The material NAME cannot tell the two cases apart;
  only the bound texture path can. Check with
  `core/tools/inspect_materials.gd` on every art drop. (birch_log_01 was checked
  on 2026-08-01 and is correctly on its own textures.)
- **A log's CUT face is not the FBX's business.** Bark and authored ends come
  from the imported materials, but the cut face is generated at runtime from
  `_LOG_SPECIES`'s `inside_tex`/`inside_normal`. Those must be **tileable** —
  cut-face UVs are a metres-based tiling mapping, so a log-end "disc" texture
  repeats into a grid of discs. Oak and birch each have a `*_tilable` set.
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
