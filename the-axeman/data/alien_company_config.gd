class_name AlienCompanyConfig
extends Resource

@export_range(1, 10, 1) var fleet_cap_per_destination := 3
@export_range(1, 3600, 1) var seconds_per_cargo := 30
@export_range(1, 1000, 1) var cargo_logs_per_fleet := 2
@export_range(1, 1000, 1) var orbital_logs_per_line := 3
@export_range(1, 100000, 1) var receipt_log_cap := 120
@export var tuning_status := "PLACEHOLDER — interplanetary throughput review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if fleet_cap_per_destination <= 0 or seconds_per_cargo <= 0 \
			or cargo_logs_per_fleet <= 0 or orbital_logs_per_line <= 0 \
			or receipt_log_cap <= 0:
		errors.append("alien company bounds are invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("alien company tuning must remain provisional")
	return errors
