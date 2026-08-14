class_name LogDescendantState
extends RefCounted
## Serializable physical state for one stable descendant path within a root.

var id: StringName = &"root"
var parent_id: StringName = &""
var transform := Transform3D.IDENTITY
var linear_velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO
var projection_offset := Vector3.ZERO
var scar_records: Array[Dictionary] = []
var mass := 0.0
var is_firewood := false
var _decoded_types_valid := true


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"parent_id": String(parent_id),
		"transform": transform,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity,
		"projection_offset": projection_offset,
		"scar_records": scar_records.duplicate(true),
		"mass": mass,
		"is_firewood": is_firewood,
	}


static func from_dict(data: Dictionary) -> LogDescendantState:
	var state := LogDescendantState.new()
	var id_value: Variant = data.get("id", "root")
	var parent_value: Variant = data.get("parent_id", "")
	if not (id_value is String or id_value is StringName):
		state._decoded_types_valid = false
		id_value = ""
	if not (parent_value is String or parent_value is StringName):
		state._decoded_types_valid = false
		parent_value = ""
	state.id = StringName(id_value)
	state.parent_id = StringName(parent_value)
	var transform_value: Variant = data.get("transform", Transform3D.IDENTITY)
	if transform_value is Transform3D:
		state.transform = transform_value
	else:
		state._decoded_types_valid = false
	for key: String in ["linear_velocity", "angular_velocity", "projection_offset"]:
		var value: Variant = data.get(key, Vector3.ZERO)
		if value is Vector3:
			state.set(key, value)
		else:
			state._decoded_types_valid = false
	var raw_scars: Variant = data.get("scar_records", [])
	if raw_scars is Array:
		for raw: Variant in raw_scars:
			if raw is Dictionary:
				state.scar_records.append((raw as Dictionary).duplicate(true))
			else:
				state._decoded_types_valid = false
	else:
		state._decoded_types_valid = false
	var mass_value: Variant = data.get("mass", 0.0)
	if mass_value is int or mass_value is float:
		state.mass = float(mass_value)
	else:
		state._decoded_types_valid = false
		state.mass = NAN
	var firewood_value: Variant = data.get("is_firewood", false)
	if firewood_value is bool:
		state.is_firewood = firewood_value
	else:
		state._decoded_types_valid = false
	return state


func is_valid() -> bool:
	return _decoded_types_valid and id != &"" and mass >= 0.0 and is_finite(mass) \
		and _vector_is_finite(transform.origin) \
		and _vector_is_finite(transform.basis.x) \
		and _vector_is_finite(transform.basis.y) \
		and _vector_is_finite(transform.basis.z) \
		and _vector_is_finite(linear_velocity) \
		and _vector_is_finite(angular_velocity) \
		and _vector_is_finite(projection_offset)


func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
