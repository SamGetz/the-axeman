class_name ForestPlayer
extends CharacterBody3D
## FILE: res://scenes/3d_action/forest_player.gd
## ATTACHES TO: the root CharacterBody3D of res://scenes/3d_action/forest_player.tscn.
## Requires the child nodes Body (CollisionShape3D) and Head/Camera3D.
##
## THE PLAYER, ON FOOT. WASD, mouse look, gravity, and a camera at eye height —
## the first-person half of `handoff/08_FPS_FOREST.md` §1. Creative Director
## direction, 2026-07-26: *"I want this to be an fps game now, where you walk
## through a forest and chop down trees."*
##
## It knows nothing about chopping. `tree_felling.gd` reads `camera()` and asks it
## where the player is looking; this file never touches a tree.
##
## TWO MODES, and the second one is not a debug afterthought — it is what keeps the
## render-to-PNG workflow alive:
##
##   `active = true`  — the player drives. Mouse captured, WASD, gravity.
##   `active = false` — a PUPPET. No input, no gravity, no move_and_slide; whoever
##                      owns it calls `place()` and the body simply goes there.
##
## Every dev shot tool (`core/tools/tree_shot.gd`, `seam_shot.gd`, `seam_layers.gd`)
## frames its shot by driving `tree_felling.gd`'s `cam_distance`/`cam_height`/
## `cam_focus_y`, and that render-to-PNG loop is the ONLY thing that has ever caught
## a rendering bug in this project. Puppet mode is how those exports keep meaning
## what they meant: `TreeFelling._apply_camera()` turns them into a `place()` call
## and the old polar camera is reproduced exactly. `m5_acceptance` runs in puppet
## mode for the same reason it pins gravity and `cut_span` — so what the suite
## measures does not depend on where a player happened to be standing.
##
## GAMEFEEL IS UNAFFECTED, deliberately. It writes `h_offset`/`v_offset` on the
## camera and nothing else; those are frustum shifts, not transforms, so the trauma
## shake composes with mouse look instead of fighting it (A11 + M3). Never write the
## camera's `transform` from anywhere but here.
##
## EVERY tuning value below is a PLACEHOLDER (Directive 3) — authored as @export so
## Sam tunes it live in the inspector, never a hardcoded final.

## Collision, using the layers TreeTrunk already defines.
##
## MASK — what the player is stopped by: the ground and TIMBER (the stump, a standing
## trunk, a felled log). Deliberately NOT `DEBRIS_LAYER`: splinters already pass
## through timber by Sam's own call, 2026-07-25, and a hundred of them shoving the
## player about is all cost.
const _WALK_MASK := TreeTrunk.GROUND_LAYER | TreeTrunk.TIMBER_LAYER
## LAYER — what is stopped by the PLAYER: nothing. Timber's own mask is ground +
## timber, so a falling tree would ignore the player whatever this said; leaving it
## at zero states that on purpose rather than by accident. A tree that can crush the
## player is a design decision, not a collision-layer one.
const _PLAYER_LAYER := 0

# --- movement --------------------------------------------------------------
@export_group("Movement")
## Walking speed on flat ground (m/s).
@export var walk_speed := 3.4
## How sharply the player reaches that speed (1/s) — higher is more immediate and
## less slippery. This is most of what walking FEELS like; tune it before speed.
@export var accel := 12.0
## ...and how sharply they stop (1/s). Kept separate so the player can be given
## weight to get going without also skating to a halt.
@export var brake := 16.0
## Downward acceleration (m/s^2). Its own number rather than the project default so
## it can be tuned with the fall's `fall_gravity_scale`, which is already not 9.8.
@export var gravity := 9.8
## Terminal downward speed (m/s), so a player who walks off something does not
## accelerate for ever.
@export var max_fall_speed := 30.0

# --- look ------------------------------------------------------------------
@export_group("Look")
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity := 0.0022
## How far the player can look down (deg, negative).
@export var pitch_min_deg := -85.0
## ...and up.
@export var pitch_max_deg := 80.0
## Invert the vertical axis.
@export var invert_y := false

# --- build -----------------------------------------------------------------
@export_group("Build")
## Eye height above the player's feet (m). Written to the Head node at _ready, so
## the scene's authored value never has to agree with this one.
@export var eye_height := 1.65
## Capsule radius (m) — how close the player can get to a trunk, which is also how
## close the axe can be swung from. `TreeFelling.chop_reach` has to clear it.
@export var body_radius := 0.35
## Capsule height (m), feet to crown.
@export var body_height := 1.8

## FALSE makes this a puppet: no input, no gravity, no movement, and the mouse is
## left alone. See the header — this is what dev shot tools and m5_acceptance run in.
var active := true:
	set(value):
		active = value
		_apply_mode()

@onready var _body: CollisionShape3D = $Body
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D

var _yaw := 0.0
var _pitch := 0.0
## Whether the player is taking WASD and mouse look right now. Tracked HERE rather than
## read back off `Input.mouse_mode` every frame, because the OS cursor and the intent are
## two different things: a headless run cannot capture a cursor at all, so a controller
## gated on the real mouse mode can never be driven by a test — which is exactly how the
## walk in `core/tools/fps_smoke.gd` came to be unverifiable.
var _taking_input := true


func _ready() -> void:
	collision_layer = _PLAYER_LAYER
	collision_mask = _WALK_MASK
	_fit_body()
	_yaw = rotation.y
	_pitch = _head.rotation.x
	_apply_mode()


func _exit_tree() -> void:
	# Never leave the OS mouse captured behind a scene that has gone away — a
	# headless test that instances and drops this thing, or the A10 hand-back to 2D
	# mode, would otherwise strand the cursor.
	release_mouse()


