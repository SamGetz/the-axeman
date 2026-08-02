class_name AxeViewmodel
extends Node3D
## FILE: res://scenes/3d_action/axe_viewmodel.gd
## ATTACHES TO: AxeViewmodelAnchor (Node3D), a CHILD OF THE CHOPPING CAMERA in
## res://scenes/3d_action/chopping_minigame.tscn. Its own children are fixed:
##
##   Camera3D
##   └── AxeViewmodelAnchor      (this script — fixed to the camera, aims the swing)
##       ├── AxeAnimationRoot    (Node3D — the ONLY node the animation moves)
##       │   └── axe_basic       (the imported FBX; scale lives here)
##       └── AnimationPlayer     (plays "swing" from res://data/axe_swing_lib.tres)
##
## REPLACES `axe_rig.gd` (deleted 2026-08-02, recoverable from git). That rig flew
## a world-space axe from the impact point to the wood on a hand-built Bezier with
## two euler poses, all of it hardcoded in script — which is why the swing read as
## clunky and why there was no way to tune it without editing GDScript. This is a
## VIEWMODEL: the axe is bolted to the camera and swings in the camera's own space,
## so it reads as the player's own overhead chop, and the entire motion is an
## AnimationPlayer track Sam can scrub, re-key and re-time in the editor.
##
## THE ANIMATION OWNS THE TIMING, INCLUDING THE GAMEPLAY BEAT. `swing` carries a
## METHOD TRACK whose key calls `_on_swing_contact()` on this node at the frame the
## blade bites; that emits `contact`, and the mini-game resolves the split or the
## scar there. So moving the contact key in the editor moves when the wood breaks —
## the picture and the mechanic cannot drift apart, which is exactly what they did
## when the axe was tweened for `swing_time` (1.0 s in the scene) while the split
## fired off a separate `anticipation_sec` timer (0.1 s): the log came apart while
## the axe was still up in the air.
##
## The method key is called DEFERRED (AnimationMixer's default callback mode). The
## split adds and frees nodes, and doing that from inside the mixer's own process
## is asking for trouble; one frame of slack costs nothing a player can see.
##
## FAILSAFE, and it is load-bearing: the mini-game does NOT trust this signal to
## arrive. `contact` is emitted by a key in an editable data file, so an animation
## re-keyed without one would leave a strike pending forever and soft-lock the
## chop loop. `contact_time()` lets the caller arm its own deadline — see
## chopping_minigame._strike_timeout().

## The frame the blade bites. The mini-game resolves the strike here.
signal contact
## The whole swing, recovery included, is over and the axe is out of frame again.
signal swing_finished

## Name of the swing in the AnimationPlayer's library. The method track inside it
## is what fires `contact`; see res://core/tools/build_axe_swing.gd.
@export var swing_anim := &"swing"

@export_group("Aim")
## The anchor is "fixed to the camera" in the sense that it never leaves it — but
## a swing that lands in the same pixel however far off-centre you clicked reads
## as a cutscene rather than as your own axe. These lean the WHOLE rig toward the
## click before the animation plays, so the authored motion is never touched.
## PLACEHOLDERS (Directive 3) — set both to 0 for a rigidly fixed viewmodel.
@export var aim_yaw_deg := 6.0
@export var aim_pitch_deg := 4.0

@onready var _root: Node3D = $AxeAnimationRoot
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _speed := 1.0


func _ready() -> void:
	# Out of frame until asked for. The animation's rest pose already parks the axe
	# off-screen, but hiding it means a half-authored or missing animation can never
	# leave an axe floating in the middle of the yard.
	if _root != null:
		_root.visible = false
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)


## Play the swing. `aim` is the click in normalised screen coordinates — (0,0) is
## the centre of the frame, x right, y UP, roughly +/-1 at the edges.
func swing(aim := Vector2.ZERO) -> void:
	if _anim == null or not _anim.has_animation(swing_anim):
		push_warning("AxeViewmodel: no '%s' animation — the swing will not play." % swing_anim)
		return
	_apply_aim(aim)
	if _root != null:
		_root.visible = true
	_anim.speed_scale = _speed
	_anim.play(swing_anim)
	_anim.seek(0.0, true)   # true = update now, so frame one is the rest pose


## How much faster than authored the swing plays. The mini-game drives this off
## the swing-speed skill so "5% faster between swings" speeds up the SWING, not
## just a dead wait after it — an upgrade you can see is worth more than one you
## can only measure.
func set_speed(speed: float) -> void:
	_speed = maxf(speed, 0.01)
	if _anim != null and _anim.is_playing():
		_anim.speed_scale = _speed


func is_swinging() -> bool:
	return _anim != null and _anim.is_playing()


## Authored length of the whole swing, in seconds, at the CURRENT speed.
func swing_duration() -> float:
	if _anim == null or not _anim.has_animation(swing_anim):
		return 0.0
	return _anim.get_animation(swing_anim).length / _speed


## When the blade bites, in seconds from the start of the swing, at the CURRENT
## speed. -1.0 if the animation carries no contact key at all — which the caller
## must treat as "this animation cannot resolve a strike", not as "time zero".
func contact_time() -> float:
	var t := _authored_contact_time()
	return -1.0 if t < 0.0 else t / _speed


func has_contact_key() -> bool:
	return _authored_contact_time() >= 0.0


## THE METHOD TRACK'S TARGET. Renaming it renames the key in
## res://data/axe_swing_lib.tres, and m4_acceptance checks the two still agree.
func _on_swing_contact() -> void:
	contact.emit()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != swing_anim:
		return
	if _root != null:
		_root.visible = false
	swing_finished.emit()


func _apply_aim(aim: Vector2) -> void:
	# Rotating about the camera's own axes: yaw NEGATIVE swings the rig toward
	# screen right, pitch follows aim.y directly (a low click aims low).
	var a := Vector2(clampf(aim.x, -1.0, 1.0), clampf(aim.y, -1.0, 1.0))
	rotation = Vector3(deg_to_rad(a.y * aim_pitch_deg), deg_to_rad(-a.x * aim_yaw_deg), 0.0)


## Walks the method track for the key that calls `_on_swing_contact`. Read off the
## animation rather than stored, for the same reason the level is derived from XP:
## a value copied out of a data file is a value that can disagree with it, and this
## one is edited by hand in the animation editor.
func _authored_contact_time() -> float:
	if _anim == null or not _anim.has_animation(swing_anim):
		return -1.0
	var anim := _anim.get_animation(swing_anim)
	for track in range(anim.get_track_count()):
		if anim.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in range(anim.track_get_key_count(track)):
			if anim.method_track_get_name(track, key) == &"_on_swing_contact":
				return anim.track_get_key_time(track, key)
	return -1.0
