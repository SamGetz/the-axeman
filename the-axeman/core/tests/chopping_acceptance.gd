extends Node
## Runtime chopping, settlement, held-input, and floor-sink acceptance.
## Not shipped.
## Verifies `chopping_minigame.tscn`:
##   - a fresh log spawns as a single cuttable piece on the block
##   - a slice produces two valid halves and fires action_hit_registered ONCE,
##     carrying the acting axe tier
##   - a full chop-down deposits the log's species yield into InventoryManager,
##     exactly one unit per finished firewood piece (A7 resource_gathered)
##   - the per-species table drives the yield item: an oak log yields oak_firewood,
##     a pine log yields pine_firewood (nothing crosses over)
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
var _gathered: Dictionary = {}   # item_id -> total amount gathered since last clear

const _MINIGAME := preload("res://scenes/3d_action/chopping_minigame.tscn")
const _SURVIVAL_TUNING := preload("res://data/survival_run_tuning_placeholder.tres")


func _ready() -> void:
	print("=== CHOPPING ACCEPTANCE ===")
	EventBus.action_hit_registered.connect(_on_hit)
	EventBus.resource_gathered.connect(_on_gathered)
	await _test_1_fresh_log()
	await _test_2_slice_geometry_and_hit()
	await _test_3_chopdown_stocks_inventory()
	await _test_4_species_drives_yield()
	await _test_6_species_table_integrity()
	await _test_7_axe_viewmodel_drives_the_strike()
	await _test_8_failed_strike_schedules_thud()
	await _test_9_unlocked_hold_to_chop_repeats_input()
	print("=== CHOPPING RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL CHOPPING ACCEPTANCE CRITERIA PASS ===")
	EventBus.action_hit_registered.disconnect(_on_hit)
	EventBus.resource_gathered.disconnect(_on_gathered)
	var tree := get_tree()
	tree.create_timer(0.0).timeout.connect(tree.quit, CONNECT_ONE_SHOT)
	queue_free()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _on_hit(_pos: Vector3) -> void:
	_hit_count += 1


func _on_gathered(item: StringName, amount: int) -> void:
	_gathered[item] = int(_gathered.get(item, 0)) + amount


# --------------------------------------------------------------- helpers
## Instance the mini-game with a forced log species (set BEFORE _ready so the
## first log uses it) and let _ready() spawn that log.
func _make_minigame(forced_species: int) -> Node3D:
	var mg: Node3D = _MINIGAME.instantiate()
	mg.debug_forced_species = forced_species
	# This test checks the yield contract: a finished piece deposits stock. Production
	# validates and sells that stock when landed physics is retired, which would
	# empty the inventory these tests count, so the economy layer is disabled here.
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame   # let _ready() build the stump + drop the first log
	return mg


func _drop(mg: Node) -> void:
	mg.queue_free()
	await get_tree().process_frame   # let _exit_tree() unregister the camera before the next one


## Cut the on-block pieces (always _on_block[0], through its centre, alternating
## horizontal axes) until nothing is cuttable. Returns the firewood produced —
## captured immediately, before any of it has settled and become an inert
## finished piece, so on-block == 0 means piece_count() is the live firewood count.
func _drive_to_completion(mg) -> int:
	var safety := 0
	while mg.cuttable_count() > 0 and safety < 60:
		var n := Vector3.RIGHT if (safety % 2 == 0) else Vector3(0.0, 0.0, 1.0)
		mg.debug_slice_world(Plane(n, 0.0))
		safety += 1
		await get_tree().process_frame
	return mg.piece_count()


