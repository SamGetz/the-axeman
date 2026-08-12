extends Node3D
## Isolated visual proof for UV-light procedural log texturing.
##
## Renders three species on generated branch-stub geometry. Bark is sampled by
## object-space triplanar projection; every authored end is a separate semantic
## surface with an automatically fitted planar UV island. A final comparison
## uses the existing runtime inside textures on fresh-cut faces. Nothing in this
## tool starts a chopping session or touches saves/gameplay resources.

const OUT := "/private/tmp/axeman_log_material_lab_"
const _BARK_SHADER := preload("res://assets/shaders/log_bark_triplanar.gdshader")
const _END_SHADER := preload("res://assets/shaders/log_end_cap.gdshader")

const _OAK_BARK := preload("res://assets/models/logs_export/log_01_0.png")
const _OAK_END := preload("res://assets/models/logs_export/log_01_1.png")
const _OAK_INSIDE := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_diffColor.jpg")
const _OAK_INSIDE_N := preload("res://assets/textures/wood_oak/wood_oak_inside_tilable_normals.jpg")
const _BIRCH_BARK := preload("res://assets/textures/wood_birch/birch_bark_tilable.png")
const _BIRCH_END := preload("res://assets/textures/wood_birch/birch_top_tilable.png")
const _BIRCH_INSIDE := preload("res://assets/textures/wood_birch/birch_inside_tilable.png")
const _PINE_BARK := preload("res://assets/textures/wood_eastern_pine/eastern_pine_bark.png")
const _PINE_END := preload("res://assets/textures/wood_eastern_pine/eastern_pine_top.png")
const _PINE_INSIDE := preload("res://assets/textures/wood_eastern_pine/eastern_pine_inside_tilable.png")

const _PLACEHOLDER_BLEND_SHARPNESS := 7.0
const _SIDES := 14

var _camera: Camera3D
var _overview_root: Node3D
var _cut_root: Node3D
var _overview_logs: Array[MeshInstance3D] = []


func _ready() -> void:
	_setup_world()
	_build_overview()
	_build_cut_comparison()
	_cut_root.hide()
	await _settle_frames(12)

	_set_camera(Vector3(0.0, 1.46, 3.55), Vector3(0.0, 0.58, 0.0), 39.0)
	await _save("01_overview")

	# The detail pass isolates the branch-heavy birch specimen. Keeping all three
	# comparison labels in a close crop made the first render visually noisy and
	# clipped text at both sides, obscuring the material result it was meant to show.
	for index in range(_overview_logs.size()):
		_overview_logs[index].visible = index == 1
	for child in _overview_root.get_children():
		if child is Label3D:
			child.hide()
	_add_label(_overview_root, "DETAIL  /  ONE CENTRED END-GRAIN ISLAND PER CUT STUB",
		Vector3(0.0, 1.29, -0.04), 0.00215)
	_set_camera(Vector3(0.10, 1.20, 2.0), Vector3(0.0, 0.61, 0.04), 35.0)
	await _save("02_branch_end_detail")

	_overview_root.hide()
	_cut_root.show()
	_set_camera(Vector3(0.0, 1.25, 3.0), Vector3(0.0, 0.52, 0.05), 37.0)
	await _settle_frames(3)
	await _save("03_inside_unchanged")

	print("log_material_lab_shot: done")
	get_tree().quit()


func _setup_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#b9c6b6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f2ead8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	key.light_color = Color("#ffe3b8")
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 1.9, 2.4)
	fill.light_color = Color("#b8d5ff")
	fill.light_energy = 2.6
	fill.omni_range = 5.0
	add_child(fill)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 4.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#6d765e")
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	add_child(ground)

	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)


