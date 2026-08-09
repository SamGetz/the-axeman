extends Node
## Focused completion suite for M8 supplier queues, direct purchases and offline equivalence.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M8 LOGISTICS ACCEPTANCE — Certified Queues and Offline Ledger ===")
	_test_purchase_sequence()
	_test_bounded_queue_and_priority()
	_test_active_offline_equivalence()
	_test_atomic_application_and_exclusions()
	_test_bulk_only_automation()
	_test_v8_migration_and_restore()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M8 LOGISTICS RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M8 LOGISTICS ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_purchase_sequence() -> void:
	GameState.reset_to_defaults()
	_check(CompanyLogistics.validate_catalogue().is_empty()
		and CompanyLogistics.upgrades().size() == 3,
		"three bundled logistics stages replace the former six-click sequence")
	var first := CompanyLogistics.upgrades()[0]
	_check(not CompanyLogistics.buy(first.id),
		"logistics cannot be purchased before the certified splitter is installed")
	_prepare_certified_aspen(false)
	GameState.add_cash(1000000)
	var spent := 0
	var all_bought := true
	for upgrade: LogisticsUpgradeDef in CompanyLogistics.upgrades():
		var cash_before := GameState.get_cash()
		all_bought = all_bought and CompanyLogistics.buy(upgrade.id)
		spent += upgrade.cost
		all_bought = all_bought and GameState.get_cash() == cash_before - upgrade.cost
	_check(all_bought and CompanyLogistics.all_owned(),
		"Log Feeder through Dispatch Console purchase atomically in authored order")
	_check(not CompanyLogistics.buy(first.id) and GameState.get_cash() == 1000000 - spent,
		"owned logistics purchases cannot charge or apply twice")
	_check(not CompanyLogistics.can_run_offline(),
		"Dispatch Console alone cannot skip the required watched automation path")
	GameState.record_watched_automation_logs(1)
	_check(CompanyLogistics.can_run_offline(),
		"one watched certified cycle enables bounded offline dispatch")


func _test_bounded_queue_and_priority() -> void:
	_prepare_certified_aspen(true)
	var cfg := CompanySimulation.config()
	var species_id := SpeciesTable.starting_species().id
	_check(GameState.enqueue_supplier_input(species_id, cfg.supplier_queue_capacity),
		"the Log Feeder accepts one full certified supplier queue")
	_check(not GameState.enqueue_supplier_input(species_id, 1)
		and int(GameState.get_supplier_input_queues().get(species_id, 0)) \
		== cfg.supplier_queue_capacity,
		"supplier input refuses overflow atomically at its resource-authored bound")
	_check(GameState.set_route_priorities([species_id])
		and GameState.get_route_priorities() == [species_id],
		"the Order Router persists an explicit visible species priority")
	_check(not GameState.enqueue_supplier_input(&"lignum_vitae", 1),
		"uncertified supplier wood cannot enter an automation queue")


func _test_active_offline_equivalence() -> void:
	var species_id := SpeciesTable.starting_species().id
	var state := {
		"queues": {species_id: 10},
		"route_priorities": [species_id],
		"last_timestamp": 100,
		"dispatch_capacity": 1,
	}
	var active := CompanySimulation.simulate_duration(state, 50)
	var offline := CompanySimulation.simulate(state, 150, true)
	_check(active.processed_by_species == offline.processed_by_species
		and active.outputs == offline.outputs
		and active.remaining_queues == offline.remaining_queues,
		"active and offline simulation are mathematically equivalent for identical inputs")
	var capped := CompanySimulation.simulate({
		"queues": {species_id: CompanySimulation.config().supplier_queue_capacity},
		"route_priorities": [species_id], "last_timestamp": 0,
	}, CompanySimulation.config().offline_cap_seconds * 3, true)
	_check(capped.elapsed_seconds == CompanySimulation.config().offline_cap_seconds
		and capped.processed_logs() <= CompanySimulation.config().supplier_queue_capacity,
		"offline progress is bounded by both elapsed-time and supplier-queue caps")


