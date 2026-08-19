class_name RunPowerBurst
extends Node3D
## Short-lived, presentation-only announcement shared by run-power acquisition
## and runtime triggers. Gameplay resolves before this node is spawned.
##
## Every part of the announcement is real 3D geometry from RunPowerPropLibrary:
## an emblem prop naming the power, one billet per destroyed log, and, for the
## periodic tools and area effects, the world-scale silhouette of the thing that
## actually resolved. The retired billboard core and GPU particle cloud are gone
## — a burst now says what happened with objects rather than pigment.
##
## The two live gameplay quantities reach the geometry directly: `amount` is the
## destroyed-log count and becomes that many billets, and `action_value` is the
## already Area-Size-scaled radius and becomes the ground ring's true radius.

const _CONFIG = preload("res://data/run_vfx_config_placeholder.tres")
const _MAX_REAL_DELTA := 0.05

## Powers that additionally draw a world-scale silhouette of the tool sweep or
## area they resolved over.
const ACTION_POWERS: Array[StringName] = [&"flying_wedge", &"crosscut_sweep",
	&"maul_drop", &"earthshaker", &"powder_keg", &"kindling_chain",
	&"stump_pulse", &"sawblade_halo", &"timber_burst"]
const AREA_ACTION_POWERS: Array[StringName] = [&"earthshaker", &"powder_keg",
	&"kindling_chain", &"stump_pulse", &"sawblade_halo", &"timber_burst"]

var power_id: StringName = &""
var _duration := 0.58
var _age := 0.0
var _started_ms := 0
var _prop_root: Node3D
var _prop_meshes: Array[MeshInstance3D] = []
var _prop_base_scale := 1.0
var _tally_root: Node3D
var _tally_meshes: Array[MeshInstance3D] = []
var _tally_offsets: Array[Vector3] = []
var _tally_spins: Array[Vector3] = []
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
##
## `amount` is the number of loose roots this trigger destroyed; zero means the
## event has no log payload (an acquisition) and draws no tally. `identity_count`
## carries a power's own count stat — orbiting axes, Momentum stacks, Area Size
## ranks — for the emblems that are built out of that many pieces.
static func spawn(parent: Node, world_position: Vector3, definition: RunPowerDef,
		event_name := "", color_override: Variant = null,
		show_action := false, action_value := 0.0,
		action_variant := 0, action_travel_value := 0.0,
		amount := 0, identity_count := 0) -> RunPowerBurst:
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
		action_value, action_variant, action_travel_value, amount,
		identity_count)
	return burst


## Convenience seam for chopping/arena call sites that only carry the stable id.
static func spawn_for_id(parent: Node, world_position: Vector3,
		requested_power_id: StringName, event_name := "",
		color_override: Variant = null, show_action := false,
		action_value := 0.0, action_variant := 0,
		action_travel_value := 0.0, amount := 0,
		identity_count := 0) -> RunPowerBurst:
	var table := SurvivorsContent.run_powers()
	var definition: RunPowerDef = table.by_id(requested_power_id) \
		if table != null else null
	return spawn(parent, world_position, definition, event_name, color_override,
		show_action, action_value, action_variant, action_travel_value,
		amount, identity_count)


static func default_power_color() -> Color:
	return Color(0.52, 0.88, 0.36, 1.0)


func _build(definition: RunPowerDef, event_name: String,
		color_override: Variant = null, show_action := false,
		action_value := 0.0, action_variant := 0,
		action_travel_value := 0.0, amount := 0,
		identity_count := 0) -> void:
	power_id = definition.id
	_duration = _CONFIG.generic_duration
	process_mode = Node.PROCESS_MODE_ALWAYS
	var color := color_override as Color if color_override is Color \
		else default_power_color()
	_build_prop(color, action_value, amount, identity_count)
	_build_tally(color, amount)
	if show_action:
		_build_action(color, action_value, action_variant, action_travel_value)
	_build_label(definition.display_name if event_name.strip_edges().is_empty() \
		else "%s · %s" % [definition.display_name, event_name], color)
	_build_light(color)
	_started_ms = Time.get_ticks_msec()


## The emblem naming the power. Count-identity powers are built out of their own
## live count; area powers are sized from the already scaled effective radius.
func _build_prop(color: Color, action_value: float, amount: int,
		identity_count: int) -> void:
	_prop_root = Node3D.new()
	_prop_root.name = "PowerProp"
	add_child(_prop_root)
	var count := identity_count
	if count <= 0:
		count = maxi(1, amount)
	_prop_meshes = RunPowerPropLibrary.build_emblem(_prop_root, power_id, color,
		maxf(0.0, action_value), count)
	_prop_base_scale = maxf(0.01, _CONFIG.prop_scale)
	_prop_root.position.y = _CONFIG.proc_log_base_clearance \
		+ _CONFIG.prop_ground_clearance
	_prop_root.scale = Vector3.ZERO


