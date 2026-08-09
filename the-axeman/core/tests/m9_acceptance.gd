extends Node
## Focused acceptance for M9 Slice 1 Working Yard Commissions. This suite is
## prepared with the implementation but must not be run until Sam approves the
## experimental code/presentation checkpoint.

const _BACKUP_PATH := "user://the_axeman_save.m9_testbackup"

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M9 SLICE 1 ACCEPTANCE — Working Yard Commissions ===")
	_stash_real_save()
	_test_hidden_gate_and_catalogue()
	_test_stable_owned_offer_generation()
	_test_relevant_roles_and_rotation()
	_test_single_long_term_selection()
	_test_manual_settlement_and_exact_completion()
	_test_automation_exclusion()
	_test_save_v17_and_restore()
	await _test_native_hud_flow()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M9 SLICE 1 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M9 SLICE 1 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_hidden_gate_and_catalogue() -> void:
	GameState.reset_to_defaults()
	_check(not Orders.commissions_unlocked(),
		"commissions remain locked before Pine Campsite Load completion")
	_check(not GameState.ensure_commission_offers()
		and GameState.get_commission_offers().is_empty(),
		"locked commission content cannot be generated or leaked")
	_check(Orders.validate_live_commissions().is_empty(),
		"the typed provisional commission catalogue validates")
	var templates := Orders.commission_templates()
	var labelled := templates.size() >= Orders.COMMISSION_OFFER_COUNT
	for template: CommissionTemplateDef in templates:
		labelled = labelled and template != null \
			and template.tuning_status.begins_with("PLACEHOLDER")
	_check(labelled,
		"every commission quantity and premium source remains explicitly provisional")


func _test_stable_owned_offer_generation() -> void:
	GameState.apply_save_dict(_unlocked_shape())
	_check(Orders.commissions_unlocked() \
		and GameState.get_commission_offers().size() == Orders.COMMISSION_OFFER_COUNT,
		"completing Pine Campsite Load automatically prepares the first standing choice")
	var offers := GameState.get_commission_offers()
	_check(offers.size() == Orders.COMMISSION_OFFER_COUNT,
		"the compact choice creates exactly three stable offers")
	var valid_owned := true
	var ids: Dictionary = {}
	for offer: Dictionary in offers:
		var normalised := Orders.normalise_commission_offer(offer)
		var species_id := StringName(offer.get("required_species", &""))
		valid_owned = valid_owned and not normalised.is_empty() \
			and (species_id == &"" or GameState.owns_species(species_id))
		ids[StringName(offer.get("id", &""))] = true
	_check(valid_owned and ids.size() == Orders.COMMISSION_OFFER_COUNT,
		"offers are unique, valid and expose only owned species or mixed work")
	var stable := GameState.get_commission_offers()
	_check(not GameState.ensure_commission_offers() and stable == offers,
		"re-entering the flow cannot reroll its persisted offer snapshots")


func _test_relevant_roles_and_rotation() -> void:
	var owned_ids: Array[String] = []
	for index in range(5):
		owned_ids.append(String(SpeciesTable.at(index).id))
	GameState.apply_save_dict({
		"owned_species": owned_ids,
		"completed_orders": [String(Orders.COMMISSION_UNLOCK_ORDER_ID)],
	})
	var offers := Orders.generate_commission_offers(0)
	var anchor := Orders.commission_cash_anchor()
	var table := load("res://data/commission_table.tres") as CommissionTable
	var expected_relevant := int(round(float(anchor) * table.relevance_premium_ratio))
	_check(offers.size() == 3 \
		and int(offers[0].get("offer_role", -1)) == Orders.CommissionOfferRole.MIXED \
		and int(offers[1].get("offer_role", -1)) == Orders.CommissionOfferRole.FRONTIER \
		and int(offers[2].get("offer_role", -1)) == Orders.CommissionOfferRole.ROTATION,
		"the board has stable mixed, frontier and rotation slot identities")
	_check(StringName(offers[1].get("required_species", &"")) == SpeciesTable.at(4).id \
		and int(offers[0].get("cash_bonus", 0)) == expected_relevant \
		and int(offers[1].get("cash_bonus", 0)) == expected_relevant,
		"mixed/frontier premiums follow the next-species anchor and frontier uses the highest owned wood")
	var rotation_species: Dictionary = {}
	for generation in range(4):
		var generated := Orders.generate_commission_offers(generation)
		rotation_species[StringName(generated[2].get("required_species", &""))] = true
	_check(rotation_species.size() == 4 and not rotation_species.has(SpeciesTable.at(4).id),
		"the rotation slot covers the broader owned catalogue without displacing frontier work")


