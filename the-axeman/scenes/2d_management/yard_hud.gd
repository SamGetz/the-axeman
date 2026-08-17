class_name YardHUD
extends Control
## Transitional slice-one run HUD. Permanent progression is home-only, so this
## surface exposes pause/suspend/abandon but no shop, skill or species spending.

signal displayed_level_gained(new_level: int)
signal suspend_requested
signal abandon_requested
signal home_requested

const _CREAM := Color(0.965, 0.925, 0.82, 0.97)
const _INK := Color(0.13, 0.105, 0.075, 1.0)
const _RUST := Color(0.58, 0.12, 0.07, 1.0)
const _FOREST := Color(0.10, 0.25, 0.14, 1.0)
const _MENU_PANEL := Color(0.045, 0.052, 0.038, 0.985)
const _MENU_SURFACE := Color(0.105, 0.115, 0.078, 0.99)
const _MENU_INK := Color(0.96, 0.91, 0.78, 1.0)
const _MENU_MUTED := Color(0.70, 0.68, 0.57, 1.0)
const _MENU_GOLD := Color(0.86, 0.66, 0.28, 1.0)
const _COIN := preload("res://assets/ui/coin.png")
const _LevelUpOfferRain := preload(
	"res://scenes/2d_management/level_up_offer_rain.gd")

var _run: RunDirector
var _xp_source: Node
var _panel_kind := &""
var _warning_times: Dictionary = {}
var _earliest_warning_id: StringName = &""
var _earliest_warning_seconds := INF
var _displayed_level := 1
var _displayed_xp_total := 0
var _pending_orb_xp := 0
var _inflight_orb_xp := 0
var _xp_delivery_queue: Array[int] = []
var _xp_delivery_animating := false
var _xp_delivery_flush_queued := false
var _xp_delivery_generation := 0
var _xp_level_up_hold_level := 0
var _displayed_cash := 0
var _pending_coin_count := 0
var _power_slot_labels: Array[Label] = []
var _power_slot_panels: Array[PanelContainer] = []
var _power_slot_icons: Array[TextureRect] = []
var _power_slot_rank_labels: Array[Label] = []
var _power_slot_status_labels: Array[Label] = []
var _power_slots_snapshot: Array = []
var _power_ranks_snapshot: Dictionary = {}
var _power_runtime_state: Dictionary = {}
var _power_runtime_available := false

var _stage_label: Label
var _cash_label: Label
var _bank_label: Label
var _clock_label: Label
var _loose_label: Label
var _delivery_label: Label
var _xp_label: Label
var _xp_progress: ProgressBar
var _danger_label: Label
var _boss_stack_label: Label
var _modal_backdrop: ColorRect
var _modal: PanelContainer
var _modal_title: Label
var _modal_list: VBoxContainer
var _modal_resume: Button
var _result_backdrop: ColorRect
var _result_title: Label
var _result_stats: Label
var _result_primary: Button
var _result_secondary: Button
var _offer_backdrop: ColorRect
var _offer_panel: PanelContainer
var _offer_content: VBoxContainer
var _offer_rain_layer: Control
var _offer_rain_clip: Control
var _offer_rain: LevelUpOfferRain
var _offer_rain_serial := -1
var _offer_title: Label
var _offer_cards: VBoxContainer
var _offer_retired_cards: Array[Control] = []
var _offer_choose_buttons: Array[Button] = []
var _offer_reroll: Button
var _offer_charges: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_always_on_hud()
	_build_quick_menu()
	_build_modal()
	_build_results()
	_build_power_offer()
	visibility_changed.connect(_on_hud_visibility_changed)
	GameState.home_cash_changed.connect(_on_home_cash_changed)
	_displayed_level = 1
	_refresh_profile()


## Vampire-Survivors-style menu flow: one Cancel action always backs out of an
## ordinary pause, while mandatory level choices and run results remain modal.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") \
			and _modal_backdrop != null and _modal_backdrop.visible \
			and (_offer_backdrop == null or not _offer_backdrop.visible) \
			and (_result_backdrop == null or not _result_backdrop.visible):
		get_viewport().set_input_as_handled()
		_close_panel()


func _exit_tree() -> void:
	if _offer_rain != null:
		_offer_rain.stop()
	_free_retired_offer_cards()


func _free_retired_offer_cards() -> void:
	for retired: Control in _offer_retired_cards:
		if is_instance_valid(retired):
			retired.free()
	_offer_retired_cards.clear()


func bind_run_director(run: RunDirector) -> void:
	_run = run
	if _run == null:
		return
	_run.run_identity_changed.connect(_on_run_identity_changed)
	_run.cash_changed.connect(_on_cash_changed)
	_run.xp_changed.connect(_on_run_xp_changed)
	_run.level_choice_changed.connect(_on_level_choice_changed)
	_run.power_slots_changed.connect(_on_power_slots_changed)
	if _run.has_signal(&"run_power_runtime_changed"):
		var runtime_callback := Callable(self, "_on_run_power_runtime_changed")
		if not _run.is_connected(&"run_power_runtime_changed", runtime_callback):
			_run.connect(&"run_power_runtime_changed", runtime_callback)
		_power_runtime_available = true
	_run.utility_charges_changed.connect(_on_utility_charges_changed)
	_run.run_clock_changed.connect(_on_run_clock_changed)
	_run.stage_time_changed.connect(_on_stage_time_changed)
	_run.delivery_changed.connect(_on_delivery_changed)
	_run.loose_logs_changed.connect(_on_loose_logs_changed)
	_run.boundary_warning_changed.connect(_on_boundary_warning_changed)
	_run.phase_changed.connect(_on_phase_changed)
	_run.stage_cleared.connect(_on_stage_cleared)
	if _run.has_signal(&"boss_stack_changed"):
		_run.boss_stack_changed.connect(_on_boss_stack_changed)
	_run.attempt_finished.connect(_on_attempt_finished)
	_run.settlement_failed.connect(show_error)
	var choice_callback := Callable(_run, "present_level_choice")
	if not displayed_level_gained.is_connected(choice_callback):
		displayed_level_gained.connect(choice_callback)
	_displayed_cash = _run.get_cash()
	_pending_coin_count = 0
	_reset_xp_presentation(_run.get_xp())
	_refresh_run()
	if _run.has_method("get_run_power_runtime_state"):
		var runtime_state: Variant = _run.call("get_run_power_runtime_state")
		if runtime_state is Dictionary:
			_power_runtime_state = (runtime_state as Dictionary).duplicate(true)
			_power_runtime_available = true
	_on_power_slots_changed(_run.get_power_slots(), _run.get_run_power_ranks())
	_on_utility_charges_changed(int(_run.get_utility_charges().get("rerolls", 0)),
		int(_run.get_utility_charges().get("banishes", 0)))
	_on_level_choice_changed(_run.get_current_offer())


