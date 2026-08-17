class_name ItemRegistry
extends Resource
## FILE: res://data/item_registry.gd
## Single source of truth for valid item ids.
## Exactly ONE instance: res://data/item_registry.tres (loaded by InventoryManager).

@export var items: Array[ItemDef] = []
