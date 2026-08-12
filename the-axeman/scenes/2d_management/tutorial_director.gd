class_name TutorialDirector
extends Control
## Persisted, state-observing tutorial presentation. It never grants cash, XP,
## items or progression and never reveals a feature before its public gate.

## Tutorial content remains in the project for a future opt-in pass, but live
## presentation is deliberately disabled.
const ENABLED := false
const _CONTENT := preload("res://data/tutorial_content.tres")
const _ARMED_ID := &"tutorial_armed"
const _STARTED_ID := &"tutorial_started"
const _OPENING_COMPLETE_ID := &"tutorial_opening_complete"
const _SKIPPED_ID := &"tutorial_all_skipped"
const _BEAT_PREFIX := "tutorial_beat_"

@onready var _panel: PanelContainer = $Card
@onready var _portrait: TextureRect = $Card/Margin/Row/PortraitFrame/Portrait
@onready var _speaker: Label = $Card/Margin/Row/Copy/Speaker
@onready var _role: Label = $Card/Margin/Row/Copy/Role
@onready var _title: Label = $Card/Margin/Row/Copy/Title
@onready var _dialogue: Label = $Card/Margin/Row/Copy/Dialogue
@onready var _objective: Label = $Card/Margin/Row/Copy/Objective
@onready var _continue_button: Button = $Card/Margin/Row/Copy/Actions/Continue
@onready var _close_button: Button = $Card/Margin/Row/Copy/Actions/Close
@onready var _skip_button: Button = $Card/Margin/Row/Copy/Actions/Skip
@onready var _help_button: Button = $HelpButton
@onready var _focus_ring: Panel = $FocusRing

var _content: TutorialTable = _CONTENT
var _hud: Control
var _active: TutorialBeatDef
var _opening: Array[TutorialBeatDef] = []
var _opening_index := -1
var _running := false
var _replaying := false
var _armed := false
var _focus_tween: Tween
var _show_timer: Timer
var _active_is_pending := false


