extends Node
## DEV TOOL. The one thing the acceptance suite cannot check: the PLAYER actually
## being a player.
##
## `m5_acceptance` runs in puppet mode (`player_controlled = false`) on purpose — it
## measures which way trees fall against a known camera. So nothing in it ever exercises
## the CharacterBody3D: gravity, `move_and_slide`, or the fact that the floor under the
## clearing is a trimesh built from imported art at load (`_fit_ground_collider`) rather
## than the authored box. A player who falls through the world would pass all 179 checks.
##
## Run: godot --headless --path . --quit-after 20000 res://core/tools/fps_smoke.tscn

var _passes := 0
var _fails := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Press or release a key for real, so `Input.is_key_pressed` sees it — which is what
## forest_player.gd reads. The project has no input map beyond the engine defaults
## (adding one is a project.godot edit, which is the clobber trap), so WASD is raw keys
## and this is the only honest way to drive it.
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _ready() -> void:
	print("=== FPS SMOKE ===")
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = 0
	game.natural_lean_deg = 0.0
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	# THE POINT OF THIS TOOL: the player drives, exactly as the game ships.
	game.player_controlled = true
	add_child(game)
	await _wait(1.2)

	var player: ForestPlayer = game.player()
	_check(player != null and is_instance_valid(player), "the game has a player")
	if player == null:
		get_tree().quit()
		return
	_check(player.active, "...and it is driving, not being puppeted")
	_check(game.camera() != null and game.camera() == player.camera(),
		"...and the game's camera is the player's")

	# STANDING ON THE GROUND. The floor is a ConcavePolygonShape3D taken off
	# forest_floor_a's own mesh, which sits between y = 0.005 and y = 0.034, plus a box
	# backstop 5 mm under that.
	for i in range(60):
		await get_tree().physics_frame
	_check(player.is_on_floor(), "the player is standing on the ground")
	_check(absf(player.global_position.y) < 0.2,
		"...at ground level, not through it (y = %.3f)" % player.global_position.y)
	var eye := player.eye_position().y
	_check(absf(eye - player.eye_height) < 0.25,
		"...with the camera at eye height (%.2f m, wanted %.2f)" % [eye, player.eye_height])

	# DROPPED FROM A HEIGHT it falls and lands, rather than sinking or floating.
	var start := player.global_position
	player.global_position = start + Vector3.UP * 3.0
	var fell := false
	for i in range(240):
		await get_tree().physics_frame
		if player.is_on_floor():
			fell = true
			break
	_check(fell, "dropped from 3 m it falls under gravity and lands")
	_check(fell and absf(player.global_position.y - start.y) < 0.25,
		"...back at the height it started from (y = %.3f)" % player.global_position.y)

	# AND IT CAN WALK UP TO A TREE AND AIM AT IT.
	#
	# The tree is FOUND, not assumed to be at the origin. This tool runs the shipping
	# configuration, which is now a scattered stand with a `spawn_clear_radius` — so there is
	# deliberately no tree where the single-tree scene used to keep one, and a check written
	# against the origin fails on a perfectly good game. (It did.)
	var target: TreeTrunk = game.debug_nearest_tree()
	_check(target != null, "there is a tree in the stand to walk up to")
	if target == null:
		print("=== FPS SMOKE: %d passed, %d failed ===" % [_passes, _fails])
		get_tree().quit()
		return
	var axis: Vector3 = target.axis_point()
	var stand_off := (Vector3(axis.x, 0.0, axis.z) - Vector3(start.x, 0.0, start.z))
	stand_off = stand_off.normalized() if stand_off.length() > 0.01 else Vector3.BACK
	player.place(axis - stand_off * 2.6 + Vector3(0.0, start.y, 0.0),
		axis + Vector3(0.0, 0.6, 0.0))
	await get_tree().process_frame
	var aim: Dictionary = game.debug_aim()
	_check(aim.ok, "the crosshair finds the tree from the player's own eye")
	_check(aim.ok and absf(aim.local_y - 0.6) < 0.5,
		"...at the height it is looking at (%.2f m)" % aim.local_y)
	_check(aim.ok and aim.trunk == target, "...and it is the tree it was pointed at")

	# WALKING, through the real controller. Synthetic key events rather than a poke at
	# `velocity`: _physics_process reads the keyboard directly and rewrites velocity from
	# it every frame, so anything written from outside is gone before move_and_slide sees
	# it — which is how an earlier version of this check ended up "passing" with the
	# player flung 13 m across the clearing.
	# Measured against the TARGET TREE's own axis, not the world origin — same reason.
	player.place(axis - stand_off * 5.0 + Vector3(0.0, start.y, 0.0),
		axis + Vector3(0.0, 0.6, 0.0))
	player.capture_mouse()   # no-op headless; the walk is gated on the mouse being held
	var from_axis := Vector2(player.global_position.x - axis.x,
		player.global_position.z - axis.z).length()
	_key(KEY_W, true)
	for i in range(300):
		await get_tree().physics_frame
	_key(KEY_W, false)
	var gap := Vector2(player.global_position.x - axis.x,
		player.global_position.z - axis.z).length()
	_check(gap < from_axis - 0.5,
		"holding W walks the player toward the tree (%.2f m out, from %.2f)" % [gap, from_axis])
	# Stopped by TIMBER, at about its own radius clear of the bark. `_WALK_MASK` includes
	# TIMBER_LAYER, so the trunk is solid; the tolerance is loose because the capsule
	# meets a carved, faceted trunk rather than a cylinder.
	_check(gap > target.radius and gap < target.radius + player.body_radius + 0.5,
		"...and is stopped by the trunk, standing clear of it (%.2f m out, trunk radius %.2f)" % [
			gap, target.radius])

	print("=== FPS SMOKE: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== FPS SMOKE OK ===")
	get_tree().quit()
