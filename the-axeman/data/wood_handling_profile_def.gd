class_name WoodHandlingProfileDef
extends Resource
## Shared terrestrial handling grammar. Species identity and base resistance stay
## in SpeciesDef; a profile changes how a player reads and improves the cut.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var lesson := ""
@export var species_ids: Array[StringName] = []
@export_range(-0.25, 0.25, 0.005) var fresh_split_modifier := 0.0
@export_range(0.25, 2.0, 0.05) var scar_bonus_multiplier := 1.0
@export_range(0.25, 2.0, 0.05) var size_relief_multiplier := 1.0
@export var tuning_status := "PLACEHOLDER — five-family handling playtest required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or lesson.strip_edges().is_empty() or species_ids.is_empty():
		errors.append("handling profile identity or membership is incomplete")
	if scar_bonus_multiplier <= 0.0 or size_relief_multiplier <= 0.0:
		errors.append("handling profile multipliers must be positive")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("handling profile tuning must remain labelled provisional")
	return errors