## Advance only the finished-piece presentation clock. The public snapshot and
## production updater prove that sinking begins on the first positive delta.
func _check_finished_piece_sink_lifecycle(mg: Node, expected_count: int) -> void:
	var hold_seconds := float(_SURVIVAL_TUNING.finished_piece_hold_seconds)
	var sink_speed := float(_SURVIVAL_TUNING.finished_piece_sink_speed)
	var initial := mg.debug_finished_piece_state() as Dictionary
	_check(is_zero_approx(hold_seconds),
		"finished firewood has no pre-sink hold")
	_check(int(initial.get("count", 0)) == expected_count \
			and int(initial.get("geometry_count", 0)) >= expected_count \
			and int(initial.get("collision_shape_count", 0)) >= expected_count \
			and int(initial.get("enabled_collision_count", -1)) == 0 \
			and is_zero_approx(float(initial.get("max_sink_distance", -1.0))),
		"every settled piece is visible and already non-colliding before its first sink frame (%d pieces)" % expected_count)

	var first_sink_delta := 0.05
	mg.call("_update_finished_piece_sink", first_sink_delta)
	var sinking := mg.debug_finished_piece_state() as Dictionary
	_check(int(sinking.get("count", 0)) > 0 \
			and int(sinking.get("count", 0)) <= expected_count \
			and is_equal_approx(float(sinking.get("max_sink_distance", 0.0)),
				sink_speed * first_sink_delta) \
			and int(sinking.get("enabled_collision_count", -1)) == 0,
		"finished pieces sink on their first frame while remaining non-colliding [state=%s expected_sink=%.3f]" % [
			sinking, sink_speed * first_sink_delta])

	for _step: int in range(30):
		if int((mg.debug_finished_piece_state() as Dictionary).get(
				"count", 0)) == 0:
			break
		mg.call("_update_finished_piece_sink", 1.0)
	var gone := mg.debug_finished_piece_state() as Dictionary
	_check(int(gone.get("count", -1)) == 0 \
			and int(gone.get("geometry_count", -1)) == 0,
		"finished pieces despawn only after sinking fully below the floor")


# ----------------------------------------------------------------- tests
func _test_1_fresh_log() -> void:
	var mg: Node3D = await _make_minigame(0)
	_check(mg.piece_count() == 1, "fresh log spawns exactly one piece")
	_check(mg.cuttable_count() == 1, "fresh log is cuttable (sitting on the block)")
	var live_bark := load(
		"res://assets/shaders/log_bark_triplanar.gdshader") as Shader
	var live_end := load(
		"res://assets/shaders/log_end_cap.gdshader") as Shader
	_check(live_bark != null and live_end != null
			and not live_bark.code.contains("ALPHA")
			and not live_end.code.contains("ALPHA"),
		"active bark and end grain stay in the opaque pipeline until retirement")
	await _drop(mg)


func _test_2_slice_geometry_and_hit() -> void:
	var mg := await _make_minigame(0)
	var hits0 := _hit_count
	var ok: bool = mg.debug_slice_world(Plane(Vector3.RIGHT, 0.0))
	_check(ok, "a slice succeeds (produces two valid halves)")
	await get_tree().process_frame
	_check(mg.piece_count() >= 2, "slice produced at least two pieces")
	_check(_hit_count - hits0 == 1, "exactly one action_hit_registered per slice")
	await _drop(mg)


