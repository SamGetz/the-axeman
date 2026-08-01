extends Node
## FILE: res://core/tests/m4_acceptance.gd
## ATTACHES TO: root Node of res://core/tests/m4_acceptance.tscn. Run (F6).
## Not shipped.
##
## Verifies M4 — the Amendment-6 runtime-slicing firewood mini-game
## (chopping_minigame.tscn / chopping_minigame.gd):
##   - a fresh log spawns as a single cuttable piece on the block
##   - a slice produces two valid halves and fires action_hit_registered ONCE,
##     carrying the acting axe tier
##   - a full chop-down deposits the log's species yield into InventoryManager,
##     exactly one unit per finished firewood piece (A7 resource_gathered)
##   - the per-species table drives the yield item: an oak log yields oak_firewood,
##     a pine log yields pine_firewood (nothing crosses over)
##   - A12: fragment_physics_budget still caps active bodies at 24 with a
##     settle-timeout backstop (reserved for M5/M6, kept + covered here)
##   - EVERY row of the species table is coherent: a registered yield id, and a
##     log that actually builds at the authored height with real girth. This one
##     is written to cover species the suite has never heard of, so an art drop
##     is checked without editing this file.
##
## Drives debug_slice_world() directly (no mouse) so it is fully headless. The
## click-to-chop input layer itself is NOT headless-verifiable — eyeball that in
## F5/F6. Awaits physics settle timers — run with a generous --quit-after (30+).

var _passes := 0
var _fails := 0
var _hit_count := 0
var _last_hit_tier := -1
var _gathered: Dictionary = {}   # item_id -> total amount gathered since last clear

const _MINIGAME := preload("res://scenes/3d_action/chopping_minigame.tscn")
const _FRAGMENT_PIECE := preload("res://scenes/3d_action/fragment_piece.tscn")
const _BUDGET_SCRIPT := preload("res://scenes/3d_action/fragment_physics_budget.gd")


