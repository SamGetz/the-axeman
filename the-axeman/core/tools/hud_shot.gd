extends Node
## FILE: res://core/tools/hud_shot.gd
## ATTACHES TO: root Node of res://core/tools/hud_shot.tscn. DEV TOOL, not shipped.
##
## RUN NON-HEADLESS (F6, or with the scene path and no --headless): it renders the
## real main.tscn — yard HUD and all — to PNGs in user://, because every numeric
## check in this project can be green on a UI that is off-screen, unreadably
## small, or covering the chopping block. This is the shot_runner pattern applied
## to the 2D side.
##
## It drives the REAL scene and the REAL signals: firewood arrives via A7
## resource_gathered exactly as the mini-game deposits it, and the mode change
## comes from pressing the HUD's own button.
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

	# One finished birch log and a couple of oak pieces, deposited one at a time.
	for i in range(6):
		EventBus.resource_gathered.emit(&"birch_firewood", 1)
	for i in range(3):
		EventBus.resource_gathered.emit(&"oak_firewood", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_save("_1_yard")

	# Into the chopping game through the button the player uses.
	hud.get_node("YardPanel/Column/ChopButton").pressed.emit()
	for i in range(30):
		await get_tree().process_frame
	_save("_2_chopping")

	# A yard that has been worked for a while: stock arriving the way a LOAD
	# delivers it, so the pile has to be rebuilt from the counts alone.
	InventoryManager.apply_save_dict({"birch_firewood": 40, "oak_firewood": 25})
	for i in range(20):
		await get_tree().process_frame
	_save("_3_stockpile")

	# Back out and sell the lot: the wood leaves the yard, so it leaves the pile.
	hud.get_node("BackButton").pressed.emit()
	await get_tree().process_frame
	hud.get_node("YardPanel/Column/SellAllButton").pressed.emit()
	await get_tree().process_frame
	hud.get_node("YardPanel/Column/ChopButton").pressed.emit()
	for i in range(10):
		await get_tree().process_frame
	_save("_4_sold_out")

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
