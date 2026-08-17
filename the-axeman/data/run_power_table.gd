class_name RunPowerTable
extends Resource

const MAX_POWER_COUNT := 32

@export var power_curves: RunPowerCurveTable:
	set(value):
		_power_curves = value
		_bind_power_curves()
	get:
		return _power_curves

@export var powers: Array[RunPowerDef] = []:
	set(value):
		_powers = value
		_bind_power_curves()
	get:
		_bind_power_curves()
		return _powers

var _power_curves: RunPowerCurveTable
var _powers: Array[RunPowerDef] = []


func by_id(id: StringName) -> RunPowerDef:
	for power: RunPowerDef in powers:
		if power != null and power.id == id:
			return power
	return null


func from_pool(pool: RunPowerDef.Pool) -> Array[RunPowerDef]:
	var out: Array[RunPowerDef] = []
	for power: RunPowerDef in powers:
		if power != null and power.pool == pool:
			out.append(power)
	return out


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_bind_power_curves()
	if power_curves == null:
		errors.append("run-power table has no central curve resource")
	else:
		errors.append_array(power_curves.validate())
	if powers.is_empty() or powers.size() > MAX_POWER_COUNT:
		errors.append("run-power table must contain between 1 and %d powers" \
			% MAX_POWER_COUNT)
	var ids: Dictionary = {}
	for power: RunPowerDef in powers:
		if power == null:
			errors.append("run-power table contains null")
			continue
		errors.append_array(power.validate())
		if ids.has(power.id):
			errors.append("duplicate run-power id:%s" % power.id)
		ids[power.id] = true
	if power_curves != null:
		for curve: RunPowerCurveDef in power_curves.curves:
			if curve != null and not ids.has(curve.power_id):
				errors.append("run-power curve has no catalogue identity:%s" \
					% curve.power_id)
	return errors


func _bind_power_curves() -> void:
	for power: RunPowerDef in _powers:
		if power == null:
			continue
		var authored: Array[ProgressionEffectDef] = []
		if _power_curves != null:
			authored = _power_curves.effects_for(power.id)
		power.bind_effects(authored)
