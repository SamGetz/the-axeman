extends Node
## Focused contract for the presentation-only currency simulation: manual-sale
## tokens collide with the live stump proxy while non-stump pools keep the yard
## floor fallback.

const _CoinRewardPool := preload("res://scenes/3d_action/coin_reward_pool.gd")

var _passes := 0
var _fails := 0
var _pool: CoinRewardPool
var _stump_collision: CollisionShape3D


func _ready() -> void:
	print("=== CURRENCY STUMP ACCEPTANCE ===")
	_build_fixture()
	_test_stump_top_bounce()
	_test_stump_wall_bounce()
	_test_stump_top_rest()
	_test_floor_only_fallback()
	await _test_manual_completion_delivers_xp()
	print("=== CURRENCY STUMP RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL CURRENCY STUMP ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit(0 if _fails == 0 else 1)


func _build_fixture() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	var stump := StaticBody3D.new()
	stump.name = "StumpBody"
	add_child(stump)
	_stump_collision = CollisionShape3D.new()
	_stump_collision.name = "StumpCollision"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.4
	cylinder.height = 0.5
	_stump_collision.shape = cylinder
	_stump_collision.position = Vector3(0.0, 0.25, 0.0)
	stump.add_child(_stump_collision)
	_pool = _CoinRewardPool.new()
	add_child(_pool)
	_pool.initialize(camera)
	_pool.set_stump_collider(_stump_collision)


func _test_stump_top_bounce() -> void:
	_stage(Vector3(0.1, _stump_top_center_y() + 0.02, 0.0),
		Vector3(0.15, -1.0, 0.0))
	_pool._step_flight(0, 0.05)
	_check(_pool._coins[0].global_position.y >= _stump_top_center_y()
			and _pool._velocities[0].y > 0.0,
		"a descending token sweeps onto the stump top and rebounds")


func _test_stump_wall_bounce() -> void:
	var wall_x := 0.4 + _pool._collision_radius(0)
	_stage(Vector3(wall_x + 0.02, 0.30, 0.0), Vector3(-1.0, 0.0, 0.0))
	_pool._step_flight(0, 0.05)
	_check(_pool._coins[0].global_position.x >= wall_x
			and _pool._velocities[0].x > 0.0,
		"an inward token hits the curved stump wall instead of tunnelling through")


func _test_stump_top_rest() -> void:
	_stage(Vector3(0.0, _stump_top_center_y() + 0.001, 0.0),
		Vector3(0.0, -0.1, 0.0))
	_pool._step_flight(0, 0.01)
	_check(_pool._phases[0] == CoinRewardPool.Phase.REST
			and is_equal_approx(_pool._support_y[0], 0.5),
		"a spent bounce can settle visibly on the stump surface")


func _test_floor_only_fallback() -> void:
	_pool.set_stump_collider(null)
	var floor_center_y := 0.025 + _pool._collision_radius(0)
	_stage(Vector3(0.0, floor_center_y + 0.001, 0.0),
		Vector3(0.0, -0.1, 0.0))
	_pool._step_flight(0, 0.01)
	_check(_pool._phases[0] == CoinRewardPool.Phase.REST
			and is_equal_approx(_pool._support_y[0], 0.025),
		"a pool without stump geometry retains the yard-floor bounce")


## Currency stages immediately before XP in the live final-split transaction.
## Exercise that complete ordering so a presentation failure can never strand
## the authoritative award behind an uncollected HUD batch.
func _test_manual_completion_delivers_xp() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var game: Node3D = load(
		"res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0
	game.debug_forced_mesh = 0
	game.debug_split_roll = 1
	game.min_vol = 1000.0
	game.auto_sell = true
	game.orbs_enabled = true
	add_child(game)
	var hud: Control = load(
		"res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	hud.bind_xp_source(game)

	var batch_total := [0]
	var collected_total := [0]
	game.xp_orb_batch_started.connect(
		func(amount: int) -> void: batch_total[0] += amount)
	game.xp_orb_collected.connect(
		func(amount: int, _tier: int) -> void: collected_total[0] += amount)
	# Old builds persisted an in-process instance id and restarted this serial at
	# one. Seed the exact id they would reuse after a relaunch; the new session
	# nonce must keep this real completion distinct.
	var legacy_root := StringName("manual_log_%d_1" % game.get_instance_id())
	GameState.record_manual_log_equivalent(legacy_root, SpeciesTable.at(0).id)
	var before := GameState.get_xp()
	game.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	var awarded := GameState.get_xp() - before
	var active_orbs := 0
	for child in game.get_children():
		if child is XPOrb and child.is_processing():
			active_orbs += 1
	_check(awarded > 0 and batch_total[0] == awarded and active_orbs > 0,
		"a currency-staged final split still banks XP and spills active orbs " \
			+ "[cuttable=%d awarded=%d batch=%d active=%d]" % [
				game.cuttable_count(), awarded, batch_total[0], active_orbs])

	var deadline := Time.get_ticks_msec() + 3000
	while collected_total[0] < awarded and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame
	var bar: ProgressBar = hud.get_node("XPBar/Progress")
	_check(collected_total[0] == awarded
			and hud._displayed_xp_total == GameState.get_xp()
			and hud._pending_orb_xp == 0 and hud._inflight_orb_xp == 0,
		"the completed orb wave delivers the exact award into the live XP bar " \
			+ "[collected=%d awarded=%d bar=%.3f expected=%.3f]" % [
				collected_total[0], awarded, bar.value,
				GameState.get_level_progress_for_xp(GameState.get_xp())])
	game.queue_free()
	hud.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


func _stage(position: Vector3, velocity: Vector3) -> void:
	_pool.begin_burst(position, 1, 0.025, 0.4, 99.0, 0.0)
	_pool._coins[0].global_position = position
	_pool._velocities[0] = velocity


func _stump_top_center_y() -> float:
	return 0.5 + _pool._collision_radius(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
