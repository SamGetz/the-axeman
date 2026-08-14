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
const _COIN := preload("res://assets/ui/coin.png")

var _run: RunDirector
var _xp_source: Node
var _panel_kind := &""
var _warning_times: Dictionary = {}
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
var _splitter_installed_shown := false
var _splitter_rank_shown := -1
var _power_slot_labels: Array[Label] = []

var _earth_label: Label
var _cash_label: Label
var _bank_label: Label
var _clock_label: Label
var _loose_label: Label
var _delivery_label: Label
var _xp_label: Label
var _xp_progress: ProgressBar
var _danger_label: Label
var _modal_backdrop: ColorRect
var _modal: PanelContainer
var _modal_title: Label
var _modal_list: VBoxContainer
var _result_backdrop: ColorRect
var _result_title: Label
var _result_stats: Label
var _result_primary: Button
var _result_secondary: Button
var _offer_backdrop: ColorRect
var _offer_title: Label
var _offer_cards: HBoxContainer
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
	GameState.skill_points_changed.connect(_on_profile_ui_changed.unbind(1))
	GameState.skill_level_changed.connect(_on_profile_ui_changed.unbind(2))
	GameState.selected_species_changed.connect(_on_profile_ui_changed.unbind(1))
	GameState.species_purchased.connect(_on_profile_ui_changed.unbind(1))
	GameState.building_tiers_changed.connect(_on_profile_ui_changed)
	GameState.home_cash_changed.connect(_on_home_cash_changed)
	_displayed_level = 1
	_refresh_profile()


func bind_run_director(run: RunDirector) -> void:
	_run = run
	if _run == null:
		return
	_run.run_identity_changed.connect(_on_run_identity_changed)
	_run.cash_changed.connect(_on_cash_changed)
	_run.xp_changed.connect(_on_run_xp_changed)
	_run.level_choice_changed.connect(_on_level_choice_changed)
	_run.power_slots_changed.connect(_on_power_slots_changed)
	_run.utility_charges_changed.connect(_on_utility_charges_changed)
	_run.earth_changed.connect(_on_earth_changed)
	_run.run_clock_changed.connect(_on_run_clock_changed)
	_run.stage_time_changed.connect(_on_stage_time_changed)
	_run.delivery_changed.connect(_on_delivery_changed)
	_run.loose_logs_changed.connect(_on_loose_logs_changed)
	_run.boundary_warning_changed.connect(_on_boundary_warning_changed)
	_run.powerups_changed.connect(_on_powerups_changed)
	_run.phase_changed.connect(_on_phase_changed)
	_run.stage_cleared.connect(_on_stage_cleared)
	_run.attempt_finished.connect(_on_attempt_finished)
	_run.settlement_failed.connect(show_error)
	_run.splitter_changed.connect(_on_splitter_changed)
	var choice_callback := Callable(_run, "present_level_choice")
	if not displayed_level_gained.is_connected(choice_callback):
		displayed_level_gained.connect(choice_callback)
	_displayed_cash = _run.get_cash()
	_pending_coin_count = 0
	_reset_xp_presentation(_run.get_xp())
	_refresh_run()
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


func begin_tutorial(_fresh: bool) -> void:
	# The survival loop teaches itself through the arrival timer and boundary
	# countdown. Keep this compatibility seam for old launch callers.
	pass


