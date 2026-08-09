extends Node
## Focused acceptance for the presentation contract: XP remains authoritative
## immediately, while the visible level waits for its orb to complete the bar.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== XP DELIVERY ACCEPTANCE ===")
	var level_effect := LevelUpBurst.create_prewarmed(self, 0.4)
	_check(level_effect.find_children(
		"LevelRing*", "MeshInstance3D", true, false).is_empty() \
		and level_effect.find_children(
			"LevelRay*", "MeshInstance3D", true, false).size() == 10 \
		and level_effect.find_children(
			"LevelSpark*", "MeshInstance3D", true, false).size() == 18,
		"the level-up effect keeps rays and sparks without a ground halo ring")
	level_effect.queue_free()
	var xp_pacing := GameConfig.current().xp_pacing
	var original_global_multiplier := xp_pacing.global_xp_multiplier if xp_pacing != null else 1.0
	if xp_pacing != null:
		xp_pacing.global_xp_multiplier = 2.0
	GameState.reset_to_defaults()
	_check(GameState.award_xp(17, &"xp_delivery_acceptance") == 34,
		"the global XP playtest multiplier scales every central XP award")
	if xp_pacing != null:
		xp_pacing.global_xp_multiplier = original_global_multiplier
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var level_one_span := GameState.get_xp_to_next_level_for_xp(0)
	GameState.add_xp(level_one_span - 1)

	var hud: Control = load(
		"res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	var authoritative_levels: Array[int] = []
	var displayed_levels: Array[int] = []
	GameState.level_gained.connect(
		func(level: int) -> void: authoritative_levels.append(level))
	hud.displayed_level_gained.connect(
		func(level: int) -> void: displayed_levels.append(level))
	var bar: ProgressBar = hud.get_node("XPBar/Progress")
	var label: Label = hud.get_node("XPBar/LevelLabel")
	var skills: Button = hud.get_node("QuickMenu/SkillsButton")

	var award := GameState.award_xp(2, &"xp_delivery_acceptance")
	hud._on_xp_orb_batch_started(award)
	await get_tree().process_frame
	_check(GameState.get_level() == 2 and authoritative_levels == [2],
		"earned XP and its level reward are banked immediately")
	_check(label.text.begins_with("Level 1") and displayed_levels.is_empty()
		and not skills.visible,
		"the visible level and Skills unlock remain behind an in-flight orb")

	hud._on_xp_orb_collected(award)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(bar.value, 1.0)
		and label.text.begins_with("Level 1")
		and label.text.contains("0 XP to go")
		and displayed_levels.is_empty(),
		"the arriving orb fills the old level bar completely before rollover")
	_capture_if_rendered("/private/tmp/axeman_xp_bar_full.png")

	await get_tree().create_timer(0.18).timeout
	await get_tree().process_frame
	_check(displayed_levels == [2] and label.text.begins_with("Level 2")
		and label.text.contains("1 pt") and skills.visible,
		"the visible level, reward point, and Skills unlock advance after the full bar")
	_capture_if_rendered("/private/tmp/axeman_xp_level_advanced.png")

	hud.queue_free()
	await get_tree().process_frame
	var to_level_three := GameState.get_xp_to_next_level()
	GameState.add_xp(to_level_three - 1)
	var level_three_hud: Control = load(
		"res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(level_three_hud)
	await get_tree().process_frame
	await get_tree().process_frame
	var jobs: Button = level_three_hud.get_node("QuickMenu/OrdersButton")
	var level_three_label: Label = level_three_hud.get_node("XPBar/LevelLabel")
	var level_three_events: Array[int] = []
	level_three_hud.displayed_level_gained.connect(
		func(level: int) -> void: level_three_events.append(level))
	var level_three_award := GameState.award_xp(2, &"xp_delivery_acceptance")
	level_three_hud._on_xp_orb_batch_started(level_three_award)
	await get_tree().process_frame
	_check(GameState.get_level() == 3 and not jobs.visible,
		"the authoritative level-three Jobs gate remains hidden during orb flight")
	level_three_hud._on_xp_orb_collected(level_three_award)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(level_three_label.text.begins_with("Level 2") and not jobs.visible
		and level_three_events.is_empty(),
		"the level-three gate stays hidden during the completed level-two bar hold")
	await get_tree().create_timer(0.18).timeout
	await get_tree().process_frame
	_check(level_three_events == [3] and jobs.visible,
		"Jobs reveals only after the visible level-three rollover")
	level_three_hud.queue_free()
	print("=== XP DELIVERY RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL XP DELIVERY ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _capture_if_rendered(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	_check(error == OK and image.get_size() == Vector2i(1280, 720),
		"rendered XP timing checkpoint is 1280x720: %s" % path)
