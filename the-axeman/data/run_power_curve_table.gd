class_name RunPowerCurveTable
extends Resource
## Central balance sheet for temporary run powers. Identity/copy stays in the
## separate catalogue so balancing never touches offer or presentation data.

@export var curves: Array[RunPowerCurveDef] = []


func effects_for(power_id: StringName) -> Array[ProgressionEffectDef]:
	for curve: RunPowerCurveDef in curves:
		if curve != null and curve.power_id == power_id:
			return curve.effects
	return []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if curves.is_empty():
		errors.append("run-power curve table is empty")
	var ids: Dictionary = {}
	for curve: RunPowerCurveDef in curves:
		if curve == null:
			errors.append("run-power curve table contains null")
			continue
		errors.append_array(curve.validate())
		if ids.has(curve.power_id):
			errors.append("duplicate run-power curve id:%s" % curve.power_id)
		ids[curve.power_id] = true
	return errors
