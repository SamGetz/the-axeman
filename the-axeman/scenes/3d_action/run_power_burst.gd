class_name RunPowerBurst
extends Node3D
## Short-lived, presentation-only announcement shared by run-power acquisition
## and runtime triggers. Gameplay resolves before this node is spawned.

const _CONFIG = preload("res://data/skill_vfx_config.tres")
const _STYLE = preload("res://data/painterly_vfx_style_placeholder.tres")
const _DEFAULT_SHADER = preload("res://assets/shaders/painterly_vfx_daub.gdshader")
const _MAX_REAL_DELTA := 0.05

static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

var power_id: StringName = &""
var _duration := 0.58
var _age := 0.0
var _started_ms := 0
var _core: MeshInstance3D
var _label: Label3D
var _light: OmniLight3D
var _action_root: Node3D
var _action_meshes: Array[MeshInstance3D] = []
var _action_kind: StringName = &""
var _action_span := 2.0
var _action_travel_span := 2.0
var _action_variant := 0


## Preferred caller API when the authoritative runtime already has the immutable
## definition in hand. `event_name` may distinguish a trigger (for example
## "RESCUE") while an empty value shows the authored power name.
static func spawn(parent: Node, world_position: Vector3, definition: RunPowerDef,
		event_name := "", color_override: Variant = null,
		show_action := false, action_value := 0.0,
		action_variant := 0, action_travel_value := 0.0) -> RunPowerBurst:
	if parent == null or definition == null:
		return null
	# Several named powers can resolve in one rendered frame. Preserve every proc
	# and offset only bursts that share this location so a later chain member never
	# erases an earlier power's feedback before it can render.
	var overlap_index := 0
	for child: Node in parent.get_children():
		if child is RunPowerBurst and (child as RunPowerBurst).global_position \
				.distance_to(world_position) < 0.45:
			overlap_index += 1
	var burst := RunPowerBurst.new()
	burst.name = "RunPowerBurst_%s" % definition.id
	parent.add_child(burst)
	var angle := float(overlap_index) * 2.399963
	var ring := 0.11 * float(1 + overlap_index / 5)
	burst.global_position = world_position + Vector3(
		cos(angle) * ring, float(overlap_index % 4) * 0.11, sin(angle) * ring)
	burst._build(definition, event_name, color_override, show_action,
		action_value, action_variant, action_travel_value)
	return burst


## Convenience seam for chopping/arena call sites that only carry the stable id.
static func spawn_for_id(parent: Node, world_position: Vector3,
		requested_power_id: StringName, event_name := "",
		color_override: Variant = null, show_action := false,
		action_value := 0.0, action_variant := 0,
		action_travel_value := 0.0) -> RunPowerBurst:
	var table := SurvivorsContent.run_powers()
	var definition: RunPowerDef = table.by_id(requested_power_id) \
		if table != null else null
	return spawn(parent, world_position, definition, event_name, color_override,
		show_action, action_value, action_variant, action_travel_value)


static func default_power_color() -> Color:
	return Color(0.52, 0.88, 0.36, 1.0)


func _build(definition: RunPowerDef, event_name: String,
		color_override: Variant = null, show_action := false,
		action_value := 0.0, action_variant := 0,
		action_travel_value := 0.0) -> void:
	power_id = definition.id
	_duration = _CONFIG.generic_duration
	process_mode = Node.PROCESS_MODE_ALWAYS
	var color := color_override as Color if color_override is Color \
		else default_power_color()
	var shader := load(definition.vfx_path) as Shader
	if shader == null:
		shader = _DEFAULT_SHADER
	_build_core(shader, color)
	_build_particles(shader, color)
	if show_action:
		_build_action(shader, color, action_value, action_variant,
			action_travel_value)
	_build_label(definition.display_name if event_name.strip_edges().is_empty() \
		else "%s · %s" % [definition.display_name, event_name], color)
	_build_light(color)
	_started_ms = Time.get_ticks_msec()


