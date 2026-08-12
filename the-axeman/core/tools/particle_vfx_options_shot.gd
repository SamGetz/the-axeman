extends Node
## DEV TOOL — deterministic in-game comparison of particle-led skill VFX.
## It does not modify ProcBurst or LevelUpBurst. Output is written to user://.

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")
const _PARTICLE_SHADER := preload("res://core/tools/particle_vfx_option.gdshader")
const _OUT := "user://particle_vfx_option_"

var _quad: QuadMesh
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var game: Node3D = _SCENE.instantiate()
	game.debug_forced_species = 0
	game.debug_forced_mesh = 0
	game.auto_sell = false
	game.orbs_enabled = false
	add_child(game)
	for _frame in range(20):
		await get_tree().process_frame
	await _wait_ms(650)
	# Open the same centre gap used by the live proc shots, so the effect itself is
	# judged rather than being depth-hidden by an intact log cylinder.
	game.debug_slice_world(Plane(Vector3.RIGHT, 0.0))
	await _wait_ms(650)

	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	var origin := Vector3(0.0, game._stump_top_y + 0.18, 0.0)
	for option: Array in [
		["soft_bloom", Callable(self, "_build_soft_bloom")],
		["spark_spray", Callable(self, "_build_spark_spray")],
		["ember_cloud", Callable(self, "_build_ember_cloud")],
		["energy_wisps", Callable(self, "_build_energy_wisps")],
	]:
		_rng.seed = 0xA7E5
		var root := Node3D.new()
		root.name = "ParticleOption_%s" % option[0]
		game.add_child(root)
		root.position = origin
		option[1].call(root)
		for _frame in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := _OUT + String(option[0]) + ".png"
		get_viewport().get_texture().get_image().save_png(path)
		print("PARTICLE VFX OPTION: %s -> %s" % [
			option[0], ProjectSettings.globalize_path(path)])
		root.queue_free()
		for _frame in range(3):
			await get_tree().process_frame

	print("=== particle_vfx_options_shot: done ===")
	get_tree().quit()


func _build_soft_bloom(root: Node3D) -> void:
	# A soft impact volume surrounded by a dotted shockfront and fine sparks.
	_particle(root, Vector3(0.0, 0.05, 0.0), Vector2(0.46, 0.46),
		Color(1.0, 0.16, 0.035, 0.18), Color(1.0, 0.86, 0.42, 0.92), 0, 0.0, 0.72, 0.42)
	_particle(root, Vector3(0.0, 0.05, -0.015), Vector2(0.24, 0.24),
		Color(1.0, 0.24, 0.06, 0.22), Color(1.0, 0.98, 0.72, 1.0), 0, 0.0, 0.52, 0.36)
	for i in range(42):
		var angle := TAU * float(i) / 42.0
		var radius := 0.56 + _rng.randf_range(-0.035, 0.035)
		var point := Vector3(cos(angle) * radius, _rng.randf_range(-0.015, 0.035),
			sin(angle) * radius)
		_particle(root, point, Vector2.ONE * _rng.randf_range(0.032, 0.060),
			Color(0.84, 0.04, 0.01, 0.08), Color(1.0, 0.46, 0.10, 0.86), 0,
			0.0, 0.58, 0.50)
	for i in range(56):
		var angle := _rng.randf_range(0.0, TAU)
		var radius := pow(_rng.randf(), 0.62) * 0.78
		var point := Vector3(cos(angle) * radius,
			_rng.randf_range(0.0, 0.46) * (1.0 - radius * 0.55), sin(angle) * radius * 0.68)
		var warm := Color(1.0, 0.32, 0.06, 0.82) if i % 3 else Color(1.0, 0.82, 0.28, 0.92)
		_particle(root, point, Vector2.ONE * _rng.randf_range(0.018, 0.052),
			Color(warm.r * 0.48, warm.g * 0.28, 0.01, 0.05), warm, 0,
			0.0, 0.48, 0.62)


func _build_spark_spray(root: Node3D) -> void:
	# The axe path is implied by overlapping streak particles, not a solid crescent.
	_particle(root, Vector3(0.0, 0.04, 0.0), Vector2(0.30, 0.30),
		Color(0.90, 0.04, 0.01, 0.14), Color(1.0, 0.92, 0.62, 1.0), 0, 0.0, 0.62, 0.38)
	for i in range(38):
		var t := float(i) / 37.0
		var angle := lerpf(-2.55, 1.05, t)
		var radius := 0.58 + sin(PI * t) * 0.10
		var point := Vector3(cos(angle) * radius, sin(angle) * radius + 0.12,
			_rng.randf_range(-0.035, 0.035))
		var size := Vector2(_rng.randf_range(0.12, 0.25), _rng.randf_range(0.018, 0.040))
		var hot := Color(1.0, lerpf(0.28, 0.82, t), lerpf(0.04, 0.28, t), 0.88)
		_particle(root, point, size, Color(0.72, 0.03, 0.01, 0.05), hot, 1,
			angle + PI * 0.5, 0.38, 0.60)
	for i in range(46):
		var t := _rng.randf()
		var angle := lerpf(-2.45, 0.92, t)
		var radius := _rng.randf_range(0.26, 0.62)
		var point := Vector3(cos(angle) * radius, sin(angle) * radius + 0.12,
			_rng.randf_range(-0.05, 0.05))
		_particle(root, point, Vector2.ONE * _rng.randf_range(0.016, 0.042),
			Color(0.86, 0.05, 0.01, 0.04), Color(1.0, 0.52, 0.10, 0.82), 0,
			0.0, 0.44, 0.58)


