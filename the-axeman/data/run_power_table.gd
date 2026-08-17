class_name RunPowerTable
extends Resource

const MAX_POWER_COUNT := 32

@export var powers: Array[RunPowerDef] = []


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
	return errors