## Code-native silhouettes for automatic tools and area effects whose gameplay
## otherwise resolves instantly. These are provisional painterly geometry, not
## a second authority: the real cut/target receipt has already resolved.
func _build_action(shader: Shader, color: Color, action_value: float,
		action_variant: int, action_travel_value: float) -> void:
	if power_id not in [&"flying_wedge", &"crosscut_sweep", &"maul_drop",
			&"earthshaker", &"powder_keg", &"kindling_chain", &"stump_pulse",
			&"sawblade_halo", &"timber_burst"]:
		return
	_action_kind = power_id
	_action_variant = action_variant
	_action_span = maxf(0.2, action_value) if power_id == &"crosscut_sweep" \
		else maxf(2.0, action_value)
	_action_travel_span = maxf(_action_span, action_travel_value)
	_action_root = Node3D.new()
	_action_root.name = "ActionSilhouette"
	add_child(_action_root)
	var area_action := power_id in [&"earthshaker", &"powder_keg",
		&"kindling_chain", &"stump_pulse", &"sawblade_halo", &"timber_burst"]
	var action_material := _material(shader, color.lerp(Color.WHITE, 0.12),
		false, &"solid_area" if area_action else &"solid_tool")
	match power_id:
		&"flying_wedge":
			var wedge := CylinderMesh.new()
			wedge.top_radius = 0.025
			wedge.bottom_radius = 0.17
			wedge.height = 0.46
			wedge.radial_segments = 3
			wedge.material = action_material
			var wedge_mesh := _action_mesh("FlyingWedge", wedge)
			wedge_mesh.rotation.x = PI * 0.5
			var tail := BoxMesh.new()
			tail.size = Vector3(0.08, 0.08, 0.32)
			tail.material = action_material
			var tail_mesh := _action_mesh("WedgeTail", tail)
			tail_mesh.position.z = 0.28
			_action_root.position = Vector3(0.0, 1.55, 0.62)
			_action_root.rotation.x = -0.72
		&"crosscut_sweep":
			var blade := BoxMesh.new()
			blade.size = Vector3(_action_span, 0.045, 0.12)
			blade.material = action_material
			_action_mesh("CrosscutBlade", blade)
			var alternate_axis := _action_variant % 2 != 0
			_action_root.position = Vector3(-_action_travel_span * 0.5, 0.16, 0.0) \
				if alternate_axis else Vector3(
					0.0, 0.16, -_action_travel_span * 0.5)
			_action_root.rotation.y = PI * 0.5 if alternate_axis else 0.0
		&"maul_drop":
			var head := BoxMesh.new()
			head.size = Vector3(0.62, 0.24, 0.28)
			head.material = action_material
			_action_mesh("MaulHead", head)
			var handle := CylinderMesh.new()
			handle.top_radius = 0.035
			handle.bottom_radius = 0.045
			handle.height = 0.82
			handle.radial_segments = 8
			handle.material = action_material
			var handle_mesh := _action_mesh("MaulHandle", handle)
			handle_mesh.position.y = -0.50
			_action_root.position = Vector3(0.0, 1.85, 0.0)
			_action_root.rotation.z = -0.18
		&"earthshaker", &"powder_keg", &"kindling_chain", &"stump_pulse", \
				&"sawblade_halo", &"timber_burst":
			_action_span = maxf(0.2, action_value)
			var ring := TorusMesh.new()
			ring.inner_radius = maxf(0.04, _action_span - 0.085)
			ring.outer_radius = _action_span
			ring.material = action_material
			_action_mesh("AreaRing", ring)
			_action_root.position.y = 0.055


func _action_mesh(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_action_root.add_child(instance)
	_action_meshes.append(instance)
	return instance


func _build_core(shader: Shader, color: Color) -> void:
	_core = MeshInstance3D.new()
	_core.name = "PainterlyCore"
	_core.mesh = _draw_mesh(_material(shader, color.lerp(Color.WHITE, 0.24), true),
		Vector2.ONE)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core.position.y = _CONFIG.proc_log_base_clearance + 0.035
	add_child(_core)


func _build_particles(shader: Shader, color: Color) -> void:
	var draw_material := _material(shader, color, false)
	var process := draw_material.get_meta(
		&"run_power_particle_process") as ParticleProcessMaterial \
		if draw_material.has_meta(&"run_power_particle_process") else null
	if process == null:
		process = ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = _CONFIG.strength_cloud_radius
		process.direction = Vector3.UP
		process.spread = _CONFIG.strength_spread_degrees
		process.initial_velocity_min = _CONFIG.generic_speed_min
		process.initial_velocity_max = _CONFIG.generic_speed_max
		process.gravity = Vector3.DOWN * 1.2
		process.damping_min = 0.15
		process.damping_max = 0.55
		# These are the existing generic ProcBurst placeholder dimensions, reused so
		# this announcement does not introduce a second unreviewed particle scale.
		process.scale_min = 0.016
		process.scale_max = 0.052
		process.color_ramp = _particle_fade_ramp()
		draw_material.set_meta(&"run_power_particle_process", process)

	var particles := GPUParticles3D.new()
	particles.name = "PainterlyMotes"
	particles.amount = _CONFIG.generic_particle_count
	particles.lifetime = _duration
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.randomness = 0.34
	particles.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0),
		Vector3(6.0, 5.0, 6.0))
	particles.process_material = process
	particles.draw_pass_1 = _draw_mesh(draw_material, Vector2.ONE)
	add_child(particles)
	particles.emitting = true