func bind_xp_source(source: Node) -> void:
	_xp_source = source
	if source == null:
		return
	if source.has_signal("xp_orb_batch_started"):
		var batch_callback := Callable(self, "_on_xp_orb_batch_started")
		if not source.is_connected(&"xp_orb_batch_started", batch_callback):
			source.connect(&"xp_orb_batch_started", batch_callback)
	if source.has_signal("xp_orb_collected"):
		var collected_callback := Callable(self, "_on_xp_orb_collected")
		if not source.is_connected(&"xp_orb_collected", collected_callback):
			source.connect(&"xp_orb_collected", collected_callback)
	if source.has_signal("coin_batch_started"):
		var coin_batch_callback := Callable(self, "_on_coin_batch_started")
		if not source.is_connected(&"coin_batch_started", coin_batch_callback):
			source.connect(&"coin_batch_started", coin_batch_callback)
	if source.has_signal("coin_collected"):
		var coin_callback := Callable(self, "_on_coin_collected")
		if not source.is_connected(&"coin_collected", coin_callback):
			source.connect(&"coin_collected", coin_callback)
	if source.has_signal("coins_cancelled"):
		var cancel_callback := Callable(self, "_on_coins_cancelled")
		if not source.is_connected(&"coins_cancelled", cancel_callback):
			source.connect(&"coins_cancelled", cancel_callback)
	if source.has_signal("coin_batch_finished"):
		var finish_callback := Callable(self, "_on_coin_batch_finished")
		if not source.is_connected(&"coin_batch_finished", finish_callback):
			source.connect(&"coin_batch_finished", finish_callback)
	if source.has_method("set_xp_screen_target"):
		source.call("set_xp_screen_target",
			Callable(self, "xp_orb_target_normalized"))
	if source.has_method("set_coin_screen_target"):
		source.call("set_coin_screen_target",
			Callable(self, "coin_target_normalized"))
	if source.has_method("present_level_gain"):
		var level_callback := Callable(source, "present_level_gain")
		if not displayed_level_gained.is_connected(level_callback):
			displayed_level_gained.connect(level_callback)


func show_error(message: String) -> void:
	if _run != null:
		_run.pause_attempt()
	if _result_backdrop != null:
		_result_backdrop.hide()
	if _offer_backdrop != null:
		_set_offer_presentation_active(false)
	_panel_kind = &"pause"
	_modal_backdrop.show()
	move_child(_modal_backdrop, get_child_count() - 1)
	_rebuild_panel()
	var error := _body(message)
	error.add_theme_color_override("font_color", _RUST)
	_modal_list.add_child(error)
	_modal_list.move_child(error, 0)


func _build_always_on_hud() -> void:
	# Session cash stays prominent so reward coins have an unmistakable target;
	# the permanent bank remains smaller and locked throughout the attempt.
	var xp_bar := Control.new()
	xp_bar.name = "XPBar"
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_bottom = 24
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(xp_bar)
	_xp_progress = ProgressBar.new()
	_xp_progress.name = "Progress"
	_xp_progress.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xp_progress.max_value = 1.0
	_xp_progress.step = 0.001
	_xp_progress.show_percentage = false
	_xp_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_background := StyleBoxFlat.new()
	xp_background.bg_color = Color(0.10, 0.075, 0.045, 0.82)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.75, 0.51, 0.16, 0.96)
	_xp_progress.add_theme_stylebox_override("background", xp_background)
	_xp_progress.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.add_child(_xp_progress)
	_xp_label = _label("Level 1", 14, Color(1.0, 0.94, 0.76, 1.0))
	_xp_label.name = "LevelLabel"
	_xp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_label.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 0.9))
	_xp_label.add_theme_constant_override("outline_size", 3)
	xp_bar.add_child(_xp_label)

	var cash_row := HBoxContainer.new()
	cash_row.name = "CashCounter"
	cash_row.position = Vector2(16, 36)
	cash_row.size = Vector2(260, 42)
	cash_row.add_theme_constant_override("separation", 8)
	cash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cash_row)
	var cash_icon := TextureRect.new()
	cash_icon.name = "CashIcon"
	cash_icon.custom_minimum_size = Vector2(32, 32)
	cash_icon.texture = _COIN
	cash_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cash_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cash_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cash_row.add_child(cash_icon)
	_cash_label = _label("0", 26, Color(1.0, 0.90, 0.58, 1.0))
	_cash_label.name = "CashLabel"
	_cash_label.add_theme_color_override("font_outline_color", Color(0.18, 0.105, 0.045, 0.9))
	_cash_label.add_theme_constant_override("outline_size", 3)
	cash_row.add_child(_cash_label)
	_bank_label = _label("BANK 0 · LOCKED", 12, Color(0.78, 0.74, 0.65, 0.94))
	_bank_label.name = "LockedHomeBank"
	_bank_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04, 0.9))
	_bank_label.add_theme_constant_override("outline_size", 3)
	_bank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cash_row.add_child(_bank_label)

	var detail := HBoxContainer.new()
	detail.name = "RunPressure"
	detail.position = Vector2(18, 82)
	detail.size = Vector2(360, 28)
	detail.add_theme_constant_override("separation", 16)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail)
	_loose_label = _label("Loose 0", 14, Color.WHITE)
	_delivery_label = _label("Next 0.0s", 14, Color.WHITE)
	for label: Label in [_loose_label, _delivery_label]:
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 1.0))
		label.add_theme_constant_override("outline_size", 5)
		detail.add_child(label)

	var lower_left := HBoxContainer.new()
	lower_left.name = "StageAndRunTimer"
	lower_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lower_left.position = Vector2(16, -42)
	lower_left.size = Vector2(520, 26)
	lower_left.add_theme_constant_override("separation", 16)
	lower_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower_left)
	_stage_label = _label("YARD ONE · 15:00", 13,
		Color(0.82, 0.82, 0.77, 0.96))
	_clock_label = _label("RUN  00:00.000", 13, Color(0.90, 0.82, 0.64, 0.96))
	_stage_label.name = "StageCountdown"
	_clock_label.name = "RunTimer"
	for label: Label in [_stage_label, _clock_label]:
		label.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.035, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		lower_left.add_child(label)

	_danger_label = _label("", 28, Color.WHITE)
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.position = Vector2(440, 82)
	_danger_label.size = Vector2(400, 46)
	_danger_label.add_theme_color_override("font_outline_color", Color(0.25, 0, 0, 1))
	_danger_label.add_theme_constant_override("outline_size", 8)
	_danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_label)

	_boss_stack_label = _label("", 18, Color(1.0, 0.86, 0.48, 1.0))
	_boss_stack_label.name = "BossStackStatus"
	_boss_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_stack_label.position = Vector2(900, 42)
	_boss_stack_label.size = Vector2(350, 44)
	_boss_stack_label.add_theme_color_override(
		"font_outline_color", Color(0.12, 0.035, 0.01, 1.0))
	_boss_stack_label.add_theme_constant_override("outline_size", 6)
	_boss_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_stack_label.hide()
	add_child(_boss_stack_label)

	var power_slots := HBoxContainer.new()
	power_slots.name = "RunPowerSlots"
	# Icon-first active loadout: compact enough to stay out of the playfield and
	# anchored immediately under the full-width XP bar at every viewport size.
	power_slots.set_anchors_preset(Control.PRESET_CENTER_TOP)
	power_slots.position = Vector2(-178, 30)
	power_slots.size = Vector2(356, 42)
	power_slots.add_theme_constant_override("separation", 4)
	power_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_slots)
	for index: int in range(RunDirector.MAX_RUN_POWER_SLOTS):
		var slot := PanelContainer.new()
		slot.name = "PowerSlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(56, 40)
		slot.add_theme_stylebox_override("panel", _power_slot_style(
			Color(0.12, 0.09, 0.055, 0.86),
			Color(0.65, 0.52, 0.30, 0.75)))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		power_slots.add_child(slot)
		_power_slot_panels.append(slot)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(column)
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_theme_constant_override("separation", 3)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(top)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(icon)
		_power_slot_icons.append(icon)
		var slot_label := _label("EMPTY", 8, Color(0.72, 0.66, 0.55, 0.95))
		slot_label.name = "Name"
		slot_label.custom_minimum_size = Vector2(0, 18)
		slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.clip_text = true
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(slot_label)
		slot_label.hide()
		_power_slot_labels.append(slot_label)
		var footer := HBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_CENTER
		footer.add_theme_constant_override("separation", 2)
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(footer)
		var rank_label := _label("", 9, Color(0.94, 0.79, 0.47, 1.0))
		rank_label.name = "Rank"
		footer.add_child(rank_label)
		_power_slot_rank_labels.append(rank_label)
		var status_label := _label("", 8, Color(0.76, 0.90, 0.70, 1.0))
		status_label.name = "Status"
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		footer.add_child(status_label)
		status_label.hide()
		_power_slot_status_labels.append(status_label)


