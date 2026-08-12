extends Node
## Focused M9 regional supplier network acceptance.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M9 REGIONAL ACCEPTANCE — Supplier Atlas and Routes ===")
	_test_catalogue_and_discovery()
	_test_visible_fixable_steps()
	_test_regional_customer_standing()
	_test_signature_manual_ownership()
	_test_v9_migration_and_restore()
	await _test_native_atlas()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M9 REGIONAL RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M9 REGIONAL ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_catalogue_and_discovery() -> void:
	GameState.reset_to_defaults()
	_check(RegionalNetwork.initial_regions().size() == 3
		and RegionalNetwork.validate_catalogue().is_empty(),
		"Eastern, Boreal and Northern Europe typed regional catalogues validate")
	_check(RegionalNetwork.region_for_species(&"quaking_aspen").id \
		== &"eastern_north_america"
		and RegionalNetwork.region_for_species(&"balsam_fir").id \
		== &"boreal_north_america"
		and RegionalNetwork.region_for_species(&"norway_spruce").id \
		== &"northern_europe",
		"existing species reference one authored source without duplicated definitions")
	_check(GameState.discover_region(&"eastern_north_america")
		and not GameState.discover_region(&"boreal_north_america"),
		"reputation discovers the home supplier while later regions remain gated")
	GameState.add_reputation(4)
	_check(GameState.discover_region(&"boreal_north_america"),
		"monotonic reputation opens the next supplier region")


func _test_visible_fixable_steps() -> void:
	GameState.reset_to_defaults()
	var species_id := &"quaking_aspen"
	_check(int(RegionalNetwork.supply_status(species_id).reason) \
		== RegionalNetwork.DelayReason.STANDING,
		"an undiscovered supplier names reputation as the blocking step")
	GameState.discover_region(&"eastern_north_america")
	GameState.add_regional_standing(&"eastern_north_america", 2)
	_check(int(RegionalNetwork.supply_status(species_id).reason) \
		== RegionalNetwork.DelayReason.DEPOT,
		"sufficient standing names the missing depot as the next fix")
	GameState.add_cash(1000000)
	_check(GameState.build_regional_depot(&"eastern_north_america")
		and int(RegionalNetwork.supply_status(species_id).reason) \
		== RegionalNetwork.DelayReason.ROUTE,
		"the atomic depot purchase advances the diagnosis to freight route")
	_check(GameState.establish_regional_route(&"eastern_north_america")
		and int(RegionalNetwork.supply_status(species_id).reason) \
		== RegionalNetwork.DelayReason.DISPATCH,
		"an established route names missing yard dispatch equipment")
	_prepare_certified_aspen_logistics(false)
	var preserved := GameState.to_save_dict()
	preserved["discovered_regions"] = ["eastern_north_america"]
	preserved["regional_standing"] = {"eastern_north_america": 2}
	preserved["regional_depots"] = ["eastern_north_america"]
	preserved["regional_routes"] = {"eastern_north_america": "east_road_freight"}
	GameState.apply_save_dict(preserved)
	_check(int(RegionalNetwork.supply_status(species_id).reason) \
		== RegionalNetwork.DelayReason.READY,
		"a certified connected supplier becomes directly dispatchable")
	GameState.enqueue_supplier_input(species_id,
		CompanySimulation.config().supplier_queue_capacity)
	_check(int(RegionalNetwork.supply_status(species_id).reason) \
		== RegionalNetwork.DelayReason.YARD_QUEUE,
		"a full bounded input reports the yard queue rather than a vague delay")


func _test_regional_customer_standing() -> void:
	GameState.apply_save_dict({
		"owned_species": [String(SpeciesTable.at(1).id)],
		"completed_orders": [String(Orders.COMMISSION_UNLOCK_ORDER_ID)],
		"discovered_regions": ["eastern_north_america"],
	})
	InventoryManager.apply_save_dict({})
	GameState.ensure_commission_offers()
	var offer := GameState.get_commission_offers()[0]
	GameState.accept_commission(StringName(offer.id))
	var item_id := SpeciesTable.starting_species().yield_item
	for _index in range(int(offer.required_count)):
		InventoryManager.add_item(item_id, 1)
		Orders.settle_piece(item_id)
	_check(GameState.get_regional_standing(&"eastern_north_america") == 1,
		"completing a regional customer's manual commission grants standing once")


