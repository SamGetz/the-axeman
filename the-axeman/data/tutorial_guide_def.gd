class_name TutorialGuideDef
extends Resource
## One UI-only mentor. Guides are presentation characters, never yard workers,
## villagers or staff, and have no gameplay ownership.

@export var id: StringName
@export var display_name := ""
@export var role := ""
@export_file("*.png", "*.webp") var portrait_path := ""
@export var accent := Color(0.78, 0.56, 0.28, 1.0)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("tutorial guide has an empty id")
	if display_name.strip_edges().is_empty():
		errors.append("tutorial guide %s has no display name" % id)
	if role.strip_edges().is_empty():
		errors.append("tutorial guide %s has no role" % id)
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		errors.append("tutorial guide %s has no loadable portrait" % id)
	return errors
