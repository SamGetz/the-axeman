class_name ItemDef
extends Resource
## FILE: res://data/item_def.gd
## Schema per A8. Instances live inside res://data/item_registry.tres.

@export var id: StringName
@export var display_name: String
@export var category: Enums.ItemCategory
@export var icon: Texture2D
