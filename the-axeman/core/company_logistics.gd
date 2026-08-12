class_name CompanyLogistics
extends RefCounted
## Purchase and settlement facade. GameState/InventoryManager remain the only
## state writers; simulation itself stays pure.

const _TABLE_PATH := "res://data/logistics_upgrade_table.tres"
static var _table: LogisticsUpgradeTable


static func upgrades() -> Array[LogisticsUpgradeDef]:
	var table := _catalogue()
	return [] if table == null else table.upgrades.duplicate()


static func by_id(id: StringName) -> LogisticsUpgradeDef:
	var table := _catalogue()
	return null if table == null else table.by_id(id)


static func is_owned(id: StringName) -> bool:
	return Shop.get_level(id) > 0


static func is_available(id: StringName) -> bool:
	var upgrade := by_id(id)
	if upgrade == null or is_owned(id) or not MechanicalSplitter.is_installed():
		return false
	return upgrade.required_previous_id == &"" or is_owned(upgrade.required_previous_id)


static func buy(id: StringName) -> bool:
	var upgrade := by_id(id)
	if upgrade == null or not is_available(id) \
			or not GameState.try_spend_cash(upgrade.cost):
		return false
	EventBus.building_upgraded.emit(id, GameState.DEFAULT_BUILDING_TIER + 1)
	return true


static func all_owned() -> bool:
	for upgrade: LogisticsUpgradeDef in upgrades():
		if not is_owned(upgrade.id):
			return false
	return not upgrades().is_empty()


static func supplier_queue_capacity() -> int:
	var cfg := CompanySimulation.config()
	if cfg == null:
		return 0
	return maxi(0, cfg.supplier_queue_capacity + int(round(Shop.total_effect(
		UpgradeDef.Effect.SUPPLIER_QUEUE_CAPACITY))))


static func validate_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	var previous: StringName = &""
	var ids: Dictionary = {}
	for upgrade: LogisticsUpgradeDef in upgrades():
		if upgrade == null or not upgrade.validate().is_empty():
			errors.append("invalid logistics upgrade")
			continue
		if ids.has(upgrade.id):
			errors.append("duplicate logistics upgrade:%s" % upgrade.id)
		if upgrade.required_previous_id != previous:
			errors.append("logistics upgrade %s breaks the direct-purchase sequence" % upgrade.id)
		ids[upgrade.id] = true
		previous = upgrade.id
	return errors


static func apply_receipt(receipt: CompanySimulationReceipt) -> bool:
	if receipt == null or receipt.receipt_id == &"" or receipt.processed_logs() <= 0:
		return false
	if not GameState.can_apply_company_simulation_receipt(receipt):
		return false
	var lines: Array = []
	for raw_item: Variant in receipt.outputs:
		var item_id := StringName(raw_item)
		var amount := int(receipt.outputs[raw_item])
		if amount <= 0 or not Market.is_sellable(item_id):
			return false
		lines.append({"item_id": item_id, "amount": amount})
	for line: Dictionary in lines:
		if not InventoryManager.add_item(StringName(line.item_id), int(line.amount)):
			return false
	var payout := Market.sell_automation_batch(lines,
		ProductionEconomy.automation_sale_bonus())
	if payout <= 0:
		return false
	if not GameState.apply_company_simulation_receipt(receipt, payout):
		return false
	var xp := _receipt_xp(receipt)
	if xp > 0:
		GameState.award_xp(xp, GameState.XP_ORIGIN_COMPANY_AUTOMATION)
	for line: Dictionary in lines:
		GameState.record_automation_bulk_delivery(StringName(line.item_id),
			int(line.amount), receipt.receipt_id)
	return true


static func _receipt_xp(receipt: CompanySimulationReceipt) -> int:
	var base_xp := 0
	for raw_species: Variant in receipt.processed_by_species:
		var trees := maxi(0, int(receipt.processed_by_species[raw_species]))
		var species := SpeciesTable.by_id(StringName(raw_species))
		if species == null or trees <= 0:
			continue
		var units := 1 + int(floor(log(float(trees)) / log(2.0)))
		base_xp += units * species.xp_reward
	return maxi(0, int(round(float(base_xp) \
		* ProductionEconomy.automation_xp_rate())))


static func can_run_offline() -> bool:
	return is_owned(&"dispatch_console") \
		and not GameState.is_earth_depleted() \
		and GameState.get_automated_log_equivalents() > 0


static func _catalogue() -> LogisticsUpgradeTable:
	if _table == null:
		_table = load(_TABLE_PATH) as LogisticsUpgradeTable
	return _table