func _build_label(text: String, color: Color) -> void:
	_label = Label3D.new()
	_label.name = "PowerName"
	_label.text = text.to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 34
	_label.outline_size = 10
	_label.pixel_size = 0.0025
	_label.modulate = color.lerp(Color.WHITE, 0.20)
	_label.position.y = _CONFIG.proc_core_size * 1.65
	_label.no_depth_test = true
	_label.render_priority = 127
	add_child(_label)


func _build_light(color: Color) -> void:
	_light = OmniLight3D.new()
	_light.name = "PowerLight"
	_light.light_color = color.lerp(Color.WHITE, 0.22)
	_light.light_energy = 0.0
	_light.omni_range = _CONFIG.proc_light_range
	_light.shadow_enabled = false
	_light.position.y = _CONFIG.proc_core_size
	add_child(_light)


func _process(_delta: float) -> void:
	var now_ms := Time.get_ticks_msec()
	var real_delta := clampf(float(now_ms - _started_ms) / 1000.0,
		0.0, _MAX_REAL_DELTA)
	_started_ms = now_ms
	_age += real_delta
	var k := clampf(_age / _duration, 0.0, 1.0)
	var pulse := sin(PI * clampf(k / 0.42, 0.0, 1.0)) \
		* (1.0 - smoothstep(0.34, 0.90, k))
	_core.scale = Vector3.ONE * _CONFIG.proc_core_size * (0.62 + pulse * 1.75)
	_core.transparency = 1.0 - clampf(pulse * _CONFIG.proc_core_opacity, 0.0, 1.0)
	_light.light_energy = _CONFIG.mastery_light_energy * pulse
	_label.position.y = _CONFIG.proc_core_size * (1.65 + k * 1.25)
	var label_color := _label.modulate
	label_color.a = 1.0 - smoothstep(0.56, 1.0, k)
	_label.modulate = label_color
	_update_action(k)
	if k >= 1.0:
		queue_free()


func _update_action(k: float) -> void:
	if _action_root == null:
		return
	var travel := smoothstep(0.0, 0.62, k)
	match _action_kind:
		&"flying_wedge":
			_action_root.position = Vector3(0.0, lerpf(1.55, 0.12, travel),
				lerpf(0.62, 0.0, travel))
			_action_root.rotation.x = lerpf(-0.72, -PI * 0.5, travel)
			var fitted := _camera_fitted_action_scale(1.0, true)
			_action_root.scale = Vector3.ONE * fitted \
				if fitted > 0.0 else Vector3.ZERO
		&"crosscut_sweep":
			if _action_variant % 2 != 0:
				_action_root.position.x = lerpf(-_action_travel_span * 0.5,
					_action_travel_span * 0.5, travel)
				_action_root.position.z = 0.0
			else:
				_action_root.position.x = 0.0
				_action_root.position.z = lerpf(-_action_travel_span * 0.5,
					_action_travel_span * 0.5, travel)
			var reveal := sin(PI * clampf(k / 0.82, 0.0, 1.0))
			var fitted := _camera_fitted_action_scale(maxf(0.08, reveal), false)
			_action_root.scale = Vector3(fitted, 1.0, 1.0) \
				if fitted > 0.0 else Vector3.ZERO
		&"maul_drop":
			_action_root.position.y = lerpf(1.85, 0.22, travel)
			_action_root.rotation.z = lerpf(-0.18, 0.0, travel)
			var fitted := _camera_fitted_action_scale(1.0, true)
			_action_root.scale = Vector3.ONE * fitted \
				if fitted > 0.0 else Vector3.ZERO
		&"earthshaker", &"powder_keg", &"kindling_chain", &"stump_pulse", \
				&"sawblade_halo", &"timber_burst":
			var expand := sin(PI * clampf(k / 0.86, 0.0, 1.0))
			_action_root.scale = Vector3.ONE * maxf(0.02, expand)
	var fade := smoothstep(0.68, 1.0, k)
	for mesh: MeshInstance3D in _action_meshes:
		if is_instance_valid(mesh):
			mesh.transparency = fade


