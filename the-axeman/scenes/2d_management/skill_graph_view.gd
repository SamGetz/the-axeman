class_name SkillGraphView
extends Control
## One navigable WoW-style branch. Semantic grid coordinates remain in data;
## this control owns only their presentation and prerequisite connectors.

signal node_selected(id: StringName)

const NODE_SIZE := Vector2(42.0, 42.0)
const CELL := Vector2(50.0, 44.0)
const GRAPH_MIN_HEIGHT := 88.0
const GRAPH_HEIGHT := 400.0

var _branch: SkillBranchDef
var _selected: StringName = &""
var _centres: Dictionary = {}
var _buttons: Dictionary = {}
var _positions: Dictionary = {}
var _presented_points_available := -1


class SkillIconButton extends Button:
	## Godot's stock tooltip is too small and low-contrast for the amount of
	## information a one-click purchase needs. Each icon owns a readable tooltip
	## card, while tooltip_text remains populated for keyboard/accessibility APIs.
	var tooltip_title := ""
	var tooltip_body := ""
	var tooltip_footer := ""
	var tooltip_accent := Color(0.82, 0.63, 0.28, 1.0)

	func _make_custom_tooltip(_for_text: String) -> Object:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(360.0, 0.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var surface := StyleBoxFlat.new()
		surface.bg_color = Color(0.055, 0.050, 0.045, 0.985)
		surface.border_color = tooltip_accent
		surface.set_border_width_all(2)
		surface.set_corner_radius_all(8)
		surface.content_margin_left = 14.0
		surface.content_margin_right = 14.0
		surface.content_margin_top = 12.0
		surface.content_margin_bottom = 12.0
		panel.add_theme_stylebox_override("panel", surface)

		var copy := VBoxContainer.new()
		copy.add_theme_constant_override("separation", 8)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(copy)

		var title := Label.new()
		title.text = tooltip_title
		title.custom_minimum_size = Vector2(328.0, 0.0)
		title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.66))
		title.add_theme_font_size_override("font_size", 17)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(title)

		var body := Label.new()
		body.text = tooltip_body
		body.custom_minimum_size = Vector2(328.0, 0.0)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_constant_override("line_spacing", 3)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(body)

		var footer := Label.new()
		footer.text = tooltip_footer
		footer.custom_minimum_size = Vector2(328.0, 0.0)
		footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		footer.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
		footer.add_theme_font_size_override("font_size", 13)
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(footer)
		return panel


func configure(branch: SkillBranchDef, selected: StringName,
		presented_points_available := -1) -> void:
	_branch = branch
	_selected = selected
	_presented_points_available = presented_points_available
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_centres.clear()
	_buttons.clear()
	_positions.clear()
	if branch == null:
		queue_redraw()
		return
	var nodes: Array[SkillNodeDef] = []
	for node: SkillNodeDef in SkillTree.get_presented_nodes():
		if node != null and node.branch_id == branch.id:
			nodes.append(node)
	var revealed_height := GRAPH_MIN_HEIGHT
	for node: SkillNodeDef in nodes:
		revealed_height = maxf(revealed_height,
			float(node.presentation_position.y) * CELL.y + NODE_SIZE.y)
	custom_minimum_size = Vector2(170.0, minf(revealed_height, GRAPH_HEIGHT))
	for node: SkillNodeDef in nodes:
		var button := _make_node_button(node)
		add_child(button)
		_buttons[node.id] = button
		_positions[node.id] = node.presentation_position
	_layout_nodes()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _buttons.is_empty():
		_layout_nodes()


func _layout_nodes() -> void:
	# Authored x slots are 1..3. Centre that three-lane span in whatever share of
	# the window this branch receives; revealing Frontier simply narrows all four.
	var used_width := CELL.x * 2.0 + NODE_SIZE.x
	var base_x := (size.x - used_width) * 0.5 - CELL.x
	for id: StringName in _buttons:
		var semantic: Vector2i = _positions[id]
		var pos := Vector2(base_x + float(semantic.x) * CELL.x,
			float(semantic.y) * CELL.y)
		(_buttons[id] as Button).position = pos
		_centres[id] = pos + NODE_SIZE * 0.5
	queue_redraw()


func _draw() -> void:
	if _branch == null:
		return
	for node: SkillNodeDef in SkillTree.get_presented_nodes():
		if node == null or node.branch_id != _branch.id or not _centres.has(node.id):
			continue
		for required: StringName in node.requires:
			if not _centres.has(required):
				continue
			var required_def := SkillTree.get_node_def(required)
			var learned := required_def != null \
				and required_def.is_maxed(SkillTree.get_level(required))
			var color := _branch.color if learned else Color(0.30, 0.31, 0.34, 0.72)
			draw_line(_centres[required], _centres[node.id], color, 5.0, true)
			draw_circle(_centres[node.id], 4.0, color)


