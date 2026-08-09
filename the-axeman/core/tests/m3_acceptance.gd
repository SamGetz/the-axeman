extends Node
## FILE: res://core/tests/m3_acceptance.gd
## ATTACHES TO: the root Node of res://core/tests/m3_acceptance.tscn.
## Run that scene (F6). Not shipped in builds.
##
## Verifies M3 GameFeel:
##   - all global tuning loaded and validated through game_config.tres
##   - A11 hit-pause sets/restores Engine.time_scale
##   - the A11 overlap guard: time_scale never sticks low, always ends at 1.0
##   - trauma add/clamp, strength clamp
##   - camera shake writes h/v offset while trauma > 0, and zeroes on exit
##
## This suite AWAITS real-time timers; run headless with a generous window,
## e.g. --quit-after 10. No deliberate contract violations — any red is real.
## (One EXPECTED push_warning appears in the camera-replacement path.)

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M3 ACCEPTANCE — GameFeel (hit-pause + shake) ===")
	await _test_1_config_loaded()
	await _test_2_pause_sets_time_scale()
	await _test_3_pause_restores_time_scale()
	await _test_4_overlap_guard()
	await _test_5_trauma_clamp()
	await _test_6_camera_shake()
	await _test_7_strength_clamp()
	print("=== M3 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M3 ACCEPTANCE CRITERIA PASS ===")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


## Real-time wait (ignores Engine.time_scale) so pause tests are deterministic.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _test_1_config_loaded() -> void:
	var global_config := GameConfig.current()
	_check(global_config != null and global_config.validate().is_empty(),
		"the consolidated global config loads with every domain valid")
	_check(GameFeel.config is GameFeelConfig, "GameFeel.config is a GameFeelConfig")
	_check(GameFeel.config == global_config.game_feel
		and CompanySimulation.config() == global_config.company_simulation
		and Craftsmanship.config() == global_config.craftsmanship
		and AlienCompanySimulation.config() == global_config.alien_company,
		"runtime modules share the one embedded global tuning graph")
	_check(is_equal_approx(GameFeel.config.hit_pause_duration, 0.06),
		"config.hit_pause_duration matches the .tres (0.06)")
	# nothing awaited, but keep the async signature uniform
	await get_tree().process_frame


func _test_2_pause_sets_time_scale() -> void:
	_check(is_equal_approx(Engine.time_scale, 1.0), "time_scale is 1.0 before impact")
	GameFeel.register_impact(0.5)
	_check(is_equal_approx(Engine.time_scale, GameFeel._HIT_PAUSE_SCALE),
		"register_impact pins time_scale to 0.05 synchronously")
	await _wait(GameFeel.config.hit_pause_duration + 0.06)


func _test_3_pause_restores_time_scale() -> void:
	# after test 2's wait the pause has expired
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"time_scale restored to 1.0 after the pause expires")
	await get_tree().process_frame


func _test_4_overlap_guard() -> void:
	_check(is_equal_approx(Engine.time_scale, 1.0), "clean start: time_scale 1.0")
	# First pause: 0.05s. Second pause starts 0.02s later, lasts 0.20s.
	GameFeel.hit_pause(0.05)
	await _wait(0.02)
	GameFeel.hit_pause(0.20)
	_check(is_equal_approx(Engine.time_scale, GameFeel._HIT_PAUSE_SCALE),
		"two overlapping pauses: time_scale held at 0.05")
	# Advance to ~0.08s: first pause (expired at 0.05) is gone, second still runs.
	await _wait(0.06)
	_check(is_equal_approx(Engine.time_scale, GameFeel._HIT_PAUSE_SCALE),
		"first pause expired but second holds time_scale at 0.05 (no premature restore)")
	# Advance past the second pause's end (~0.22s).
	await _wait(0.20)
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"time_scale back to 1.0 only after the LAST pause expired")

	# Stress: 10 overlapping pauses must still resolve to exactly 1.0.
	for i in range(10):
		GameFeel.hit_pause(0.05)
	await _wait(0.15)
	_check(is_equal_approx(Engine.time_scale, 1.0) and GameFeel._active_pauses == 0,
		"10 overlapping pauses resolve to time_scale 1.0, counter back to 0")


func _test_5_trauma_clamp() -> void:
	# Drain any residual trauma first.
	EventBus.minigame_exited.emit()
	GameFeel.register_impact(1.0)
	GameFeel.register_impact(1.0)
	_check(GameFeel.get_trauma() <= 1.0 + 0.0001 and GameFeel.get_trauma() > 0.0,
		"two full impacts clamp trauma to <= 1.0")
	await _wait(0.15)   # let the two hit-pauses drain before the next test


func _test_6_camera_shake() -> void:
	EventBus.minigame_exited.emit()   # reset trauma
	var cam := Camera3D.new()
	add_child(cam)
	GameFeel.register_camera(cam)
	GameFeel.register_impact(1.0)

	var saw_shake := false
	for i in range(5):
		await get_tree().process_frame
		if absf(cam.h_offset) > 0.0 or absf(cam.v_offset) > 0.0:
			saw_shake = true
	_check(saw_shake, "camera h/v offset is non-zero while trauma > 0")

	EventBus.minigame_exited.emit()
	_check(is_equal_approx(cam.h_offset, 0.0) and is_equal_approx(cam.v_offset, 0.0),
		"minigame_exited zeroes the camera offsets")
	_check(is_equal_approx(GameFeel.get_trauma(), 0.0),
		"minigame_exited zeroes trauma")
	cam.queue_free()
	await _wait(0.15)   # drain the impact's hit-pause


func _test_7_strength_clamp() -> void:
	EventBus.minigame_exited.emit()   # trauma -> 0
	GameFeel.register_impact(50.0)
	_check(GameFeel.get_trauma() <= 1.0 + 0.0001,
		"register_impact(50.0) clamps strength; trauma <= 1.0")
	await _wait(GameFeel.config.hit_pause_duration + 0.06)
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"time_scale clean (1.0) at end of suite")
