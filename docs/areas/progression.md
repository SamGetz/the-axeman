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
- The contract board has Open and Completed work; its legacy Commissions tab is
  permanently hidden. Open lists every revealed incomplete authored contract in
  authored order; Completed is compact and read-only. No tab exposes unrevealed
  work, and the XP strip names only the next unrevealed authored contract.

## Standing campaign commissions

- `GameState` owns persisted offer moments, generation, the sole active identity,
  progress, completion count and exact-once reward sources. `Orders` reads
  immutable templates and validates every saved snapshot.
- Exactly five campaign facts can prepare a choice: Pine Campsite completion,
  first regional route/company machine, terrestrial readiness, Earth zero and
  first alien mastery. Each presents three stable roles—mixed, highest-owned
  frontier and broader rotation—but accepts only one. Completing it closes the
  chip until the next campaign fact; fast work cannot create a menu loop.
- Premiums snapshot the labelled relevance ratio against the next meaningful
  species, launch project or missing alien production line, retaining delivered
  work value as a floor. Accepted work never drifts after generation.
- Authored contracts and one standing commission may coexist. A successful
  matching sale advances both. Each commission pays automatically exactly once;
  unmatched work still receives ordinary sale cash.
- `Market.sell_automation()` never reaches manual delivery credit, so splitter
  output cannot advance contracts or commissions.
- The compact top-right chip expands in place to show all three choices without
  a modal, board transition or scrollbar. Once selected it becomes a collapsed
  background-progress line. Collapse state is local presentation only.
- Save v17 persists campaign cycles, the source ledger and exact active progress.
  Older simultaneous slots are retained as legacy work without inventing new
  choices or replaying payouts.
- Same-frame delivery completions aggregate into one presentation receipt and
  later batches queue. Receipt presentation never changes authoritative cash.

## Craftsmanship, reputation and customers (M7B)

- `ManualPieceReceipt` carries item, species, normalised size, grade, source log
  and manual/automation origin. Item-only callers use a compatibility wrapper.
- `Craftsmanship` derives forgiving rough, clean and exceptional bands from
  normalised geometry. Rough always sells for base value; bonuses and thresholds
  live in the Craftsmanship section of `data/game_config.tres`.
- Reputation is monotonic and non-spendable. It unlocks typed customer families
  and later regions. Customer completion history is resource-bounded.
- Quantity, species, size, quality and signature orders settle only after an
  authoritative sale. Automation-origin receipts cannot earn craft grades,
  signature records, manual mastery, perfect-log records or Axeman XP.

## Logistics and regional company (M8–M10)

- `CompanySimulation` accepts persisted queues, priorities, dispatch capacity
  and elapsed time, then returns one unapplied receipt. Active and offline runs
  are mathematically equivalent for identical input.
- Input Line → Routing Desk → Continuity Dispatch is the three-stage typed
  logistics chain, bundling the former six maintenance clicks. Supplier input,
  blocked output recovery, dispatch work and the return ledger remain bounded.
- Offline time is available only after watched automation and is capped by
  resource data. It cannot discover/certify/master a species, complete a first
  story event or cross the Earth finale.
- `RegionalNetwork` assigns all 25 existing species to one of seven regions.
  Discovery, reputation, standing, depot, route and yard queue remain separate
  so the Atlas can name the exact delay and its next action.
- Road, rail and port routes remain usable. Craft House, Logistics Company and
  Global Specialist are freely adjustable provisional doctrines. Hydraulic
  Split Banks add bounded capacity without changing the watched splitter.
- Yard appearance is derived from purchases/projects: stump, shed, working yard,
  depot and headquarters. Never persist a duplicate cosmetic tier.

## Global Earth campaign and launch (M11–M12)

- `EarthCampaign.catalogue_rows()` derives the 25-row World Wood Catalogue from
  ownership, mastery, region, contract and profile state. Manual and automated
  log-equivalents persist separately; the combined total is a reader.
- Lignum Vitae is locked until the other 24 species are manually mastered and
  all three global projects are complete. Its three valid manual finale
  receipts complete the showcase; only depleting all 3.04 trillion Earth trees
  now sets Earth Master and reveals launch.
- `LaunchProgram` consumes existing cash/output/mastery plus explicit timber
  contributions removed by `InventoryManager`. Mission Control, Gantry, Orbital
  Test and Deep-Space Vessel complete in order without a new currency.
- Spacecraft range, cargo and shielding form a configurable persisted loadout.
  `ExpeditionSimulation` uses an injected clock and returns an unapplied arrival
  receipt. Output cannot change a planned arrival time.

