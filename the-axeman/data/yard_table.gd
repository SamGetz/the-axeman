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
	return errors
