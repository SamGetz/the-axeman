extends Node
## Non-headless 1280×720 tutorial and placeholder-art review captures.

const OUT := "/private/tmp/axeman_tutorial_"


func _ready() -> void:
	await _capture_fresh_yard()
	await _capture_complete_gallery()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	get_tree().quit()


func _capture_fresh_yard() -> void:
	var nodes := await _make_scene({})
	var hud: Control = nodes.hud
	hud.begin_tutorial(true)
	await _frames(4)
	_save("fresh_yard")
	await _clear_scene(nodes)


func _capture_complete_gallery() -> void:
	var after_chopping := ["tutorial_started"]
	var after_opening := ["tutorial_started", "tutorial_opening_complete"]
	var curve := GameConfig.current().level_curve
	var level_two_xp := curve.total_xp_for_level(2)
	var level_three_xp := curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL)
	var specs: Array[Dictionary] = [
		{"id": &"skills", "state": {
			"cash": 50, "lifetime_cash_earned": 50,
			"xp": level_two_xp, "skill_points_earned_total": 1,
			"last_rewarded_level": 2,
			"introduced_feature_ids": after_chopping}},
		{"id": &"skill_spend", "panel": &"skills", "state": {
			"cash": 50, "lifetime_cash_earned": 50,
			"xp": level_two_xp, "skill_points_earned_total": 1,
			"last_rewarded_level": 2,
			"introduced_feature_ids": after_chopping}},
		{"id": &"open_orders", "state": {
			"cash": 50, "lifetime_cash_earned": 50,
			"xp": level_three_xp, "skill_points_earned_total": 2,
			"last_rewarded_level": 3,
			"introduced_feature_ids": after_chopping}},
		{"id": &"orders_reading", "panel": &"orders", "state": {
			"cash": 50, "lifetime_cash_earned": 50,
			"xp": level_three_xp, "skill_points_earned_total": 2,
			"last_rewarded_level": 3,
			"introduced_feature_ids": after_chopping}},
		{"id": &"open_shop", "state": {
			"cash": 50, "lifetime_cash_earned": 50,
			"xp": level_three_xp, "skill_points_earned_total": 2,
			"last_rewarded_level": 3,
			"completed_orders": ["campfire_warmup"],
			"introduced_feature_ids": after_chopping}},
		{"id": &"shop_reading", "panel": &"shop", "state": {
			"cash": 50, "lifetime_cash_earned": 50,
			"xp": level_three_xp, "skill_points_earned_total": 2,
			"last_rewarded_level": 3,
			"completed_orders": ["campfire_warmup"],
			"introduced_feature_ids": after_chopping}},
		{"id": &"opening_complete", "panel": &"shop", "state": {
			"lifetime_cash_earned": 50,
			"xp": level_three_xp, "skill_points_earned_total": 2,
			"last_rewarded_level": 3,
			"completed_orders": ["campfire_warmup"],
			"building_tiers": {"balanced_axe": 2},
			"introduced_feature_ids": after_chopping}},
		{"id": &"open_catalog", "state": {
			"cash": 1000, "lifetime_cash_earned": 1000, "xp": 1000,
			"building_tiers": {"supplier_ledger": 2},
			"introduced_feature_ids": after_opening}},
		{"id": &"catalog_pick", "panel": &"catalog", "state": {
			"cash": 1000, "lifetime_cash_earned": 1000, "xp": 1000,
			"building_tiers": {"supplier_ledger": 2},
			"introduced_feature_ids": after_opening}},
		{"id": &"orders", "state": {
			"xp": level_three_xp,
			"completed_orders": ["pine_campsite_load"],
			"introduced_feature_ids": after_opening}},
		{"id": &"automation", "state": {
			"building_tiers": {"mechanical_splitter": 2},
			"introduced_feature_ids": after_opening}},
		{"id": &"automation_assign", "panel": &"catalog", "state": {
			"owned_species": ["quaking_aspen"],
			"species_mastery_progress": {"quaking_aspen": 10},
			"building_tiers": {
				"mechanical_splitter": 2,
				"splitter_profile_quaking_aspen": 2,
			},
			"introduced_feature_ids": after_opening}},
		{"id": &"automation_load", "state": {
			"owned_species": ["quaking_aspen"],
			"species_mastery_progress": {"quaking_aspen": 10},
			"building_tiers": {
				"mechanical_splitter": 2,
				"splitter_profile_quaking_aspen": 2,
			},
			"splitter_assigned_species": "quaking_aspen",
			"introduced_feature_ids": after_opening}},
		{"id": &"atlas", "state": {
			"reputation": 4, "introduced_feature_ids": after_opening}},
		{"id": &"atlas_step", "panel": &"atlas", "state": {
			"reputation": 4, "introduced_feature_ids": after_opening}},
		{"id": &"launch", "state": {
			"earth_trees_felled": GameState.TOTAL_EARTH_TREES,
			"earth_finale_state": GameState.EarthFinaleState.COMPLETE,
			"earth_finale_splits": 3, "earth_master": true,
			"introduced_feature_ids": after_opening}},
	]
	var content := load("res://data/tutorial_content.tres") as TutorialTable
	for index in range(specs.size()):
		var spec := specs[index]
		var nodes := await _make_scene(spec.get("state", {}))
		var hud: Control = nodes.hud
		var panel_id := StringName(spec.get("panel", &""))
		if panel_id != &"":
			_open_gallery_panel(hud, panel_id)
			await _frames(2)
		var beat_id := StringName(spec.id)
		var beat := content.beat_by_id(beat_id)
		(hud.tutorial_director() as TutorialDirector).debug_present_beat(beat)
		await _frames(4)
		_save("%02d_%s" % [index + 1, beat_id])
		await _clear_scene(nodes)


func _open_gallery_panel(hud: Control, panel_id: StringName) -> void:
	var path := NodePath()
	match panel_id:
		&"shop": path = ^"QuickMenu/ShopButton"
		&"catalog": path = ^"QuickMenu/TreesButton"
		&"orders": path = ^"QuickMenu/OrdersButton"
		&"skills": path = ^"QuickMenu/SkillsButton"
		&"atlas": path = ^"QuickMenu/AtlasButton"
	var button := hud.get_node_or_null(path) as Button
	if button == null or not button.visible:
		push_error("Tutorial gallery cannot open %s for its capture." % panel_id)
		return
	button.pressed.emit()


func _make_scene(state: Dictionary) -> Dictionary:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	if not state.is_empty():
		GameState.apply_save_dict(state)
	var game: Node3D = load(
		"res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	var hud: Control = load(
		"res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	var runtime := game.get_node("MechanicalSplitterRuntime") \
		as MechanicalSplitterRuntime
	runtime.set_yard_active(true)
	hud.bind_splitter_runtime(runtime)
	await _frames(12)
	return {"game": game, "hud": hud}


func _clear_scene(nodes: Dictionary) -> void:
	(nodes.hud as Control).queue_free()
	(nodes.game as Node3D).queue_free()
	await _frames(4)


func _save(tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + tag + ".png"
	image.save_png(path)
	print("TUTORIAL SHOT %s · %dx%d" % [path, image.get_width(), image.get_height()])


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