## The yield ids are READ FROM THE TABLE, never spelled out here. They used to be
## literal `oak_firewood`/`pine_firewood`, which quietly encoded "species 0 is
## oak" — a fact that stopped being true on 2026-08-02 when Sam's 25 woods
## reordered the ladder by hardness and put Quaking Aspen at index 0. What these
## tests are actually about is that THE LOG ON THE BLOCK DECIDES THE YIELD, which
## is exactly as testable without naming the wood.
func _test_3_chopdown_stocks_inventory() -> void:
	var item := SpeciesTable.at(0).yield_item
	var mg := await _make_minigame(0)
	var before := InventoryManager.get_count(item)
	_gathered.clear()
	AudioDirector.begin_session()
	var impacts_before := AudioDirector.debug_started_event_count(&"piece_land")
	var firewood := await _drive_to_completion(mg)
	_check(firewood > 0, "chop-down produced firewood (%d pieces)" % firewood)
	var landing_bodies: Array = mg.get("_firewood")
	for raw_body: Variant in landing_bodies:
		if raw_body is RigidBody3D:
			(raw_body as RigidBody3D).linear_velocity = Vector3(10.0, 0.0, 0.0)
	mg.set("_finished_batch_age", 0.0)
	_check(not bool(mg.call("_firewood_settled")),
		"finished firewood cannot exhaust its settle timeout while active play is paused")
	mg.set("_finished_batch_age", 99.0)
	_check(bool(mg.call("_firewood_settled")),
		"finished firewood settle timeout is driven by active gameplay seconds")
	# Retire synchronously so the zero-hold sink can be inspected before normal
	# process frames legitimately carry every small billet below the floor.
	mg.call("_settle_finished_firewood")
	_check_finished_piece_sink_lifecycle(mg, firewood)

	await _wait(2.2)   # settle-timeout (1.5s) + margin, so finished pieces settle and collect
	var ground_impacts := AudioDirector.debug_started_event_count(&"piece_land") - impacts_before
	AudioDirector.end_session()
	_check(ground_impacts == firewood,
		"every finished firewood piece schedules one ground-impact cue (%d/%d)"
			% [ground_impacts, firewood])
	var after := InventoryManager.get_count(item)
	_check(after - before == firewood,
		"each finished piece deposits 1 %s (inventory +%d for %d pieces)" % [item, after - before, firewood])
	_check(int(_gathered.get(item, 0)) == firewood,
		"resource_gathered fired once per firewood piece (%s x%d)" % [item, firewood])
	_check(_gathered.size() == 1,
		"the first wood on the ladder yields ONLY %s (%d ids gathered)" % [item, _gathered.size()])
	await _drop(mg)


