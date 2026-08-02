extends Node
## FILE: res://core/tools/hud_shot.gd
## ATTACHES TO: root Node of res://core/tools/hud_shot.tscn. DEV TOOL, not shipped.
##
## RUN NON-HEADLESS (F6, or with the scene path and no --headless): it renders the
## real main.tscn — yard HUD, shop, stockpile and haul-away — to PNGs in user://,
## because every numeric check in this project can be green on a UI that is
## off-screen, unreadably small, or covering the chopping block. This is the
## shot_runner pattern applied to the 2D side.
##
## It drives the REAL scene and the REAL signals: firewood arrives via A7
## resource_gathered exactly as the mini-game deposits it, the mode change comes
## from pressing the HUD's own button, and the haul-away is the production one.
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

	# A yard part way through a working day: cash earned, wood chopped, and a load
	# stacked. The pile pieces go in the way the game adds them, one at a time.
	GameState.add_cash(370)
	for i in range(26):
		EventBus.resource_gathered.emit(&"birch_firewood", 1)
		GameState.add_to_yard_pile(&"birch_firewood", 1)
	for i in range(14):
		EventBus.resource_gathered.emit(&"oak_firewood", 1)
		GameState.add_to_yard_pile(&"oak_firewood", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_save("_1_yard")

	# The shop: Sam's coin on the button and on the counter.
	hud.get_node("YardPanel/Column/ShopButton").pressed.emit()
	await get_tree().process_frame
	_save("_2_shop")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	# The woodshed, mid-ladder: several woods earned, one still to come. The 40
	# gathers above have already unlocked the first few rungs, so this is the real
	# list rather than a staged one — the thing worth looking at is whether an
	# earned wood, the wood on the block and the next milestone are all
	# distinguishable at a glance.
	hud.get_node("YardPanel/Column/WoodButton").pressed.emit()
	await get_tree().process_frame
	_save("_2b_woodshed")
	hud.get_node("WoodPanel/Column/CloseWoodButton").pressed.emit()

	# The skill tree, part way up: enough levels to have points in hand and to
	# have opened a second rank, so the indent, the "Needs X" rows and the
	# affordable rows are all on screen at once.
	GameState.add_xp(30000)
	SkillTree.buy(&"quick_hands")
	SkillTree.buy(&"strong_arms")
	hud.get_node("YardPanel/Column/SkillsButton").pressed.emit()
	await get_tree().process_frame
	_save("_2c_skills")
	hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()

	# Into the chopping game through the button the player uses.
	hud.get_node("YardPanel/Column/ChopButton").pressed.emit()
	for i in range(30):
		await get_tree().process_frame
	_save("_3_chopping")

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
