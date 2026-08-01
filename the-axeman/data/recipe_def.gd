class_name RecipeDef
extends Resource
## FILE: res://data/recipe_def.gd
## Schema per A8. inputs/outputs entries are Dictionaries:
##   { "item_id": StringName, "amount": int }
## All ids must exist in item_registry.tres. Consumption is atomic via
## InventoryManager.remove_items() — never partial (M7).

@export var inputs: Array = []
@export var outputs: Array = []
@export var base_seconds: float = 1.0
