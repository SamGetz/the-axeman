class_name LevelUpBurst
extends Node3D
## Particle-led gold milestone shower. Ten soft rising streak sprites preserve the
## established crown count, while dense ember emitters replace the old solid
## triangular beams. All glow layers are intentionally dither-free.

const _CONFIG = preload("res://data/skill_vfx_config.tres")
const _PARTICLE_SHADER = preload("res://assets/shaders/skill_vfx_particle.gdshader")
const _OVERLAY_SHADER = preload("res://assets/shaders/skill_vfx_overlay_glow.gdshader")

static var _material_cache: Dictionary = {}

var _radius := 0.4
var _age := 0.0
var _rays: Array[MeshInstance3D] = []
var _ray_starts: Array[Vector3] = []
var _ray_scales := PackedFloat32Array()
var _sparks: Array[MeshInstance3D] = []
var _spark_starts: Array[Vector3] = []
var _spark_dirs: Array[Vector3] = []
var _spark_speeds := PackedFloat32Array()
var _spark_scales := PackedFloat32Array()
var _emitters: Array[GPUParticles3D] = []
var _core: MeshInstance3D
var _light: OmniLight3D
var _overlay_material: ShaderMaterial


static func prewarm() -> void:
	_sprite_material(Color(1.0, 0.72, 0.12, _CONFIG.level_ray_alpha), 1, true).get_rid()
	_sprite_material(Color(1.0, 0.86, 0.30, 0.92), 2, false).get_rid()
	_sprite_material(Color(1.0, 0.92, 0.54, _CONFIG.level_core_alpha), 0, true).get_rid()


static func create_prewarmed(parent: Node, radius: float) -> LevelUpBurst:
	prewarm()
	var burst := LevelUpBurst.new()
	burst.name = "LevelUpVFXPool"
	parent.add_child(burst)
	burst._build(maxf(0.2, radius))
	burst._stop()
	return burst


func _build(radius: float) -> void:
	_radius = maxf(radius, _CONFIG.level_crown_radius)
	var ray_material := _sprite_material(
		Color(1.0, 0.72, 0.12, _CONFIG.level_ray_alpha), 1, true)
	var spark_material := _sprite_material(Color(1.0, 0.86, 0.30, 0.92), 2, false)
	var core_material := _sprite_material(
		Color(1.0, 0.92, 0.54, _CONFIG.level_core_alpha), 0, true)

	for i in range(_CONFIG.level_ray_count):
		var angle := TAU * float(i) / float(_CONFIG.level_ray_count)
		var start := Vector3(cos(angle) * _radius * randf_range(0.28, 0.88),
			randf_range(0.02, 0.16), sin(angle) * _radius * randf_range(0.28, 0.72))
		var ray := MeshInstance3D.new()
		ray.name = "LevelRay%d" % i
		ray.mesh = _draw_mesh(ray_material, Vector2.ONE)
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ray.position = start
		add_child(ray)
		_rays.append(ray)
		_ray_starts.append(start)
		_ray_scales.append(randf_range(0.72, 1.16))

	for i in range(_CONFIG.level_spark_count):
		var angle := TAU * (float(i) + randf_range(-0.3, 0.3)) \
			/ float(_CONFIG.level_spark_count)
		var start := Vector3(cos(angle), 0.0, sin(angle)) \
			* randf_range(_radius * 0.18, _radius * 0.95)
		var spark := MeshInstance3D.new()
		spark.name = "LevelSpark%d" % i
		spark.mesh = _draw_mesh(spark_material, Vector2.ONE)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		_sparks.append(spark)
		_spark_starts.append(start)
		_spark_dirs.append(Vector3(cos(angle) * 0.28, randf_range(1.6, 2.5),
			sin(angle) * 0.28).normalized())
		_spark_speeds.append(randf_range(
			_CONFIG.level_spark_speed_min, _CONFIG.level_spark_speed_max))
		_spark_scales.append(randf_range(0.82, 1.18))

	_core = MeshInstance3D.new()
	_core.name = "LevelCrownGlow"
	_core.mesh = _draw_mesh(core_material, Vector2.ONE)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.position.y = 0.22
	add_child(_core)

	_new_emitter("LevelEmberCloud", _CONFIG.level_ember_count,
		_CONFIG.level_duration * 0.92, Color(1.0, 0.62, 0.10, 0.92),
		2, false, Vector2.ONE, Vector3.UP, 68.0,
		_CONFIG.level_particle_speed_min, _CONFIG.level_particle_speed_max,
		Vector3.DOWN * 0.28, _CONFIG.level_cloud_radius, 0.012, 0.046)
	_new_emitter("LevelSmoothGlowDust", _CONFIG.level_glow_particle_count,
		_CONFIG.level_duration,
		Color(1.0, 0.84, 0.34, _CONFIG.level_smooth_glow_alpha),
		0, true, Vector2.ONE, Vector3.UP, 58.0, 0.32, 1.05,
		Vector3.UP * 0.04, _CONFIG.level_cloud_radius * 1.12, 0.026, 0.078)

	_light = OmniLight3D.new()
	_light.name = "LevelCrownLight"
	_light.light_color = Color(1.0, 0.62, 0.16)
	_light.light_energy = 0.0
	_light.omni_range = _radius * _CONFIG.level_light_range_multiplier
	_light.shadow_enabled = false
	_light.position.y = 0.38
	add_child(_light)

	var layer := CanvasLayer.new()
	layer.name = "LevelScreenGlow"
	layer.layer = 23
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = Vector2.ZERO
	rect.size = get_viewport().get_visible_rect().size
	rect.color = Color.WHITE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = _OVERLAY_SHADER
	_overlay_material.set_shader_parameter("tint", Color(1.0, 0.64, 0.16, 0.68))
	_overlay_material.set_shader_parameter("intensity", 0.0)
	_overlay_material.set_shader_parameter("mask_mode", 1)
	rect.material = _overlay_material
	layer.add_child(rect)


