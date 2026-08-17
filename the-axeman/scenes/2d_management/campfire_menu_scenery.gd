extends Control
## Lightweight title-screen scenery drawn in native Godot primitives.
## The shader supplies the ember-lit sky; this layer adds a quiet tree line,
## ground silhouette, split logs, and drifting sparks without texture assets.

const PINE := Color(0.018, 0.027, 0.022, 0.92)
const PINE_NEAR := Color(0.012, 0.018, 0.014, 0.98)
const GROUND := Color(0.011, 0.014, 0.011, 1.0)
const LOG_BARK := Color(0.12, 0.054, 0.026, 0.92)
const LOG_END := Color(0.44, 0.19, 0.07, 0.92)

var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var ground_y := viewport_size.y * 0.83
	draw_rect(Rect2(0.0, ground_y, viewport_size.x,
		viewport_size.y - ground_y), GROUND)

	# The open centre keeps the brand and primary action readable. The heavier
	# edge trees produce the same vignetted stage framing as the reference.
	var back_trees := [
		Vector3(0.02, 0.70, 0.19), Vector3(0.09, 0.76, 0.13),
		Vector3(0.16, 0.79, 0.10), Vector3(0.84, 0.79, 0.10),
		Vector3(0.91, 0.75, 0.14), Vector3(0.98, 0.69, 0.20),
	]
	for tree: Vector3 in back_trees:
		_draw_pine(Vector2(viewport_size.x * tree.x, viewport_size.y * tree.y),
			viewport_size.y * tree.z, PINE)
	var near_trees := [
		Vector3(-0.015, 0.82, 0.31), Vector3(0.075, 0.84, 0.22),
		Vector3(0.925, 0.84, 0.23), Vector3(1.015, 0.82, 0.32),
	]
	for tree: Vector3 in near_trees:
		_draw_pine(Vector2(viewport_size.x * tree.x, viewport_size.y * tree.y),
			viewport_size.y * tree.z, PINE_NEAR)

	_draw_log(Vector2(viewport_size.x * 0.46, viewport_size.y * 0.865),
		viewport_size.x * 0.10, -0.18)
	_draw_log(Vector2(viewport_size.x * 0.54, viewport_size.y * 0.872),
		viewport_size.x * 0.10, PI + 0.16)

	# Deterministic spark paths avoid RNG churn while still giving the title
	# screen a living campfire pulse.
	for index: int in range(24):
		var phase := fmod(_elapsed * (0.12 + float(index % 5) * 0.018)
			+ float(index) * 0.137, 1.0)
		var spread := sin(float(index) * 12.37 + _elapsed * 0.7) * 0.17
		var spark_x := viewport_size.x * (0.5 + spread * (0.25 + phase))
		var spark_y := viewport_size.y * (0.87 - phase * 0.58)
		var alpha := sin(phase * PI) * (0.20 + float(index % 4) * 0.08)
		var radius := 1.1 + float(index % 3) * 0.65
		draw_circle(Vector2(spark_x, spark_y), radius,
			Color(1.0, 0.48 + float(index % 3) * 0.10, 0.12, alpha))


func _draw_pine(base: Vector2, height: float, color: Color) -> void:
	var width := height * 0.48
	draw_rect(Rect2(base.x - width * 0.055, base.y - height * 0.28,
		width * 0.11, height * 0.30), color)
	for tier: int in range(3):
		var tier_top := base.y - height * (0.95 - float(tier) * 0.25)
		var tier_bottom := base.y - height * (0.40 - float(tier) * 0.19)
		var tier_width := width * (0.58 + float(tier) * 0.23)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x, tier_top),
			Vector2(base.x - tier_width, tier_bottom),
			Vector2(base.x + tier_width, tier_bottom),
		]), color)


func _draw_log(center: Vector2, length: float, angle: float) -> void:
	var half_length := length * 0.5
	var half_width := length * 0.075
	var forward := Vector2(cos(angle), sin(angle))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center - forward * half_length - side * half_width,
		center + forward * half_length - side * half_width,
		center + forward * half_length + side * half_width,
		center - forward * half_length + side * half_width,
	])
	draw_colored_polygon(points, LOG_BARK)
	draw_circle(center + forward * half_length, half_width, LOG_END)
	draw_circle(center + forward * half_length, half_width * 0.55,
		Color(0.22, 0.085, 0.035, 0.75))
