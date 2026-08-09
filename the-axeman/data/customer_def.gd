class_name CustomerDef
extends Resource
## Authored customer identity. Reputation gates are monotonic and never spent.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var preference_copy := ""
@export_range(0, 1000000, 1) var reputation_required := 0
@export var family: CraftRequirementDef.Family = CraftRequirementDef.Family.QUANTITY
@export var portrait_candidate_path := ""
@export var art_status := "REPLACEABLE CANDIDATE — portrait pending"
@export var tuning_status := "PLACEHOLDER — M7B customer reputation review required"


func is_unlocked(reputation: int) -> bool:
	return reputation >= reputation_required


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or preference_copy.strip_edges().is_empty():
		errors.append("customer identity/copy is incomplete")
	if reputation_required < 0:
		errors.append("customer reputation gate cannot be negative")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("customer tuning must remain explicitly provisional")
	return errors
