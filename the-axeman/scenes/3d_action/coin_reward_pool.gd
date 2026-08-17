class_name CoinRewardPool
extends Node3D
## A fully prebuilt manual-sale receipt pool. Coins burst from the final cut,
## bounce across the stump and yard, then fly to the HUD on the same collection
## beat as XP. RunDirector owns every cent; this only presents it.
## Counts, timing and motion are PLACEHOLDERS pending the VFX feel pass.

enum Phase { INACTIVE, FLIGHT, REST, DRAW }

signal batch_started(count: int)
signal coin_collected(amount: int, tier: int)
signal coins_cancelled(count: int)
signal batch_finished

const CAPACITY := 40
const _GRAVITY := 9.0
const _BOUNCE := 0.46
const _GROUND_DRAG := 0.62
const _SETTLE_SPEED := 0.35
const _DRAW_TIME := 0.52
const _ABSORB_DIST := 0.42
const _COIN_TEXTURE := preload("res://assets/ui/coin.png")
const _NOTE_GREEN := preload("res://assets/ui/reward_note_green.svg")
const _NOTE_BLUE := preload("res://assets/ui/reward_note_blue.svg")
const _NOTE_BUNDLE := preload("res://assets/ui/reward_note_bundle.svg")

static var _meshes: Array[QuadMesh] = []
static var _materials: Array[StandardMaterial3D] = []

var _camera: Camera3D
var _screen_target := Callable()
var _coins: Array[MeshInstance3D] = []
var _phases := PackedInt32Array()
var _velocities: Array[Vector3] = []
var _ground_y := PackedFloat32Array()
var _support_y := PackedFloat32Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _collect_times := PackedFloat32Array()
var _amounts: Array[int] = []
var _tiers := PackedInt32Array()
var _spin := PackedFloat32Array()
var _draw_from: Array[Vector3] = []
var _batch_remaining := 0
var _render_warmup_active := false
var _tier_scales := PackedFloat32Array()
var _stump_collider: CollisionShape3D
var _stump_geometry_radius := -1.0

# Reused collision result. The reward pool exists to avoid impact-time
# allocations, so the swept stump test writes into these fields instead of
# constructing a Dictionary for every active token on every frame.
var _hit_found := false
var _hit_fraction := 1.0
var _hit_position := Vector3.ZERO
var _hit_normal := Vector3.UP


func initialize(camera: Camera3D) -> void:
	_ensure_shared()
	_camera = camera
	_tier_scales = GameConfig.current().reward_bursts.tier_scales
	_build()


static func _ensure_shared() -> void:
	if not _meshes.is_empty():
		return
	var textures: Array[Texture2D] = [_COIN_TEXTURE, _NOTE_GREEN, _NOTE_BLUE, _NOTE_BUNDLE]
	var sizes := [Vector2(0.084, 0.084), Vector2(0.126, 0.063),
		Vector2(0.145, 0.072), Vector2(0.158, 0.099)]
	for tier in range(4):
		var tier_mesh := QuadMesh.new()
		tier_mesh.size = sizes[tier]
		var tier_material := StandardMaterial3D.new()
		tier_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tier_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tier_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX \
			if tier > 0 else BaseMaterial3D.BLEND_MODE_ADD
		tier_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		tier_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		tier_material.billboard_keep_scale = true
		tier_material.albedo_texture = textures[tier]
		_meshes.append(tier_mesh)
		_materials.append(tier_material)
	# Force procedural geometry, shader/material and imported texture resources
	# onto the rendering server during initial load, before any coin is visible.
	for tier_mesh in _meshes:
		tier_mesh.get_rid()
	for tier_material in _materials:
		tier_material.get_rid()
	_COIN_TEXTURE.get_rid()
	_NOTE_GREEN.get_rid()
	_NOTE_BLUE.get_rid()
	_NOTE_BUNDLE.get_rid()


func _build() -> void:
	for i in range(CAPACITY):
		var coin := MeshInstance3D.new()
		coin.name = "Coin%d" % i
		coin.mesh = _meshes[0]
		coin.material_override = _materials[0]
		coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coin.visible = false
		add_child(coin)
		_coins.append(coin)
		_phases.append(Phase.INACTIVE)
		_velocities.append(Vector3.ZERO)
		_ground_y.append(0.0)
		_support_y.append(0.0)
		_ages.append(0.0)
		_lifetimes.append(0.0)
		_collect_times.append(0.0)
		_amounts.append(-1)
		_tiers.append(0)
		_spin.append(0.0)
		_draw_from.append(Vector3.ZERO)
	set_process(false)


