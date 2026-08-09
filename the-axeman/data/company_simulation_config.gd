class_name CompanySimulationConfig
extends Resource

@export_range(1, 1000, 1) var supplier_queue_capacity := 24
@export_range(0.1, 3600.0, 0.1) var seconds_per_log := 5.0
@export_range(1, 100, 1) var output_pieces_per_log := 1
@export_range(1, 86400, 1) var offline_cap_seconds := 14400
@export_range(1, 20, 1) var dispatch_capacity := 1
@export_range(1, 100, 1) var return_ledger_limit := 12
@export var tuning_status := "PLACEHOLDER — M8 logistics/offline measured tuning required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if supplier_queue_capacity <= 0 or seconds_per_log <= 0.0 \
			or output_pieces_per_log <= 0 or offline_cap_seconds <= 0 \
			or dispatch_capacity <= 0 or return_ledger_limit <= 0:
		errors.append("company simulation bounds must be positive")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("company simulation tuning must remain explicitly provisional")
	return errors
