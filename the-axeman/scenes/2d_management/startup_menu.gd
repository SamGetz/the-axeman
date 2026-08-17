class_name StartupMenu
extends Control
## FILE: res://scenes/2d_management/startup_menu.gd
## ATTACHES TO: StartupMenu, instanced above the dormant yard by main.tscn.
##
## Main owns profile loading, run lifecycle, and persistence. This surface emits
## run intent and performs home-only progression writes through GameState's
## public transaction API. All copy and tuning shown here comes from the
## immutable SurvivorsContent catalogues.

signal new_profile_requested
signal continue_profile_requested
signal resume_attempt_requested
signal abandon_attempt_requested
## Compatibility aliases for non-survival startup harnesses.
signal new_game_requested
signal load_game_requested

const TAB_HOME: StringName = &"home"
const TAB_UPGRADES: StringName = &"upgrades"
const TAB_YARD: StringName = &"yard"
const TAB_POWERS: StringName = &"powers"
const TAB_RECORDS: StringName = &"records"

const INK := Color(1.0, 0.89, 0.68, 1.0)
const MUTED := Color(0.73, 0.67, 0.56, 1.0)
const DIM := Color(0.47, 0.43, 0.37, 1.0)
const GOLD := Color(0.96, 0.58, 0.19, 1.0)
const GREEN := Color(0.55, 0.78, 0.48, 1.0)
const RED := Color(0.94, 0.61, 0.51, 1.0)
const BLUE := Color(0.48, 0.72, 0.90, 1.0)
const PURPLE := Color(0.75, 0.55, 0.91, 1.0)
const PANEL_DARK := Color(0.045, 0.032, 0.024, 0.96)
const PANEL_MID := Color(0.078, 0.052, 0.035, 0.97)
const PANEL_LIGHT := Color(0.115, 0.074, 0.043, 0.98)
const BORDER := Color(0.55, 0.28, 0.10, 1.0)

var _has_save := false
var _has_attempt := false
var _current_tab: StringName = TAB_HOME
var _home_message_override := ""
var _nav_buttons: Dictionary = {}
var _pending_level_select_after_profile_create := false
var _selected_upgrade_id: StringName = &"axe_power"

var _home_root: MarginContainer
var _home_header: PanelContainer
var _home_brand_kicker: Label
var _home_brand_title: Label
var _home_brand_subtitle: Label
var _home_profile_column: VBoxContainer
var _home_bank_column: VBoxContainer
var _home_back_button: Button
var _home_landing_spacer: Control
var _home_landing_lower_spacer: Control
var _home_content_panel: PanelContainer
var _home_action_panel: PanelContainer
var _home_action_copy: HBoxContainer
var _home_quick_start_button: Button
var _home_nav_panel: PanelContainer
var _home_nav_row: HBoxContainer
var _home_detail_host: VBoxContainer
var _home_cash_label: Label
var _home_lock_banner: PanelContainer
var _home_message_label: Label
var _home_content_title: Label
var _home_content_subtitle: Label
var _home_scroll: ScrollContainer
var _home_content: VBoxContainer
var _home_selection_label: Label
var _home_start_button: Button
var _home_level_start_button: Button
var _home_resume_button: Button
var _home_abandon_button: Button
var _home_new_profile_button: Button

@onready var _intro_center: CenterContainer = $Center
@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _resume_attempt_button: Button = %ResumeAttemptButton
@onready var _abandon_attempt_button: Button = %AbandonAttemptButton
@onready var _status_label: Label = %StatusLabel
@onready var _footer: Label = %Footer
@onready var _new_game_confirmation: ConfirmationDialog = %NewGameConfirmation


func _ready() -> void:
	_footer.text = "Progress saves automatically. · Alpha %s · %s" % [
		ProjectSettings.get_setting("application/config/version", "unversioned"),
		ProjectSettings.get_setting("application/config/build_date", "undated"),
	]
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_continue_pressed)
	_resume_attempt_button.pressed.connect(resume_attempt_requested.emit)
	_abandon_attempt_button.pressed.connect(abandon_attempt_requested.emit)
	_new_game_confirmation.confirmed.connect(_emit_new_profile)
	_style_confirmation_dialog()
	_build_home()
	if not GameState.profile_changed.is_connected(_on_profile_changed):
		GameState.profile_changed.connect(_on_profile_changed)
	if not GameState.permanent_controls_lock_changed.is_connected(
			_on_permanent_controls_lock_changed):
		GameState.permanent_controls_lock_changed.connect(
			_on_permanent_controls_lock_changed)
	_apply_mode()


func configure(has_save: bool, has_attempt: bool = false) -> void:
	_has_save = has_save
	_has_attempt = has_save and has_attempt
	if _has_save:
		if _pending_level_select_after_profile_create and not _has_attempt:
			_current_tab = TAB_YARD
		else:
			_current_tab = TAB_HOME
		_pending_level_select_after_profile_create = false
	else:
		_current_tab = TAB_HOME
	## The public authority repeats the lock check inside every relevant write.
	## Mirroring the suspended-attempt fact here keeps non-UI callers safe too.
	GameState.set_permanent_controls_locked(_has_attempt)
	_apply_mode()


func show_error(message: String) -> void:
	_home_message_override = message.strip_edges()
	_status_label.text = _home_message_override
	_refresh_home(false)


func dismiss() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func _apply_mode() -> void:
	if not is_node_ready() or _home_root == null:
		return
	# The same authored landing is used before and after profile creation. The
	# legacy scene nodes remain as signal/test adapters, but never become a
	# second visually divergent title screen.
	_intro_center.visible = false
	_home_root.visible = true

	_load_game_button.disabled = not _has_save
	_load_game_button.visible = _has_save and not _has_attempt
	_load_game_button.text = "START"
	_resume_attempt_button.visible = _has_attempt
	_abandon_attempt_button.visible = _has_attempt
	_load_game_button.tooltip_text = (
		"Keep your permanent yard and begin a fresh attempt."
		if _has_save else "No saved yard was found."
	)
	_new_game_button.text = "START FRESH CAMP" if _has_save else "START"
	_status_label.text = (
		"A suspended run is ready."
		if _has_attempt
		else "Your permanent camp is ready for another run."
	) if _has_save else "No save found — light a new campfire."

	if _has_save:
		_refresh_home(true)
		if _has_attempt and _home_resume_button != null:
			_home_resume_button.grab_focus()
		elif _current_tab == TAB_YARD and _home_level_start_button != null:
			_home_level_start_button.grab_focus()
		elif _home_start_button != null:
			_home_start_button.grab_focus()
	else:
		_refresh_home(false)
		_home_start_button.grab_focus()


