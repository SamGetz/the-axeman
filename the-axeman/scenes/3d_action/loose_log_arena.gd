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
const CHOPPING_VISIBILITY_DOME_LAYER := 1 << 6
const _BASE_BOUNCE := 0.05
const OFF_BLOCK_COMPLETION_CUTS := 5

var _run: RunDirector
var _chopping: Node
var _tuning: SurvivalRunTuning
var _bodies: Dictionary = {}
var _paused := true
var _boundary_timers_paused := false
var _ring: MeshInstance3D
var _warning_material: StandardMaterial3D
var _effective_boundary_radius := 0.0
var _effective_boundary_radius_squared := 0.0
var _effective_boundary_grace := 0.0
var _arrival_lateral_multiplier := 1.0
var _arrival_bounce_multiplier := 1.0
var _arrival_outward_multiplier := 1.0
var _yard_magnet_force := 0.0
var _visibility_dome: StaticBody3D
var _batch_root: Node3D
var _visual_batches: Dictionary = {}
var _dirty_batch_keys: Dictionary = {}


func bind_run(run: RunDirector, chopping: Node, tuning: SurvivalRunTuning) -> void:
	_run = run
	_chopping = chopping
	_tuning = tuning
	_effective_boundary_radius = tuning.boundary_radius if tuning != null else 0.0
	_effective_boundary_radius_squared = _effective_boundary_radius \
		* _effective_boundary_radius
	_effective_boundary_grace = tuning.boundary_grace_seconds if tuning != null else 0.0
	if _batch_root == null:
		_batch_root = Node3D.new()
		_batch_root.name = "SleepingLogBatches"
		add_child(_batch_root)
	_build_ring()
	_build_chopping_visibility_dome()


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
	body.collision_mask = 1 | LOOSE_LAYER | CHOPPING_VISIBILITY_DOME_LAYER
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.continuous_cd = true
	body.mass = maxf(0.5, _mesh_volume(mesh) * 650.0)
	body.linear_damp = 0.38
	body.angular_damp = 0.85
	body.arrival_gravity_scale = pow(
		maxf(0.01, _tuning.arrival_fall_speed_multiplier), 2.0)
	body.gravity_scale = body.arrival_gravity_scale
	body.arrival_bounce_multiplier = maxf(0.0, float(restore.get(
		"arrival_bounce_multiplier", _arrival_bounce_multiplier))) \
		if not restore.is_empty() else _arrival_bounce_multiplier
	body.physics_material_override = _physics_material(body.arrival_bounce_multiplier)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	visual.set_meta("stable_piece_id", descriptor.id)
	visual.set_meta("is_firewood", false)
	visual.set_meta("projection_offset", Vector3.ZERO)
	body.add_child(visual)
	body.piece_visuals.append(visual)
	var collision := CollisionShape3D.new()
	collision.shape = MeshUtils.convex_shape(mesh)
	body.add_child(collision)
	body.collision_shapes.append(collision)
	add_child(body)
	_bodies[descriptor.id] = body
	body.body_entered.connect(_on_body_entered.bind(body))
	body.body_exited.connect(_on_body_exited.bind(body))
	body.sleeping_state_changed.connect(_on_sleeping_state_changed.bind(body))
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
		var velocity := lateral * _tuning.arrival_lateral_speed \
			* _arrival_lateral_multiplier
		var radial := Vector3(body.global_position.x, 0.0,
			body.global_position.z).normalized()
		var outward_speed := maxf(0.0, velocity.dot(radial))
		velocity -= radial * outward_speed * (1.0 - _arrival_outward_multiplier)
		body.linear_velocity = velocity
		body.angular_velocity = Vector3(rng.randf_range(-1.5, 1.5),
			rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
	else:
		body.global_transform = restore.get("transform", Transform3D.IDENTITY)
		body.linear_velocity = restore.get("linear_velocity", Vector3.ZERO)
		body.angular_velocity = restore.get("angular_velocity", Vector3.ZERO)
		body.boundary_exposure = maxf(0.0, float(restore.get("boundary_exposure", 0.0)))
		body.landed = bool(restore.get("landed", false))
	body.freeze = _paused
	if descriptor.pending_power_cuts > 0:
		_replay_saved_power_cuts(body)
	_refresh_power_marker(body)
	if body.landed:
		try_batch_visual(body)
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
		var horizontal_squared := Vector2(body.global_position.x,
			body.global_position.z).length_squared()
		if horizontal_squared > _effective_boundary_radius_squared:
			body.boundary_exposure += hazard_delta
			var left := maxf(0.0, _effective_boundary_grace - body.boundary_exposure)
			if _set_warning(body, true, left):
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
		if horizontal <= _effective_boundary_radius:
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
	_snapshot_handoff_visuals(body, descriptor)
	body.queue_free()
	return descriptor


func _snapshot_handoff_visuals(body: LooseLogBody,
		descriptor: LogDescriptor) -> void:
	descriptor.transfer_visual_meshes.clear()
	descriptor.transfer_visual_transforms.clear()
	descriptor.transfer_visual_projection_offsets.clear()
	descriptor.transfer_visual_overlays.clear()
	var body_inverse := body.global_transform.affine_inverse()
	for visual: MeshInstance3D in _piece_visuals(body):
		if visual.mesh == null:
			continue
		descriptor.transfer_visual_meshes.append(visual.mesh)
		descriptor.transfer_visual_transforms.append(
			body_inverse * visual.global_transform)
		descriptor.transfer_visual_projection_offsets.append(
			visual.get_meta("projection_offset", Vector3.ZERO))
		descriptor.transfer_visual_overlays.append(visual.material_overlay)


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


## Run-power environment is derived by RunDirector from immutable catalogue
## effects. Arrival multipliers affect future bodies only; boundary values are
## live and therefore rebuild the rendered ring immediately.
func set_run_power_environment(boundary_radius: float, boundary_grace: float,
		arrival_lateral_multiplier: float, arrival_bounce_multiplier: float,
		arrival_outward_multiplier: float) -> void:
	var next_radius := maxf(0.1, boundary_radius)
	var radius_changed := not is_equal_approx(next_radius, _effective_boundary_radius)
	_effective_boundary_radius = next_radius
	_effective_boundary_radius_squared = next_radius * next_radius
	_effective_boundary_grace = maxf(0.0, boundary_grace)
	_arrival_lateral_multiplier = maxf(0.0, arrival_lateral_multiplier)
	_arrival_bounce_multiplier = maxf(0.0, arrival_bounce_multiplier)
	_arrival_outward_multiplier = maxf(0.0, arrival_outward_multiplier)
	if radius_changed:
		_rebuild_ring()


func apply_yard_magnet(force: float, delta: float) -> int:
	if delta <= 0.0:
		return 0
	_yard_magnet_force = maxf(0.0, force)
	if force <= 0.0:
		for body: LooseLogBody in _live_bodies():
			_release_yard_magnet_drag(body)
		return 0
	var eligible := 0
	for body: LooseLogBody in _live_bodies():
		if body.grounded:
			eligible += 1
	return eligible


## Physics, rather than render cadence, owns the arcade ground servo. This
## prevents contacts from alternating with process-frame velocity writes.
func _physics_process(delta: float) -> void:
	if _paused or _yard_magnet_force <= 0.0 or delta <= 0.0:
		return
	_advance_yard_magnet_drag(_yard_magnet_force, delta)


## Sleeping intact roots keep their individual physics owners but share one
## MultiMesh per immutable log mesh. Physics/query/save identity is unchanged;
## only hundreds of identical render submissions collapse into a few batches.
func _process(_delta: float) -> void:
	_flush_visual_batches()


func ensure_individual_visual(body: LooseLogBody) -> void:
	_unbatch_body(body)


func try_batch_visual(body: LooseLogBody) -> void:
	if body == null or not is_instance_valid(body) or body.descriptor == null \
			or not _bodies.has(body.descriptor.id) or not body.landed \
			or (not body.sleeping and not body.freeze) or body.warning_active \
			or body.magnet_engaged or body.descriptor.pending_power_cuts > 0 \
			or body.descriptor.pending_power_scars > 0 \
			or body.piece_visuals.size() != 1:
		return
	var visual := body.piece_visuals[0]
	if not is_instance_valid(visual) or visual.mesh == null \
			or visual.material_overlay != null or visual.transparency > 0.001:
		return
	var key := int(visual.mesh.get_instance_id())
	if body.batched_visual and body.batch_key == key:
		return
	_unbatch_body(body)
	var entry: Dictionary = _visual_batches.get(key, {})
	if entry.is_empty():
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.mesh = visual.mesh
		var instance := MultiMeshInstance3D.new()
		instance.name = "LogBatch_%d" % key
		instance.multimesh = multi_mesh
		instance.cast_shadow = visual.cast_shadow
		_batch_root.add_child(instance)
		entry = {"instance": instance, "bodies": []}
	var bodies := entry.get("bodies", []) as Array
	if not bodies.has(body):
		bodies.append(body)
	entry["bodies"] = bodies
	_visual_batches[key] = entry
	body.batched_visual = true
	body.batch_key = key
	visual.visible = false
	_dirty_batch_keys[key] = true


func _unbatch_body(body: LooseLogBody) -> void:
	if body == null or not body.batched_visual:
		return
	var key := body.batch_key
	var entry: Dictionary = _visual_batches.get(key, {})
	if not entry.is_empty():
		var bodies := entry.get("bodies", []) as Array
		bodies.erase(body)
		entry["bodies"] = bodies
		_visual_batches[key] = entry
		_dirty_batch_keys[key] = true
	body.batched_visual = false
	body.batch_key = 0
	for visual: MeshInstance3D in body.piece_visuals:
		if is_instance_valid(visual):
			visual.visible = true


func _on_sleeping_state_changed(body: LooseLogBody) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.sleeping:
		try_batch_visual(body)
	else:
		_unbatch_body(body)


func _flush_visual_batches() -> void:
	if _dirty_batch_keys.is_empty():
		return
	var keys := _dirty_batch_keys.keys()
	_dirty_batch_keys.clear()
	for raw_key: Variant in keys:
		var key := int(raw_key)
		var entry: Dictionary = _visual_batches.get(key, {})
		if entry.is_empty():
			continue
		var source_bodies := entry.get("bodies", []) as Array
		var bodies: Array[LooseLogBody] = []
		for raw_body: Variant in source_bodies:
			var body := raw_body as LooseLogBody
			if body != null and is_instance_valid(body) and body.batched_visual \
					and body.batch_key == key and body.piece_visuals.size() == 1:
				bodies.append(body)
		var instance := entry.get("instance") as MultiMeshInstance3D
		if bodies.is_empty():
			if is_instance_valid(instance):
				instance.queue_free()
			_visual_batches.erase(key)
			continue
		var multi_mesh := instance.multimesh if is_instance_valid(instance) else null
		if multi_mesh == null:
			continue
		multi_mesh.instance_count = bodies.size()
		for index: int in range(bodies.size()):
			var body := bodies[index]
			var visual := body.piece_visuals[0]
			multi_mesh.set_instance_transform(index, body.transform * visual.transform)
		entry["bodies"] = bodies
		_visual_batches[key] = entry


func _advance_yard_magnet_drag(force: float, delta: float) -> int:
	var affected := 0
	for body: LooseLogBody in _live_bodies():
		if not body.grounded:
			_release_yard_magnet_drag(body)
			continue
		var pulse_just_engaged := not body.magnet_engaged
		_engage_yard_magnet_drag(body)
		var target := yard_magnet_dock_world_position(body)
		var to_block := target - body.global_position
		to_block.y = 0.0
		var distance := to_block.length()
		if distance <= 0.002:
			body.magnet_drag_speed = 0.0
			body.linear_velocity = Vector3.UP * minf(
				body.linear_velocity.y, 0.0)
			body.angular_velocity = Vector3.ZERO
			affected += 1
			continue
		var toward := to_block / distance
		# Yard Magnet is a controlled draw, not another free impulse. Discard
		# sideways/outward floor motion, advance a controller-owned speed ramp, cap
		# it at the authored rank value, and brake before crossing the target. The
		# ramp deliberately ignores collision-modified velocity so a floor contact
		# cannot make Rank 1 look stationary on every subsequent frame.
		var brake_distance := maxf(0.001,
			_tuning.yard_magnet_brake_distance)
		var brake_ratio := smoothstep(0.0, 1.0,
			clampf(distance / brake_distance, 0.0, 1.0))
		var desired_speed := force * brake_ratio
		# A half-second pulse must read immediately. Enter at the authored capped
		# speed on its first physics tick; subsequent ticks retain the smooth
		# controller-owned ramp and braking behavior used near the stump.
		var next_speed := desired_speed if pulse_just_engaged else minf(
			desired_speed, body.magnet_drag_speed + force * delta)
		next_speed = minf(next_speed, distance / delta)
		body.magnet_drag_speed = next_speed
		# A floor-gated magnet must remain a drag, not alternate between one frame
		# of pull and one frame of arrival bounce. Consume upward velocity and
		# tumbling only after proven floor contact; gravity then keeps the body on
		# the yard while its capped planar velocity advances smoothly to the block.
		body.linear_velocity = toward * next_speed \
			+ Vector3.UP * minf(body.linear_velocity.y, 0.0)
		body.angular_velocity = Vector3.ZERO
		affected += 1
	return affected


func yard_magnet_dock_world_position(body: LooseLogBody) -> Vector3:
	var centre := yard_magnet_target_world_position()
	if body == null or not is_instance_valid(body):
		return centre
	if body.magnet_dock_direction.length_squared() <= 0.000001:
		var away := Vector2(body.global_position.x - centre.x,
			body.global_position.z - centre.z)
		body.magnet_dock_direction = away.normalized() \
			if away.length_squared() > 0.000001 else Vector2.RIGHT
	var required_radius := _yard_magnet_stump_radius() \
		+ _body_planar_radius(body) + _tuning.yard_magnet_dock_margin
	body.magnet_dock_radius = maxf(body.magnet_dock_radius, required_radius)
	return Vector3(
		centre.x + body.magnet_dock_direction.x * body.magnet_dock_radius,
		body.global_position.y,
		centre.z + body.magnet_dock_direction.y * body.magnet_dock_radius)


func _yard_magnet_stump_radius() -> float:
	if _chopping != null and _chopping.has_method(
			&"yard_magnet_stump_collision_radius"):
		return maxf(0.0, float(_chopping.call(
			&"yard_magnet_stump_collision_radius")))
	return 0.0


func _body_planar_radius(body: LooseLogBody) -> float:
	var radius := 0.0
	for visual: MeshInstance3D in _piece_visuals(body):
		if visual.mesh == null:
			continue
		var aabb := visual.mesh.get_aabb()
		for corner_index: int in range(8):
			var corner := Vector3(
				aabb.end.x if (corner_index & 1) != 0 else aabb.position.x,
				aabb.end.y if (corner_index & 2) != 0 else aabb.position.y,
				aabb.end.z if (corner_index & 4) != 0 else aabb.position.z)
			# A waiting root can land on any face. Measure its current world-planar
			# support rather than assuming the authored upright mesh orientation;
			# otherwise a long root lying sideways can be given a dock inside the
			# stump even though an upright acceptance fixture clears it.
			var local_corner := visual.global_transform.basis * corner
			radius = maxf(radius,
				Vector2(local_corner.x, local_corner.z).length())
	return radius


func _engage_yard_magnet_drag(body: LooseLogBody) -> void:
	if body == null or not is_instance_valid(body):
		return
	_unbatch_body(body)
	if not body.magnet_engaged:
		body.magnet_engaged = true
		body.magnet_restore_linear_damp = body.linear_damp
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true
	body.linear_damp = 0.0
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	var physics_material := body.physics_material_override
	if physics_material != null:
		# Static floor friction was cancelling Rank 1's deliberately small target
		# speed. A magnetised root glides; ordinary airborne/finished physics gets
		# the authored friction and bounce back when this controller releases it.
		physics_material.friction = 0.0
		physics_material.bounce = 0.0


func _release_yard_magnet_drag(body: LooseLogBody) -> void:
	if body == null or not is_instance_valid(body) or not body.magnet_engaged:
		return
	body.magnet_engaged = false
	body.magnet_drag_speed = 0.0
	body.magnet_dock_direction = Vector2.ZERO
	body.magnet_dock_radius = 0.0
	body.axis_lock_angular_x = false
	body.axis_lock_angular_y = false
	body.axis_lock_angular_z = false
	body.linear_damp = body.magnet_restore_linear_damp
	var physics_material := body.physics_material_override
	if physics_material != null:
		physics_material.friction = 0.8
		physics_material.bounce = _BASE_BOUNCE \
			* maxf(0.0, body.arrival_bounce_multiplier)


func yard_magnet_target_world_position() -> Vector3:
	if _chopping != null and _chopping.has_method(
			&"yard_magnet_target_world_position"):
		var target: Variant = _chopping.call(
			&"yard_magnet_target_world_position")
		if target is Vector3:
			return target as Vector3
	if _chopping is Node3D:
		return (_chopping as Node3D).global_position
	return global_position


## Applies bounded real cuts immediately to loose roots. Each hit splits the
## largest unfinished descendant with a log-local top-to-bottom X/Z plane; the
## descriptor retains successful cut/source receipts for restore and later block
## claims.
func queue_power_cuts(power_id: StringName, count: int,
		origin: Vector3 = Vector3.ZERO, max_range: float = INF,
		mode: StringName = &"endangered", excluded_ids: Array = []) -> Array[Dictionary]:
	var applied: Dictionary = {}
	var hit_positions: Dictionary = {}
	var touched: Dictionary = {}
	if count <= 0:
		return []
	var candidates := _ordered_power_targets(origin, max_range, mode, excluded_ids)
	if candidates.is_empty():
		return []
	# Wedge, maul, and restored nearest-root Splinter Volley payloads name one
	# authoritative target. Explicit spread/radial/chain modes retain rotation.
	if mode in [&"endangered", &"hardest", &"nearest_single"]:
		candidates.resize(1)
	for index: int in range(count):
		var body := candidates[index % candidates.size()] as LooseLogBody
		if body == null or body.descriptor == null \
				or not _bodies.has(body.descriptor.id):
			continue
		var hit_position := body.global_position
		if not _apply_power_cut(body, power_id, false, true, false):
			continue
		var id := body.descriptor.id
		applied[id] = int(applied.get(id, 0)) + 1
		hit_positions[id] = hit_position
		touched[id] = body
	for raw_id: Variant in touched:
		var body := touched[raw_id] as LooseLogBody
		if body == null or not is_instance_valid(body) or body.descriptor == null \
				or not _bodies.has(body.descriptor.id):
			continue
		_rebuild_body_collisions(body)
		_flash_power_cut(body)
		_refresh_power_marker(body)
	var receipts := _target_receipts(power_id, applied, &"cuts")
	for receipt: Dictionary in receipts:
		var id := StringName(receipt.get("log_id", ""))
		if hit_positions.has(id):
			receipt["position"] = hit_positions[id]
	return receipts


func queue_power_scars(power_id: StringName, count: int,
		origin: Vector3 = Vector3.ZERO, max_range: float = INF,
		mode: StringName = &"nearest") -> Array[Dictionary]:
	var applied: Dictionary = {}
	if count <= 0:
		return []
	var candidates := _ordered_power_targets(origin, max_range, mode, [])
	for index: int in range(mini(count, candidates.size())):
		var body := candidates[index] as LooseLogBody
		if body == null or body.descriptor == null:
			continue
		body.descriptor.pending_power_scars = _safe_pending_add(
			body.descriptor.pending_power_scars, 1)
		applied[body.descriptor.id] = 1
		_refresh_power_marker(body)
	return _target_receipts(power_id, applied, &"scars")


## Completes every loose root inside a circular AoE with real descendant cuts.
## Target count still comes from live geometry, so Area Size only increases the
## reach; it does not silently add ranks or affect roots outside the authored
## circle.
func cut_all_in_radius(power_id: StringName, origin: Vector3,
		radius: float) -> Array[Dictionary]:
	var applied: Dictionary = {}
	var hit_positions: Dictionary = {}
	if radius <= 0.0:
		return []
	for body: LooseLogBody in _ordered_power_targets(
			origin, radius, &"nearest", []):
		if body == null or body.descriptor == null \
				or not _bodies.has(body.descriptor.id):
			continue
		var id := body.descriptor.id
		var hit_position := body.global_position
		var cut_count := _complete_power_cut_target(body, power_id)
		if cut_count <= 0:
			continue
		applied[id] = cut_count
		hit_positions[id] = hit_position
	var receipts := _target_receipts(power_id, applied, &"cuts")
	for receipt: Dictionary in receipts:
		var id := StringName(receipt.get("log_id", ""))
		if hit_positions.has(id):
			receipt["position"] = hit_positions[id]
	return receipts


func apply_inward_pulse(power_id: StringName, origin: Vector3,
		radius: float, force: float) -> Array[Dictionary]:
	var affected: Array[Dictionary] = []
	if radius <= 0.0 or force <= 0.0:
		return affected
	# `origin` selects the effect's local AoE (important for off-block Powder Keg
	# completions), but "inward" always means toward the chopping block. Using an
	# off-centre strike point as the velocity target could pull roots toward the
	# arena edge even though the event itself correctly found nearby targets.
	var draw_target := yard_magnet_target_world_position()
	for body: LooseLogBody in _ordered_power_targets(origin, radius, &"nearest", []):
		if not _set_strict_inward_velocity(body, draw_target, force):
			continue
		affected.append({
			"power_id": String(power_id),
			"log_id": String(body.descriptor.id),
			"force": force,
		})
	return affected


func pull_highest_risk(power_id: StringName, force: float) -> Dictionary:
	if force <= 0.0:
		return {}
	var targets := _ordered_power_targets(Vector3.ZERO, INF, &"endangered", [])
	if targets.is_empty():
		return {}
	var body := targets[0] as LooseLogBody
	if not _set_strict_inward_velocity(body,
			yard_magnet_target_world_position(), force):
		return {}
	return {
		"power_id": String(power_id),
		"log_id": String(body.descriptor.id),
		"force": force,
	}


## Draw-in powers are controlled movement, not free impulses. Replacing the
## planar velocity removes every outward and tangential component. The authored
## force is the exact target speed—not another acceleration—so repeated pulses
## also cap an already-fast inward root before it can shoot through the centre.
## Positive vertical velocity is consumed as well, so a pull can never turn a
## floor log into an airborne projectile.
func _set_strict_inward_velocity(body: LooseLogBody, origin: Vector3,
		force: float) -> bool:
	if body == null or not is_instance_valid(body) or force <= 0.0:
		return false
	var to_origin := origin - body.global_position
	to_origin.y = 0.0
	if to_origin.length_squared() <= 0.000001:
		return false
	_unbatch_body(body)
	var inward := to_origin.normalized()
	body.linear_velocity = inward * force \
		+ Vector3.UP * minf(body.linear_velocity.y, 0.0)
	return true


func rescue_log(id: StringName) -> bool:
	var body := _bodies.get(id) as LooseLogBody
	if not is_instance_valid(body):
		return false
	_unbatch_body(body)
	var flat := Vector2(body.global_position.x, body.global_position.z)
	var direction := flat.normalized() if flat.length_squared() > 0.000001 \
		else Vector2.RIGHT
	var safe_radius := maxf(0.1, _effective_boundary_radius * 0.5)
	body.global_position = Vector3(direction.x * safe_radius,
		maxf(0.15, body.global_position.y), direction.y * safe_radius)
	body.linear_velocity = Vector3(-direction.x, 0.0, -direction.y) \
		* body.linear_velocity.length()
	body.boundary_exposure = 0.0
	_set_warning(body, false)
	boundary_warning.emit(id, -1.0)
	return true


func claim_endangered_non_boss_for_splitter() -> LogDescriptor:
	for body: LooseLogBody in _ordered_power_targets(
			Vector3.ZERO, INF, &"endangered", []):
		if body.descriptor == null or body.descriptor.boss_id != &"":
			continue
		var descriptor := body.descriptor
		_take_body(descriptor.id, true)
		return descriptor
	return null


func crosscut_sweep(power_id: StringName, width: float,
		horizontal_axis: int) -> Array[Dictionary]:
	var applied: Dictionary = {}
	if width <= 0.0:
		return []
	var half_width := width * 0.5
	for body: LooseLogBody in _live_bodies():
		var coordinate := body.global_position.x if horizontal_axis == 0 \
			else body.global_position.z
		if absf(coordinate) > half_width or body.descriptor == null:
			continue
		var id := body.descriptor.id
		var cut_count := _complete_power_cut_target(body, power_id)
		if cut_count <= 0:
			continue
		applied[id] = cut_count
	return _target_receipts(power_id, applied, &"cuts")


## Resolve contacts at the rendered axes' actual world positions. Each visible
## axe may complete at most one loose root per update, and one root cannot be hit
## by an axe drawn on the opposite side of the orbit.
func queue_orbiting_axe_contacts(power_id: StringName, axes: Array,
		excluded_ids: Array = []) -> Array[Dictionary]:
	if axes.is_empty():
		return []
	var applied: Dictionary = {}
	for raw_axe: Variant in axes:
		if not (raw_axe is Dictionary):
			continue
		var axe := raw_axe as Dictionary
		var axe_position: Variant = axe.get("position", null)
		if not (axe_position is Vector3):
			continue
		var axe_radius := maxf(0.0, float(axe.get("contact_radius", 0.0)))
		var candidates: Array[LooseLogBody] = []
		for body: LooseLogBody in _live_bodies():
			if body.descriptor == null or body.descriptor.id in excluded_ids \
					or applied.has(body.descriptor.id):
				continue
			if body.global_position.distance_to(axe_position as Vector3) \
					<= _body_contact_radius(body) + axe_radius:
				candidates.append(body)
		candidates.sort_custom(func(left: LooseLogBody, right: LooseLogBody) -> bool:
			var left_distance := left.global_position.distance_squared_to(
				axe_position as Vector3)
			var right_distance := right.global_position.distance_squared_to(
				axe_position as Vector3)
			if not is_equal_approx(left_distance, right_distance):
				return left_distance < right_distance
			return String(left.descriptor.id) < String(right.descriptor.id))
		if candidates.is_empty():
			continue
		var body := candidates[0]
		var id := body.descriptor.id
		var cut_count := _complete_power_cut_target(body, power_id)
		if cut_count <= 0:
			continue
		applied[id] = cut_count
	return _target_receipts(power_id, applied, &"cuts")


func get_log_world_position(id: StringName) -> Vector3:
	var body := _bodies.get(id) as LooseLogBody
	return body.global_position if is_instance_valid(body) else Vector3.ZERO


func get_run_power_runtime_state() -> Dictionary:
	var bodies: Dictionary = {}
	for body: LooseLogBody in _live_bodies():
		if body.descriptor == null:
			continue
		bodies[String(body.descriptor.id)] = {
			"pending_power_cuts": body.descriptor.pending_power_cuts,
			"pending_power_cut_sources": _serialized_cut_sources(
				body.descriptor.pending_power_cut_sources),
			"pending_power_scars": body.descriptor.pending_power_scars,
			"position": body.global_position,
			"linear_velocity": body.linear_velocity,
			"boundary_exposure": body.boundary_exposure,
			"arrival_bounce_multiplier": body.arrival_bounce_multiplier,
			"piece_count": _piece_visuals(body).size(),
			"choppable_piece_count": _choppable_piece_count(body),
			"power_cut_flash_count": int(body.get_meta(
				"power_cut_flash_count", 0)),
			"power_cut_axes": (body.get_meta("power_cut_axes", []) as Array).duplicate(),
			"power_cut_local_planes": (body.get_meta(
				"power_cut_local_planes", []) as Array).duplicate(),
			"magnet_engaged": body.magnet_engaged,
			"magnet_drag_speed": body.magnet_drag_speed,
		}
	return {
		"boundary_radius": _effective_boundary_radius,
		"boundary_grace": _effective_boundary_grace,
		"arrival_lateral_multiplier": _arrival_lateral_multiplier,
		"arrival_bounce_multiplier": _arrival_bounce_multiplier,
		"arrival_outward_multiplier": _arrival_outward_multiplier,
		"bodies": bodies,
		"chopping_visibility_dome": debug_chopping_visibility_dome_state(),
	}


func debug_chopping_visibility_dome_state() -> Dictionary:
	var shape_node := _visibility_dome.get_node_or_null(
		"CollisionShape3D") as CollisionShape3D if _visibility_dome != null \
		else null
	var capsule := shape_node.shape as CapsuleShape3D \
		if shape_node != null else null
	return {
		"present": _visibility_dome != null \
			and is_instance_valid(_visibility_dome),
		"radius": capsule.radius if capsule != null else 0.0,
		"height": capsule.height if capsule != null else 0.0,
		"collision_layer": _visibility_dome.collision_layer \
			if _visibility_dome != null else 0,
		"world_position": _visibility_dome.global_position \
			if _visibility_dome != null else Vector3.ZERO,
	}


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
	_unbatch_body(body)
	body.continuous_cd = true
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
	for entry: Dictionary in _visual_batches.values():
		var instance := entry.get("instance") as MultiMeshInstance3D
		if is_instance_valid(instance):
			instance.queue_free()
	_visual_batches.clear()
	_dirty_batch_keys.clear()
	loose_count_changed.emit(0)


func set_hazards_paused(value: bool) -> void:
	_paused = value
	for body: LooseLogBody in _live_bodies():
		body.freeze = value
		if value:
			try_batch_visual(body)
		elif not body.sleeping:
			_unbatch_body(body)


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
	_unbatch_body(body)
	_bodies.erase(id)
	_set_warning(body, false)
	boundary_warning.emit(id, -1.0)
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze = true
	if not splitter:
		# queue_free is deferred. Hide the claimed rigid body synchronously so the
		# handoff presentation never draws on top of it for one renderer frame.
		body.visible = false
	loose_count_changed.emit(_bodies.size())
	if splitter:
		if body.descriptor != null:
			body.descriptor.transfer_from = body.global_position
			body.descriptor.transfer_rotation = body.quaternion
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(body, "position",
			body.position + Vector3(2.4, 0.7, -0.8), 0.28)
		tween.tween_callback(body.queue_free)
	return body


func _on_body_entered(other: Node, body: LooseLogBody) -> void:
	if not is_instance_valid(body) or body.descriptor == null \
			or not _bodies.has(body.descriptor.id):
		return
	if _is_ground_surface(other):
		body.grounded = true
	if body.landed:
		return
	# The tall visibility shield is an airborne/side collision, never proof that
	# the incoming root has reached the ground and become magnet-eligible.
	if other is StaticBody3D and not bool(other.get_meta(
			"chopping_visibility_dome", false)):
		body.landed = true
		body.continuous_cd = false
		log_landed.emit(body.descriptor.id)
		if body.sleeping:
			try_batch_visual(body)


func _on_body_exited(other: Node, body: LooseLogBody) -> void:
	if is_instance_valid(body) and _is_ground_surface(other):
		body.grounded = false
		_release_yard_magnet_drag(body)


func _is_ground_surface(other: Node) -> bool:
	return other != null and other == get_node_or_null("../Floor")


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


func _ordered_power_targets(origin: Vector3, max_range: float,
		mode: StringName, excluded_ids: Array) -> Array[LooseLogBody]:
	var out: Array[LooseLogBody] = []
	var range_squared := max_range * max_range
	for body: LooseLogBody in _live_bodies():
		if body.descriptor == null or body.descriptor.id in excluded_ids:
			continue
		var delta := Vector2(body.global_position.x - origin.x,
			body.global_position.z - origin.z)
		if not is_inf(max_range) and delta.length_squared() > range_squared:
			continue
		out.append(body)
	out.sort_custom(func(left: LooseLogBody, right: LooseLogBody) -> bool:
		return _power_target_precedes(left, right, origin, mode))
	return out


func _power_target_precedes(left: LooseLogBody, right: LooseLogBody,
		origin: Vector3, mode: StringName) -> bool:
	if mode in [&"endangered", &"endangered_spread"]:
		if not is_equal_approx(left.boundary_exposure, right.boundary_exposure):
			return left.boundary_exposure > right.boundary_exposure
		var left_radius := Vector2(left.global_position.x,
			left.global_position.z).length_squared()
		var right_radius := Vector2(right.global_position.x,
			right.global_position.z).length_squared()
		if not is_equal_approx(left_radius, right_radius):
			return left_radius > right_radius
	elif mode == &"hardest":
		var left_boss := left.descriptor != null and left.descriptor.boss_id != &""
		var right_boss := right.descriptor != null and right.descriptor.boss_id != &""
		if left_boss != right_boss:
			return left_boss
		if left.descriptor != null and right.descriptor != null \
				and not is_equal_approx(left.descriptor.hardness_snapshot,
				right.descriptor.hardness_snapshot):
			return left.descriptor.hardness_snapshot > right.descriptor.hardness_snapshot
	else:
		var left_distance := Vector2(left.global_position.x - origin.x,
			left.global_position.z - origin.z).length_squared()
		var right_distance := Vector2(right.global_position.x - origin.x,
			right.global_position.z - origin.z).length_squared()
		if not is_equal_approx(left_distance, right_distance):
			return left_distance < right_distance
	return String(left.descriptor.id) < String(right.descriptor.id)


func _target_receipts(power_id: StringName, applied: Dictionary,
		amount_key: StringName) -> Array[Dictionary]:
	var ids: Array[String] = []
	for raw_id: Variant in applied:
		ids.append(String(raw_id))
	ids.sort()
	var receipts: Array[Dictionary] = []
	for id: String in ids:
		receipts.append({
			"power_id": String(power_id),
			"log_id": id,
			String(amount_key): int(applied.get(StringName(id), applied.get(id, 0))),
		})
	return receipts


func _safe_pending_add(current: int, amount: int) -> int:
	return mini(GameState.MAX_SAFE_ECONOMY_VALUE, maxi(0, current) + maxi(0, amount))


func _apply_power_cut(body: LooseLogBody, power_id: StringName,
		present_flash := true, allow_completion := true,
		rebuild_collisions := true) -> bool:
	if body == null or body.descriptor == null or _chopping == null \
			or not _chopping.has_method("slice_loose_run_piece"):
		return false
	var piece := _largest_choppable_piece(body)
	if piece == null or piece.mesh == null:
		return false
	_unbatch_body(body)
	var descriptor := body.descriptor
	var previous := maxi(0, descriptor.pending_power_cuts)
	var next := _safe_pending_add(previous, 1)
	if next <= previous:
		return false
	var axis_seed := hash("%s|%s|%d" % [
		String(descriptor.id), String(power_id), previous])
	# Select the plane in the piece's own upright mesh frame. The body can be
	# lying or tumbling at any world rotation without turning this into a diagonal
	# cut through the log's authored top and bottom.
	var local_axis := Vector3.RIGHT if (absi(axis_seed) % 2) == 0 \
		else Vector3.FORWARD
	var split: Dictionary = _chopping.call("slice_loose_run_piece",
		descriptor, piece.mesh, piece.global_transform, local_axis, next)
	# A descendant may be too narrow along the rolled direction after earlier
	# cuts. Preserve the local-X/Z-only contract but try the other true vertical
	# plane before declaring that this power hit cannot divide the selected wood.
	if split.is_empty():
		local_axis = Vector3.FORWARD if local_axis == Vector3.RIGHT \
			else Vector3.RIGHT
		split = _chopping.call("slice_loose_run_piece", descriptor,
			piece.mesh, piece.global_transform, local_axis, next)
	var raw_halves: Variant = split.get("halves", [])
	if not (raw_halves is Array) or (raw_halves as Array).size() != 2:
		return false
	var stable_id := StringName(piece.get_meta("stable_piece_id",
		descriptor.id))
	var projection_offset: Vector3 = piece.get_meta(
		"projection_offset", Vector3.ZERO)
	var piece_transform := piece.transform
	body.piece_visuals.erase(piece)
	body.remove_child(piece)
	piece.queue_free()
	for raw_half: Variant in raw_halves:
		if not (raw_half is Dictionary):
			continue
		var half := raw_half as Dictionary
		var half_mesh := half.get("mesh") as Mesh
		var center: Vector3 = half.get("center", Vector3.ZERO)
		var separation: Vector3 = half.get("separation", Vector3.ZERO)
		if half_mesh == null:
			continue
		var visual := MeshInstance3D.new()
		visual.name = "LoosePiece%d" % body.get_child_count()
		visual.mesh = half_mesh
		visual.transform = piece_transform * Transform3D(
			Basis.IDENTITY, center + separation)
		var child_id := StringName("%s/%s" % [stable_id,
			String(half.get("suffix", "a"))])
		visual.set_meta("stable_piece_id", child_id)
		visual.set_meta("is_firewood", bool(half.get("is_firewood", false)))
		visual.set_meta("projection_offset",
			projection_offset + center + separation)
		visual.set_instance_shader_parameter(&"projection_offset",
			projection_offset + center + separation)
		body.add_child(visual)
		body.piece_visuals.append(visual)
	body.remove_meta(&"visibility_local_bounds")
	body.remove_meta(&"visibility_meshes")
	descriptor.pending_power_cuts = next
	descriptor.pending_power_cut_sources.append(
		power_id if power_id != &"" else &"precut")
	var cut_axes: Array = body.get_meta("power_cut_axes", [])
	cut_axes.append(local_axis)
	body.set_meta("power_cut_axes", cut_axes)
	var local_planes: Array = body.get_meta("power_cut_local_planes", [])
	local_planes.append(split.get("local_plane", Plane()))
	body.set_meta("power_cut_local_planes", local_planes)
	if rebuild_collisions:
		_rebuild_body_collisions(body)
	if next >= OFF_BLOCK_COMPLETION_CUTS and allow_completion:
		_finish_off_block_root(body, power_id)
	elif present_flash:
		_flash_power_cut(body)
	return true


## Apply only the remaining real cuts needed by the shared off-block completion
## rule. A partly cut root therefore receives fewer new cuts than a fresh one,
## while both finish through the same geometry, reward, and retirement path.
func _complete_power_cut_target(body: LooseLogBody,
		power_id: StringName) -> int:
	if body == null or body.descriptor == null:
		return 0
	var descriptor := body.descriptor
	var applied := 0
	while is_instance_valid(body) and _bodies.has(descriptor.id) \
			and descriptor.pending_power_cuts < OFF_BLOCK_COMPLETION_CUTS:
		if not _apply_power_cut(body, power_id, false, false, false):
			break
		applied += 1
	if is_instance_valid(body) and _bodies.has(descriptor.id) \
			and descriptor.pending_power_cuts >= OFF_BLOCK_COMPLETION_CUTS:
		_finish_off_block_root(body, power_id)
	if _bodies.has(descriptor.id):
		_rebuild_body_collisions(body)
		if applied > 0:
			_flash_power_cut(body)
		_refresh_power_marker(body)
	return applied


func _replay_saved_power_cuts(body: LooseLogBody) -> void:
	if body == null or body.descriptor == null:
		return
	var count := body.descriptor.pending_power_cuts
	var sources := body.descriptor.pending_power_cut_sources.duplicate()
	body.descriptor.pending_power_cuts = 0
	body.descriptor.pending_power_cut_sources.clear()
	for index: int in range(count):
		var source: StringName = sources[index] if index < sources.size() \
			else &"precut"
		if not _apply_power_cut(body, source, false, false, false):
			break
	if body.descriptor.pending_power_cuts >= OFF_BLOCK_COMPLETION_CUTS:
		_finish_off_block_root(body, sources[-1] if not sources.is_empty() \
			else &"precut")
	elif is_instance_valid(body) and body.descriptor != null \
			and _bodies.has(body.descriptor.id):
		_rebuild_body_collisions(body)


func _largest_choppable_piece(body: LooseLogBody) -> MeshInstance3D:
	var best: MeshInstance3D
	var best_volume := -1.0
	for piece: MeshInstance3D in _piece_visuals(body):
		if piece.mesh == null:
			continue
		# A block cut releases firewood-sized descendants immediately, but a loose
		# root is one five-hit power transaction. Keep every real descendant
		# sliceable until that fifth hit releases the complete batch; otherwise
		# canonical (non-diagonal) quarter pieces strand the root after three cuts.
		var volume := _mesh_volume(piece.mesh)
		if volume > best_volume:
			best = piece
			best_volume = volume
	return best


func _has_choppable_piece(body: LooseLogBody) -> bool:
	return _largest_choppable_piece(body) != null


func _choppable_piece_count(body: LooseLogBody) -> int:
	var count := 0
	for piece: MeshInstance3D in _piece_visuals(body):
		if piece.mesh != null:
			count += 1
	return count


func _piece_visuals(body: LooseLogBody) -> Array[MeshInstance3D]:
	if body == null:
		return []
	for index: int in range(body.piece_visuals.size() - 1, -1, -1):
		if not is_instance_valid(body.piece_visuals[index]):
			body.piece_visuals.remove_at(index)
	return body.piece_visuals


func _rebuild_body_collisions(body: LooseLogBody) -> void:
	for collision: CollisionShape3D in body.collision_shapes:
		if is_instance_valid(collision):
			body.remove_child(collision)
			collision.queue_free()
	body.collision_shapes.clear()
	var total_volume := 0.0
	for piece: MeshInstance3D in _piece_visuals(body):
		if piece.mesh == null:
			continue
		var collision := CollisionShape3D.new()
		collision.name = "LoosePieceCollision"
		collision.shape = MeshUtils.box_shape(piece.mesh)
		collision.transform = piece.transform
		body.add_child(collision)
		body.collision_shapes.append(collision)
		total_volume += _mesh_volume(piece.mesh)
	body.mass = maxf(0.5, total_volume * 650.0)


func _finish_off_block_root(body: LooseLogBody,
		power_id: StringName) -> void:
	if body == null or body.descriptor == null:
		return
	var descriptor := body.descriptor
	var id := descriptor.id
	var world_position := body.global_position
	var piece_count := _piece_visuals(body).size()
	_bodies.erase(id)
	_set_warning(body, false)
	boundary_warning.emit(id, -1.0)
	body.collision_layer = 0
	body.collision_mask = 0
	loose_count_changed.emit(_bodies.size())
	_flash_power_cut(body)
	var completion_receipt: Dictionary = {}
	if _run != null and _run.has_method("complete_off_block_log"):
		completion_receipt = _run.call("complete_off_block_log", descriptor,
			piece_count, power_id, world_position)
	if _chopping != null and _chopping.has_method(
			"retire_off_block_finished_log"):
		_chopping.call("retire_off_block_finished_log", body,
			completion_receipt, world_position)
	else:
		body.queue_free()


func _flash_power_cut(body: LooseLogBody) -> void:
	if body == null or not is_instance_valid(body):
		return
	var flash := StandardMaterial3D.new()
	flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	flash.no_depth_test = true
	for piece: MeshInstance3D in _piece_visuals(body):
		piece.material_overlay = flash
	var flash_id := int(body.get_meta("power_cut_flash_count", 0)) + 1
	body.set_meta("power_cut_flash_count", flash_id)
	body.set_meta("power_cut_flash_material", flash)
	var body_id := body.get_instance_id()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(Callable(self, "_set_power_flash_alpha").bind(
		body_id, flash_id), 0.92, 0.0, 0.14)
	tween.tween_callback(Callable(self, "_finish_power_flash").bind(
		body_id, flash_id))


func _set_power_flash_alpha(alpha: float, body_id: int,
		flash_id: int) -> void:
	var body := instance_from_id(body_id) as LooseLogBody
	if body == null or not is_instance_valid(body) \
			or int(body.get_meta("power_cut_flash_count", 0)) != flash_id:
		return
	var material := body.get_meta(
		"power_cut_flash_material", null) as StandardMaterial3D
	if material == null:
		return
	var color := material.albedo_color
	color.a = alpha
	material.albedo_color = color


func _finish_power_flash(body_id: int, flash_id: int) -> void:
	var body := instance_from_id(body_id) as LooseLogBody
	if body == null or not is_instance_valid(body) \
			or int(body.get_meta("power_cut_flash_count", 0)) != flash_id:
		return
	body.remove_meta("power_cut_flash_material")
	var outside := Vector2(body.global_position.x,
		body.global_position.z).length_squared() > _effective_boundary_radius_squared
	var enabled := outside and body.descriptor != null \
		and _bodies.has(body.descriptor.id)
	var left := maxf(0.0,
		_effective_boundary_grace - body.boundary_exposure) if enabled else -1.0
	_set_warning(body, enabled, left, true)


func _serialized_cut_sources(sources: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for source: StringName in sources:
		out.append(String(source))
	return out


func _body_contact_radius(body: LooseLogBody) -> float:
	var radius := 0.0
	for visual: MeshInstance3D in _piece_visuals(body):
		if visual.mesh != null:
			radius = maxf(radius, visual.position.length()
				+ visual.mesh.get_aabb().size.length() * 0.5)
	return radius


func _refresh_power_marker(body: LooseLogBody) -> void:
	if body == null or body.descriptor == null:
		return
	var marker := body.get_node_or_null("RunPowerMark") as Label3D
	var scars := body.descriptor.pending_power_scars
	if scars <= 0 or not _bodies.has(body.descriptor.id):
		if marker != null:
			marker.queue_free()
		return
	if marker == null:
		_unbatch_body(body)
		marker = Label3D.new()
		marker.name = "RunPowerMark"
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.font_size = 28
		marker.outline_size = 7
		marker.pixel_size = 0.0025
		marker.modulate = Color(1.0, 0.72, 0.18, 1.0)
		marker.position = Vector3.UP * 0.92
		body.add_child(marker)
	marker.text = "SCAR %d" % scars


func _set_warning(body: LooseLogBody, enabled: bool,
		seconds_left := -1.0, force := false) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var decisecond := ceili(maxf(0.0, seconds_left) * 10.0 - 0.0001) \
		if enabled else -1
	var changed := body.warning_active != enabled \
		or (enabled and body.warning_decisecond != decisecond)
	if not changed and not force:
		return false
	if enabled:
		_unbatch_body(body)
	body.warning_active = enabled
	body.warning_decisecond = decisecond
	for mesh: MeshInstance3D in _piece_visuals(body):
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
		label.text = "%.1f" % (float(decisecond) * 0.1)
	else:
		if label != null:
			label.queue_free()
		try_batch_visual(body)
	return changed


func _warning_overlay() -> StandardMaterial3D:
	if _warning_material == null:
		_warning_material = StandardMaterial3D.new()
		_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_warning_material.albedo_color = Color(1.0, 0.05, 0.02, 0.38)
		_warning_material.no_depth_test = true
	return _warning_material


func _physics_material(bounce_multiplier: float = 1.0) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = _BASE_BOUNCE * maxf(0.0, bounce_multiplier)
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


## A solid, invisible capsule reserves the full air column above the stump.
## Loose roots collide with its dedicated layer, while the active Area3D log is
## unaffected inside it. Its rounded cap turns direct hits outward instead of
## allowing a late-run pile to roof over the workpiece.
func _build_chopping_visibility_dome() -> void:
	if _visibility_dome != null or _tuning == null:
		return
	_visibility_dome = StaticBody3D.new()
	_visibility_dome.name = "ChoppingVisibilityDome"
	_visibility_dome.collision_layer = CHOPPING_VISIBILITY_DOME_LAYER
	_visibility_dome.collision_mask = 0
	_visibility_dome.set_meta("chopping_visibility_dome", true)
	var material := PhysicsMaterial.new()
	material.friction = _tuning.chopping_visibility_dome_friction
	material.bounce = 0.0
	_visibility_dome.physics_material_override = material
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = _tuning.chopping_visibility_dome_radius
	capsule.height = maxf(_tuning.chopping_visibility_dome_height,
		capsule.radius * 2.0)
	collision.shape = capsule
	_visibility_dome.add_child(collision)
	add_child(_visibility_dome)
	var base := yard_magnet_target_world_position()
	if _chopping != null and _chopping.has_method(
			&"chopping_visibility_dome_base_world_position"):
		base = _chopping.call(
			&"chopping_visibility_dome_base_world_position")
	# Sink the lower hemisphere by one radius so the full authored radius begins
	# exactly at yard-floor height; there is no low side gap for settled roots.
	_visibility_dome.global_position = base + Vector3.UP * (
		capsule.height * 0.5 - capsule.radius)


func _build_ring() -> void:
	if _ring != null or _tuning == null:
		return
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var radii := PackedFloat32Array([
		_effective_boundary_radius - _tuning.boundary_gradient_width,
		_effective_boundary_radius - _tuning.boundary_core_half_width,
		_effective_boundary_radius + _tuning.boundary_core_half_width,
		_effective_boundary_radius + _tuning.boundary_gradient_width,
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


func _rebuild_ring() -> void:
	if _ring != null:
		remove_child(_ring)
		_ring.queue_free()
		_ring = null
	_build_ring()
