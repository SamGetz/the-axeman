class_name LevelUpBurst
extends Node3D
## Procedural stand-in for the level-up celebration: tall light streaks and
## sparks rise from the block without a ground-level halo or ring.
## Pure presentation; GameState.level_gained remains the authoritative event.
## All timing, counts and dimensions are PLACEHOLDERS pending the VFX art pass.

static var _ray_mesh: QuadMesh
static var _spark_mesh: QuadMesh
static var _ray_material: StandardMaterial3D
static var _spark_material: StandardMaterial3D

const _DURATION := 1.45
const _RAY_COUNT := 10
const _SPARK_COUNT := 18

var _radius := 0.4
var _age := 0.0
var _rays: Array[MeshInstance3D] = []
var _ray_angles := PackedFloat32Array()
var _sparks: Array[MeshInstance3D] = []
var _spark_starts: Array[Vector3] = []
var _spark_dirs: Array[Vector3] = []
var _spark_speeds := PackedFloat32Array()
var _light: OmniLight3D


static func prewarm() -> void:
	_ensure_shared()


## Builds the complete effect graph during the initial load. The returned node
## stays resident and hidden between level-ups, so play_at performs no allocation.
static func create_prewarmed(parent: Node, radius: float) -> LevelUpBurst:
	_ensure_shared()
	var burst := LevelUpBurst.new()
	burst.name = "LevelUpVFXPool"
	parent.add_child(burst)
	burst._build(maxf(0.2, radius))
	burst._stop()
	return burst


static func _ensure_shared() -> void:
	if _ray_mesh != null:
		return

	_ray_mesh = QuadMesh.new()
	_ray_mesh.size = Vector2(0.08, 1.0)
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.045, 0.045)

	_ray_material = _additive_material(Color.WHITE)
	_ray_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ray_material.billboard_keep_scale = true
	_ray_material.albedo_texture = _ray_texture()

	_spark_material = _additive_material(Color.WHITE)
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_spark_material.billboard_keep_scale = true
	_spark_material.albedo_texture = _spark_texture()

	_ray_mesh.get_rid()
	_spark_mesh.get_rid()
	_ray_material.get_rid()
	_spark_material.get_rid()


static func _additive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	return material


static func _ray_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(1.0, 0.55, 0.08, 0.45),
		Color(1.0, 0.92, 0.42, 0.95),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 8
	texture.height = 64
	return texture


static func _spark_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.96, 0.62, 1.0),
		Color(1.0, 0.48, 0.04, 0.65),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture


func _build(radius: float) -> void:
	_radius = radius
	for i in range(_RAY_COUNT):
		var angle := TAU * float(i) / float(_RAY_COUNT)
		var ray := MeshInstance3D.new()
		ray.name = "LevelRay%d" % i
		ray.mesh = _ray_mesh
		ray.material_override = _ray_material
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ray)
		_rays.append(ray)
		_ray_angles.append(angle)

	for i in range(_SPARK_COUNT):
		var angle := TAU * (float(i) + randf_range(-0.3, 0.3)) / float(_SPARK_COUNT)
		var start := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(_radius * 0.2, _radius)
		var spark := MeshInstance3D.new()
		spark.name = "LevelSpark%d" % i
		spark.mesh = _spark_mesh
		spark.material_override = _spark_material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		_sparks.append(spark)
		_spark_starts.append(start)
		_spark_dirs.append(Vector3(cos(angle), randf_range(1.4, 2.2), sin(angle)).normalized())
		_spark_speeds.append(randf_range(0.65, 1.15))

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.18)
	_light.light_energy = 0.0
	_light.omni_range = _radius * 4.0
	_light.shadow_enabled = false
	_light.position.y = 0.35
	add_child(_light)


func play_at(world_position: Vector3) -> void:
	global_position = world_position
	_age = 0.0
	visible = true
	set_process(true)
	_update_visuals(0.0)


## Submit every level-up surface to the renderer during the covered startup
## frames. Resource RIDs are cheap to create, but the Compatibility backend does
## not compile the material pipelines until something is actually drawn.
func show_for_render_warmup(world_position: Vector3) -> void:
	global_position = world_position
	_age = _DURATION * 0.28
	visible = true
	set_process(false)
	_update_visuals(0.28)


func hide_render_warmup() -> void:
	_stop()


func _process(delta: float) -> void:
	_age += delta
	var k := clampf(_age / _DURATION, 0.0, 1.0)
	_update_visuals(k)
	if k >= 1.0:
		_stop()


func _update_visuals(k: float) -> void:
	var flash := sin(PI * clampf(k / 0.52, 0.0, 1.0)) * (1.0 - k)
	_light.light_energy = flash * 2.4

	for i in range(_rays.size()):
		var angle: float = _ray_angles[i]
		var pulse := sin(PI * clampf(k / 0.68, 0.0, 1.0))
		var orbit_radius := _radius * (0.78 + 0.18 * k)
		_rays[i].position = Vector3(cos(angle) * orbit_radius, 0.42 + k * 0.38,
			sin(angle) * orbit_radius)
		_rays[i].scale = Vector3(0.65 + pulse * 0.55, 0.2 + pulse * 1.25, 1.0)
		_rays[i].transparency = smoothstep(0.58, 1.0, k)

	for i in range(_sparks.size()):
		var travel := _spark_speeds[i] * _age
		_sparks[i].position = _spark_starts[i] + _spark_dirs[i] * travel
		var spark_scale := maxf(0.0, sin(PI * k))
		_sparks[i].scale = Vector3.ONE * spark_scale
		_sparks[i].transparency = smoothstep(0.68, 1.0, k)


func _stop() -> void:
	set_process(false)
	visible = false
	if _light != null:
		_light.light_energy = 0.0
