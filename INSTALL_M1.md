# M1 — Core Contracts: Install Steps

Target project: `C:\Users\Sam\Documents\the_axeman\the-axeman`

## 1. Copy files
Copy the `core/` and `data/` folders from this zip into the project root, so you get:

```
res://core/enums.gd
res://core/event_bus.gd
res://core/inventory_manager.gd
res://core/game_state.gd
res://core/tests/m1_acceptance.gd
res://core/tests/m1_acceptance.tscn
res://data/item_def.gd
res://data/item_registry.gd
res://data/fragment_def.gd
res://data/tree_def.gd
res://data/ore_vein_def.gd
res://data/recipe_def.gd
res://data/building_def.gd
res://data/villager_def.gd
res://data/game_feel_config.gd
res://data/item_registry.tres
res://data/game_config.tres
```

## 2. Register autoloads (Project → Project Settings → Globals → Autoload)
Add in EXACTLY this order (A5). `enums.gd` is NOT an autoload — it is
class_name only.

| Order | Node Name          | Path                                |
|-------|--------------------|-------------------------------------|
| 1     | EventBus           | res://core/event_bus.gd             |
| 2     | InventoryManager   | res://core/inventory_manager.gd     |
| 3     | GameState          | res://core/game_state.gd            |

Equivalent `project.godot` block if you prefer editing it directly:

```ini
[autoload]

EventBus="*res://core/event_bus.gd"
InventoryManager="*res://core/inventory_manager.gd"
GameState="*res://core/game_state.gd"
```

## 3. Run the acceptance test
Open `res://core/tests/m1_acceptance.tscn` and press **Run Current Scene** (F6).

Expected in the Output panel:
- Every line starts with `PASS:` and the run ends with
  `=== ALL M1 ACCEPTANCE CRITERIA PASS ===`
- **A handful of red errors/yellow warnings from InventoryManager and GameState
  are EXPECTED** — tests 2, 5, 7, 8 deliberately violate the contract
  (unregistered ids, downgrades, duplicate unlocks) to prove it rejects them.
  Only lines beginning with `FAIL:` indicate a problem.

## 4. Notes
- Godot will assign `uid://` ids to the two `.tres` files on first import and
  may re-save them with uid attributes — that is normal, let it.
- All GameFeelConfig values are placeholders (Directive 4); we tune them in
  the .tres during M3/M4.
