class_name AlienAutomationReceipt
extends RefCounted

var receipt_id: StringName
var processed_logs: Dictionary
var output_items: Dictionary
var elapsed_seconds: int


func _init(p_receipt_id: StringName, p_processed_logs: Dictionary,
		p_output_items: Dictionary, p_elapsed_seconds: int) -> void:
	receipt_id = p_receipt_id
	processed_logs = p_processed_logs.duplicate(true)
	output_items = p_output_items.duplicate(true)
	elapsed_seconds = maxi(0, p_elapsed_seconds)


func total_logs() -> int:
	var total := 0
	for amount: Variant in processed_logs.values():
		var logs := maxi(0, int(amount))
		if total > GameState.MAX_SAFE_ECONOMY_VALUE - logs:
			return -1
		total += logs
	return total