func _build_ember_cloud(root: Node3D) -> void:
	# Chunky, physical embers with a dense centre and upward debris plume.
	_particle(root, Vector3(0.0, 0.035, 0.0), Vector2(0.36, 0.36),
		Color(0.78, 0.02, 0.005, 0.16), Color(1.0, 0.74, 0.26, 0.96), 0, 0.0, 0.70, 0.48)
	for i in range(92):
		var angle := _rng.randf_range(0.0, TAU)
		var radial := pow(_rng.randf(), 0.76) * 0.72
		var lift := pow(_rng.randf(), 1.42) * 0.82
		var point := Vector3(cos(angle) * radial, lift - radial * 0.10,
			sin(angle) * radial * 0.74)
		var shape := 2 if i % 3 == 0 else 0
		var size := _rng.randf_range(0.018, 0.074) * (1.0 - lift * 0.32)
		var hot := Color(1.0, _rng.randf_range(0.28, 0.70), _rng.randf_range(0.03, 0.16),
			_rng.randf_range(0.68, 0.96))
		_particle(root, point, Vector2.ONE * size,
			Color(0.64, 0.025, 0.005, 0.04), hot, shape,
			_rng.randf_range(-PI, PI), 0.34 if shape == 2 else 0.50, 0.72)


func _build_energy_wisps(root: Node3D) -> void:
	# Several broken curls climb from the impact; gaps keep them particulate.
	_particle(root, Vector3(0.0, 0.04, 0.0), Vector2(0.34, 0.34),
		Color(0.72, 0.02, 0.01, 0.12), Color(1.0, 0.90, 0.54, 0.96), 0, 0.0, 0.68, 0.38)
	for strand in range(4):
		for i in range(24):
			if (i + strand) % 5 == 0:
				continue
			var t := float(i) / 23.0
			var angle := t * TAU * 1.45 + float(strand) * TAU / 4.0
			var radius := lerpf(0.42, 0.11, t)
			var point := Vector3(cos(angle) * radius, 0.02 + t * 0.92,
				sin(angle) * radius)
			var warm := Color(1.0, lerpf(0.22, 0.74, t), lerpf(0.04, 0.18, t),
				lerpf(0.72, 0.48, t))
			_particle(root, point,
				Vector2(_rng.randf_range(0.052, 0.092), _rng.randf_range(0.020, 0.040)),
				Color(0.70, 0.02, 0.01, 0.04), warm, 3,
				angle + PI * 0.5, 0.64, 0.54)
	for i in range(38):
		var point := Vector3(_rng.randf_range(-0.46, 0.46),
			_rng.randf_range(0.05, 0.86), _rng.randf_range(-0.30, 0.30))
		_particle(root, point, Vector2.ONE * _rng.randf_range(0.012, 0.035),
			Color(0.68, 0.02, 0.01, 0.03), Color(1.0, 0.48, 0.10, 0.66), 0,
			0.0, 0.52, 0.58)


func _particle(root: Node3D, position: Vector3, size: Vector2,
		edge: Color, core: Color, shape: int, angle: float,
		softness: float, dither: float) -> void:
	var particle := MeshInstance3D.new()
	particle.mesh = _quad
	particle.position = position
	particle.scale = Vector3(size.x, size.y, 1.0)
	particle.material_override = _material(edge, core, shape, angle, softness, dither)
	particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(particle)


func _material(edge: Color, core: Color, shape: int, angle: float,
		softness: float, dither: float) -> ShaderMaterial:
	var key := "%s|%s|%d|%.3f|%.3f|%.3f" % [edge.to_html(true), core.to_html(true),
		shape, angle, softness, dither]
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = _PARTICLE_SHADER
	material.set_shader_parameter("edge_color", edge)
	material.set_shader_parameter("core_color", core)
	material.set_shader_parameter("shape_mode", shape)
	material.set_shader_parameter("sprite_rotation", angle)
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("dither_strength", dither)
	material.set_shader_parameter("dither_pixel_size", 1.30)
	_materials[key] = material
	return material


func _wait_ms(ms: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < ms:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
