class_name RouteDef
extends Resource

enum Tier { ROAD, RAIL, PORT }

@export var id: StringName = &""
@export var region_id: StringName = &""
@export var display_name := ""
@export var tier: Tier = Tier.ROAD
@export_range(1, 1000000000, 1) var cost := 1
@export_range(1, 86400, 1) var travel_seconds := 60
@export_range(1, 1000, 1) var capacity := 4
@export var tuning_status := "PLACEHOLDER — M9 route timing/capacity review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or region_id == &"" or display_name.strip_edges().is_empty() \
			or cost <= 0 or travel_seconds <= 0 or capacity <= 0:
		errors.append("route identity, cost, timing or capacity is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("route tuning must remain explicitly provisional")
	return errors
