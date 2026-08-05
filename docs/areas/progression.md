# Progression area guide

Read this only for inventory, cash, saves, orders, the shop/woodshed, species
ownership, or the yard HUD.

## Ownership boundaries

- `InventoryManager` is the only inventory writer.
- `GameState` owns cash, lifetime chopped, XP/level state, owned species, yard
  pile state, skills, orders, and save integration exposed through its public
  API.
- Static helpers such as Market, Shop, SkillTree, and SaveSystem are not
  autoloads unless the live project says otherwise.
- The bottom-right Tree Catalog is a standalone frequently checked window. The
  Shop contains separate Items, Mechanical Splitter and Purchased tabs;
  certified profile assignment is chosen from the relevant Tree Catalog row and
  written by `GameState`.
- Purchased is a read-only view derived from existing building tiers. Completed
  one-time purchases and maxed tiered rows move there in authored order; a
  tiered row stays in its functional tab while another rank remains. Never add a
  duplicate purchase-history authority or save field for this presentation.
- Cash changes are atomic through the current `GameState` methods. A failed
  purchase changes nothing.

## Watched Mechanical Splitter (M8 Slice 4)

- `GameState.get_splitter_assigned_species()` is the sole species route. The
  runtime admits it only through `MechanicalSplitter.can_accept_species()`.
- The player loads one transient assigned log into one bounded input slot. Logs
  remain chopping inputs, not inventory; supplier/delivery simulation is not in
  this slice.
- Only active yard time advances the cycle. Runtime queue, partial progress and
  completion receipts are not saved; loading/resetting cancels them and grants
  no output.
- A successful completion reads `SpeciesDef.yield_item`, deposits it through
  `InventoryManager`, then sells exactly that receipt through
  `Market.sell_automation()`. Inventory removal remains in `InventoryManager`;
  cash arrives through `GameState`.
- Automation starts at 20% of the assigned `SpeciesDef.xp_reward`, written by
  `GameState`. It does not advance orders, emit manual gather/log roots, add
  lifetime chopped or mastery/certification, or trigger manual skill procs.
- One static representative log proxy is shown during processing regardless of
  species or Logs per Split rank. It disappears on settlement; no runtime slice
  or multi-species geometry load occurs.
- Splitter upgrades reveal sequentially: Speed → Auto Loading → Logs per Split
  → Experience Gain → Money Gain. The first prior rank/purchase reveals the next
  line. Auto Loading is one-time; the other four are bounded ranks persisted in
  existing building tiers.
- `data/mechanical_splitter_runtime.tres` is the single typed source for cycle
  duration, queue capacity, output amount, the speed floor, Sam's approved
  starting 20% XP rate, and the approved 5-to-12 Logs per Split band. That line
  adds exactly 1 represented log per rank. The matching catalogue rows in
  `data/upgrade_table.tres` own Sam's approved prices, growth, ranks and effect
  steps; runtime code must not duplicate those mappings.

## Current economy

- Chopping yields registered `*_firewood` items. Logs themselves are transient
  chopping inputs, not inventory.
- Cash purchases world-facing goods such as species and later equipment or
  automation. Skill points purchase player capability.
- Level gates determine when a species may be bought; cash buys it; the owned
  set persists. The starting species remains available by construction.
- Species definitions and their ladder order live in `data/species_table.tres`.
  Item validity lives in `data/item_registry.tres`; prices live in the current
  price/market resources. Inspect those files instead of copying ID and price
  lists into documentation.
- Sam's 2026-08-05 economy injection multiplies every firewood entry in
  `data/price_table.tres` by 4 while preserving the authored relative ladder.
- The basic buyer keeps unmatched work sellable. Orders reserve matching
  inventory atomically and must not produce payout after a failed sale.
- Progression saves are versioned. Unknown or retired data is handled by the
  live migration/validation code, not by prose assumptions.

## Verification

- Use `core/tests/m7a_acceptance.tscn` for progression, buyer, shop, orders,
  species, and save contracts.
- Use `core/tools/save_probe.tscn` modes only as temporary feel-test setup; they
  are not shipped progression or tuning authority.
- For yard/pile presentation, pair acceptance coverage with the relevant
  non-headless HUD or pile shot tool.
- For the watched splitter, run `core/tools/m8_splitter_shot.tscn` non-headless
  and inspect the native greybox, missing-art label, card state and progress.

Historical narrative is in `docs/history/03_m7a_progression_economy.md`. The old
M7 management and purchase briefs are background, not prerequisites.
