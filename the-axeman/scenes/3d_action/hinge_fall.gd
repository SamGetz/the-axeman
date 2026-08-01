class_name HingeFall
extends RefCounted
## FILE: res://scenes/3d_action/hinge_fall.gd
## ATTACHES TO: nothing — tree_felling.gd creates one when a tree lets go.
##
## THE FIRST HALF OF A TREE COMING DOWN: the part where it is still attached.
##
## A felled tree does not get pushed over, and for the first sixty degrees it is
## not a free body either — it is hanging off the holding wood, rotating about
## the hinge while the fibres tear. That is the whole drama of felling: nothing,
## nothing, a creak, and then it is going and cannot be stopped. So that part is
## integrated here, about the real hinge line, and only once it is unmistakably
## committed does tree_felling hand the trunk to the physics engine.
##
## The torque is gravity's, on the real moment arm:
##     arm(θ) = (rot(θ) · r0) · fall_direction
## where `r0` is the offset from the hinge to the centre of mass at the moment it
## let go. At θ = 0 that arm is whatever the notch and the tree's own lean left
## hanging over the hinge — so the fall STARTS on its own, from the cut, with no
## impulse anywhere. It is tiny, which is why the first second is agonising, and
## it grows with sin(θ), which is why the end is violent. Nothing about that
## curve is authored.
##
## The holding wood fights back until it tears: `hold` is a constant resisting
## moment that fades to nothing over `tear_angle`. That is the creak.
##
## This SUPERSEDES the old "spin it about the hinge axis and let Jolt sort it
## out" release (Amendment 11's implementation, not its principle): a rigid body
## spun off a stump slid, jammed on the stump at ~25 degrees, and had to be
## nursed with a fake shove. Attached rotation cannot do any of those things.

var angle := 0.0            ## radians from where it stood when the hinge went
var omega := 0.0            ## rad/s
var pivot := Vector3.ZERO   ## the hinge line's world position
var axis := Vector3.UP      ## ...and its world direction (horizontal)
var fall_dir := Vector3.RIGHT

var mass := 1.0             ## kg of tree coming down
var inertia := 1.0          ## kg·m² about the hinge line
var r0 := Vector3.ZERO      ## hinge -> centre of mass, at the moment it let go
var hold := 0.0             ## resisting moment of the holding wood (N·m)
var tear_angle := 0.44      ## ...which fades to nothing over this many radians
var release_angle := 0.96   ## hand over to physics here


## Set the tree up to go. `com` is the world centre of mass, `length` how much
## tree is above the hinge; the inertia is a uniform rod about its end, which is
## what a trunk is to within far less than the strengths are guessed at.
func setup(pivot_world: Vector3, direction: Vector3, com: Vector3, body_mass: float,
		length: float) -> void:
	pivot = pivot_world
	fall_dir = Vector3(direction.x, 0.0, direction.z).normalized()
	if fall_dir.length() < 0.0001:
		fall_dir = Vector3.RIGHT
	axis = Vector3.UP.cross(fall_dir).normalized()
	mass = maxf(body_mass, 0.01)
	r0 = com - pivot
	inertia = maxf(mass * length * length / 3.0, 0.01)
	angle = 0.0
	omega = 0.0


## Advance one step. Returns the current rotation about the hinge.
func step(delta: float, gravity: float) -> Basis:
	var rot := Basis(axis, angle)
	var arm := (rot * r0).dot(fall_dir)
	var torque := mass * gravity * arm
	# The holding wood tears as it bends: full resistance at the moment it let
	# go, nothing left by `tear_angle`. It only ever opposes the fall.
	var resist := hold * maxf(1.0 - angle / maxf(tear_angle, 0.0001), 0.0)
	omega += (torque - resist) / inertia * delta
	omega = maxf(omega, 0.0)   # it does not stand back up
	angle += omega * delta
	return Basis(axis, angle)


## True once the fibres have all let go.
func torn() -> bool:
	return angle >= tear_angle


## True once it is committed far enough that physics can take it without the
## butt catching on the stump.
func done() -> bool:
	return angle >= release_angle


## The velocity of a point that is rigidly rotating with the trunk — what the
## rigid body has to be handed so the transition is seamless.
func velocity_at(world_point: Vector3) -> Vector3:
	return (axis * omega).cross(world_point - pivot)


## Where the centre of mass is now.
func com_world() -> Vector3:
	return pivot + Basis(axis, angle) * r0


## How far over it has gone, in degrees.
func tilt_deg() -> float:
	return rad_to_deg(angle)
