extends Node
## Acceptance coverage for the procedural exterior rollout. It validates the
## whole species table, the exact placeholder debt, material-slot semantics,
## MeshSlicer fresh-inside identity, and recenter-stable projection offsets.

const _CHOPPING := preload("res://scenes/3d_action/chopping_minigame.gd")
const _BARK_SHADER := preload("res://assets/shaders/log_bark_triplanar.gdshader")
const _END_SHADER := preload("res://assets/shaders/log_end_cap.gdshader")
const _PLACEHOLDER_ROOT := "res://assets/textures/wood_placeholders/"

var _failures: Array[String] = []


func _ready() -> void:
	var dresser := _CHOPPING.new()
	var placeholder_species := 0
	var placeholder_paths := 0
	var sampled_half: ArrayMesh = null

	for species_index in range(SpeciesTable.count()):
		var row: SpeciesDef = SpeciesTable.at(species_index)
		_check(row != null, "species %d is missing" % species_index)
		if row == null:
			continue
		var row_has_placeholder := row.bark_tex.begins_with(_PLACEHOLDER_ROOT) \
			or row.top_tex.begins_with(_PLACEHOLDER_ROOT)
		_check(row.exterior_textures_placeholder == row_has_placeholder,
			"%s placeholder flag does not match its paths" % row.id)
		if row_has_placeholder:
			placeholder_species += 1
		for path: String in [row.bark_tex, row.top_tex]:
			if path.is_empty():
				continue
			_check(ResourceLoader.exists(path), "%s texture is missing: %s" % [row.id, path])
			_check(load(path) is Texture2D, "%s did not import as Texture2D: %s" % [row.id, path])
			if path.begins_with(_PLACEHOLDER_ROOT):
				placeholder_paths += 1
		_check(row.bark_tint == Color.WHITE,
			"%s still relies on exterior colour shifting" % row.id)

		_check(not row.meshes.is_empty(), "%s has no log geometry" % row.id)
		if row.meshes.is_empty():
			continue
		var raw := dresser._build_split_log(row.meshes[0]) as ArrayMesh
		var dressed := dresser._apply_species_look(MeshUtils.centered(raw), species_index)
		_check(dressed.get_surface_count() == 2,
			"%s authored log should have bark + end surfaces" % row.id)
		var bark_count := 0
		var end_count := 0
		for surface in range(dressed.get_surface_count()):
			var material := dressed.surface_get_material(surface)
			_check(material is ShaderMaterial,
				"%s exterior surface %d is not procedural" % [row.id, surface])
			if not material is ShaderMaterial:
				continue
			var shader_material := material as ShaderMaterial
			var slot := material.resource_name.to_lower()
			if slot.contains("top"):
				end_count += 1
				_check(shader_material.shader == _END_SHADER,
					"%s end slot uses the wrong shader" % row.id)
				_check(shader_material.get_shader_parameter(&"end_texture") is Texture2D,
					"%s end slot has no texture" % row.id)
			else:
				bark_count += 1
				_check(shader_material.shader == _BARK_SHADER,
					"%s bark slot uses the wrong shader" % row.id)
				_check(shader_material.get_shader_parameter(&"bark_texture") is Texture2D,
					"%s bark slot has no texture" % row.id)
				_check(is_equal_approx(
					float(shader_material.get_shader_parameter(&"projection_scale")),
					row.bark_projection_scale),
					"%s projection scale did not reach the shader" % row.id)
		_check(bark_count == 1 and end_count == 1,
			"%s material slots were not classified as one bark + one end" % row.id)

		var cut_material := dresser._cut_mat_for(species_index) as StandardMaterial3D
		_check(cut_material != null, "%s fresh-inside material changed type" % row.id)
		var sliced := MeshSlicer.slice(dressed, Plane(Vector3.RIGHT, 0.0), cut_material)
		_check(sliced.above != null and sliced.below != null,
			"%s could not be sliced through its centre" % row.id)
		if sliced.above != null:
			_check(sliced.above.get_surface_count() == 3,
				"%s slice did not add exactly one fresh-inside surface" % row.id)
			_check(sliced.above.surface_get_material(2) == cut_material,
				"%s fresh-inside material identity was not preserved" % row.id)
			if sampled_half == null:
				sampled_half = sliced.above

	_check(placeholder_species == 21,
		"expected 21 placeholder species, found %d" % placeholder_species)
	_check(placeholder_paths == 41,
		"expected 41 placeholder texture paths, found %d" % placeholder_paths)
	_check_projection_recenter(dresser, sampled_half)

	if _failures.is_empty():
		print("log_material_acceptance: PASS (25 species, 21 placeholder species, 41 placeholder textures)")
		dresser.free()
		get_tree().quit()
		return
	for failure in _failures:
		push_error("log_material_acceptance: " + failure)
	dresser.free()
	get_tree().quit(1)


func _check_projection_recenter(dresser: Node, half: ArrayMesh) -> void:
	_check(half != null, "no sliced half was available for projection-offset coverage")
	if half == null:
		return
	var parent_offset := Vector3(0.17, -0.09, 0.23)
	var aabb := half.get_aabb()
	var centre := aabb.position + aabb.size * 0.5
	var original_vertex: Vector3 = half.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
	var centred := dresser._translate_mesh(half, -centre) as ArrayMesh
	var centred_vertex: Vector3 = centred.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
	_check((original_vertex + parent_offset).is_equal_approx(
		centred_vertex + parent_offset + centre),
		"projection coordinates changed when a sliced half was recentered")

	dresser.min_vol = 0.0
	dresser.aspect_limit = 1_000_000.0
	dresser._pieces_root = Node3D.new()
	var piece: Area3D = dresser._realise_half(
		half, Transform3D.IDENTITY, Vector3.RIGHT, [], parent_offset)
	_check(piece != null, "projection-offset test half unexpectedly became firewood")
	if piece != null:
		var expected := parent_offset + centre
		_check((piece.get_meta("projection_offset", Vector3.ZERO) as Vector3).is_equal_approx(expected),
			"descendant did not store its accumulated projection offset")
		var mesh_instance := piece.get_node_or_null("Mesh") as MeshInstance3D
		_check(mesh_instance != null, "descendant has no MeshInstance3D")
		if mesh_instance != null:
			var actual: Variant = mesh_instance.get_instance_shader_parameter(&"projection_offset")
			_check(actual is Vector3 and (actual as Vector3).is_equal_approx(expected),
				"descendant did not send its projection offset to the shaders")
	dresser._pieces_root.free()
	dresser._pieces_root = null
	dresser._on_block.clear()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
