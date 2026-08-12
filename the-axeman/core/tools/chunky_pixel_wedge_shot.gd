extends Node
## Renders a restrained-to-current wedge of the prototype chunky-pixel style
## against one frozen gameplay frame. It does not start a session or touch saves.

const OUT := "/private/tmp/axeman_chunky_wedge_"
const WEDGE := [
	["1_subtle", 2.0, 18.0],
	["2_light", 3.0, 16.0],
	["3_medium", 4.0, 13.0],
	["4_current", 5.0, 10.0],
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

	main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"
	).process_mode = Node.PROCESS_MODE_DISABLED

	var effect: ColorRect = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/PixelColorGrade/ColorClampAndDither")
	var material: ShaderMaterial = load(
		"res://assets/shaders/visual_style_lab_placeholder.tres").duplicate()
	effect.material = material
	material.set_shader_parameter("style_mode", 1)

	for candidate: Array in WEDGE:
		material.set_shader_parameter("chunky_block_size", candidate[1])
		material.set_shader_parameter("chunky_color_levels", candidate[2])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save(String(candidate[0]))
	get_tree().quit()


func _save(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + label + ".png"
	var error := image.save_png(path)
	print("chunky_pixel_wedge_shot: %s (%s)" % [path, error_string(error)])
