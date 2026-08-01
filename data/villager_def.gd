class_name VillagerDef
extends Resource
## FILE: res://data/villager_def.gd
## Schema per A8. `morale` here is the authored default; runtime morale is
## mirrored in GameState when M8 lands (per A8 note).

@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var role: StringName
@export var morale: float = 1.0
