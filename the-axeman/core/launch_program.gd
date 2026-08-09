class_name LaunchProgram
extends RefCounted

const TABLE_PATH := "res://data/launch_program_table.tres"
const EXPEDITION_TABLE_PATH := "res://data/expedition_table.tres"
static var _table: LaunchProgramTable
static var _expeditions: ExpeditionTable


static func table() -> LaunchProgramTable:
	if _table == null:
		_table = load(TABLE_PATH) as LaunchProgramTable
	return _table


static func expedition_table() -> ExpeditionTable:
	if _expeditions == null:
		_expeditions = load(EXPEDITION_TABLE_PATH) as ExpeditionTable
	return _expeditions


static func projects() -> Array[LaunchProjectDef]:
	return [] if table() == null else table().projects


static func components() -> Array[SpacecraftComponentDef]:
	return [] if table() == null else table().components


static func project_by_id(id: StringName) -> LaunchProjectDef:
	return null if table() == null else table().project_by_id(id)


static func component_by_id(id: StringName) -> SpacecraftComponentDef:
	return null if table() == null else table().component_by_id(id)


static func expedition_by_id(id: StringName) -> ExpeditionDef:
	return null if expedition_table() == null else expedition_table().by_id(id)


static func contribute(project_id: StringName, amount: int) -> bool:
	var project := project_by_id(project_id)
	if project == null or amount <= 0 \
			or not GameState.can_record_launch_contribution(project_id, amount):
		return false
	var costs := [{"item_id": project.contribution_item_id, "amount": amount}]
	if not InventoryManager.can_afford(costs) or not InventoryManager.remove_items(costs):
		return false
	return GameState.record_launch_contribution(project_id, amount)


static func validate_catalogues() -> PackedStringArray:
	var errors := PackedStringArray()
	if table() == null:
		errors.append("launch programme table failed to load")
	else:
		errors.append_array(table().validate())
	if expedition_table() == null:
		errors.append("expedition table failed to load")
	else:
		errors.append_array(expedition_table().validate())
	for project: LaunchProjectDef in projects():
		if project.contribution_item_id != &"" \
				and not InventoryManager.is_valid_id(project.contribution_item_id):
			errors.append("launch contribution item is unregistered:%s" % project.id)
	return errors