## Size the capsule from the exports rather than trusting the .tscn, so `body_radius`
## and `eye_height` are the single answer to "how big is the player" and the shape
## cannot drift away from the numbers the chopping reach is judged against.
func _fit_body() -> void:
	var shape := _body.shape as CapsuleShape3D
	if shape == null:
		shape = CapsuleShape3D.new()
		_body.shape = shape
	else:
		# The .tscn's shape is shared with every other instance of this scene; edit a
		# copy or two players would resize each other.
		shape = shape.duplicate()
		_body.shape = shape
	shape.radius = body_radius
	shape.height = maxf(body_height, body_radius * 2.0 + 0.01)
	_body.position = Vector3(0.0, shape.height * 0.5, 0.0)
	_head.position = Vector3(0.0, eye_height, 0.0)


func _apply_mode() -> void:
	if not is_inside_tree():
		return
	set_physics_process(active)
	set_process_unhandled_input(active)
	if active:
		capture_mouse()
	else:
		velocity = Vector3.ZERO
		# A puppet must not hold the OS cursor. Parent _ready() runs AFTER its
		# children's, so tree_felling.gd hands `active = false` down to a player that
		# has already captured on its own _ready — this is where that is undone.
		release_mouse()


# ------------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _taking_input:
		var motion := (event as InputEventMouseMotion).relative
		_yaw -= motion.x * mouse_sensitivity
		_pitch += motion.y * mouse_sensitivity * (1.0 if invert_y else -1.0)
		_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
		_apply_look()
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		release_mouse()
	elif event is InputEventMouseButton and event.pressed and not _taking_input:
		# Clicking back into the window re-captures — and that click is SPENT doing so.
		# _unhandled_input runs children before parents, so without marking it handled
		# the same press would reach tree_felling.gd and swing the axe at whatever the
		# crosshair happened to be resting on while the player was in a menu.
		capture_mouse()
		get_viewport().set_input_as_handled()


func _apply_look() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)   # the BODY yaws; only the head pitches
	_head.rotation = Vector3(_pitch, 0.0, 0.0)


func capture_mouse() -> void:
	_taking_input = true
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	_taking_input = false
	if DisplayServer.get_name() == "headless":
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Is the player currently steering? False while the cursor is free (ESC), and while the
## player is a puppet.
func is_taking_input() -> bool:
	return _taking_input and active


# ----------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	var wish := Vector3.ZERO
	if _taking_input:
		# Read directly rather than through named actions: this project has no input
		# map beyond the engine defaults, and inventing one is a project.godot edit,
		# which is the clobber trap. WASD is hard-wired here on purpose and is the
		# one place to change it.
		var f := (1.0 if Input.is_key_pressed(KEY_W) else 0.0) \
			- (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
		var r := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) \
			- (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
		var basis := global_transform.basis
		wish = (basis.z * -f + basis.x * r)
		wish.y = 0.0
		if wish.length() > 0.001:
			wish = wish.normalized()

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var want := wish * walk_speed
	var rate := accel if wish.length() > 0.001 else brake
	flat = flat.lerp(want, clampf(rate * delta, 0.0, 1.0))

	var vy := velocity.y
	if is_on_floor():
		vy = minf(vy, 0.0)   # keep a little into the floor so the ground test holds
	else:
		vy = maxf(vy - gravity * delta, -max_fall_speed)

	velocity = Vector3(flat.x, vy, flat.z)
	move_and_slide()


# -------------------------------------------------------------- the camera
func camera() -> Camera3D:
	return _camera


func head() -> Node3D:
	return _head


## The ray out of the middle of the screen. `[origin, direction]`, world space.
##
## THIS IS THE AIM, and it is the whole of it (plan §2, Option A: cut where you look).
## The old screen-space aim compared a click's x against the trunk's unprojected x,
## which at a crosshair pointed straight at a trunk are always within a pixel or two
## of each other — so both the side and the ANGLE OF ENTRY would have collapsed, and
## the angle of entry is what M5 PASS 5 exists to give the player. Everything is
## taken off the 3D hit point instead.
func aim_ray() -> Array:
	if _camera == null:
		return [global_position, -global_transform.basis.z]
	var centre := _camera.get_viewport().get_visible_rect().size * 0.5
	return [_camera.project_ray_origin(centre), _camera.project_ray_normal(centre)]


## Where the eye is (world) — what a reach is measured from.
func eye_position() -> Vector3:
	return _camera.global_position if _camera != null else global_position


# ------------------------------------------------------------ puppet seam
## Stand the player at `origin` looking at `target`. Only meaningful with
## `active == false`; the yaw/pitch it sets are picked back up if control is handed
## over afterwards, so a dev tool can frame a shot and then let the player walk from
## exactly there.
func place(origin: Vector3, target: Vector3) -> void:
	global_position = origin
	velocity = Vector3.ZERO
	# Aimed from the EYE, not from `origin` — `origin` is the player's FEET. Aiming
	# from the feet pitches the camera up by the angle the eye height subtends, which
	# on the dev camera (1.65 m up, 2.5 m out, looking at 0.6 m) is 13 degrees of look
	# that the shot tools never asked for and the crosshair sails right over the tree.
	var to := target - (origin + Vector3(0.0, _head.position.y, 0.0))
	if to.length() < 0.0001:
		return
	_yaw = atan2(-to.x, -to.z)
	_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()),
		deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	_apply_look()
	force_update_transform()
	_head.force_update_transform()
	_camera.force_update_transform()
