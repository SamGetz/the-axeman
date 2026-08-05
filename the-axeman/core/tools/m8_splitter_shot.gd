extends Node
## Non-headless 1280x720 render QA for M8 Slice 6. Drives production Main/HUD,
## immutable catalogue data and ephemeral runtime seams without touching tuning.

const OUT := "/private/tmp/axeman_m8_splitter"
const _BACKUP := "user://the_axeman_save.m8splittershotbackup"

var _main: Node
var _hud: Control
var _game: Node3D
var _runtime: MechanicalSplitterRuntime


func _ready() -> void:
	_stash_save()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_main.start_new_game()
	await _frames(10)
	_hud = _main.get_node("UI_Overlay/YardHUD")
	_game = _main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	_runtime = _game.get_node("MechanicalSplitterRuntime")

	await _capture_contract_chapter()
	await _capture_later_profile_gates()
	await _capture_species_and_runtime()

	_main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()


func _capture_contract_chapter() -> void:
	_apply_state(8, [0, 1, 2], [], [], _base_tiers())
	await _frames()
	_save("_next_contract_level8")

	var mixed := _state(9, [0, 1, 2], [0, 1], [], _base_tiers())
	mixed["active_order"] = String(Orders.all()[2].id)
	mixed["active_order_progress"] = 8
	GameState.apply_save_dict(mixed)
	await _open_orders(0)
	_save("_orders_open_mixed")
	var open_scroll: ScrollContainer = _hud.get_node("OrdersPanel/Column/Tabs/Open/Scroll")
	open_scroll.scroll_vertical = int(open_scroll.get_v_scroll_bar().max_value)
	await _frames()
	_save("_orders_open_mixed_requirements")

	_apply_state(9, [0, 1, 2, 3], [0, 1, 2], [], _base_tiers())
	await _open_orders(2)
	_save("_orders_completed_early")

	_apply_state(49, _indices(14), _indices(14), [], _base_tiers())
	await _open_orders(2, true)
	_save("_orders_completed_middle")

	_apply_state(99, _indices(25), _indices(26), _indices(25), _base_tiers())
	await _open_orders(2, true)
	_save("_orders_completed_level99")
	_hud._close_panels()


func _capture_later_profile_gates() -> void:
	var profiles := MechanicalSplitter.profile_definitions()
	var profile: UpgradeDef = profiles[12]
	var machine := MechanicalSplitter.machine_definition()
	var mastered := [0, 1, 2, 12]
	var completed_target := [Orders.all().find(Orders.by_id(profile.unlock_order_id))]
	var machine_tiers := _base_tiers()
	machine_tiers[String(machine.id)] = GameState.DEFAULT_BUILDING_TIER + 1

	_apply_state(99, [0, 1, 2, 12], [], mastered, machine_tiers)
	await _open_splitter_shop(true)
	_save("_profile_gate_missing_contract")

	_apply_state(99, [0, 1, 2, 12], completed_target, [0, 1, 2], machine_tiers)
	await _open_splitter_shop(true)
	_save("_profile_gate_missing_mastery")

	_apply_state(99, [0, 1, 2, 12], completed_target, mastered, _base_tiers())
	await _open_splitter_shop(true)
	_save("_profile_gate_missing_machine")

	_apply_state(99, [0, 1, 2, 12], completed_target, mastered, machine_tiers)
	await _open_splitter_shop(true)
	_save("_profile_actionable")

	var purchased_tiers := machine_tiers.duplicate()
	purchased_tiers[String(profile.id)] = GameState.DEFAULT_BUILDING_TIER + 1
	_apply_state(99, [0, 1, 2, 12], completed_target, mastered, purchased_tiers)
	_hud._close_panels()
	_hud.get_node("QuickMenu/ShopButton").pressed.emit()
	_hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 2
	await _frames()
	var purchased_scroll: ScrollContainer = _hud.get_node(
		"ShopPanel/Column/ShopTabs/Purchased/Scroll")
	purchased_scroll.scroll_vertical = int(purchased_scroll.get_v_scroll_bar().max_value)
	await _frames()
	_save("_profile_purchased")

	_hud._close_panels()
	_hud.get_node("QuickMenu/TreesButton").pressed.emit()
	await _frames()
	var tree_scroll: ScrollContainer = _hud.get_node("TreesPanel/Column/WoodScroll")
	tree_scroll.scroll_vertical = int(tree_scroll.get_v_scroll_bar().max_value)
	await _frames()
	_save("_profile_assignable")
	var assign := _find_button(_hud.get_node("TreesPanel"), "Assign to splitter")
	if assign != null:
		assign.pressed.emit()
	await _frames()
	_save("_profile_assigned")
	_hud._close_panels()