func set_screen_target(provider: Callable) -> void:
	_screen_target = provider


## Manual rewards share the stump's cylinder proxy. `geometry_radius` is the
## measured mesh footprint; the gameplay work-radius upgrade can widen this same
## CollisionShape3D beyond the visible wood and must not make tokens bounce off
## empty air. Splitter rewards leave this unset and retain their floor bounce.
func set_stump_collider(collider: CollisionShape3D,
		geometry_radius := -1.0) -> void:
	_stump_collider = collider
	_stump_geometry_radius = geometry_radius


## Pop one visible coin per eventual piece payout. They share XPOrb's collection
## beat so the two reward waves leave the world together.
func begin_burst(from: Vector3, count: int, ground_y: float, clear_radius: float,
		collect_at: float, stagger: float) -> void:
	_finish_pending()
	var active_count := clampi(count, 0, CAPACITY)
	_batch_remaining = active_count
	for i in range(CAPACITY):
		if i >= active_count:
			_deactivate(i)
			continue
		var angle := TAU * (float(i) + randf_range(-0.35, 0.35)) / float(active_count)
		var reach := maxf(clear_radius * 1.02, 0.22) * randf_range(0.85, 1.2)
		var up := randf_range(0.85, 1.55)
		# Same full ballistic solve as XPOrb. The previous same-height shortcut
		# ignored the half-metre drop from log to yard, so horizontal velocity was
		# almost doubled and coins overshot their intended landing ring.
		var floor := ground_y + _collision_radius(i)
		var drop := maxf(from.y - floor, 0.01)
		var flight_time := (up + sqrt(up * up + 2.0 * _GRAVITY * drop)) / _GRAVITY
		_coins[i].global_position = from
		_coins[i].visible = true
		_coins[i].scale = Vector3.ONE
		_apply_tier(i, 0)
		_phases[i] = Phase.FLIGHT
		_velocities[i] = Vector3(cos(angle) * reach / flight_time, up,
			sin(angle) * reach / flight_time)
		_ground_y[i] = ground_y
		_support_y[i] = ground_y
		_ages[i] = 0.0
		_lifetimes[i] = 0.0
		_collect_times[i] = maxf(0.0, collect_at) + float(i) * maxf(0.0, stagger)
		_amounts[i] = -1
		_spin[i] = randf_range(8.0, 14.0) * (-1.0 if i % 2 == 0 else 1.0)
	set_process(active_count > 0)
	if active_count > 0:
		batch_started.emit(active_count)


## Attach the exact authoritative payout to the next coin. This is called after
## RunDirector has settled one landed piece, so completion bonuses ride on the same
## receipt without moving any economy authority into presentation code.
func queue_payout(amount: int) -> void:
	if amount <= 0:
		return
	for i in range(CAPACITY):
		if _phases[i] != Phase.INACTIVE and _amounts[i] < 0:
			_resolve_payout(i, amount)
			return


func _resolve_payout(anchor: int, amount: int) -> void:
	var reward_config := GameConfig.current().reward_bursts
	var free: Array[int] = []
	for index in range(CAPACITY):
		if _phases[index] == Phase.INACTIVE:
			free.append(index)
	var requested := reward_config.cash_token_count_for_amount(amount)
	var tokens := reward_config.plan_tokens(RewardBurstConfig.Kind.CASH, amount,
		mini(requested, 1 + free.size()))
	if tokens.is_empty():
		return
	_assign_token(anchor, tokens[0])
	for token_index in range(1, tokens.size()):
		var index := free[token_index - 1]
		_clone_anchor(anchor, index, token_index)
		_assign_token(index, tokens[token_index])
	_batch_remaining += tokens.size() - 1
	if tokens.size() > 1:
		batch_started.emit(tokens.size() - 1)


func _assign_token(index: int, token: Dictionary) -> void:
	_amounts[index] = int(token.amount)
	_apply_tier(index, int(token.tier))


