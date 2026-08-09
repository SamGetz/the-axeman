class_name YardStageDef
extends Resource
## Authored visible yard state. Eligibility is derived; this resource stores no
## mutable tier or purchase history.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var recognition_copy := ""
@export var accent := Color.WHITE
@export var tuning_status := "PLACEHOLDER — M7D yard-readability review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or recognition_copy.strip_edges().is_empty():
		errors.append("yard stage identity/copy is incomplete")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("yard stage tuning must remain explicitly provisional")
	return errors
