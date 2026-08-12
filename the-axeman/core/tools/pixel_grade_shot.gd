extends Node
## Focused non-headless comparison for the 3D-only smooth painterly grade. It
## does not start a session, mutate progression, or touch the player's save.
## Output: /private/tmp/axeman_painterly_grade_{off,on}.png.

const OUT := "/private/tmp/axeman_painterly_grade"


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)

	# Let Main's covered render warm-up finish before presenting the yard without
	# crossing its save/autosave startup boundary.
	for _frame in range(4):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	main.get_node("UI_Overlay/YardHUD").show()
	main.call("_enter_3d_mode")

	var grade: CanvasLayer = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/PainterlyColorGrade")
	grade.hide()
	for _frame in range(12):
		await get_tree().process_frame
	_save("_off")

	grade.show()
	for _frame in range(4):
		await get_tree().process_frame
	_save("_on")
	get_tree().quit()


func _save(suffix: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + suffix + ".png"
	var error := image.save_png(path)
	print("painterly_grade_shot: %s (%s)" % [path, error_string(error)])
