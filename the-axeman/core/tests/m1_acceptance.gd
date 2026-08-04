extends Node
## FILE: res://core/tests/m1_acceptance.gd
## ATTACHES TO: the root Node of res://core/tests/m1_acceptance.tscn.
## Run that scene (F6 / Run Current Scene). Not shipped in builds.
##
## Covers the M1 acceptance criteria verbatim, plus the hardening edges
## (atomicity, duplicate-cost aggregation, downgrade rejection, biome unlock).
## NOTE: tests 2, 5, 7 and 8 INTENTIONALLY trigger push_error/push_warning —
## seeing red lines from InventoryManager/GameState in the Output panel during
## those tests is the contract working, not a failure. Only lines beginning
## with "FAIL:" are failures.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M1 ACCEPTANCE — core contracts ===")
	_test_1_gather_valid()
	_test_2_gather_unregistered()
	_test_3_fresh_tool_tiers()
	_test_4_atomic_remove_success()
	_test_5_atomic_remove_failure()
	_test_6_duplicate_cost_aggregation()
	_test_7_biome_unlock_flow()
	_test_8_gear_upgrade_flow()
	print("=== M1 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M1 ACCEPTANCE CRITERIA PASS ===")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


## Criterion: emitting resource_gathered(&"pine_firewood", 3) raises pine log count by 3.
func _test_1_gather_valid() -> void:
	var before := InventoryManager.get_count(&"pine_firewood")
	EventBus.resource_gathered.emit(&"pine_firewood", 3)
	_check(InventoryManager.get_count(&"pine_firewood") == before + 3,
		"resource_gathered(&\"pine_firewood\", 3) raised count from %d to %d" % [before, before + 3])


## Criterion: emitting an unregistered id logs an error and changes nothing.
func _test_2_gather_unregistered() -> void:
	var snapshot := InventoryManager.get_all_counts()
	EventBus.resource_gathered.emit(&"unobtainium", 5) # expected: 1 error in Output
	var unchanged := InventoryManager.get_all_counts() == snapshot
	_check(unchanged, "unregistered id 'unobtainium' rejected; no counts changed (an error above is EXPECTED)")
	_check(not InventoryManager.is_valid_id(&"unobtainium"), "is_valid_id(&\"unobtainium\") is false")
	_check(InventoryManager.is_valid_id(&"oak_firewood"), "is_valid_id(&\"oak_firewood\") is true")


## Criterion: GameState.get_tool_tier(Enums.ToolType.AXE) returns 1 on a fresh save.
func _test_3_fresh_tool_tiers() -> void:
	_check(GameState.get_tool_tier(Enums.ToolType.AXE) == 1, "fresh save: AXE tier == 1")
	_check(GameState.get_building_tier(&"sawmill") == 1, "fresh save: unknown building reads tier 1")


func _test_4_atomic_remove_success() -> void:
	EventBus.resource_gathered.emit(&"wood_board", 5)
	EventBus.resource_gathered.emit(&"birch_firewood", 2)
	var boards := InventoryManager.get_count(&"wood_board")
	var birch := InventoryManager.get_count(&"birch_firewood")
	var costs := [
		{ "item_id": &"wood_board", "amount": 3 },
		{ "item_id": &"birch_firewood", "amount": 2 },
	]
	_check(InventoryManager.can_afford(costs), "can_afford true for 3 boards + 2 birch firewood")
	var ok := InventoryManager.remove_items(costs)
	_check(ok and InventoryManager.get_count(&"wood_board") == boards - 3
		and InventoryManager.get_count(&"birch_firewood") == birch - 2,
		"affordable remove_items consumed exactly 3 boards + 2 birch firewood")


func _test_5_atomic_remove_failure() -> void:
	var boards := InventoryManager.get_count(&"wood_board")
	var costs := [
		{ "item_id": &"wood_board", "amount": 1 },
		{ "item_id": &"aspen_firewood", "amount": 999 },
	]
	var ok := InventoryManager.remove_items(costs)
	_check(not ok and InventoryManager.get_count(&"wood_board") == boards,
		"unaffordable remove_items refused; boards untouched (atomic — no partial consume)")
	var bad_costs := [{ "item_id": &"unobtainium", "amount": 1 }]
	_check(not InventoryManager.remove_items(bad_costs),
		"cost list with unregistered id rejected (an error above is EXPECTED)")


func _test_6_duplicate_cost_aggregation() -> void:
	EventBus.resource_gathered.emit(&"yellow_birch_firewood", 4)
	var yellow_birch := InventoryManager.get_count(&"yellow_birch_firewood") # 4 on a fresh test run
	# Naive per-entry checking would wrongly pass this with only 4 yellow birch:
	# each 3-piece entry is individually affordable, but the true total is 6.
	var dup_costs := [
		{ "item_id": &"yellow_birch_firewood", "amount": 3 },
		{ "item_id": &"yellow_birch_firewood", "amount": 3 },
	]
	_check(not InventoryManager.can_afford(dup_costs),
		"duplicate cost entries aggregate (3+3 needs 6, have %d) — can_afford false" % yellow_birch)
	_check(not InventoryManager.remove_items(dup_costs),
		"duplicate-cost remove_items refused")
	_check(InventoryManager.get_count(&"yellow_birch_firewood") == yellow_birch,
		"yellow birch firewood count untouched after refused duplicate-cost remove")


func _test_7_biome_unlock_flow() -> void:
	_check(GameState.is_biome_unlocked(Enums.Biome.PINE_FOREST), "PINE_FOREST unlocked on fresh save")
	_check(not GameState.is_biome_unlocked(Enums.Biome.MAHOGANY_FOREST), "MAHOGANY_FOREST locked on fresh save")
	EventBus.environment_unlocked.emit(Enums.Biome.MAHOGANY_FOREST)
	_check(GameState.is_biome_unlocked(Enums.Biome.MAHOGANY_FOREST), "environment_unlocked unlocks MAHOGANY_FOREST")
	EventBus.environment_unlocked.emit(Enums.Biome.MAHOGANY_FOREST) # expected: 1 warning
	_check(GameState.is_biome_unlocked(Enums.Biome.MAHOGANY_FOREST),
		"duplicate unlock is idempotent (a warning above is EXPECTED)")


func _test_8_gear_upgrade_flow() -> void:
	EventBus.gear_upgraded.emit(Enums.ToolType.AXE, 2)
	_check(GameState.get_tool_tier(Enums.ToolType.AXE) == 2, "gear_upgraded(AXE, 2) applied")
	EventBus.gear_upgraded.emit(Enums.ToolType.AXE, 1) # expected: 1 warning
	_check(GameState.get_tool_tier(Enums.ToolType.AXE) == 2,
		"downgrade attempt ignored, tier stays 2 (a warning above is EXPECTED)")
