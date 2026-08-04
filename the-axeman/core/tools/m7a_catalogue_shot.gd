extends Node
## Render QA for the approved M7A catalogue. Run NON-HEADLESS. This drives the
## real main scene and uses the same persisted tier events as a purchase, while
## safely stashing/restoring the real save. Output goes to /private/tmp.

const OUT := "/private/tmp/axeman_m7a_catalogue"
const _BACKUP := "user://the_axeman_save.catalogueshotbackup"


func _ready() -> void:
	_stash_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in range(10):
		await get_tree().process_frame
	GameState.reset_to_defaults()

	var hud: Control = main.get_node("UI_Overlay/YardHUD")
	var game: Node3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	await get_tree().process_frame
	_save("_1_fresh_shop")
	hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 1
	await get_tree().process_frame
	_save("_1b_tree_catalogue")
	hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 0
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	var first := Orders.by_id(&"campfire_warmup")
	GameState.accept_order(first.id)
	for _i in range(first.required_count):
		GameState.record_order_piece(&"aspen_firewood")
	GameState.record_haul_away()
	GameState.add_xp(GameState.get_xp_to_next_level())
	var aspen := Orders.by_id(&"aspen_hearth_load")
	GameState.accept_order(aspen.id)
	for _i in range(aspen.required_count):
		GameState.record_order_piece(&"aspen_firewood")
	for def: UpgradeDef in Shop.get_upgrades():
		EventBus.building_upgraded.emit(def.id, GameState.DEFAULT_BUILDING_TIER + 1)
	await get_tree().process_frame
	await get_tree().process_frame
	game._swing_axe()
	for _i in range(8):
		await get_tree().process_frame
	_save("_2_balanced_axe")
	await get_tree().create_timer(1.2).timeout
	_save("_2_all_owned_yard")

	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	await get_tree().process_frame
	_save("_3_all_owned_shop")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	game._stage_next_log()
	game._spawn_fresh_log(false)
	await get_tree().create_timer(0.18).timeout
	_save("_4_log_hop_smoke")

	main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()


func _save(tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUT + tag + ".png")
	print("SHOT saved: " + OUT + tag + ".png")


func _stash_save() -> void:
	if not FileAccess.file_exists(SaveSystem.SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP)


func _restore_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.remove(SaveSystem.SAVE_PATH)
	if FileAccess.file_exists(_BACKUP):
		dir.rename(_BACKUP, SaveSystem.SAVE_PATH)
