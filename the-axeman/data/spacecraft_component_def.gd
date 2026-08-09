class_name SpacecraftComponentDef
extends Resource

enum Slot { RANGE, CARGO, SHIELDING }

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var slot: Slot = Slot.RANGE
@export_range(0, 10, 1) var capability := 0
@export var tuning_status := "PLACEHOLDER — spacecraft component tuning review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or capability <= 0:
		errors.append("spacecraft component identity or capability is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("spacecraft tuning must remain provisional")
	return errors