## Exactly one real billet per destroyed loose root, so a ×4 receipt puts four
## logs on screen instead of one label. Acquisitions pass no amount and get no
## tally at all.
func _build_tally(color: Color, amount: int) -> void:
	var tally := clampi(amount, 0, _CONFIG.prop_tally_max)
	if tally <= 0:
		return
	_tally_root = Node3D.new()
	_tally_root.name = "LogTally"
	add_child(_tally_root)
	_tally_root.position.y = _CONFIG.proc_log_base_clearance + 0.04
	for index: int in range(tally):
		var billet := RunPowerPropLibrary.build_tally_billet(_tally_root, index,
			color)
		if billet == null:
			continue
		var angle := TAU * float(index) / float(tally) + 0.4
		_tally_meshes.append(billet)
		_tally_offsets.append(Vector3(cos(angle), 0.0, sin(angle)))
		_tally_spins.append(Vector3(
			1.4 + 0.6 * float(index % 3), 2.1, 0.9 - 0.4 * float(index % 2)))
		billet.scale = Vector3.ZERO


## World-scale silhouettes for the periodic tools and area effects whose gameplay
## otherwise resolves instantly. These are not a second authority: the real
## cut/target receipt has already resolved, and the ring only draws the radius
## the resolver actually used.
func _build_action(color: Color, action_value: float,
		action_variant: int, action_travel_value: float) -> void:
	if power_id not in ACTION_POWERS:
		return
	_action_kind = power_id
	_action_variant = action_variant
	_action_span = maxf(0.2, action_value) if power_id == &"crosscut_sweep" \
		else maxf(2.0, action_value)
	_action_travel_span = maxf(_action_span, action_travel_value)
	_action_root = Node3D.new()
	_action_root.name = "ActionSilhouette"
	add_child(_action_root)
	var tint := color.lerp(Color.WHITE, 0.12)
	var steel := RunPowerPropLibrary.material_for(
		Color(0.62, 0.71, 0.80, 1.0).lerp(tint, 0.22), &"action_steel")
	var accent := RunPowerPropLibrary.material_for(
		tint.lerp(Color(1.0, 0.94, 0.76, 1.0), 0.45), &"action_accent")
	var wood := RunPowerPropLibrary.material_for(
		Color(0.42, 0.24, 0.11, 1.0).lerp(tint, 0.12), &"action_wood")
	var area_material := RunPowerPropLibrary.material_for(tint, &"action_area")
	match power_id:
		&"flying_wedge":
			var wedge := PrismMesh.new()
			wedge.size = Vector3(0.20, 0.46, 0.11)
			wedge.material = steel
			var wedge_mesh := _action_mesh("FlyingWedge", wedge)
			wedge_mesh.rotation.x = -PI * 0.5
			var tail := BoxMesh.new()
			tail.size = Vector3(0.08, 0.08, 0.32)
			tail.material = accent
			var tail_mesh := _action_mesh("WedgeTail", tail)
			tail_mesh.position.z = 0.28
			_action_root.position = Vector3(0.0, 1.55, 0.62)
			_action_root.rotation.x = -0.72
		&"crosscut_sweep":
			var blade := BoxMesh.new()
			blade.size = Vector3(_action_span, 0.045, 0.12)
			blade.material = steel
			var blade_mesh := _action_mesh("CrosscutBlade", blade)
			_add_saw_teeth(blade_mesh, accent, _action_span)
			var alternate_axis := _action_variant % 2 != 0
			_action_root.position = Vector3(-_action_travel_span * 0.5, 0.16, 0.0) \
				if alternate_axis else Vector3(
					0.0, 0.16, -_action_travel_span * 0.5)
			_action_root.rotation.y = PI * 0.5 if alternate_axis else 0.0
		&"maul_drop":
			var head := BoxMesh.new()
			head.size = Vector3(0.62, 0.24, 0.28)
			head.material = steel
			var head_mesh := _action_mesh("MaulHead", head)
			var edge := PrismMesh.new()
			edge.size = Vector3(0.24, 0.20, 0.28)
			edge.material = accent
			var edge_mesh := MeshInstance3D.new()
			edge_mesh.name = "MaulEdge"
			edge_mesh.mesh = edge
			edge_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			edge_mesh.position.x = -0.40
			edge_mesh.rotation.z = PI * 0.5
			head_mesh.add_child(edge_mesh)
			var handle := CylinderMesh.new()
			handle.top_radius = 0.035
			handle.bottom_radius = 0.045
			handle.height = 0.82
			handle.radial_segments = 8
			handle.material = wood
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
			# A world-scale ring needs real slices around its circumference or
			# the true radius reads as a polygon on the yard floor.
			ring.rings = 56
			ring.ring_segments = 6
			ring.material = area_material
			var ring_mesh := _action_mesh("AreaRing", ring)
			_add_ring_ticks(ring_mesh, accent, _action_span)
			_action_root.position.y = 0.055