func _test_4_species_drives_yield() -> void:
	var item := SpeciesTable.at(1).yield_item
	var other := SpeciesTable.at(0).yield_item
	_check(item != other,
		"the first two woods on the ladder yield DIFFERENT items (%s vs %s)" % [other, item])

	var mg := await _make_minigame(1)
	var before := InventoryManager.get_count(item)
	_gathered.clear()
	var firewood := await _drive_to_completion(mg)
	await _wait(2.2)
	_check(InventoryManager.get_count(item) - before == firewood,
		"species 1's log deposits %s (the species table drives the yield)" % item)
	_check(int(_gathered.get(item, 0)) == firewood and not _gathered.has(other),
		"only the chopped log's species is gathered — no %s" % other)
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
##
## SPLIT IN TWO on 2026-08-02, when Sam's 25 woods landed. The row checks still
## run over EVERY species, but the expensive half — spawning a live scene and
## measuring the built log — now runs once per DISTINCT MESH PATH rather than
## once per species. That is not a shortcut, it is the more honest target: 22 of
## the 25 rows currently point at the same two oak FBXs, so spawning 25 scenes
## measured the same eight imports twenty-five times over. What can break here is
## an IMPORT, and there are eight of those.
func _test_6_species_table_integrity() -> void:
	var probe: Node = _MINIGAME.instantiate()
	var target_height: float = probe.log_height
	probe.free()

	var species := SpeciesTable.all()
	_check(species.size() >= 2,
		"the species table holds at least the two shipped woods (%d rows)" % species.size())

	# --- every row, cheaply: a species that yields nothing loses its wood silently
	var seen_ids: Dictionary = {}
	var mesh_paths: Array[String] = []
	var bad_yield: Array[String] = []
	var no_meshes: Array[String] = []
	var dupe_ids: Array[String] = []
	for i in range(species.size()):
		var row := species[i]
		if row == null:
			_check(false, "species row %d is null" % i)
			continue
		if seen_ids.has(row.id):
			dupe_ids.append(String(row.id))
		seen_ids[row.id] = true
		if row.yield_item == &"" or not InventoryManager.is_valid_id(row.yield_item):
			bad_yield.append("%s -> '%s'" % [row.id, row.yield_item])
		if row.meshes.is_empty():
			no_meshes.append(String(row.id))
		for p in row.meshes:
			if not mesh_paths.has(p):
				mesh_paths.append(p)

	_check(bad_yield.is_empty(),
		"all %d species yield a REGISTERED item id%s"
			% [species.size(), "" if bad_yield.is_empty() else " — unregistered: " + ", ".join(bad_yield)])
	_check(no_meshes.is_empty(),
		"all %d species list at least one log mesh%s"
			% [species.size(), "" if no_meshes.is_empty() else " — empty: " + ", ".join(no_meshes)])
	_check(dupe_ids.is_empty(),
		"every species id is unique%s"
			% ["" if dupe_ids.is_empty() else " — repeated: " + ", ".join(dupe_ids)])

	# --- every authored SHAPE, through the real code path. Log variety is exactly
	# where a bad import hides: five good meshes and one broken one still spawns
	# fine five times out of six.
	_check(mesh_paths.size() >= 2,
		"the table names at least two distinct log meshes (%d)" % mesh_paths.size())

	var mg := await _make_minigame(0)
	_check(mg.cuttable_count() == 1, "the block spawns exactly one cuttable piece")
	for path in mesh_paths:
		var label := path.get_file()
		var built: Mesh = mg._center_mesh(mg._build_split_log(path))
		if built == null:
			_check(false, "  %s builds a log mesh" % label)
			continue
		var size: Vector3 = built.get_aabb().size
		_check(absf(size.y - target_height) <= 0.001,
			"  %s stands %.3f m on the block, as authored (%.2f m)" % [label, size.y, target_height])
		_check(size.x > 0.05 and size.z > 0.05,
			"  %s has real girth (%.3f x %.3f m), not a degenerate import" % [label, size.x, size.z])
	await _drop(mg)

	# --- and every species still SPAWNS, which the row checks alone cannot prove:
	# a row can name a registered item and a real mesh and still fail to reach the
	# block. Cheap (no cutting, no physics), so it stays exhaustive.
	var spawned := 0
	var failed: Array[String] = []
	for i in range(species.size()):
		var one := await _make_minigame(i)
		if one.cuttable_count() == 1:
			spawned += 1
		else:
			failed.append("%d/%s" % [i, species[i].id])
		one.queue_free()
		await get_tree().process_frame
	# Asserts the COUNT, not "nothing failed": an empty table, or a loop that
	# silently stopped spawning, would satisfy a no-failures check vacuously.
	_check(spawned == species.size() and spawned > 0,
		"all %d species spawn a log on the block (%d did%s)"
			% [species.size(), spawned, "" if failed.is_empty() else " — failed: " + ", ".join(failed)])


