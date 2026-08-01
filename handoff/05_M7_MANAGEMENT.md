# M7 — 2D Management (inventory UI · buildings · refining · upgrades)

Status at handoff: direction only. M7 is where the 2D half of the hybrid
finally exists — the game stops booting to an empty screen, and the M-key
debug toggle finally dies.

## Scope fence

IN: the 2D management mode UI (inventory display, buildings, refining
queues, gear/building upgrades); real entry/exit flow into the 3D
mini-games (emitting `minigame_entered(biome)` / `minigame_exited` from UI);
BuildingDef/RecipeDef-driven data; removing `main.gd`'s M2/M3 TEMPORARY
debug blocks.
OUT: villagers/morale (M8 — but see the multiplier hook below), save/load
unless the blueprint says it lands here (ask), art polish.

## Binding contracts

- **A9 (critical, easy to get wrong):** ALL gameplay UI lives on
  `UI_Overlay` (CanvasLayer, layer 2) — **never** inside `UI_Canvas`.
  UI_Canvas exists only to hold the SubViewportContainer. The management
  screen is gameplay UI → UI_Overlay.
- **A10:** entering/leaving mini-games via the real EventBus signals; the
  mode switch itself is already in `main.gd` — do not duplicate it.
- **Amendment 2:** InventoryManager's local signal
  `inventory_changed(item_id, new_count)` fires on every count change
  including consumption — the UI binds to THIS, zero polling. It is local:
  connect directly on the InventoryManager autoload, not via EventBus.
- **Amendment 3:** non-increasing tier upgrades are warned+ignored by
  GameState — UI must therefore only offer valid next-tier upgrades.
- **Amendment 4:** cost lists aggregate duplicate ids; `remove_items` is
  atomic. UI affordability display uses `can_afford` (never re-implement
  affordability locally).
- Writes: UI NEVER mutates inventory/progression directly. Refining consume
  = `InventoryManager.remove_items`; outputs — **decision needed**: outputs
  via `EventBus.resource_gathered` or `InventoryManager.add_item`? Previous
  agent's lean: `add_item` directly (refining is not "gathering"; A7 signal
  semantics stay clean) — confirm with Sam.
  Upgrades = emit `EventBus.building_upgraded` / `gear_upgraded` after
  atomic cost removal succeeds. GameState applies them; UI re-reads.
- **A11 tail:** every production Timer in 2D-land sets
  `ignore_time_scale = true` (a 3D hit-pause mustn't stretch refining
  timers). Make the acceptance test assert this on every Timer in the scene
  tree (walk and check — cheap and catches regressions forever).
- Refining duration: `RecipeDef.base_seconds`, wrapped NOW in the M8 formula
  `effective_seconds = base_seconds / (role_bonus * morale_factor)` with
  both factors hard-defaulted to 1.0 via a single function
  (e.g. `Refinery.get_effective_seconds(recipe)`) — M8 then plugs in real
  factors at ONE call site.

## ⚠ Known data flag (in CLAUDE.md, unresolved on purpose)

Blueprint's M7 example mentions **"Mahogany Boards"**; the locked registry
has generic **`wood_board`**. **Ask Sam whether boards become per-species
BEFORE authoring any recipe/upgrade `.tres`.** If per-species: registry
change = contract-adjacent (locked id list in CLAUDE.md) → treat as an
amendment with new ids enumerated. This is the first Ask-Sam item of M7.

## Design direction

- `res://scenes/2d_management/management_root.tscn` (+ script), instanced
  under `UI_Overlay` in `main.tscn`. Visible in 2D mode; hidden while in a
  mini-game (drive visibility from the same EventBus signals `main.gd`
  already consumes — a sibling connection, not a `main.gd` rewrite).
- Inventory panel: rows built from
  `InventoryManager.get_all_counts()` + `get_item_def` (icons may be null —
  placeholder-safe), updated via `inventory_changed`.
- Buildings: author `res://data/buildings/*.tres` (BuildingDef). Building
  UI shows tier (`GameState.get_building_tier`), next-tier cost
  (`upgrade_costs[current_tier - 1]`... **verify indexing against the
  schema comment: index 0 = cost to reach tier 2**), affordability via
  `can_afford`, upgrade button → `remove_items` then emit.
- Refining: recipe list per building (`BuildingDef.recipes`); a running job
  = consume inputs atomically up front, Timer (ignore_time_scale!), on
  timeout add outputs. One job per building initially unless Sam says
  queues — ask.
- Entry to 3D: biome buttons gated by `GameState.is_biome_unlocked`,
  emitting `minigame_entered(biome)`. An in-3D "Return" affordance emits
  `minigame_exited` — where that UI lives (UI_Overlay stays visible over
  the viewport) needs Sam's input; simplest: keyboard Esc + on-screen hint
  on UI_Overlay.
- **Delete the M-key and H-key debug blocks from `main.gd`** once the real
  flow works; M2/M3 acceptance suites don't reference them (verify).
- Godot UI discipline: Control anchors/containers (VBox/HBox/Grid), theme
  variations later; remember the whole canvas is 640×360 logical
  (canvas_items stretch) — design chunky, readable at that resolution. If
  Sam wants hi-res UI, that's the M8 portrait conversation arriving early
  (CanvasLayer `follow_viewport` / transform tricks) — flag, don't
  improvise.

## Acceptance test — `m7_acceptance` (+ all older suites green)

1. Management UI is under UI_Overlay (walk the tree; assert nothing but the
   SubViewportContainer chain lives under UI_Canvas).
2. `inventory_changed` drives the UI: add via EventBus `resource_gathered`,
   assert the row's displayed count updated (no polling — assert no
   `_process` on the inventory panel, or just behavioral coverage).
3. Upgrade happy path: grant materials via EventBus → afford → upgrade →
   GameState tier incremented → costs consumed exactly once.
4. Upgrade blocked path: insufficient → button disabled/refused → zero
   consumption (atomicity re-proven at UI level).
5. Refining: job consumes inputs at start (atomic), produces outputs after
   `effective_seconds` (factors 1.0); no partial states if inputs
   insufficient.
6. Timer audit: every Timer under the management scene has
   `ignore_time_scale == true`.
7. Mode flow: biome button → `minigame_entered` → A10 flips (reuse M2
   assertions); return → management visible again.
8. Locked biome buttons: MAHOGANY_FOREST et al. disabled until
   `environment_unlocked`.

## Ask-Sam list for M7

1. **Boards: per-species or generic?** (the flagged decision — first ask.)
2. Building roster + recipes + upgrade costs + base_seconds (pure data; get
   at least one real building, else placeholder `.tres` clearly labelled).
3. Refining UX: instant-with-timer? queues? one-job-per-building?
4. Return-from-minigame affordance (Esc? button? both?).
5. Does save/load land in M7 or later? (Blueprint says — ask for the text.)
6. Biome → mini-game scene mapping for entry buttons (pine forest → M4
   chopping? Where does M5 felling live vs M4's block?).
