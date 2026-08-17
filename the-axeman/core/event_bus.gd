extends Node
## FILE: res://core/event_bus.gd
## Minimal cross-owner signal bridge. InventoryManager consumes gathered wood;
## GameFeel consumes successful split impacts.
##
## All resource_id values MUST exist in res://data/item_registry.tres.
## Emitting an unregistered id is a contract violation; InventoryManager
## pushes an error and ignores it.

@warning_ignore("unused_signal")
signal resource_gathered(resource_id: StringName, amount: int)

@warning_ignore("unused_signal")
signal action_hit_registered(hit_position: Vector3)
