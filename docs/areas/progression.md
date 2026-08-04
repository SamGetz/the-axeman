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
- Cash changes are atomic through the current `GameState` methods. A failed
  purchase changes nothing.

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

Historical narrative is in `docs/history/03_m7a_progression_economy.md`. The old
M7 management and purchase briefs are background, not prerequisites.
