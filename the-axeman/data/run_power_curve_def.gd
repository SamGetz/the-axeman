class_name RunPowerCurveDef
extends Resource
## The complete authored effect ladder for one temporary run-power identity.

@export var power_id: StringName = &""
@export var effects: Array[ProgressionEffectDef] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if power_id == &"":
		errors.append("run-power curve has no identity")
	if effects.is_empty():
		errors.append("run-power curve %s has no typed effects" % power_id)
	var kinds: Dictionary = {}
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			errors.append("run-power curve %s contains a null effect" % power_id)
			continue
		if kinds.has(effect.kind):
			errors.append("run-power curve %s contains duplicate effect kind:%d" % [
				power_id, effect.kind])
		kinds[effect.kind] = true
	return errors