func show_error(message: String) -> void:
	if _run != null:
		_run.pause_attempt()
	if _result_backdrop != null:
		_result_backdrop.hide()
	if _offer_backdrop != null:
		_offer_backdrop.hide()
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
	_earth_label = _label("YARD ONE · 20:00", 13,
		Color(0.82, 0.82, 0.77, 0.96))
	_clock_label = _label("RUN  00:00.000", 13, Color(0.90, 0.82, 0.64, 0.96))
	_earth_label.name = "StageCountdown"
	_clock_label.name = "RunTimer"
	for label: Label in [_earth_label, _clock_label]:
		label.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.035, 1.0))
		label.add_theme_constant_override("outline_size", 4)
		lower_left.add_child(label)

	_danger_label = _label("", 28, Color.WHITE)
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.position = Vector2(440, 26)
	_danger_label.size = Vector2(400, 54)
	_danger_label.add_theme_color_override("font_outline_color", Color(0.25, 0, 0, 1))
	_danger_label.add_theme_constant_override("outline_size", 8)
	_danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_label)

	var power_slots := HBoxContainer.new()
	power_slots.name = "RunPowerSlots"
	power_slots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	power_slots.position = Vector2(-300, -132)
	power_slots.size = Vector2(600, 52)
	power_slots.add_theme_constant_override("separation", 6)
	power_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_slots)
	for index: int in range(RunDirector.MAX_RUN_POWER_SLOTS):
		var slot := PanelContainer.new()
		slot.name = "PowerSlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(95, 50)
		slot.add_theme_stylebox_override("panel", _panel_style(
			Color(0.12, 0.09, 0.055, 0.80), 5, 1,
			Color(0.65, 0.52, 0.30, 0.75)))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		power_slots.add_child(slot)
		var slot_label := _label("EMPTY", 11, Color(0.72, 0.66, 0.55, 0.95))
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(slot_label)
		_power_slot_labels.append(slot_label)


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
	_modal_backdrop.color = Color(0.035, 0.025, 0.02, 0.72)
	_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_modal_backdrop)
	_modal = PanelContainer.new()
	_modal.name = "ManagementPanel"
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.position = Vector2(-330, -275)
	_modal.size = Vector2(660, 550)
	_modal.add_theme_stylebox_override("panel", _panel_style(_CREAM, 16, 3, _INK))
	_modal_backdrop.add_child(_modal)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_modal.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	_modal_title = _label("", 26, _INK)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_modal_title)
	var close := _button("CLOSE")
	close.pressed.connect(_close_panel)
	header.add_child(close)
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
	_result_backdrop.color = Color(0.035, 0.018, 0.012, 0.86)
	_result_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-290, -220)
	panel.size = Vector2(580, 440)
	panel.add_theme_stylebox_override("panel", _panel_style(_CREAM, 18, 4, _RUST))
	_result_backdrop.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	_result_title = _label("", 34, _INK)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_title)
	_result_stats = _label("", 18, _INK)
	_result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_stats)
	_result_primary = _button("GO HOME")
	_result_primary.custom_minimum_size.y = 52
	column.add_child(_result_primary)
	_result_secondary = _button("CONTINUE ENDLESS")
	_result_secondary.custom_minimum_size.y = 48
	column.add_child(_result_secondary)
	_result_backdrop.hide()


func _build_power_offer() -> void:
	_offer_backdrop = ColorRect.new()
	_offer_backdrop.name = "RunPowerOffer"
	_offer_backdrop.color = Color(0.025, 0.018, 0.012, 0.86)
	_offer_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offer_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_offer_backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-590, -285)
	panel.size = Vector2(1180, 570)
	panel.add_theme_stylebox_override("panel", _panel_style(
		Color(0.94, 0.88, 0.74, 0.985), 18, 4, Color(0.30, 0.19, 0.09, 1.0)))
	_offer_backdrop.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_offer_title = _label("LEVEL UP — CHOOSE ONE", 30, _INK)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_offer_title)
	var subtitle := _label(
		"A temporary power for this attempt. You can carry six.", 15, _INK)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_offer_cards = HBoxContainer.new()
	_offer_cards.name = "Cards"
	_offer_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_offer_cards.add_theme_constant_override("separation", 10)
	column.add_child(_offer_cards)
	var utilities := HBoxContainer.new()
	utilities.alignment = BoxContainer.ALIGNMENT_CENTER
	utilities.add_theme_constant_override("separation", 12)
	column.add_child(utilities)
	_offer_reroll = _button("REROLL")
	_offer_reroll.custom_minimum_size = Vector2(180, 44)
	_offer_reroll.pressed.connect(_on_offer_reroll_pressed)
	utilities.add_child(_offer_reroll)
	_offer_charges = _label("Rerolls 0 · Banishes 0", 14, _INK)
	utilities.add_child(_offer_charges)
	_offer_backdrop.hide()


func _on_level_choice_changed(offer: Dictionary) -> void:
	if _offer_backdrop == null:
		return
	if offer.is_empty():
		_offer_backdrop.hide()
		return
	_offer_title.text = "LEVEL %d — CHOOSE ONE" % int(offer.get("level", 1))
	for child: Node in _offer_cards.get_children():
		child.queue_free()
	var raw_cards: Variant = offer.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary:
				_offer_cards.add_child(_build_power_card(raw_card as Dictionary))
	_offer_backdrop.show()


