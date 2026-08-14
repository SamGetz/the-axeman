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

const TAB_UPGRADES: StringName = &"upgrades"
const TAB_YARD: StringName = &"yard"
const TAB_POWERS: StringName = &"powers"
const TAB_RECORDS: StringName = &"records"

const INK := Color(0.94, 0.89, 0.76, 1.0)
const MUTED := Color(0.64, 0.68, 0.59, 1.0)
const DIM := Color(0.45, 0.49, 0.42, 1.0)
const GOLD := Color(0.86, 0.67, 0.31, 1.0)
const GREEN := Color(0.55, 0.78, 0.48, 1.0)
const RED := Color(0.94, 0.61, 0.51, 1.0)
const BLUE := Color(0.48, 0.72, 0.90, 1.0)
const PURPLE := Color(0.75, 0.55, 0.91, 1.0)
const PANEL_DARK := Color(0.055, 0.069, 0.056, 0.98)
const PANEL_MID := Color(0.085, 0.105, 0.079, 0.98)
const PANEL_LIGHT := Color(0.115, 0.14, 0.103, 0.98)
const BORDER := Color(0.38, 0.31, 0.19, 1.0)

var _has_save := false
var _has_attempt := false
var _current_tab: StringName = TAB_UPGRADES
var _home_message_override := ""
var _nav_buttons: Dictionary = {}