func _capture_species_and_runtime() -> void:
	var profiles := MechanicalSplitter.profile_definitions()
	for index in [0, 12, 24]:
		var profile: UpgradeDef = profiles[index]
		var tiers := _base_tiers()
		tiers[String(MechanicalSplitter.machine_definition().id)] = \
			GameState.DEFAULT_BUILDING_TIER + 1
		tiers[String(profile.id)] = GameState.DEFAULT_BUILDING_TIER + 1
		var completed: Array[int] = []
		if profile.unlock_order_id != &"":
			completed.append(Orders.all().find(Orders.by_id(profile.unlock_order_id)))
		_apply_state(99, [0, index], completed, [index], tiers, profile.automation_species_id)
		await _frames(4)
		_save("_species_%02d_ready" % index)

	var final_profile: UpgradeDef = profiles[24]
	var all_tiers := _base_tiers()
	all_tiers[String(MechanicalSplitter.machine_definition().id)] = \
		GameState.DEFAULT_BUILDING_TIER + 1
	all_tiers[String(final_profile.id)] = GameState.DEFAULT_BUILDING_TIER + 1
	for upgrade: UpgradeDef in MechanicalSplitter.upgrade_definitions():
		all_tiers[String(upgrade.id)] = GameState.DEFAULT_BUILDING_TIER + upgrade.max_level
	var final_order_index := Orders.all().find(Orders.by_id(final_profile.unlock_order_id))
	_apply_state(99, [0, 24], [final_order_index], [24], all_tiers,
		final_profile.automation_species_id)
	await _frames(4)
	_runtime.set_yard_active(true)
	_runtime._process(0.001)
	_runtime._process(_runtime.effective_duration_seconds() * 0.5)
	await _frames()
	_save("_runtime_processing_max_speed")

	_runtime._process(_runtime.effective_duration_seconds())
	await get_tree().process_frame
	_save("_runtime_settlement_receipts")
	await get_tree().create_timer(1.8).timeout
	_save("_runtime_completed_reconciled")

	_runtime._pending_output = {
		"receipt_id": &"shot_blocked_output",
		"species_id": final_profile.automation_species_id,
		"item_id": &"invented_firewood",
		"amount": 1,
		"logs": 12,
		"inventory_deposited": false,
	}
	_runtime._publish_state(true)
	await _frames()
	_save("_runtime_blocked_output")
	_runtime.retry_blocked_output()
	await _frames()
	_save("_runtime_blocked_retry_cancelled")

	# Presentation-only overlap shot: the splitter uses its dedicated pools while
	# the already-prewarmed manual pools stage an independent chop receipt.
	_runtime._pending_output = {}
	_runtime._publish_state(true)
	_runtime._process(0.001)
	_runtime._process(_runtime.effective_duration_seconds())
	var manual_pool: CoinRewardPool = _game.get_node("CoinRewardPool")
	var manual_origin := Vector3(0.26, 0.96, 0.08)
	manual_pool.begin_burst(manual_origin, 4, 0.025, 0.2, 0.62, 0.035)
	GameState.add_cash(64)
	for _i in range(4):
		manual_pool.queue_payout(16)
	GameState.add_xp(40)
	_game._burst_xp_orbs(40, manual_origin)
	await get_tree().create_timer(0.22).timeout
	_save("_runtime_and_manual_receipts_overlap")


