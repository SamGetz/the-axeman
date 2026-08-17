class_name LevelUpOfferRain
extends Control
## Presentation-only, pooled level-choice shower. It uses its own deterministic
## RNG and one CanvasItem draw pass, so rerolls cannot perturb gameplay rolls or
## create a growing tree of TextureRects/Tweens.

const _CONFIG := preload("res://data/skill_vfx_config.tres")
const _TREE := preload("res://assets/generated/vfx/level_up_pine.png")
const _LOG := preload("res://assets/ui/wood_icon.svg")

enum DropKind { TREE, LOG, LEAF }

var _rng := RandomNumberGenerator.new()
var _rain_rect := Rect2()
var _positions := PackedVector2Array()
var _sizes := PackedFloat32Array()
var _fall_speeds := PackedFloat32Array()
var _drifts := PackedFloat32Array()
var _rotations := PackedFloat32Array()
var _spin_speeds := PackedFloat32Array()
var _phases := PackedFloat32Array()
var _kinds := PackedInt32Array()
var _active := false
var _elapsed := 0.0
var _animation_tick := 0
var _seed := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()


func restart(seed: int, effect_rect: Rect2) -> void:
	_seed = maxi(1, seed)
	_rain_rect = effect_rect
	_active = true
	_elapsed = 0.0
	_animation_tick = 0
	_rng.seed = _seed
	_reset_pool()
	show()
	set_process(true)
	queue_redraw()


func stop() -> void:
	_active = false
	set_process(false)
	hide()
	queue_redraw()


func set_effect_rect(effect_rect: Rect2) -> void:
	if _rain_rect.is_equal_approx(effect_rect):
		return
	_rain_rect = effect_rect
	if _active:
		_rng.seed = _seed
		_reset_pool()
		queue_redraw()


func is_active() -> bool:
	return _active


func debug_state() -> Dictionary:
	var counts := [0, 0, 0]
	for kind: int in _kinds:
		if kind >= DropKind.TREE and kind <= DropKind.LEAF:
			counts[kind] += 1
	return {
		"active": _active,
		"animation_tick": _animation_tick,
		"allocated": _positions.size(),
		"live": _positions.size() if _active else 0,
		"trees": counts[DropKind.TREE],
		"logs": counts[DropKind.LOG],
		"leaves": counts[DropKind.LEAF],
		"effect_rect": _rain_rect,
		"processing": is_processing(),
	}


func _process(delta: float) -> void:
	if not _active or delta <= 0.0 or _rain_rect.size.x <= 1.0 \
			or _rain_rect.size.y <= 1.0:
		return
	_elapsed += delta
	_animation_tick += 1
	var left := _rain_rect.position.x
	var right := _rain_rect.end.x
	var bottom := _rain_rect.end.y
	for index: int in range(_positions.size()):
		var point := _positions[index]
		point.y += _fall_speeds[index] * delta
		point.x += sin(_elapsed * 1.15 + _phases[index]) \
			* _drifts[index] * delta
		_rotations[index] += _spin_speeds[index] * delta
		var half_size := _sizes[index] * 0.5
		if point.y - half_size > bottom:
			point.y = _rain_rect.position.y - half_size
			point.x = _rng.randf_range(left + half_size, right - half_size)
		if point.x < left - half_size:
			point.x = right + half_size
		elif point.x > right + half_size:
			point.x = left - half_size
		_positions[index] = point
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var alpha := clampf(_CONFIG.level_offer_rain_opacity, 0.0, 1.0)
	for index: int in range(_positions.size()):
		draw_set_transform(_positions[index], _rotations[index], Vector2.ONE)
		var drop_size := _sizes[index]
		match _kinds[index]:
			DropKind.TREE:
				_draw_texture_drop(_TREE, drop_size,
					Color(1.0, 0.94, 0.80, alpha))
			DropKind.LOG:
				_draw_texture_drop(_LOG, drop_size,
					Color(0.48, 0.20, 0.07, alpha * 1.12))
			DropKind.LEAF:
				_draw_leaf(drop_size, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_texture_drop(texture: Texture2D, drop_size: float,
		modulate: Color) -> void:
	if texture == null:
		return
	var source := texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return
	var scale_factor := drop_size / maxf(source.x, source.y)
	var draw_size := source * scale_factor
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false,
		modulate)


func _draw_leaf(drop_size: float, alpha: float) -> void:
	var leaf := PackedVector2Array([
		Vector2(0.0, -0.52), Vector2(0.31, -0.30),
		Vector2(0.48, 0.02), Vector2(0.22, 0.31),
		Vector2(0.0, 0.50), Vector2(-0.22, 0.31),
		Vector2(-0.48, 0.02), Vector2(-0.31, -0.30),
	])
	for index: int in range(leaf.size()):
		leaf[index] *= drop_size
	draw_colored_polygon(leaf, Color(0.20, 0.48, 0.20, alpha))
	draw_polyline(PackedVector2Array([
		Vector2(0.0, drop_size * 0.56),
		Vector2(0.0, -drop_size * 0.40),
	]), Color(0.08, 0.23, 0.10, alpha * 1.25),
		maxf(1.0, drop_size * 0.08), true)


func _reset_pool() -> void:
	_positions.clear()
	_sizes.clear()
	_fall_speeds.clear()
	_drifts.clear()
	_rotations.clear()
	_spin_speeds.clear()
	_phases.clear()
	_kinds.clear()
	if _rain_rect.size.x <= 1.0 or _rain_rect.size.y <= 1.0:
		return
	var count := maxi(3, _CONFIG.level_offer_rain_count)
	for index: int in range(count):
		var drop_size := _rng.randf_range(_CONFIG.level_offer_rain_size_min,
			_CONFIG.level_offer_rain_size_max)
		var half_size := drop_size * 0.5
		_positions.append(Vector2(
			_rng.randf_range(_rain_rect.position.x + half_size,
				_rain_rect.end.x - half_size),
			_rng.randf_range(_rain_rect.position.y - half_size,
				_rain_rect.end.y + half_size)))
		_sizes.append(drop_size)
		_fall_speeds.append(_rng.randf_range(
			_CONFIG.level_offer_rain_speed_min,
			_CONFIG.level_offer_rain_speed_max))
		_drifts.append(_rng.randf_range(
			_CONFIG.level_offer_rain_drift_min,
			_CONFIG.level_offer_rain_drift_max))
		_rotations.append(_rng.randf_range(-0.45, 0.45))
		var spin := _rng.randf_range(_CONFIG.level_offer_rain_spin_min,
			_CONFIG.level_offer_rain_spin_max)
		_spin_speeds.append(spin * (-1.0 if index % 2 == 0 else 1.0))
		_phases.append(_rng.randf_range(0.0, TAU))
		_kinds.append(index % 3)
