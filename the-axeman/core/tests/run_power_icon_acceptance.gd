extends Control
## Visual/catalogue gate for the complete run-power icon language. The gallery
## keeps every emblem visible in one 1280×720 checkpoint so duplicated or
## unreadable icons cannot hide behind offer RNG or a scrolled Home catalogue.

const _CAPTURE_PATH := "/private/tmp/axeman_run_power_icons.png"

var _passed := 0
var _failed := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.035, 0.026, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var title := Label.new()
	title.text = "RUN POWER ICONS · 27 DISTINCT EMBLEMS"
	title.position = Vector2(32, 16)
	title.size = Vector2(1216, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66, 1.0))
	add_child(title)

	var grid := GridContainer.new()
	grid.name = "IconGrid"
	grid.columns = 7
	grid.position = Vector2(28, 58)
	grid.size = Vector2(1224, 636)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)

	var table := SurvivorsContent.run_powers()
	var paths: Dictionary = {}
	var loaded := table != null and table.powers.size() == 27 \
		and table.powers.size() <= RunPowerTable.MAX_POWER_COUNT
	if table != null:
		for definition: RunPowerDef in table.powers:
			if definition == null:
				loaded = false
				continue
			var texture := load(definition.icon_path) as Texture2D
			loaded = loaded and texture != null \
				and definition.icon_path.begins_with("res://assets/ui/powers/") \
				and not paths.has(definition.icon_path)
			paths[definition.icon_path] = true
			grid.add_child(_icon_card(definition, texture))
	_check(loaded and paths.size() == 27 and grid.get_child_count() == 27,
		"all 27 powers own one distinct loadable icon below the 32-power cap")

	for _frame: int in range(5):
		await get_tree().process_frame
	var geometry_ok := grid.get_child_count() == 27
	for raw_card: Node in grid.get_children():
		var card := raw_card as Control
		var icon := raw_card.find_child("Icon", true, false) as TextureRect
		geometry_ok = geometry_ok and card != null and icon != null \
			and card.size.x <= 169.01 and card.size.y <= 151.01 \
			and icon.visible and icon.texture != null
	_check(geometry_ok,
		"the full icon gallery fits at readable size inside one 1280x720 frame")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image != null and image.get_width() == 1280 \
			and image.get_height() == 720 and image.save_png(_CAPTURE_PATH) == OK,
			"the rendered 27-icon checkpoint writes at 1280x720")
	print("RUN POWER ICONS: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _icon_card(definition: RunPowerDef, texture: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(168, 150)
	card.add_theme_stylebox_override("panel", _card_style(
		Color(0.42, 0.76, 0.49, 1.0)))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(76, 76)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var name_label := Label.new()
	name_label.text = definition.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80, 1.0))
	column.add_child(name_label)
	var detail := Label.new()
	detail.text = "CORE" if definition.pool == RunPowerDef.Pool.CORE \
		else "BLUEPRINT"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", Color(0.42, 0.76, 0.49, 1.0))
	column.add_child(detail)
	return card


func _card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.06, 0.98)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