func _build_home() -> void:
	_home_root = MarginContainer.new()
	_home_root.name = "HomeRoot"
	_home_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_root.add_theme_constant_override("margin_left", 24)
	_home_root.add_theme_constant_override("margin_top", 14)
	_home_root.add_theme_constant_override("margin_right", 24)
	_home_root.add_theme_constant_override("margin_bottom", 14)
	add_child(_home_root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 9)
	_home_root.add_child(shell)

	_home_header = _make_panel(Color(0.035, 0.024, 0.018, 0.82), BORDER, 8)
	_home_header.custom_minimum_size = Vector2(0, 180)
	shell.add_child(_home_header)
	var header_margin := _make_margin(18, 10, 18, 10)
	_home_header.add_child(header_margin)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	header_margin.add_child(header_row)

	_home_profile_column = VBoxContainer.new()
	_home_profile_column.custom_minimum_size.x = 210
	_home_profile_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_profile_column.add_theme_constant_override("separation", 5)
	header_row.add_child(_home_profile_column)
	var profile_kicker := _make_label("CAMP PROFILE", 10, MUTED)
	_home_profile_column.add_child(profile_kicker)
	_home_new_profile_button = _make_button("NEW CAMP", false)
	_home_new_profile_button.name = "NewProfileButton"
	_home_new_profile_button.custom_minimum_size = Vector2(150, 40)
	_home_new_profile_button.pressed.connect(_on_new_game_pressed)
	_home_profile_column.add_child(_home_new_profile_button)
	_home_back_button = _make_button("BACK", false)
	_home_back_button.name = "BackButton"
	_home_back_button.custom_minimum_size = Vector2(150, 40)
	_home_back_button.visible = false
	_home_back_button.pressed.connect(_select_home_tab.bind(TAB_HOME))
	_home_profile_column.add_child(_home_back_button)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	title_column.add_theme_constant_override("separation", -2)
	header_row.add_child(title_column)
	_home_brand_kicker = _make_label(
		"FIFTEEN MINUTES · ONE CHOPPING BLOCK", 12, GOLD)
	_home_brand_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_column.add_child(_home_brand_kicker)
	_home_brand_title = _make_label("CAMPFIRE\nSURVIVORS", 52, INK)
	_home_brand_title.name = "GameTitle"
	_home_brand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_brand_title.add_theme_color_override(
		"font_shadow_color", Color(0.18, 0.025, 0.006, 1.0))
	_home_brand_title.add_theme_constant_override("line_spacing", -8)
	_home_brand_title.add_theme_constant_override("shadow_offset_x", 3)
	_home_brand_title.add_theme_constant_override("shadow_offset_y", 4)
	title_column.add_child(_home_brand_title)
	_home_brand_subtitle = _make_label("SPLIT · GROW · SURVIVE", 12, MUTED)
	_home_brand_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_column.add_child(_home_brand_subtitle)

	_home_bank_column = VBoxContainer.new()
	_home_bank_column.custom_minimum_size.x = 210
	_home_bank_column.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_child(_home_bank_column)
	var bank_kicker := _make_label("CAMP FUNDS", 10, MUTED)
	bank_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_home_bank_column.add_child(bank_kicker)
	_home_cash_label = _make_label("$0", 27, GOLD)
	_home_cash_label.name = "HomeCashLabel"
	_home_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_home_cash_label.custom_minimum_size.x = 210
	_home_bank_column.add_child(_home_cash_label)

	_home_lock_banner = _make_panel(Color(0.18, 0.075, 0.035, 0.98), RED, 7)
	_home_lock_banner.name = "SuspendedLockBanner"
	shell.add_child(_home_lock_banner)
	var lock_margin := _make_margin(14, 6, 14, 6)
	_home_lock_banner.add_child(lock_margin)
	var lock_label := _make_label(
		"SUSPENDED RUN · Camp upgrades and yard controls are read-only until you Resume or Abandon.",
		14, Color(1.0, 0.79, 0.64, 1.0))
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_margin.add_child(lock_label)

	_home_landing_spacer = Control.new()
	_home_landing_spacer.name = "LandingStage"
	_home_landing_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_home_landing_spacer)

	_home_content_panel = _make_panel(PANEL_DARK, BORDER, 8)
	_home_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_content_panel.visible = false
	shell.add_child(_home_content_panel)
	var content_margin := _make_margin(20, 12, 20, 12)
	_home_content_panel.add_child(content_margin)
	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 5)
	content_margin.add_child(content_column)
	_home_content_title = _make_label("POWER UP", 22, INK)
	_home_content_title.name = "ContentTitle"
	content_column.add_child(_home_content_title)
	_home_content_subtitle = _make_label("", 12, MUTED)
	_home_content_subtitle.name = "ContentSubtitle"
	_home_content_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_column.add_child(_home_content_subtitle)
	content_column.add_child(HSeparator.new())
	_home_scroll = ScrollContainer.new()
	_home_scroll.name = "ContentScroll"
	_home_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_column.add_child(_home_scroll)
	_home_content = VBoxContainer.new()
	_home_content.name = "Content"
	_home_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_content.add_theme_constant_override("separation", 12)
	_home_scroll.add_child(_home_content)
	_home_detail_host = VBoxContainer.new()
	_home_detail_host.name = "UpgradeDetailHost"
	_home_detail_host.visible = false
	content_column.add_child(_home_detail_host)

	_home_action_panel = _make_panel(
		Color(0.055, 0.035, 0.024, 0.97), BORDER, 8)
	_home_action_panel.custom_minimum_size.y = 94
	shell.add_child(_home_action_panel)
	var action_margin := _make_margin(14, 7, 14, 7)
	_home_action_panel.add_child(action_margin)
	var action_column := VBoxContainer.new()
	action_column.add_theme_constant_override("separation", 3)
	action_margin.add_child(action_column)
	var action_center := CenterContainer.new()
	action_column.add_child(action_center)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	action_center.add_child(action_row)
	_home_abandon_button = _make_button("ABANDON", false)
	_home_abandon_button.name = "AbandonAttemptButton"
	_home_abandon_button.custom_minimum_size = Vector2(132, 58)
	_home_abandon_button.pressed.connect(abandon_attempt_requested.emit)
	action_row.add_child(_home_abandon_button)
	_home_resume_button = _make_button("RESUME RUN", true)
	_home_resume_button.name = "ResumeAttemptButton"
	_home_resume_button.custom_minimum_size = Vector2(260, 58)
	_home_resume_button.add_theme_font_size_override("font_size", 20)
	_home_resume_button.pressed.connect(resume_attempt_requested.emit)
	action_row.add_child(_home_resume_button)
	_home_start_button = _make_button("START", true)
	_home_start_button.name = "YardTabButton"
	_home_start_button.custom_minimum_size = Vector2(310, 70)
	_home_start_button.add_theme_font_size_override("font_size", 26)
	_home_start_button.tooltip_text = "Open Level Select."
	_home_start_button.pressed.connect(_on_landing_start_pressed)
	_apply_landing_button_style(_home_start_button, false)
	action_row.add_child(_home_start_button)
	_nav_buttons[TAB_YARD] = _home_start_button
	_home_quick_start_button = _make_button("QUICK START", false)
	_home_quick_start_button.name = "QuickStartButton"
	_home_quick_start_button.custom_minimum_size = Vector2(145, 40)
	_home_quick_start_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_home_quick_start_button.add_theme_font_size_override("font_size", 12)
	_home_quick_start_button.tooltip_text = (
		"Immediately begin the currently selected level and frequency."
	)
	_home_quick_start_button.pressed.connect(_on_continue_pressed)
	_apply_landing_button_style(_home_quick_start_button, false)
	action_row.add_child(_home_quick_start_button)
	_home_action_copy = HBoxContainer.new()
	_home_action_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_action_copy.add_theme_constant_override("separation", 14)
	action_column.add_child(_home_action_copy)
	_home_message_label = _make_label("Cash is banked when a run settles.", 12, MUTED)
	_home_message_label.name = "StatusLabel"
	_home_message_label.custom_minimum_size.x = 390
	_home_message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_home_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_home_action_copy.add_child(_home_message_label)
	_home_selection_label = _make_label("", 12, DIM)
	_home_selection_label.name = "SelectionLabel"
	_home_selection_label.custom_minimum_size.x = 300
	_home_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_home_action_copy.add_child(_home_selection_label)

	_home_landing_lower_spacer = Control.new()
	_home_landing_lower_spacer.name = "LandingActionSpacer"
	_home_landing_lower_spacer.custom_minimum_size.y = 58
	shell.add_child(_home_landing_lower_spacer)

	_home_nav_panel = _make_panel(
		Color(0.035, 0.024, 0.018, 0.94), BORDER, 8)
	_home_nav_panel.custom_minimum_size.y = 66
	shell.add_child(_home_nav_panel)
	var nav_margin := _make_margin(10, 7, 10, 7)
	_home_nav_panel.add_child(nav_margin)
	_home_nav_row = HBoxContainer.new()
	_home_nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_nav_row.add_theme_constant_override("separation", 58)
	nav_margin.add_child(_home_nav_row)
	_add_nav_button(_home_nav_row, TAB_POWERS, "COLLECTION", "Run powers")
	_add_nav_button(_home_nav_row, TAB_UPGRADES, "POWER UP", "Permanent ranks")
	_add_nav_button(_home_nav_row, TAB_RECORDS, "UNLOCKS", "Records & progress")


