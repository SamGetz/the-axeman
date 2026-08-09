class_name ExpeditionReceipt
extends RefCounted

var receipt_id: StringName
var destination_id: StringName
var planned_at: int
var arrives_at: int


func _init(p_receipt_id: StringName, p_destination_id: StringName,
		p_planned_at: int, p_arrives_at: int) -> void:
	receipt_id = p_receipt_id
	destination_id = p_destination_id
	planned_at = maxi(0, p_planned_at)
	arrives_at = maxi(planned_at, p_arrives_at)