func _build_quick_menu() -> void:
	var row := HBoxContainer.new()
	row.name = "QuickMenu"
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.position = Vector2(-110, -62)
	row.size = Vector2(92, 44)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)
	for entry: Array in [["PAUSE", &"pause"]]:
		var button := _button(String(entry[0]))
		button.custom_minimum_size = Vector2(92, 42)
		button.pressed.connect(_open_panel.bind(entry[1]))
		row.add_child(button)


func _build_modal() -> void:
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.name = "ModalBackdrop"
	_modal_backdrop.color = Color(0.012, 0.014, 0.010, 0.82)
	_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_modal_backdrop)
	_modal = PanelContainer.new()
	_modal.name = "ManagementPanel"
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.position = Vector2(-380, -215)
	_modal.size = Vector2(760, 430)
	_modal.add_theme_stylebox_override("panel", _panel_style(
		_MENU_PANEL, 8, 4, _MENU_GOLD))
	_modal_backdrop.add_child(_modal)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_modal.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	_modal_title = _label("", 34, _MENU_INK)
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_modal_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_modal_list = VBoxContainer.new()
	_modal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_modal_list)
	_modal_backdrop.hide()


func _build_results() -> void:
	_result_backdrop = ColorRect.new()
	_result_backdrop.name = "ResultOverlay"
	_result_backdrop.color = Color(0.012, 0.014, 0.010, 0.88)
	_result_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -250)
	panel.size = Vector2(680, 500)
	panel.add_theme_stylebox_override("panel", _panel_style(
		_MENU_PANEL, 8, 4, _MENU_GOLD))
	_result_backdrop.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	_result_title = _label("", 38, _MENU_INK)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_title)
	_result_stats = _label("", 18, _MENU_MUTED)
	_result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_stats)
	_result_primary = _button("GO HOME")
	_result_primary.custom_minimum_size = Vector2(420, 58)
	column.add_child(_result_primary)
	_result_secondary = _button("CONTINUE ENDLESS")
	_result_secondary.custom_minimum_size = Vector2(420, 54)
	column.add_child(_result_secondary)
	_result_backdrop.hide()


func _build_power_offer() -> void:
	_offer_backdrop = ColorRect.new()
	_offer_backdrop.name = "RunPowerOffer"
	_offer_backdrop.color = Color(0.012, 0.014, 0.010, 0.86)
	_offer_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offer_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_offer_backdrop)
	_offer_panel = PanelContainer.new()
	_offer_panel.name = "OfferPanel"
	_offer_panel.set_anchors_preset(Control.PRESET_CENTER)
	_offer_panel.position = Vector2(-500, -330)
	_offer_panel.size = Vector2(1000, 660)
	_offer_panel.add_theme_stylebox_override("panel", _panel_style(
		_MENU_PANEL, 8, 4, _MENU_GOLD))
	_offer_backdrop.add_child(_offer_panel)
	_offer_content = VBoxContainer.new()
	_offer_content.name = "OfferContent"
	_offer_content.add_theme_constant_override("separation", 10)
	_offer_panel.add_child(_offer_content)
	_offer_title = _label("LEVEL UP — CHOOSE ONE", 32, _MENU_INK)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_content.add_child(_offer_title)
	var subtitle := _label(
		"Choose one power · six slots maximum", 14, _MENU_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_content.add_child(subtitle)
	_offer_cards = _new_offer_cards_container()
	_offer_content.add_child(_offer_cards)
	var utilities := HBoxContainer.new()
	utilities.alignment = BoxContainer.ALIGNMENT_CENTER
	utilities.add_theme_constant_override("separation", 12)
	_offer_content.add_child(utilities)
	_offer_reroll = _button("REROLL")
	_offer_reroll.custom_minimum_size = Vector2(220, 48)
	_offer_reroll.pressed.connect(_on_offer_reroll_pressed)
	utilities.add_child(_offer_reroll)
	_offer_charges = _label("Rerolls 0 · Banishes 0", 14, _MENU_MUTED)
	utilities.add_child(_offer_charges)
	# One batched, input-transparent overlay sits above the opaque card panels but
	# is clipped to their band and kept deliberately faint. The full-panel layer
	# lets PanelContainer lay out normal content independently; the manually sized
	# child provides the real CanvasItem clip for the rain's custom drawing.
	_offer_rain_layer = Control.new()
	_offer_rain_layer.name = "LevelChoiceDecorLayer"
	_offer_rain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_rain_layer.z_index = 5
	_offer_panel.add_child(_offer_rain_layer)
	_offer_rain_clip = Control.new()
	_offer_rain_clip.name = "CardBandClip"
	_offer_rain_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_rain_clip.clip_contents = true
	_offer_rain_layer.add_child(_offer_rain_clip)
	_offer_rain = _LevelUpOfferRain.new()
	_offer_rain.name = "LevelChoiceDecor"
	_offer_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_rain_clip.add_child(_offer_rain)
	_set_offer_presentation_active(false)


func _on_level_choice_changed(offer: Dictionary) -> void:
	if _offer_backdrop == null:
		return
	if offer.is_empty():
		_set_offer_presentation_active(false)
		# The wider Luck row leaves a stale Compatibility canvas/layout RID when
		# its children alone are removed. Replace that row as a unit before the next
		# narrower offer; same-width rows retain a bounded off-tree resource pool.
		if _offer_cards.get_child_count() >= RunDirector.LUCK_OFFER_CARD_COUNT:
			_replace_offer_cards_container()
		else:
			_clear_offer_cards()
		return
	_offer_title.text = "LEVEL %d — CHOOSE ONE" % int(offer.get("level", 1))
	# Compatibility can recycle shaped-text and SVG render resources one frame too
	# early when a choice row is destroyed and rebuilt. Retire the hidden controls
	# outside the layout row so their render resources remain alive while the next
	# card set is shaped; the bounded pool below prevents unbounded accumulation.
	_clear_offer_cards()
	var raw_cards: Variant = offer.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary:
				_offer_cards.add_child(_build_power_card(raw_card as Dictionary))
	_set_offer_presentation_active(true, offer)
	_sync_offer_rain_rect.call_deferred()
	_focus_first_offer_choice.call_deferred()


func _focus_first_offer_choice() -> void:
	if _offer_backdrop == null or not _offer_backdrop.visible:
		return
	for button: Button in _offer_choose_buttons:
		if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return


func _set_offer_presentation_active(active: bool,
		offer: Dictionary = {}) -> void:
	if _offer_backdrop == null:
		return
	_offer_backdrop.visible = active
	if _offer_rain == null:
		return
	if not active:
		_offer_rain_serial = -1
		_offer_rain.stop()
		return
	var serial := int(offer.get("offer_id", 0))
	var level := int(offer.get("level", 1))
	var seed := maxi(1, serial * 1009 + level * 97)
	var effect_rect := _layout_offer_rain()
	if not _offer_rain.is_active() or serial != _offer_rain_serial:
		_offer_rain_serial = serial
		_offer_rain.restart(seed, effect_rect)
	else:
		_offer_rain.set_effect_rect(effect_rect)


func _sync_offer_rain_rect() -> void:
	if _offer_rain == null or not _offer_rain.is_active() \
			or _offer_backdrop == null or not _offer_backdrop.visible:
		return
	_offer_rain.set_effect_rect(_layout_offer_rain())


func _layout_offer_rain() -> Rect2:
	if _offer_rain == null or _offer_rain_layer == null \
			or _offer_rain_clip == null or _offer_cards == null:
		return Rect2()
	var cards_global := _offer_cards.get_global_rect()
	var local_origin := _offer_rain_layer.get_global_transform().affine_inverse() \
		* cards_global.position
	_offer_rain_clip.position = local_origin
	_offer_rain_clip.size = cards_global.size
	_offer_rain.position = Vector2.ZERO
	_offer_rain.size = cards_global.size
	return Rect2(Vector2.ZERO, cards_global.size)


func _on_hud_visibility_changed() -> void:
	if not is_visible_in_tree():
		_set_offer_presentation_active(false)
		return
	if _run == null:
		return
	var offer := _run.get_current_offer()
	if not offer.is_empty():
		# Hidden HUDs do no ALWAYS-mode presentation work. Rebuild from the exact
		# authoritative offer when returning from title without consuming or rerolling.
		_on_level_choice_changed(offer)


func _new_offer_cards_container() -> VBoxContainer:
	var cards := VBoxContainer.new()
	cards.name = "Cards"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 7)
	cards.resized.connect(_sync_offer_rain_rect)
	return cards