func _build_power_card(card: Dictionary) -> Control:
	var rarity := int(card.get("rarity", RunPowerDef.Rarity.COMMON))
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(265, 365)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.add_theme_stylebox_override("panel", _panel_style(
		Color(0.985, 0.95, 0.85, 1.0), 12, 3, _rarity_color(rarity)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card_panel.add_child(column)
	var icon_path := String(card.get("icon_path", ""))
	if not icon_path.is_empty():
		var texture := load(icon_path) as Texture2D
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(76, 76)
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			column.add_child(icon)
	var rarity_label := _label(_rarity_name(rarity), 13, _rarity_color(rarity))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rarity_label)
	var name_label := _label(String(card.get("display_name", "Power")), 21, _INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var rank_cap := int(card.get("rank_cap", 1))
	var rank_text := "Cash +%s" % _format_grouped_number(int(card.get("cash", 0))) \
		if StringName(card.get("id", "")) == RunDirector.PAYDAY_POWER_ID \
		else "Rank %d / %d" % [int(card.get("next_rank", 1)), rank_cap]
	var rank_label := _label(rank_text, 14, _RUST)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rank_label)
	var description := _body(String(card.get("description", "")))
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(description)
	var choose := _button("CHOOSE")
	choose.custom_minimum_size.y = 46
	choose.pressed.connect(_on_offer_choose_pressed.bind(
		StringName(card.get("id", ""))))
	column.add_child(choose)
	var banish := _button("BANISH")
	banish.name = "BanishButton"
	banish.custom_minimum_size.y = 34
	var current_cards: Array = [] if _run == null \
		else _run.get_current_offer().get("cards", [])
	var cannot_banish := StringName(card.get("id", "")) \
		== RunDirector.PAYDAY_POWER_ID or current_cards.size() <= 1
	banish.set_meta("cannot_banish", cannot_banish)
	var charges := {} if _run == null else _run.get_utility_charges()
	banish.disabled = cannot_banish or int(charges.get("banishes", 0)) <= 0
	banish.pressed.connect(_on_offer_banish_pressed.bind(
		StringName(card.get("id", ""))))
	column.add_child(banish)
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
	for index: int in range(_power_slot_labels.size()):
		var label := _power_slot_labels[index]
		if index >= slots.size():
			label.text = "EMPTY"
			label.tooltip_text = "Empty run-power slot"
			continue
		var power_id := StringName(slots[index])
		var definition := SurvivorsContent.run_powers().by_id(power_id)
		var rank := int(ranks.get(String(power_id), ranks.get(power_id, 0)))
		label.text = "%s\nR%d" % [
			String(power_id) if definition == null else definition.display_name, rank]
		label.tooltip_text = "" if definition == null else definition.description


func _rarity_name(rarity: int) -> String:
	match rarity:
		RunPowerDef.Rarity.RARE:
			return "RARE"
		RunPowerDef.Rarity.EPIC:
			return "EPIC"
	return "COMMON"


func _rarity_color(rarity: int) -> Color:
	match rarity:
		RunPowerDef.Rarity.RARE:
			return Color(0.18, 0.43, 0.72, 1.0)
		RunPowerDef.Rarity.EPIC:
			return Color(0.55, 0.22, 0.67, 1.0)
	return Color(0.34, 0.48, 0.24, 1.0)


func _open_panel(kind: StringName) -> void:
	if _run == null or not _run.has_live_attempt():
		return
	_run.pause_attempt()
	_panel_kind = kind
	_modal_backdrop.show()
	_rebuild_panel()


func _close_panel() -> void:
	_modal_backdrop.hide()
	_panel_kind = &""
	if _run != null:
		_run.resume_attempt()


func _rebuild_panel() -> void:
	for child: Node in _modal_list.get_children():
		child.queue_free()
	_modal_title.text = "ATTEMPT PAUSED"
	_build_pause_panel()


func _build_shop_panel() -> void:
	_modal_list.add_child(_body(
		"Permanent upgrades are bought with banked cash from Home. Session cash "
		+ "cannot be spent during a run."))


func _build_skills_panel() -> void:
	_modal_list.add_child(_body(
		"The permanent skill tree is retired. Run powers arrive through level-up "
		+ "choices in the next gated slice."))


func _build_woods_panel() -> void:
	_modal_list.add_child(_body(
		"Yard one now owns its six-species timeline. Woods are not purchased or "
		+ "selected during a run."))


func _build_pause_panel() -> void:
	_modal_list.add_child(_body("All hazards, physics, chopping, and the run clock are paused while a menu is open."))
	_modal_list.add_child(_body(
		"Starting fall frequency is selected at Home and is locked for this run."))
	_modal_list.add_child(_section("SAVE & EXIT"))
	var suspend := _button("SUSPEND THIS ATTEMPT")
	suspend.tooltip_text = "Normalises active animations, saves the exact cut journal, and returns to the title."
	suspend.pressed.connect(suspend_requested.emit)
	_modal_list.add_child(suspend)
	var abandon := _button("ABANDON ATTEMPT")
	abandon.add_theme_color_override("font_color", _RUST)
	abandon.pressed.connect(abandon_requested.emit)
	_modal_list.add_child(abandon)


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
	var p := _run.get_powerup_state()
	_on_powerups_changed(int(p.get("slow_charges", 0)), int(p.get("blaster_ammo", 0)),
		float(p.get("slow_seconds_left", 0.0)))


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


func _on_earth_changed(_remaining: int, _cleared: int) -> void:
	# The signal remains for old attempt fixtures; stage time owns this surface.
	pass


func _on_run_clock_changed(ms: int) -> void:
	_clock_label.text = "RUN  %s" % _format_time(ms)


func _on_stage_time_changed(remaining_ms: int) -> void:
	if _earth_label == null:
		return
	if _run != null and _run.phase == RunDirector.Phase.OVERFLOW:
		_earth_label.text = "YARD ONE · ENDLESS"
		return
	_earth_label.text = "YARD ONE · %s" % _format_countdown(remaining_ms)


func _on_delivery_changed(seconds_left: float, tier: int) -> void:
	_delivery_label.text = "Next %.1fs · T%d" % [maxf(0.0, seconds_left), tier + 1]


func _on_loose_logs_changed(count: int) -> void:
	_loose_label.text = "Loose %d" % count


func _on_boundary_warning_changed(log_id: StringName, seconds_left: float) -> void:
	if seconds_left < 0.0:
		_warning_times.erase(log_id)
	else:
		_warning_times[log_id] = seconds_left
	var earliest := INF
	for value: Variant in _warning_times.values():
		earliest = minf(earliest, float(value))
	_danger_label.text = "" if is_inf(earliest) else "BOUNDARY  %.1f" % earliest
	_danger_label.modulate = Color.WHITE if is_inf(earliest) else Color(1.0, 0.25, 0.18, 1.0)


func _on_powerups_changed(_slow_charges: int, _blaster_ammo: int,
		_slow_seconds: float) -> void:
	# Retired Slow Time/right-click ammunition no longer owns a HUD row. Keep the
	# transitional signal callback inert until those old RunDirector fields leave.
	pass


func _on_splitter_changed(_installed: bool, _rank: int, _seconds: float) -> void:
	if _installed == _splitter_installed_shown and _rank == _splitter_rank_shown:
		return
	_splitter_installed_shown = _installed
	_splitter_rank_shown = _rank
	if _panel_kind == &"shop":
		_rebuild_panel()


func _on_phase_changed(phase: RunDirector.Phase) -> void:
	if phase == RunDirector.Phase.ACTIVE or phase == RunDirector.Phase.OVERFLOW:
		_result_backdrop.hide()
		_modal_backdrop.hide()
		_panel_kind = &""
		_warning_times.clear()
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


func _continue_overflow() -> void:
	if _run != null and _run.continue_endless():
		_result_backdrop.hide()


func _cash_out_stage() -> void:
	if _run != null:
		_run.cash_out_stage()


func _clear_button_connections(button: Button) -> void:
	for connection: Dictionary in button.pressed.get_connections():
		button.pressed.disconnect(connection.callable)


func _on_profile_ui_changed() -> void:
	_refresh_profile()
	if _panel_kind != &"":
		_rebuild_panel()


func _on_run_xp_changed(total: int) -> void:
	if total < _displayed_xp_total:
		_reset_xp_presentation(total)
		return
	# A gameplay award emits this before its orb batch in the same transaction.
	# Defer the no-receipt fallback so the bar never flashes ahead for one frame.
	_settle_unbatched_xp.call_deferred()


func _on_run_identity_changed(_run_id: StringName) -> void:
	_pending_coin_count = 0
	_displayed_cash = 0 if _run == null else _run.get_cash()
	if _cash_label != null:
		_cash_label.text = _format_grouped_number(_displayed_cash)
	_reset_xp_presentation(0 if _run == null else _run.get_xp())


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


func _section(text: String) -> Label:
	var label := _label(text, 16, _RUST)
	label.add_theme_constant_override("outline_size", 0)
	return label


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
	button.add_theme_color_override("font_disabled_color", Color(0.24, 0.21, 0.17, 0.86))
	button.add_theme_stylebox_override("normal",
		_panel_style(Color(0.86, 0.76, 0.58, 0.96), 6, 1, Color(0.32, 0.22, 0.12, 1.0)))
	button.add_theme_stylebox_override("hover",
		_panel_style(Color(0.96, 0.84, 0.61, 1.0), 6, 2, _RUST))
	button.add_theme_stylebox_override("pressed",
		_panel_style(Color(0.70, 0.56, 0.36, 1.0), 6, 2, _INK))
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