func _ready() -> void:
	print("=== M4 ACCEPTANCE — runtime-slicing firewood mini-game ===")
	EventBus.action_hit_registered.connect(_on_hit)
	EventBus.resource_gathered.connect(_on_gathered)
	await _test_1_fresh_log()
	await _test_2_slice_geometry_and_hit()
	await _test_3_chopdown_stocks_inventory()
	await _test_4_species_drives_yield()
	await _test_5_budget_cap_and_timeout()
	await _test_6_species_table_integrity()
	print("=== M4 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M4 ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()   # deterministic headless exit once the awaits have all resolved


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _on_hit(_pos: Vector3, tool_tier: int, _dir: Enums.ChopDirection) -> void:
	_hit_count += 1
	_last_hit_tier = tool_tier


func _on_gathered(item: StringName, amount: int) -> void:
	_gathered[item] = int(_gathered.get(item, 0)) + amount


# --------------------------------------------------------------- helpers
## Instance the mini-game with a forced log species (set BEFORE _ready so the
## first log uses it) and let _ready() spawn that log.
func _make_minigame(forced_species: int) -> Node3D:
	var mg: Node3D = _MINIGAME.instantiate()
	mg.debug_forced_species = forced_species
	# M4 tests the YIELD contract: a finished piece deposits stock. Since
	# 2026-08-01 the yard buys that stock back the moment the piece lands on the
	# pile, which would empty the very inventory these tests are counting — so the
	# economy layer is switched off here. Its own behaviour is m7a_acceptance's.
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame   # let _ready() build the stump + drop the first log
	return mg


func _drop(mg: Node) -> void:
	mg.queue_free()
	await get_tree().process_frame   # let _exit_tree() unregister the camera before the next one


## Cut the on-block pieces (always _on_block[0], through its centre, alternating
## horizontal axes) until nothing is cuttable. Returns the firewood produced —
## captured immediately, before any of it has settled/stacked, so on-block == 0
## means piece_count() is exactly the live firewood count.
func _drive_to_completion(mg) -> int:
	var safety := 0
	while mg.cuttable_count() > 0 and safety < 60:
		var n := Vector3.RIGHT if (safety % 2 == 0) else Vector3(0.0, 0.0, 1.0)
		mg.debug_slice_world(Plane(n, 0.0))
		safety += 1
		await get_tree().process_frame
	return mg.piece_count()


# ----------------------------------------------------------------- tests
func _test_1_fresh_log() -> void:
	var mg := await _make_minigame(0)
	_check(mg.piece_count() == 1, "fresh log spawns exactly one piece")
	_check(mg.cuttable_count() == 1, "fresh log is cuttable (sitting on the block)")
	await _drop(mg)


func _test_2_slice_geometry_and_hit() -> void:
	var mg := await _make_minigame(0)
	var hits0 := _hit_count
	var ok: bool = mg.debug_slice_world(Plane(Vector3.RIGHT, 0.0))
	_check(ok, "a slice succeeds (produces two valid halves)")
	await get_tree().process_frame
	_check(mg.piece_count() >= 2, "slice produced at least two pieces")
	_check(_hit_count - hits0 == 1, "exactly one action_hit_registered per slice")
	_check(_last_hit_tier == GameState.get_tool_tier(Enums.ToolType.AXE),
		"hit carries the acting axe tier (%d)" % GameState.get_tool_tier(Enums.ToolType.AXE))
	await _drop(mg)


func _test_3_chopdown_stocks_inventory() -> void:
	var mg := await _make_minigame(0)   # species 0 -> oak_firewood
	var before := InventoryManager.get_count(&"oak_firewood")
	_gathered.clear()
	var firewood := await _drive_to_completion(mg)
	_check(firewood > 0, "chop-down produced firewood (%d pieces)" % firewood)

	await _wait(2.2)   # settle-timeout (1.5s) + margin, so _begin_stacking runs and collects
	var after := InventoryManager.get_count(&"oak_firewood")
	_check(after - before == firewood,
		"each finished piece deposits 1 oak_firewood (inventory +%d for %d pieces)" % [after - before, firewood])
	_check(int(_gathered.get(&"oak_firewood", 0)) == firewood,
		"resource_gathered fired once per firewood piece (oak_firewood x%d)" % firewood)
	_check(not _gathered.has(&"pine_firewood"), "an oak log yields no pine_firewood")
	await _drop(mg)


func _test_4_species_drives_yield() -> void:
	var mg := await _make_minigame(1)   # species 1 -> pine_firewood
	var before := InventoryManager.get_count(&"pine_firewood")
	_gathered.clear()
	var firewood := await _drive_to_completion(mg)
	await _wait(2.2)
	_check(InventoryManager.get_count(&"pine_firewood") - before == firewood,
		"a pine log deposits pine_firewood, not oak (the species table drives the yield)")
	_check(int(_gathered.get(&"pine_firewood", 0)) == firewood and not _gathered.has(&"oak_firewood"),
		"only the chopped log's species is gathered")
	await _drop(mg)


## Every row of the species table, checked the same way — so a NEW SPECIES DROP is
## covered the moment it is added, instead of needing its own hand-written test.
##
## Tests 3 and 4 only ever exercise species 0 and 1 by index; birch (added
## 2026-08-01) would have shipped with an unregistered `birch_firewood` yield and
## nothing here would have gone red — InventoryManager errors and ignores an
## unregistered id, so the wood would simply have vanished on collection.
##
## Each check asserts a POSITIVE quantity, never just a bound: the row count is
## asserted first so an emptied table cannot satisfy the loop vacuously, and the
## height check asserts the log measures `log_height`, not merely "less than
## enormous" — the 2026-07-29 bug shipped a 14 m log past every relative check.
func _test_6_species_table_integrity() -> void:
	var probe: Node = _MINIGAME.instantiate()
	var species: Array = probe._LOG_SPECIES
	var target_height: float = probe.log_height
	probe.free()

	_check(species.size() >= 2,
		"the species table holds at least the two shipped woods (%d rows)" % species.size())

	for i in range(species.size()):
		var row: Dictionary = species[i]
		var yield_item: StringName = row.get("yield_item", &"")
		var meshes: Array = row.get("meshes", [])

		_check(yield_item != &"" and InventoryManager.is_valid_id(yield_item),
			"species %d ('%s') yields a REGISTERED item id" % [i, yield_item])
		_check(not meshes.is_empty(),
			"species %d ('%s') lists at least one log mesh (%d)" % [i, yield_item, meshes.size()])

		# One live scene per species, then every AUTHORED SHAPE of that species
		# built through the same code path. Log variety is exactly where a bad
		# import hides: five good meshes and one broken one still spawns fine
		# five times out of six.
		var mg := await _make_minigame(i)
		_check(mg.cuttable_count() == 1,
			"species %d ('%s') spawns exactly one cuttable piece" % [i, yield_item])

		for m in range(meshes.size()):
			var label: String = String(meshes[m]).get_file()
			var built: Mesh = mg._center_mesh(mg._build_split_log(meshes[m]))
			if built == null:
				_check(false, "  %s builds a log mesh" % label)
				continue
			var size: Vector3 = built.get_aabb().size
			_check(absf(size.y - target_height) <= 0.001,
				"  %s stands %.3f m on the block, as authored (%.2f m)" % [label, size.y, target_height])
			_check(size.x > 0.05 and size.z > 0.05,
				"  %s has real girth (%.3f x %.3f m), not a degenerate import" % [label, size.x, size.z])
		await _drop(mg)


func _test_5_budget_cap_and_timeout() -> void:
	# fragment_physics_budget is reserved for M5/M6 but kept + enforced here (A12).
	var budget: Node = _BUDGET_SCRIPT.new()
	add_child(budget)
	var pieces: Array = []
	for i in range(30):
		var p := _FRAGMENT_PIECE.instantiate()
		add_child(p)
		pieces.append(p)
		budget.track(p)
	_check(budget.tracked_count() == 30, "budget tracked all 30 bodies")
	_check(budget.active_count() == 24, "A12: active bodies capped at 24")
	_check(pieces[0].freeze, "A12: oldest body force-settled (frozen) first")

	var solo := _FRAGMENT_PIECE.instantiate()
	add_child(solo)
	solo.setup(null, 0.1)
	await _wait(0.35)
	_check(solo.is_settled(), "settle-timeout backstop settles a non-sleeping body")

	for p in pieces:
		p.queue_free()
	solo.queue_free()
	budget.queue_free()
	await get_tree().process_frame
