extends Node
## Visual QA for the actual chopping scene: an intact placeholder-textured log,
## followed by a real MeshSlicer split showing the unchanged fresh-inside face.

const _OUT := "/private/tmp/axeman_log_material_live_"


func _ready() -> void:
	var minigame: Node3D = load(
		"res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	minigame.debug_forced_species = 24 # Lignum Vitae: strongest exterior/inside contrast.
	minigame.debug_forced_mesh = 0
	minigame.debug_split_roll = 1
	minigame.auto_sell = false
	add_child(minigame)
	await _frames(90)
	_save("01_intact_placeholder")

	minigame.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await _frames(55)
	_save("02_live_split_inside_unchanged")
	print("log_material_live_shot: done")
	get_tree().quit()


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _save(suffix: String) -> void:
	var path := _OUT + suffix + ".png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("log_material_live_shot: %s (%s)" % [path, error_string(result)])

