extends Node
## Focused non-headless visual QA for the native startup stand-in. It renders
## the menu in the saved-yard state and its destructive-action confirmation
## without touching the real save file.

const OUT := "/private/tmp/campfire_survivors_startup"


func _ready() -> void:
	var menu: StartupMenu = load(
		"res://scenes/2d_management/startup_menu.tscn").instantiate()
	add_child(menu)
	menu.configure(false, false)
	for _i in range(4):
		await get_tree().process_frame
	_save("_new_camp")
	menu.configure(true, false)
	for _i in range(2):
		await get_tree().process_frame
	_save("_profile_menu")
	var start_button := menu.find_child("YardTabButton", true, false) as Button
	start_button.pressed.emit()
	for _i in range(3):
		await get_tree().process_frame
	_save("_level_select")
	var back_button := menu.find_child("BackButton", true, false) as Button
	back_button.pressed.emit()
	var power_up_button := menu.find_child(
		"UpgradesTabButton", true, false) as Button
	power_up_button.pressed.emit()
	for _i in range(3):
		await get_tree().process_frame
	_save("_power_up")
	back_button.pressed.emit()
	menu.configure(true, true)
	for _i in range(4):
		await get_tree().process_frame
	_save("_suspended_attempt")
	menu.configure(true, false)
	for _i in range(2):
		await get_tree().process_frame
	var new_button := menu.find_child("NewProfileButton", true, false) as Button
	new_button.pressed.emit()
	for _i in range(4):
		await get_tree().process_frame
	_save("_confirmation")
	get_tree().quit()


func _save(suffix: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + suffix + ".png"
	var error := image.save_png(path)
	print("startup_shot: %s (%s)" % [path, error_string(error)])
