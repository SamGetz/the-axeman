class_name ProcBurst
extends Node3D
## Particle-led proc announcement for the Compatibility renderer.
## Strength explodes as hot physical embers, Speed fires a directional spark
## spray, and Mastery rises as mixed green/gold motes. Pure presentation: the
## proc outcome is authoritative before this node exists.

enum Style { GENERIC, STRENGTH, SPEED, MASTERY }

const _CONFIG = preload("res://data/skill_vfx_config.tres")
const _PARTICLE_SHADER = preload("res://assets/shaders/skill_vfx_particle.gdshader")
const _OVERLAY_SHADER = preload("res://assets/shaders/skill_vfx_overlay_glow.gdshader")
const _MAX_REAL_DELTA := 0.05

static var _material_cache: Dictionary = {}

var _style := Style.GENERIC
var _duration := 0.58
var _age := 0.0
var _started_ms := 0
var _core: MeshInstance3D
var _emitters: Array[GPUParticles3D] = []
var _light: OmniLight3D
var _overlay_material: ShaderMaterial


static func spawn(parent: Node, world_pos: Vector3, color: Color,
		branch_id: StringName = &"") -> ProcBurst:
	var burst := ProcBurst.new()
	parent.add_child(burst)
	burst.global_position = world_pos
	burst._build(color, _style_for(branch_id))
	return burst


## Strength and Speed are ground-sourced actions: preserve the split's horizontal
## position but pin their announcement to the foot of the log. The clearance is
## provisional authored VFX tuning rather than a gameplay geometry constant.
static func spawn_from_log_base(parent: Node, split_pos: Vector3,
		log_base_y: float, color: Color, branch_id: StringName,
		toward_viewer := Vector3.ZERO) -> ProcBurst:
	var base_pos := Vector3(split_pos.x,
		log_base_y + _CONFIG.proc_log_base_clearance, split_pos.z)
	if toward_viewer.length_squared() > 0.0001:
		base_pos += toward_viewer.normalized() * _CONFIG.proc_log_base_viewer_offset
	return spawn(parent, base_pos, color, branch_id)


static func prewarm(colors: Array[Color]) -> void:
	for color: Color in colors:
		for shape: int in [0, 1, 2]:
			_sprite_material(color, shape, false).get_rid()
		_sprite_material(color.lerp(Color.WHITE, 0.46), 0, true).get_rid()
	_sprite_material(_CONFIG.mastery_accent_color, 0, false).get_rid()
	_sprite_material(Color(1.0, 0.84, 0.42, 0.48), 0, true).get_rid()


static func _style_for(branch_id: StringName) -> int:
	match branch_id:
		&"strength": return Style.STRENGTH
		&"speed": return Style.SPEED
		&"mastery": return Style.MASTERY
	return Style.GENERIC


func _build(color: Color, style: int) -> void:
	_style = style
	_duration = _duration_for(style)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_core(color)
	_build_light(color)
	_build_overlay(color)
	match style:
		Style.STRENGTH: _build_strength(color)
		Style.SPEED: _build_speed(color)
		Style.MASTERY: _build_mastery(color)
		_: _build_generic(color)
	_started_ms = Time.get_ticks_msec()


func _duration_for(style: int) -> float:
	match style:
		Style.STRENGTH: return _CONFIG.strength_duration
		Style.SPEED: return _CONFIG.speed_duration
		Style.MASTERY: return _CONFIG.mastery_duration
	return _CONFIG.generic_duration


func _build_core(color: Color) -> void:
	_core = MeshInstance3D.new()
	_core.name = "ProcContactGlow"
	var core_color := color.lerp(Color.WHITE, 0.46)
	core_color.a = _CONFIG.proc_core_opacity
	_core.mesh = _draw_mesh(_sprite_material(
		core_color, 0, true), Vector2.ONE)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.position.y = 0.035
	add_child(_core)


func _build_light(color: Color) -> void:
	_light = OmniLight3D.new()
	_light.name = "ProcImpactLight"
	_light.light_color = color.lerp(Color.WHITE, 0.22)
	_light.light_energy = 0.0
	_light.omni_range = _CONFIG.proc_light_range
	_light.shadow_enabled = false
	_light.position.y = 0.08
	add_child(_light)