## Camera fitting is presentation-only. Each candidate is applied against the
## immutable mesh/base transform, so repeated frames can never compound shrink.
## Crosscut fits only its reveal axis; Wedge/Maul fit uniformly around the same
## authoritative target anchor and motion path.
func _camera_fitted_action_scale(desired: float, uniform: bool) -> float:
	var requested := clampf(desired, 0.0, 1.0)
	if requested <= 0.0 or _action_root == null or _action_meshes.is_empty():
		return 0.0
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera == null:
		return requested
	var visible_rect := viewport.get_visible_rect()
	if camera.is_position_behind(_action_root.global_position) \
			or not visible_rect.has_point(camera.unproject_position(
				_action_root.global_position)):
		return 0.0
	if _action_meshes_fit(camera, visible_rect, requested, uniform):
		return requested
	var lower := 0.0
	var upper := requested
	for _step: int in range(10):
		var candidate := (lower + upper) * 0.5
		if _action_meshes_fit(camera, visible_rect, candidate, uniform):
			lower = candidate
		else:
			upper = candidate
	return lower


func _action_meshes_fit(camera: Camera3D, visible_rect: Rect2,
		candidate: float, uniform: bool) -> bool:
	_action_root.scale = Vector3.ONE * candidate if uniform \
		else Vector3(candidate, 1.0, 1.0)
	for mesh_instance: MeshInstance3D in _action_meshes:
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue
		var bounds := mesh_instance.mesh.get_aabb()
		for x_side: int in range(2):
			for y_side: int in range(2):
				for z_side: int in range(2):
					var corner := bounds.position + Vector3(
						bounds.size.x * float(x_side),
						bounds.size.y * float(y_side),
						bounds.size.z * float(z_side))
					var world_corner := mesh_instance.global_transform * corner
					if camera.is_position_behind(world_corner) \
							or not visible_rect.has_point(
								camera.unproject_position(world_corner)):
						return false
	return true


static func _material(shader: Shader, color: Color, smooth: bool,
		variant: StringName = &"base") -> ShaderMaterial:
	var key := "%d|%s|%s|%s" % [shader.get_instance_id(), color.to_html(true),
		str(smooth), String(variant)]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("dark_color", Color(
		color.r * 0.32, color.g * 0.22, color.b * 0.18, 0.88))
	material.set_shader_parameter("mid_color", Color(color.r, color.g, color.b,
		_CONFIG.smooth_glow_alpha if smooth else 0.94))
	var light := color.lerp(Color.WHITE, 0.52)
	light.a = 0.94 if smooth else 0.98
	material.set_shader_parameter("light_color", light)
	material.set_shader_parameter("shape_mode", 0)
	material.set_shader_parameter("dry_amount", _STYLE.soft_dry_amount if smooth \
		else _STYLE.daub_dry_amount)
	material.set_shader_parameter("opacity", _STYLE.soft_opacity if smooth else 1.0)
	material.set_shader_parameter("seed", 17.0 if smooth else 11.0)
	if variant in [&"solid_area", &"solid_tool"]:
		material.set_shader_parameter("billboard_enabled", false)
		material.set_shader_parameter("shape_mode", 1)
		material.set_shader_parameter("solid_geometry", true)
		material.set_shader_parameter("opacity", minf(
			_STYLE.soft_opacity, 0.46) if variant == &"solid_area" \
			else _STYLE.soft_opacity)
	_material_cache[key] = material
	return material


static func _draw_mesh(material: ShaderMaterial, size: Vector2) -> QuadMesh:
	var cache_key := "%d|%.4f|%.4f" % [
		material.get_instance_id(), size.x, size.y]
	var cached := _mesh_cache.get(cache_key) as QuadMesh
	if cached != null:
		return cached
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	_mesh_cache[cache_key] = mesh
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
