class_name RegionDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var species_ids: Array[StringName] = []
@export var customer_ids: Array[StringName] = []
@export_range(0, 1000000, 1) var reputation_required := 0
@export_range(0, 1000000, 1) var depot_standing_required := 2
@export_range(1, 1000000000, 1) var depot_cost := 1
@export var map_panel_candidate_path := ""
@export var art_status := "REPLACEABLE CANDIDATE — regional map pending"
@export var tuning_status := "PLACEHOLDER — M9 regional standing/cost review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or species_ids.is_empty():
		errors.append("regional identity, copy or species assignment is incomplete")
	if depot_standing_required < 0 or depot_cost <= 0:
		errors.append("regional depot gate/cost is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("regional tuning must remain explicitly provisional")
	return errors