func _test_single_long_term_selection() -> void:
	GameState.apply_save_dict(_unlocked_shape())
	GameState.ensure_commission_offers()
	var offers := GameState.get_commission_offers()
	var offer_id := StringName(offers[0].get("id", &""))
	var second_offer_id := StringName(offers[1].get("id", &""))
	_check(GameState.accept_order(&"campfire_warmup")
		and GameState.accept_commission(offer_id)
		and not GameState.accept_commission(second_offer_id)
		and GameState.get_active_manual_job_count() == 2,
		"authored work may coexist with exactly one selected standing commission")
	_check(not GameState.accept_order(&"campfire_warmup")
		and not GameState.accept_commission(offer_id),
		"the same delivery cannot be accepted twice")
	InventoryManager.apply_save_dict({})
	var shared_item := StringName(offers[1].get("required_item", &""))
	InventoryManager.add_item(shared_item, 1)
	Orders.settle_piece(shared_item)
	_check(GameState.get_active_order_progress_for(&"campfire_warmup") == 1
		and GameState.get_active_commission_progress_for(offer_id) == 1
		and GameState.get_active_commission_progress_for(second_offer_id) == 0,
		"one matching sale advances the authored job and sole selected commission")
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_active_manual_job_count() == 2
		and GameState.get_active_order_progress_for(&"campfire_warmup") == 1
		and GameState.get_active_commission_progress_for(offer_id) == 1,
		"the selected standing identity and bounded progress restore together")


func _test_manual_settlement_and_exact_completion() -> void:
	GameState.apply_save_dict(_unlocked_shape())
	InventoryManager.apply_save_dict({})
	GameState.ensure_commission_offers()
	var offer := _first_specific_offer(GameState.get_commission_offers())
	_check(not offer.is_empty() \
		and GameState.accept_commission(StringName(offer.get("id", &""))),
		"test setup accepts a species-specific standing commission")
	if offer.is_empty():
		return
	var required_item := StringName(offer.get("required_item", &""))
	var mismatched := SpeciesTable.starting_species().yield_item
	if mismatched == required_item:
		mismatched = SpeciesTable.at(1).yield_item
	InventoryManager.add_item(mismatched, 1)
	var mismatch_paid := Orders.settle_piece(mismatched)
	_check(mismatch_paid > 0 and GameState.get_active_commission_progress() == 0,
		"mismatched manual wood still sells but cannot advance the commission")
	var required_count := int(offer.get("required_count", 0))
	for _i in range(maxi(0, required_count - 1)):
		InventoryManager.add_item(required_item, 1)
		Orders.settle_piece(required_item)
	_check(GameState.get_active_commission_progress() == required_count - 1
		and GameState.get_completed_commission_count() == 0,
		"each successfully sold matching manual piece advances exactly once")
	var cash_before := GameState.get_cash()
	InventoryManager.add_item(required_item, 1)
	Orders.settle_piece(required_item)
	var expected_delta := Market.get_price(required_item) \
		+ int(offer.get("cash_bonus", 0))
	_check(GameState.get_cash() - cash_before == expected_delta
		and GameState.get_active_commission_id() == &""
		and GameState.get_completed_commission_count() == 1,
		"the final manual sale pays its ordinary value and fixed premium exactly once")
	var replacement_ids: Dictionary = {}
	for replacement: Dictionary in GameState.get_commission_offers():
		replacement_ids[StringName(replacement.get("id", &""))] = true
	_check(replacement_ids.is_empty(),
		"automatic payout closes the chip until the next campaign offer moment")
	EventBus.building_upgraded.emit(CompanyStrategy.machine().id,
		GameState.DEFAULT_BUILDING_TIER + 1)
	for replacement: Dictionary in GameState.get_commission_offers():
		replacement_ids[StringName(replacement.get("id", &""))] = true
	_check(replacement_ids.size() == Orders.COMMISSION_OFFER_COUNT
		and not replacement_ids.has(StringName(offer.get("id", &""))),
		"the regional-company beat prepares the next deterministic choice")


func _test_automation_exclusion() -> void:
	GameState.apply_save_dict(_unlocked_shape())
	InventoryManager.apply_save_dict({})
	GameState.ensure_commission_offers()
	var offer := _first_specific_offer(GameState.get_commission_offers())
	if offer.is_empty():
		_check(false, "automation exclusion setup finds a specific offer")
		return
	GameState.accept_commission(StringName(offer.get("id", &"")))
	var item_id := StringName(offer.get("required_item", &""))
	InventoryManager.add_item(item_id, 1)
	var paid := Market.sell_automation(item_id, 1, 0.0)
	_check(paid > 0 and GameState.get_active_commission_progress() == 0,
		"the separate automation sale path never advances manual commission work")


