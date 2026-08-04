# CLAUDE.md — The Axeman (log-cutting game)

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
net exists, use it. **UPDATED 2026-08-04: a remote now exists** —
`origin` → `https://github.com/SamGetz/the-axeman.git`, tracking `master`.
This line originally said there was no remote; it was stale. See Operational
Rule 7 below — sync with `origin/master` at the start of every session before
starting new work.

### APPROVED POST-PIVOT DIRECTION (2026-08-01)

Sam approved the full cozy-lumberyard recommendation and the roadmap in
`handoff/08_COZY_LUMBERYARD_ROADMAP.md`:

1. **M6 ore mining is fully removed, not archival.** Retired from the roadmap
   2026-08-01; on 2026-08-04 Sam asked directly to strip it out ("this is logs
   only") and its spec, data class (`OreVeinDef`) and registry items were
   deleted outright. `ItemCategory.MINERAL`/`GEM`, `ToolType.PICKAXE` and the
   `MOSSY_QUARRY`/`VOLCANIC_CAVERN` biomes are gone from the frozen A6 enums —
   see the amendment log. Mining must not be reintroduced as a second action
   loop unless Sam separately reverses this.
2. **M7 is re-scoped to lightweight lumberyard progression and orders.** Cash,
   firewood stock, reputation and lifetime wood chopped are the progression
   spine. The yard grows visibly alongside the counters.
3. **M8 is reinterpreted as certified automation, with no yard-staff layer.**
   Sam removed the villagers/yard-staff concept 2026-08-04 — unlocking and
   purchasing stay driven entirely by the existing shop (the same Items/Trees
   tabs M7A already built), not by a hired roster. M8's scope is the first
   certified Mechanical Splitter: once a species is mastered, its cutting
   profile is bought directly through the shop like every other purchase, and
   the machinery then replaces routine manual commodity chopping for that
   solved wood while the player moves to the next unknown species.
4. **Biomes may return only as wood-supply regions**, not explorable FPS forest
   levels. They unlock species, customers and contracts.
5. **Tone is cozy lumberyard first**, with restrained absurd escalation only
   after the grounded chopping-and-yard fantasy is established.

### EXPANDED ENDGAME DIRECTION (2026-08-01)

Sam has now defined the long-horizon goal: build from the cozy yard into the
company that **masters and chops every kind of log on Earth**, then spend the
resulting wealth and materials on space expeditions that return alien logs. The
extensive design and module sequence are in
`handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`.

This does **not** restore M5 or create a replacement tree-felling management
layer. There are no standing-tree counts, forest-depletion maps, felling crews,
skidders or Last Tree sequence. Regions are log suppliers only: every unknown
species first arrives at the existing chopping block for its manual learning
and certification phase. The grounded yard must be established before the
global and space scale is revealed. The roadmap is not permission to skip
module sign-off or invent tuning values.

**Certified auto-cutting IS in scope, begins with the first Mechanical Splitter
in M8 and is required for trillion-scale timber throughput.** This automates log
processing, never tree felling. The progression loop is: manually chop and learn
a new species a small authored number of times, certify it, buy/install its
cutting profile, then let machinery replace manual commodity production for
that solved wood while the player moves to the next unknown species. Machines
cannot award Axeman XP, discover, master or certify a new species. Exact rates,
requirements and value differences remain tuning calls.

### SKILL TREE AND STORE DIRECTION (2026-08-02)

Sam approved three player-skill branches: **Strength**, **Speed** and
**Technique**. Skills must do more than make the same loop faster. Their defining
rewards are named random bonus mechanics such as double/triple/quadruple strikes,
free follow-ups, hot streaks, golden-grain opportunities and multiplied manual
XP. Proc chains require bad-luck protection, valid slicer geometry, visible
announcements and protection for precision work. Final odds and magnitudes are
tuning calls.

Cash belongs to the physical store: axes/tools, workstation/environment,
automated production, yard/logistics and optional session supplies. Skills
define what the Axeman can do; equipment weights how often, how strongly or how
safely those mechanics occur. Every meaningful purchase must be felt or seen in
the yard. Full framework: `handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`.

Exact prices, payout multipliers, timing values and upgrade magnitudes are still
tuning decisions. Do not invent them in code: present them to Sam as resource
values/placeholders and tune with Creative Director sign-off.

### CLEANUP — resolved 2026-08-04

Both items formerly tracked here as open Creative Director calls were resolved
by Sam's direct request to strip deprecated/unused elements from the repo:

1. `slice_poc.tscn` (the pre-Amendment-8 960×540 harness, superseded by
   `chopping_minigame_harness.tscn`) — **deleted**. Recoverable from git.
2. The stale root-level `core/` and `data/` duplicates of the M1 drop —
   **deleted**. The canonical copies are the only copies now: `the-axeman/core/`
   and `the-axeman/data/`. `handoff/00_OVERVIEW.md` is stale on this point (it
   still describes the old "don't delete" stance, preserved there as history).

Also removed in the same pass: the stale, drifted `AGENTS.md` (a duplicate of
this file that had fallen out of sync — CLAUDE.md is the sole source of truth),
`assets/models/logs_export/log_2.fbx` (the unused duplicate noted below), a
stray unrelated `java_script_working_example.js` bundle at the repo root, and
a tracked `.DS_Store`.

---

## CURRENT PROJECT STATUS (as of 2026-08-03)

Suite results, all re-run after the pivot on the shipping assets:

| Suite | How to run | Result |
|---|---|---|
| M1 | `--quit-after 900 res://core/tests/m1_acceptance.tscn` | **21/21** |
| M2 | `--quit-after 900 res://core/tests/m2_acceptance.tscn` | **24/24** — the A1 finding is fixed (Amendment 16) |
| M3 | `--quit-after 900 res://core/tests/m3_acceptance.tscn` | **16/16** |
| M4 | `--quit-after 20000 res://core/tests/m4_acceptance.tscn` | **55/55** |
| M7A | `--quit-after 20000 res://core/tests/m7a_acceptance.tscn` | **245/245** |
| Slicer | `-s res://core/tools/test_slicer.gd` | **34/34** |
| Chopping smoke | `--quit-after 8000 res://core/tools/chopping_smoke.tscn` | green |
| Pile smoke | `res://core/tools/pile_smoke.tscn` | **green; run NON-headless** — it polls the real pile/respawn outcome against a real-time deadline because uncapped frame counts outrun the animation clock |

Engine binary: `C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe`.
Godot project: `C:\Users\Sam\Documents\the_axeman\the-axeman\`.

**Those two paths are the DESKTOP's, not the project's** — nothing in the repo
reads either one. On any other machine, see `SETUP.md` at the repo root: it is
the bootstrap for a fresh clone (which engine build, the `--import` pass that
must run TWICE before any suite means anything, the suites and their expected
counts, and what does and does not travel between machines). Verified end to end
on a clean clone on 2026-08-02.

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
  batch-collect point (`_begin_stacking`). Wood type is data-driven: since
  2026-08-02 the table is `res://data/species_table.tres` (it was a `_LOG_SPECIES`
  const in `chopping_minigame.gd` until Sam's 25 woods landed — see the 25-wood
  ladder section). A row maps log meshes → yield item, and scales to many woods
  (add a row) and many log SHAPES per wood (add a path). CURRENT ART: only
  `log_01/log_02.fbx` (oak) and `birch_log_01..06.fbx` (real birch art, six
  authored shapes) exist; the other 22 species wear tinted oak via `bark_tint`.
