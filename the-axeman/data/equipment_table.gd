class_name EquipmentTable
extends Resource

@export var equipment: Array[EquipmentDef] = []


func by_id(id: StringName) -> EquipmentDef:
	for definition: EquipmentDef in equipment:
		if definition != null and definition.id == id:
			return definition
	return null


func starting_for_slot(slot: EquipmentDef.Slot) -> EquipmentDef:
	for definition: EquipmentDef in equipment:
		if definition != null and definition.slot == slot and definition.is_starting_fallback:
			return definition
	return null