func _build_overlay(color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProcScreenGlow"
	layer.layer = 24
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2.ZERO
	rect.size = get_viewport().get_visible_rect().size
	rect.color = Color.WHITE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = _OVERLAY_SHADER
	_overlay_material.set_shader_parameter("tint", color)
	_overlay_material.set_shader_parameter("intensity", 0.0)
	_overlay_material.set_shader_parameter("center_weight",
		0.22 if _style == Style.STRENGTH else (0.36 if _style == Style.SPEED else 0.64))
	_overlay_material.set_shader_parameter("mask_mode", 0)
	rect.material = _overlay_material
	layer.add_child(rect)


func _build_strength(color: Color) -> void:
	_new_emitter("StrengthEmberCloud", _CONFIG.strength_ember_count,
		_duration * 0.94, color, 0, false, Vector2.ONE, Vector3.UP,
		_CONFIG.strength_spread_degrees,
		_CONFIG.strength_speed_min, _CONFIG.strength_speed_max,
		Vector3.DOWN * 1.8, _CONFIG.strength_cloud_radius, 0.018, 0.066)
	_new_emitter("StrengthHotFragments", _CONFIG.strength_hot_particle_count,
		_duration * 0.82, color.lerp(Color(1.0, 0.78, 0.24), 0.48), 2, false,
		Vector2.ONE, Vector3.UP, _CONFIG.strength_spread_degrees * 1.08,
		_CONFIG.strength_speed_min * 1.35,
		_CONFIG.strength_speed_max * 1.35, Vector3.DOWN * 2.2,
		_CONFIG.strength_cloud_radius * 0.55, 0.012, 0.040)
	_new_emitter("StrengthSmoothGlowDust", _CONFIG.strength_glow_particle_count,
		_duration, Color(color.r, color.g, color.b, _CONFIG.smooth_glow_alpha), 0, true,
		Vector2.ONE, Vector3.UP, _CONFIG.strength_spread_degrees, 0.28, 0.86,
		Vector3.DOWN * 0.65,
		_CONFIG.strength_cloud_radius * 0.8, 0.030, 0.085)


func _build_speed(color: Color) -> void:
	var direction := Vector3.UP
	_new_emitter("SpeedSparkSpray", _CONFIG.speed_streak_count,
		_duration * 0.92, color, 1, false, Vector2(0.72, 4.4), direction,
		_CONFIG.speed_spread_degrees, _CONFIG.speed_particle_speed_min,
		_CONFIG.speed_particle_speed_max, Vector3.DOWN * 0.30,
		_CONFIG.speed_emission_radius, 0.020, 0.050)
	_new_emitter("SpeedTrailingMotes", _CONFIG.speed_mote_count,
		_duration, color.lerp(Color.WHITE, 0.18), 0, false, Vector2.ONE,
		direction, _CONFIG.speed_spread_degrees * 1.45,
		_CONFIG.speed_particle_speed_min * 0.52,
		_CONFIG.speed_particle_speed_max * 0.72, Vector3.DOWN * 0.18,
		_CONFIG.speed_emission_radius * 1.2, 0.012, 0.038)
	_new_emitter("SpeedSmoothGlowTrail", _CONFIG.speed_glow_particle_count,
		_duration, Color(color.r, color.g, color.b, _CONFIG.smooth_glow_alpha), 1, true,
		Vector2(0.9, 3.2), direction, _CONFIG.speed_spread_degrees * 0.62,
		_CONFIG.speed_particle_speed_min * 0.38,
		_CONFIG.speed_particle_speed_max * 0.46, Vector3.ZERO,
		_CONFIG.speed_emission_radius,
		0.026, 0.065)


func _build_mastery(color: Color) -> void:
	var direction := Vector3.UP
	_new_emitter("MasteryGreenEmbers", _CONFIG.mastery_green_mote_count,
		_duration, color, 0, false, Vector2.ONE, direction,
		_CONFIG.mastery_spread_degrees, _CONFIG.mastery_particle_speed_min,
		_CONFIG.mastery_particle_speed_max, Vector3.UP * 0.12,
		_CONFIG.mastery_emission_radius, 0.014, 0.050)
	_new_emitter("MasteryGoldEmbers", _CONFIG.mastery_gold_mote_count,
		_duration * 0.96, _CONFIG.mastery_accent_color, 2, false, Vector2.ONE,
		direction, _CONFIG.mastery_spread_degrees * 0.88,
		_CONFIG.mastery_particle_speed_min * 0.92,
		_CONFIG.mastery_particle_speed_max * 1.08, Vector3.UP * 0.10,
		_CONFIG.mastery_emission_radius * 0.84, 0.012, 0.042)
	_new_emitter("MasterySmoothGlowMotes", _CONFIG.mastery_glow_particle_count,
		_duration, Color(color.r, color.g, color.b, _CONFIG.smooth_glow_alpha), 0, true,
		Vector2.ONE, direction, _CONFIG.mastery_spread_degrees,
		0.30, 0.88, Vector3.UP * 0.08, _CONFIG.mastery_emission_radius,
		0.026, 0.075)


func _build_generic(color: Color) -> void:
	_new_emitter("ProcEmberCloud", _CONFIG.generic_particle_count,
		_duration, color, 0, false, Vector2.ONE, Vector3.UP, 180.0,
		_CONFIG.generic_speed_min, _CONFIG.generic_speed_max,
		Vector3.DOWN * 1.2, 0.06, 0.016, 0.052)


func _new_emitter(node_name: String, count: int, lifetime: float,
		color: Color, shape: int, smooth: bool, mesh_size: Vector2,
		direction: Vector3, spread: float, speed_min: float, speed_max: float,
		gravity: Vector3, emission_radius: float, scale_min: float,
		scale_max: float) -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = emission_radius
	process.direction = direction.normalized()
	process.spread = spread
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.gravity = gravity
	process.damping_min = 0.15
	process.damping_max = 0.55
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.color_ramp = _particle_fade_ramp()

	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.randomness = 0.34
	particles.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 5.0, 6.0))
	particles.process_material = process
	particles.draw_pass_1 = _draw_mesh(_sprite_material(color, shape, smooth), mesh_size)
	add_child(particles)
	_emitters.append(particles)
	particles.emitting = true


