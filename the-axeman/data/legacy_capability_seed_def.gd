class_name LegacyCapabilitySeedDef
extends Resource
## Safe one-way v19 migration mapping. It never grants currency and can only
## seed the explicitly named new capability line.

@export var legacy_source_id: StringName = &""
@export_range(1, 99, 1) var minimum_legacy_rank := 1
@export var target_meta_upgrade_id: StringName = &""
@export_range(1, 99, 1) var fixed_target_rank := 1
@export var copy_legacy_rank := false
@export_multiline var tuning_status := \
	"PLACEHOLDER — legacy capability migration mapping requires approval"


func target_rank_for(source_rank: int) -> int:
	if source_rank < minimum_legacy_rank:
		return 0
	return source_rank if copy_legacy_rank else fixed_target_rank


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if legacy_source_id == &"" or target_meta_upgrade_id == &"" \
			or minimum_legacy_rank <= 0 or fixed_target_rank <= 0:
		errors.append("legacy capability seed identity or ranks are invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("legacy capability seed must remain explicitly provisional")
	return errors