## The camera-mounted axe (2026-08-02) and THE THING THAT MAKES IT MORE THAN ART:
## the swing animation's own method key is what breaks the wood. The rig itself is
## a picture and pictures are judged in core/tools/axe_shot.tscn, but the seam
## between the picture and the mechanic is exactly the sort of thing that rots
## silently — a re-keyed animation that drops the contact key would leave every
## click hanging, and nothing else in this suite would notice.
func _test_7_axe_viewmodel_drives_the_strike() -> void:
	var mg := await _make_minigame(0)
	var axe: Node = mg.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor")
	_check(axe is AxeViewmodel, "the axe rig hangs off the camera as AxeViewmodelAnchor")
	if axe == null:
		await _drop(mg)
		return
	# The node names are the contract between the scene and the animation: the
	# transform tracks address "AxeAnimationRoot" by name, so a rename in the scene
	# alone silently animates nothing at all.
	_check(axe.get_node_or_null("AxeAnimationRoot") != null,
		"the animated child is named AxeAnimationRoot (the tracks address it by name)")
	_check(axe.get_node_or_null("AnimationPlayer") is AnimationPlayer,
		"the rig carries its own AnimationPlayer")
	var player: AnimationPlayer = axe.get_node("AnimationPlayer")
	_check(axe.swing_duration() > 0.0, "the swing animation exists and has a length")
	_check(player.has_animation(axe.bounce_anim),
		"the rig carries a separate failed-strike bounce animation")
	# has_contact_key() hunts the method track for the name the script implements,
	# so this is the two halves of the seam checked against each other, not a
	# restatement of either.
	_check(axe.has_contact_key(),
		"the swing carries a contact key calling a method the viewmodel implements")
	_check(axe.contact_time() > 0.0 and axe.contact_time() < axe.swing_duration(),
		"the contact key lands INSIDE the swing, not at either end")

	# Idle means invisible: a viewmodel left on screen between swings is an axe
	# standing in the middle of the yard.
	var root: Node3D = axe.get_node("AxeAnimationRoot")
	_check(not root.visible, "the axe is hidden while nothing is swinging")

	# THE STRIKE LANDS ON THE KEY, AND IT IS THE KEY THAT LANDS IT. The failsafe
	# resolves a strike too, so a check that merely waits long enough cannot tell
	# the two apart — push the failsafe far out of reach and anything that resolves
	# inside the swing can only have come from the contact key.
	mg.strike_timeout_slack = 20.0
	# FORCE THE ROLL. This test is about WHEN the strike resolves, not whether it
	# goes through — and a real roll on the first wood fails about 45% of the time
	# (Sam's number), so leaving it to luck would make the check below flake on a
	# scar, which is a perfectly correct outcome.
	mg.debug_split_roll = 1

	# THE ONLY RAYCAST IN THIS SUITE, and it needs two things the slice tests never
	# did: the piece's Area3D actually registered in the physics space (a process
	# frame is not enough — the query runs against the physics server), and the log
	# settled at rest rather than still dropping in from `drop_height`.
	await _wait(0.6)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var before: int = mg.piece_count()
	mg._on_click(get_viewport().get_visible_rect().size * 0.5)
	await get_tree().process_frame
	_check(axe.is_swinging(), "a click starts the swing")
	_check(root.visible, "the axe is on screen while it swings")
	_check(mg.piece_count() == before,
		"the wood is INTACT while the axe is still travelling (%d pieces)" % mg.piece_count())
	await _wait(axe.contact_time() * 0.55)
	_check(mg.piece_count() == before,
		"still intact past the halfway point of the swing")
	await _wait(axe.contact_time() * 0.7)
	_check(mg.piece_count() > before,
		"the wood comes apart on the contact key, with the failsafe %.1fs away (%d -> %d)"
			% [axe.contact_time() * 20.0, before, mg.piece_count()])
	await _drop(mg)

	# THE FAILSAFE, proven rather than assumed. Strip the contact key out of a copy
	# of the swing and install it: the strike must still resolve, because a pending
	# strike that never lands blocks every future click and stops the game dead.
	var mg2 := await _make_minigame(0)
	mg2.debug_split_roll = 1
	var axe2: Node = mg2.get_node("CameraPivot/Camera3D/AxeViewmodelAnchor")
	var player2: AnimationPlayer = axe2.get_node("AnimationPlayer")
	var maimed: Animation = player2.get_animation(axe2.swing_anim).duplicate(true)
	for track in range(maimed.get_track_count() - 1, -1, -1):
		if maimed.track_get_type(track) == Animation.TYPE_METHOD:
			maimed.remove_track(track)
	var lib := AnimationLibrary.new()
	lib.add_animation(axe2.swing_anim, maimed)
	player2.remove_animation_library(&"")
	player2.add_animation_library(&"", lib)
	_check(not axe2.has_contact_key(), "(setup) the copy really has lost its contact key")

	await _wait(0.6)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before2: int = mg2.piece_count()
	mg2._on_click(get_viewport().get_visible_rect().size * 0.5)
	await _wait(axe2.swing_duration() + 0.3)
	_check(mg2.piece_count() > before2,
		"a swing with NO contact key still resolves on the failsafe (%d -> %d)"
			% [before2, mg2.piece_count()])
	await _drop(mg2)


