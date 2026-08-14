extends Node3D
## Real slicer/journal round-trip. This guards the highest-risk suspension seam:
## a partially chopped and scarred active log must restore, not reroll.

var _passed := 0
var _failed := 0


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var game := load("res://scenes/3d_action/chopping_minigame.tscn").instantiate() as Node3D
	add_child(game)
	var run := RunDirector.new()
	run.tuning = load("res://data/survival_run_tuning_placeholder.tres")
	add_child(run)
	await get_tree().process_frame
	game.call("bind_run_director", run)
	var species := SpeciesTable.starting_species()
	var descriptor := LogDescriptor.create(&"journal_log", species.id, 0, 1, 991)
	game.call("stage_run_log", descriptor, false)
	game.set("debug_split_roll", 0)
	var failed_cut := bool(game.call("debug_swing_world", Plane(Vector3.RIGHT, 0.0)))
	_check(not failed_cut and int(game.call("debug_scar_count")) == 1,
		"a failed active-log cut records one physical scar before suspension")
	game.set("debug_split_roll", 1)
	var split := bool(game.call("debug_swing_world", Plane(Vector3.FORWARD, 0.0)))
	_check(split and int(game.call("piece_count")) > 0,
		"the real slicer creates resumable descendants")
	var before := game.call("to_run_save_dict") as Dictionary
	var before_ids := _piece_ids(before)
	var before_scars := int(game.call("debug_total_scar_projection_count"))
	_check(not bool(before.get("transitioning", true))
		and (before.get("cut_journal", []) as Array).size() == 1
		and not before_ids.is_empty(),
		"snapshot carries descriptor, local split plane, stable descendants, and transforms")

	game.call("clear_run_log")
	game.call("restore_run_save_dict", before)
	var after := game.call("to_run_save_dict") as Dictionary
	var after_ids := _piece_ids(after)
	_check(after_ids == before_ids
		and (after.get("cut_journal", []) as Array).size()
			== (before.get("cut_journal", []) as Array).size(),
		"restore replays the cut journal to the same stable piece identities")
	_check(_piece_transforms_match(before, after),
		"restore reapplies each descendant's exact saved transform")
	_check(int(game.call("debug_total_scar_projection_count")) == before_scars,
		"restore preserves physical scar projections without duplicating pity")

	print("SURVIVAL CUT JOURNAL: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _piece_ids(snapshot: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	var rows: Variant = snapshot.get("pieces", [])
	if rows is Array:
		for raw: Variant in rows:
			if raw is Dictionary:
				ids.append(String(raw.get("id", "")))
	ids.sort()
	return ids


func _piece_transforms_match(before: Dictionary, after: Dictionary) -> bool:
	var expected: Dictionary = {}
	for raw: Variant in before.get("pieces", []):
		if raw is Dictionary:
			expected[String(raw.get("id", ""))] = raw.get("transform", Transform3D.IDENTITY)
	for raw: Variant in after.get("pieces", []):
		if not (raw is Dictionary):
			return false
		var id := String(raw.get("id", ""))
		if not expected.has(id):
			return false
		var wanted: Transform3D = expected[id]
		var actual: Transform3D = raw.get("transform", Transform3D.IDENTITY)
		if not wanted.is_equal_approx(actual):
			return false
		expected.erase(id)
	return expected.is_empty()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