func _clone_anchor(anchor: int, index: int, offset: int) -> void:
	_phases[index] = _phases[anchor]
	_coins[index].global_position = _coins[anchor].global_position \
		+ Vector3(randf_range(-0.025, 0.025), 0.008 * offset,
			randf_range(-0.025, 0.025))
	_coins[index].visible = true
	_velocities[index] = _velocities[anchor] + Vector3(
		randf_range(-0.16, 0.16), randf_range(0.10, 0.28), randf_range(-0.16, 0.16))
	_ground_y[index] = _ground_y[anchor]
	_support_y[index] = _support_y[anchor]
	_ages[index] = _ages[anchor]
	_lifetimes[index] = _lifetimes[anchor]
	_collect_times[index] = _collect_times[anchor] + float(offset) * 0.025
	_spin[index] = _spin[anchor] * (-1.0 if offset % 2 == 0 else 1.0)
	_draw_from[index] = _draw_from[anchor]
	set_process(true)


func _apply_tier(index: int, tier: int) -> void:
	var safe_tier := clampi(tier, 0, 3)
	_tiers[index] = safe_tier
	_coins[index].mesh = _meshes[safe_tier]
	_coins[index].material_override = _materials[safe_tier]
	var tier_scale := _tier_scales[safe_tier]
	_coins[index].scale = Vector3.ONE * tier_scale


func _process(delta: float) -> void:
	var any_active := false
	var destination := Vector3.ZERO
	var destination_ready := false
	for i in range(CAPACITY):
		if _phases[i] == Phase.FLIGHT or _phases[i] == Phase.REST:
			_lifetimes[i] += delta
			# Never approach the HUD without a real receipt. Previously an unpaid
			# coin travelled 92% of the path and spun beside the counter while its
			# firewood was still landing. Waiting in the yard reads as loot; waiting
			# in the UI corner reads as a stuck effect.
			if _lifetimes[i] >= _collect_times[i] and _amounts[i] >= 0:
				_begin_draw(i)
		match _phases[i]:
			Phase.INACTIVE:
				continue
			Phase.FLIGHT:
				any_active = true
				_step_flight(i, delta)
			Phase.REST:
				any_active = true
				_ages[i] += delta
				var rest_position := _coins[i].global_position
				rest_position.y = _support_y[i] + _collision_radius(i) \
					+ sin(_ages[i] * 6.0 + float(i)) * 0.006
				_coins[i].global_position = rest_position
			Phase.DRAW:
				any_active = true
				if not destination_ready:
					destination = _screen_destination()
					destination_ready = true
				_step_draw(i, delta, destination)
	set_process(any_active)


func _step_flight(i: int, delta: float) -> void:
	_ages[i] += delta
	_velocities[i].y -= _GRAVITY * delta
	var from := _coins[i].global_position
	var to := from + _velocities[i] * delta
	_find_first_surface_hit(i, from, to)
	if _hit_found:
		_coins[i].global_position = _hit_position + _hit_normal * 0.0005
		var inward_speed := _velocities[i].dot(_hit_normal)
		if inward_speed < 0.0:
			var tangent := _velocities[i] - _hit_normal * inward_speed
			_velocities[i] = tangent * _GROUND_DRAG \
				- _hit_normal * inward_speed * _BOUNCE
		if _hit_normal.y > 0.7 and -inward_speed < _SETTLE_SPEED:
			_phases[i] = Phase.REST
			_ages[i] = 0.0
			_support_y[i] = _hit_position.y - _collision_radius(i)
	else:
		_coins[i].global_position = to
	_apply_spin(i)


## Sweep the token centre from `from` to `to`. A point test lets a fast token
## tunnel through the half-metre block between frames; expanding the floor and
## cylinder by the token's current visual radius gives the billboard a stable
## physical footprint without adding forty RigidBody3Ds to the physics budget.
func _find_first_surface_hit(i: int, from: Vector3, to: Vector3) -> void:
	_hit_found = false
	_hit_fraction = 1.0
	var radius := _collision_radius(i)
	var floor := _ground_y[i] + radius
	var motion := to - from
	if motion.y < 0.0 and from.y >= floor and to.y <= floor:
		var floor_fraction := (floor - from.y) / motion.y
		_record_surface_hit(floor_fraction,
			from.lerp(to, floor_fraction), Vector3.UP)
	_find_stump_hit(from, to, radius)


