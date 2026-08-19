class_name RunPowerCurveDef
extends Resource
## The complete authored effect ladder for one temporary run-power identity.

@export var power_id: StringName = &""
@export var effects: Array[ProgressionEffectDef] = []


## A run power's ladder length is balance data. The longest authored effect
## defines the number of ranks; shorter companion effects hold their final
## value through the remaining ranks via ProgressionEffectDef.value_at_rank().
func rank_cap() -> int:
	var cap := 0
	for effect: ProgressionEffectDef in effects:
		if effect != null:
			cap = maxi(cap, effect.cumulative_values_by_rank.size())
	return cap


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
		errors.append_array(effect.validate())
	if rank_cap() <= 0:
		errors.append("run-power curve %s has no authored ranks" % power_id)
	return errors