func play_at(world_position: Vector3) -> void:
	global_position = world_position
	_age = 0.0
	visible = true
	for emitter: GPUParticles3D in _emitters:
		emitter.restart()
		emitter.emitting = true
	set_process(true)
	_update_visuals(0.0)


func show_for_render_warmup(world_position: Vector3) -> void:
	global_position = world_position
	_age = _CONFIG.level_duration * 0.28
	visible = true
	for emitter: GPUParticles3D in _emitters:
		emitter.restart()
		emitter.emitting = true
	set_process(false)
	_update_visuals(0.28)


func hide_render_warmup() -> void:
	_stop()


func _process(delta: float) -> void:
	_age += delta
	var k := clampf(_age / _CONFIG.level_duration, 0.0, 1.0)
	_update_visuals(k)
	if k >= 1.0:
		_stop()


func _update_visuals(k: float) -> void:
	var flash := sin(PI * clampf(k / 0.52, 0.0, 1.0)) * (1.0 - k)
	var rise_pulse := sin(PI * clampf(k / 0.72, 0.0, 1.0))
	var fade := 1.0 - smoothstep(0.58, 1.0, k)
	_light.light_energy = flash * _CONFIG.level_light_energy
	_overlay_material.set_shader_parameter("intensity",
		flash * _CONFIG.level_overlay_strength)

	_core.scale = Vector3.ONE * lerpf(0.14, 0.62, rise_pulse)
	_core.transparency = 1.0 - fade * clampf(flash * 1.55, 0.0, 1.0)

	for i in range(_rays.size()):
		var ray := _rays[i]
		ray.position = _ray_starts[i] + Vector3.UP * k * (0.34 + float(i % 3) * 0.08)
		ray.scale = Vector3(
			_CONFIG.level_ray_width * _ray_scales[i] * (0.55 + rise_pulse * 0.70),
			_CONFIG.level_ray_height * _ray_scales[i] * (0.10 + rise_pulse * 0.56), 1.0)
		ray.transparency = 1.0 - fade * 0.72

	for i in range(_sparks.size()):
		var stagger := float(i % 5) * 0.035
		var local_age := maxf(0.0, _age - stagger)
		var travel := _spark_speeds[i] * local_age
		_sparks[i].position = _spark_starts[i] + _spark_dirs[i] * travel
		var spark_scale := maxf(0.0, sin(PI * clampf(k * 1.08, 0.0, 1.0)))
		_sparks[i].scale = Vector3.ONE * 0.055 * spark_scale * _spark_scales[i]
		_sparks[i].transparency = 1.0 - fade


func _stop() -> void:
	set_process(false)
	visible = false
	if _light != null:
		_light.light_energy = 0.0
	if _overlay_material != null:
		_overlay_material.set_shader_parameter("intensity", 0.0)
	for emitter: GPUParticles3D in _emitters:
		emitter.emitting = false


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
	process.damping_min = 0.12
	process.damping_max = 0.42
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.color_ramp = _particle_fade_ramp()

	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.32
	particles.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 5.0, 6.0))
	particles.process_material = process
	particles.draw_pass_1 = _draw_mesh(_sprite_material(color, shape, smooth), mesh_size)
	particles.emitting = false
	add_child(particles)
	_emitters.append(particles)


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
	gradient.offsets = PackedFloat32Array([0.0, 0.06, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0), Color.WHITE,
		Color(1.0, 1.0, 1.0, 0.74), Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 64
	return texture
