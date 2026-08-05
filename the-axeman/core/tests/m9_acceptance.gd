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
	_test_multiple_active_deliveries()
	_test_manual_settlement_and_exact_completion()
	_test_automation_exclusion()
	_test_save_v5_and_restore()
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
	_check(Orders.commissions_unlocked() and GameState.ensure_commission_offers(),
		"completing Pine Campsite Load makes the first standing offers eligible")
	var offers := GameState.get_commission_offers()
	_check(offers.size() == Orders.COMMISSION_OFFER_COUNT,
		"the earned board creates exactly three offers")
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


func _test_multiple_active_deliveries() -> void:
	GameState.apply_save_dict(_unlocked_shape())
	GameState.ensure_commission_offers()
	var offers := GameState.get_commission_offers()
	var offer_id := StringName(offers[0].get("id", &""))
	var second_offer_id := StringName(offers[1].get("id", &""))
	_check(GameState.accept_order(&"campfire_warmup")
		and GameState.accept_commission(offer_id)
		and GameState.accept_commission(second_offer_id)
		and GameState.get_active_manual_job_count() == 3,
		"authored contracts and standing commissions can remain active together")
	_check(not GameState.accept_order(&"campfire_warmup")
		and not GameState.accept_commission(offer_id),
		"the same delivery cannot be accepted twice")
	InventoryManager.apply_save_dict({})
	InventoryManager.add_item(&"aspen_firewood", 1)
	Orders.settle_piece(&"aspen_firewood")
	_check(GameState.get_active_order_progress_for(&"campfire_warmup") == 1
		and GameState.get_active_commission_progress_for(offer_id) == 1
		and GameState.get_active_commission_progress_for(second_offer_id) == 1,
		"one matching manual sale advances every matching accepted delivery")
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_active_manual_job_count() == 3
		and GameState.get_active_order_progress_for(&"campfire_warmup") == 1
		and GameState.get_active_commission_progress_for(offer_id) == 1
		and GameState.get_active_commission_progress_for(second_offer_id) == 1,
		"multiple active identities and bounded progress restore together")


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
	_check(replacement_ids.size() == Orders.COMMISSION_OFFER_COUNT
		and not replacement_ids.has(StringName(offer.get("id", &""))),
		"completion advances the sole generation authority and posts a new stable set")


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


func _test_save_v5_and_restore() -> void:
	SaveSystem.delete_save()
	GameState.apply_save_dict(_unlocked_shape())
	InventoryManager.apply_save_dict({})
	GameState.ensure_commission_offers()
	var offers := GameState.get_commission_offers()
	var offer := _first_specific_offer(offers)
	GameState.accept_commission(StringName(offer.get("id", &"")))
	GameState.record_manual_delivery_piece(StringName(offer.get("required_item", &"")))
	_check(SaveSystem.save_game(), "a commission-bearing version 5 save writes atomically")
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


func _test_native_hud_flow() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var tabs: TabContainer = hud.get_node("OrdersPanel/Column/Tabs")
	var chip: PanelContainer = hud.get_node("ActiveJobChip")
	_check(tabs.is_tab_hidden(1) and not chip.visible,
		"the native Commissions tab and active chip are absent before their gate")
	hud.queue_free()
	await get_tree().process_frame

	GameState.apply_save_dict(_unlocked_shape())
	GameState.ensure_commission_offers()
	hud = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	tabs = hud.get_node("OrdersPanel/Column/Tabs")
	var list: VBoxContainer = hud.get_node("OrdersPanel/Column/Tabs/Commissions/Scroll/List")
	_check(not tabs.is_tab_hidden(1) \
		and list.get_child_count() == Orders.COMMISSION_OFFER_COUNT,
		"the earned native tab shows exactly the persisted standing offers")
	var first := GameState.get_commission_offers()[0]
	GameState.accept_commission(StringName(first.get("id", &"")))
	await get_tree().process_frame
	chip = hud.get_node("ActiveJobChip")
	var task_button: Button = chip.get_node("Column/Header/Button")
	_check(chip.visible and task_button.text.contains("Tasks 1"),
		"the compact active-task stand-in follows authoritative commission state")
	(task_button as Button).pressed.emit()
	await get_tree().process_frame
	_check(hud.get_node("OrdersPanel").visible and not chip.visible
		and tabs.current_tab == 1,
		"the active chip opens its commission and gets out of the board's way")
	hud._close_panels()
	await get_tree().process_frame
	_check(chip.visible,
		"closing the board restores the active objective over live chopping")
	var cash_before := GameState.get_cash()
	GameState.commission_completed.emit(first, int(first.get("cash_bonus", 0)))
	await get_tree().process_frame
	var receipt: PanelContainer = hud.get_node("DeliveryReceipt")
	_check(receipt.visible and GameState.get_cash() == cash_before,
		"the native delivery card is presentation-only and cannot mint progression")
	hud.queue_free()
	await get_tree().process_frame


func _unlocked_shape() -> Dictionary:
	return {
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
