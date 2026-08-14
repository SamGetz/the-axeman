class_name Shop
extends RefCounted
## Retired v18 equipment catalogue. It remains readable for migration and for
## selecting the already-authored axe/block meshes, but cannot grant effects,
## procs, eligibility, or purchases in the survivors progression loop.

const _BASE_TABLE_PATH := "res://data/upgrade_table.tres"
const _EQUIPMENT_TABLE_PATH := "res://data/equipment_upgrade_table.tres"

const _BASE_IDS: Array[StringName] = [
	&"balanced_axe", &"reinforced_chopping_block", &"supplier_ledger",
	&"handcart", &"coffee_thermos",
]
const _AXE_IDS: Array[StringName] = [
	&"tempered_woodsmans_axe", &"forged_splitting_maul", &"steel_cheek_axe",
	&"journeymans_bearded_axe", &"hardwood_pattern_axe",
	&"continental_mill_axe", &"earthmaster_axe",
]
const _BLOCK_IDS: Array[StringName] = [
	&"iron_block_dogs", &"log_cradle", &"raised_split_stand",
	&"braced_yard_block", &"millhouse_chopping_block",
	&"continental_split_deck", &"earthmaster_ironwood_block",
]

## PLACEHOLDER re-gates. Each row is [minimum player level, owned species].
## These replace the removed contracts/mastery/company gates and require a
## measured progression review before being labelled final.
const _STAGE_GATES := [
	Vector2i(2, 1), Vector2i(8, 2), Vector2i(16, 4), Vector2i(28, 7),
	Vector2i(42, 11), Vector2i(60, 16), Vector2i(82, 21),
]

static var _base_table: UpgradeTable
static var _equipment_table: UpgradeTable
static var _harvest_def: UpgradeDef


static func get_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for id: StringName in _BASE_IDS:
		var row := _lookup_raw(id)
		if row != null:
			out.append(row)
	out.append(_harvest_capacity_def())
	for id: StringName in _AXE_IDS:
		var row := _lookup_raw(id)
		if row != null:
			out.append(row)
	for id: StringName in _BLOCK_IDS:
		var row := _lookup_raw(id)
		if row != null:
			out.append(row)
	return out


static func get_upgrade(id: StringName) -> UpgradeDef:
	if id == GameState.UPGRADE_HARVEST_CAPACITY:
		return _harvest_capacity_def()
	if id not in _BASE_IDS and id not in _AXE_IDS and id not in _BLOCK_IDS:
		return null
	return _lookup_raw(id)


static func get_level(id: StringName) -> int:
	return GameState.get_permanent_upgrade_level(id)


static func get_next_cost(id: StringName) -> int:
	var row := get_upgrade(id)
	if row == null or row.is_maxed(get_level(id)):
		return 0
	return row.cost_for_level(get_level(id))


static func is_fully_purchased(id: StringName) -> bool:
	var row := get_upgrade(id)
	return row != null and row.is_maxed(get_level(id))


static func get_purchased_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for row: UpgradeDef in get_upgrades():
		if row != null and get_level(row.id) > 0:
			out.append(row)
	return out


static func get_visible_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for row: UpgradeDef in get_upgrades():
		if row != null and (get_level(row.id) > 0 or is_unlocked(row.id)):
			out.append(row)
	return out


static func is_visible(id: StringName) -> bool:
	return get_upgrade(id) != null and (get_level(id) > 0 or is_unlocked(id))


static func is_entry_revealed() -> bool:
	return true


static func opening_unlock_cost() -> int:
	var first := get_upgrade(GameState.UPGRADE_BALANCED_AXE)
	return 0 if first == null else first.base_cost


