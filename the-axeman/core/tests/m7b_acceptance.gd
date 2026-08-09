extends Node
## Focused acceptance for M7B craftsmanship, customers and reputation.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M7B ACCEPTANCE — Craftsmanship, Customers and Reputation ===")
	_test_grade_rules_and_value()
	_test_typed_manual_ownership()
	_test_craft_families()
	_test_reputation_and_history()
	_test_v7_migration_and_restore()
	await _test_native_feedback_and_customer_cards()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M7B RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M7B ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_grade_rules_and_value() -> void:
	var cfg := Craftsmanship.config()
	_check(cfg != null and cfg.validate().is_empty()
		and cfg.tuning_status.begins_with("PLACEHOLDER"),
		"forgiving grade thresholds and premiums live in labelled provisional data")
	_check(Craftsmanship.grade_piece(0.80) == Craftsmanship.Grade.ROUGH
		and Craftsmanship.grade_piece(0.34) == Craftsmanship.Grade.CLEAN
		and Craftsmanship.grade_piece(0.25) == Craftsmanship.Grade.EXCEPTIONAL,
		"normalized geometry resolves rough, clean and exceptional bands")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var item_id := &"oak_firewood"
	var price := Market.get_price(item_id)
	InventoryManager.add_item(item_id, 3)
	var rough := Orders.settle_manual_piece(ManualPieceReceipt.new(item_id,
		&"pedunculate_oak", 0.8, Craftsmanship.Grade.ROUGH, &"log_a"))
	var clean := Orders.settle_manual_piece(ManualPieceReceipt.new(item_id,
		&"pedunculate_oak", 0.34, Craftsmanship.Grade.CLEAN, &"log_a"))
	var exceptional := Orders.settle_manual_piece(ManualPieceReceipt.new(item_id,
		&"pedunculate_oak", 0.25, Craftsmanship.Grade.EXCEPTIONAL, &"log_a"))
	_check(rough == price and clean == price + Craftsmanship.cash_bonus(item_id,
		Craftsmanship.Grade.CLEAN) and exceptional == price + Craftsmanship.cash_bonus(
		item_id, Craftsmanship.Grade.EXCEPTIONAL),
		"rough always sells at base while higher manual grades add exact data-backed value")
	_check(GameState.get_craft_grade_count(Craftsmanship.Grade.ROUGH) == 1
		and GameState.get_craft_grade_count(Craftsmanship.Grade.CLEAN) == 1
		and GameState.get_craft_grade_count(Craftsmanship.Grade.EXCEPTIONAL) == 1,
		"manual grade records count each successfully settled piece once")


func _test_typed_manual_ownership() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var item_id := SpeciesTable.starting_species().yield_item
	InventoryManager.add_item(item_id, 1)
	var automation := ManualPieceReceipt.new(item_id, &"quaking_aspen", 0.25,
		Craftsmanship.Grade.EXCEPTIONAL, &"auto_log",
		ManualPieceReceipt.Origin.AUTOMATION)
	var before := GameState.to_save_dict()
	_check(Orders.settle_manual_piece(automation) == 0
		and InventoryManager.get_count(item_id) == 1
		and GameState.get_craft_grade_count(Craftsmanship.Grade.EXCEPTIONAL) == 0
		and GameState.get_reputation() == 0,
		"automation-origin receipts cannot sell, grade, gain reputation or claim manual work")
	_check(before.get("reputation", -1) == GameState.get_reputation(),
		"a rejected automation receipt leaves progression unchanged")


func _test_craft_families() -> void:
	var templates := Orders.commission_templates()
	var families: Dictionary = {}
	var valid := templates.size() >= 5
	for template: CommissionTemplateDef in templates:
		valid = valid and template != null and template.craft_requirement != null \
			and template.craft_requirement.validate().is_empty()
		if template != null and template.craft_requirement != null:
			families[int(template.craft_requirement.family)] = true
	_check(valid and families.size() == 5,
		"typed commission data represents quantity, species, size, quality and signature families")
	var size_rule: CraftRequirementDef
	var quality_rule: CraftRequirementDef
	var signature_rule: CraftRequirementDef
	for template: CommissionTemplateDef in templates:
		if template.craft_requirement.family == CraftRequirementDef.Family.SIZE_BAND:
			size_rule = template.craft_requirement
		elif template.craft_requirement.family == CraftRequirementDef.Family.QUALITY:
			quality_rule = template.craft_requirement
		elif template.craft_requirement.family == CraftRequirementDef.Family.SIGNATURE:
			signature_rule = template.craft_requirement
	var rough_large := ManualPieceReceipt.new(&"oak_firewood", &"pedunculate_oak",
		0.8, Craftsmanship.Grade.ROUGH)
	var clean_target := ManualPieceReceipt.new(&"oak_firewood", &"pedunculate_oak",
		0.25, Craftsmanship.Grade.CLEAN, &"manual_log")
	var exceptional_target := ManualPieceReceipt.new(&"oak_firewood", &"pedunculate_oak",
		0.25, Craftsmanship.Grade.EXCEPTIONAL, &"manual_log")
	_check(size_rule != null and not size_rule.matches(rough_large)
		and size_rule.matches(clean_target) and quality_rule.matches(clean_target)
		and not signature_rule.matches(clean_target)
		and signature_rule.matches(exceptional_target),
		"size, quality and signature rules reject misses and accept qualifying manual receipts")