func _replace_offer_cards_container() -> void:
	if _offer_cards == null or _offer_cards.get_parent() == null:
		return
	var old_cards := _offer_cards
	var parent := old_cards.get_parent()
	var child_index := old_cards.get_index()
	parent.remove_child(old_cards)
	old_cards.free()
	_offer_cards = _new_offer_cards_container()
	parent.add_child(_offer_cards)
	parent.move_child(_offer_cards, child_index)


func _clear_offer_cards(retain_render_resources: bool = true) -> void:
	if _offer_cards == null:
		return
	_offer_choose_buttons.clear()
	for child: Node in _offer_cards.get_children():
		child.hide()
		_offer_cards.remove_child(child)
		if retain_render_resources and child is Control:
			_offer_retired_cards.append(child as Control)
		else:
			child.free()
	while _offer_retired_cards.size() > 12:
		var oldest := _offer_retired_cards.pop_front() as Control
		if is_instance_valid(oldest):
			oldest.free()


func _build_power_card(card: Dictionary) -> Control:
	var quality := int(card.get("quality", RunOfferTuning.Quality.COMMON))
	var quality_multiplier := maxf(1.0, float(card.get(
		"quality_multiplier", 1.0)))
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(0, 106)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.add_theme_stylebox_override("panel", _quality_card_style(quality))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card_panel.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(92, 86)
	icon_frame.add_theme_stylebox_override("panel", _panel_style(
		Color(0.035, 0.042, 0.03, 0.96), 4, 2, _quality_color(quality)))
	row.add_child(icon_frame)
	var icon_path := String(card.get("icon_path", ""))
	if not icon_path.is_empty():
		var texture := load(icon_path) as Texture2D
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(78, 72)
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_frame.add_child(icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	row.add_child(details)
	var quality_row := HBoxContainer.new()
	quality_row.name = "QualityRow"
	quality_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	quality_row.add_theme_constant_override("separation", 7)
	details.add_child(quality_row)
	var quality_badge := PanelContainer.new()
	quality_badge.name = "QualityBadge"
	quality_badge.add_theme_stylebox_override("panel",
		_quality_badge_style(quality))
	quality_row.add_child(quality_badge)
	var quality_text := "%s QUALITY · ×%s" % [
		_quality_name(quality), _quality_multiplier_text(quality_multiplier)]
	var quality_label := _label(quality_text, 12,
		_quality_badge_text_color(quality))
	quality_label.name = "QualityLabel"
	quality_badge.add_child(quality_label)
	var name_label := _label(String(card.get("display_name", "Power")), 22,
		_MENU_INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(name_label)
	var rank_cap := int(card.get("rank_cap", 1))
	var rank_text := "Cash +%s" % _format_grouped_number(int(card.get("cash", 0))) \
		if StringName(card.get("id", "")) == RunDirector.PAYDAY_POWER_ID \
		else "Rank %d / %d" % [int(card.get("next_rank", 1)), rank_cap]
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 10)
	details.add_child(summary_row)
	var rank_label := _label(rank_text, 14, _MENU_GOLD)
	summary_row.add_child(rank_label)
	var power_id := StringName(card.get("id", ""))
	if power_id != RunDirector.PAYDAY_POWER_ID:
		var table := SurvivorsContent.run_powers()
		var definition := table.by_id(power_id) if table != null else null
		if definition != null:
			var summary := String(card.get("effect_summary", ""))
			if summary.is_empty() and card.has("quality_multiplier"):
				summary = definition.effect_summary_for_pick_multipliers(
					_pick_multipliers(card.get("pick_multipliers", [])),
					quality_multiplier)
			if summary.is_empty():
				summary = definition.effect_summary_for_rank(
					int(card.get("next_rank", 1)),
					int(card.get("current_rank", 0)))
			var effects := _label(summary, 13, _quality_color(quality).lightened(0.22))
			effects.name = "EffectSummary"
			effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			effects.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			summary_row.add_child(effects)
	var description := _body(String(card.get("description", "")))
	description.add_theme_color_override("font_color", _MENU_MUTED)
	description.max_lines_visible = 2
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.add_child(description)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 150
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)
	var choose := _button("CHOOSE")
	choose.name = "ChooseButton"
	choose.custom_minimum_size = Vector2(150, 46)
	choose.pressed.connect(_on_offer_choose_pressed.bind(
		StringName(card.get("id", ""))))
	actions.add_child(choose)
	_offer_choose_buttons.append(choose)
	var banish := _button("BANISH")
	banish.name = "BanishButton"
	banish.custom_minimum_size = Vector2(150, 32)
	var current_cards: Array = [] if _run == null \
		else _run.get_current_offer().get("cards", [])
	var cannot_banish := StringName(card.get("id", "")) \
		== RunDirector.PAYDAY_POWER_ID or current_cards.size() <= 1
	banish.set_meta("cannot_banish", cannot_banish)
	var charges := {} if _run == null else _run.get_utility_charges()
	banish.disabled = cannot_banish or int(charges.get("banishes", 0)) <= 0
	banish.pressed.connect(_on_offer_banish_pressed.bind(
		StringName(card.get("id", ""))))
	actions.add_child(banish)
	return card_panel