func _test_signature_manual_ownership() -> void:
	GameState.reset_to_defaults()
	var manual := ManualPieceReceipt.new(&"aspen_firewood", &"quaking_aspen", 0.25,
		Craftsmanship.Grade.EXCEPTIONAL, &"signature_log")
	var automation := ManualPieceReceipt.new(&"aspen_firewood", &"quaking_aspen", 0.25,
		Craftsmanship.Grade.EXCEPTIONAL, &"automation_log",
		ManualPieceReceipt.Origin.AUTOMATION)
	_check(GameState.record_signature_log(manual)
		and not GameState.record_signature_log(manual)
		and not GameState.record_signature_log(automation)
		and GameState.get_signature_log_record(&"quaking_aspen") == 1,
		"signature-log records require one exceptional traceable manual source")


func _test_v9_migration_and_restore() -> void:
	var migrated := SaveSystem._migrate({"cash": 9}, 8)
	_check((migrated.get("discovered_regions") as Array).is_empty()
		and (migrated.get("regional_routes") as Dictionary).is_empty()
		and (migrated.get("signature_log_records") as Dictionary).is_empty(),
		"v8 to v9 migration invents no discovery, route or signature record")
	GameState.apply_save_dict({
		"cash": 123,
		"discovered_regions": ["eastern_north_america"],
		"regional_standing": {"eastern_north_america": 7},
		"regional_depots": ["eastern_north_america"],
		"regional_routes": {"eastern_north_america": "east_road_freight"},
		"signature_log_records": {"quaking_aspen": 2},
		"signature_log_sources": {"a": "quaking_aspen", "b": "quaking_aspen"},
	})
	var snapshot := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(snapshot)
	_check(GameState.get_cash() == 123 and GameState.is_region_discovered(
		&"eastern_north_america") and GameState.get_regional_standing(
		&"eastern_north_america") == 7 and GameState.has_regional_route(
		&"eastern_north_america") and GameState.get_signature_log_record(
		&"quaking_aspen") == 2,
		"regional standing, depot, route and records round-trip without new rewards")


func _test_native_atlas() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"reputation": 8})
	var early_hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(early_hud)
	await get_tree().process_frame
	_check(not (early_hud.get_node("QuickMenu/AtlasButton") as Button).visible,
		"reputation alone does not expose the mid-game Supplier Atlas")
	early_hud.queue_free()
	await get_tree().process_frame

	GameState.apply_save_dict({
		"reputation": 8,
		"building_tiers": {String(CompanyStrategy.machine().id): 2},
	})
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("QuickMenu/AtlasButton").pressed.emit()
	await get_tree().process_frame
	var panel: PanelContainer = hud.get_node("AtlasPanel")
	var list: VBoxContainer = hud.get_node("AtlasPanel/Column/Scroll/List")
	_check(panel.visible and list.get_child_count() == 4
		and list.get_node_or_null("eastern_north_america") != null
		and list.get_node_or_null("northern_europe") != null
		and list.get_node_or_null("pacific_northwest") == null,
		"the native Supplier Atlas presents only the three actionable regions")
	hud.queue_free()
	await get_tree().process_frame


func _prepare_certified_aspen_logistics(include_queue: bool) -> void:
	var species := SpeciesTable.starting_species()
	var mastery := M7CContent.mastery().by_species_id(species.id)
	var tiers := {
		String(MechanicalSplitter.machine_definition().id): 2,
		String(MechanicalSplitter.profile_for_species(species.id).id): 2,
		"log_feeder": 2,
	}
	GameState.apply_save_dict({
		"building_tiers": tiers,
		"species_mastery_progress": {String(species.id): mastery.mastery_target},
	})
	if include_queue:
		GameState.enqueue_supplier_input(species.id, 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
