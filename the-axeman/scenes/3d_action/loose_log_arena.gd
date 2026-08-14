class_name LooseLogArena
extends Node3D
## Physical waiting-log arena. It owns bodies and boundary presentation but asks
## RunDirector to decide deliveries, random claims, rewards and failure.

signal loose_count_changed(count: int)
signal boundary_warning(log_id: StringName, seconds_left: float)
signal breach_expired(log_id: StringName)
signal log_landed(log_id: StringName)

const LOOSE_LAYER := 1 << 4
const BLASTER_PICK_LAYER := 1 << 5

var _run: RunDirector
var _chopping: Node
var _tuning: SurvivalRunTuning
var _bodies: Dictionary = {}
var _paused := true
var _boundary_timers_paused := false
var _ring: MeshInstance3D
var _warning_material: StandardMaterial3D


func bind_run(run: RunDirector, chopping: Node, tuning: SurvivalRunTuning) -> void:
	_run = run
	_chopping = chopping
	_tuning = tuning
	_build_ring()


func spawn_loose_log(descriptor: LogDescriptor, physics_seed: int,
		restore: Dictionary = {}) -> LooseLogBody:
	if descriptor == null or not descriptor.is_valid() or _chopping == null:
		return null
	var mesh: Mesh = _chopping.call("build_run_log_mesh", descriptor)
	if mesh == null:
		return null
	var body := LooseLogBody.new()
	body.name = String(descriptor.id)
	body.descriptor = descriptor
	body.collision_layer = LOOSE_LAYER | BLASTER_PICK_LAYER
	body.collision_mask = 1 | LOOSE_LAYER
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.continuous_cd = true
	body.mass = maxf(0.5, _mesh_volume(mesh) * 650.0)
	body.linear_damp = 0.38
	body.angular_damp = 0.85
	body.physics_material_override = _physics_material()
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape()
	body.add_child(collision)
	add_child(body)
	_bodies[descriptor.id] = body
	body.body_entered.connect(_on_body_entered.bind(body))
	if restore.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = physics_seed
		body.global_position = _choose_spawn_position(rng) + Vector3.UP * _tuning.arrival_height
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.4),
			rng.randf_range(-1.0, 1.0)).normalized()
		body.quaternion = Quaternion(axis if axis.length() > 0.1 else Vector3.RIGHT,
			rng.randf_range(-PI, PI))
		var lateral := Vector3(rng.randf_range(-1.0, 1.0), 0.0,
			rng.randf_range(-1.0, 1.0)).normalized()
		body.linear_velocity = lateral * _tuning.arrival_lateral_speed
		body.angular_velocity = Vector3(rng.randf_range(-1.5, 1.5),
			rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
	else:
		body.global_transform = restore.get("transform", Transform3D.IDENTITY)
		body.linear_velocity = restore.get("linear_velocity", Vector3.ZERO)
		body.angular_velocity = restore.get("angular_velocity", Vector3.ZERO)
		body.boundary_exposure = maxf(0.0, float(restore.get("boundary_exposure", 0.0)))
		body.landed = bool(restore.get("landed", false))
	body.freeze = _paused
	loose_count_changed.emit(_bodies.size())
	return body


func advance_hazards(hazard_delta: float, hazard_speed: float) -> void:
	if _paused or hazard_delta <= 0.0:
		return
	var expired: Array[StringName] = []
	for raw_id: Variant in _bodies:
		var id := StringName(raw_id)
		var body := _bodies[id] as LooseLogBody
		if not is_instance_valid(body):
			expired.append(id)
			continue
		body.set_hazard_speed(hazard_speed)
		if _boundary_timers_paused:
			continue
		var horizontal := Vector2(body.global_position.x, body.global_position.z).length()
		if horizontal > _tuning.boundary_radius:
			body.boundary_exposure += hazard_delta
			_set_warning(body, true)
			var left := maxf(0.0, _tuning.boundary_grace_seconds - body.boundary_exposure)
			boundary_warning.emit(id, left)
			if left <= 0.0:
				expired.append(id)
		else:
			if body.boundary_exposure > 0.0:
				body.boundary_exposure = 0.0
				boundary_warning.emit(id, -1.0)
			_set_warning(body, false)
	for id: StringName in expired:
		if _bodies.has(id):
			breach_expired.emit(id)


func eligible_log_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for raw_id: Variant in _bodies:
		var body := _bodies[raw_id] as LooseLogBody
		if is_instance_valid(body) and body.landed:
			out.append(StringName(raw_id))
	return out


## The next manual log rescues the most urgent breach first, even if that body is
## still settling. Returning an empty id means every log is safely inside the
## circle, in which case RunDirector retains the normal random landed choice.
func highest_risk_outside_log_id() -> StringName:
	var target: LooseLogBody
	for body: LooseLogBody in _live_bodies():
		var horizontal := Vector2(body.global_position.x, body.global_position.z).length()
		if horizontal <= _tuning.boundary_radius:
			continue
		if target == null or body.boundary_exposure > target.boundary_exposure:
			target = body
	return &"" if target == null else target.descriptor.id


func claim_for_block(id: StringName) -> LogDescriptor:
	var body := _take_body(id, false)
	if body == null:
		return null
	var descriptor := body.descriptor
	descriptor.transfer_from = body.global_position
	descriptor.transfer_rotation = body.quaternion
	body.queue_free()
	return descriptor


func claim_highest_risk_for_splitter() -> LogDescriptor:
	var target: LooseLogBody
	for body: LooseLogBody in _live_bodies():
		if target == null or body.boundary_exposure > target.boundary_exposure:
			target = body
	if target == null:
		return null
	var descriptor := target.descriptor
	_take_body(descriptor.id, true)
	return descriptor


func blast(ray_origin: Vector3, ray_direction: Vector3, impulse: float) -> bool:
	if _paused or get_world_3d() == null:
		return false
	var direction := ray_direction.normalized()
	var query := PhysicsRayQueryParameters3D.create(ray_origin,
		ray_origin + direction * 100.0, BLASTER_PICK_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is LooseLogBody):
		return false
	var body := hit.collider as LooseLogBody
	if not _bodies.has(body.descriptor.id):
		return false
	body.apply_impulse(direction * impulse, hit.position - body.global_position)
	return true


func loose_log_count() -> int:
	return _bodies.size()


func clear_all() -> void:
	for body: LooseLogBody in _live_bodies():
		if body.descriptor != null:
			boundary_warning.emit(body.descriptor.id, -1.0)
		body.queue_free()
	_bodies.clear()
	loose_count_changed.emit(0)


func set_hazards_paused(value: bool) -> void:
	_paused = value
	for body: LooseLogBody in _live_bodies():
		body.freeze = value


## This is intentionally narrower than set_hazards_paused(): logs and delivery
## physics keep moving while the empty block changes over, but an existing
## breach countdown cannot end the run between completed logs.
func set_boundary_timers_paused(value: bool) -> void:
	_boundary_timers_paused = value


func to_save_dict() -> Dictionary:
	var logs: Array[Dictionary] = []
	for body: LooseLogBody in _live_bodies():
		logs.append(body.to_save_dict())
	return {"logs": logs}


func restore_from_save(data: Dictionary) -> void:
	clear_all()
	_paused = true
	var logs: Variant = data.get("logs", [])
	if not (logs is Array):
		return
	for raw: Variant in logs:
		if not (raw is Dictionary):
			continue
		var descriptor_data: Variant = raw.get("descriptor", {})
		if not (descriptor_data is Dictionary):
			continue
		var descriptor := LogDescriptor.from_save_dict(descriptor_data)
		spawn_loose_log(descriptor, descriptor.visual_seed, raw)


func _take_body(id: StringName, splitter: bool) -> LooseLogBody:
	var body := _bodies.get(id) as LooseLogBody
	if not is_instance_valid(body):
		return null
	_bodies.erase(id)
	_set_warning(body, false)
	boundary_warning.emit(id, -1.0)
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true
	loose_count_changed.emit(_bodies.size())
	if splitter:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(body, "position",
			body.position + Vector3(2.4, 0.7, -0.8), 0.28)
		tween.tween_callback(body.queue_free)
	return body


func _on_body_entered(other: Node, body: LooseLogBody) -> void:
	if body.landed or not _bodies.has(body.descriptor.id):
		return
	if other is StaticBody3D:
		body.landed = true
		log_landed.emit(body.descriptor.id)


func _choose_spawn_position(rng: RandomNumberGenerator) -> Vector3:
	var best := Vector3.ZERO
	var best_clearance := -INF
	for _sample in range(_tuning.spawn_sample_count):
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf_range(
			_tuning.spawn_inner_radius * _tuning.spawn_inner_radius,
			_tuning.spawn_outer_radius * _tuning.spawn_outer_radius))
		var candidate := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var clearance := _minimum_clearance(candidate)
		if clearance > best_clearance:
			best = candidate
			best_clearance = clearance
	return best


