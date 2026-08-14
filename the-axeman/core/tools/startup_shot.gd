extends Node
## Focused non-headless visual QA for the native startup stand-in. It renders
## the menu in the saved-yard state and its destructive-action confirmation
## without touching the real save file.

const OUT := "/private/tmp/axeman_startup"


func _ready() -> void:
	var menu: StartupMenu = load(
		"res://scenes/2d_management/startup_menu.tscn").instantiate()
	add_child(menu)
	menu.configure(true, true)
	for _i in range(4):
		await get_tree().process_frame
	_save("_suspended_attempt")
	menu.configure(true, false)
	for _i in range(2):
		await get_tree().process_frame
	_save("_profile_menu")
	var new_button: Button = menu.get_node(
		"Center/Panel/Margin/Column/NewGameButton")
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
