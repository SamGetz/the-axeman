class_name CompanySimulationReceipt
extends RefCounted
## Unapplied deterministic result. Owning systems validate and apply it once.

var receipt_id: StringName
var elapsed_seconds: int
var processed_by_species: Dictionary
var outputs: Dictionary
var remaining_queues: Dictionary
var next_timestamp: int
var offline: bool


func _init(p_id: StringName, p_elapsed: int, p_processed: Dictionary,
		p_outputs: Dictionary, p_remaining: Dictionary, p_timestamp: int,
		p_offline: bool) -> void:
	receipt_id = p_id
	elapsed_seconds = maxi(0, p_elapsed)
	processed_by_species = p_processed.duplicate(true)
	outputs = p_outputs.duplicate(true)
	remaining_queues = p_remaining.duplicate(true)
	next_timestamp = maxi(0, p_timestamp)
	offline = p_offline


func processed_logs() -> int:
	var total := 0
	for value: Variant in processed_by_species.values():
		total += maxi(0, int(value))
	return total
