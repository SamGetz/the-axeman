class_name CompanyStrategy
extends RefCounted

const _DOCTRINE_PATH := "res://data/company_doctrine_table.tres"
const _MACHINE_PATH := "res://data/hydraulic_split_bank.tres"
static var _doctrines: CompanyDoctrineTable
static var _machine: CompanyMachineDef


static func doctrines() -> Array[CompanyDoctrineDef]:
	if _doctrines == null:
		_doctrines = load(_DOCTRINE_PATH) as CompanyDoctrineTable
	return [] if _doctrines == null else _doctrines.doctrines.duplicate()


static func doctrine_by_id(id: StringName) -> CompanyDoctrineDef:
	if _doctrines == null:
		doctrines()
	return null if _doctrines == null else _doctrines.by_id(id)


static func machine() -> CompanyMachineDef:
	if _machine == null:
		_machine = load(_MACHINE_PATH) as CompanyMachineDef
	return _machine


static func effect(kind: CompanyDoctrineDef.Effect) -> float:
	var doctrine := doctrine_by_id(GameState.get_company_doctrine())
	return doctrine.magnitude if doctrine != null and doctrine.effect == kind else 0.0


static func effective_dispatch_capacity() -> int:
	var cfg := CompanySimulation.config()
	var capacity := 1 if cfg == null else cfg.dispatch_capacity
	capacity += int(round(effect(CompanyDoctrineDef.Effect.DISPATCH_CAPACITY)))
	var machine_def := machine()
	if machine_def != null and Shop.get_level(machine_def.id) > 0:
		capacity += machine_def.added_dispatch_capacity
	capacity += ProductionEconomy.dispatch_capacity_bonus()
	return maxi(1, capacity)


static func buy_machine() -> bool:
	var definition := machine()
	if definition == null or Shop.get_level(definition.id) > 0 \
			or not MechanicalSplitter.is_installed() \
			or not GameState.try_spend_cash(definition.cost):
		return false
	EventBus.building_upgraded.emit(definition.id, GameState.DEFAULT_BUILDING_TIER + 1)
	return true


static func validate_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	var effects: Dictionary = {}
	for doctrine: CompanyDoctrineDef in doctrines():
		if doctrine == null or not doctrine.validate().is_empty() or effects.has(doctrine.effect):
			errors.append("invalid/duplicate company doctrine")
		else:
			effects[doctrine.effect] = true
	if effects.size() != 3 or machine() == null or not machine().validate().is_empty():
		errors.append("company strategy catalogue is incomplete")
	return errors
