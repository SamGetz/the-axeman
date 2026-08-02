extends SceneTree
## FILE: res://core/tools/build_axe_swing.gd
## ATTACHES TO: nothing — a SceneTree dev tool, run with -s. Not shipped.
##
## Authors the DEFAULT overhead axe swing and writes it to
## res://data/axe_swing_lib.tres (an AnimationLibrary holding "swing", "bounce"
## and "RESET").
##
##   godot --headless --path . -s res://core/tools/build_axe_swing.gd
##
## WHY A GENERATOR AND NOT A HAND-WRITTEN .tres: a rotation_3d track stores
## QUATERNIONS. Nobody should be typing those, and nobody can read them back to
## check them. Here a pose is written the way it is actually thought about — where
## the player's hand is, which way the handle points, how the blade is rolled — and
## the quaternion falls out of it.
##
## *** THIS IS A DEFAULT-BUILDER, NOT A BUILD STEP. *** Once Sam has re-keyed the
## swing in the animation editor, running this AGAIN OVERWRITES HIS TUNING. It is
## here to (re)generate a sane starting pose set, and to document how the shipped
## one was derived. Every number in `_KEYS` is a PLACEHOLDER per Directive 3.
##
## COORDINATES ARE CAMERA SPACE. The rig hangs off Camera3D and AxeViewmodelAnchor
## is identity, so +X is screen right, +Y is screen up and -Z is into the screen.
## The chopping camera is pitched 32.7 deg DOWN, which is the thing to keep hold of
## while reading the poses below: an axe falling "down" onto the block travels
## mostly INTO THE SCREEN, not down it. Measured, so the poses aim at something
## real (core/tools/_tmp_axe_probe.gd, since deleted):
##
##   camera origin (0, 1.463, 1.004), forward (0, -0.540, -0.842)
##   top of a standing log  ->  camera space (0, 0.085, -1.14)
##   top of the stump       ->  camera space (0, -0.269, -1.37)
##
## THE AXE MODEL'S OWN AXES (measured with core/tools/inspect_fbx.gd):
## axe_basic.fbx sits with its ORIGIN AT THE BUTT OF THE HANDLE, running +Y up the
## handle to 0.502 m, with the head poking out along +Z. The origin being the grip
## is a gift — rotating AxeAnimationRoot pivots the axe about the player's hand.
## At the scene's authored 1.4 scale the axe is `_AXE_LEN` long.

const _OUT := "res://data/axe_swing_lib.tres"
const _AXE_LEN := 0.702        # 0.502 m of axe at chopping_minigame.tscn's 1.4 scale
const _CONTACT_METHOD := &"_on_swing_contact"
const _TARGET := "AxeAnimationRoot"