## The authored stump currently exposes a CylinderShape3D collision proxy. Work
## in that shape's local space so the reward follows its live height and transform.
## Its radius comes from the measured mesh footprint when supplied, because the
## same gameplay proxy can be wider than the rendered stump after an upgrade.
func _find_stump_hit(from: Vector3, to: Vector3, radius: float) -> void:
	if _stump_collider == null or not is_instance_valid(_stump_collider) \
			or _stump_collider.disabled \
			or not (_stump_collider.shape is CylinderShape3D):
		return
	var cylinder := _stump_collider.shape as CylinderShape3D
	var shape_transform := _stump_collider.global_transform
	var inverse := shape_transform.affine_inverse()
	var local_from := inverse * from
	var local_to := inverse * to
	var local_motion := local_to - local_from
	var stump_radius := _stump_geometry_radius \
		if _stump_geometry_radius >= 0.0 else cylinder.radius
	var expanded_radius := stump_radius + radius
	var top := cylinder.height * 0.5 + radius

	# Flat top. The small radius overhang approximates the rounded edge of a
	# swept disc and prevents a coin grazing the rim from clipping through it.
	if local_motion.y < 0.0 and local_from.y >= top and local_to.y <= top:
		var top_fraction := (top - local_from.y) / local_motion.y
		var top_point := local_from.lerp(local_to, top_fraction)
		if Vector2(top_point.x, top_point.z).length_squared() \
				<= expanded_radius * expanded_radius:
			_record_surface_hit(top_fraction, shape_transform * top_point,
				(shape_transform.basis * Vector3.UP).normalized())

	# Curved wall. Only an outside-to-inside crossing is a hit; a token leaving
	# the top must be allowed to travel out over the rim and fall to the yard.
	var a := local_motion.x * local_motion.x + local_motion.z * local_motion.z
	if a <= 0.0000001:
		return
	var b := 2.0 * (local_from.x * local_motion.x + local_from.z * local_motion.z)
	var c := local_from.x * local_from.x + local_from.z * local_from.z \
		- expanded_radius * expanded_radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return
	var root := sqrt(discriminant)
	for root_index in range(2):
		var signed_root := -root if root_index == 0 else root
		var side_fraction := (-b + signed_root) / (2.0 * a)
		if side_fraction < 0.0 or side_fraction > _hit_fraction:
			continue
		var side_point := local_from.lerp(local_to, side_fraction)
		if side_point.y < -cylinder.height * 0.5 - radius \
				or side_point.y > cylinder.height * 0.5 + radius:
			continue
		var local_normal := Vector3(side_point.x, 0.0, side_point.z).normalized()
		if local_motion.dot(local_normal) >= 0.0:
			continue
		_record_surface_hit(side_fraction, shape_transform * side_point,
			(shape_transform.basis * local_normal).normalized())


func _record_surface_hit(fraction: float, position: Vector3, normal: Vector3) -> void:
	if fraction < 0.0 or fraction > _hit_fraction:
		return
	_hit_found = true
	_hit_fraction = fraction
	_hit_position = position
	_hit_normal = normal


func _collision_radius(i: int) -> float:
	var tier := clampi(_tiers[i], 0, _meshes.size() - 1)
	var tier_scale := _tier_scales[clampi(tier, 0, _tier_scales.size() - 1)]
	return maxf(_meshes[tier].size.x, _meshes[tier].size.y) * 0.5 * tier_scale


func _begin_draw(i: int) -> void:
	_phases[i] = Phase.DRAW
	_ages[i] = 0.0
	_draw_from[i] = _coins[i].global_position
	set_process(true)


func _step_draw(i: int, delta: float, destination: Vector3) -> void:
	_ages[i] += delta
	var k := clampf(_ages[i] / _DRAW_TIME, 0.0, 1.0)
	var eased := k * k
	var start: Vector3 = _draw_from[i]
	var control := start.lerp(destination, 0.5) + Vector3.UP * start.distance_to(destination) * 0.18
	var a := start.lerp(control, eased)
	var b := control.lerp(destination, eased)
	_coins[i].global_position = a.lerp(b, eased)
	_apply_spin(i)
	var scale_amount := maxf(0.18, 1.0 - eased * 0.5)
	var tier_scale := _tier_scales[_tiers[i]]
	_coins[i].scale.y = scale_amount * tier_scale
	if k < 1.0:
		return
	_complete_coin(i)


## Reconcile the visual count with the valid proxies that survived collection.
## This removes only unpaid receipts; a real settled payout is never discarded.
func trim_unpaid_to_count(keep_count: int) -> void:
	var unpaid: Array[int] = []
	for i in range(CAPACITY):
		if _phases[i] != Phase.INACTIVE and _amounts[i] < 0:
			unpaid.append(i)
	var cancel_count := maxi(0, unpaid.size() - maxi(0, keep_count))
	for n in range(cancel_count):
		_deactivate(unpaid[unpaid.size() - 1 - n])
	_batch_remaining = maxi(0, _batch_remaining - cancel_count)
	if cancel_count > 0:
		coins_cancelled.emit(cancel_count)
	if _batch_remaining == 0 and cancel_count > 0:
		batch_finished.emit()