func _process(_delta: float) -> void:
	var now_ms := Time.get_ticks_msec()
	var real_delta := clampf(float(now_ms - _started_ms) / 1000.0,
		0.0, _MAX_REAL_DELTA)
	_started_ms = now_ms
	_age += real_delta
	var k := clampf(_age / _duration, 0.0, 1.0)
	_update_shared(k)
	if k >= 1.0:
		queue_free()


func _update_shared(k: float) -> void:
	var core_pulse := sin(PI * clampf(k / 0.36, 0.0, 1.0)) \
		* (1.0 - smoothstep(0.28, 0.78, k))
	var core_size := _CONFIG.proc_core_size * (0.55 + core_pulse * 1.70)
	_core.scale = Vector3.ONE * core_size
	_core.transparency = 1.0 - clampf(
		core_pulse * _CONFIG.proc_core_opacity, 0.0, 1.0)
	var energy := _CONFIG.speed_light_energy
	if _style == Style.STRENGTH:
		energy = _CONFIG.strength_light_energy
	elif _style == Style.MASTERY:
		energy = _CONFIG.mastery_light_energy
	_light.light_energy = energy * core_pulse
	var overlay_pulse := sin(PI * clampf(k / 0.60, 0.0, 1.0)) * (1.0 - k)
	var multiplier := 1.0 if _style == Style.STRENGTH else (0.70 if _style == Style.SPEED else 0.58)
	_overlay_material.set_shader_parameter("intensity",
		_CONFIG.proc_overlay_strength * multiplier * overlay_pulse)


static func _sprite_material(color: Color, shape: int,
		smooth: bool) -> ShaderMaterial:
	var key := "%s|%d|%s" % [color.to_html(true), shape, str(smooth)]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = _PARTICLE_SHADER
	material.set_shader_parameter("edge_color", Color(
		color.r * 0.34, color.g * 0.22, color.b * 0.16, 0.0))
	material.set_shader_parameter("core_color", color)
	material.set_shader_parameter("shape_mode", shape)
	material.set_shader_parameter("softness",
		_CONFIG.smooth_glow_softness if smooth else (0.40 if shape == 2 else 0.56))
	material.set_shader_parameter("dither_strength",
		0.0 if smooth else _CONFIG.particle_dither_strength)
	material.set_shader_parameter("dither_pixel_size", _CONFIG.particle_dither_pixel_size)
	_material_cache[key] = material
	return material


static func _draw_mesh(material: ShaderMaterial, size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


static func _particle_fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.06, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0), Color.WHITE,
		Color(1.0, 1.0, 1.0, 0.72), Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 64
	return texture