- **A row's `meshes` is a LIST on purpose.** Species is picked first, shape
  second, so log variety never changes how often a wood turns up — six birch
  meshes as six rows would have made three quarters of every yard birch.
  `debug_forced_species` (a LADDER INDEX) / `debug_forced_mesh` force either for
  tests and shots. A row may also carry `inside_tex`/`inside_normal`/`inside_tint`
  for its cut faces; empty falls back to oak.
  Cut materials are cached per species BY DESIGN, not just for speed:
  `MeshUtils.jag_cut` finds a piece's cut surface by comparing
  `material == _cut_mat` **by reference**, so a fresh instance per log would
  leave anything cut before the swap unroughenable.
- `log_2.fbx`, an unused duplicate that used to sit in `assets/models/logs_export/`,
  was deleted 2026-08-04. `maya_working/` still has unimported `log_03/04/05.fbx`
  (raw Maya exports, never referenced from the project — see ASSET PIPELINE).
  CLAUDE.md previously claimed log_01…log_05 were live; they were not, and are not.
- **Acceptance:** `m4_acceptance.tscn` **54/54** — drives `debug_slice_world` to
  completion, checks inventory deposit == firewood count, per-species yield, one
  hit per slice, the A12 budget, and (since 2026-08-02) the axe viewmodel's contact
  key and its failsafe. It calls `get_tree().quit()` on finish, so run headless
  with a generous `--quit-after` backstop (e.g. 20000).
  **The click layer IS partly headless-verifiable now.** Test 7 calls `_on_click`
  for real, which is the suite's ONLY raycast — and it needs `await physics_frame`
  plus a settle wait first, because the query runs against the physics server and
  the log is still dropping in from `drop_height` a process frame after spawn. The
  FEEL of clicking is still Sam's eyeball test in F5/F6.
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
  selling stock cannot un-chop wood.
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
- **Autosave: on every persisted progression change.** This began as the Creative
  Director's 2026-08-01 call to save when inventory gains something, then widened
  on 2026-08-02 so cash, yard-pile state, XP, skills, species purchases and the
  selected wood cannot wait for another chop before they are safe. It is
  **coalesced**: a finished log touches inventory, XP, cash and pile state, but
  the deferred flush collapses the whole transaction to one write. Connections
  are made AFTER main's own load so restoration signals cannot immediately
  rewrite the file that was just read.
  The suite proves both sides: a batch writes nothing inside the transaction,
  and a woodshed purchase persists without waiting for another inventory move.
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
  `Main/UI_Overlay` (A9 — gameplay UI never goes in UI_Canvas). Cash is the only
  permanent economy number; pile and lifetime totals remain saved background
  stats. The yard panel derives one next useful cash purchase from the live
  shop/woodshed catalogues, including a wood's level prerequisite, so it cannot
  drift from authored data. Chopping mode alone shows the haul progress bar.
- **THERE IS NO MANUAL SELLING** (Creative Director call, 2026-08-01 — see the
  auto-sell section below). The per-species sell rows and "Sell all" this HUD
  shipped with on the same day are GONE; `Market` is still the buyer, it is just
  called by the yard as each piece lands instead of by a button.
- **The shop is an empty room ON PURPOSE.** `assets/ui/coin.png` (Sam's art) is
  the shop's icon on the button and on its header; the panel itself says what
  will be sold there. Upgrades and new woods are blocked on Sam's numbers
  (Directive 3), so this is the door and the counter, with nothing on the shelves.
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
### M7A — the pile pays as it lands, and the load is hauled away (2026-08-01)

**Creative Director call, and it REPLACED the model shipped earlier the same day:**
*"I think we should have the pile of chopped wood still build up, but we shouldn't
be selling it manually — as soon as the pieces enter the pile, they should be
converted to their cash value. Once the pile hits 50 pieces, it can animate off
screen in a fun way, similarly to how it animates on to the pile after it is
chopped."*

- **A piece is bought the MOMENT IT LANDS.** `WoodPile.start_stacking` now takes an
  `on_piece_settled` callback and fires it as each piece comes to rest, so the cash
  ticks up in the same cascade the player is watching land, not in one lump before
  the wood has arrived. `chopping_minigame._on_piece_landed` is that callback: it
  adds the piece to the yard pile and sells it through `Market`, so the price table
  is still the one place a piece's worth is decided and Directive 6 still holds.
- **`auto_sell` (@export, default true) is OFF in `m4_acceptance`.** M4 tests the
  chopping game's YIELD contract — a finished piece deposits stock — and the
  economy would otherwise sell that stock out from under it. Two suites, two
  concerns; nothing about the deposit changed.
- **The pile is no longer a view of InventoryManager.** It could not be: the wood
  is paid for and gone by the time it is stacked. It is now a view of
  **`GameState`'s yard pile** (`add_to_yard_pile` / `clear_yard_pile` /
  `yard_pile_changed`, saved in `to_save_dict`) — a record of WORK DONE since the
  last load left, which is progression, which is why it lives there.
- **A LOADED SAVE lands after this scene is built** — a child's `_ready` runs
  before its parent's, so the pile builds empty and `main.gd` reads the save
  moments later. The `yard_pile_changed` connection is what makes a restored pile
  appear at all; the count check in `_on_yard_pile_changed` is what stops the
  pieces this scene adds one at a time from triggering a rebuild on top of the
  animation that is placing them.
- **Rebuilt, never patched.** `wood_pile.gd`'s arc packing is deterministic and
  has no way to pull one piece out of the middle of a stack, so a change rebuilds
  the whole pile instantly via `WoodPile.place_settled()` — which shares
  `_slot_layout`/`_sim_to_world` with the animated path, so a restored pile packs
  exactly like one the player watched being thrown together.
- **Stand-in pieces are made by SLICING that species' own log** — two centre cuts
  into a quarter column with jagged cut faces, which is what the first two clicks
  on it would produce. A box would have been cheaper and would have looked like a
  box next to the real pieces. Built lazily and cached per species, so a wood the
  player owns none of never loads its FBX. NOTE it calls `MeshUtils.jag_cut` with
  the SPECIMEN's material, not through `_jag_cut()`, which roughens only what
  matches the log currently on the block.