var _home_root: MarginContainer
var _home_cash_label: Label
var _home_lock_banner: PanelContainer
var _home_message_label: Label
var _home_content_title: Label
var _home_content_subtitle: Label
var _home_scroll: ScrollContainer
var _home_content: VBoxContainer
var _home_selection_label: Label
var _home_start_button: Button
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
	_intro_center.visible = not _has_save
	_home_root.visible = _has_save

	_load_game_button.disabled = not _has_save
	_load_game_button.visible = _has_save and not _has_attempt
	_load_game_button.text = "Start Run"
	_resume_attempt_button.visible = _has_attempt
	_abandon_attempt_button.visible = _has_attempt
	_load_game_button.tooltip_text = (
		"Keep your permanent yard and begin a fresh attempt."
		if _has_save else "No saved yard was found."
	)
	_new_game_button.text = "Start Fresh Profile" if _has_save else "Create Profile"
	_status_label.text = (
		"A suspended attempt is ready."
		if _has_attempt
		else "Your permanent yard is ready for another run."
	) if _has_save else "No save found — begin a new yard."

	if _has_save:
		_refresh_home(true)
		if _has_attempt and _home_resume_button != null:
			_home_resume_button.grab_focus()
		elif _home_start_button != null:
			_home_start_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _build_home() -> void:
	_home_root = MarginContainer.new()
	_home_root.name = "HomeRoot"
	_home_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home_root.add_theme_constant_override("margin_left", 26)
	_home_root.add_theme_constant_override("margin_top", 20)
	_home_root.add_theme_constant_override("margin_right", 26)
	_home_root.add_theme_constant_override("margin_bottom", 20)
	add_child(_home_root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	_home_root.add_child(shell)

	var header := _make_panel(PANEL_DARK, BORDER, 11)
	header.custom_minimum_size = Vector2(0, 82)
	shell.add_child(header)
	var header_margin := _make_margin(22, 12, 22, 12)
	header.add_child(header_margin)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 18)
	header_margin.add_child(header_row)
	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 1)
	header_row.add_child(title_column)
	var kicker := _make_label("PERMANENT HOME", 12, GOLD)
	title_column.add_child(kicker)
	var title := _make_label("THE AXEMAN", 29, INK)
	title_column.add_child(title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)
	var bank_column := VBoxContainer.new()
	bank_column.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_child(bank_column)
	var bank_kicker := _make_label("HOME CASH", 11, MUTED)
	bank_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bank_column.add_child(bank_kicker)
	_home_cash_label = _make_label("$0", 27, GOLD)
	_home_cash_label.name = "HomeCashLabel"
	_home_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_home_cash_label.custom_minimum_size.x = 190
	bank_column.add_child(_home_cash_label)

	_home_lock_banner = _make_panel(Color(0.18, 0.105, 0.065, 0.98), RED, 8)
	_home_lock_banner.name = "SuspendedLockBanner"
	shell.add_child(_home_lock_banner)
	var lock_margin := _make_margin(14, 8, 14, 8)
	_home_lock_banner.add_child(lock_margin)
	var lock_label := _make_label(
		"SUSPENDED RUN · Permanent upgrades and yard controls are read-only until you Resume or Abandon.",
		14, Color(1.0, 0.79, 0.64, 1.0))
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_margin.add_child(lock_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	shell.add_child(body)

	var nav_panel := _make_panel(PANEL_DARK, BORDER, 10)
	nav_panel.custom_minimum_size.x = 218
	body.add_child(nav_panel)
	var nav_margin := _make_margin(14, 16, 14, 14)
	nav_panel.add_child(nav_margin)
	var nav_column := VBoxContainer.new()
	nav_column.add_theme_constant_override("separation", 9)
	nav_margin.add_child(nav_column)
	var nav_heading := _make_label("HOME HUB", 12, MUTED)
	nav_column.add_child(nav_heading)
	_add_nav_button(nav_column, TAB_UPGRADES, "Upgrades", "18 permanent lines")
	_add_nav_button(nav_column, TAB_YARD, "Yard", "Stage & frequency")
	_add_nav_button(nav_column, TAB_POWERS, "Power Catalogue", "Run-only discoveries")
	_add_nav_button(nav_column, TAB_RECORDS, "Records", "Career & yard history")
	var nav_spacer := Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_column.add_child(nav_spacer)
	_home_new_profile_button = _make_button("Start Fresh Profile", false)
	_home_new_profile_button.name = "NewProfileButton"
	_home_new_profile_button.custom_minimum_size.y = 42
	_home_new_profile_button.pressed.connect(_on_new_game_pressed)
	nav_column.add_child(_home_new_profile_button)

	var content_panel := _make_panel(PANEL_DARK, BORDER, 10)
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content_panel)
	var content_margin := _make_margin(20, 16, 20, 16)
	content_panel.add_child(content_margin)
	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 7)
	content_margin.add_child(content_column)
	_home_content_title = _make_label("UPGRADES", 23, INK)
	_home_content_title.name = "ContentTitle"
	content_column.add_child(_home_content_title)
	_home_content_subtitle = _make_label("", 13, MUTED)
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

	var action_panel := _make_panel(PANEL_DARK, BORDER, 10)
	action_panel.custom_minimum_size.y = 62
	shell.add_child(action_panel)
	var action_margin := _make_margin(16, 8, 12, 8)
	action_panel.add_child(action_margin)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 9)
	action_margin.add_child(action_row)
	var action_copy := VBoxContainer.new()
	action_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_child(action_copy)
	_home_message_label = _make_label("Cash is banked when a run settles.", 12, MUTED)
	_home_message_label.name = "StatusLabel"
	_home_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_copy.add_child(_home_message_label)
	_home_selection_label = _make_label("", 12, DIM)
	_home_selection_label.name = "SelectionLabel"
	action_copy.add_child(_home_selection_label)
	_home_abandon_button = _make_button("Abandon", false)
	_home_abandon_button.name = "AbandonAttemptButton"
	_home_abandon_button.custom_minimum_size = Vector2(112, 44)
	_home_abandon_button.pressed.connect(abandon_attempt_requested.emit)
	action_row.add_child(_home_abandon_button)
	_home_resume_button = _make_button("Resume Run", true)
	_home_resume_button.name = "ResumeAttemptButton"
	_home_resume_button.custom_minimum_size = Vector2(154, 44)
	_home_resume_button.pressed.connect(resume_attempt_requested.emit)
	action_row.add_child(_home_resume_button)
	_home_start_button = _make_button("Start Run", true)
	_home_start_button.name = "StartRunButton"
	_home_start_button.custom_minimum_size = Vector2(154, 44)
	_home_start_button.pressed.connect(_on_continue_pressed)
	action_row.add_child(_home_start_button)


func _add_nav_button(parent: VBoxContainer, id: StringName, title: String,
		subtitle: String) -> void:
	var button := _make_button("%s\n%s" % [title, subtitle], false)
	match id:
		TAB_UPGRADES:
			button.name = "UpgradesTabButton"
		TAB_YARD:
			button.name = "YardTabButton"
		TAB_POWERS:
			button.name = "PowerCatalogueTabButton"
		TAB_RECORDS:
			button.name = "RecordsTabButton"
	button.custom_minimum_size.y = 57
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.pressed.connect(_select_home_tab.bind(id))
	parent.add_child(button)
	_nav_buttons[id] = button


