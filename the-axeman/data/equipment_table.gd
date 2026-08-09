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


func active_for_slot(slot: EquipmentDef.Slot) -> EquipmentDef:
	var active := starting_for_slot(slot)
	for definition: EquipmentDef in equipment:
		if definition == null or definition.slot != slot \
				or definition.ownership_upgrade_id == &"" \
				or Shop.get_level(definition.ownership_upgrade_id) <= 0:
			continue
		if active == null or active.is_starting_fallback \
				or definition.progression_stage > active.progression_stage:
			active = definition
	return active