func _on_offer_choose_pressed(power_id: StringName) -> void:
	if _run != null:
		_run.choose_run_offer(power_id)


func _on_offer_reroll_pressed() -> void:
	if _run != null:
		_run.reroll_run_offer()


func _on_offer_banish_pressed(power_id: StringName) -> void:
	if _run != null:
		_run.banish_run_offer(power_id)


func _on_utility_charges_changed(rerolls: int, banishes: int) -> void:
	if _offer_reroll != null:
		_offer_reroll.disabled = rerolls <= 0
		_offer_reroll.text = "REROLL (%d)" % maxi(0, rerolls)
	if _offer_charges != null:
		_offer_charges.text = "Rerolls %d · Banishes %d" % [
			maxi(0, rerolls), maxi(0, banishes)]
	if _offer_cards != null:
		for card_panel: Node in _offer_cards.get_children():
			var banish := card_panel.find_child("BanishButton", true, false) as Button
			if banish != null:
				banish.disabled = banishes <= 0 \
					or bool(banish.get_meta("cannot_banish", false))


func _on_power_slots_changed(slots: Array, ranks: Dictionary) -> void:
	_power_slots_snapshot = slots.duplicate()
	_power_ranks_snapshot = ranks.duplicate(true)
	_refresh_power_slots()


func _on_run_power_runtime_changed(state: Dictionary) -> void:
	_power_runtime_state = state.duplicate(true)
	_power_runtime_available = true
	_refresh_power_slot_statuses()


func _refresh_power_slot_statuses() -> void:
	for index: int in range(_power_slot_status_labels.size()):
		var status_label := _power_slot_status_labels[index]
		if index >= _power_slots_snapshot.size():
			status_label.text = ""
			continue
		var power_id := StringName(_power_slots_snapshot[index])
		var table := SurvivorsContent.run_powers()
		var definition := table.by_id(power_id) if table != null else null
		var rank := int(_power_ranks_snapshot.get(
			String(power_id), _power_ranks_snapshot.get(power_id, 0)))
		status_label.text = _power_runtime_status(power_id, definition, rank)


func _refresh_power_slots() -> void:
	for index: int in range(_power_slot_labels.size()):
		var label := _power_slot_labels[index]
		var panel := _power_slot_panels[index]
		var icon := _power_slot_icons[index]
		var rank_label := _power_slot_rank_labels[index]
		var status_label := _power_slot_status_labels[index]
		if index >= _power_slots_snapshot.size():
			label.text = ""
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon.texture = null
			icon.hide()
			rank_label.text = ""
			status_label.text = ""
			panel.tooltip_text = "Empty run-power slot"
			panel.add_theme_stylebox_override("panel", _power_slot_style(
				Color(0.12, 0.09, 0.055, 0.86),
				Color(0.65, 0.52, 0.30, 0.75)))
			continue
		var power_id := StringName(_power_slots_snapshot[index])
		var table := SurvivorsContent.run_powers()
		var definition := table.by_id(power_id) if table != null else null
		var rank := int(_power_ranks_snapshot.get(
			String(power_id), _power_ranks_snapshot.get(power_id, 0)))
		label.text = String(power_id) if definition == null else definition.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rank_label.text = "R%d" % rank
		status_label.text = _power_runtime_status(power_id, definition, rank)
		if definition == null:
			icon.texture = null
			icon.hide()
			panel.tooltip_text = String(power_id)
			continue
		var texture := load(definition.icon_path) as Texture2D
		icon.texture = texture
		icon.visible = texture != null
		var current_picks := _power_pick_multipliers(power_id)
		var exact_summary := definition.effect_summary_for_rank(rank)
		if not current_picks.is_empty():
			exact_summary = definition.effect_summary_for_owned_pick_multipliers(
				current_picks)
		panel.tooltip_text = "%s\nRank %d · %s\n%s" % [definition.display_name,
			rank, exact_summary, definition.description]
		panel.add_theme_stylebox_override("panel", _power_slot_style(
			Color(0.10, 0.075, 0.045, 0.90), _MENU_GOLD))


func _power_runtime_status(power_id: StringName, definition: RunPowerDef,
		rank: int) -> String:
	if definition == null:
		return ""
	if power_id == &"momentum":
		var stacks := maxi(0, int(_power_runtime_state.get("momentum_stacks", 0)))
		var picks := _power_pick_multipliers(power_id)
		var cap_value := definition.effect_value(
			ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS, rank) \
			if picks.is_empty() else definition.effect_value_for_pick_multipliers(
				ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS, picks)
		var cap := maxi(0, int(round(cap_value)))
		return "Stacks %d/%d" % [mini(stacks, cap), cap] if _power_runtime_available \
			else "ACTIVE"
	if power_id == &"last_ditch_rescue":
		var rescue_charges: Variant = _power_runtime_state.get("rescue_charges",
			_power_runtime_state.get("rescue_charges_remaining", 0))
		return "Rescue %d" % maxi(0, int(rescue_charges)) \
			if _power_runtime_available else "ACTIVE"
	if power_id == &"yard_magnet":
		if bool(_power_runtime_state.get("yard_magnet_active", false)):
			return "PULL %.1fs" % maxf(0.0, float(_power_runtime_state.get(
				"yard_magnet_pulse_seconds_left", 0.0)))
		return "Pulse %.1fs" % maxf(0.0, float(_power_runtime_state.get(
			"yard_magnet_cycle_seconds_left", 0.0)))
	var timers: Variant = _power_runtime_state.get("timers",
		_power_runtime_state.get("periodic_seconds_left", {}))
	if timers is Dictionary:
		var timer_value: Variant = (timers as Dictionary).get(String(power_id),
			(timers as Dictionary).get(power_id, null))
		if timer_value != null:
			var seconds := _runtime_seconds(timer_value)
			return "READY" if seconds <= 0.05 else "%.1fs" % seconds
	var trigger_counts: Variant = _power_runtime_state.get("trigger_counts", {})
	if trigger_counts is Dictionary:
		var raw_count: Variant = (trigger_counts as Dictionary).get(String(power_id),
			(trigger_counts as Dictionary).get(power_id, null))
		if raw_count != null:
			var count := maxi(0, int(raw_count))
			return "Trigger %d" % count
	return "ACTIVE"


func _power_pick_multipliers(power_id: StringName) -> Array[float]:
	var all_picks: Variant = _power_runtime_state.get("pick_multipliers", {})
	if all_picks is Dictionary:
		var raw: Variant = (all_picks as Dictionary).get(String(power_id),
			(all_picks as Dictionary).get(power_id, []))
		var picks := _pick_multipliers(raw)
		if not picks.is_empty():
			return picks
	if _run != null and _run.has_method("get_run_power_pick_multipliers"):
		var queried: Variant = _run.call("get_run_power_pick_multipliers")
		if queried is Dictionary:
			return _pick_multipliers((queried as Dictionary).get(String(power_id),
				(queried as Dictionary).get(power_id, [])))
	return []