## Radial ticks make the ring's true radius legible against the yard floor
## without changing the fitted bounds the camera guard measures.
func _add_ring_ticks(ring_mesh: MeshInstance3D, material: ShaderMaterial,
		radius: float) -> void:
	for index: int in range(8):
		var angle := TAU * float(index) / 8.0
		var tick := BoxMesh.new()
		tick.size = Vector3(maxf(0.04, radius * 0.10), 0.03, 0.045)
		tick.material = material
		var instance := MeshInstance3D.new()
		instance.name = "RingTick%d" % (index + 1)
		instance.mesh = tick
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.position = Vector3(cos(angle) * radius, 0.0,
			sin(angle) * radius)
		instance.rotation.y = -angle
		ring_mesh.add_child(instance)


func _add_saw_teeth(blade_mesh: MeshInstance3D, material: ShaderMaterial,
		width: float) -> void:
	var teeth := clampi(int(round(width / 0.10)), 4, 24)
	for index: int in range(teeth):
		var tooth := PrismMesh.new()
		tooth.size = Vector3(0.05, 0.05, 0.12)
		tooth.material = material
		var instance := MeshInstance3D.new()
		instance.name = "SweepTooth%d" % (index + 1)
		instance.mesh = tooth
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.position = Vector3(
			-width * 0.5 + width * (float(index) + 0.5) / float(teeth),
			-0.045, 0.0)
		instance.rotation.z = PI
		blade_mesh.add_child(instance)


func _action_mesh(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_action_root.add_child(instance)
	_action_meshes.append(instance)
	return instance


func _build_label(text: String, color: Color) -> void:
	_label = Label3D.new()
	_label.name = "PowerName"
	_label.text = text.to_upper()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 34
	_label.outline_size = 10
	_label.pixel_size = 0.0025
	_label.modulate = color.lerp(Color.WHITE, 0.20)
	_label.position.y = _CONFIG.prop_label_height
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
	_light.position.y = _CONFIG.prop_ground_clearance
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
	_update_prop(k)
	_update_tally(k)
	_light.light_energy = _CONFIG.generic_light_energy * pulse
	_label.position.y = _CONFIG.prop_label_height + k * 0.30
	var label_color := _label.modulate
	label_color.a = 1.0 - smoothstep(0.56, 1.0, k)
	_label.modulate = label_color
	_update_action(k)
	if k >= 1.0:
		queue_free()


## Solid geometry cannot rely on an alpha fade under the Compatibility renderer,
## so the emblem announces and retires by scale: it pops in with a short
## overshoot, holds, rises, and shrinks out.
func _update_prop(k: float) -> void:
	if _prop_root == null:
		return
	var pop_span := maxf(0.02, _CONFIG.prop_pop_fraction)
	var pop := smoothstep(0.0, pop_span, k)
	var overshoot := 1.0 + 0.30 * sin(PI * clampf(k / pop_span, 0.0, 1.0))
	var retire := smoothstep(0.74, 1.0, k)
	_prop_root.scale = Vector3.ONE * maxf(0.0,
		_prop_base_scale * pop * overshoot * (1.0 - retire))
	_prop_root.position.y = _CONFIG.proc_log_base_clearance \
		+ _CONFIG.prop_ground_clearance + _CONFIG.prop_rise * smoothstep(
			0.0, 1.0, k)
	_prop_root.rotation.y = TAU * _CONFIG.prop_spin_turns * k


func _update_tally(k: float) -> void:
	for index: int in range(_tally_meshes.size()):
		var billet := _tally_meshes[index]
		if not is_instance_valid(billet):
			continue
		# A short per-billet stagger keeps a large payload readable as separate
		# logs; it is capped so even the ceiling count still clears the burst.
		var stagger := minf(0.24, 0.035 * float(index))
		var t := clampf((k - stagger) / maxf(0.2, 0.86 - stagger), 0.0, 1.0)
		var travel := 1.0 - pow(1.0 - t, 2.4)
		var offset: Vector3 = _tally_offsets[index]
		billet.position = offset * _CONFIG.prop_tally_radius * travel \
			+ Vector3.UP * _CONFIG.prop_tally_rise * sin(PI * t * 0.82)
		var spin: Vector3 = _tally_spins[index]
		billet.rotation = spin * t * 2.2
		billet.scale = Vector3.ONE * maxf(0.0,
			smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.72, 1.0, t)))


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