## Four-hour pacing foundation (M15)

- `CampaignProgression` derives one phase and one actionable goal from live state:
  Cozy Clearing, Working Yard, Regional Company, Planetary Machine, Cosmic Finale
  and Complete. `CampaignGoalSnapshot` is read-only presentation data; all writes
  remain in `GameState` and its public signal flow.
- Credits require Earth at exactly zero, all three alien manual masteries, all
  three orbital lines, Frontier Master and the first combined orbital receipt.
  None of those facts alone can roll credits early.

- `EarthProductionDelta` is the exactly-once source contract for watched,
  company and offline production. Four unique completed manual source logs fell
  one tree; a persisted 0–3 remainder prevents reloads from losing or duplicating
  partial progress.
  Company simulation caps the tree budget before deriving recovered logs, cash
  or sublinear automation XP. Satellite Forest Survey is the explicit boundary
  where bounded depot queues become global work allocation.
- `lifetime_cash_earned` counts credited gameplay awards but not raw setup,
  migration, restore or refunds. Spending cannot lower it. Production rows
  require both their resource-authored earnings threshold and their live
  campaign milestone; ownership always survives later retuning.
- Sixteen bounded `ProductionUpgradeDef` rows cover parallel lines, recovery,
  grading, interval, dispatch, multi-species routing, planetary tree volume,
  launch continuity and alien cargo/orbital production. Every new numeric value
  remains labelled `PLACEHOLDER — four-hour reinvestment validation required`.
- Continuity Reserve prepays the minimum four-project cash/timber launch spine.
  Earth depletion, mastery, processed-output gates and sequential player actions
  remain required. The final Planetary Dispatch Core rank cannot be bought
  before the reserve.
- Save v17 includes Earth depletion, gross earnings, Earth receipt identities,
  manual-log remainder and
  exact-once feature introductions plus standing-commission campaign moments.
  Migration preserves compatible Earth Master
  launch access and raises gross earnings only to the minimum implied by owned
  progression; it never grants spendable cash.

## Alien campaign and repeat company (M13–M14)

- Each destination advances through survey, quarantine, identification, first
  specimen, manual certification, repeat cargo and manual mastery. New specimens
  are never automation-eligible.
- Spiralwood reveals a luminous weak band after a failed strike; Tideglass
  creates only a bounded low-gravity fragment fan; Cinderheart consumes visible
  scars for one non-recursive assist.
- Only certified/mastered destinations may commission bounded fleets and build
  orbital cutting lines. Soft charters change deterministic priority without
  resetting fleets or history.
- `AlienCompanySimulation` returns bounded idempotent receipts. Orbital output
  contributes automated log-equivalents but cannot alter manual mastery or
  certification. Earth headquarters and terrestrial systems remain live.

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

## First-time and contextual tutorial

- `data/tutorial_content.tres` is the typed source for guide identities,
  portraits, dialogue, objectives, completion conditions, reveal gates and the
  final two-second post-event presentation delay.
- Rowan Pike, Ada Gearhart and Nova Quill are UI-only presentation mentors. They
  are not restored villagers, staff or automation workers and own no progression.
- A fresh New Game shows only the untouched log and normal HUD. Chopping
  feedback, the coin counter and the XP bar teach the first interaction and
  reward loop without an outline or explanatory card. The first skill point at
  level 2 restores the Skills lesson; level 3 reveals Jobs, and completing the
  first authored job reveals Shop and authorises purchases. Cash and skill
  spending cannot bypass either gate. Tutorial cards can be closed temporarily
  without marking their lesson complete or permanently skipping later guidance.
  Tree Catalog keeps its separate post-opening affordability gate. Loading
  resumes only an armed/started tutorial on that save; existing progressed saves
  are not surprised by a new opening sequence.
- Shop, Tree Catalog and Contract Board lessons observe their real HUD actions.
  Tutorial code never
  calls cash, XP, inventory, purchase or unlock writers.
- The fresh dock is empty. Jobs, Skills, Catalog, Atlas, standing
  commissions, automation and launch guidance remain absent until their live
  public prerequisites are actionable. Future reward identities are not teased
  by the XP strip, Shop, Catalog or contract rows. Completion and skipping
  persist in the v16 introduced-feature ledger and participate in autosave.
- Related progression signals can arrive in one transaction. Deferred tutorial
  advancement pins the expected beat identity so one receipt cannot skip two
  dialogue beats. Every lesson waits five seconds after its triggering event,
  allowing reward and unlock feedback to settle first. If the player completes
  the lesson during that pause, the stale card is completed without appearing.
