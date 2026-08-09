class_name AlienCampaign
extends RefCounted

const TABLE_PATH := "res://data/alien_wood_table.tres"
static var _table: AlienWoodTable


static func table() -> AlienWoodTable:
	if _table == null:
		_table = load(TABLE_PATH) as AlienWoodTable
	return _table


static func traits() -> Array[AlienWoodTraitDef]:
	return [] if table() == null else table().traits


static func trait_by_id(id: StringName) -> AlienWoodTraitDef:
	return null if table() == null else table().by_id(id)


static func trait_for_destination(destination_id: StringName) -> AlienWoodTraitDef:
	return null if table() == null else table().by_destination(destination_id)


static func validate_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	if table() == null:
		errors.append("alien wood table failed to load")
		return errors
	errors.append_array(table().validate())
	for wood_trait: AlienWoodTraitDef in traits():
		if not InventoryManager.is_valid_id(wood_trait.yield_item):
			errors.append("alien yield item is unregistered:%s" % wood_trait.id)
		if LaunchProgram.expedition_by_id(wood_trait.destination_id) == null:
			errors.append("alien wood has no expedition:%s" % wood_trait.id)
	var cfg := AlienCompanySimulation.config()
	if cfg == null:
		errors.append("alien company config failed to load")
	else:
		errors.append_array(cfg.validate())
	return errors


static func quarantine(destination_id: StringName) -> bool:
	return GameState.advance_alien_protocol(destination_id, &"quarantine")


static func identify(destination_id: StringName) -> bool:
	return GameState.advance_alien_protocol(destination_id, &"identify")


static func retrieve_specimen(destination_id: StringName) -> bool:
	return GameState.advance_alien_protocol(destination_id, &"retrieve_specimen")


static func unlock_repeat_cargo(destination_id: StringName) -> bool:
	return GameState.advance_alien_protocol(destination_id, &"repeat_cargo")


static func premium_order_family(destination_id: StringName) -> Dictionary:
	var wood_trait := trait_for_destination(destination_id)
	if wood_trait == null or GameState.get_alien_destination_state(destination_id) \
			< GameState.AlienDestinationState.CERTIFIED:
		return {}
	return {"name": wood_trait.premium_order_name,
		"multiplier": wood_trait.premium_multiplier, "species_id": wood_trait.id}


static func alien_cutting_profile_unlocked(species_id: StringName) -> bool:
	var wood_trait := trait_by_id(species_id)
	return wood_trait != null and GameState.get_alien_destination_state(
		wood_trait.destination_id) >= GameState.AlienDestinationState.CERTIFIED


static func apply_automation_receipt(receipt: AlienAutomationReceipt) -> bool:
	if receipt == null or receipt.total_logs() <= 0 \
			or not GameState.can_apply_alien_automation_receipt(receipt):
		return false
	var lines: Array = []
	for raw_item: Variant in receipt.output_items:
		var item_id := StringName(raw_item)
		var amount := maxi(0, int(receipt.output_items[raw_item]))
		if amount <= 0 or not InventoryManager.add_item(item_id, amount):
			return false
		lines.append({"item_id": item_id, "amount": amount})
	var payout := Market.sell_automation_batch(lines,
		ProductionEconomy.alien_sale_bonus())
	if payout <= 0 or not GameState.apply_alien_automation_receipt(receipt):
		return false
	var base_xp := 0
	for raw_destination: Variant in receipt.processed_logs:
		var logs := maxi(0, int(receipt.processed_logs[raw_destination]))
		var wood_trait := trait_for_destination(StringName(raw_destination))
		if wood_trait != null and logs > 0:
			var units := 1 + int(floor(log(float(logs)) / log(2.0)))
			base_xp += units * wood_trait.xp_reward
	if base_xp > 0:
		GameState.award_xp(maxi(1, int(round(float(base_xp) \
			* ProductionEconomy.automation_xp_rate()))), &"alien_automation")
	return true
