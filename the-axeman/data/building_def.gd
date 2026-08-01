class_name BuildingDef
extends Resource
## FILE: res://data/building_def.gd
## Schema per A8.

@export var id: StringName
@export var recipes: Array[RecipeDef] = []
## Per tier: an Array of cost Dictionaries { "item_id": StringName, "amount": int }.
## Index 0 = cost to reach tier 2, index 1 = cost to reach tier 3, etc.
## Untyped Array per the frozen A8 signature.
@export var upgrade_costs: Array = []