func _runtime_seconds(value: Variant) -> float:
	if value is Dictionary:
		for key: String in ["remaining", "seconds_left", "seconds"]:
			if (value as Dictionary).has(key):
				return maxf(0.0, float((value as Dictionary)[key]))
		return 0.0
	return maxf(0.0, float(value))


func _pick_multipliers(raw_values: Variant) -> Array[float]:
	var values: Array[float] = []
	if raw_values is Array:
		for raw_value: Variant in raw_values:
			values.append(maxf(1.0, float(raw_value)))
	return values


func _quality_multiplier_text(value: float) -> String:
	var result := "%.2f" % value
	while result.contains(".") and result.ends_with("0"):
		result = result.substr(0, result.length() - 1)
	if result.ends_with("."):
		result = result.substr(0, result.length() - 1)
	return result


func _quality_name(quality: int) -> String:
	match quality:
		RunOfferTuning.Quality.RARE:
			return "RARE"
		RunOfferTuning.Quality.EPIC:
			return "EPIC"
		RunOfferTuning.Quality.LEGENDARY:
			return "LEGENDARY"
	return "COMMON"


func _quality_color(quality: int) -> Color:
	return RunOfferTuning.color_for_quality(quality)


func _quality_badge_text_color(quality: int) -> Color:
	return Color(1.0, 0.92, 0.62, 1.0) \
		if quality == RunOfferTuning.Quality.LEGENDARY else _CREAM


func _quality_card_style(quality: int) -> StyleBoxFlat:
	var background := _MENU_SURFACE
	if quality == RunOfferTuning.Quality.RARE:
		background = Color(0.075, 0.105, 0.105, 0.99)
	elif quality == RunOfferTuning.Quality.EPIC:
		background = Color(0.105, 0.072, 0.115, 0.99)
	elif quality == RunOfferTuning.Quality.LEGENDARY:
		background = Color(0.145, 0.090, 0.030, 0.995)
	var legendary := quality == RunOfferTuning.Quality.LEGENDARY
	var style := _panel_style(background, 12, 5 if legendary else 3,
		_quality_color(quality))
	if legendary:
		style.shadow_color = Color(0.98, 0.66, 0.10, 0.48)
		style.shadow_size = 7
		style.shadow_offset = Vector2.ZERO
	return style


func _quality_badge_style(quality: int) -> StyleBoxFlat:
	var color := _quality_color(quality)
	var background := color.darkened(0.44)
	if quality == RunOfferTuning.Quality.LEGENDARY:
		background = Color(0.25, 0.105, 0.018, 1.0)
	var style := _panel_style(background, 5, 1, color.lightened(0.20))
	style.content_margin_left = 7
	style.content_margin_top = 2
	style.content_margin_right = 7
	style.content_margin_bottom = 2
	return style


func _open_panel(kind: StringName) -> void:
	if _run == null or not _run.has_live_attempt():
		return
	_run.pause_attempt()
	_panel_kind = kind
	_modal_backdrop.show()
	_rebuild_panel()
	_focus_pause_primary.call_deferred()


func _close_panel() -> void:
	_modal_backdrop.hide()
	_panel_kind = &""
	_modal_resume = null
	if _run != null:
		_run.resume_attempt()


func _rebuild_panel() -> void:
	for child: Node in _modal_list.get_children():
		child.queue_free()
	_modal_title.text = "PAUSED"
	_build_pause_panel()