func _refresh_home(rebuild_content: bool) -> void:
	if _home_root == null:
		return
	_home_cash_label.text = "$%s" % _format_number(GameState.get_home_cash())
	var locked := _permanent_mutations_locked()
	_home_lock_banner.visible = _has_attempt
	_home_start_button.visible = not _has_attempt
	_home_start_button.disabled = _has_attempt
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
			nav_button.set_pressed_no_signal(StringName(raw_id) == _current_tab)
	if rebuild_content and _has_save:
		_render_current_tab(true)


func _select_home_tab(id: StringName) -> void:
	if id not in [TAB_UPGRADES, TAB_YARD, TAB_POWERS, TAB_RECORDS]:
		return
	_current_tab = id
	_home_message_override = ""
	_render_current_tab(false)
	_refresh_home(false)
	_home_scroll.scroll_vertical = 0


func _render_current_tab(preserve_scroll: bool) -> void:
	if _home_content == null:
		return
	var previous_scroll := _home_scroll.scroll_vertical if preserve_scroll else 0
	_clear_children(_home_content)
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
	_home_content_title.text = "PERMANENT UPGRADES"
	_home_content_subtitle.text = (
		"Spend banked Home Cash between runs. Every line is visible, every rank is "
		+ "authored explicitly, and a full refund returns exactly what you paid."
	)
	var table := SurvivorsContent.meta_upgrades()
	if table == null:
		_add_empty_state("The permanent-upgrade catalogue could not be loaded.")
		return
	var total_ranks := 0
	var total_spent := 0
	for definition: MetaUpgradeDef in table.upgrades:
		if definition == null:
			continue
		total_ranks += GameState.get_meta_upgrade_rank(definition.id)
		total_spent += GameState.get_meta_upgrade_spend(definition.id)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 12)
	_home_content.add_child(summary_row)
	var summary := _make_label("%d lines · %d ranks owned · $%s invested" % [
		table.upgrades.size(), total_ranks, _format_number(total_spent)], 13, MUTED)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(summary)
	var refund := _make_button("Refund All · $%s" % _format_number(total_spent), false)
	refund.custom_minimum_size = Vector2(184, 40)
	refund.disabled = _permanent_mutations_locked() or total_spent <= 0
	refund.tooltip_text = (
		"Permanent controls are locked while a run is suspended."
		if _permanent_mutations_locked()
		else "Free full refund using the exact recorded amounts paid."
	)
	refund.pressed.connect(_refund_all_upgrades)
	summary_row.add_child(refund)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_home_content.add_child(grid)
	for definition: MetaUpgradeDef in table.upgrades:
		if definition != null:
			grid.add_child(_build_upgrade_card(definition, table))


