class_name CraftRequirementDef
extends Resource
## Immutable catalogue rule for the manual qualities a customer is asking for.
## Runtime settlement reads these facts but never edits the resource.

enum Family {
	QUANTITY,
	SPECIES,
	SIZE_BAND,
	QUALITY,
	SIGNATURE,
}

@export var family: Family = Family.QUANTITY
@export_range(0.0, 1.0, 0.01) var min_normalized_size := 0.0
@export_range(0.0, 1.0, 0.01) var max_normalized_size := 1.0
@export_range(0, 2, 1) var minimum_grade := 0
@export var require_source_identity := false
@export var tuning_status := "PLACEHOLDER — M7B craft requirement review required"


func matches(receipt: ManualPieceReceipt) -> bool:
	if receipt == null or not receipt.is_manual():
		return false
	if receipt.normalized_size < min_normalized_size \
			or receipt.normalized_size > max_normalized_size:
		return false
	if receipt.grade < minimum_grade:
		return false
	return not require_source_identity or receipt.source_log_id != &""


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if min_normalized_size < 0.0 or max_normalized_size > 1.0 \
			or min_normalized_size > max_normalized_size:
		errors.append("craft size band must fit inside [0, 1]")
	if minimum_grade < Craftsmanship.Grade.ROUGH \
			or minimum_grade > Craftsmanship.Grade.EXCEPTIONAL:
		errors.append("craft grade is outside the authored grade catalogue")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("craft requirement tuning must remain explicitly provisional")
	return errors