func cancel_next_unpaid() -> void:
	for i in range(CAPACITY):
		if _phases[i] != Phase.INACTIVE and _amounts[i] < 0:
			_deactivate(i)
			_batch_remaining = maxi(0, _batch_remaining - 1)
			coins_cancelled.emit(1)
			if _batch_remaining == 0:
				batch_finished.emit()
			return


func _apply_spin(i: int) -> void:
	var tier_scale := _tier_scales[_tiers[i]]
	if _tiers[i] == 0:
		# Billboarded icon, with an X squash that reads as a coin turning edge-on.
		var face := 0.18 + absf(cos(_ages[i] * _spin[i])) * 0.82
		_coins[i].scale.x = face * tier_scale
	else:
		# Notes flutter broadside; the top bundle has a slower, heavier tumble.
		var flutter := sin(_ages[i] * _spin[i]) * (0.20 if _tiers[i] < 3 else 0.12)
		_coins[i].rotation.z = flutter
		_coins[i].scale.x = tier_scale


func _screen_destination() -> Vector3:
	if _camera != null and is_instance_valid(_camera) and _screen_target.is_valid():
		var normalized: Vector2 = _screen_target.call()
		var viewport_size := Vector2(_camera.get_viewport().get_visible_rect().size)
		return _camera.project_position(normalized * viewport_size, _ABSORB_DIST)
	if _camera != null and is_instance_valid(_camera):
		var camera_transform := _camera.global_transform
		return camera_transform.origin - camera_transform.basis.z * _ABSORB_DIST
	return Vector3.ZERO


func _finish_pending() -> void:
	var had_batch := _batch_remaining > 0
	var cancelled := 0
	for i in range(CAPACITY):
		if _phases[i] == Phase.INACTIVE:
			continue
		if _amounts[i] > 0:
			coin_collected.emit(_amounts[i], _tiers[i])
		else:
			cancelled += 1
		_deactivate(i)
	_batch_remaining = 0
	if cancelled > 0:
		coins_cancelled.emit(cancelled)
	if had_batch:
		batch_finished.emit()


## Canonical save boundary: deliver every paid visual receipt and explicitly
## cancel any unpaid placeholder so the HUD's pending-token count cannot wedge.
func settle_all() -> void:
	_finish_pending()


## Run identity boundary: discard old visuals without presenting their amounts.
## Authoritative cash remains safe and the HUD repaints from the new run total.
func cancel_all() -> void:
	var active := 0
	for i in range(CAPACITY):
		if _phases[i] == Phase.INACTIVE:
			continue
		active += 1
		_deactivate(i)
	var had_batch := _batch_remaining > 0
	_batch_remaining = 0
	set_process(false)
	if active > 0:
		coins_cancelled.emit(active)
	if had_batch:
		batch_finished.emit()


func _complete_coin(i: int) -> void:
	var amount := _amounts[i]
	var tier := _tiers[i]
	_deactivate(i)
	if amount > 0:
		AudioDirector.play_reward(&"cash", tier, &"collect")
		coin_collected.emit(amount, tier)
	_batch_remaining = maxi(0, _batch_remaining - 1)
	if _batch_remaining == 0:
		batch_finished.emit()


## Make the already-pooled coin surface reach an actual draw submission while
## the opaque startup overlay covers the yard. RID creation alone does not force
## the Compatibility renderer to compile its first-use material pipeline.
func show_for_render_warmup(world_position: Vector3) -> void:
	if _batch_remaining > 0 or _coins.is_empty():
		return
	_render_warmup_active = true
	_coins[0].global_position = world_position
	_coins[0].scale = Vector3.ONE * 1.5
	_coins[0].visible = true


func hide_render_warmup() -> void:
	if not _render_warmup_active or _coins.is_empty():
		return
	_render_warmup_active = false
	_deactivate(0)


func _deactivate(i: int) -> void:
	_phases[i] = Phase.INACTIVE
	_amounts[i] = -1
	_tiers[i] = 0
	_coins[i].visible = false
	_coins[i].scale = Vector3.ONE
	_coins[i].rotation = Vector3.ZERO
	_coins[i].mesh = _meshes[0]
	_coins[i].material_override = _materials[0]