func _minimum_clearance(candidate: Vector3) -> float:
	if _bodies.is_empty():
		return INF
	var minimum := INF
	for body: LooseLogBody in _live_bodies():
		var delta := Vector2(candidate.x - body.global_position.x,
			candidate.z - body.global_position.z)
		minimum = minf(minimum, delta.length_squared())
	return minimum


func _set_warning(body: LooseLogBody, enabled: bool) -> void:
	var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	mesh.material_overlay = _warning_overlay() if enabled else null
	var label := body.get_node_or_null("BoundaryCountdown") as Label3D
	if enabled:
		if label == null:
			label = Label3D.new()
			label.name = "BoundaryCountdown"
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 34
			label.outline_size = 8
			label.pixel_size = 0.003
			label.modulate = Color(1.0, 0.24, 0.18)
			label.position = Vector3.UP * 0.7
			body.add_child(label)
		label.text = "%.1f" % maxf(0.0,
			_tuning.boundary_grace_seconds - body.boundary_exposure)
	else:
		if label != null:
			label.queue_free()


func _warning_overlay() -> StandardMaterial3D:
	if _warning_material == null:
		_warning_material = StandardMaterial3D.new()
		_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warning_material.albedo_color = Color(1.0, 0.05, 0.02, 0.38)
		_warning_material.no_depth_test = true
	return _warning_material