func _build_overview() -> void:
	_overview_root = Node3D.new()
	_overview_root.name = "Overview"
	add_child(_overview_root)

	# PLACEHOLDER macro-scale pass: reduced by a further 40% after review. These
	# remain comparison values only, not final species tuning.
	var specs := [
		{
			"name": "OAK  /  TRIPLANAR BARK",
			"x": -0.82,
			"bark": _OAK_BARK,
			"end": _OAK_END,
			"tint": Color("#fff4df"),
			"scale": 1.8,
			"phase": -0.28,
		},
		{
			"name": "BIRCH  /  AUTO BRANCH ENDS",
			"x": 0.0,
			"bark": _BIRCH_BARK,
			"end": _BIRCH_END,
			"tint": Color.WHITE,
			"scale": 1.62,
			"phase": 0.08,
		},
		{
			"name": "PINE  /  SHARED GEOMETRY",
			"x": 0.82,
			"bark": _PINE_BARK,
			"end": _PINE_END,
			"tint": Color("#fff8e8"),
			"scale": 2.16,
			"phase": 0.34,
		},
	]
	for spec: Dictionary in specs:
		var bark := _bark_material(spec.bark, spec.tint, spec.scale)
		var end := _end_material(spec.end, Color.WHITE)
		var log := MeshInstance3D.new()
		log.mesh = _branch_log_mesh(bark, end, null, float(spec.phase))
		log.position = Vector3(float(spec.x), 0.51, 0.0)
		log.rotation_degrees.y = rad_to_deg(float(spec.phase)) * 0.32
		_overview_root.add_child(log)
		_overview_logs.append(log)
		_add_label(_overview_root, String(spec.name),
			Vector3(float(spec.x), 1.13, 0.0), 0.0017)

	_add_label(_overview_root,
		"PROCEDURAL EXTERIOR LAB  •  PLACEHOLDER TUNING",
		Vector3(0.0, 1.38, -0.06), 0.00235)


func _build_cut_comparison() -> void:
	_cut_root = Node3D.new()
	_cut_root.name = "InsideComparison"
	add_child(_cut_root)

	var bark := _bark_material(_OAK_BARK, Color("#fff4df"), 1.8)
	var end := _end_material(_OAK_END, Color.WHITE)
	var intact := MeshInstance3D.new()
	intact.mesh = _branch_log_mesh(bark, end, null, -0.12)
	intact.position = Vector3(-0.54, 0.51, -0.03)
	_cut_root.add_child(intact)
	_add_label(_cut_root, "AUTHORED ENDS", Vector3(-0.54, 1.13, -0.03), 0.0019)

	var inside := _inside_material(_OAK_INSIDE, _OAK_INSIDE_N)
	var billet := MeshInstance3D.new()
	billet.mesh = _fresh_cut_billet_mesh(bark, inside)
	billet.position = Vector3(0.58, 0.47, 0.15)
	billet.rotation_degrees = Vector3(-10.0, -8.0, 0.0)
	_cut_root.add_child(billet)
	_add_label(_cut_root, "FRESH INSIDE  /  EXISTING PATH",
		Vector3(0.58, 1.05, 0.12), 0.0019)

	_add_label(_cut_root,
		"BARK + ORIGINAL ENDS CHANGE  •  RUNTIME SPLIT FACE DOES NOT",
		Vector3(0.0, 1.38, -0.05), 0.00225)


func _branch_log_mesh(bark: Material, end: Material,
		inside: Material, phase: float) -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var end_st := SurfaceTool.new()
	end_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside_st: SurfaceTool = null
	if inside != null:
		inside_st = SurfaceTool.new()
		inside_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_tube(bark_st, end_st,
		Vector3(0.015, -0.46, 0.0), Vector3(-0.018, 0.46, 0.0),
		0.225, 0.185, _SIDES, true, true, phase)
	_add_tube(bark_st, end_st,
		Vector3(0.10, 0.05, 0.02),
		Vector3(0.39, 0.24 + phase * 0.12, 0.28),
		0.105, 0.068, 11, false, true, phase + 0.61)
	_add_tube(bark_st, end_st,
		Vector3(-0.10, -0.13, -0.01),
		Vector3(-0.36, 0.01 - phase * 0.10, 0.25),
		0.09, 0.056, 10, false, true, phase + 1.17)

	var mesh := ArrayMesh.new()
	bark_st.set_material(bark)
	bark_st.commit(mesh)
	end_st.set_material(end)
	end_st.commit(mesh)
	if inside_st != null:
		inside_st.set_material(inside)
		inside_st.commit(mesh)
	return mesh


func _fresh_cut_billet_mesh(bark: Material, inside: Material) -> ArrayMesh:
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside_st := SurfaceTool.new()
	inside_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube(bark_st, inside_st,
		Vector3(0.0, 0.0, -0.42), Vector3(0.0, 0.0, 0.42),
		0.255, 0.235, _SIDES, true, true, 0.22)
	var mesh := ArrayMesh.new()
	bark_st.set_material(bark)
	bark_st.commit(mesh)
	inside_st.set_material(inside)
	inside_st.commit(mesh)
	return mesh


