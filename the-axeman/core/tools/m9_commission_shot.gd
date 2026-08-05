extends Node
## Non-headless 1280x720 visual QA for M9 Slice 1. Drives the production yard
## and native HUD through the earned, active, completed and repeat-play states.

const OUT := "/private/tmp/axeman_m9_commission"
const _BACKUP := "user://the_axeman_save.m9commissionshotbackup"

var _main: Node
var _hud: Control


func _ready() -> void:
	_stash_save()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_main.start_new_game()
	await _frames(10)
	_hud = _main.get_node("UI_Overlay/YardHUD")

	GameState.apply_save_dict({
		"cash": 1200,
		"xp": _xp_for_level(9),
		"owned_species": [
			String(SpeciesTable.at(1).id),
			String(SpeciesTable.at(2).id),
		],
		"completed_orders": [String(Orders.COMMISSION_UNLOCK_ORDER_ID)],
	})
	GameState.ensure_commission_offers()
	await _open_commissions()
	_save("_earned_offers")

	var offers := GameState.get_commission_offers()
	var active_offer: Dictionary = offers[1]
	GameState.accept_order(&"campfire_warmup")
	GameState.accept_commission(StringName(offers[0].get("id", &"")))
	GameState.accept_commission(StringName(active_offer.get("id", &"")))
	_hud._close_panels()
	await _frames()
	_save("_active_tasks_collapsed")
	_hud.get_node("ActiveJobChip/Column/Header/Toggle").pressed.emit()
	await _frames()
	_save("_active_tasks_expanded")

	await _open_commissions()
	_save("_active_board")

	var required_item := StringName(active_offer.get("required_item", &""))
	for _i in range(int(active_offer.get("required_count", 0))):
		InventoryManager.add_item(required_item, 1)
		Orders.settle_piece(required_item)
	await _frames()
	_save("_delivered_refresh")

	await get_tree().create_timer(3.2).timeout
	var tabs: TabContainer = _hud.get_node("OrdersPanel/Column/Tabs")
	tabs.current_tab = 2
	await _frames()
	_save("_repeat_history")

	_main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()


func _open_commissions() -> void:
	_hud._close_panels()
	_hud.get_node("QuickMenu/OrdersButton").pressed.emit()
	var tabs: TabContainer = _hud.get_node("OrdersPanel/Column/Tabs")
	tabs.current_tab = 1
	await _frames()


func _xp_for_level(level: int) -> int:
	var xp := 0
	while GameState.get_level_for_xp(xp) < level:
		xp += GameState.get_xp_to_next_level_for_xp(xp)
	return xp


func _frames(count := 4) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _save(tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + tag + ".png"
	var error := image.save_png(path)
	print("m9_commission_shot: %s (%s)" % [path, error_string(error)])


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
