class_name YardTable
extends Resource

@export var yards: Array[YardDef] = []


func by_id(id: StringName) -> YardDef:
	for yard: YardDef in yards:
		if yard != null and yard.id == id:
			return yard
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	for yard: YardDef in yards:
		if yard == null:
			errors.append("yard table contains null")
			continue
		errors.append_array(yard.validate())
		if ids.has(yard.id):
			errors.append("duplicate yard id:%s" % yard.id)
		ids[yard.id] = true
	for yard: YardDef in yards:
		if yard == null or yard.prerequisite_yard_id == &"":
			continue
		if by_id(yard.prerequisite_yard_id) == null:
			errors.append("yard %s has an unknown prerequisite:%s" % [
				yard.id, yard.prerequisite_yard_id])
		elif yard.prerequisite_yard_id == yard.id:
			errors.append("yard %s requires itself" % yard.id)
	var visit_state: Dictionary = {}
	for yard: YardDef in yards:
		if yard != null:
			_visit_prerequisite(yard.id, visit_state, [], errors)
	return errors


func _visit_prerequisite(id: StringName, visit_state: Dictionary,
		path: Array[StringName], errors: PackedStringArray) -> void:
	var state := int(visit_state.get(id, 0))
	if state == 2:
		return
	if state == 1:
		errors.append("yard prerequisite cycle:%s" % " -> ".join(path))
		return
	visit_state[id] = 1
	var definition := by_id(id)
	if definition != null and definition.prerequisite_yard_id != &"" \
			and by_id(definition.prerequisite_yard_id) != null:
		var next_path := path.duplicate()
		next_path.append(id)
		_visit_prerequisite(definition.prerequisite_yard_id,
			visit_state, next_path, errors)
	visit_state[id] = 2
