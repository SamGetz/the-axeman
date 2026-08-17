class_name YardBossDef
extends Resource
## One scheduled five-root stump-stack encounter. The jackpot is divided exactly
## across the five ordinary-hardness roots; clearing the complete stack owns the
## single Blueprint roll.

@export var id: StringName = &""
@export var display_name := ""
@export var species_id: StringName = &""
@export_range(1.0, 86400.0, 1.0) var scheduled_seconds := 1.0
@export_range(1, 99, 1) var boss_tier := 1
@export_range(1, 1000000000, 1) var cash_jackpot := 1
@export_range(1, 1000000000, 1) var xp_jackpot := 1
@export_range(1, 1, 1) var pending_blueprints := 1
@export_multiline var tuning_status := \
	"PLACEHOLDER — boss schedule and rewards require measured approval"


func validate(stage_duration_seconds: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty():
		errors.append("yard boss identity or copy is incomplete")
	if species_id == &"" or SpeciesTable.by_id(species_id) == null:
		errors.append("yard boss references an unknown species:%s" % species_id)
	if scheduled_seconds <= 0.0 or scheduled_seconds >= stage_duration_seconds:
		errors.append("yard boss schedule must fall inside the stage")
	if boss_tier <= 0:
		errors.append("yard boss tier is invalid")
	if cash_jackpot <= 0 or xp_jackpot <= 0 or pending_blueprints != 1:
		errors.append("yard boss reward bundle is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("yard boss tuning must remain explicitly provisional")
	return errors
