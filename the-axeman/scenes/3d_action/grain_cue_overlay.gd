extends Control
## Screen-space half of the grain opportunity. The corners and centre diamond
## remain readable without colour; Technique's authored branch colour is an
## additional identity layer, never the only carrier.

var _branch_color := Color.WHITE
var _config: Resource
var _label: Label


func setup(branch_color: Color, config: Resource) -> void:
	_branch_color = branch_color
	_config = config
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = config.bracket_size
	_label = Label.new()
	_label.text = config.cue_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_font_size_override("font_size", 18)
	_label.position = Vector2(-80.0, config.label_offset_y)
	_label.size = Vector2(size.x + 160.0, 28.0)
	add_child(_label)
	queue_redraw()


func place_at(screen_position: Vector2, viewport_size: Vector2) -> void:
	var desired := screen_position - size * 0.5
	position = Vector2(
		clampf(desired.x, 4.0, maxf(4.0, viewport_size.x - size.x - 4.0)),
		clampf(desired.y, 4.0, maxf(4.0, viewport_size.y - size.y - 36.0)))


func cue_text() -> String:
	return "" if _label == null else _label.text


func _draw() -> void:
	if _config == null:
		return
	var w := size.x
	var h := size.y
	var a: float = _config.bracket_arm
	var outline: float = _config.bracket_outline_width
	var core: float = _config.bracket_core_width
	var dark := Color(0.02, 0.025, 0.02, 0.96)
	var white := Color(1.0, 1.0, 1.0, 0.98)
	var corners := [
		PackedVector2Array([Vector2(a, 0.0), Vector2(0.0, 0.0), Vector2(0.0, a)]),
		PackedVector2Array([Vector2(w - a, 0.0), Vector2(w, 0.0), Vector2(w, a)]),
		PackedVector2Array([Vector2(0.0, h - a), Vector2(0.0, h), Vector2(a, h)]),
		PackedVector2Array([Vector2(w, h - a), Vector2(w, h), Vector2(w - a, h)]),
	]
	for corner: PackedVector2Array in corners:
		draw_polyline(corner, dark, outline, true)
		draw_polyline(corner, white, core + 2.0, true)
		draw_polyline(corner, _branch_color, core, true)

	# A diamond remains an unmistakable target icon if colour is unavailable.
	var c := size * 0.5
	var diamond := PackedVector2Array([
		c + Vector2(0.0, -8.0), c + Vector2(8.0, 0.0),
		c + Vector2(0.0, 8.0), c + Vector2(-8.0, 0.0),
		c + Vector2(0.0, -8.0),
	])
	draw_polyline(diamond, dark, outline, true)
	draw_polyline(diamond, white, core + 2.0, true)
	draw_polyline(diamond, _branch_color, core, true)