func _ready() -> void:
	_panel.hide()
	_focus_ring.hide()
	_help_button.hide()
	if not ENABLED:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hide()
		return
	_show_timer = Timer.new()
	_show_timer.one_shot = true
	_show_timer.timeout.connect(_present_active_beat)
	add_child(_show_timer)
	_continue_button.pressed.connect(_on_continue_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_help_button.pressed.connect(_on_help_pressed)
	GameState.earth_trees_changed.connect(_on_progress_changed.unbind(2))
	GameState.manual_log_progress_changed.connect(_on_progress_changed.unbind(2))
	GameState.cash_changed.connect(_on_progress_changed.unbind(1))
	GameState.lifetime_cash_earned_changed.connect(_on_progress_changed.unbind(1))
	GameState.xp_changed.connect(_on_progress_changed.unbind(1))
	GameState.skill_points_changed.connect(_on_progress_changed.unbind(1))
	GameState.order_state_changed.connect(_on_progress_changed)
	GameState.building_tiers_changed.connect(_on_progress_changed)
	GameState.species_purchased.connect(_on_progress_changed.unbind(1))
	GameState.splitter_assignment_changed.connect(_on_progress_changed.unbind(1))
	GameState.regional_network_changed.connect(_on_progress_changed)
	GameState.earth_campaign_changed.connect(_on_progress_changed)
	get_viewport().size_changed.connect(_refresh_focus)


func begin_for_session(is_fresh_game: bool, hud: Control) -> void:
	_hud = hud
	if not ENABLED:
		_running = false
		_replaying = false
		_armed = false
		_active = null
		_hide_card()
		hide()
		return
	_opening = _content.opening_beats()
	if is_fresh_game:
		GameState.mark_feature_introduced(_ARMED_ID)
	_armed = GameState.has_introduced_feature(_ARMED_ID) \
		or GameState.has_introduced_feature(_STARTED_ID)
	if not _armed or GameState.has_introduced_feature(_SKIPPED_ID):
		return
	if not GameState.has_introduced_feature(_STARTED_ID):
		_start_tutorial()
		return
	_running = true
	if not GameState.has_introduced_feature(_OPENING_COMPLETE_ID):
		if _orders_actionable():
			_resume_opening()
		else:
			_hide_card()
			_evaluate_contextual.call_deferred()
	else:
		_hide_card()
		_evaluate_contextual.call_deferred()


func _start_tutorial() -> void:
	if not _armed or _running or GameState.has_introduced_feature(_SKIPPED_ID):
		return
	GameState.mark_feature_introduced(_STARTED_ID)
	_running = true
	if _orders_actionable():
		_resume_opening()
	else:
		_hide_card()
		_evaluate_contextual.call_deferred()


func notify_hud_action(action_id: StringName) -> void:
	if not ENABLED or not _running:
		return
	if _active == null:
		if action_id == &"panel_closed":
			_evaluate_contextual.call_deferred()
		return
	if _active.completion_kind == TutorialBeatDef.CompletionKind.HUD_ACTION \
		and _active.completion_value == action_id:
		_complete_active()


## XP is authoritative before its orbs arrive. YardHUD calls this only when the
## visible bar has caught up, keeping the contextual Skills lesson causal.
func notify_presented_progress_changed() -> void:
	if not ENABLED:
		return
	_on_progress_changed()


func replay_opening() -> void:
	if not ENABLED or _content == null:
		return
	_running = true
	_replaying = true
	_opening = _content.opening_beats()
	_opening_index = 0
	_show_beat(_opening[0] if not _opening.is_empty() else null)


func is_showing_tip() -> bool:
	return _panel.visible


func active_beat_id() -> StringName:
	return &"" if _active == null else _active.id


func content_errors() -> PackedStringArray:
	return _content.validate() if _content != null else PackedStringArray(["tutorial content missing"])


## Deterministic visual-gallery seam. Live tutorial routes always use _show_beat
## and its authored delay; capture tools need a chosen card on a chosen frame.
func debug_present_beat(beat: TutorialBeatDef) -> void:
	if not ENABLED:
		return
	_running = true
	_replaying = false
	_cancel_pending_show()
	_active = beat
	_active_is_pending = beat != null
	_present_active_beat()


func _resume_opening() -> void:
	_opening_index = 0
	while _opening_index < _opening.size() \
		and _is_beat_complete(_opening[_opening_index].id):
		_opening_index += 1
	if _opening_index >= _opening.size():
		_finish_opening()
		return
	_show_beat(_opening[_opening_index])


func _show_beat(beat: TutorialBeatDef) -> void:
	if not ENABLED:
		return
	_cancel_pending_show()
	_active = beat
	if beat == null:
		_hide_card()
		return
	var guide := _content.guide_by_id(beat.guide_id)
	if guide == null:
		_complete_active()
		return
	# Every beat waits after the event that made it relevant. Keeping `_active`
	# assigned during the pause lets fast players complete a now-stale lesson
	# without ever having it pop up after the fact.
	_active_is_pending = true
	_panel.hide()
	_help_button.hide()
	_hide_focus()
	if _content.event_delay_seconds <= 0.0:
		_present_active_beat.call_deferred()
	else:
		_show_timer.start(_content.event_delay_seconds)


func _present_active_beat() -> void:
	if not ENABLED or not _active_is_pending or _active == null or not _running \
			or GameState.has_introduced_feature(_SKIPPED_ID):
		return
	_active_is_pending = false
	var beat := _active
	var guide := _content.guide_by_id(beat.guide_id)
	if guide == null:
		_complete_active()
		return
	_portrait.texture = load(guide.portrait_path) as Texture2D
	_speaker.text = guide.display_name
	_speaker.add_theme_color_override("font_color", guide.accent.lightened(0.28))
	_role.text = guide.role
	_title.text = beat.title
	_dialogue.text = beat.dialogue
	_objective.text = "NEXT  ›  %s" % beat.objective
	_continue_button.text = beat.continue_label
	_continue_button.visible = beat.completion_kind == TutorialBeatDef.CompletionKind.ACKNOWLEDGE
	_skip_button.text = "Close guide" if _replaying else "Skip tutorials"
	_panel.show()
	_help_button.hide()
	_refresh_focus.call_deferred()
	if _condition_satisfied(beat):
		_complete_active.call_deferred()


func _on_continue_pressed() -> void:
	if _active != null and _active.completion_kind == \
			TutorialBeatDef.CompletionKind.ACKNOWLEDGE:
		_complete_active()


func _on_close_pressed() -> void:
	_hide_card()
	_help_button.show()


func _on_help_pressed() -> void:
	if _active != null and not _active_is_pending:
		_panel.show()
		_help_button.hide()
		_refresh_focus.call_deferred()
		return
	replay_opening()


func _on_skip_pressed() -> void:
	_cancel_pending_show()
	if _replaying:
		_replaying = false
		_active = null
		_hide_card()
		return
	GameState.mark_feature_introduced(_SKIPPED_ID)
	_active = null
	_running = false
	_hide_card()


func _complete_active() -> void:
	if _active == null:
		return
	_cancel_pending_show()
	if not _replaying:
		GameState.mark_feature_introduced(_beat_feature_id(_active.id))
	var was_opening := _active.availability_kind == \
		TutorialBeatDef.AvailabilityKind.OPENING
	_active = null
	if was_opening:
		_opening_index += 1
		if _opening_index < _opening.size():
			_show_beat(_opening[_opening_index])
		else:
			if _replaying:
				_replaying = false
				_hide_card()
			else:
				_finish_opening()
	else:
		_hide_card()
		_evaluate_contextual.call_deferred()


func _finish_opening() -> void:
	_cancel_pending_show()
	GameState.mark_feature_introduced(_OPENING_COMPLETE_ID)
	_hide_card()
	_evaluate_contextual.call_deferred()


func _on_progress_changed() -> void:
	if not _running or GameState.has_introduced_feature(_SKIPPED_ID):
		return
	if _active != null and _condition_satisfied(_active):
		_complete_active_if_current.call_deferred(_active.id)
	elif _active == null and not GameState.has_introduced_feature(\
			_OPENING_COMPLETE_ID):
		if _orders_actionable():
			_resume_opening.call_deferred()
		else:
			_evaluate_contextual.call_deferred()
	elif _active == null and GameState.has_introduced_feature(_OPENING_COMPLETE_ID):
		_evaluate_contextual.call_deferred()


func _complete_active_if_current(expected_id: StringName) -> void:
	if _active != null and _active.id == expected_id and _condition_satisfied(_active):
		_complete_active()


func _evaluate_contextual() -> void:
	if not _running or _active != null or _replaying \
			or GameState.has_introduced_feature(_SKIPPED_ID):
		return
	var opening_complete := GameState.has_introduced_feature(_OPENING_COMPLETE_ID)
	for beat: TutorialBeatDef in _content.contextual_beats():
		# The level-2 Skills lesson is intentionally allowed before the level-3
		# Jobs opening. Every other contextual lesson waits for that opening to end.
		if not opening_complete and beat.availability_kind != \
				TutorialBeatDef.AvailabilityKind.SKILL_POINT_AVAILABLE:
			continue
		if not _is_beat_complete(beat.id) and _is_available(beat):
			# A glowing dock/card target cannot be clicked through an open window.
			# Panel-reading beats intentionally omit a focus target and may appear
			# over the panel they explain.
			if beat.focus_target != &"" and _hud_has_open_panel():
				return
			_show_beat(beat)
			return
	if opening_complete:
		_help_button.show()


func _condition_satisfied(beat: TutorialBeatDef) -> bool:
	if beat == null:
		return false
	match beat.completion_kind:
		TutorialBeatDef.CompletionKind.MANUAL_LOG_FINISHED:
			return GameState.get_manual_log_equivalents() > 0
		TutorialBeatDef.CompletionKind.SHOP_AVAILABLE:
			return Shop.is_entry_revealed()
		TutorialBeatDef.CompletionKind.FIRST_UPGRADE_BOUGHT:
			for upgrade: UpgradeDef in Shop.get_upgrades():
				if upgrade != null and Shop.get_level(upgrade.id) > 0:
					return true
			return false
		TutorialBeatDef.CompletionKind.FIRST_ORDER_ACCEPTED:
			return GameState.has_active_manual_job()
		TutorialBeatDef.CompletionKind.FIRST_ORDER_COMPLETED:
			return not GameState.get_completed_order_ids().is_empty()
		TutorialBeatDef.CompletionKind.FIRST_SKILL_SPENT:
			return GameState.get_skill_points_spent() > 0
		TutorialBeatDef.CompletionKind.FIRST_EXTRA_WOOD_OWNED:
			return GameState.get_owned_species().size() > 1
		TutorialBeatDef.CompletionKind.SPLITTER_ASSIGNED:
			return GameState.get_splitter_assigned_species() != &""
		_:
			return false


func _hud_has_open_panel() -> bool:
	if _hud == null:
		return false
	var backdrop := _hud.get_node_or_null("ModalBackdrop") as Control
	return backdrop != null and backdrop.visible


func _orders_actionable() -> bool:
	var button := _target_control(&"orders_button")
	return button != null and button.visible


func _is_available(beat: TutorialBeatDef) -> bool:
	match beat.availability_kind:
		TutorialBeatDef.AvailabilityKind.SKILL_POINT_AVAILABLE:
			return _hud != null and _hud.has_method(
				"displayed_skill_points_earned") \
				and int(_hud.call("displayed_skill_points_earned")) > 0
		TutorialBeatDef.AvailabilityKind.ORDERS_ACTIONABLE:
			return _target_control(&"orders_button") != null \
				and _target_control(&"orders_button").visible
		TutorialBeatDef.AvailabilityKind.CATALOG_ACTIONABLE:
			return _target_control(&"catalog_button") != null \
				and _target_control(&"catalog_button").visible
		TutorialBeatDef.AvailabilityKind.COMMISSIONS_AVAILABLE:
			return Orders.commissions_unlocked()
		TutorialBeatDef.AvailabilityKind.SPLITTER_INSTALLED:
			return MechanicalSplitter.is_installed()
		TutorialBeatDef.AvailabilityKind.ATLAS_ACTIONABLE:
			# Keep the early yard lessons coherent even if the first completed job
			# also earns enough standing to expose Atlas immediately.
			return _is_beat_complete(&"catalog_pick") \
				and _target_control(&"atlas_button") != null \
				and _target_control(&"atlas_button").visible
		TutorialBeatDef.AvailabilityKind.EARTH_DEPLETED:
			return GameState.is_earth_depleted()
		_:
			return false


func _refresh_focus() -> void:
	if _active == null or _active.focus_target == &"":
		_hide_focus()
		return
	var target := _target_control(_active.focus_target)
	if target == null or not target.is_visible_in_tree():
		_hide_focus()
		return
	var rect := target.get_global_rect()
	_show_focus(rect.position - Vector2(6, 6), rect.size + Vector2(12, 12))


func _show_focus(position: Vector2, size: Vector2) -> void:
	_hide_focus()
	_focus_ring.position = position
	_focus_ring.size = size
	_focus_ring.show()
	_focus_tween = create_tween().set_loops()
	_focus_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(_focus_ring, "modulate:a", 0.48, 0.55)
	_focus_tween.tween_property(_focus_ring, "modulate:a", 1.0, 0.55)


func _hide_focus() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null
	_focus_ring.modulate = Color.WHITE
	_focus_ring.hide()


func _target_control(target_id: StringName) -> Control:
	if _hud == null:
		return null
	match target_id:
		&"shop_button": return _hud.get_node_or_null("QuickMenu/ShopButton") as Control
		&"catalog_button": return _hud.get_node_or_null("QuickMenu/TreesButton") as Control
		&"skills_button": return _hud.get_node_or_null("QuickMenu/SkillsButton") as Control
		&"orders_button": return _hud.get_node_or_null("QuickMenu/OrdersButton") as Control
		&"atlas_button": return _hud.get_node_or_null("QuickMenu/AtlasButton") as Control
		&"splitter_card": return _hud.get_node_or_null("SplitterRuntimeCard") as Control
	return null


func _hide_card() -> void:
	_panel.hide()
	_hide_focus()
	if _running and GameState.has_introduced_feature(_OPENING_COMPLETE_ID):
		_help_button.show()


func _cancel_pending_show() -> void:
	if _show_timer != null:
		_show_timer.stop()
	_active_is_pending = false


func _is_beat_complete(beat_id: StringName) -> bool:
	return GameState.has_introduced_feature(_beat_feature_id(beat_id))


func _beat_feature_id(beat_id: StringName) -> StringName:
	return StringName(_BEAT_PREFIX + String(beat_id))
