class_name YardProgression
extends RefCounted
## Derives visible yard growth from authoritative purchases. No cosmetic tier is
## stored, so old saves and retuned presentation cannot drift apart.

enum Stage {
	STUMP,
	SHED,
	WORKING_YARD,
	DEPOT,
	HEADQUARTERS,
}

const _TABLE_PATH := "res://data/yard_stage_table.tres"
static var _table: YardStageTable


static func current_stage() -> Stage:
	if GameState.has_infrastructure_project(&"headquarters_yard"):
		return Stage.HEADQUARTERS
	if MechanicalSplitter.is_installed():
		return Stage.DEPOT
	if Shop.get_level(GameState.UPGRADE_HANDCART) > 0:
		return Stage.WORKING_YARD
	if Shop.get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0:
		return Stage.SHED
	return Stage.STUMP


static func definition(stage: Stage = current_stage()) -> YardStageDef:
	if _table == null:
		_table = load(_TABLE_PATH) as YardStageTable
	return null if _table == null else _table.at(stage)


static func validate_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	if _table == null:
		_table = load(_TABLE_PATH) as YardStageTable
	if _table == null or _table.stages.size() < 4:
		errors.append("yard catalogue must contain the four foundational authored stages")
		return errors
	for stage: YardStageDef in _table.stages:
		if stage == null:
			errors.append("yard catalogue contains a null stage")
		elif not stage.validate().is_empty():
			errors.append("yard stage %s is invalid" % stage.id)
	return errors