static func is_unlocked(id: StringName) -> bool:
	if get_level(id) > 0:
		return true
	if id in [GameState.UPGRADE_BALANCED_AXE, GameState.UPGRADE_REINFORCED_BLOCK]:
		return true
	if id == GameState.UPGRADE_SUPPLIER_LEDGER:
		return get_level(GameState.UPGRADE_BALANCED_AXE) > 0
	if id == GameState.UPGRADE_HANDCART:
		return get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0
	if id == GameState.UPGRADE_COFFEE_THERMOS:
		return get_level(GameState.UPGRADE_HANDCART) > 0
	if id == GameState.UPGRADE_HARVEST_CAPACITY:
		return get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0
	var axe_index := _AXE_IDS.find(id)
	if axe_index >= 0:
		return _equipment_stage_unlocked(_AXE_IDS, axe_index,
			GameState.UPGRADE_BALANCED_AXE)
	var block_index := _BLOCK_IDS.find(id)
	if block_index >= 0:
		return _equipment_stage_unlocked(_BLOCK_IDS, block_index,
			GameState.UPGRADE_REINFORCED_BLOCK)
	return false


static func can_buy(id: StringName) -> bool:
	return false


## Currency must already have been spent by RunDirector.
static func commit_purchase_after_payment(id: StringName) -> int:
	return -1


static func total_effect(kind: UpgradeDef.Effect) -> float:
	return 0.0


static func active_equipment(slot: UpgradeDef.EquipmentSlot) -> UpgradeDef:
	var active: UpgradeDef
	for row: UpgradeDef in get_upgrades():
		if row == null or row.equipment_slot != slot or get_level(row.id) <= 0:
			continue
		if active == null or row.equipment_stage > active.equipment_stage:
			active = row
	return active


static func equipment_proc_chance(proc_id: StringName) -> float:
	return 0.0


static func equipment_proc_chain_cap(proc_id: StringName) -> int:
	return 0


static func _equipment_stage_unlocked(chain: Array[StringName], index: int,
		fallback_id: StringName) -> bool:
	var previous := fallback_id if index == 0 else chain[index - 1]
	if get_level(previous) <= 0:
		return false
	var gate: Vector2i = _STAGE_GATES[index]
	return GameState.get_level() >= gate.x \
		and GameState.get_owned_species().size() >= gate.y


static func _proc_chance_from(row: UpgradeDef, proc_id: StringName) -> float:
	for contribution: UpgradeProcContributionDef in row.proc_contributions:
		if contribution != null and contribution.proc_id == proc_id:
			return contribution.chance_per_level
	return 0.0


static func _lookup_raw(id: StringName) -> UpgradeDef:
	var base := _base_catalogue()
	var row := null if base == null else base.get_upgrade(id)
	if row != null:
		return row
	var equipment := _equipment_catalogue()
	return null if equipment == null else equipment.get_upgrade(id)


static func _base_catalogue() -> UpgradeTable:
	if _base_table == null:
		_base_table = load(_BASE_TABLE_PATH) as UpgradeTable
	return _base_table


static func _equipment_catalogue() -> UpgradeTable:
	if _equipment_table == null:
		_equipment_table = load(_EQUIPMENT_TABLE_PATH) as UpgradeTable
	return _equipment_table


static func _harvest_capacity_def() -> UpgradeDef:
	if _harvest_def == null:
		var tuning := load("res://data/survival_run_tuning_placeholder.tres") as SurvivalRunTuning
		_harvest_def = UpgradeDef.new()
		_harvest_def.id = GameState.UPGRADE_HARVEST_CAPACITY
		_harvest_def.display_name = "Harvest Capacity"
		_harvest_def.description = "Each arena log clears a larger authored batch of Earth's remaining trees."
		_harvest_def.limitation = "Does not slow deliveries or make an individual log easier to split."
		_harvest_def.purchase_form = UpgradeDef.PurchaseForm.TIERED
		_harvest_def.base_cost = int(tuning.harvest_capacity_costs[0])
		_harvest_def.cost_growth = 10.0
		_harvest_def.max_level = tuning.harvest_capacity_costs.size()
		_harvest_def.tuning_status = "PLACEHOLDER — costs and represented tree batches require measured pacing review"
	return _harvest_def