func _add_nav_button(parent: Container, id: StringName, title: String,
		subtitle: String) -> void:
	var button := _make_button(title, false)
	button.tooltip_text = subtitle
	match id:
		TAB_UPGRADES:
			button.name = "UpgradesTabButton"
		TAB_YARD:
			button.name = "YardTabButton"
		TAB_POWERS:
			button.name = "PowerCatalogueTabButton"
		TAB_RECORDS:
			button.name = "RecordsTabButton"
	button.custom_minimum_size = Vector2(230, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.toggle_mode = true
	_apply_landing_button_style(button, id == TAB_UPGRADES)
	button.pressed.connect(_select_home_tab.bind(id))
	parent.add_child(button)
	_nav_buttons[id] = button


func _refresh_home(rebuild_content: bool) -> void:
	if _home_root == null:
		return
	if rebuild_content and _has_save and _current_tab != TAB_HOME:
		_render_current_tab(true)
	_apply_home_screen_layout()
	_home_cash_label.text = "$%s" % _format_number(GameState.get_home_cash())
	var locked := _permanent_mutations_locked()
	_home_lock_banner.visible = _has_attempt
	_home_start_button.visible = not _has_attempt
	_home_start_button.disabled = _has_attempt
	_home_quick_start_button.visible = _has_save and not _has_attempt
	_home_quick_start_button.disabled = not _has_save or _has_attempt
	_home_start_button.tooltip_text = (
		"Open Level Select."
		if _has_save else "Create a camp, then open Level Select."
	)
	if _home_level_start_button != null:
		_home_level_start_button.visible = _current_tab == TAB_YARD and not _has_attempt
		_home_level_start_button.disabled = _has_attempt
	_home_resume_button.visible = _has_attempt
	_home_abandon_button.visible = _has_attempt
	_home_new_profile_button.disabled = locked
	_home_new_profile_button.tooltip_text = (
		"Resolve the suspended run before replacing the profile."
		if locked else "Replace this profile after confirmation."
	)
	_home_message_label.text = _home_message_override if not _home_message_override.is_empty() \
		else ("Your suspended run is preserved. Permanent controls are locked."
			if _has_attempt else "Session cash banks here only when a run settles.")
	var yard := SurvivorsContent.yards().by_id(GameState.get_selected_yard()) \
		if SurvivorsContent.yards() != null else null
	var yard_name := yard.display_name if yard != null else _title_from_id(
		GameState.get_selected_yard())
	_home_selection_label.text = "%s · Frequency tier %d" % [
		yard_name, GameState.get_selected_frequency_tier()]
	for raw_id: Variant in _nav_buttons:
		var nav_button := _nav_buttons[raw_id] as Button
		if nav_button != null:
			if StringName(raw_id) != TAB_YARD:
				nav_button.disabled = not _has_save
				nav_button.tooltip_text = (
					"Create a camp to open this section."
					if not _has_save else _landing_nav_tooltip(StringName(raw_id))
				)
			nav_button.set_pressed_no_signal(StringName(raw_id) == _current_tab)


func _landing_nav_tooltip(id: StringName) -> String:
	match id:
		TAB_UPGRADES:
			return "Open permanent Power Ups."
		TAB_POWERS:
			return "Open the run-power Collection."
		TAB_RECORDS:
			return "Open Unlocks and Records."
	return "Open this section."


func _apply_home_screen_layout() -> void:
	var landing := _current_tab == TAB_HOME
	_home_root.add_theme_constant_override("margin_left", 24 if landing else 170)
	_home_root.add_theme_constant_override("margin_right", 24 if landing else 170)
	_home_header.custom_minimum_size.y = 235 if landing else 88
	_home_landing_spacer.visible = landing
	_home_landing_lower_spacer.visible = landing
	_home_content_panel.visible = not landing
	_home_action_panel.visible = landing
	_home_action_copy.visible = landing and not _home_message_override.is_empty()
	_home_nav_panel.visible = landing
	_home_profile_column.visible = not landing
	_home_bank_column.visible = not landing
	_home_new_profile_button.visible = false
	_home_back_button.visible = not landing
	if landing:
		_home_header.add_theme_stylebox_override("panel",
			_style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		_home_action_panel.add_theme_stylebox_override("panel",
			_style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		_home_nav_panel.add_theme_stylebox_override("panel",
			_style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		_home_brand_kicker.text = "FIFTEEN MINUTES · ONE CHOPPING BLOCK"
		_home_brand_title.text = "CAMPFIRE\nSURVIVORS"
		_home_brand_title.add_theme_font_size_override("font_size", 60)
		_home_brand_subtitle.text = "SPLIT · GROW · SURVIVE"
	else:
		_home_header.add_theme_stylebox_override("panel", _style_box(
			Color(0.035, 0.024, 0.018, 0.82), BORDER, 8))
		_home_brand_kicker.text = "CAMPFIRE SURVIVORS"
		_home_brand_title.text = _section_title(_current_tab)
		_home_brand_title.add_theme_font_size_override("font_size", 30)
		_home_brand_subtitle.text = _section_subtitle(_current_tab)


func _section_title(id: StringName) -> String:
	match id:
		TAB_UPGRADES:
			return "POWERUP SELECTION"
		TAB_YARD:
			return "LEVEL SELECT"
		TAB_POWERS:
			return "COLLECTION"
		TAB_RECORDS:
			return "UNLOCKS"
	return "CAMPFIRE SURVIVORS"


func _section_subtitle(id: StringName) -> String:
	match id:
		TAB_UPGRADES:
			return "SPEND CAMP FUNDS · RANK UP PERMANENTLY"
		TAB_YARD:
			return "CHOOSE THE NEXT SURVIVAL RUN"
		TAB_POWERS:
			return "DISCOVERED RUN POWERS"
		TAB_RECORDS:
			return "PROGRESS, DISCOVERIES, AND RECORDS"
	return "SPLIT · GROW · SURVIVE"


func _select_home_tab(id: StringName) -> void:
	if id not in [TAB_HOME, TAB_UPGRADES, TAB_YARD, TAB_POWERS, TAB_RECORDS]:
		return
	_current_tab = id
	_home_message_override = ""
	if id != TAB_HOME:
		_render_current_tab(false)
	_refresh_home(false)
	if id != TAB_HOME:
		_home_scroll.scroll_vertical = 0
	if id == TAB_HOME:
		if _has_attempt:
			_home_resume_button.grab_focus()
		else:
			_home_start_button.grab_focus()
	elif id == TAB_YARD and _home_level_start_button != null:
		_home_level_start_button.grab_focus()
	else:
		_home_back_button.grab_focus()


func _render_current_tab(preserve_scroll: bool) -> void:
	if _home_content == null:
		return
	var previous_scroll := _home_scroll.scroll_vertical if preserve_scroll else 0
	_clear_children(_home_content)
	_clear_children(_home_detail_host)
	_home_detail_host.visible = false
	_home_level_start_button = null
	match _current_tab:
		TAB_UPGRADES:
			_render_upgrades()
		TAB_YARD:
			_render_yard()
		TAB_POWERS:
			_render_power_catalogue()
		TAB_RECORDS:
			_render_records()
	if preserve_scroll:
		_restore_scroll.call_deferred(previous_scroll)


func _render_upgrades() -> void:
	_home_content_title.text = "PERMANENT POWER UPS"
	_home_content_subtitle.text = (
		"Select a power up for details, then buy one permanent rank at a time."
	)
	var table := SurvivorsContent.meta_upgrades()
	if table == null:
		_add_empty_state("The permanent-upgrade catalogue could not be loaded.")
		return
	if table.by_id(_selected_upgrade_id) == null and not table.upgrades.is_empty():
		_selected_upgrade_id = table.upgrades[0].id
	var total_ranks := 0
	var total_spent := 0
	for definition: MetaUpgradeDef in table.upgrades:
		if definition == null:
			continue
		total_ranks += GameState.get_meta_upgrade_rank(definition.id)
		total_spent += GameState.get_meta_upgrade_spend(definition.id)
	var summary := _make_label("%d power ups · %d ranks owned · $%s invested" % [
		table.upgrades.size(), total_ranks, _format_number(total_spent)], 13, MUTED)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_content.add_child(summary)
	var refund := _make_button("Refund All Power Ups · $%s" %
		_format_number(total_spent), false)
	refund.name = "RefundAllUpgradesButton"
	refund.custom_minimum_size = Vector2(0, 48)
	refund.disabled = _permanent_mutations_locked() or total_spent <= 0
	refund.tooltip_text = (
		"Permanent controls are locked while a run is suspended."
		if _permanent_mutations_locked()
		else "Free full refund using the exact recorded amounts paid."
	)
	refund.pressed.connect(_refund_all_upgrades)
	_home_content.add_child(refund)

	var grid := GridContainer.new()
	grid.name = "PowerUpGrid"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_home_content.add_child(grid)
	for definition: MetaUpgradeDef in table.upgrades:
		if definition != null:
			grid.add_child(_build_upgrade_tile(definition, table))
	_home_detail_host.visible = true
	_render_upgrade_detail(table.by_id(_selected_upgrade_id))


func _build_upgrade_tile(definition: MetaUpgradeDef,
		table: MetaUpgradeTable) -> PanelContainer:
	var selected := definition.id == _selected_upgrade_id
	var card := _make_panel(PANEL_LIGHT if selected else PANEL_MID,
		GOLD if selected else Color(0.38, 0.27, 0.12, 1.0), 6)
	card.name = "Upgrade_%s" % definition.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(175, 158)
	var margin := _make_margin(8, 7, 8, 7)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var rank := GameState.get_meta_upgrade_rank(definition.id)
	var title := _make_label(definition.display_name, 13, INK)
	title.custom_minimum_size.y = 31
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var select := _make_button("", false)
	select.name = "Select_%s" % definition.id
	select.custom_minimum_size.y = 62
	if ResourceLoader.exists(definition.icon_path):
		select.icon = load(definition.icon_path) as Texture2D
	select.expand_icon = true
	select.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select.add_theme_constant_override("icon_max_width", 52)
	select.tooltip_text = "Show %s details." % definition.display_name
	select.pressed.connect(_select_upgrade_detail.bind(definition.id))
	column.add_child(select)
	var rank_label := _make_label(_rank_markers(rank, definition.max_rank), 12,
		GREEN if rank > 0 else MUTED)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.tooltip_text = "Rank %d / %d" % [rank, definition.max_rank]
	column.add_child(rank_label)
	var buy := _make_button("", true)
	buy.name = "Buy_%s" % definition.id
	buy.custom_minimum_size = Vector2(0, 32)
	buy.add_theme_font_size_override("font_size", 12)
	_configure_upgrade_buy_button(buy, definition, table, rank)
	buy.pressed.connect(_purchase_upgrade.bind(definition.id))
	column.add_child(buy)
	return card


func _render_upgrade_detail(definition: MetaUpgradeDef) -> void:
	_clear_children(_home_detail_host)
	if definition == null:
		return
	var rank := GameState.get_meta_upgrade_rank(definition.id)
	var panel := _make_panel(PANEL_LIGHT, GOLD, 7)
	panel.name = "SelectedUpgradeDetail"
	panel.custom_minimum_size.y = 126
	_home_detail_host.add_child(panel)
	var margin := _make_margin(13, 10, 13, 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	var icon := _make_icon(definition.icon_path, Vector2(72, 72))
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	copy.add_child(_make_label(definition.display_name, 18, INK))
	var description := _make_label(definition.description, 12, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description)
	var effects := _make_label(_meta_effect_summary(definition, rank), 11, BLUE)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(effects)
	var state := VBoxContainer.new()
	state.custom_minimum_size.x = 170
	state.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(state)
	var rank_label := _make_label("RANK %d / %d" % [rank, definition.max_rank],
		13, GREEN if rank > 0 else MUTED)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_child(rank_label)
	var next_text := "MAXIMUM\nLEVEL REACHED" if definition.is_maxed(rank) \
		else "NEXT RANK\n$%s" % _format_number(
			definition.cost_for_rank(rank + 1))
	var next := _make_label(next_text, 13, GOLD)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_child(next)


func _rank_markers(rank: int, maximum: int) -> String:
	var markers := PackedStringArray()
	for index: int in range(maximum):
		markers.append("◆" if index < rank else "◇")
	return " ".join(markers)


func _select_upgrade_detail(id: StringName) -> void:
	var table := SurvivorsContent.meta_upgrades()
	if table == null or table.by_id(id) == null:
		return
	_selected_upgrade_id = id
	_render_current_tab(true)


func _configure_upgrade_buy_button(button: Button,
		definition: MetaUpgradeDef, table: MetaUpgradeTable, rank: int) -> void:
	if definition.is_maxed(rank):
		button.text = "MAXED"
		button.disabled = true
		button.tooltip_text = "All authored ranks are owned."
		return
	var next_cost := definition.cost_for_rank(rank + 1)
	button.text = "BUY · $%s" % _format_number(next_cost)
	button.disabled = not GameState.can_purchase_meta_upgrade(definition.id)
	if _permanent_mutations_locked():
		button.tooltip_text = "Permanent controls are locked while a run is suspended."
	elif definition.prerequisite_upgrade_id != &"" and GameState.get_meta_upgrade_rank(
			definition.prerequisite_upgrade_id) < definition.prerequisite_rank:
		var prerequisite := table.by_id(definition.prerequisite_upgrade_id)
		var prerequisite_name := prerequisite.display_name if prerequisite != null \
			else _title_from_id(definition.prerequisite_upgrade_id)
		button.tooltip_text = "Requires %s rank %d." % [
			prerequisite_name, definition.prerequisite_rank]
	elif GameState.get_home_cash() < next_cost:
		button.tooltip_text = "Need $%s more Home Cash." % _format_number(
			next_cost - GameState.get_home_cash())
	else:
		button.tooltip_text = "Purchase rank %d." % (rank + 1)


func _render_yard() -> void:
	_home_content_title.text = "CHOOSE A LEVEL"
	_home_content_subtitle.text = (
		"Choose a stage and a starting delivery tier. Faster tiers add no cash or XP "
		+ "multiplier; their extra log volume is the reward and the risk."
	)
	var table := SurvivorsContent.yards()
	if table == null:
		_add_empty_state("The yard catalogue could not be loaded.")
		return
	var locked := _permanent_mutations_locked()
	for definition: YardDef in table.yards:
		if definition == null:
			continue
		var selected := definition.id == GameState.get_selected_yard()
		var card := _make_panel(PANEL_MID,
			GOLD if selected else Color(0.27, 0.25, 0.17, 1.0), 8)
		_home_content.add_child(card)
		var margin := _make_margin(16, 14, 16, 14)
		card.add_child(margin)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 7)
		margin.add_child(column)
		var top := HBoxContainer.new()
		column.add_child(top)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(names)
		names.add_child(_make_label(definition.display_name, 20, INK))
		names.add_child(_make_label("%s · %s" % [String(definition.id),
			_format_duration_seconds(definition.stage_duration_seconds)], 11, MUTED))
		var select_button := _make_button("SELECTED" if selected else "SELECT", true)
		select_button.custom_minimum_size = Vector2(126, 40)
		select_button.disabled = selected or locked
		select_button.tooltip_text = (
			"Permanent controls are locked while a run is suspended."
			if locked else "Use this yard for the next run."
		)
		select_button.pressed.connect(_select_yard.bind(definition.id))
		top.add_child(select_button)
		var copy := _make_label(definition.description, 13, MUTED)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(copy)
		column.add_child(_make_label("TIMELINE ROSTER · %s" %
			_species_roster(definition), 11, BLUE))
		column.add_child(_make_label("SCHEDULED BOSSES · %s" %
			_boss_roster(definition), 11, PURPLE))
		var tuning := _make_label(definition.tuning_status, 10, GOLD)
		tuning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(tuning)

	var yard := table.by_id(GameState.get_selected_yard())
	if yard == null:
		return
	var frequency_panel := _make_panel(PANEL_LIGHT, Color(0.31, 0.29, 0.19, 1.0), 8)
	_home_content.add_child(frequency_panel)
	var frequency_margin := _make_margin(16, 14, 16, 14)
	frequency_panel.add_child(frequency_margin)
	var frequency_column := VBoxContainer.new()
	frequency_column.add_theme_constant_override("separation", 9)
	frequency_margin.add_child(frequency_column)
	frequency_column.add_child(_make_label("STARTING FALL FREQUENCY", 16, INK))
	var frequency_copy := _make_label(
		"Fall Frequency Control unlocks three faster selectable tiers beyond the default.",
		12, MUTED)
	frequency_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frequency_column.add_child(frequency_copy)
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 8)
	frequency_column.add_child(tier_row)
	var max_tier := GameState.get_max_frequency_tier()
	var current_tier := GameState.get_selected_frequency_tier()
	for tier: int in range(yard.delivery_tier_interval_scales.size()):
		var interval := yard.delivery_interval_seconds(1, tier)
		var tier_button := _make_button(
			"%s\n%.1fs" % ["DEFAULT" if tier == 0 else "TIER %d" % tier, interval],
			tier == current_tier)
		tier_button.name = "FrequencyTier%dButton" % tier
		tier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_button.custom_minimum_size.y = 52
		var tier_locked := tier > max_tier
		tier_button.disabled = locked or tier_locked or tier == current_tier
		if locked:
			tier_button.tooltip_text = "Permanent controls are locked while a run is suspended."
		elif tier_locked:
			tier_button.tooltip_text = "Requires Fall Frequency Control rank %d." % tier
		elif tier == current_tier:
			tier_button.tooltip_text = "Selected for the next run."
		else:
			tier_button.tooltip_text = "Begin future deliveries at this authored interval."
		tier_button.pressed.connect(_select_frequency_tier.bind(tier))
		tier_row.add_child(tier_button)

	var launch_panel := _make_panel(
		Color(0.12, 0.055, 0.025, 0.98), GOLD, 7)
	launch_panel.name = "LevelLaunchPanel"
	_home_content.add_child(launch_panel)
	var launch_margin := _make_margin(14, 10, 14, 10)
	launch_panel.add_child(launch_margin)
	var launch_column := VBoxContainer.new()
	launch_column.add_theme_constant_override("separation", 5)
	launch_margin.add_child(launch_column)
	var selected_copy := _make_label("%s · %s · FREQUENCY TIER %d" % [
		yard.display_name, _format_duration_seconds(yard.stage_duration_seconds),
		GameState.get_selected_frequency_tier()], 12, MUTED)
	selected_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launch_column.add_child(selected_copy)
	_home_level_start_button = _make_button("START RUN", true)
	_home_level_start_button.name = "StartRunButton"
	_home_level_start_button.custom_minimum_size.y = 54
	_home_level_start_button.add_theme_font_size_override("font_size", 20)
	_home_level_start_button.visible = not _has_attempt
	_home_level_start_button.disabled = _has_attempt
	_home_level_start_button.tooltip_text = (
		"Resolve the suspended run before starting another."
		if _has_attempt else "Begin the selected 15-minute survival run."
	)
	_home_level_start_button.pressed.connect(_on_continue_pressed)
	launch_column.add_child(_home_level_start_button)


func _render_power_catalogue() -> void:
	_home_content_title.text = "RUN POWER CATALOGUE"
	_home_content_subtitle.text = (
		"A run can hold six powers. Core powers begin unlocked; boss blueprints "
		+ "permanently reveal the remaining powers when a run is banked."
	)
	var table := SurvivorsContent.run_powers()
	if table == null:
		_add_empty_state("The run-power catalogue could not be loaded.")
		return
	var unlocked := GameState.get_unlocked_run_powers().size()
	_home_content.add_child(_make_label("%d / %d unlocked · 6 slots per run" % [
		unlocked, table.powers.size()], 13, MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_home_content.add_child(grid)
	for definition: RunPowerDef in table.powers:
		if definition != null:
			grid.add_child(_build_power_card(definition))


func _build_power_card(definition: RunPowerDef) -> PanelContainer:
	var unlocked := GameState.is_run_power_unlocked(definition.id)
	var power_color := GREEN
	var card := _make_panel(PANEL_MID if unlocked else PANEL_DARK,
		power_color.darkened(0.42) if unlocked else Color(0.2, 0.21, 0.19, 1.0), 8)
	card.name = "Power_%s" % definition.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(380, 176)
	var margin := _make_margin(13, 12, 13, 12)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var icon := _make_icon(definition.icon_path, Vector2(42, 42))
	icon.modulate = Color.WHITE if unlocked else Color(0.4, 0.42, 0.39, 1.0)
	top.add_child(icon)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_column)
	title_column.add_child(_make_label(definition.display_name, 17,
		INK if unlocked else MUTED))
	title_column.add_child(_make_label("%s · CAP %d" % [
		_pool_name(definition.pool),
		definition.rank_cap], 10, power_color))
	var state := _make_label("UNLOCKED" if unlocked else "BLUEPRINT LOCKED", 10,
		GREEN if unlocked else DIM)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(state)
	var copy := _make_label(definition.description, 12, MUTED if unlocked else DIM)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.y = 34
	column.add_child(copy)
	var effects := _make_label(_power_effect_summary(definition), 10,
		power_color if unlocked else DIM)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(effects)
	var tuning := _make_label("PLACEHOLDER TUNING", 10, GOLD if unlocked else DIM)
	tuning.tooltip_text = definition.tuning_status
	column.add_child(tuning)
	return card


func _render_records() -> void:
	_home_content_title.text = "UNLOCKS & RECORDS"
	_home_content_subtitle.text = (
		"Review permanent discoveries, career totals, and independent level records."
	)
	var power_table := SurvivorsContent.run_powers()
	if power_table != null:
		var unlock_panel := _make_panel(PANEL_LIGHT, GOLD, 7)
		_home_content.add_child(unlock_panel)
		var unlock_margin := _make_margin(14, 10, 14, 10)
		unlock_panel.add_child(unlock_margin)
		var unlock_row := HBoxContainer.new()
		unlock_margin.add_child(unlock_row)
		var unlock_copy := _make_label("RUN POWER UNLOCKS", 14, INK)
		unlock_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unlock_row.add_child(unlock_copy)
		var unlock_count := _make_label("%d / %d" % [
			GameState.get_unlocked_run_powers().size(), power_table.powers.size()],
			16, GOLD)
		unlock_row.add_child(unlock_count)
	var notice := GameState.get_migration_notice()
	if not notice.is_empty():
		_render_migration_notice(notice)
	_render_record_section("CAREER", GameState.get_lifetime_stats(), {
		"roots_completed": "Roots completed",
		"cash_earned": "Home Cash earned",
		"runs_settled": "Runs settled",
		"bosses_defeated": "Bosses defeated",
		"haul_aways_completed": "Legacy haul-aways",
	})
	var yards := SurvivorsContent.yards()
	if yards != null:
		for definition: YardDef in yards.yards:
			if definition == null:
				continue
			_render_yard_record(definition,
				GameState.get_yard_record(definition.id))
	var legacy := GameState.get_legacy_records()
	if not legacy.is_empty():
		_render_legacy_records(legacy)
	var profile_button := _make_button("START FRESH CAMP", false)
	profile_button.name = "RecordsNewProfileButton"
	profile_button.custom_minimum_size.y = 44
	profile_button.disabled = _permanent_mutations_locked()
	profile_button.tooltip_text = (
		"Resolve the suspended run before replacing the profile."
		if _permanent_mutations_locked()
		else "Replace this profile after confirmation."
	)
	profile_button.pressed.connect(_on_new_game_pressed)
	_home_content.add_child(profile_button)


func _render_migration_notice(notice: Dictionary) -> void:
	var panel := _make_panel(Color(0.16, 0.12, 0.06, 0.98), GOLD, 8)
	_home_content.add_child(panel)
	var margin := _make_margin(14, 12, 14, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	column.add_child(_make_label("PROFILE MIGRATED", 15, GOLD))
	var message := _make_label(String(notice.get("message",
		"Legacy progression was preserved in this v19 profile.")), 12, INK)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	var row := HBoxContainer.new()
	column.add_child(row)
	var detail := _make_label("Source version %s · refund $%s" % [
		str(notice.get("source_version", "—")),
		_format_number(int(notice.get("refund_cash", 0)))], 10, MUTED)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var acknowledge := _make_button("Acknowledge", false)
	acknowledge.custom_minimum_size = Vector2(126, 36)
	acknowledge.disabled = _permanent_mutations_locked()
	acknowledge.tooltip_text = (
		"Permanent controls are locked while a run is suspended."
		if acknowledge.disabled else "Dismiss this one-time notice."
	)
	acknowledge.pressed.connect(_acknowledge_migration.bind(
		StringName(notice.get("id", ""))))
	row.add_child(acknowledge)


func _render_record_section(title: String, values: Dictionary,
		labels: Dictionary) -> void:
	var panel := _make_panel(PANEL_MID, Color(0.27, 0.25, 0.17, 1.0), 8)
	_home_content.add_child(panel)
	var margin := _make_margin(14, 12, 14, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	column.add_child(_make_label(title, 15, INK))
	for raw_key: Variant in labels:
		var key := String(raw_key)
		_add_record_row(column, String(labels[raw_key]),
			_format_number(int(values.get(key, 0))))


func _render_yard_record(definition: YardDef, record: Dictionary) -> void:
	var panel := _make_panel(PANEL_MID, Color(0.27, 0.25, 0.17, 1.0), 8)
	_home_content.add_child(panel)
	var margin := _make_margin(14, 12, 14, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	column.add_child(_make_label(definition.display_name.to_upper(), 15, INK))
	_add_record_row(column, "Attempts", _format_number(int(record.get("attempts", 0))))
	_add_record_row(column, "Clears", _format_number(int(record.get("clears", 0))))
	_add_record_row(column, "Best clear", _format_duration_ms(
		int(record.get("best_clear_ms", -1))))
	_add_record_row(column, "Longest endless", _format_duration_ms(
		int(record.get("longest_endless_ms", -1))))
	_add_record_row(column, "Highest level", _format_number(
		int(record.get("highest_level", 1))))
	_add_record_row(column, "Best session cash", "$%s" % _format_number(
		int(record.get("best_session_cash", 0))))


func _render_legacy_records(records: Dictionary) -> void:
	var panel := _make_panel(PANEL_DARK, Color(0.22, 0.23, 0.2, 1.0), 8)
	_home_content.add_child(panel)
	var margin := _make_margin(14, 12, 14, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	column.add_child(_make_label("LEGACY RECORDS · READ ONLY", 15, MUTED))
	_add_dictionary_rows(column, records, 0)


func _add_dictionary_rows(parent: VBoxContainer, values: Dictionary,
		depth: int) -> void:
	var keys: Array = values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b))
	for raw_key: Variant in keys:
		var key := String(raw_key)
		var value: Variant = values[raw_key]
		if value is Dictionary:
			var heading := _make_label("%s%s" % ["  ".repeat(depth),
				_title_from_id(StringName(key))], 11, MUTED)
			parent.add_child(heading)
			_add_dictionary_rows(parent, value as Dictionary, depth + 1)
		else:
			var display := JSON.stringify(value) if value is Array else str(value)
			_add_record_row(parent, "%s%s" % ["  ".repeat(depth),
				_title_from_id(StringName(key))], display)


func _add_record_row(parent: VBoxContainer, label_text: String,
		value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _make_label(label_text, 11, MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := _make_label(value_text, 11, INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)


func _purchase_upgrade(id: StringName) -> void:
	if _permanent_mutations_locked():
		return
	_selected_upgrade_id = id
	var definition := SurvivorsContent.meta_upgrades().by_id(id) \
		if SurvivorsContent.meta_upgrades() != null else null
	if GameState.purchase_meta_upgrade(id):
		_home_message_override = "%s advanced to rank %d." % [
			definition.display_name if definition != null else _title_from_id(id),
			GameState.get_meta_upgrade_rank(id)]
	else:
		_home_message_override = "That upgrade is not currently purchasable."
	_refresh_home(false)


func _refund_all_upgrades() -> void:
	if _permanent_mutations_locked():
		return
	var amount := GameState.refund_all_meta_upgrades()
	_home_message_override = (
		"Refunded $%s using the exact spend ledger." % _format_number(amount)
		if amount > 0 else "There are no paid upgrade ranks to refund."
	)
	_refresh_home(false)


func _select_yard(id: StringName) -> void:
	if _permanent_mutations_locked():
		return
	if GameState.select_yard(id):
		_home_message_override = "%s selected." % _title_from_id(id)
	else:
		_home_message_override = "That yard is not available for selection."
	_refresh_home(false)


func _select_frequency_tier(tier: int) -> void:
	if _permanent_mutations_locked():
		return
	if GameState.select_frequency_tier(tier):
		_home_message_override = "Starting frequency tier %d selected." % tier
	else:
		_home_message_override = "That frequency tier is not unlocked."
	_refresh_home(false)


func _acknowledge_migration(id: StringName) -> void:
	if _permanent_mutations_locked():
		return
	if GameState.acknowledge_migration_notice(id):
		_home_message_override = "Migration notice acknowledged. Legacy records remain intact."
	_refresh_home(false)


func _on_profile_changed() -> void:
	if _has_save and visible:
		_refresh_home(true)


func _on_permanent_controls_lock_changed(_locked: bool) -> void:
	if _has_save and visible:
		_refresh_home(true)


func _on_new_game_pressed() -> void:
	if _has_save:
		_new_game_confirmation.popup_centered()
		return
	_emit_new_profile()


func _on_landing_start_pressed() -> void:
	if _has_save:
		_select_home_tab(TAB_YARD)
	else:
		_emit_new_profile()


func _emit_new_profile() -> void:
	_pending_level_select_after_profile_create = true
	new_profile_requested.emit()
	new_game_requested.emit()


func _on_continue_pressed() -> void:
	continue_profile_requested.emit()
	load_game_requested.emit()


func _permanent_mutations_locked() -> bool:
	return _has_attempt or GameState.are_permanent_controls_locked()


func _meta_effect_summary(definition: MetaUpgradeDef, rank: int) -> String:
	var lines := PackedStringArray()
	for effect: ProgressionEffectDef in definition.effects:
		if effect == null:
			continue
		var current := effect.value_at_rank(rank)
		var label := _effect_name(effect.kind)
		if rank >= definition.max_rank:
			lines.append("%s · %s" % [label,
				_format_effect_value(effect, current)])
		else:
			var next := effect.value_at_rank(rank + 1)
			lines.append("%s · %s → %s" % [label,
				_format_effect_value(effect, current),
				_format_effect_value(effect, next)])
	return "\n".join(lines)


func _power_effect_summary(definition: RunPowerDef) -> String:
	var lines := PackedStringArray()
	for effect: ProgressionEffectDef in definition.effects:
		if effect == null:
			continue
		lines.append("%s · %s → %s" % [
			_effect_name(effect.kind),
			_format_effect_value(effect, effect.value_at_rank(1)),
			_format_effect_value(effect, effect.value_at_rank(definition.rank_cap)),
		])
	return " · ".join(lines)


func _format_effect_value(effect: ProgressionEffectDef, value: float) -> String:
	if effect.operation == ProgressionEffectDef.Operation.ENABLE:
		return "Enabled" if value >= 1.0 else "Locked"
	if effect.operation == ProgressionEffectDef.Operation.MULTIPLY:
		return "%.2f×" % value
	if effect.kind in [
		ProgressionEffectDef.Kind.FREQUENCY_TIER_UNLOCK,
		ProgressionEffectDef.Kind.REROLL_CHARGES,
		ProgressionEffectDef.Kind.BANISH_CHARGES,
		ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS,
		ProgressionEffectDef.Kind.FOLLOW_UP_DEPTH,
		ProgressionEffectDef.Kind.SPLINTER_COUNT,
		ProgressionEffectDef.Kind.FLYING_WEDGE_CUT_COUNT,
		ProgressionEffectDef.Kind.EARTHSHAKER_TRIGGER_CUTS,
		ProgressionEffectDef.Kind.POWDER_KEG_CUT_COUNT,
		ProgressionEffectDef.Kind.KINDLING_CHAIN_COUNT,
		ProgressionEffectDef.Kind.ORBITING_AXE_COUNT,
		ProgressionEffectDef.Kind.MAUL_DROP_CUT_COUNT,
		ProgressionEffectDef.Kind.RESCUE_CHARGES,
		ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS,
	]:
		return str(int(round(value)))
	if effect.kind in [
		ProgressionEffectDef.Kind.SPLIT_RELIABILITY,
		ProgressionEffectDef.Kind.SWING_RECOVERY,
		ProgressionEffectDef.Kind.SCAR_RELIABILITY,
		ProgressionEffectDef.Kind.FOURTH_CARD_CHANCE,
		ProgressionEffectDef.Kind.RARE_QUALITY_WEIGHT,
		ProgressionEffectDef.Kind.EPIC_QUALITY_WEIGHT,
		ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE,
	]:
		return "%.0f%%" % (value * 100.0)
	return "%.2f" % value


func _effect_name(kind: ProgressionEffectDef.Kind) -> String:
	var names := ProgressionEffectDef.Kind.keys()
	if int(kind) < 0 or int(kind) >= names.size():
		return "Effect"
	return String(names[int(kind)]).capitalize()


func _species_roster(yard: YardDef) -> String:
	var ids: Array[StringName] = []
	for entry: YardTimelineEntryDef in yard.species_timeline:
		if entry != null and entry.species_id not in ids:
			ids.append(entry.species_id)
	var names := PackedStringArray()
	for id: StringName in ids:
		names.append(_title_from_id(id))
	return ", ".join(names)


func _boss_roster(yard: YardDef) -> String:
	var names := PackedStringArray()
	for boss: YardBossDef in yard.bosses:
		if boss != null:
			names.append("%s at %s" % [boss.display_name,
				_format_duration_seconds(boss.scheduled_seconds)])
	return ", ".join(names) if not names.is_empty() else "None"


func _pool_name(pool: RunPowerDef.Pool) -> String:
	return "CORE" if pool == RunPowerDef.Pool.CORE else "BLUEPRINT"


func _title_from_id(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()


func _format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if negative else "") + digits + grouped


func _format_duration_seconds(seconds: float) -> String:
	var total := maxi(0, int(round(seconds)))
	return "%d:%02d" % [total / 60, total % 60]


func _format_duration_ms(milliseconds: int) -> String:
	return "—" if milliseconds < 0 else _format_duration_seconds(
		float(milliseconds) / 1000.0)


func _restore_scroll(value: int) -> void:
	if _home_scroll != null:
		_home_scroll.scroll_vertical = value


func _add_empty_state(message: String) -> void:
	var label := _make_label(message, 14, RED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_home_content.add_child(label)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_icon(path: String, minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not path.is_empty() and ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	return icon


func _make_button(text: String, accent: bool) -> Button:
	var button := Button.new()
	button.text = text
	_apply_button_style(button, accent)
	return button


func _apply_button_style(button: Button, accent: bool) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 1.0))
	button.add_theme_color_override("font_disabled_color", DIM)
	var normal_bg := Color(0.42, 0.13, 0.035, 1.0) if accent \
		else Color(0.12, 0.075, 0.045, 1.0)
	button.add_theme_stylebox_override("normal", _style_box(normal_bg, BORDER, 7))
	button.add_theme_stylebox_override("hover", _style_box(
		Color(0.54, 0.19, 0.055, 1.0), GOLD, 7, 2))
	button.add_theme_stylebox_override("pressed", _style_box(
		Color(0.23, 0.065, 0.025, 1.0), GOLD.darkened(0.08), 7, 2))
	button.add_theme_stylebox_override("disabled", _style_box(
		Color(0.07, 0.055, 0.045, 1.0), Color(0.19, 0.15, 0.12, 1.0), 7))
	button.add_theme_stylebox_override("focus", _style_box(Color.TRANSPARENT, GOLD, 7, 3))


func _apply_landing_button_style(button: Button, green: bool) -> void:
	if button == null:
		return
	var base := Color(0.10, 0.43, 0.18, 1.0) if green \
		else Color(0.10, 0.19, 0.52, 1.0)
	var hover := Color(0.15, 0.58, 0.24, 1.0) if green \
		else Color(0.16, 0.29, 0.72, 1.0)
	button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	button.add_theme_stylebox_override("normal", _style_box(base, GOLD, 7, 3))
	button.add_theme_stylebox_override("hover", _style_box(hover,
		Color(1.0, 0.78, 0.34, 1.0), 7, 3))
	button.add_theme_stylebox_override("pressed", _style_box(
		base.darkened(0.28), GOLD.darkened(0.05), 7, 3))
	button.add_theme_stylebox_override("focus", _style_box(
		Color.TRANSPARENT, Color(1.0, 0.86, 0.45, 1.0), 8, 4))


func _style_confirmation_dialog() -> void:
	_new_game_confirmation.add_theme_stylebox_override("panel",
		_style_box(PANEL_DARK, BORDER, 8, 2))
	_new_game_confirmation.add_theme_color_override("title_color", INK)
	_new_game_confirmation.add_theme_font_size_override("title_font_size", 18)
	var copy := _new_game_confirmation.get_label()
	if copy != null:
		copy.add_theme_color_override("font_color", INK)
		copy.add_theme_font_size_override("font_size", 15)
	var confirm := _new_game_confirmation.get_ok_button()
	_apply_button_style(confirm, true)
	confirm.add_theme_font_size_override("font_size", 16)
	confirm.custom_minimum_size = Vector2(170, 42)
	var cancel := _new_game_confirmation.get_cancel_button()
	_apply_button_style(cancel, false)
	cancel.add_theme_font_size_override("font_size", 16)
	cancel.custom_minimum_size = Vector2(170, 42)


func _make_panel(background: Color, border: Color,
		corner_radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		_style_box(background, border, corner_radius))
	return panel


func _make_margin(left: int, top: int, right: int,
		bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _style_box(background: Color, border: Color, corner_radius: int,
		border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style
