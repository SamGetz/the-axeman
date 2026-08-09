extends Node
## Phase-1 reward planner and generated-audio contract.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== REWARD + AUDIO PHASE 1 ACCEPTANCE ===")
	_test_reward_plans()
	_test_audio_catalogue()
	_test_audio_world_registration()
	print("=== REWARD + AUDIO RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL REWARD + AUDIO PHASE 1 CRITERIA PASS ===")
	get_tree().quit()


func _test_reward_plans() -> void:
	var config := GameConfig.current().reward_bursts
	_check(config != null and config.validate().is_empty(),
		"the four-tier reward configuration validates")
	for kind: int in [RewardBurstConfig.Kind.XP,
			RewardBurstConfig.Kind.CASH]:
		var thresholds := config.xp_tier_thresholds if kind == RewardBurstConfig.Kind.XP \
			else config.cash_tier_thresholds
		for tier in range(4):
			var amount: int = thresholds[tier]
			var tokens := config.plan_tokens(kind, amount, mini(amount, 32))
			var total := 0
			var highest := 0
			for token: Dictionary in tokens:
				total += int(token.amount)
				highest = maxi(highest, int(token.tier))
			_check(total == amount and tokens.size() <= 32,
				"%s tier %d reconciles exactly inside the visual cap" % [
					"XP" if kind == RewardBurstConfig.Kind.XP else "cash", tier])
			_check(highest == tier, "tier %d visibly introduces its authored representation" % tier)
	var huge := 1_000_000_000_000_000_000
	var huge_tokens := config.plan_tokens(RewardBurstConfig.Kind.CASH, huge, 40)
	var huge_total := 0
	for token: Dictionary in huge_tokens:
		huge_total += int(token.amount)
	_check(huge_total == huge and huge_tokens.size() == 40,
		"the safe campaign maximum folds into forty exact bounded tokens")


func _test_audio_catalogue() -> void:
	_check(not AudioDirector.debug_session_active(),
		"audio remains gated during fixture/startup state")
	var file := FileAccess.open("res://data/sound_manifest.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary and String(parsed.get("tuning_status", "")).begins_with(
		"PLACEHOLDER"), "the audio manifest retains an explicit provisional label")
	var cues: Dictionary = parsed.get("cues", {}) if parsed is Dictionary else {}
	_check(cues.size() >= 29 and AudioDirector.debug_cue_count() == cues.size(),
		"AudioDirector loads the complete Phase-1 cue catalogue")
	var missing := PackedStringArray()
	var variation_count := 0
	for cue_id: String in cues:
		var cue: Dictionary = cues[cue_id]
		for path: String in cue.get("variations", []):
			variation_count += 1
			if not FileAccess.file_exists(path):
				missing.append(path)
	_check(missing.is_empty(), "every generated cue variation exists")
	_check(AudioDirector.debug_preloaded_stream_count() == variation_count,
		"every authored stream is resident before the first gameplay event")
	for bus_name in [&"SFX", &"SFX/World", &"SFX/Rewards", &"SFX/UI",
			&"SFX/Machinery", &"Ambience"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "%s mixer bus exists" % bus_name)


func _test_audio_world_registration() -> void:
	var viewport := SubViewport.new()
	viewport.name = "AudioWorldTestViewport"
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	var world_root := Node3D.new()
	viewport.add_child(world_root)
	AudioDirector.register_world_root(world_root)
	_check(AudioDirector.debug_world_root_registered(),
		"a positional audio world can be registered")
	_check(AudioDirector.debug_world_voice_viewport() == viewport,
		"pooled positional voices share the chopping SubViewport listener world")
	AudioDirector.begin_session()
	var split_before := AudioDirector.debug_started_event_count(&"wood_split")
	var split_started := AudioDirector.play_world(&"wood_split", Vector3.ZERO)
	_check(split_started
		and AudioDirector.debug_started_event_count(&"wood_split") == split_before + 1,
		"successful splits use a listener-independent impact cue")
	var before := AudioDirector.debug_started_event_count(&"wood_thud")
	var all_started := true
	for _event in range(5):
		all_started = AudioDirector.play_world(&"wood_thud", Vector3.ZERO) and all_started
	_check(AudioDirector.debug_playing_3d_voice_count() == 4,
		"rapid failed-chop cues stay inside their authored positional polyphony")
	_check(all_started
		and AudioDirector.debug_started_event_count(&"wood_thud") == before + 5,
		"rapid authored events retrigger the oldest voice instead of silently dropping SFX")
	AudioDirector.end_session()
	AudioDirector.unregister_world_root(world_root)
	_check(not AudioDirector.debug_world_root_registered(),
		"the positional audio world unregisters cleanly on scene exit")
	viewport.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
