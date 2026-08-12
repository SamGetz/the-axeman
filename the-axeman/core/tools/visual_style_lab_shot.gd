extends Node
## Renders four non-production visual directions against one frozen yard frame.
## It never starts a session or touches the player's save. Candidate values live
## in the explicitly labelled prototype shader/material resources.

const OUT := "/private/tmp/axeman_style_"
const STYLES := [
	[1, "1_chunky_pixels"],
	[2, "2_autumn_storybook"],
	[3, "3_woodcut_print"],
	[4, "4_miniature_diorama"],
]


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

	# Freeze gameplay so every candidate grades the same composition. The
	# Action_Viewport continues rendering while its 3D nodes stop advancing.
	main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"
	).process_mode = Node.PROCESS_MODE_DISABLED

	var effect: ColorRect = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/PixelColorGrade/ColorClampAndDither")
	var material: ShaderMaterial = load(
		"res://assets/shaders/visual_style_lab_placeholder.tres").duplicate()
	effect.material = material

	for candidate: Array in STYLES:
		material.set_shader_parameter("style_mode", candidate[0])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(String(candidate[1]))
	get_tree().quit()


func _save(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + label + ".png"
	var error := image.save_png(path)
	print("visual_style_lab_shot: %s (%s)" % [path, error_string(error)])
