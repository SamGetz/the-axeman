class_name MetaUpgradeTable
extends Resource

@export var upgrades: Array[MetaUpgradeDef] = []


func by_id(id: StringName) -> MetaUpgradeDef:
	for upgrade: MetaUpgradeDef in upgrades:
		if upgrade != null and upgrade.id == id:
			return upgrade
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	for upgrade: MetaUpgradeDef in upgrades:
		if upgrade == null:
			errors.append("meta upgrade table contains null")
			continue
		errors.append_array(upgrade.validate())
		if ids.has(upgrade.id):
			errors.append("duplicate meta upgrade id:%s" % upgrade.id)
		ids[upgrade.id] = true
	for upgrade: MetaUpgradeDef in upgrades:
		if upgrade == null or upgrade.prerequisite_upgrade_id == &"":
			continue
		var required := by_id(upgrade.prerequisite_upgrade_id)
		if required == null:
			errors.append("meta upgrade %s has an unknown prerequisite:%s" % [
				upgrade.id, upgrade.prerequisite_upgrade_id])
		elif upgrade.prerequisite_rank > required.max_rank:
			errors.append("meta upgrade %s requires an impossible prerequisite rank" % upgrade.id)
		elif upgrade.prerequisite_upgrade_id == upgrade.id:
			errors.append("meta upgrade %s requires itself" % upgrade.id)
	var visit_state: Dictionary = {}
	for upgrade: MetaUpgradeDef in upgrades:
		if upgrade != null:
			_visit_prerequisite(upgrade.id, visit_state, [], errors)
	return errors


func _visit_prerequisite(id: StringName, visit_state: Dictionary,
		path: Array[StringName], errors: PackedStringArray) -> void:
	var state := int(visit_state.get(id, 0))
	if state == 2:
		return
	if state == 1:
		errors.append("meta upgrade prerequisite cycle:%s" % " -> ".join(path))
		return
	visit_state[id] = 1
	var definition := by_id(id)
	if definition != null and definition.prerequisite_upgrade_id != &"" \
			and by_id(definition.prerequisite_upgrade_id) != null:
		var next_path := path.duplicate()
		next_path.append(id)
		_visit_prerequisite(definition.prerequisite_upgrade_id,
			visit_state, next_path, errors)
	visit_state[id] = 2
