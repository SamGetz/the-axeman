extends Node
## Focused non-headless proof that proc billboards composite cleanly through the
## production painterly grade. It never starts a session or touches the save.

const OUT := "/private/tmp/axeman_painterly_vfx_"


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _frame in range(4):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	main.get_node("UI_Overlay/YardHUD").show()
	main.call("_enter_3d_mode")
	for _frame in range(12):
		await get_tree().process_frame

	var world: Node3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/"
		+ "Chopping_Minigame")
	var grade: CanvasLayer = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/PainterlyColorGrade")

	grade.hide()
	ProcBurst.spawn(world, Vector3(0.0, 0.86, 0.0),
		Color(0.82, 0.29, 0.20), &"strength")
	await _wait_ms(130)
	_save("off")

	await _wait_ms(900)
	grade.show()
	ProcBurst.spawn(world, Vector3(0.0, 0.86, 0.0),
		Color(0.82, 0.29, 0.20), &"strength")
	await _wait_ms(130)
	_save("proc_on")

	await _wait_ms(900)
	var level_up := LevelUpBurst.create_prewarmed(world, 0.46)
	level_up.play_at(Vector3(0.0, 0.66, 0.0))
	await _wait_ms(380)
	_save("level_on")
	get_tree().quit()


func _wait_ms(ms: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < ms:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(label: String) -> void:
	var path := OUT + label + ".png"
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("painterly_vfx_shot: %s (%s)" % [path, error_string(error)])