## The swing, beat by beat. `grip` is where the player's hand is; `handle` is the
## direction the handle points (the head sits _AXE_LEN along it). The roll about
## the handle is not authored — see `_pose`.
##
## TWO RULES THESE POSES OBEY, both learned from rendering the first pass
## (core/tools/axe_shot.tscn), because both are invisible in the numbers:
##
##  1. THE GRIP MOVES; THE HEAD IS WHAT SWINGS. The first pass drove the head from
##     0.27 m to 1.15 m from the lens in 0.09 s, and a 4x change in apparent size
##     reads as the axe shrinking away from you, not as a chop. The head's depth
##     now stays in a band, and the swing is sold by its ARC ACROSS THE FRAME.
##  2. THE HANDLE BUTT IS NEVER ON SCREEN. A whole axe on screen is a prop lying
##     in a field — the second pass put the butt end floating mid-frame and it read
##     as a fence post. `_report` prints the grip's screen position for every key
##     for exactly this reason: it is a rule to check, not to hope for.
##
## THERE IS NO WINDUP IN FRAME (Creative Director call, 2026-08-02: *"the axe can
## just swing down from off screen, we dont need to see it rise in to frame, it
## looks weird"*). The raise happened off-camera; the swing STARTS already raised,
## parked past the right edge over the player's shoulder, and the first thing the
## player sees is the head already coming down. Which is also why the whole motion
## is 0.46 s with contact at 0.18 s — deleting the raise took the dead time at the
## front of a click with it.
const _KEYS: Array[Dictionary] = [
	# RAISED, AND ENTIRELY OFF THE RIGHT OF THE FRAME. Grip and head both project
	# past x = 1, so nothing is on screen — the swing has no visible beginning.
	{"t": 0.00, "grip": Vector3(0.66, -0.56, -0.45), "handle": Vector3(0.30, 0.93, 0.21)},
	# ENTERING: the head crosses the right edge, already travelling.
	{"t": 0.06, "grip": Vector3(0.56, -0.56, -0.48), "handle": Vector3(0.16, 0.92, -0.36)},
	# CONTACT — the head lands on the TOP FACE of the log, centre of frame, hands
	# driven down and forward. This is the frame the method key sits on, and it is
	# the pose to check first in axe_shot: the first pass landed the blade on the
	# log's shoulder, which is not where the cut plane or the failure scar goes.
	{"t": 0.18, "grip": Vector3(0.18, -0.58, -0.72), "handle": Vector3(-0.24, 0.85, -0.47)},
	# FOLLOW-THROUGH: the head carries on past the wood and drops below it.
	{"t": 0.24, "grip": Vector3(0.16, -0.60, -0.62), "handle": Vector3(-0.30, 0.52, -0.80)},
	# RECOVERY back out past the right edge, ready for the next click.
	{"t": 0.46, "grip": Vector3(0.66, -0.56, -0.45), "handle": Vector3(0.30, 0.93, 0.21)},
]
const _CONTACT_T := 0.18
const _LENGTH := 0.46

## The swing happens in the plane whose normal is this — the camera's own right,
## which is also the cut normal every click produces (chopping_minigame._on_click
## reads the plane off `_camera.global_transform.basis.x`). Used to roll the head
## so its EDGE leads the travel: an axe that arrives flat-side-first is a mallet.
const _SWING_PLANE_NORMAL := Vector3.RIGHT


func _init() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"swing", _build_swing())
	lib.add_animation(&"bounce", _build_bounce())
	lib.add_animation(&"RESET", _build_reset())
	var err := ResourceSaver.save(lib, _OUT)
	if err != OK:
		printerr("FAILED to write %s (error %d)" % [_OUT, err])
	else:
		print("wrote %s — swing %.2fs, contact at %.2fs, %d pose keys"
			% [_OUT, _LENGTH, _CONTACT_T, _KEYS.size()])
		_report()
	quit()


func _build_swing() -> Animation:
	var anim := Animation.new()
	anim.resource_name = "swing"
	anim.length = _LENGTH
	anim.loop_mode = Animation.LOOP_NONE
	anim.step = 0.01        # a hundredth-second grid to key on in the editor

	var pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos, NodePath(_TARGET))
	# CUBIC, not linear: linear between six poses reads as six separate moves, which
	# is the "clunky" being fixed here. The overshoot cubic gives on the reversal at
	# the top of the swing is wanted, not tolerated.
	anim.track_set_interpolation_type(pos, Animation.INTERPOLATION_CUBIC)

	var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot, NodePath(_TARGET))
	anim.track_set_interpolation_type(rot, Animation.INTERPOLATION_CUBIC)

	for k: Dictionary in _KEYS:
		anim.position_track_insert_key(pos, k.t, k.grip)
		anim.rotation_track_insert_key(rot, k.t, _pose(k.handle))

	# THE GAMEPLAY BEAT. Path "." is the AnimationPlayer's root_node, which is the
	# anchor (AnimationPlayer.root_node defaults to ".." — its own parent), so this
	# calls AxeViewmodel._on_swing_contact and the mini-game splits the wood there.
	var method := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(method, NodePath("."))
	anim.track_insert_key(method, _CONTACT_T, {"method": _CONTACT_METHOD, "args": []})
	return anim