func _build_pause_panel() -> void:
	var status := _label(
		"The run clock, chopping, and physics are frozen.", 16, _MENU_MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_list.add_child(status)
	_modal_resume = _button("RESUME RUN")
	_modal_resume.custom_minimum_size.y = 58
	_modal_resume.pressed.connect(_close_panel)
	_modal_list.add_child(_modal_resume)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	_modal_list.add_child(spacer)
	var section := _label("RUN OPTIONS", 15, _MENU_GOLD)
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_list.add_child(section)
	var suspend := _button("SUSPEND THIS ATTEMPT")
	suspend.custom_minimum_size.y = 54
	suspend.tooltip_text = "Normalises active animations, saves the exact cut journal, and returns to the title."
	suspend.pressed.connect(suspend_requested.emit)
	_modal_list.add_child(suspend)
	var abandon := _button("ABANDON ATTEMPT")
	abandon.custom_minimum_size.y = 54
	abandon.add_theme_color_override("font_color", _RUST)
	abandon.pressed.connect(abandon_requested.emit)
	_modal_list.add_child(abandon)
	var hint := _label("Esc / B  Back", 13, _MENU_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_list.add_child(hint)


func _focus_pause_primary() -> void:
	if _modal_backdrop != null and _modal_backdrop.visible \
			and is_instance_valid(_modal_resume):
		_modal_resume.grab_focus()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var local := _modal.get_global_rect()
		if not local.has_point(event.position):
			_close_panel()


func _refresh_run() -> void:
	if _run == null:
		return
	_on_cash_changed(_run.get_cash())
	_on_home_cash_changed(GameState.get_home_cash())
	_on_stage_time_changed(_run.stage_remaining_ms())
	_on_run_clock_changed(_run.elapsed_ms())
	_on_delivery_changed(float(_run.to_save_dict().get("delivery_seconds_left", 0.0)),
		int(_run.to_save_dict().get("delivery_tier", 0)))
	_on_loose_logs_changed(_run.loose_log_count())


func _refresh_profile() -> void:
	var level := 1
	var progress := 0.0
	if _run != null:
		level = _xp_level_up_hold_level if _xp_level_up_hold_level > 0 \
			else _run.get_level_for_xp(_displayed_xp_total)
		progress = 1.0 if _xp_level_up_hold_level > 0 \
			else _run.get_level_progress_for_xp(_displayed_xp_total)
	if _xp_label != null:
		_xp_label.text = "Level %d" % level
	if _xp_progress != null:
		_xp_progress.value = progress
	_on_home_cash_changed(GameState.get_home_cash())


func _on_cash_changed(amount: int) -> void:
	if _pending_coin_count == 0 or amount <= _displayed_cash:
		_displayed_cash = maxi(0, amount)
		_cash_label.text = _format_grouped_number(_displayed_cash)


func _on_coin_batch_started(count: int) -> void:
	_pending_coin_count += maxi(0, count)


func _on_coin_collected(amount: int, _tier: int = 0) -> void:
	_pending_coin_count = maxi(0, _pending_coin_count - 1)
	if _run == null:
		return
	_displayed_cash = mini(_run.get_cash(), _displayed_cash + maxi(0, amount))
	_cash_label.text = _format_grouped_number(_displayed_cash)


func _on_coins_cancelled(count: int) -> void:
	_pending_coin_count = maxi(0, _pending_coin_count - maxi(0, count))
	if _pending_coin_count == 0 and _run != null:
		_displayed_cash = _run.get_cash()
		_cash_label.text = _format_grouped_number(_displayed_cash)


func _on_coin_batch_finished() -> void:
	if _pending_coin_count == 0 and _run != null:
		_displayed_cash = _run.get_cash()
		_cash_label.text = _format_grouped_number(_displayed_cash)


func _on_home_cash_changed(amount: int) -> void:
	if _bank_label != null:
		_bank_label.text = "BANK %s · LOCKED" % _format_grouped_number(
			maxi(0, amount))


func _on_run_clock_changed(ms: int) -> void:
	_clock_label.text = "RUN  %s" % _format_time(ms)


func _on_stage_time_changed(remaining_ms: int) -> void:
	if _stage_label == null:
		return
	if _run != null and _run.phase == RunDirector.Phase.OVERFLOW:
		_stage_label.text = "YARD ONE · ENDLESS"
		return
	_stage_label.text = "YARD ONE · %s" % _format_countdown(remaining_ms)


func _on_delivery_changed(seconds_left: float, tier: int) -> void:
	var batch_size := 1
	if _run != null and _run.has_method("delivery_batch_size"):
		batch_size = maxi(1, int(_run.call("delivery_batch_size")))
	_delivery_label.text = "Next %.1fs%s · T%d" % [maxf(0.0, seconds_left),
		" ×%d" % batch_size if batch_size > 1 else "", tier + 1]


func _on_loose_logs_changed(count: int) -> void:
	_loose_label.text = "Loose %d" % count


func _on_boss_stack_changed(display_name: String, remaining_logs: int) -> void:
	if _boss_stack_label == null:
		return
	_boss_stack_label.visible = remaining_logs > 0
	_boss_stack_label.text = "%s · %d LOG%s" % [
		display_name.to_upper(), remaining_logs,
		"" if remaining_logs == 1 else "S"] if remaining_logs > 0 else ""


func _on_boundary_warning_changed(log_id: StringName, seconds_left: float) -> void:
	if seconds_left < 0.0:
		_warning_times.erase(log_id)
		if log_id == _earliest_warning_id:
			_recalculate_earliest_warning()
	else:
		_warning_times[log_id] = seconds_left
		if _earliest_warning_id == &"" or log_id == _earliest_warning_id \
				or seconds_left < _earliest_warning_seconds:
			_earliest_warning_id = log_id
			_earliest_warning_seconds = seconds_left
	_refresh_boundary_warning_label()


func _recalculate_earliest_warning() -> void:
	_earliest_warning_id = &""
	_earliest_warning_seconds = INF
	for raw_id: Variant in _warning_times:
		var seconds := float(_warning_times[raw_id])
		if seconds < _earliest_warning_seconds:
			_earliest_warning_id = StringName(raw_id)
			_earliest_warning_seconds = seconds


func _refresh_boundary_warning_label() -> void:
	_danger_label.text = "" if is_inf(_earliest_warning_seconds) \
		else "BOUNDARY  %.1f" % _earliest_warning_seconds
	_danger_label.modulate = Color.WHITE if is_inf(_earliest_warning_seconds) \
		else Color(1.0, 0.25, 0.18, 1.0)


func _on_phase_changed(phase: RunDirector.Phase) -> void:
	if phase == RunDirector.Phase.ACTIVE or phase == RunDirector.Phase.OVERFLOW:
		_result_backdrop.hide()
		_modal_backdrop.hide()
		_panel_kind = &""
		_warning_times.clear()
		_earliest_warning_id = &""
		_earliest_warning_seconds = INF
		_danger_label.text = ""
		_on_stage_time_changed(0 if phase == RunDirector.Phase.OVERFLOW \
			else (_run.stage_remaining_ms() if _run != null else 0))


func _on_stage_cleared(clear_ms: int) -> void:
	_result_backdrop.show()
	_result_title.text = "YARD ONE CLEARED"
	_result_stats.text = "Stage time  %s\nBank the full purse now, or keep this attempt alive in endless play." % _format_time(clear_ms)
	_result_primary.visible = true
	_result_secondary.visible = true
	_result_primary.text = "CONTINUE ENDLESS"
	_result_secondary.text = "BANK & GO HOME"
	_clear_button_connections(_result_primary)
	_clear_button_connections(_result_secondary)
	_result_primary.pressed.connect(_continue_overflow)
	_result_secondary.pressed.connect(_cash_out_stage)
	_result_primary.grab_focus.call_deferred()


func _on_attempt_finished(results: Dictionary) -> void:
	_result_backdrop.show()
	var result_kind := String(results.get("result_kind", "failure"))
	_result_title.text = "RUN BANKED" if result_kind == "cash_out" \
		else "THE YARD WAS OVERRUN"
	var overflow_ms := int(results.get("overflow_ms", -1))
	var bank: Variant = results.get("bank_receipt", {})
	var banked := int((bank as Dictionary).get("cash_banked", 0)) \
		if bank is Dictionary else 0
	_result_stats.text = "Run time  %s\nLevel  %d · Roots completed  %d\nPeak loose logs  %d\nSession cash transferred  %s%s" % [
		_format_time(int(results.get("total_ms", 0))),
		int(results.get("level", 1)), int(results.get("manual_clears", 0)),
		int(results.get("peak_loose_logs", 0)),
		_format_grouped_number(banked),
		"\nEndless time  %s" % _format_time(overflow_ms) if overflow_ms >= 0 else "",
	]
	_result_primary.visible = true
	_result_secondary.visible = false
	_result_primary.text = "GO HOME"
	_clear_button_connections(_result_primary)
	_clear_button_connections(_result_secondary)
	_result_primary.pressed.connect(home_requested.emit)
	_result_primary.grab_focus.call_deferred()


func _continue_overflow() -> void:
	if _run != null and _run.continue_endless():
		_result_backdrop.hide()


func _cash_out_stage() -> void:
	if _run != null:
		_run.cash_out_stage()


func _clear_button_connections(button: Button) -> void:
	for connection: Dictionary in button.pressed.get_connections():
		button.pressed.disconnect(connection.callable)


func _on_run_xp_changed(total: int) -> void:
	if total < _displayed_xp_total:
		_reset_xp_presentation(total)
		return
	# A gameplay award emits this before its orb batch in the same transaction.
	# Defer the no-receipt fallback so the bar never flashes ahead for one frame.
	_settle_unbatched_xp.call_deferred()


func _on_run_identity_changed(run_id: StringName) -> void:
	_pending_coin_count = 0
	_displayed_cash = 0 if _run == null else _run.get_cash()
	if _cash_label != null:
		_cash_label.text = _format_grouped_number(_displayed_cash)
	_reset_xp_presentation(0 if _run == null else _run.get_xp())
	if run_id == &"":
		_set_offer_presentation_active(false)


func _on_xp_orb_batch_started(amount: int) -> void:
	if amount <= 0 or _run == null:
		return
	var was_idle := _pending_orb_xp == 0 and not _xp_delivery_animating
	_pending_orb_xp += amount
	_inflight_orb_xp += amount
	if was_idle:
		_displayed_xp_total = maxi(0, _run.get_xp() - _pending_orb_xp)
		_displayed_level = _run.get_level_for_xp(_displayed_xp_total)
		_refresh_profile()


func _on_xp_orb_collected(amount: int, _tier: int = 0) -> void:
	var delivered := clampi(amount, 0, _inflight_orb_xp)
	if delivered <= 0:
		return
	_inflight_orb_xp -= delivered
	_xp_delivery_queue.append(delivered)
	if not _xp_delivery_flush_queued:
		_xp_delivery_flush_queued = true
		_process_xp_delivery_queue.call_deferred()


func _process_xp_delivery_queue() -> void:
	_xp_delivery_flush_queued = false
	if _run == null or _xp_delivery_animating or _xp_delivery_queue.is_empty():
		return
	_xp_delivery_animating = true
	var generation := _xp_delivery_generation
	while not _xp_delivery_queue.is_empty():
		var amount: int = _xp_delivery_queue.pop_front()
		while amount > 0:
			var old_level := _run.get_level_for_xp(_displayed_xp_total)
			var to_boundary := _run.get_xp_to_next_level_for_xp(
				_displayed_xp_total)
			if amount < to_boundary:
				_displayed_xp_total += amount
				_pending_orb_xp = maxi(0, _pending_orb_xp - amount)
				amount = 0
				_refresh_profile()
				continue
			_displayed_xp_total += to_boundary
			_pending_orb_xp = maxi(0, _pending_orb_xp - to_boundary)
			amount -= to_boundary
			_xp_level_up_hold_level = old_level
			_refresh_profile()
			await get_tree().create_timer(_level_up_bar_hold_seconds()).timeout
			if generation != _xp_delivery_generation or not is_inside_tree():
				return
			_xp_level_up_hold_level = 0
			_present_displayed_level(old_level + 1)
	if generation != _xp_delivery_generation:
		return
	_xp_delivery_animating = false
	if _pending_orb_xp == 0 and _inflight_orb_xp == 0:
		var authoritative := _run.get_xp()
		_present_unbatched_levels(authoritative)
		_displayed_xp_total = authoritative
	_refresh_profile()


func _settle_unbatched_xp() -> void:
	if _run == null or _pending_orb_xp > 0 or _inflight_orb_xp > 0 \
			or _xp_delivery_animating or not _xp_delivery_queue.is_empty():
		return
	var authoritative := _run.get_xp()
	_present_unbatched_levels(authoritative)
	_displayed_xp_total = authoritative
	_refresh_profile()


func _present_unbatched_levels(total: int) -> void:
	if _run == null:
		return
	var new_level := _run.get_level_for_xp(total)
	for level: int in range(_displayed_level + 1, new_level + 1):
		displayed_level_gained.emit(level)
	_displayed_level = new_level


func _present_displayed_level(level: int) -> void:
	_displayed_level = maxi(_displayed_level, level)
	_refresh_profile()
	displayed_level_gained.emit(level)


func _reset_xp_presentation(total: int) -> void:
	_xp_delivery_generation += 1
	_pending_orb_xp = 0
	_inflight_orb_xp = 0
	_xp_delivery_queue.clear()
	_xp_delivery_animating = false
	_xp_delivery_flush_queued = false
	_xp_level_up_hold_level = 0
	_displayed_xp_total = maxi(0, total)
	_displayed_level = 1 if _run == null \
		else _run.get_level_for_xp(_displayed_xp_total)
	_refresh_profile()


func _level_up_bar_hold_seconds() -> float:
	var pacing := GameConfig.current().xp_pacing
	return 0.15 if pacing == null else maxf(0.0,
		pacing.level_up_bar_hold_seconds)


func displayed_xp_total() -> int:
	return _displayed_xp_total


func displayed_level() -> int:
	return _displayed_level


func displayed_cash_total() -> int:
	return _displayed_cash


func pending_coin_count() -> int:
	return _pending_coin_count


## Normalized window coordinate of the live fill edge. XPOrb maps it into the
## 3D SubViewport before projecting onto a plane in front of its camera.
func xp_orb_target_normalized() -> Vector2:
	if _xp_progress == null:
		return Vector2(0.5, 0.0)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.0)
	var rect := _xp_progress.get_global_rect()
	var span := maxf(_xp_progress.max_value - _xp_progress.min_value, 0.0001)
	var progress := clampf(
		(_xp_progress.value - _xp_progress.min_value) / span, 0.0, 1.0)
	var inset := minf(4.0, rect.size.x * 0.5)
	var target := Vector2(
		lerpf(rect.position.x + inset, rect.end.x - inset, progress),
		rect.position.y + rect.size.y * 0.5)
	return Vector2(target.x / viewport_size.x, target.y / viewport_size.y)


## Normalized centre of the prominent session-cash counter. CoinRewardPool maps
## this into its 3D viewport exactly as XPOrb maps the live bar edge.
func coin_target_normalized() -> Vector2:
	if _cash_label == null:
		return Vector2(0.02, 0.07)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.02, 0.07)
	var rect := _cash_label.get_global_rect()
	var target := rect.position + rect.size * 0.5
	return Vector2(target.x / viewport_size.x, target.y / viewport_size.y)


