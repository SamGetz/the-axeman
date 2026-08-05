extends Node
## Focused acceptance for the explicit New Game / Load Game boot boundary.
## The suite uses the production main scene and real save path, while stashing
## and restoring any player save around the run.

const _BACKUP_PATH := "user://the_axeman_save.startup_testbackup"

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== STARTUP ACCEPTANCE — explicit New Game / Load Game ===")
	_stash_real_save()
	await _test_fresh_boot_and_new_game()
	await _test_load_is_explicit()
	await _test_existing_save_requires_new_game_confirmation()
	await _test_corrupt_save_stays_at_menu()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== STARTUP RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL STARTUP ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_fresh_boot_and_new_game() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var main := _spawn_main()
	await get_tree().process_frame
	var menu: Control = main.get_node("StartupOverlay/StartupMenu")
	var load_button: Button = menu.get_node(
		"Center/Panel/Margin/Column/LoadGameButton")
	var viewport: SubViewport = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport")
	_check(menu.visible and not main.has_started_session(),
		"a fresh boot waits at the startup menu")
	_check(load_button.disabled,
		"Load Game is disabled when no save exists")
	_check(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"the yard neither renders nor advances before a choice")
	GameState.add_cash(73)
	await get_tree().process_frame
	_check(not SaveSystem.has_save(),
		"menu-time state cannot autosave over an unchosen yard")
	var new_button: Button = menu.get_node(
		"Center/Panel/Margin/Column/NewGameButton")
	new_button.pressed.emit()
	await get_tree().process_frame
	_check(main.has_started_session() and not menu.visible,
		"New Game dismisses the menu and starts the session")
	_check(GameState.get_cash() == GameState.DEFAULT_CASH
			and InventoryManager.to_save_dict().is_empty(),
		"New Game resets progression and inventory to authored defaults")
	_check(SaveSystem.has_save()
			and viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"the fresh yard is saved before gameplay becomes active")
	await _free_main(main)


func _test_load_is_explicit() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	GameState.add_cash(4321)
	InventoryManager.add_item(&"aspen_firewood", 3)
	var expected_cash := GameState.get_cash()
	_check(SaveSystem.save_game(), "load fixture writes through the real save service")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var main := _spawn_main()
	await get_tree().process_frame
	var menu: Control = main.get_node("StartupOverlay/StartupMenu")
	var load_button: Button = menu.get_node(
		"Center/Panel/Margin/Column/LoadGameButton")
	_check(not load_button.disabled and GameState.get_cash() == GameState.DEFAULT_CASH,
		"boot discovers a save without loading it before player input")
	load_button.pressed.emit()
	await get_tree().process_frame
	_check(main.has_started_session() and not menu.visible,
		"Load Game dismisses the menu only after a successful restore")
	_check(GameState.get_cash() == expected_cash
			and InventoryManager.get_count(&"aspen_firewood") == 3,
		"Load Game restores progression and inventory together")
	await _free_main(main)


func _test_existing_save_requires_new_game_confirmation() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	GameState.add_cash(2222)
	_check(SaveSystem.save_game(), "replacement fixture writes successfully")
	GameState.reset_to_defaults()
	var main := _spawn_main()
	await get_tree().process_frame
	var menu: Control = main.get_node("StartupOverlay/StartupMenu")
	var new_button: Button = menu.get_node(
		"Center/Panel/Margin/Column/NewGameButton")
	var confirmation: ConfirmationDialog = menu.get_node("NewGameConfirmation")
	new_button.pressed.emit()
	await get_tree().process_frame
	_check(confirmation.visible and not main.has_started_session(),
		"New Game asks before replacing an existing autosave")
	confirmation.confirmed.emit()
	await get_tree().process_frame
	_check(main.has_started_session() and GameState.get_cash() == GameState.DEFAULT_CASH,
		"confirming New Game starts from authored defaults")
	GameState.add_cash(1)
	await get_tree().process_frame
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK
			and GameState.get_cash() == GameState.DEFAULT_CASH + 1,
		"the confirmed fresh yard becomes the autosave authority")
	await _free_main(main)


func _test_corrupt_save_stays_at_menu() -> void:
	SaveSystem.delete_save()
	var file := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("this is not a ConfigFile")
		file.close()
	var main := _spawn_main()
	await get_tree().process_frame
	var menu: Control = main.get_node("StartupOverlay/StartupMenu")
	var load_button: Button = menu.get_node(
		"Center/Panel/Margin/Column/LoadGameButton")
	load_button.pressed.emit()
	await get_tree().process_frame
	var status: Label = menu.get_node("Center/Panel/Margin/Column/StatusLabel")
	_check(menu.visible and not main.has_started_session(),
		"an unreadable save never falls through into a fresh session")
	_check(SaveSystem.has_save() and status.text.contains("not overwritten"),
		"the corrupt save stays on disk and the player gets a clear error")
	await _free_main(main)
	SaveSystem.delete_save()


func _spawn_main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	return main


func _free_main(main: Node) -> void:
	main.queue_free()
	await get_tree().process_frame


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