func _test_atomic_application_and_exclusions() -> void:
	_prepare_certified_aspen(true)
	var species := SpeciesTable.starting_species()
	GameState.record_watched_automation_logs(1)
	GameState.set_company_clock_anchor(100)
	GameState.enqueue_supplier_input(species.id, 5)
	var craft_before := GameState.get_craft_grade_count(Craftsmanship.Grade.ROUGH)
	var rep_before := GameState.get_reputation()
	var mastery_before := GameState.get_species_mastery_progress(species.id)
	var receipt := CompanySimulation.simulate(GameState.get_company_simulation_input(), 110)
	var cash_before := GameState.get_cash()
	_check(receipt.processed_logs() == 2 and CompanyLogistics.apply_receipt(receipt)
		and GameState.get_cash() > cash_before
		and InventoryManager.get_count(species.yield_item) == 0,
		"a deterministic receipt deposits and sells output through the owning systems")
	_check(not CompanyLogistics.apply_receipt(receipt)
		and GameState.get_company_return_ledger().size() == 1,
		"the same receipt cannot settle twice and the return ledger records it once")
	_check(GameState.get_craft_grade_count(Craftsmanship.Grade.ROUGH) == craft_before
		and GameState.get_reputation() == rep_before
		and GameState.get_species_mastery_progress(species.id) == mastery_before,
		"offline automation cannot earn craftsmanship, reputation or manual mastery")


func _test_bulk_only_automation() -> void:
	_prepare_certified_aspen(true)
	var species := SpeciesTable.starting_species()
	var shape := GameState.to_save_dict()
	shape["completed_orders"] = [String(Orders.COMMISSION_UNLOCK_ORDER_ID)]
	shape["commission_generation"] = 1
	shape["reputation"] = 20
	shape["commission_offers"] = []
	GameState.apply_save_dict(shape)
	GameState.ensure_commission_offers()
	var bulk: Dictionary = {}
	var handcrafted: Dictionary = {}
	for offer: Dictionary in GameState.get_commission_offers():
		if bool(offer.get("automation_eligible", false)):
			bulk = offer
		elif int(offer.get("minimum_grade", 0)) > 0:
			handcrafted = offer
	_check(not bulk.is_empty() and not handcrafted.is_empty()
		and GameState.accept_commission(StringName(bulk.id))
		and not GameState.accept_commission(StringName(handcrafted.id))
		and GameState.get_active_commission_ids().size() == 1,
		"the compact standing choice admits one long-term commission at a time")
	var amount := int(bulk.get("required_count", 0))
	GameState.record_automation_bulk_delivery(species.yield_item, amount, &"bulk_fixture")
	_check(not GameState.is_commission_active(StringName(bulk.id))
		and GameState.get_active_commission_progress_for(StringName(handcrafted.id)) == 0,
		"automated wood fulfils certified bulk but never handcrafted size/quality/signature work")


func _test_v8_migration_and_restore() -> void:
	var migrated := SaveSystem._migrate({"cash": 7}, 7)
	_check((migrated.get("supplier_input_queues") as Dictionary).is_empty()
		and int(migrated.get("automated_log_equivalents", -1)) == 0
		and (migrated.get("company_return_ledger") as Array).is_empty(),
		"v7 to v8 migration invents no queues, automated work or return rewards")
	_prepare_certified_aspen(true)
	var species_id := SpeciesTable.starting_species().id
	GameState.set_company_clock_anchor(1234)
	GameState.enqueue_supplier_input(species_id, 3)
	GameState.record_watched_automation_logs(9)
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(int(GameState.get_supplier_input_queues().get(species_id, 0)) == 3
		and GameState.get_automated_log_equivalents() == 9
		and int(GameState.get_company_simulation_input().last_timestamp) == 1234,
		"queue, clock and separate automated log-equivalents restore without processing")


func _prepare_certified_aspen(with_logistics: bool) -> void:
	var species := SpeciesTable.starting_species()
	var mastery := M7CContent.mastery().by_species_id(species.id)
	var machine := MechanicalSplitter.machine_definition()
	var profile := MechanicalSplitter.profile_for_species(species.id)
	var tiers := {
		String(machine.id): 2,
		String(profile.id): 2,
	}
	if with_logistics:
		for upgrade: LogisticsUpgradeDef in CompanyLogistics.upgrades():
			tiers[String(upgrade.id)] = 2
	GameState.apply_save_dict({
		"building_tiers": tiers,
		"species_mastery_progress": {String(species.id): mastery.mastery_target},
	})
	InventoryManager.apply_save_dict({})


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