func _body(text: String) -> Label:
	var label := _label(text, 14, _INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", _INK)
	button.add_theme_color_override("font_hover_color", Color(0.08, 0.055, 0.03, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.08, 0.055, 0.03, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.24, 0.21, 0.17, 0.86))
	button.add_theme_stylebox_override("normal",
		_panel_style(Color(0.86, 0.76, 0.58, 0.96), 6, 1, Color(0.32, 0.22, 0.12, 1.0)))
	button.add_theme_stylebox_override("hover",
		_panel_style(Color(0.96, 0.84, 0.61, 1.0), 6, 2, _RUST))
	button.add_theme_stylebox_override("pressed",
		_panel_style(Color(0.70, 0.56, 0.36, 1.0), 6, 2, _INK))
	var focus := _panel_style(Color.TRANSPARENT, 6, 3, _MENU_GOLD)
	focus.content_margin_left = 0
	focus.content_margin_top = 0
	focus.content_margin_right = 0
	focus.content_margin_bottom = 0
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled",
		_panel_style(Color(0.62, 0.58, 0.49, 0.78), 6, 1, Color(0.35, 0.31, 0.25, 0.72)))
	return button


func _panel_style(color: Color, radius: int, border: int,
		border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


func _power_slot_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _panel_style(color, 5, 2, border_color)
	style.content_margin_left = 4
	style.content_margin_top = 2
	style.content_margin_right = 4
	style.content_margin_bottom = 2
	return style


func _compact_number(value: int) -> String:
	var magnitude: int = absi(value)
	if magnitude >= 1_000_000_000_000:
		return "%.2fT" % (float(value) / 1_000_000_000_000.0)
	if magnitude >= 1_000_000_000:
		return "%.2fB" % (float(value) / 1_000_000_000.0)
	if magnitude >= 1_000_000:
		return "%.2fM" % (float(value) / 1_000_000.0)
	if magnitude >= 1_000:
		return "%.1fK" % (float(value) / 1_000.0)
	return str(value)


func _format_grouped_number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3, 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if negative else "") + digits + grouped


func _format_time(ms: int) -> String:
	if ms < 0:
		return "—"
	var total_seconds := ms / 1000
	return "%02d:%02d.%03d" % [total_seconds / 60, total_seconds % 60, ms % 1000]


func _format_countdown(ms: int) -> String:
	var total_seconds := int(ceil(float(maxi(0, ms)) / 1000.0))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]