func _add_tube(bark_st: SurfaceTool, cap_st: SurfaceTool,
		start: Vector3, finish: Vector3, start_radius: float, finish_radius: float,
		sides: int, cap_start: bool, cap_finish: bool, phase: float) -> void:
	var axis := (finish - start).normalized()
	var u := axis.cross(Vector3.UP)
	if u.length() < 0.01:
		u = axis.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := axis.cross(u).normalized()

	var start_ring := PackedVector3Array()
	var finish_ring := PackedVector3Array()
	for index in range(sides):
		var angle := TAU * float(index) / float(sides)
		var radial := u * cos(angle) + v * sin(angle)
		var wobble := 1.0 + 0.045 * sin(angle * 3.0 + phase * 4.0) \
			+ 0.025 * sin(angle * 5.0 - phase * 2.0)
		start_ring.append(start + radial * start_radius * wobble)
		finish_ring.append(finish + radial * finish_radius * wobble)

	for index in range(sides):
		var next := (index + 1) % sides
		var normal_a := (start_ring[index] - start).normalized()
		var normal_b := (start_ring[next] - start).normalized()
		_emit_tri(bark_st,
			start_ring[index], normal_a,
			finish_ring[next], normal_b,
			finish_ring[index], normal_a)
		_emit_tri(bark_st,
			start_ring[index], normal_a,
			start_ring[next], normal_b,
			finish_ring[next], normal_b)

	if cap_start:
		_add_cap(cap_st, start, start_ring, -axis, true)
	if cap_finish:
		_add_cap(cap_st, finish, finish_ring, axis, false)


func _add_cap(st: SurfaceTool, center: Vector3, ring: PackedVector3Array,
		normal: Vector3, reverse: bool) -> void:
	for index in range(ring.size()):
		var next := (index + 1) % ring.size()
		var angle_a := TAU * float(index) / float(ring.size())
		var angle_b := TAU * float(next) / float(ring.size())
		var uv_center := Vector2(0.5, 0.5)
		var uv_a := Vector2(cos(angle_a), sin(angle_a)) * 0.47 + uv_center
		var uv_b := Vector2(cos(angle_b), sin(angle_b)) * 0.47 + uv_center
		if reverse:
			_emit_tri_uv(st, center, normal, uv_center,
				ring[next], normal, uv_b, ring[index], normal, uv_a)
		else:
			_emit_tri_uv(st, center, normal, uv_center,
				ring[index], normal, uv_a, ring[next], normal, uv_b)


func _emit_tri(st: SurfaceTool,
		a: Vector3, na: Vector3, b: Vector3, nb: Vector3,
		c: Vector3, nc: Vector3) -> void:
	_emit_vertex(st, a, na, Vector2.ZERO)
	_emit_vertex(st, b, nb, Vector2.ZERO)
	_emit_vertex(st, c, nc, Vector2.ZERO)


func _emit_tri_uv(st: SurfaceTool,
		a: Vector3, na: Vector3, uva: Vector2,
		b: Vector3, nb: Vector3, uvb: Vector2,
		c: Vector3, nc: Vector3, uvc: Vector2) -> void:
	_emit_vertex(st, a, na, uva)
	_emit_vertex(st, b, nb, uvb)
	_emit_vertex(st, c, nc, uvc)


func _emit_vertex(st: SurfaceTool, position: Vector3,
		normal: Vector3, uv: Vector2) -> void:
	st.set_normal(normal)
	st.set_uv(uv)
	st.set_color(Color.WHITE)
	st.add_vertex(position)


func _bark_material(texture: Texture2D, tint: Color, scale: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _BARK_SHADER
	material.set_shader_parameter("bark_texture", texture)
	material.set_shader_parameter("bark_tint", tint)
	material.set_shader_parameter("projection_scale", scale)
	material.set_shader_parameter("blend_sharpness", _PLACEHOLDER_BLEND_SHARPNESS)
	return material


func _end_material(texture: Texture2D, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _END_SHADER
	material.set_shader_parameter("end_texture", texture)
	material.set_shader_parameter("end_tint", tint)
	return material


func _inside_material(texture: Texture2D, normal: Texture2D = null) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 1.0
	return material


func _add_label(parent: Node3D, text: String,
		position: Vector3, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.pixel_size = pixel_size
	label.font_size = 28
	label.modulate = Color("#fff7df")
	label.outline_modulate = Color("#263026")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _set_camera(position: Vector3, target: Vector3, fov: float) -> void:
	_camera.position = position
	_camera.fov = fov
	_camera.look_at(target, Vector3.UP)


func _settle_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT + label + ".png"
	var error := image.save_png(path)
	print("log_material_lab_shot: %s (%s)" % [path, error_string(error)])
