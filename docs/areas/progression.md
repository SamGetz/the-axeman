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
  Shop contains Items and Purchased tabs, revealing its separate Mechanical
  Splitter tab only after the machine gate is earned;
  certified profile assignment is chosen from the relevant Tree Catalog row and
  written by `GameState`.
- Purchased is a read-only view derived from existing building tiers. Completed
  one-time purchases and maxed tiered rows move there in authored order; a
  tiered row stays in its functional tab while another rank remains. Never add a
  duplicate purchase-history authority or save field for this presentation.
- Cash changes are atomic through the current `GameState` methods. A failed
  purchase changes nothing.

## Discovery rules

- Shop shelves contain unlocked unfinished rows only. Owned/maxed rows remain
  authoritative in Purchased, but a future row must never appear as a disabled
  teaser.
- A hidden row is advertised by the source that will reveal it: contract cards
  name their shop unlocks, prerequisite purchases name the next row, the first
  haul names the Handcart reward, the XP strip names the next contract, and the
  final mastery reward names splitter certification.
- The Mechanical Splitter tab is hidden until its combined prerequisite gate is
  satisfied. Certified profiles and the paced upgrade chain appear only when
  their own purchase/mastery prerequisites are satisfied.
- The splitter runtime card and Tree Catalog assignment controls are hidden
  until the machine/profile interaction exists. Mastery reward copy remains the
  forward promise before that point.
- The skill tree is the exception: it is an authored prerequisite map, so its
  connected locked nodes remain visible to explain branch structure.
- The contract board has Open and Completed tabs. Open lists the active contract
  first, then every revealed incomplete contract in authored order, including
  exact ownership requirements. Completed is compact and read-only. Neither tab
  exposes unrevealed work; the XP strip names only the next unrevealed contract.

## Startup save boundary

- `Main` presents New Game / Load Game before activating the yard. It does not
  call `load_or_start_fresh()` in production or infer the player's choice.
- Rendering, yard processing, HUD interaction, autosave and save-on-quit stay
  inactive until one choice succeeds.
- Load is available only when `SaveSystem.has_save()` is true. Missing, corrupt
  and newer-version results remain at the menu; they never fall through into a
  fresh autosaving session.
- New Game over an existing autosave requires confirmation. It resets through
  the public GameState and InventoryManager ownership routes, then uses the
  existing atomic `SaveSystem.save_game()` replacement before gameplay starts.
  A failed write leaves the prior save intact and reloads it into memory.
- Use `core/tests/startup_acceptance.tscn` for the behavioural boundary and
  `core/tools/startup_shot.tscn` for the native stand-in presentation.

## Reward presentation

- `GameState` remains authoritative for XP and cash. Flying orbs and coins are
  presentation receipts; quitting during their animation cannot lose or create
  progression.
- A completed manual log banks XP once, divides that exact award across pooled
  orbs, and lets the HUD advance its displayed total as each orb reaches the live
  XP-fill edge. The HUD reconciles to the authoritative total after the batch.
- Manual firewood still sells only when each pile piece lands. The exact cash
  delta from `Orders.settle_piece()`—including any completion bonus—is attached
  to one pooled coin. A coin waits in the yard until that delta exists, then its
  counter impact increments the displayed cash and applies one capped grow/bounce
  impulse. It must never hover beside the HUD awaiting authority.
- XP orbs, coins and the level-up celebration own resident node pools built at
  initial scene load. `Main` submits their materials for one covered render frame
  behind the startup menu so first-use shader compilation does not land on the
  first completion or level-up.
- The Mechanical Splitter owns separate resident coin/orb/chip pools. Settlement
  start stages one unpaid coin before cash changes; success attaches the exact
  runtime cash/XP receipt and cancellation removes the unpaid proxy. Manual and
  splitter effects may overlap without borrowing nodes or progression authority.

## Watched Mechanical Splitter (M8 Slices 4-6)

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
  species or Logs per Split rank. It uses the assigned species' existing bark
  and inside treatment, then disappears on settlement; no runtime slice or
  multi-species geometry load occurs.
- Every species has one profile. Aspen, Pine and Norway retain their approved
  early values; Balsam Fir through Lignum Vitae require their matching one-time
  contract, own certification and the installed machine. Their authored prices
  remain labelled post-M8 tuning placeholders.
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
  and inspect the full contract/profile/runtime matrix. Run
  `core/tools/m8_slice6_pacing_probe.tscn` headless for the labelled level
  9/49/96 economy snapshot.

Historical narrative is in `docs/history/03_m7a_progression_economy.md`. The old
M7 management and purchase briefs are background, not prerequisites.
