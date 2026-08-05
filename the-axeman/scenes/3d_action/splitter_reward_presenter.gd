class_name SplitterRewardPresenter
extends Node3D
## Prewarmed presentation-only receipts for the watched Mechanical Splitter.
## Runtime/GameState already own every reward; this node stages one coin before
## settlement, then presents the exact successful cash/XP values without sharing
## manual chopping's pools.

signal xp_orb_batch_started(amount: int)
signal xp_orb_collected(amount: int)
signal coin_batch_started(count: int)
signal coin_collected(amount: int)
signal coins_cancelled(count: int)
signal coin_batch_finished

const _CoinRewardPool := preload("res://scenes/3d_action/coin_reward_pool.gd")
const _ORB_CAPACITY := 10
const _CHIP_CAPACITY := 12

# PLACEHOLDERS — post-M8 visual-feel review required. The full receipt returns
# inside the approved 2.5-second fastest watched cycle.
const _COLLECT_AT := 0.62
const _ORB_STAGGER := 0.035
const _ORB_DENSITY := 0.42
const _ORB_COUNT_MIN := 2
const _ORB_COUNT_MAX := 8
const _SCATTER_RADIUS := 0.16
const _GROUND_Y := 0.025

var _camera: Camera3D
var _runtime: MechanicalSplitterRuntime
var _origin_provider := Callable()
var _xp_screen_target := Callable()
var _coin_pool: CoinRewardPool
var _orb_root: Node3D
var _orbs: Array[XPOrb] = []
var _active_receipt_id: StringName = &""
var _chips: Array[MeshInstance3D] = []
var _chip_velocities: Array[Vector3] = []
var _chip_ages := PackedFloat32Array()


func initialize(camera: Camera3D, runtime: MechanicalSplitterRuntime,
		origin_provider: Callable) -> void:
	_camera = camera
	_origin_provider = origin_provider
	_build_pools()
	bind_runtime(runtime)
	set_process(false)


func bind_runtime(runtime: MechanicalSplitterRuntime) -> void:
	if _runtime != null:
		if _runtime.cycle_settlement_started.is_connected(_on_settlement_started):
			_runtime.cycle_settlement_started.disconnect(_on_settlement_started)
		if _runtime.cycle_settlement_cancelled.is_connected(_on_settlement_cancelled):
			_runtime.cycle_settlement_cancelled.disconnect(_on_settlement_cancelled)
		if _runtime.cycle_completed.is_connected(_on_cycle_completed):
			_runtime.cycle_completed.disconnect(_on_cycle_completed)
	_runtime = runtime
	if _runtime != null:
		_runtime.cycle_settlement_started.connect(_on_settlement_started)
		_runtime.cycle_settlement_cancelled.connect(_on_settlement_cancelled)
		_runtime.cycle_completed.connect(_on_cycle_completed)


func set_xp_screen_target(provider: Callable) -> void:
	_xp_screen_target = provider


func set_coin_screen_target(provider: Callable) -> void:
	if _coin_pool != null:
		_coin_pool.set_screen_target(provider)


func _build_pools() -> void:
	if _coin_pool != null:
		return
	XPOrb.prewarm()
	_coin_pool = _CoinRewardPool.new()
	_coin_pool.name = "SplitterCoinPool"
	add_child(_coin_pool)
	_coin_pool.initialize(_camera)
	_coin_pool.batch_started.connect(coin_batch_started.emit)
	_coin_pool.coin_collected.connect(coin_collected.emit)
	_coin_pool.coins_cancelled.connect(coins_cancelled.emit)
	_coin_pool.batch_finished.connect(coin_batch_finished.emit)

	_orb_root = Node3D.new()
	_orb_root.name = "SplitterXPOrbPool"
	add_child(_orb_root)
	for i in range(_ORB_CAPACITY):
		var orb := XPOrb.new()
		orb.name = "SplitterXPOrb%d" % i
		_orb_root.add_child(orb)
		orb.prepare_for_pool()
		orb.collected.connect(_on_orb_collected)
		_orbs.append(orb)

	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.018, 0.008, 0.055)
	var chip_material := StandardMaterial3D.new()
	chip_material.albedo_color = Color(0.72, 0.42, 0.14, 1.0)
	chip_mesh.get_rid()
	chip_material.get_rid()
	for i in range(_CHIP_CAPACITY):
		var chip := MeshInstance3D.new()
		chip.name = "SplitterChip%d" % i
		chip.mesh = chip_mesh
		chip.material_override = chip_material
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chip.visible = false
		add_child(chip)
		_chips.append(chip)
		_chip_velocities.append(Vector3.ZERO)
		_chip_ages.append(-1.0)