## A failed strike reaches the SAME contact pose, then springs back through the
## overhead approach instead of using the successful below-the-log follow-through.
## The contact/entry/raised poses come from `_KEYS`, so regenerating the default
## library cannot produce a bounce whose first frame disagrees with its swing.
func _build_bounce() -> Animation:
	var anim := Animation.new()
	anim.resource_name = "bounce"
	anim.length = 0.32
	anim.loop_mode = Animation.LOOP_NONE
	anim.step = 0.01

	var pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos, NodePath(_TARGET))
	anim.track_set_interpolation_type(pos, Animation.INTERPOLATION_CUBIC)
	var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot, NodePath(_TARGET))
	anim.track_set_interpolation_type(rot, Animation.INTERPOLATION_CUBIC)

	var source: Array[Dictionary] = [_KEYS[2], _KEYS[1], _KEYS[0], _KEYS[4]]
	var times: Array[float] = [0.0, 0.07, 0.14, 0.30]
	for i in range(source.size()):
		anim.position_track_insert_key(pos, times[i], source[i].grip)
		anim.rotation_track_insert_key(rot, times[i], _pose(source[i].handle))
	return anim


## The pose the editor restores, and what the axe holds when nothing is swinging.
func _build_reset() -> Animation:
	var anim := Animation.new()
	anim.resource_name = "RESET"
	anim.length = 0.001
	var rest: Dictionary = _KEYS[0]
	var pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos, NodePath(_TARGET))
	anim.position_track_insert_key(pos, 0.0, rest.grip)
	var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot, NodePath(_TARGET))
	anim.rotation_track_insert_key(rot, 0.0, _pose(rest.handle))
	return anim


## Turn "the handle points this way" into the rotation the track stores.
##
## Y is the handle: the model runs +Y from the grip to the head. Z is the way the
## head faces (measured — the blade pokes out along the model's +Z), and it is
## DERIVED rather than authored: `handle x plane_normal` is perpendicular to the
## handle, lies in the swing plane, and points along the travel, so the edge leads
## the whole way round the arc and the roll never jumps between two keys. Authoring
## it per pose was tried first and produced a spin, because "which way is the edge
## facing" flips sense as the handle passes vertical.
##
## X = Y x Z closes a right-handed basis (check: (Y x Z) x Y = Z).
static func _pose(handle: Vector3) -> Quaternion:
	var y := handle.normalized()
	var z := y.cross(_SWING_PLANE_NORMAL)
	if z.length() < 0.001:
		# Handle parallel to the plane normal — no swing plane to speak of. Any
		# square direction will do; nothing is being cut in this pose.
		z = Vector3.FORWARD - y * y.dot(Vector3.FORWARD)
	z = z.normalized()
	return Basis(y.cross(z), y, z).get_rotation_quaternion()


## Where the grip and the head land ON SCREEN at each beat. The poses are authored
## as a hand position plus a direction, so without this there is no way to see what
## the player sees short of opening the editor — and it is what enforces rule 2:
## a grip inside the frame is a floating handle butt, and gets flagged here.
## Screen coords are -1..1 from centre, for the scene's 75 deg vertical FOV at 16:9.
func _report() -> void:
	for k: Dictionary in _KEYS:
		var head: Vector3 = k.grip + k.handle.normalized() * _AXE_LEN
		var g := _screen(k.grip)
		var h := _screen(head)
		var note := ""
		if is_equal_approx(k.t, _CONTACT_T):
			note = "   <- CONTACT"
		if absf(g.x) <= 1.0 and absf(g.y) <= 1.0:
			note += "   ** GRIP IS ON SCREEN (floating handle butt) **"
		print("  t=%.2f  grip screen (%+.2f, %+.2f)  head screen (%+.2f, %+.2f) at %.2fm%s"
			% [k.t, g.x, g.y, h.x, h.y, absf(head.z), note])


static func _screen(p: Vector3) -> Vector2:
	var tan_half := tan(deg_to_rad(75.0) * 0.5)
	var depth := absf(p.z)
	if depth < 0.001 or p.z > 0.0:
		return Vector2(INF, INF)     # behind the lens; no meaningful projection
	return Vector2(p.x / (depth * tan_half * (16.0 / 9.0)), p.y / (depth * tan_half))
