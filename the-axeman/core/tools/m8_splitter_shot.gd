extends Node
## Focused non-headless render QA for M8 Slices 4-5. It drives the real main
## scene, captures fresh/functional/Purchased shop placement, the mastered-tree
## purchase route, then one purchased/assigned splitter and its watched native
## greybox cycle.

const OUT := "/private/tmp/axeman_m8_splitter"
const _BACKUP := "user://the_axeman_save.m8splittershotbackup"


func _ready() -> void:
	_stash_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _i in range(10):
		await get_tree().process_frame
	GameState.reset_to_defaults()
	var hud: Control = main.get_node("UI_Overlay/YardHUD")
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	await get_tree().process_frame
	_save("_shop_fresh")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	var machine := MechanicalSplitter.machine_definition()
	var profiles := MechanicalSplitter.profile_definitions()
	var profile := profiles[0]
	var speed := MechanicalSplitter.upgrade_definition(
		UpgradeDef.Effect.AUTOMATION_SPEED)
	var mastery_progress: Dictionary = {}
	for certified: UpgradeDef in profiles:
		mastery_progress[String(certified.automation_species_id)] = \
			M7CContent.mastery().by_species_id(
				certified.automation_species_id).mastery_target
	GameState.apply_save_dict({
		"building_tiers": {
			String(GameState.UPGRADE_BALANCED_AXE): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_REINFORCED_BLOCK): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_SUPPLIER_LEDGER): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_HANDCART): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_COFFEE_THERMOS): GameState.DEFAULT_BUILDING_TIER + 1,
		},
		"species_mastery_progress": mastery_progress,
	})
	for _i in range(4):
		await get_tree().process_frame
	hud.get_node("QuickMenu/TreesButton").pressed.emit()
	await get_tree().process_frame
	_save("_mastery_route")
	hud.get_node("TreesPanel/Column/CloseButton").pressed.emit()

	GameState.apply_save_dict({
		"building_tiers": {
			String(GameState.UPGRADE_BALANCED_AXE): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_REINFORCED_BLOCK): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_SUPPLIER_LEDGER): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_HANDCART): GameState.DEFAULT_BUILDING_TIER + 1,
			String(GameState.UPGRADE_COFFEE_THERMOS): GameState.DEFAULT_BUILDING_TIER + 1,
			String(machine.id): GameState.DEFAULT_BUILDING_TIER + 1,
			String(profile.id): GameState.DEFAULT_BUILDING_TIER + 1,
			String(speed.id): GameState.DEFAULT_BUILDING_TIER + 1,
		},
		"species_mastery_progress": mastery_progress,
		"splitter_assigned_species": String(profile.automation_species_id),
	})
	for _i in range(4):
		await get_tree().process_frame
	_save("_ready")

	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 1
	await get_tree().process_frame
	var splitter_scroll: ScrollContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Splitter/Scroll")
	splitter_scroll.scroll_vertical = int(splitter_scroll.get_v_scroll_bar().max_value)
	await get_tree().process_frame
	_save("_upgrades")
	hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 2
	await get_tree().process_frame
	var purchased_scroll: ScrollContainer = hud.get_node(
		"ShopPanel/Column/ShopTabs/Purchased/Scroll")
	purchased_scroll.scroll_vertical = int(purchased_scroll.get_v_scroll_bar().max_value)
	await get_tree().process_frame
	_save("_purchased")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()
	hud.get_node("SplitterRuntimeCard/Column/Action").pressed.emit()
	var runtime: MechanicalSplitterRuntime = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame/MechanicalSplitterRuntime")
	runtime._process(runtime.config.processing_duration_seconds * 0.55)
	await get_tree().process_frame
	_save("_processing")

	runtime._process(runtime.config.processing_duration_seconds)
	await get_tree().process_frame
	_save("_completed")

	main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()


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