func _physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.05
	return material


func _mesh_volume(mesh: Mesh) -> float:
	var size := mesh.get_aabb().size
	return maxf(0.001, size.x * size.y * size.z)


func _live_bodies() -> Array[LooseLogBody]:
	var out: Array[LooseLogBody] = []
	for body: Variant in _bodies.values():
		if body is LooseLogBody and is_instance_valid(body):
			out.append(body)
	return out


func _build_ring() -> void:
	if _ring != null or _tuning == null:
		return
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var radii := PackedFloat32Array([
		_tuning.boundary_radius - _tuning.boundary_gradient_width,
		_tuning.boundary_radius - _tuning.boundary_core_half_width,
		_tuning.boundary_radius + _tuning.boundary_core_half_width,
		_tuning.boundary_radius + _tuning.boundary_gradient_width,
	])
	var alphas := PackedFloat32Array([
		0.0, _tuning.boundary_peak_alpha,
		_tuning.boundary_peak_alpha, 0.0,
	])
	const SEGMENTS := 96
	for segment: int in range(SEGMENTS + 1):
		var angle := TAU * float(segment) / float(SEGMENTS)
		for band: int in range(radii.size()):
			vertices.append(Vector3(cos(angle) * radii[band], 0.0,
				sin(angle) * radii[band]))
			normals.append(Vector3.UP)
			colors.append(Color(0.98, 0.035, 0.02, alphas[band]))
	for segment: int in range(SEGMENTS):
		for band: int in range(radii.size() - 1):
			var current := segment * radii.size() + band
			var next := (segment + 1) * radii.size() + band
			indices.append_array(PackedInt32Array([
				current, next, current + 1,
				current + 1, next, next + 1,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The ring is painted onto the yard floor, not a screen-space hazard overlay:
	# ordinary depth lets logs, the stump, and other world geometry occlude it.
	material.no_depth_test = false
	mesh.surface_set_material(0, material)
	_ring = MeshInstance3D.new()
	_ring.name = "RedBoundary"
	_ring.mesh = mesh
	_ring.position.y = 0.018
	add_child(_ring)