func _test_8_failed_strike_schedules_thud() -> void:
	var mg := await _make_minigame(0)
	mg.debug_split_roll = 0
	AudioDirector.begin_session()
	var before := AudioDirector.debug_started_event_count(&"wood_thud")
	var split: bool = mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	var thuds := AudioDirector.debug_started_event_count(&"wood_thud") - before
	AudioDirector.end_session()
	_check(not split and thuds == 1,
		"one failed strike schedules exactly one wood thud")
	await _drop(mg)


func _test_9_unlocked_hold_to_chop_repeats_input() -> void:
	GameState.reset_to_defaults()
	var profile := GameState.to_save_dict()
	profile["meta_upgrade_ranks"] = {"hold_to_chop": 1}
	profile["meta_upgrade_spend_ledger"] = {"hold_to_chop": [0]}
	GameState.apply_save_dict(profile)
	var mg: Node3D = await _make_minigame(0)
	mg.set("debug_split_roll", 1)
	# This case isolates held-input repetition. Cross-axis camera correction has
	# its own contract and can intentionally consume a request before the next
	# swing, so keep the target-facing axis stable for this input regression.
	mg.set("long_axis_bias", 999.0)
	await _wait(0.6)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var camera := mg.get_node("CameraPivot/Camera3D") as Camera3D
	var pieces: Array = mg.get("_on_block")
	var first_piece := pieces[0] as Area3D if not pieces.is_empty() else null
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = camera.unproject_position(first_piece.global_position) \
		if first_piece != null else get_viewport().get_visible_rect().size * 0.5
	mg.call("_unhandled_input", press)
	var first_armed := not (mg.get("_pending") as Dictionary).is_empty()
	var player := mg.get_node(
		"CameraPivot/Camera3D/AxeViewmodelAnchor/AnimationPlayer") \
		as AnimationPlayer
	mg.call("_on_axe_contact")
	player.stop()
	var after_first: int = int(mg.call("piece_count"))
	pieces = mg.get("_on_block")
	# A production hold reaches its next legal swing after the first split's
	# authored hop has settled. Snap that presentation to the same final pose so
	# this test can exercise the input/cooldown contract without sleeping in real
	# time while the PieceAnimator follows its wall clock.
	var animator := mg.get("_animator") as RefCounted
	animator.call("finish_for", pieces)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var next_piece := pieces[0] as Area3D if not pieces.is_empty() else null
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(next_piece.global_position) \
		if next_piece != null else press.position
	mg.call("_unhandled_input", motion)
	# Advance in frame-sized phases rather than one artificial long frame: the
	# latter can both arm and consume the strike failsafe in the same call.
	var cooldown: float = float(mg.call("current_swing_cooldown"))
	mg.call("_process", cooldown * 0.5)
	mg.call("_process", cooldown * 0.5 + 0.01)
	var second_armed := not (mg.get("_pending") as Dictionary).is_empty()
	mg.call("_on_axe_contact")
	player.stop()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	mg.call("_unhandled_input", release)
	_check(GameState.has_meta_capability(
			MetaUpgradeDef.Capability.HOLD_TO_CHOP) \
		and first_armed and after_first >= 2 and second_armed \
		and int(mg.call("piece_count")) > after_first \
		and not bool(mg.get("_hold_chop_active")),
		"unlocked Hold-to-Chop consumes one press, repeats the next legal swing while held, and stops on release [owned=%s first=%s after_first=%d second=%s final=%d held=%s]" % [
			GameState.has_meta_capability(
				MetaUpgradeDef.Capability.HOLD_TO_CHOP), first_armed,
			after_first, second_armed, int(mg.call("piece_count")),
			bool(mg.get("_hold_chop_active"))])
	await _drop(mg)
	GameState.reset_to_defaults()