func _build_upgrade_card(definition: MetaUpgradeDef,
		table: MetaUpgradeTable) -> PanelContainer:
	var card := _make_panel(PANEL_MID, Color(0.27, 0.25, 0.17, 1.0), 8)
	card.name = "Upgrade_%s" % definition.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(380, 238)
	var margin := _make_margin(13, 12, 13, 12)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var rank := GameState.get_meta_upgrade_rank(definition.id)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var icon := _make_icon(definition.icon_path, Vector2(42, 42))
	top.add_child(icon)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_column)
	var title := _make_label(definition.display_name, 17, INK)
	title_column.add_child(title)
	var id_label := _make_label(String(definition.id), 10, DIM)
	title_column.add_child(id_label)
	var rank_label := _make_label("RANK %d / %d" % [rank, definition.max_rank], 12,
		GREEN if rank > 0 else MUTED)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(rank_label)

	var description := _make_label(definition.description, 12, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 34
	column.add_child(description)
	var effects := _make_label(_meta_effect_summary(definition, rank), 11, BLUE)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(effects)
	var limitation := _make_label(definition.limitation, 10, DIM)
	limitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(limitation)
	var ladder := _make_label("COSTS · %s" % _cost_ladder(definition.costs_by_rank),
		10, DIM)
	ladder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(ladder)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	column.add_child(bottom)
	var tuning := _make_label("PLACEHOLDER TUNING", 10, GOLD)
	tuning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuning.tooltip_text = definition.tuning_status
	bottom.add_child(tuning)
	var buy := _make_button("", true)
	buy.name = "Buy_%s" % definition.id
	buy.custom_minimum_size = Vector2(142, 38)
	_configure_upgrade_buy_button(buy, definition, table, rank)
	buy.pressed.connect(_purchase_upgrade.bind(definition.id))
	bottom.add_child(buy)
	return card


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
	_home_content_title.text = "YARD & STARTING PRESSURE"
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
	for tier: int in range(yard.starting_delivery_intervals.size()):
		var interval := float(yard.starting_delivery_intervals[tier])
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
	var rarity_color := _rarity_color(definition.rarity)
	var card := _make_panel(PANEL_MID if unlocked else PANEL_DARK,
		rarity_color.darkened(0.42) if unlocked else Color(0.2, 0.21, 0.19, 1.0), 8)
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
	title_column.add_child(_make_label("%s · %s · CAP %d" % [
		_rarity_name(definition.rarity), _pool_name(definition.pool),
		definition.rank_cap], 10, rarity_color))
	var state := _make_label("UNLOCKED" if unlocked else "BLUEPRINT LOCKED", 10,
		GREEN if unlocked else DIM)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(state)
	var copy := _make_label(definition.description, 12, MUTED if unlocked else DIM)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.y = 34
	column.add_child(copy)
	var effects := _make_label(_power_effect_summary(definition), 10,
		rarity_color if unlocked else DIM)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(effects)
	var tuning := _make_label("PLACEHOLDER TUNING", 10, GOLD if unlocked else DIM)
	tuning.tooltip_text = definition.tuning_status
	column.add_child(tuning)
	return card


func _render_records() -> void:
	_home_content_title.text = "RECORDS"
	_home_content_subtitle.text = (
		"Permanent career totals and independent yard records. Legacy values remain "
		+ "read-only and never affect the survivors run."
	)
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


func _emit_new_profile() -> void:
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
		ProgressionEffectDef.Kind.WINDUP_TIME,
		ProgressionEffectDef.Kind.BLOCK_WORK_RADIUS,
		ProgressionEffectDef.Kind.BLOCK_SETTLE_TIME,
		ProgressionEffectDef.Kind.BLOCK_HANDOFF_TIME,
		ProgressionEffectDef.Kind.SCAR_RELIABILITY,
		ProgressionEffectDef.Kind.BOSS_CUT_EFFECTIVENESS,
		ProgressionEffectDef.Kind.FOURTH_CARD_CHANCE,
		ProgressionEffectDef.Kind.RARE_OFFER_WEIGHT,
		ProgressionEffectDef.Kind.EPIC_OFFER_WEIGHT,
		ProgressionEffectDef.Kind.BLASTER_DROP_CHANCE,
		ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE,
	]:
		return "%.0f%%" % (value * 100.0)
	return "%.2f" % value


func _effect_name(kind: ProgressionEffectDef.Kind) -> String:
	var names := ProgressionEffectDef.Kind.keys()
	if int(kind) < 0 or int(kind) >= names.size():
		return "Effect"
	return String(names[int(kind)]).capitalize()


func _cost_ladder(costs: PackedInt64Array) -> String:
	var values := PackedStringArray()
	for cost: int in costs:
		values.append("$%s" % _format_number(cost))
	return " › ".join(values)


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


func _rarity_name(rarity: RunPowerDef.Rarity) -> String:
	match rarity:
		RunPowerDef.Rarity.COMMON:
			return "COMMON"
		RunPowerDef.Rarity.RARE:
			return "RARE"
		RunPowerDef.Rarity.EPIC:
			return "EPIC"
	return "UNKNOWN"


func _rarity_color(rarity: RunPowerDef.Rarity) -> Color:
	match rarity:
		RunPowerDef.Rarity.RARE:
			return BLUE
		RunPowerDef.Rarity.EPIC:
			return PURPLE
	return GREEN


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
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 1.0))
	button.add_theme_color_override("font_disabled_color", DIM)
	var normal_bg := Color(0.24, 0.285, 0.19, 1.0) if accent \
		else Color(0.15, 0.18, 0.135, 1.0)
	button.add_theme_stylebox_override("normal", _style_box(normal_bg, BORDER, 7))
	button.add_theme_stylebox_override("hover", _style_box(
		Color(0.30, 0.35, 0.23, 1.0), GOLD, 7))
	button.add_theme_stylebox_override("pressed", _style_box(
		Color(0.11, 0.14, 0.10, 1.0), GOLD.darkened(0.15), 7))
	button.add_theme_stylebox_override("disabled", _style_box(
		Color(0.09, 0.10, 0.085, 1.0), Color(0.19, 0.19, 0.16, 1.0), 7))
	button.add_theme_stylebox_override("focus", _style_box(Color.TRANSPARENT, GOLD, 7, 3))
	return button


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