- **THE HAUL-AWAY at `max_pile_pieces` (50, Sam's number).** `WoodPile.start_hauling`
  lifts every piece, arcs it outward away from the stump and tumbles it off past
  the horizon in a staggered wave — the fly-in run backwards. It has its OWN
  animation list and its own `_haul_root` parent, deliberately independent of the
  stack coming in, so **the player can chop straight through a haul-away** instead
  of waiting for the yard to tidy itself. It pays nothing: the wood was bought as
  it landed.
- Verified by 15 checks in `m7a_acceptance`, including a full chop on the real
  scene (4 pieces, 5 cash each, hauled at the cap) and pile checks that count
  pieces AND look at where they are — distinct slots, stacked upward, more than one
  billet mesh — because a count-only check would pass on a build that dropped every
  piece inside the stump. Both halves are proven to fail without their fix
  (`auto_sell = false` kills the payout checks; disarming the threshold leaves the
  load sitting in the yard). RENDERED: `hud_shot` shoots the shop, a 40-piece pile
  and the haul CAUGHT MID-FLIGHT, which no counter could have told us.
- **The haul threshold is now discoverable without reviving a permanent pile
  counter.** Chopping mode shows a numberless "Next haul-away" progress bar. Its
  maximum and the production pile both inherit `GameState.YARD_PILE_CAPACITY`
  (Sam's 50), so the threshold still has one owner.

### M7A — a swing is a ROLL, and the shop sells the odds (2026-08-01)

**Creative Director call:** *"we should make sure the player doesn't split through
every time guaranteed, they should leave a scar on the log if they fail a hit. The
stat increase works towards easier spliting, higher tier logs have a harder % to
break through."* Sam then chose, from the options put to him: a roll with a PITY
BONUS; scars that WEAKEN the piece they are in; the protein bar as +5 points of
split chance; and a REAL swing cooldown for the coffee to cut into.

- **`_resolve_strike` owns the roll, NOT `_perform_split`.** That split is
  deliberate: `_perform_split` means "cut this piece" and is what
  `debug_slice_world` and the entire M4 suite drive, so M4 goes on testing geometry
  instead of luck. The new headless seam is `debug_swing_world`, with
  `debug_split_roll` forcing the outcome (-1 roll / 0 always fail / 1 always split).
- **`split_chance_for(piece)` is the whole sum in one place:** the wood's own
  `split_chance` (a field on `SpeciesDef` — **0.55 is Sam's: "roughly 45% to
  start" on the STARTING LOG**, so on 2026-08-02 it moved with that role from oak
  to Quaking Aspen; the other 24 are placeholders laid out down the Janka ladder,
  so the wood that pays most resists most), made easier as the piece gets
  smaller (`size_relief`), plus
  `scar_bonus` per scar already in it, plus `strength_step` per protein bar,
  clamped to `max_split_chance` (0.95) — a swing is NEVER a certainty, which is
  the thing Sam asked for by name. `m7a_acceptance` asserts the price/difficulty
  ordering against the species table, so a new wood cannot ship as both the most
  valuable and the easiest.
- **A SCAR IS DRAWN OUTWARD, NOT CARVED IN.** Geometry cannot subtract from a
  surface: the first implementation sank a V into the log and rendered completely
  invisible, because the bark in front of it drew over the top. The mark is laid
  just proud of the wood instead. (Godot's `Decal` node, the obvious tool, does
  not render under Compatibility.)
- **THE MARK GOES ON THE TOP FACE, ALONG THE CUT LINE** (Creative Director call:
  *"It would need to be on the top, the line in the direction the camera is facing
  from where the player clicked"*). The log stands on the block and the axe comes
  down on its top, so that is where the bite belongs — the first version put it on
  whichever SIDE the click ray entered through, which is where the ray hit but not
  where the axe went. The line runs along `UP x normal`; since `normal` is the
  camera's own right vector (see `_on_click`), that is the line the split would
  have opened, running away from the viewer.
- **It is ONE SOFT DARK LINE, shared by every wood, UNSHADED and translucent.** It
  went through two rejected versions: a prettier two-tone of each species' own
  inside grain (*"I am having a hard time seeing the scar, it can just be a dark
  color as well, so no need to have it match every log"*), then a solid near-black
  bar (*"the line is also way too dark, it should just be a soft-indicator of
  failure, a thin mark where an axe failed to punch through"*). Unshaded is the
  load-bearing part: a lit material dims into dark bark exactly where the mark
  matters most. Readable beats correct — a scar the player misses is a mechanic
  the player misses.
- Scars live as children of the piece, so they turn with it and die with it. A
  piece that finally splits takes its scars with it and the two halves start
  clean — correct, since the cleave went straight through the marks.
- **A failed swing shakes but does NOT stop time.** `GameFeel.register_impact`
  gained an optional `with_pause` argument (a public method, not an A7 signal, so
  no contract moved) and failures pass `false`. A11's hit-pause stays the
  punctuation of a real split, so the two outcomes feel different before the
  player has read a single number.
- **A failed swing now BOUNCES OFF THE LOG.** The split roll resolves on the
  `swing` animation's contact key; a success keeps Sam's authored follow-through,
  while a failure immediately branches to the editable `bounce` animation in
  `axe_swing_lib.tres`. Its first key is the exact contact pose, then it reverses
  the overhead approach, so the scar, thud, shake and recoil are one event. Run
  `core/tools/axe_shot.tscn -- --bounce` non-headless to render the failure beats.
- **The swing cooldown did not exist before this.** The game was gated only by one
  strike at a time plus the anticipation window, so there was nothing for "5%
  faster between swings" to shorten. `swing_cooldown` (0.3 s, PLACEHOLDER and the
  value most likely to want Sam's hand) is now a real gate, and coffee compounds
  5% off it per level.
- **`res://core/shop.gd` + `data/upgrade_def.gd` / `upgrade_table.tres`.** Shop is
  static and not an autoload, like Market and SaveSystem. **Levels are stored as
  BUILDING TIERS** through A7's existing `building_upgraded` — a shop upgrade is
  exactly what that frozen signal already describes, so nothing was added to the
  contract to sell a cup of coffee. NOTE `DEFAULT_BUILDING_TIER` is 1, so LEVEL =
  TIER - 1; every reader goes through `Shop.get_level()` so that lives in one
  place. A purchase is atomic and ordered: refuse if maxed, spend the cash, and
  only then raise the tier.
- Costs (25 / 40, growth 1.6-1.7, cap 10 levels) are PLACEHOLDERS. The two 5%
  effect steps are Sam's.
- Verified by 37 checks in `m7a_acceptance`, all forcing the roll so none of them
  depend on RNG, and proven to fail without their fix (make every swing split and
  9 go red; drop the strength term and the protein bar's check goes red).
  RENDERED: `core/tools/scar_shot.tscn` shoots a clean log, a scarred one and a
  split one for both a dark wood and a pale one — run it on any change to the mark.
- **`core/tools/split_odds.tscn` MEASURES THE FELT RATE, and it is not the
  authored one.** `split_chance` is the odds on the FIRST swing of a whole log;
  almost every swing after that lands on a smaller piece that `size_relief` has
  already made easier, and on wood the scars have already weakened. Sam reported
  *"I'm not really ever seeing the failures"* and the tool said why: at oak 0.7 /
  relief 0.5, only **19% of swings failed and 12 logs in 40 went down without a
  single failure**. At oak 0.55 / relief 0.2 it is **35% of swings, and 37 logs in
  40 show at least one failure**. Run it after touching any of those numbers —
  arguing about the authored value is arguing about the wrong number.

### M7A — the 25-wood ladder (2026-08-02, no sign-off yet)

**Creative Director call:** Sam named the 25 trees the finished game will use, in
this order — Quaking Aspen, Eastern White Pine, Norway Spruce, Balsam Fir,
Lodgepole Pine, White Spruce, Black Spruce, Scots Pine, Western Hemlock, Red
Pine, Douglas Fir, Black Ash, Paper Birch, Pedunculate Oak, Silver Birch, Yellow
Birch, Northern Red Oak, American Beech, White Ash, White Oak, Sugar Maple,
European Beech, River Red Gum, Tasmanian Blue Gum, Lignum Vitae — and delegated
pricing ("You can set the pricing") and naming. He also chose, from the options
put to him: a wood is unlocked by a **lifetime-chopped milestone**, and the
**player picks** which unlocked wood goes on the block.

- **THAT LIST IS IN JANKA HARDNESS ORDER** (Aspen ~350 lbf to Lignum Vitae ~4500,
  the hardest commercial timber on Earth). That is the spine the whole ladder is
  derived from, and it makes Sam's already-approved rule fall out for free:
  **harder wood → splits less often → pays more → unlocks later.** `SpeciesDef.
  janka` carries the real-world figure as the DERIVATION RECORD, so a future
  species is slotted in by looking up one number instead of guessing.
- **`res://data/species_table.tres` + `species_def.gd` / `species_table.gd`
  (`class_name SpeciesDef` / `SpeciesTable`) REPLACE the `_LOG_SPECIES` const**
  that lived in `chopping_minigame.gd`. It had to move: 25 rows of dictionary
  literal do not belong in a gameplay script, and the **yard HUD is 2D-side (A9)
  and must never import the 3D mini-game** to find out what a wood is. `SpeciesTable`
  is static and NOT an autoload, for the same reasons as Market/Shop/SaveSystem.
- **THE LADDER ORDER IS LOAD-BEARING, not cosmetic:** the woodshed lists it top to
  bottom, `next_locked()` walks it to find the player's next goal, and
  `m7a_acceptance` asserts price, difficulty and unlock cost are all monotonic
  along it — so a wood cannot ship as the most valuable AND the easiest.
- **THE HOLE THIS CLOSED.** `_pick_species_index()` was `randi() % size`. With 25
  woods that would have put **Lignum Vitae on the player's first log, free, at
  2600 a piece**. It now reads the player's choice from GameState.
- **THE UNLOCKED SET IS DERIVED, NEVER STORED** — a species is unlocked exactly
  when `lifetime_wood_chopped >= unlock_at`, and that counter is already monotonic
  by construction. No second source of truth to drift, nothing extra to save, and
  **a retuned ladder applies to an existing save** instead of freezing its old
  thresholds in. Only the player's CHOICE persists, because nothing else implies it.
- **`GameState` gained `species_unlocked` and `selected_species_changed`** —
  LOCAL signals, Amendment 2's precedent exactly. **A7 is untouched**, and
  `environment_unlocked` was NOT reused: it carries an `Enums.Biome`, that enum is
  frozen at four values, and a wood species is not a biome.
- `select_species()` is atomic like `try_spend_cash`: an unknown or unearned wood
  changes nothing and emits nothing. `get_selected_species()` ALWAYS resolves to
  something choppable — a pre-selector save, a deleted species, or a choice a
  retuned ladder put out of reach all fall back to the starting wood.
- The unlock crossing compares **before and after**, not the new total alone: one
  finished log deposits six pieces in one frame and can cross two milestones, and
  a species must announce itself exactly once, ever.
- **`res://scenes/2d_management/yard_hud`'s WOODSHED** lists earned woods with
  price and hardness, plus **exactly one locked row** as the next goal. A wall of
  24 greyed-out rows is a list of things the player cannot do; one named goal with
  the chops still to go is a reason to pick the axe back up. Rows are built from
  the table at runtime, so Sam's 25 woods needed no UI code per wood.
- **`item_registry.tres` gained 22 firewood ids** and `price_table.tres` prices all
  25. The three existing ids were **remapped onto the ladder rather than renamed,
  so saves survive**: `pine_firewood`→Eastern White Pine, `birch_firewood`→Paper
  Birch, `oak_firewood`→Pedunculate Oak.
- **ART DEBT, THE BIG ONE: 22 of the 25 woods have no art.** Only oak (log_01/02)
  and birch (6 shapes) exist, so every other species points at the oak FBXs and
  leans on a new `bark_tint` to tell itself apart. `_apply_bark_tint` **duplicates
  the material** — imported FBX materials are shared BY REFERENCE, so tinting in
  place would repaint that wood for the whole process. WHITE means "has its own
  art, leave it alone" and is where every row should end up. **Rendered and judged:
  River Red Gum reads genuinely red, Lignum Vitae olive, Aspen pale.**
- **Verified by 39 checks in `m7a_acceptance` (tests 18, 21–24)**, and all four new
  guards are **proven to fail without their fix** (let selection ignore unlocks →
  3 red; announce every earned wood on every gather → 3 red; restore the random
  species roll → 2 red; drop the out-of-reach fallback → 2 red).
- **NUMBERS THAT ARE SAM'S:** the 25 species and their order. The starting wood's
  `split_chance` **0.55 is his** ("roughly 45% to start") — it belongs to the
  STARTING LOG, so it moved with that role from oak to Quaking Aspen.
- **NUMBERS THAT ARE PLACEHOLDERS (Directive 3), all in data:** the price ladder
  (1 → 2600, ~1.35x a rung), the other 24 split chances (0.55 → 0.12), all 25
  unlock thresholds (0 → 70,000 lifetime pieces) and every tint. The late
  thresholds are deliberately beyond hand-chopping — M8's certified auto-cutting
  (the Mechanical Splitter, bought through the shop) arrives first.
- **KNOWN, and Sam's call:** the strength upgrade caps at +0.5 split chance over 10
  levels, so the top of the ladder (0.12 base) needs `size_relief`, scars and the
  shop together to stay playable. **Run `core/tools/split_odds.tscn` before
  signing the curve off** — it measures the FELT failure rate, which is not the
  authored one.
- **The Janka check in `m7a_acceptance` is deliberately NOT strict per rung.**
  Sam's order is authoritative and real hardness has near-ties inside it (Silver
  Birch 1110 sits just above Pedunculate Oak 1120; both beeches are level with
  Sugar Maple). Bending a real-world figure to satisfy a test would corrupt the
  very record the ladder is derived from, so the check asserts no rung is
  *dramatically* softer than the one below it.
- **`m4_acceptance` moved 42 → 40 checks**, and is stronger for it: test 6's
  per-species row checks are aggregated (25 woods, not 3) and the expensive live
  spawn now runs once per DISTINCT MESH PATH — 22 rows share the same two oak
  FBXs, so the old shape measured the same eight imports 25 times. Tests 3, 4, 16
  and 17 **stopped hardcoding "species 0 is oak"**, which the reorder broke.

### M7B — XP, levels to 99 and the skill tree (2026-08-02, no sign-off yet)

**Creative Director call, and it RESHAPES the progression spine built earlier the
same day:** *"instead of just a single currency for everything, I want an
experience bar (with a max level of 99) that every level contributes to a 'skill
tree' so the currency we generate goes to things like new axes, auto cutters,
unlocking new logs etc and the skill tree goes towards player enhancements, like
cutting speed, swing timers, strength"*, plus *"when the log is finally split,
the log should also drop a bunch of green 'exp orbs' that get absorbed in to the
player (like in minecraft) higher skill logs drop more exp, high levels require
more exp to level up"*.

**TWO ECONOMIES NOW, and the split is the whole point.** Cash buys things in the
world (woods today; axes and auto-cutters when they are designed). Skill points,
earned by levelling, buy things about the PLAYER.

- **`res://data/level_curve.gd/.tres`.** `MAX_LEVEL = 99` IS SAM'S. The level is
  **DERIVED from total XP, never stored** — XP is monotonic, so a derived level
  cannot disagree with it, and retuning the curve **re-levels an existing save**
  instead of stranding it on thresholds that no longer exist. Same principle the
  wood ladder used before woods became purchases.
- **`res://core/skill_tree.gd` + `data/skill_node_def.gd` / `skill_tree.tres`.**
  Static, not an autoload (Market/Shop/SaveSystem precedent). It is a **REAL DAG**
  (Sam chose branching over a flat list): `requires` gates nodes, and
  `_validate()` hunts dangling prerequisites and CYCLES at load, because a cycle
  is invisible until someone reaches that branch and then just looks expensive.
- **Effects are a named KIND plus a step, never code per node.** The caller asks
  `SkillTree.total_effect(kind)` or `total_levels(kind)` and decides what the
  number means — swing speed COMPOUNDS (ten 5% cuts are not 50%), split strength
  SUMS. A new node is a row; only a new KIND of effect needs code.
- **COFFEE AND THE PROTEIN BAR LEFT THE CASH SHOP** and became Quick Hands and
  Strong Arms, keeping Sam's 5% steps. `upgrade_table.tres` is now EMPTY on
  purpose — axes and auto-cutters are named in the direction but not designed, and
  inventing rows for them would be Directive 3 all over again.
- **Skill points are DERIVED too**: earned = level - 1, spent = the sum of what the
  owned nodes cost. So there is no purse to drift, and a retuned tree or a deleted
  node cannot leave the player in point debt (`apply_save_dict` drops unknown
  skills and clamps to the current cap).
- **`GameState.can_afford_skill_points` is deliberately NOT named `try_spend_*`**,
  which everywhere else in that file means "take it or change nothing". There is no
  pool to take from — recording the skill IS the spend.
- **XP IS PER LOG, NOT PER PIECE** ("when the log is *finally split*"). One award
  at `_begin_stacking`, gated on `auto_sell` with the cash payout, so M4 still
  tests the yield contract with the economy switched off.
- **`SpeciesDef.xp_reward`** climbs the Janka ladder — the wood that resists most
  teaches most.

### M7B — woods became level-gated purchases (2026-08-02) — REVERSES M7A

**The morning's lifetime-chopped milestone gate is GONE.** Sam chose "level gates
it, cash buys it" when asked directly.

- `SpeciesDef.unlock_at` becomes **`unlock_level` + `unlock_cost`**.
- **THE OWNED SET IS NOW STORED, and that reversal is the important part.** The
  derived set was safe *because* `lifetime_wood_chopped` is monotonic and could not
  disagree with itself. A purchase is a discrete event that nothing else implies —
  a level says a wood MAY be bought, never that it WAS — so `_owned_species` has to
  persist. The starting wood is granted by `owns_species()` rather than stored, so
  a fresh, wiped or corrupted save always has something to chop.
- `try_buy_species` is atomic and ordered: refuse unknown / already owned /
  under-level / unaffordable, take the cash, and only then grant the wood.
- **`GameState.species_unlocked` is deleted**; `species_purchased` replaces it.
- The **woodshed is a store**: owned woods to choose from, plus exactly one row for
  the next wood — its price if it is on sale, or the level still to reach.
- **Verified by 34 new checks in `m7a_acceptance` (now 212/212)**, and the four
  load-bearing guards are **proven to fail without their fix** (ignore the level
  gate → 3 red; ignore skill prerequisites → 1 red; pay XP per piece → 1 red;
  store the level instead of deriving it → 2 red).
- **PLACEHOLDERS (Directive 3):** the whole level curve (`base_xp` 40,
  `curve_power` 1.8), every `unlock_level` (1 → 96), every `unlock_cost`
  (0 → 300M), every `xp_reward` (8 → 56,000), and every skill cost/step except
  Sam's two 5%s. These want tuning together against real play, not one at a time.
- **THE GREEN XP ORBS** (`res://scenes/3d_action/xp_orb.gd`, `class_name XPOrb`).
  **REVISED 2026-08-02** (Creative Director call: *"the experience should explode
  out a little and fall on to then bounce a little the ground near the log for a
  moment before flying to camera"*, *"pop out the moment the final piece is split,
  so all the collecting happens at once"*, *"arc towards the player, not just a
  direct line"*, *"glow a tiny amount as well and be a little transparent"*). FOUR
  phases now: BURST off the block, BOUNCE on the yard floor, a REST beat lying in
  the dirt, then an ARCING DRAW into the camera. Script-animated, not physics —
  A12 caps active rigid bodies and spending that budget on confetti would push
  real firewood out of the sim. One shared mesh, halo and material across every
  orb ever spawned. UNSHADED for the same reason the failure scar is: an orb is a
  light source in the fiction, and a lit one would go dim in the stump's shadow,
  which is exactly where they are born.
- **The burst and the bounce are INTEGRATED, not lerped.** A bounce is the one
  thing a keyframed path cannot fake — the second hop has to be a consequence of
  the first landing, or every orb bounces identically. Only the rush home is eased
  by hand, since that one is a magnet and not physics. The horizontal speed is
  solved from each orb's OWN fall time so its first touchdown lands in a ring
  OUTSIDE the stump: an orb that lands on the block it came off is the one thing
  the effect cannot survive looking like.
- **`orb_collect_at` is shared by the whole burst**, so the handful leaves the
  ground together ("all the collecting happens at once"). The first cut of this had
  a per-orb rest timer, which stacked on top of each orb's own landing time and
  dribbled them home one at a time — visible instantly in `orb_shot`, invisible to
  any counter. `orb_stagger` is now tiny (0.012) for the same reason: it exists
  only so they do not all leave on one identical frame.
- **`_ABSORB_DIST` (0.4 m) is not cosmetic trimming.** Flying to the camera's exact
  position means arriving at zero distance, where angular size explodes and a 2 cm
  bead becomes a green slab across a quarter of the screen. `orb_shot` caught
  exactly that: every orb correct, two of them billboards in the lens.
- **THE ORB BACKS OFF ALONG THE CAMERA'S VIEW AXIS, NOT ALONG ITS OWN APPROACH.**
  Backing off the way it came looks obvious and is wrong: every orb starts on the
  ground, so that line comes up from below and the whole burst converged UNDER the
  lens — Sam: *"it just flys to the players feet"*.
- **AN ORB THAT SHRINKS AS IT CONVERGES ON THE MIDDLE OF THE FRAME IS AN ORB GOING
  AWAY**, however fast it travels — Sam read exactly that as *"being absorbed in to
  the log"*. Three things carry "it is coming at me", and all three are load-bearing:
  it **shrinks by less than it closes** (`_DRAW_SHRINK` 0.25 against a trip that
  ends at `_ABSORB_DIST` 0.45 m), so apparent size roughly triples; it ends on a
  **disc** (`_ABSORB_SPREAD`) rather than a point, so the burst fans across the
  frame the way anything passing a camera does; and the ease is **quadratic, not
  cubic**, so the approach is 35 frames of visible closing instead of three.
  `orb_probe` measures all of it — the numbers are the check, the PNG is the judge.
- **UNSHADED MEANS `emission` IS NEVER READ** — an unshaded surface outputs albedo
  and nothing else, so the emission settings this shipped with did nothing. The
  glow is a real object: a small additive billboard quad wearing a code-built
  radial `GradientTexture2D`, because screen-space glow is not something to rely on
  under gl_compatibility. `billboard_keep_scale` is load-bearing — billboarding
  rebuilds the basis, and without it the draw phase's shrink is thrown away and the
  halo arrives at the camera full size.
- **AN ADDITIVE SURFACE FADES BY GOING BLACK, NOT BY GOING TRANSPARENT.** This is
  the "square exp bubble" (Sam, 2026-08-02) and it is the trap to remember: additive
  blending ADDS the source RGB, so a gradient that fades only its ALPHA still adds
  full green out to the rim and renders as a hard flat CARD. The halo gradient now
  fades its COLOUR to black; alpha rides along. Diagnosed with `orb_probe`, which
  proved the texture correct (centre alpha 0.53, corner 0.0) while the quads on
  screen were squares — art vs blend, settled in one run.
- **THE ORB IS THE RECEIPT, NOT THE PAYMENT.** XP is banked the instant the log is
  finished, never on absorption — quitting during the second of flight must not
  cost the player the log they just chopped, and the save must not disagree with
  what they watched happen. Since 2026-08-02 that instant is the FINAL SPLIT
  (the tail of `_perform_split`), not `_begin_stacking`: the settle wait is up to
  `firewood_settle_timeout` long, so awarding there put the reward a beat behind
  the swing that earned it. It is still ONE award per log.
- **How many orbs is a CURVE, not a ratio:** `sqrt(xp) * density`, clamped 5–16.
  A log worth 8 XP and one worth 56,000 both have to read as "a handful"; one orb
  per XP would bury the late game in confetti.
- **`core/tools/orb_shot.tscn` catches the burst MID-FLIGHT — RUN NON-HEADLESS.**
  A count of orbs proves nothing about an effect whose whole job is to feel like
  being paid. It shoots all seven beats; run it on any orb change. Every bug in the
  2026-08-02 revision (the dribbling wave, the orbs in the lens, the flat halo, the
  approach that read as retreat) was found in its PNGs or `orb_probe`'s numbers, and
  none of them was visible anywhere else.
- **A SHOT LIST COUNTED IN FRAMES LIES.** Writing a PNG costs tens of milliseconds,
  so each save pushes the next shot further out of step with an effect that runs on
  real time: this tool's later shots walked clean past the end of the burst and
  photographed an empty yard, which reads exactly like an orb bug that is not there.
  It now waits on ELAPSED TIME and writes every image after the run. Anything else
  in this project that shoots a timed effect wants the same shape.

### M7A — introductory orders and the contract board (2026-08-03, tuning pending)

- **THREE AUTHORED PLACEHOLDER ORDERS ARE LIVE:** Campfire Warm-up (10 any, +5),
  Aspen Hearth Load (15 Aspen, +10) and Pine Campsite Load (20 Eastern White
  Pine, +30). These six values are isolated in `data/order_table.tres` and are
  explicitly awaiting Creative Director sign-off; no gameplay code asserts them.
- `core/orders.gd` is stateless like Market/Shop. It pays every landed piece
  through the unlimited Market first, then credits a matching active order, so
  unmatched work always auto-sells and a failed sale can never earn contract
  progress. One patient order may be active; completed orders are one-time.
- Active id/progress and completion history live in GameState, survive save/load,
  and emit local repaint/autosave signals without changing frozen A7.
- The yard has a data-driven Contract Board. Its brown panel is deliberately a
  native `StyleBoxFlat` placeholder; `hud_shot_2d_orders.png` proves all three
  choices and an active progress bar fit together at 1280×720.
- Verified by 21 added checks: `m7a_acceptance` is now **245/245**. M4 remains
  **55/55** and the slicer remains **34/34**.
- Still to do in M7A: the tangible cash-purchase catalogue. Its behaviours and
  tuning remain a Creative Director call. The unlockable-species requirement is
  complete through the level-gated, cash-purchased 25-wood ladder.

### M4 — the axe became a CAMERA VIEWMODEL on an AnimationPlayer (2026-08-02)

**Creative Director call:** *"Currently the axe swing in the game looks bad, the
animation feels clunky and I want a little more create control over it. It should
look as if the axe is being over-head swung from where the camera."* Sam specified
the node tree and the four beats himself, and then, seeing the first pass:
*"the axe can just swing down from off screen, we dont need to see it rise in to
frame, it looks weird."*

- **`res://scenes/3d_action/axe_viewmodel.gd` (`class_name AxeViewmodel`) REPLACES
  `axe_rig.gd`, which is DELETED** (recoverable from git). The old rig was a
  world-space axe that flew from the impact point to the wood along a hand-built
  Bezier between two hardcoded euler poses. Nothing about it could be keyframed,
  which is exactly the "no creative control" Sam is describing. The rig is now
  authored in `chopping_minigame.tscn`, hanging off the camera:

  ```
  Camera3D
  └── AxeViewmodelAnchor      (axe_viewmodel.gd — fixed to the camera, aims the swing)
      ├── AxeAnimationRoot    (the ONLY node the animation moves)
      │   └── axe_basic.fbx   (scale 1.4 lives here)
      └── AnimationPlayer     (plays "swing" from res://data/axe_swing_lib.tres)
  ```

- **THE ANIMATION OWNS THE GAMEPLAY BEAT, and that is the point of the rebuild.**
  `swing` carries a METHOD TRACK whose key calls `AxeViewmodel._on_swing_contact()`
  at the frame the blade bites; that emits `contact`, and `chopping_minigame` runs
  `_resolve_pending()` there. Move the key in the editor and the wood breaks
  somewhere else. **This closed a real bug:** the scene carried `swing_time = 1.0`
  while the split fired off a separate `anticipation_sec = 0.1` timer, so the log
  came apart while the axe was still up in the air. Two owners for one moment.
- **The method key is DEFERRED** (AnimationMixer's default). The split adds and
  frees nodes; doing that from inside the mixer's own process is asking for it.
- **THE FAILSAFE IS LOAD-BEARING, and it is proven.** The mini-game does not trust
  the signal: `contact` comes from a key in an editable data file, and a `swing`
  re-keyed without one would leave a strike pending forever — which blocks every
  future click and stops the game dead. `_strike_timeout()` arms a deadline from
  `contact_time() * strike_timeout_slack`, and `_resolve_pending()` clears
  `_pending` FIRST so the key and the deadline can never spend the same strike.
  `m4_acceptance` strips the method track out of a copy of the animation and
  asserts the wood still splits.
- **`anticipation_sec` survives only as the no-viewmodel fallback.** A missing
  anchor is a warning, not an error — a scene stripped down for a test should not
  need a viewmodel to chop wood.
- **The swing IS the cooldown now.** A click is refused while `is_swinging()`, so
  `swing_cooldown` is a floor beneath the animation rather than the whole gate. The
  swing-speed skill therefore drives `AxeViewmodel.set_speed()` (the ratio
  `swing_cooldown / current_swing_cooldown()`), so "5% faster between swings"
  speeds up the SWING — an upgrade you can see beats one you can only measure.
- **THERE IS NO WINDUP IN FRAME.** The swing starts already raised and parked past
  the right edge; the first thing the player sees is the head coming down. Total
  0.46 s, contact at 0.18 s — deleting the raise took the dead time at the front of
  a click with it.
- **`res://core/tools/build_axe_swing.gd` authors the default swing**, because a
  `rotation_3d` track stores QUATERNIONS and nobody should be typing or reading
  those. A pose is written the way it is thought about — where the hand is, which
  way the handle points — and the quaternion falls out. **It is a default-builder,
  NOT a build step: running it again overwrites Sam's tuning.**
- **The roll is DERIVED, not authored** (`handle x swing_plane_normal`). Authoring
  "which way is the edge facing" per pose was tried first and produced a spin,
  because that sense flips as the handle passes vertical.
- **TWO FRAMING RULES, both learned from PNGs and invisible in every number:**
  (1) *the grip moves, the head is what swings* — the first pass drove the head
  from 0.27 m to 1.15 m from the lens in 0.09 s, and a 4x change in apparent size
  reads as the axe shrinking away from you, not as a chop; (2) *the handle butt is
  never on screen* — the second pass left the butt floating mid-frame and it read
  as a fence post. `build_axe_swing`'s report prints the grip's SCREEN position for
  every key and flags any that is inside the frame, so rule 2 is checked rather
  than hoped for.
- **`core/tools/axe_shot.tscn` shoots all seven beats — RUN NON-HEADLESS**, and run
  it on any change to the swing. Every problem above was found in its PNGs and none
  of them was visible anywhere else. It waits on ELAPSED TIME and writes the images
  after the run (the lesson `orb_shot` paid for), and it spaces the post-contact
  shots generously because A11's hit-pause fires there.
- **The aim lean** (`aim_yaw_deg` 6, `aim_pitch_deg` 4, PLACEHOLDERS) tips the whole
  anchor toward the click before the animation plays, so a swing does not land in
  the same pixel however far off-centre you clicked. Set both to 0 for a rigidly
  fixed viewmodel; the authored motion is never touched either way.
- **PLACEHOLDERS (Directive 3):** every pose, both timings and the axe's 1.4 scale.
  These are a starting point for Sam to re-key in the animation editor — which is
  the whole reason the motion moved into a data file.

### Files the chopping game owns

`scenes/3d_action/`: `chopping_minigame.gd/.tscn`, `chopping_minigame_harness.tscn`,
`mesh_slicer.gd`, `mesh_utils.gd`, `fragment_piece.gd/.tscn`,
`fragment_physics_budget.gd`, `piece_animator.gd`, `wood_pile.gd`,
`axe_viewmodel.gd` (**replaced `axe_rig.gd`, deleted 2026-08-02**), `canopy_gobo.gd`,
`xp_orb.gd`.

`scenes/2d_management/`: `yard_hud.gd/.tscn` (the yard HUD, the basic buyer's
front end, the shop, the woodshed and the entry flow) — the first thing this
folder has ever held.

`data/`: `species_def.gd`, `species_table.gd`, `species_table.tres` — the 25
woods. The chopping game reads them; so does the yard HUD, which is the whole
reason they are a Resource and not a const in the mini-game. Plus
`axe_swing_lib.tres` — the axe's `swing` animation, which owns both the motion and
the frame the wood breaks on.

`core/tools/`: `test_slicer`, `chopping_smoke`, `chop_diag`, `pile_smoke`,
`pile_shot`, `shot_runner`, `hud_shot`, `scar_shot`, `split_odds`, `jag_shot`,
`axe_shot` (the swing, beat by beat — run it on ANY change to the swing animation),
`build_axe_swing` (authors the DEFAULT swing into `data/axe_swing_lib.tres`; it is
a default-builder, NOT a build step — re-running it overwrites Sam's tuning),
`orb_shot` (the burst, all four phases), `orb_probe` (the halo taken apart —
texture vs blend), `inspect_log`, `inspect_stump`, `probe_log`,
`species_shot` (renders EVERY row of `species_table.tres`, fresh and cut — run it
on any log drop AND on any `bark_tint` change; `_ONLY_SPECIES`/`_FIRST_MESH_ONLY`
narrow it from the full 124 PNGs), `inspect_fbx` (tree/size/material report), `inspect_materials` (the
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
7. **Start every session by syncing with the repo before touching anything.**
   Run `git status` (uncommitted or stray work must be surfaced and handled —
   never silently overwritten) and `git fetch origin && git log HEAD..origin/master
   --oneline` (or `git status -sb`, which shows ahead/behind once fetched) to
   check the local branch against `origin/master`. If local is behind, pull
   (fast-forward only — never `--force`) before starting new work, so changes
   land on top of the latest committed state instead of forking off something
   stale. `origin` is a real GitHub remote (see the pivot section above) — do
   not assume a solo local repo with no upstream to check.

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
  moot — the tree game is gone. Its ore clause is moot too — ore mining is gone,
  see Amendment 17.)
- **A3 size rule:** the ONLY size test anywhere is
  `piece.size_tier > GameFeelConfig.size_threshold`.
- **A4 folders:** `res://core/`, `res://data/`, `res://scenes/2d_management/`,
  `res://scenes/3d_action/`, `res://assets/`.
- **A6 enums** (in `res://core/enums.gd`, class_name `Enums`; **trimmed by
  Amendment 17, 2026-08-04** — was `ItemCategory{RAW_WOOD,MINERAL,GEM,REFINED}`,
  `ToolType{AXE,PICKAXE}`, `Biome{PINE_FOREST,MAHOGANY_FOREST,MOSSY_QUARRY,
  VOLCANIC_CAVERN}`):
  `ChopDirection{LEFT,RIGHT,UP,DOWN}`,
  `ItemCategory{RAW_WOOD,REFINED}`, `ToolType{AXE}`,
  `Biome{PINE_FOREST,MAHOGANY_FOREST}`.
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
17. **A6 enums trimmed: ore mining and yard-staff support removed** (Creative
    Director call, 2026-08-04 — Sam: "Get all that ore mining stuff out of
    there, this is logs only" and "I think the villagers stuff we can remove
    as well - the purchasing can be driven from the shops we have currently
    an unlocked via purchases in those shops"). This is a genuine Part A
    contract change under Directive 2, not a data-only edit:
    `Enums.ItemCategory` lost `MINERAL`/`GEM` (kept `RAW_WOOD`, `REFINED` —
    `REFINED` shifted from value 3 to value 1, so `item_registry.tres`'s
    surviving `wood_board` row was updated to match), `Enums.ToolType` lost
    `PICKAXE` (kept `AXE`), and `Enums.Biome` lost `MOSSY_QUARRY`/
    `VOLCANIC_CAVERN` (kept `PINE_FOREST`, `MAHOGANY_FOREST` — both trailing
    values, so nothing shifted).
    Deleted outright: `data/ore_vein_def.gd` (`OreVeinDef`, never had a live
    `.tres`), `data/villager_def.gd` (`VillagerDef`, same), the item-registry
    rows `stone`/`copper_ore`/`iron_ore`/`amethyst`/`ruby`/`sapphire`/
    `copper_ingot`/`iron_nail`, and `handoff/04_M6_ORE_MINING.md` /
    `handoff/06_M8_VILLAGERS.md`.
    `m1_acceptance.gd` and `m7a_acceptance.gd` used several of those ore ids
    (`stone`, `ruby`, `iron_nail`, `copper_ingot`) purely as convenient
    "some other registered item" fixtures for generic InventoryManager/Market
    mechanics unrelated to ore as a feature — duplicate-cost aggregation,
    atomic remove, the unsellable/unpriced-item path. Those were recast onto
    real wood items instead (`wood_board`, which is already unpriced, and
    spare firewood species) rather than removed, since the mechanics they
    verify are still real. The `MOSSY_QUARRY` save-restore check in
    `m7a_acceptance.gd` became `MAHOGANY_FOREST` for the same reason — any
    second biome would have proven the point.
    M8's "yard staff" framing (deliver/gather/stack/bundle/ship, morale) is
    gone with `VillagerDef`; M8's certified-automation pillar (the Mechanical
    Splitter) is unchanged, just reframed as a direct shop purchase with no
    staff intermediary — see the M8 line in APPROVED POST-PIVOT DIRECTION and
    MODULE ORDER & SCOPE above.
    Sam separately confirmed the long-horizon "staff" design pillar running
    through M9–M14 in `handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md` should be
    cut too, not just the near-term M8 villager concept. That document's
    "Staff and automation" section (Yard staff / Supplier and route staff /
    Space staff) and every other staff/crew/hire mention across it were
    rewritten the same day into purchased, installed automation tiers bought
    through the shop — same mechanic, no named characters or roster.
    **Not touched by this amendment:** `RecipeDef`/`BuildingDef` (generic
    crafting schema, not ore-specific).

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

**The 25 woods, in ladder order** (`res://data/species_table.tres` names the
species; these are the FIREWOOD they yield):

`aspen_firewood, pine_firewood, norway_spruce_firewood, balsam_fir_firewood,
lodgepole_pine_firewood, white_spruce_firewood, black_spruce_firewood,
scots_pine_firewood, hemlock_firewood, red_pine_firewood, douglas_fir_firewood,
black_ash_firewood, birch_firewood, oak_firewood, silver_birch_firewood,
yellow_birch_firewood, red_oak_firewood, beech_firewood, white_ash_firewood,
white_oak_firewood, sugar_maple_firewood, european_beech_firewood,
river_red_gum_firewood, blue_gum_firewood, lignum_vitae_firewood`

Everything else: `mahogany_firewood, wood_board`

**REDUCED 2026-08-04.** `stone, copper_ore, iron_ore, amethyst, ruby, sapphire,
copper_ingot, iron_nail` were deleted along with ore mining — see the amendment
log. `wood_board` remains: it is wood, just unpriced and unsold today.

**EXPANDED 2026-08-02** for Sam's 25 species. The three wood ids that already
existed were **remapped onto the ladder rather than renamed**, so an existing save
keeps its stock: `pine_firewood` is now Eastern White Pine (rung 2),
`birch_firewood` is Paper Birch (rung 13) and `oak_firewood` is Pedunculate Oak
(rung 14). Their display names changed to match; nothing asserts a display name.

**`mahogany_firewood` IS ORPHANED.** Mahogany is not one of Sam's 25 trees. The id
is still registered and still priced at 25 (a placeholder from before the ladder,
now far below where a rare hardwood would sit), and no species yields it. Left in
place rather than deleted — removing an id from the registry is a save-compat
decision, and it is Sam's. **Ask before building anything on it.**

**RENAMED 2026-08-01, Creative Director call ("we can call it firewood").** The
four wood ids were `*_log`, which meant chopping a log *yielded logs* — the wrong
noun to build an economy on. They are now `*_firewood`, display names to match
("Oak Firewood"). `birch_firewood` was added the same day with Sam's birch art;
it is no longer pending.

There are deliberately **no `*_log` items**. Logs are not inventory today — they
spawn on the block and are consumed by chopping. The roadmap's "log supply"
upgrade family is about what spawns, not about a stored resource. If logs ever
need to be stock, add the ids then.

No test asserts this LIST as such, but since 2026-08-02 `m4_acceptance` does
assert that every species in the ladder yields a REGISTERED id, and
`m7a_acceptance` that the buyer prices all 25 — so a wood added to the table
without an ItemDef or a price now goes red instead of silently vanishing on
collection. The 2026-08-01 `*_log` → `*_firewood` rename touched no logic at all,
because `lifetime_wood_chopped` filters on `ItemCategory.RAW_WOOD`, not on names.

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
  `SpeciesDef.inside_tex`/`inside_normal`. Those must be **tileable** —
  cut-face UVs are a metres-based tiling mapping, so a log-end "disc" texture
  repeats into a grid of discs. Oak and birch each have a `*_tilable` set.
- Style: flat-shaded low-poly, vertex colors preferred over textures,
  hard edges fine, readable silhouettes.
- Fragment pivots at the piece's landing/contact point (predictable A12
  physics).
- Live art in `res://assets/ui/`: `coin.png` (Sam's drop, 2026-08-01) — the
  shop's icon and the cash readout's.
- Live art in `res://assets/models/`: `axe_basic`, `chopping_stump_a`,
  `forest_floor`, `logs_export` (log_01…log_05). `trees_export` was deleted in
  the pivot.
- On disk:

| Path | What |
|---|---|
| `C:\Users\Sam\Documents\the_axeman\` | **Repo root — now a git repo.** CLAUDE.md, handoff pack, source images, Maya files. |
| `...\the_axeman\the-axeman\` | **The Godot project.** Everything shipped goes here. The stale root-level `core/` and `data/` duplicates that used to sit beside it were deleted 2026-08-04 — `the-axeman\core\` and `the-axeman\data\` are now the only copies. |
| `...\the_axeman\maya_working\models\` | Sam's Maya sources + FBX exports. Copy FBX into `res://assets/models/` when needed; never reference `maya_working` from the project. |
| `C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe` | The engine binary. |

---

## MODULE ORDER & SCOPE — APPROVED COZY LUMBERYARD ROADMAP

The binding post-pivot roadmap is
`handoff/08_COZY_LUMBERYARD_ROADMAP.md`. In order:

1. **M1–M4:** existing contracts, shell, GameFeel and chopping. Preserve and
   finish Creative Director tuning/sign-off.
2. **M5:** tree felling — deleted and retired.
3. **M6:** ore mining — deleted and retired 2026-08-04. This is logs only; do
   not reintroduce it unless Sam separately reverses this.
4. **M7A:** first cozy progression slice — always-available basic buyer, three
   authored orders, cash, firewood stock, lifetime chopped, five tangible
   upgrades, one unlockable wood species and a visibly growing stockpile.
5. **M7B:** craftsmanship and expanded lumberyard — reputation, cut-quality
   bonuses, size/species orders, customer families and meaningful yard/axe/
   supply/transport upgrades. Imperfect pieces always remain sellable.
6. **M8:** first certified Mechanical Splitter — prove that automation, bought
   directly through the existing shop, replaces commodity hand production for
   a solved wood. No yard-staff/villager roster; unlocking and purchasing stay
   shop-driven the way M7A already built them.
7. **M9–M11:** regional supplier network, national/continental automation
   growth, global wood mastery and the final terrestrial-species
   showcase. Regions deliver logs; there is no felling or forest-depletion layer.
8. **M12–M14:** launch programme, first alien timber expedition and an
   interstellar log-supply/mastery loop.
9. **Postgame candidate:** the cosmic-catalogue/endless layer, only after the
   authored Earth and space campaigns are complete.

The detailed long-horizon order is binding in
`handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md`, but it is not permission to
start a later module before the current one is signed off.

The old `05_M7_MANAGEMENT.md` was historical input, not a build spec — its
replacement scope lives in the cozy roadmap. `06_M8_VILLAGERS.md` and
`04_M6_ORE_MINING.md` were deleted outright 2026-08-04 along with the villager
and ore-mining concepts they described (see the amendment log); they are not
even historical inputs any more. Continue to use `02_M4_CHOPPING_BLOCK.md` and
`07_M4_SLICING_POC.md` for the live chopping implementation and render/debug
traps.
