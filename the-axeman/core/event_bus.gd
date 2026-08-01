extends Node
## FILE: res://core/event_bus.gd
## ATTACHES TO: nothing directly. Register as Autoload "EventBus" (order 1, before
## InventoryManager and GameState — they connect to these signals in _ready()).
## Contract A7: signals only, ZERO state. Do not add vars or funcs here.
##
## All resource_id values MUST exist in res://data/item_registry.tres.
## Emitting an unregistered id is a contract violation; InventoryManager
## pushes an error and ignores it.

@warning_ignore("unused_signal")
signal resource_gathered(resource_id: StringName, amount: int)

@warning_ignore("unused_signal")
signal building_upgraded(building_id: StringName, new_tier: int)

@warning_ignore("unused_signal")
signal environment_unlocked(biome_id: Enums.Biome)

@warning_ignore("unused_signal")
signal action_hit_registered(hit_position: Vector3, tool_tier: int, direction: Enums.ChopDirection)

@warning_ignore("unused_signal")
signal gear_upgraded(tool_type: Enums.ToolType, new_tier: int)

@warning_ignore("unused_signal")
signal minigame_entered(biome_id: Enums.Biome)

@warning_ignore("unused_signal")
signal minigame_exited()
