extends Node
## FILE: res://core/tools/hud_shot.gd
## ATTACHES TO: root Node of res://core/tools/hud_shot.tscn. DEV TOOL, not shipped.
##
## RUN NON-HEADLESS (F6, or with the scene path and no --headless): it renders the
## real main.tscn — chopping HUD, panels, stockpile and haul-away — to PNGs in user://,
## because every numeric check in this project can be green on a UI that is
## off-screen, unreadably small, or covering the chopping block. This is the
## shot_runner pattern applied to the 2D side.
##
## It drives the REAL scene and the REAL signals: firewood arrives via A7
## resource_gathered exactly as the mini-game deposits it, panels open through
## the HUD's own icon buttons, and the haul-away is the production one.
##
## SAFETY: main.tscn autosaves, so this moves any existing save aside for the run
## and puts it back afterwards. A dev screenshot must not be able to overwrite
## Sam's yard with test firewood.

const OUT := "user://hud_shot"
const _BACKUP := "user://the_axeman_save.shotbackup"


func _ready() -> void:
	_stash_save()

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in range(10):
		await get_tree().process_frame

	var hud: Control = main.get_node("UI_Overlay/YardHUD")
	var mg: Node3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")

	# A chopping session part way through a working day: cash earned, wood chopped,
	# the compact action dock visible, the XP strip half full, and a load
	# stacked. The pile pieces go in the way the game adds them, one at a time.
	GameState.add_cash(370)
	GameState.add_xp(20)
	for i in range(26):
		EventBus.resource_gathered.emit(&"birch_firewood", 1)
		GameState.add_to_yard_pile(&"birch_firewood", 1)
	for i in range(14):
		EventBus.resource_gathered.emit(&"oak_firewood", 1)
		GameState.add_to_yard_pile(&"oak_firewood", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_save("_1_chopping")

	# The shop: Sam's coin on the button and on the counter.
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	await get_tree().process_frame
	_save("_2_shop")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	# The woodshed, mid-ladder: several woods earned, one still to come. The 40
	# gathers above have already unlocked the first few rungs, so this is the real
	# list rather than a staged one — the thing worth looking at is whether an
	# earned wood, the wood on the block and the next milestone are all
	# distinguishable at a glance.
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	hud.get_node("ShopPanel/Column/ShopTabs").current_tab = 1
	await get_tree().process_frame
	_save("_2b_woodshed")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	# Fresh three-bough state: every branch is present, and selecting Ready Stance
	# explains its prerequisite rather than hiding it.
	hud.get_node("QuickMenu/SkillsButton").pressed.emit()
	hud.debug_select_skill(&"ready_stance")
	await get_tree().process_frame
	_save("_2c_skills_fresh")
	hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()

	# Part way up: learned foundations, points in hand and a selected Technique
	# proc make branch identity, selection and affordability visible together.
	GameState.add_xp(30000)
	SkillTree.buy(&"quick_hands")
	SkillTree.buy(&"strong_arms")
	hud.get_node("QuickMenu/SkillsButton").pressed.emit()
	hud.debug_select_skill(&"quick_study")
	await get_tree().process_frame
	_save("_2c_skills")
	hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()

	# A real v1 fixture after migration: retained ranks stay learned and retired
	# spend returns through the derived point balance. Restore the working-day
	# state immediately after the shot so later pile/haul images remain honest.
	var before_migration_shot := GameState.to_save_dict()
	var fixture := ConfigFile.new()
	if fixture.load("res://core/tests/fixtures/m7c_v1_all_skill_mappings.cfg") == OK:
		var fixture_data: Variant = fixture.get_value("progression", "data", {})
		if fixture_data is Dictionary:
			GameState.apply_save_dict(SaveSystem._migrate(fixture_data as Dictionary, 1))
			hud.get_node("QuickMenu/SkillsButton").pressed.emit()
			hud.debug_select_skill(&"ready_stance")
			await get_tree().process_frame
			_save("_2c_skills_migration_refund")
			hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()
	GameState.apply_save_dict(before_migration_shot)
	await get_tree().process_frame

	# The contract board uses temporary native geometry/materials until Sam's yard
	# art arrives. Show both the three authored cards and live progress on one.
	GameState.accept_order(&"aspen_hearth_load")
	for i in range(6):
		EventBus.resource_gathered.emit(&"aspen_firewood", 1)
		Orders.settle_piece(&"aspen_firewood")
	hud.get_node("QuickMenu/OrdersButton").pressed.emit()
	await get_tree().process_frame
	_save("_2d_orders")
	hud.get_node("OrdersPanel/Column/CloseButton").pressed.emit()

	# The load is full and leaves the yard. This is the production haul, caught
	# mid-flight — the point of the shot is that the wood is IN THE AIR and on its
	# way off screen, which no counter can tell us.
	mg._haul_away()
	for i in range(12):
		await get_tree().process_frame
	_save("_4_hauling")
	for i in range(60):
		await get_tree().process_frame
	_save("_5_hauled")

	main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)


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