func _test_save_v17_and_restore() -> void:
	SaveSystem.delete_save()
	GameState.apply_save_dict(_unlocked_shape())
	InventoryManager.apply_save_dict({})
	GameState.ensure_commission_offers()
	var offers := GameState.get_commission_offers()
	var offer := _first_specific_offer(offers)
	GameState.accept_commission(StringName(offer.get("id", &"")))
	GameState.record_manual_delivery_piece(StringName(offer.get("required_item", &"")))
	_check(SaveSystem.save_game(), "a commission-bearing version 17 save writes atomically")
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK
		and GameState.get_commission_offers() == offers
		and GameState.get_active_commission_id() == StringName(offer.get("id", &""))
		and GameState.get_active_commission_progress() == 1,
		"offers and bounded mid-commission progress restore exactly without payout")
	var migrated := SaveSystem._migrate({"cash": 9}, 4)
	_check(migrated.get("commission_offers", null) == []
		and migrated.get("active_commission", "missing") == ""
		and int(migrated.get("completed_commissions", -1)) == 0,
		"version 4 migration invents no offers, active work or completion history")
	var v16_migrated := SaveSystem._migrate({
		"active_commissions": [{"id": "old_a", "progress": 2},
			{"id": "old_b", "progress": 3}],
	}, 16)
	_check((v16_migrated.get("legacy_commission_ids", []) as Array) \
		== ["old_a", "old_b"]
		and int(v16_migrated.get("standing_commission_cycles_completed", -1)) == 0
		and (v16_migrated.get("applied_progression_reward_sources", []) as Array).is_empty(),
		"v16 migration marks accepted multi-slot work as legacy without paying or consuming new choices")
	var v5_shape := GameState.to_save_dict()
	var v5_offers: Array = v5_shape.get("commission_offers", []).duplicate(true)
	var preserved_id := StringName(offer.get("id", &""))
	var old_inactive_ids: Dictionary = {}
	for raw_offer: Variant in v5_offers:
		if raw_offer is Dictionary:
			(raw_offer as Dictionary).erase("offer_role")
			var id := StringName((raw_offer as Dictionary).get("id", &""))
			if id != preserved_id:
				old_inactive_ids[id] = true
	v5_shape["commission_offers"] = v5_offers
	var cash_before_migration := GameState.get_cash()
	GameState.apply_save_dict(SaveSystem._migrate(v5_shape, 5))
	var active_survived := GameState.is_commission_active(preserved_id) \
		and GameState.get_active_commission_progress_for(preserved_id) == 1
	var inactive_refreshed := true
	for refreshed: Dictionary in GameState.get_commission_offers():
		var refreshed_id := StringName(refreshed.get("id", &""))
		if refreshed_id != preserved_id and old_inactive_ids.has(refreshed_id):
			inactive_refreshed = false
	_check(active_survived and inactive_refreshed \
		and GameState.get_cash() == cash_before_migration,
		"v5 migration preserves accepted work and cash while refreshing only inactive stale slots")


func _test_native_hud_flow() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var tabs: TabContainer = hud.get_node("OrdersPanel/Column/Tabs")
	var chip: PanelContainer = hud.get_node("ActiveJobChip")
	_check(tabs.is_tab_hidden(1) and not chip.visible,
		"the retired board tab and compact commission chip are absent before their gate")
	hud.queue_free()
	await get_tree().process_frame

	GameState.apply_save_dict(_unlocked_shape())
	GameState.ensure_commission_offers()
	hud = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	tabs = hud.get_node("OrdersPanel/Column/Tabs")
	chip = hud.get_node("ActiveJobChip")
	var task_button: Button = chip.get_node("Column/Header/Button")
	_check(tabs.is_tab_hidden(1) and chip.visible \
		and task_button.text.contains("choose 1 of 3"),
		"the compact objective chip replaces the commission board tab")
	var first := GameState.get_commission_offers()[0]
	GameState.accept_commission(StringName(first.get("id", &"")))
	await get_tree().process_frame
	chip = hud.get_node("ActiveJobChip")
	task_button = chip.get_node("Column/Header/Button")
	_check(chip.visible and task_button.text.contains("Tasks 1")
		and GameState.get_active_commission_ids().size() == 1,
		"the compact chip tracks the sole authoritative standing commission")
	(task_button as Button).pressed.emit()
	await get_tree().process_frame
	_check(not hud.get_node("OrdersPanel").visible and chip.visible,
		"expanding standing progress never opens the Contract Board")
	var cash_before := GameState.get_cash()
	GameState.order_completed.emit(&"campfire_warmup", 50)
	GameState.commission_completed.emit(first, int(first.get("cash_bonus", 0)))
	await get_tree().process_frame
	var receipt: PanelContainer = hud.get_node("DeliveryReceipt")
	var receipt_title: Label = hud.get_node("DeliveryReceipt/Column/Title")
	_check(receipt.visible and receipt_title.text.contains("2 deliveries") \
		and GameState.get_cash() == cash_before,
		"same-frame completions aggregate into one presentation-only receipt")
	hud.queue_free()
	await get_tree().process_frame


func _unlocked_shape() -> Dictionary:
	var curve := GameConfig.current().level_curve
	return {
		"xp": curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL),
		"owned_species": [String(SpeciesTable.at(1).id)],
		"completed_orders": [String(Orders.COMMISSION_UNLOCK_ORDER_ID)],
	}


func _first_specific_offer(offers: Array[Dictionary]) -> Dictionary:
	for offer: Dictionary in offers:
		if StringName(offer.get("required_item", &"")) != &"":
			return offer
	return {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _stash_real_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(_BACKUP_PATH):
		dir.remove(_BACKUP_PATH)
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP_PATH)


func _restore_real_save() -> void:
	SaveSystem.delete_save()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(_BACKUP_PATH):
		dir.rename(_BACKUP_PATH, SaveSystem.SAVE_PATH)
