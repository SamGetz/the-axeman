class_name ManualPieceReceipt
extends RefCounted
## Immutable facts for one successfully landed manual firewood piece. Services
## may read this receipt; only InventoryManager/GameState apply its outcomes.

enum Origin {
	MANUAL,
	AUTOMATION,
}

var item_id: StringName
var species_id: StringName
var normalized_size: float
var grade: int
var source_log_id: StringName
var origin: Origin


func _init(p_item_id: StringName, p_species_id: StringName = &"",
		p_normalized_size := 1.0, p_grade := 0,
		p_source_log_id: StringName = &"", p_origin: Origin = Origin.MANUAL) -> void:
	item_id = p_item_id
	species_id = p_species_id
	normalized_size = clampf(p_normalized_size, 0.0, 1.0)
	grade = maxi(0, p_grade)
	source_log_id = p_source_log_id
	origin = p_origin


func is_manual() -> bool:
	return origin == Origin.MANUAL