func _test_reputation_and_history() -> void:
	GameState.reset_to_defaults()
	var customers := Orders.customers()
	var gates_monotonic := customers.size() >= 5
	var previous := -1
	for customer: CustomerDef in customers:
		gates_monotonic = gates_monotonic and customer.validate().is_empty() \
			and customer.reputation_required >= previous
		previous = customer.reputation_required
	_check(gates_monotonic and customers[0].is_unlocked(0)
		and not customers.back().is_unlocked(0)
		and customers.back().is_unlocked(customers.back().reputation_required),
		"monotonic reputation visibly unlocks authored customer families")
	var curve := GameConfig.current().level_curve
	GameState.apply_save_dict({
		"xp": curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL),
		"active_orders": [{"id": "campfire_warmup", "progress": 9}],
	})
	InventoryManager.apply_save_dict({})
	var item_id := SpeciesTable.starting_species().yield_item
	InventoryManager.add_item(item_id, 1)
	Orders.settle_piece(item_id)
	var gained := Orders.by_id(&"campfire_warmup").reputation_reward
	_check(GameState.get_reputation() == gained and GameState.has_completed_order(
		&"campfire_warmup") and GameState.get_customer_completion_history().size() == 1,
		"a completed customer order grants non-spendable reputation once and records history")
	InventoryManager.add_item(item_id, 1)
	Orders.settle_piece(item_id)
	_check(GameState.get_reputation() == gained,
		"ordinary later sales cannot replay a completed order's reputation")
	for index in range(Orders.customer_history_limit() + 3):
		GameState._append_customer_completion({
			"kind": "test", "id": str(index), "customer": "Bounded fixture"})
	var history := GameState.get_customer_completion_history()
	_check(history.size() == Orders.customer_history_limit()
		and String(history[0].get("id", "")) == "3",
		"customer completion history evicts oldest entries at its resource-authored bound")


func _test_v7_migration_and_restore() -> void:
	var legacy_offer := {
		"id": "commission_1_0_neighbourhood_bundle",
		"template_id": "neighbourhood_bundle",
		"customer_name": "Neighbourhood Hearth Circle",
		"title": "Mixed Firewood Round",
		"description": "Preserved work",
		"offer_role": 0,
		"goal_kind": 0,
		"required_species": "",
		"required_item": "",
		"required_count": 12,
		"cash_bonus": 50,
	}
	var migrated := SaveSystem._migrate({"commission_offers": [legacy_offer]}, 6)
	var migrated_offer: Dictionary = migrated.get("commission_offers", [])[0]
	_check(int(migrated.get("reputation", -1)) == 0
		and (migrated.get("craft_grade_counts") as Dictionary).is_empty()
		and (migrated.get("customer_completion_history") as Array).is_empty()
		and int(migrated_offer.get("craft_family", -1)) == CraftRequirementDef.Family.QUANTITY,
		"v6 to v7 migration grants no reputation, craft records, history or retroactive quality gate")
	GameState.apply_save_dict({
		"reputation": 17,
		"craft_grade_counts": {0: 2, 1: 3, 2: 4},
		"customer_completion_history": [{"customer": "Village Baker", "id": "x"}],
	})
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_reputation() == 17
		and GameState.get_craft_grade_count(Craftsmanship.Grade.EXCEPTIONAL) == 4
		and GameState.get_customer_completion_history().size() == 1,
		"reputation, craft records and bounded customer history round-trip without rewards")


func _test_native_feedback_and_customer_cards() -> void:
	GameState.apply_save_dict({
		"owned_species": [String(SpeciesTable.at(1).id)],
		"completed_orders": [String(Orders.COMMISSION_UNLOCK_ORDER_ID)],
		"reputation": 8,
	})
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var list: VBoxContainer = hud.get_node("OrdersPanel/Column/Tabs/Commissions/Scroll/List")
	var cards := list.get_node_or_null("CustomerCards")
	_check(cards != null and cards.get_child_count() == Orders.customers().size() + 1,
		"the native commission board exposes reputation and all customer cards")
	var feedback: Label = hud.get_node("CraftFeedback")
	GameState.present_manual_piece_settlement(ManualPieceReceipt.new(&"oak_firewood",
		&"pedunculate_oak", 0.25, Craftsmanship.Grade.EXCEPTIONAL, &"log"), 95)
	await get_tree().process_frame
	_check(feedback.visible and feedback.text.contains("Exceptional")
		and feedback.text.contains("+95"),
		"manual settlement gives immediate non-blocking grade and premium feedback")
	hud.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