func _on_settlement_started(receipt_id: StringName, _species_id: StringName) -> void:
	if receipt_id == &"":
		return
	_active_receipt_id = receipt_id
	var origin := _origin()
	_coin_pool.begin_burst(origin, 1, _GROUND_Y, _SCATTER_RADIUS,
		_COLLECT_AT, 0.0)


func _on_settlement_cancelled(receipt_id: StringName) -> void:
	if receipt_id != _active_receipt_id:
		return
	_coin_pool.cancel_next_unpaid()
	_active_receipt_id = &""


func _on_cycle_completed(_species_id: StringName, _item_id: StringName,
		_amount: int, receipt_id: StringName) -> void:
	if _runtime == null:
		return
	# The started signal normally staged this before GameState cash changed. Keep
	# the fallback bounded for harnesses that connect after settlement began.
	if receipt_id != _active_receipt_id:
		_on_settlement_started(receipt_id, _species_id)
	_coin_pool.queue_payout(_runtime.last_cash_earned())
	_burst_xp(_runtime.last_xp_earned(), _origin())
	_burst_chips(_origin())
	_active_receipt_id = &""


func _burst_xp(amount: int, origin: Vector3) -> void:
	if amount <= 0 or _camera == null:
		return
	var count := clampi(int(round(sqrt(float(amount)) * _ORB_DENSITY)),
		_ORB_COUNT_MIN, _ORB_COUNT_MAX)
	count = mini(count, amount)
	var available: Array[XPOrb] = []
	for orb: XPOrb in _orbs:
		if orb.is_available():
			available.append(orb)
	count = mini(count, available.size())
	if count <= 0:
		return
	xp_orb_batch_started.emit(amount)
	var share := floori(float(amount) / float(count))
	var remainder := amount % count
	for i in range(count):
		available[i].setup(origin, _camera, float(i) * _ORB_STAGGER,
			_SCATTER_RADIUS, _GROUND_Y, _SCATTER_RADIUS, _COLLECT_AT,
			share + (1 if i < remainder else 0), _xp_screen_target)


func _on_orb_collected(amount: int) -> void:
	xp_orb_collected.emit(amount)


func _burst_chips(origin: Vector3) -> void:
	for i in range(_chips.size()):
		var angle := TAU * float(i) / float(_chips.size())
		_chips[i].global_position = origin
		_chips[i].rotation = Vector3(randf_range(-1.0, 1.0), angle,
			randf_range(-1.0, 1.0))
		_chips[i].scale = Vector3.ONE
		_chips[i].visible = true
		_chip_velocities[i] = Vector3(cos(angle) * randf_range(0.18, 0.42),
			randf_range(0.42, 0.78), sin(angle) * randf_range(0.18, 0.42))
		_chip_ages[i] = 0.0
	set_process(true)


func _process(delta: float) -> void:
	var any_active := false
	for i in range(_chips.size()):
		if _chip_ages[i] < 0.0:
			continue
		_chip_ages[i] += delta
		if _chip_ages[i] >= 0.58:
			_chip_ages[i] = -1.0
			_chips[i].visible = false
			continue
		any_active = true
		_chip_velocities[i].y -= 2.8 * delta
		_chips[i].global_position += _chip_velocities[i] * delta
		_chips[i].rotate_x(delta * 11.0)
		_chips[i].rotate_z(delta * 8.0)
		_chips[i].scale = Vector3.ONE * (1.0 - _chip_ages[i] / 0.58)
	set_process(any_active)


func _origin() -> Vector3:
	if _origin_provider.is_valid():
		var value: Variant = _origin_provider.call()
		if value is Vector3:
			return value
	return Vector3(-0.55, 0.42, -0.72)


func show_for_render_warmup(world_position: Vector3) -> void:
	if _coin_pool != null:
		_coin_pool.show_for_render_warmup(world_position)
	if not _orbs.is_empty():
		_orbs[0].show_for_render_warmup(world_position + Vector3.RIGHT * 0.08)
	if not _chips.is_empty():
		_chips[0].global_position = world_position + Vector3.UP * 0.06
		_chips[0].visible = true


func hide_render_warmup() -> void:
	if _coin_pool != null:
		_coin_pool.hide_render_warmup()
	if not _orbs.is_empty():
		_orbs[0].hide_render_warmup()
	if not _chips.is_empty() and _chip_ages[0] < 0.0:
		_chips[0].visible = false