func _make_node_button(node: SkillNodeDef) -> Button:
	var button := SkillIconButton.new()
	button.name = String(node.id).to_pascal_case()
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	var level := SkillTree.get_level(node.id)
	var learned := node.is_maxed(level)
	var available := SkillTree.can_buy(node.id) \
		and (_presented_points_available < 0 or _presented_points_available > 0)
	var locked := not SkillTree.prerequisites_met(node.id)
	button.text = _icon_letters(node.display_name) if node.max_level == 1 else (
		"%s\n%d/%d" % [_icon_letters(node.display_name), level, node.max_level])
	button.set_meta("rank_label", "%d/%d" % [level, node.max_level])
	button.tooltip_text = "%s\n%s\nRank: %d/%d\nCost: 1 point%s" % [
		node.display_name, node.description, level, node.max_level,
		"\nRequires: %s" % _prerequisite_names(node) if not node.requires.is_empty() else ""]
	button.tooltip_title = node.display_name
	button.tooltip_body = node.description + _rank_bonus_summary(node, level)
	var action_copy := "Need 1 available skill point"
	if learned:
		action_copy = "Fully ranked · %d/%d" % [level, node.max_level]
	elif locked:
		action_copy = "Locked · complete %s prerequisite branch" % (
			"either" if node.requires.size() > 1 else "the")
	elif available:
		action_copy = "Click to learn rank %d/%d" % [level + 1, node.max_level]
	button.tooltip_footer = "%s  ·  1 skill point%s" % [
		action_copy,
		"  ·  Requires: %s" % _prerequisite_names(node) if not node.requires.is_empty() else ""]
	button.tooltip_accent = _branch.color
	button.set_meta("skill_id", node.id)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(func() -> void: node_selected.emit(node.id))
	var partially_ranked := level > 0 and not learned
	var state := "insufficient"
	if learned:
		state = "learned"
	elif partially_ranked:
		state = "ranked"
	elif available:
		state = "available"
	elif locked:
		state = "locked"
	button.set_meta("skill_state", state)
	var fill := Color(0.12, 0.13, 0.15, 0.96)
	var border := Color(0.34, 0.35, 0.38, 1.0)
	if learned:
		fill = _branch.color.darkened(0.48)
		border = _branch.color.lightened(0.18)
	elif partially_ranked:
		fill = _branch.color.darkened(0.58)
		border = _branch.color.lightened(0.08)
	elif available:
		fill = _branch.color.darkened(0.70)
		border = _branch.color
	elif locked:
		button.modulate = Color(0.66, 0.66, 0.68, 0.72)
	button.add_theme_color_override("font_color",
		Color(0.96, 0.94, 0.88) if not locked else Color(0.78, 0.78, 0.78))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	if node.node_type == SkillNodeDef.NodeType.CAPSTONE:
		border = Color(1.0, 0.76, 0.22, 1.0)
	var width := 4 if node.id == _selected else (3 if node.node_type == SkillNodeDef.NodeType.CAPSTONE else 2)
	button.add_theme_stylebox_override("normal", _style(fill, border, width))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.08), border.lightened(0.15), 3))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.08), border, 4))
	return button


func _icon_letters(label: String) -> String:
	var words := label.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return label.left(2).to_upper()


func _prerequisite_names(node: SkillNodeDef) -> String:
	var names: Array[String] = []
	for id: StringName in node.requires:
		var required := SkillTree.get_node_def(id)
		names.append(String(id) if required == null else "%s (%d/%d)" % [
			required.display_name, SkillTree.get_level(id), required.max_level])
	var separator := " or " if node.requires.size() > 1 else ""
	return separator.join(names)


func _rank_bonus_summary(node: SkillNodeDef, level: int) -> String:
	if node.max_level <= 1:
		return ""
	var lines: Array[String] = []
	for modifier: GameplayModifierDef in node.effects:
		var line := _rank_bonus_line(modifier, level, node.max_level)
		if not line.is_empty():
			lines.append("• " + line)
	for modifier: GameplayModifierDef in node.modifiers:
		var line := _rank_bonus_line(modifier, level, node.max_level)
		if not line.is_empty():
			lines.append("• " + line)
	return "" if lines.is_empty() else "\n\nCURRENT BONUS · RANK %d/%d\n%s" % [
		level, node.max_level, "\n".join(lines)]


func _rank_bonus_line(modifier: GameplayModifierDef, level: int,
		max_level: int) -> String:
	if modifier == null or modifier.operation == GameplayModifierDef.Operation.ENABLE:
		return ""
	var current := modifier.magnitude * float(level)
	var maximum := modifier.magnitude * float(max_level)
	var now := _percent_text(current)
	var maxed := _percent_text(maximum)
	var now_points := _number_text(current * 100.0)
	var max_points := _number_text(maximum * 100.0)
	match modifier.kind:
		GameplayModifierDef.Kind.SPLIT_RELIABILITY:
			return "Split chance: +%s%% now · +%s%% at rank 5" % [now_points, max_points]
		GameplayModifierDef.Kind.SCAR_RELIABILITY:
			return "Split chance from each scar: +%s%% now · +%s%% at rank 5" % [now_points, max_points]
		GameplayModifierDef.Kind.SWING_RECOVERY:
			return "Wait after a swing: %s shorter now · %s at rank 5" % [now, maxed]
		GameplayModifierDef.Kind.WINDUP_TIME:
			return "Axe wind-up: %s shorter now · %s at rank 5" % [now, maxed]
		GameplayModifierDef.Kind.ORBIT_SPEED:
			return "Camera turns: %s faster now · %s at rank 5" % [now, maxed]
		GameplayModifierDef.Kind.LOG_TURNAROUND:
			return "Wait between logs: %s shorter now · %s at rank 5" % [now, maxed]
		GameplayModifierDef.Kind.GLOBAL_XP_GAIN:
			return "XP earned: +%s now · +%s at rank 5" % [now, maxed]
		GameplayModifierDef.Kind.CASH_GAIN:
			return "Cash earned: +%s now · +%s at rank 5" % [now, maxed]
		GameplayModifierDef.Kind.ALIEN_HANDLING:
			return "Alien-wood split chance: +%s%% now · +%s%% at rank 5" % [now_points, max_points]
		GameplayModifierDef.Kind.CONTRIBUTION_EFFICIENCY:
			return "Launch progress from timber: +%s now · +%s at rank 5" % [now, maxed]
	return ""


func _percent_text(value: float) -> String:
	var percentage := value * 100.0
	return _number_text(percentage) + "%"


func _number_text(value: float) -> String:
	return "%d" % int(round(value)) if is_equal_approx(value, round(value)) \
		else "%.1f" % value


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(11)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style
