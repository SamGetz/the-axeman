extends Node
## Non-headless 1280×720 M15 reveal/counter captures. In-memory state only.

const OUT := "/private/tmp/axeman_m15_"


func _ready() -> void:
	await _capture("fresh_counter", {}, &"")
	await _capture("timber_depot_shop", _timber_depot_state(), &"ShopButton")
	await _capture("planetary_shop", _planetary_state(), &"ShopButton", 780)
	await _capture("earth_zero_exhaustion", _zero_state(), &"AtlasButton")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	get_tree().quit()


func _capture(tag: String, state: Dictionary, button: StringName,
		scroll_position := 0) -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	if not state.is_empty():
		GameState.apply_save_dict(state)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	hud.bind_splitter_runtime(game.get_node("MechanicalSplitterRuntime") \
		as MechanicalSplitterRuntime)
	await _frames(24)
	if button != &"":
		var action := hud.get_node("QuickMenu/%s" % button) as Button
		if action.visible:
			action.pressed.emit()
			await _frames(4)
	if button == &"ShopButton":
		var tabs := hud.get_node("ShopPanel/Column/ShopTabs") as TabContainer
		tabs.current_tab = 1
		if scroll_position > 0:
			var scroll := hud.get_node(
				"ShopPanel/Column/ShopTabs/Splitter/Scroll") as ScrollContainer
			scroll.scroll_vertical = scroll_position
		await _frames(4)
	var image := get_viewport().get_texture().get_image()
	var path := OUT + tag + ".png"
	image.save_png(path)
	print("M15 SHOT %s · %dx%d" % [path, image.get_width(), image.get_height()])
	hud.queue_free()
	game.queue_free()
	await _frames(4)


func _timber_depot_state() -> Dictionary:
	return {
		"cash": 1000000,
		"lifetime_cash_earned": 1000000,
		"automated_log_equivalents": 1,
		"building_tiers": {
			"mechanical_splitter": 2,
			"log_feeder": 2,
			"yard_sweeper": 2,
			"auto_stacker": 2,
			"order_router": 2,
			"maintenance_package": 2,
			"dispatch_console": 2,
		},
	}


func _planetary_state() -> Dictionary:
	var state := _timber_depot_state()
	var mastery: Dictionary = {}
	var owned: Array[String] = []
	for species: SpeciesDef in SpeciesTable.all():
		owned.append(String(species.id))
		mastery[String(species.id)] = M7CContent.mastery().by_species_id(
			species.id).mastery_target
	state["cash"] = 1000000000000
	state["lifetime_cash_earned"] = 1000000000000
	state["owned_species"] = owned
	state["species_mastery_progress"] = mastery
	state["infrastructure_projects"] = EarthCampaign.GLOBAL_PROJECT_IDS.duplicate()
	state["regional_routes"] = {"eastern_north_america": "eastern_truck_route"}
	state["building_tiers"] = (state["building_tiers"] as Dictionary).merged({
		"satellite_forest_survey": 2,
		"parallel_splitter_bay": 3,
		"recovery_saw_bench": 2,
		"commercial_grading_desk": 2,
	}, true)
	return state


func _zero_state() -> Dictionary:
	var state := _planetary_state()
	(state["building_tiers"] as Dictionary)["continuity_reserve"] = 2
	state["cash"] = 0
	state["automated_log_equivalents"] = 400000
	state["earth_trees_felled"] = GameState.TOTAL_EARTH_TREES
	state["earth_master"] = true
	state["earth_finale_state"] = GameState.EarthFinaleState.COMPLETE
	state["earth_finale_splits"] = 3
	var introduced: Array[String] = []
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef:
			introduced.append("shop_%s" % upgrade.id)
	state["introduced_feature_ids"] = introduced
	return state


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