func _apply_state(level: int, owned_indices: Array, completed_indices: Array,
		mastered_indices: Array, tiers: Dictionary,
		assignment: StringName = &"") -> void:
	GameState.apply_save_dict(_state(level, owned_indices, completed_indices,
		mastered_indices, tiers, assignment))


func _state(level: int, owned_indices: Array, completed_indices: Array,
		mastered_indices: Array, tiers: Dictionary,
		assignment: StringName = &"") -> Dictionary:
	var owned: Array[String] = []
	for index: int in owned_indices:
		var species := SpeciesTable.at(index)
		if species != null and not owned.has(String(species.id)):
			owned.append(String(species.id))
	var completed: Array[String] = []
	var orders := Orders.all()
	for index: int in completed_indices:
		if index >= 0 and index < orders.size() and not completed.has(String(orders[index].id)):
			completed.append(String(orders[index].id))
	var mastery: Dictionary = {}
	for index: int in mastered_indices:
		var species := SpeciesTable.at(index)
		var definition := M7CContent.mastery().by_species_id(species.id) if species != null else null
		if definition != null:
			mastery[String(species.id)] = definition.mastery_target
	return {
		"cash": 500000000,
		"xp": _xp_for_level(level),
		"owned_species": owned,
		"completed_orders": completed,
		"species_mastery_progress": mastery,
		"building_tiers": tiers,
		"splitter_assigned_species": String(assignment),
	}


func _base_tiers() -> Dictionary:
	return {
		String(GameState.UPGRADE_BALANCED_AXE): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_REINFORCED_BLOCK): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_SUPPLIER_LEDGER): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_HANDCART): GameState.DEFAULT_BUILDING_TIER + 1,
		String(GameState.UPGRADE_COFFEE_THERMOS): GameState.DEFAULT_BUILDING_TIER + 1,
	}


func _xp_for_level(level: int) -> int:
	var xp := 0
	while GameState.get_level_for_xp(xp) < level:
		xp += GameState.get_xp_to_next_level_for_xp(xp)
	return xp


func _indices(count: int) -> Array[int]:
	var out: Array[int] = []
	for index in range(count):
		out.append(index)
	return out


func _open_orders(tab: int, scroll_to_end := false) -> void:
	_hud._close_panels()
	_hud.get_node("QuickMenu/OrdersButton").pressed.emit()
	var tabs: TabContainer = _hud.get_node("OrdersPanel/Column/Tabs")
	tabs.current_tab = tab
	await _frames()
	if scroll_to_end:
		var scroll: ScrollContainer = _hud.get_node(
			"OrdersPanel/Column/Tabs/Completed/Scroll")
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames()


func _open_splitter_shop(scroll_to_end := false) -> void:
	_hud._close_panels()
	_hud.get_node("QuickMenu/ShopButton").pressed.emit()
	_hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 1
	await _frames()
	if scroll_to_end:
		var scroll: ScrollContainer = _hud.get_node(
			"ShopPanel/Column/ShopTabs/Splitter/Scroll")
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await _frames()


func _find_button(root: Node, wanted: String) -> Button:
	if root is Button and (root as Button).text == wanted:
		return root as Button
	for child: Node in root.get_children():
		var found := _find_button(child, wanted)
		if found != null:
			return found
	return null


func _frames(count := 3) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _save(tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + tag + ".png"
	image.save_png(path)
	print("SHOT saved: " + path)


func _stash_save() -> void:
	if not FileAccess.file_exists(SaveSystem.SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		if dir.file_exists(_BACKUP):
			dir.remove(_BACKUP)
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP)


func _restore_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.remove(SaveSystem.SAVE_PATH)
	if FileAccess.file_exists(_BACKUP):
		dir.rename(_BACKUP, SaveSystem.SAVE_PATH)