- Use `core/tests/startup_acceptance.tscn` for the behavioural boundary and
  `core/tools/startup_shot.tscn` for the native stand-in presentation.

## Reward presentation

- `GameState` remains authoritative for XP and cash. Flying orbs and coins are
  presentation receipts; quitting during their animation cannot lose or create
  progression.
- A completed manual log banks XP once, divides that exact award across pooled
  orbs, and lets the HUD advance its displayed total as each orb reaches the live
  XP-fill edge. Crossing a level boundary first holds the previous level at
  100%/0 XP remaining, then rolls over the visible level and presents its reward.
  The Skills reveal/tutorial and level-up VFX use that presented rollover rather
  than the earlier authoritative write. The HUD reconciles to the authoritative
  total after the batch.
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
- The Mechanical Splitter section of `data/game_config.tres` is the single typed
  source for cycle duration, queue capacity, output amount, the speed floor, Sam's approved
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
- Progression saves are versioned through v16. V13 preserves XP, uncapped
  derived level, cash, inventory and campaign state while fully refunding the
  retired skill layout, legacy cost bases and affected proc dry streaks. It
  seeds historical point entitlement and pays no retroactive level cash. V14
  refunds v13 skill selections while preserving point entitlement and cash,
  because ranked prerequisites cannot safely retain former descendants.
  V15 adds authoritative Earth receipts and lifetime earnings; V16 persists the
  0–3 completed-manual-log remainder while preserving already committed v15 trees.
  Unknown or retired data is
  handled by live migration/validation code, not prose assumptions.

## Proc-driven equipment cash sinks

- `data/equipment_upgrade_table.tres` extends the Shop catalogue with eight
  uniquely named one-time axes and eight uniquely named one-time stump/workstation
  identities. Ownership remains an ordinary building tier; no equipped-state or
  save-version field exists.
- Each chain is linear. Its early gates are the matching M7A equipment, Aspen and
  Pine jobs, then three terrestrial masteries; late gates are Log Feeder,
  Headquarters Yard, Earth Master and the first alien specimen.
- Only the highest owned identity in each equipment slot contributes its active
  proc profile. Every owned axe reliability step and stump work-radius step remains
  cumulative through `Shop.total_effect()`.
- Handcart Workshop and Tool Care Bench have four cash ranks. They retain their
  delivery/recovery effects and independently add Express Handoff and Follow-Up
  chance. Grading Lamp, Customer Record Cabinet, Supplier Holding Racks and
  Xenowood Specimen Vise remain non-proc craftsmanship, reputation, queue and
  alien-handling sinks.
- All prices, equipment chances, passive steps, auxiliary growth curves, tints,
  and the new 20/12-event fairness bounds are labelled placeholders. Existing
  approved skill chances remain unchanged.

## Verification

- Use `core/tests/m7a_acceptance.tscn` for progression, buyer, shop, orders,
  species, and save contracts.
- Use `core/tests/equipment_proc_progression_acceptance.tscn` for the 16 named
  one-time identities, gates, atomic spending, active/cumulative composition,
  gear-only proc access, fairness persistence and non-recursive runtime outcomes.
- Use `core/tools/equipment_progression_shot.tscn` non-headless with the
  Compatibility renderer to capture all eight axe/stump placeholder pairs.
- Use `core/tests/skill_overhaul_acceptance.tscn` and
  `core/tools/xp_pacing_probe.tscn` for uncapped levels, point/cash switching,
  exact orb shares and the complete terrestrial/alien XP ramp.
- Use `core/tools/save_probe.tscn` modes only as temporary feel-test setup; they
  are not shipped progression or tuning authority.
- For yard/pile presentation, pair acceptance coverage with the relevant
  non-headless HUD or pile shot tool.
- For the watched splitter, run `core/tools/m8_splitter_shot.tscn` non-headless
  and inspect the full contract/profile/runtime matrix. Run
  `core/tools/m8_slice6_pacing_probe.tscn` headless for the labelled level
  9/49/96 economy snapshot.
- Use the focused M7B–M14 suites for each campaign layer and
  `core/tests/full_campaign_acceptance.tscn` for the uninterrupted public-API
  path. Run `core/tools/campaign_visual_shot.tscn` non-headless for the atlas,
  catalogue, finale, launch and alien material acceptance set.

Historical narrative is in `docs/history/03_m7a_progression_economy.md`. The old
M7 management and purchase briefs are background, not prerequisites.
