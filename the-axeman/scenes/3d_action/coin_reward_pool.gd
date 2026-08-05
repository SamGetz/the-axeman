class_name CoinRewardPool
extends Node3D
## A fully prebuilt manual-sale receipt pool. Coins burst from the final cut,
## bounce beside the stump, then fly to the HUD on the same collection beat as
## XP. GameState/Market still own every cent; this only presents it.
## Counts, timing and motion are PLACEHOLDERS pending the VFX feel pass.

enum Phase { INACTIVE, FLIGHT, REST, DRAW }

signal batch_started(count: int)
signal coin_collected(amount: int)
signal coins_cancelled(count: int)
signal batch_finished

const CAPACITY := 40
const _RADIUS := 0.042
const _GRAVITY := 9.0
const _BOUNCE := 0.46
const _GROUND_DRAG := 0.62
const _SETTLE_SPEED := 0.35
const _DRAW_TIME := 0.52
const _ABSORB_DIST := 0.42
const _COIN_TEXTURE := preload("res://assets/ui/coin.png")

static var _mesh: QuadMesh
static var _material: StandardMaterial3D

var _camera: Camera3D
var _screen_target := Callable()
var _coins: Array[MeshInstance3D] = []
var _phases := PackedInt32Array()
var _velocities: Array[Vector3] = []
var _floor_y := PackedFloat32Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _collect_times := PackedFloat32Array()
var _amounts := PackedInt32Array()
var _spin := PackedFloat32Array()
var _draw_from: Array[Vector3] = []
var _batch_remaining := 0
var _render_warmup_active := false


func initialize(camera: Camera3D) -> void:
	_ensure_shared()
	_camera = camera
	_build()


static func _ensure_shared() -> void:
	if _mesh != null:
		return
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(_RADIUS * 2.0, _RADIUS * 2.0)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.billboard_keep_scale = true
	_material.albedo_texture = _COIN_TEXTURE
	# Force procedural geometry, shader/material and imported texture resources
	# onto the rendering server during initial load, before any coin is visible.
	_mesh.get_rid()
	_material.get_rid()
	_COIN_TEXTURE.get_rid()


func _build() -> void:
	for i in range(CAPACITY):
		var coin := MeshInstance3D.new()
		coin.name = "Coin%d" % i
		coin.mesh = _mesh
		coin.material_override = _material
		coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coin.visible = false
		add_child(coin)
		_coins.append(coin)
		_phases.append(Phase.INACTIVE)
		_velocities.append(Vector3.ZERO)
		_floor_y.append(0.0)
		_ages.append(0.0)
		_lifetimes.append(0.0)
		_collect_times.append(0.0)
		_amounts.append(-1)
		_spin.append(0.0)
		_draw_from.append(Vector3.ZERO)
	set_process(false)


func set_screen_target(provider: Callable) -> void:
	_screen_target = provider


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
		var floor := ground_y + _RADIUS
		var drop := maxf(from.y - floor, 0.01)
		var flight_time := (up + sqrt(up * up + 2.0 * _GRAVITY * drop)) / _GRAVITY
		_coins[i].global_position = from
		_coins[i].visible = true
		_coins[i].scale = Vector3.ONE
		_phases[i] = Phase.FLIGHT
		_velocities[i] = Vector3(cos(angle) * reach / flight_time, up,
			sin(angle) * reach / flight_time)
		_floor_y[i] = floor
		_ages[i] = 0.0
		_lifetimes[i] = 0.0
		_collect_times[i] = maxf(0.0, collect_at) + float(i) * maxf(0.0, stagger)
		_amounts[i] = -1
		_spin[i] = randf_range(8.0, 14.0) * (-1.0 if i % 2 == 0 else 1.0)
	set_process(active_count > 0)
	if active_count > 0:
		batch_started.emit(active_count)


## Attach the exact authoritative payout to the next coin. This is called after
## Orders has settled one landed piece, so completion bonuses ride on the same
## receipt without moving any economy authority into presentation code.
func queue_payout(amount: int) -> void:
	if amount <= 0:
		return
	for i in range(CAPACITY):
		if _phases[i] != Phase.INACTIVE and _amounts[i] < 0:
			_amounts[i] = amount
			return


func _process(delta: float) -> void:
	var any_active := false
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
				_coins[i].position.y = _floor_y[i] + sin(_ages[i] * 6.0 + float(i)) * 0.006
			Phase.DRAW:
				any_active = true
				_step_draw(i, delta)
	set_process(any_active)


func _step_flight(i: int, delta: float) -> void:
	_ages[i] += delta
	_velocities[i].y -= _GRAVITY * delta
	_coins[i].position += _velocities[i] * delta
	_apply_spin(i)
	if _coins[i].position.y > _floor_y[i] or _velocities[i].y >= 0.0:
		return
	_coins[i].position.y = _floor_y[i]
	if -_velocities[i].y < _SETTLE_SPEED:
		_phases[i] = Phase.REST
		_ages[i] = 0.0
		return
	_velocities[i].y = -_velocities[i].y * _BOUNCE
	_velocities[i].x *= _GROUND_DRAG
	_velocities[i].z *= _GROUND_DRAG


func _begin_draw(i: int) -> void:
	_phases[i] = Phase.DRAW
	_ages[i] = 0.0
	_draw_from[i] = _coins[i].global_position
	set_process(true)


func _step_draw(i: int, delta: float) -> void:
	_ages[i] += delta
	var k := clampf(_ages[i] / _DRAW_TIME, 0.0, 1.0)
	var eased := k * k
	var destination := _screen_destination()
	var start: Vector3 = _draw_from[i]
	var control := start.lerp(destination, 0.5) + Vector3.UP * start.distance_to(destination) * 0.18
	var a := start.lerp(control, eased)
	var b := control.lerp(destination, eased)
	_coins[i].global_position = a.lerp(b, eased)
	_apply_spin(i)
	var scale_amount := maxf(0.18, 1.0 - eased * 0.5)
	_coins[i].scale.y = scale_amount
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
	# Billboarded icon, with an X squash that reads as a coin turning edge-on.
	var face := 0.18 + absf(cos(_ages[i] * _spin[i])) * 0.82
	_coins[i].scale.x = face


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
	for i in range(CAPACITY):
		if _phases[i] != Phase.INACTIVE and _amounts[i] > 0:
			coin_collected.emit(_amounts[i])
		_deactivate(i)
	_batch_remaining = 0
	if had_batch:
		batch_finished.emit()


func _complete_coin(i: int) -> void:
	var amount := _amounts[i]
	_deactivate(i)
	if amount > 0:
		coin_collected.emit(amount)
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
	_coins[i].visible = false
	_coins[i].scale = Vector3.ONE
