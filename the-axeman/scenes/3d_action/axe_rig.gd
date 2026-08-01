class_name AxeRig
extends Node3D
## FILE: res://scenes/3d_action/axe_rig.gd
## ATTACHES TO: nothing in a .tscn — the mini-games create one in code
## (`AxeRig.new()` then `add_child`) and drive it through `swing()`.
##
## The swinging axe, lifted out of M4's chopping_minigame.gd so M5 (and M6's
## pickaxe later) get the identical motion instead of a second copy. The rig is
## hidden until a swing starts: it drops in above the impact point, chops down
## to it, retracts and hides again — the reference chopper's playFromImpact.
##
## The travel is an ARC, not a straight line: the head sweeps out through a
## control point offset to the side of the direct path, so the swing reads as
## coming round from the player's shoulder rather than stabbing in. `arc_bulge`
## is how far out it bows; 0 gives the old straight line.
##
## Two swings:
##   * swing()        — a connecting hit.
##   * swing_denied() — a BOUNCE: the axe stops short of the wood and recoils,
##     for M5's gear gate (axe tier below the tree's hardness_level). Same
##     timing, shorter travel, so an under-tier hit reads as "that didn't bite"
##     without a separate animation.
##
## All motion values are supplied by the owning mini-game (they are that
## scene's exported placeholders — Directive 3), never authored here.

var hidden_euler := Vector3(-1.1, 0.0, 0.15)
var struck_euler := Vector3(0.15, 0.0, 0.1)
var hover := 0.45          # how far along `approach` the swing starts (m)
var swing_time := 0.16     # seconds for the full down+up motion
var denied_stop_frac := 0.55   # a denied swing only travels this far toward the wood
## Extra yaw applied to both poses. M4 chops a log lying on a block from
## overhead, so its swing plane never needs turning and it leaves this at 0; M5
## chops the side of a standing trunk, so it faces the rig along the swing.
var yaw := 0.0
## Which way the axe comes FROM, as a unit direction out of the impact point.
## Straight up for an overhead chop (M4); leaned back toward the player for a
## swing into a trunk (M5).
var approach := Vector3.UP
## How far the travel bows out of the straight line, in metres, and which way.
## M5 bows it around the side the swing comes from so it sweeps in.
var arc_bulge := 0.0
var arc_dir := Vector3.ZERO

var _tween: Tween


## Build the visual. `model` is the imported axe scene; `model_scale` its scale.
func setup(model: PackedScene, model_scale: float) -> void:
	visible = false
	if model == null:
		return
	var axe := model.instantiate()
	axe.scale = Vector3.ONE * model_scale
	add_child(axe)


## Chop down onto `world_point` and retract.
func swing(world_point: Vector3) -> void:
	_play(world_point, 1.0)


## Bounce off `world_point` without reaching it (gear gate denial).
func swing_denied(world_point: Vector3) -> void:
	_play(world_point, denied_stop_frac)


func _play(world_point: Vector3, reach: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var from_dir := approach if approach.length() > 0.0001 else Vector3.UP
	var start := world_point + from_dir.normalized() * hover
	var end := start.lerp(world_point, reach)
	var rest_rot := _pose(hidden_euler)
	var end_rot := rest_rot.lerp(_pose(struck_euler), reach)
	# Bezier control point: pushed out of the straight line so the head sweeps.
	var ctrl := start.lerp(end, 0.5) + _bulge() * reach
	visible = true
	global_position = start
	rotation = rest_rot

	var down := swing_time * 0.4
	var up := swing_time * 0.6
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(func(t: float): global_position = _arc(start, ctrl, end, t),
		0.0, 1.0, down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "rotation", end_rot, down) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain()
	_tween.tween_method(func(t: float): global_position = _arc(start, ctrl, end, 1.0 - t),
		0.0, 1.0, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation", rest_rot, up) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func(): visible = false)


func _bulge() -> Vector3:
	if arc_bulge <= 0.0 or arc_dir.length() < 0.0001:
		return Vector3.ZERO
	return arc_dir.normalized() * arc_bulge


static func _arc(a: Vector3, ctrl: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)   # quadratic Bezier


func _pose(euler: Vector3) -> Vector3:
	return Vector3(euler.x, euler.y + yaw, euler.z)
