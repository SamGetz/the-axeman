extends Node3D
## Two-page contact sheet of every terrestrial species using the live material
## dressing path and real imported log geometry. This is visual QA only: it does
## not enter a chopping session or write progression/inventory state.

const _CHOPPING := preload("res://scenes/3d_action/chopping_minigame.gd")
const _OUT := "/private/tmp/axeman_log_species_review_"
const _COLUMNS := 5
const _ROWS := 3
const _PAGE_SIZE := _COLUMNS * _ROWS

var _camera: Camera3D
var _gallery: Node3D
var _dresser: Node


func _ready() -> void:
	_setup_world()
	_dresser = _CHOPPING.new()
	for page in range(2):
		_build_page(page)
		await _settle_frames(12 if page == 0 else 4)
		await _save("%02d" % (page + 1))
	print("log_species_review_shot: done")
	_dresser.free()
	get_tree().quit()


func _setup_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#aebba9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d9e0d3")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-54.0, -35.0, 0.0)
	key.light_color = Color("#ffe8c8")
	key.light_energy = 0.72
	key.shadow_enabled = true
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.4, 3.2, 3.4)
	fill.light_color = Color("#c5ddff")
	fill.light_energy = 0.62
	fill.omni_range = 8.0
	add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, 5.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#68715a")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	add_child(ground)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 35.0
	_camera.position = Vector3(0.0, 3.72, 4.35)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.25, -0.05))
	add_child(_camera)


func _build_page(page: int) -> void:
	if _gallery != null:
		_gallery.queue_free()
		await get_tree().process_frame
	_gallery = Node3D.new()
	_gallery.name = "SpeciesPage%d" % (page + 1)
	add_child(_gallery)

	var start := page * _PAGE_SIZE
	var finish := mini(start + _PAGE_SIZE, SpeciesTable.count())
	for species_index in range(start, finish):
		var row: SpeciesDef = SpeciesTable.at(species_index)
		if row == null or row.meshes.is_empty():
			continue
		var local_index := species_index - start
		var column := local_index % _COLUMNS
		var grid_row := local_index / _COLUMNS
		var x := (float(column) - 2.0) * 0.78
		var z := (float(grid_row) - 1.0) * 0.75

		var mesh: ArrayMesh = _dresser._build_split_log(row.meshes[0])
		mesh = _dresser._apply_species_look(MeshUtils.centered(mesh), species_index)
		var specimen := MeshInstance3D.new()
		specimen.name = String(row.id)
		specimen.mesh = mesh
		specimen.position = Vector3(x, mesh.get_aabb().size.y * 0.5 + 0.015, z)
		specimen.rotation_degrees.y = -22.0 + float(column) * 9.0
		specimen.set_instance_shader_parameter(&"projection_offset", Vector3.ZERO)
		_gallery.add_child(specimen)

		_add_label(row.display_name, Vector3(x, 0.61, z + 0.03), 0.00135)

	_add_label(
		"LIVE PROCEDURAL LOG EXTERIORS  •  PAGE %d/2  •  PLACEHOLDER ART" % (page + 1),
		Vector3(0.0, 0.98, -1.08), 0.00215)


func _add_label(text: String, position: Vector3, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text.to_upper()
	label.position = position
	label.pixel_size = pixel_size
	label.font_size = 28
	label.modulate = Color("#fff5dc")
	label.outline_modulate = Color("#263026")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_gallery.add_child(label)


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _save(suffix: String) -> void:
	var path := _OUT + suffix + ".png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("log_species_review_shot: %s (%s)" % [path, error_string(result)])
