extends RigidBody3D
## FILE: res://scenes/3d_action/fragment_piece.gd
## ATTACHES TO: root RigidBody3D of fragment_piece.tscn.
##
## One fallen fragment. Driven entirely by a FragmentDef (A2 — pre-authored
## meshes, no runtime geometry ops). Reports when it settles — on physics
## sleep OR a settle-timeout backstop (Jolt does not always report sleep) —
## then freezes STATIC (A12). Collection reads `def.yield_item`.
##
## A SETTLED PIECE IS ALWAYS RESTING ON SOMETHING (added 2026-07-25). Freezing is
## how this project retires a body, and it used to freeze the piece exactly where
## it was — which is right when the piece has gone to sleep on the ground and
## wrong the other two times it happens. The settle TIMEOUT fires on a whole clock
## whether or not the piece has landed, and A12's budget force-settles the OLDEST
## ACTIVE body the moment a new one would break the 24-body cap. M5 breaks that cap
## routinely (five bodies per blow, and the hinge tear spits fourteen a second), so
## splinters were being frozen in mid-flight and left hanging in the air around the
## stump. `_come_to_rest` sweeps the piece down onto whatever is under it first, so
## the cap can retire a body without leaving it hanging.
##
## And it CONFIRMS that for a while afterwards, because one sweep is not enough:
## the thing a piece came to rest on can itself leave. Splinters retired near the
## stump were resting on the falling trunk as it swept past them and were left
## standing in the air half a metre up when it had gone. So a settled piece re-runs
## the sweep a few times over the next couple of seconds and stops as soon as it is
## genuinely touching something — which is the first check for nearly all of them.

signal settled(piece)

## How far down a piece will look for a surface to rest on when it is retired in
## mid-air (m). Debris in these mini-games is thrown a couple of metres at the most,
## so this is already generous — and it must NOT be huge, or a piece that has somehow
## got out of the world "lands" on whatever unrelated junk is tens of metres below it
## and gets marched further down on every confirm.
const _MAX_DROP := 5.0
## Below this height a piece has left the world and is deleted (m). Bodies spawned
## inside the stump or the trunk are occasionally pushed out downwards by the solver,
## through the ground, and then fall for ever — holding an A12 budget slot, never
## sleeping, and never coming to rest. There is nothing to be done with a piece that
## is under the map except be rid of it.
var void_y := -3.0
## How many times a settled piece re-checks that it is still resting on something,
## and how long it waits between tries (s). Cheap: a piece that is already touching
## something spends exactly one shape query and stops.
## Eight tries three quarters of a second apart — six seconds of watching, which
## comfortably outlasts a felled trunk shifting as it beds down, the slowest support
## there is. One cheap shape query each, and only while the piece has not been
## confirmed resting, so the whole clearing's worth costs a few hundred microseconds
## a second and none of it lands inside a blow.
const _REST_CONFIRMS := 8
const _REST_INTERVAL := 0.75
## Thinnest a mesh may be in any dimension and still get a convex-hull collider (m).
## Jolt shrinks a convex hull by its collision margin (0.04 m) before building it, so
## anything under about twice that collapses to nothing and the shape fails. Below
## this a piece gets a box instead, which is a Jolt PRIMITIVE and works at any size.
const _MIN_HULL_THICKNESS := 0.09
## A piece retired in mid-air whose long axis is within this of vertical is laid down
## flat before it is frozen (degrees from upright).
##
## Debris that was force-settled keeps whatever pose it happened to be tumbling in, and
## when that pose is "on end" the result is a splinter standing upright in the dirt like
## a nail — several per felling, and they read as a bug rather than as debris. A stick
## balanced on its end would fall over, so laying it down is the physical answer as well
## as the tidy one. Pieces that fell asleep on their own are left exactly as they are:
## the solver found those poses, so they are real.
const _STANDING_DEG := 40.0

var def: FragmentDef

var _settle_timeout := 2.0
var _age := 0.0
var _is_settled := false
var _confirms_left := 0
var _confirm_in := 0.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	sleeping_state_changed.connect(_on_sleeping_state_changed)


## Must be called right after add_child (nodes are ready by then).
func setup(fragment_def: FragmentDef, settle_timeout: float) -> void:
	def = fragment_def
	_settle_timeout = settle_timeout
	if def != null and def.mesh != null:
		_mesh.mesh = def.mesh
		# Derive a box collider from the mesh AABB — cheap and predictable.
		var aabb := def.mesh.get_aabb()
		var box := BoxShape3D.new()
		box.size = aabb.size
		_shape.shape = box
		_shape.position = aabb.position + aabb.size * 0.5


## Runtime-sliced piece (Amendment 6, M4): drive from a raw mesh with a convex
## collider instead of a FragmentDef. `def` stays null (no authored yield).
##
## A convex hull is the right shape for a carved chip, but only a big enough one.
## Jolt shrinks a hull by its collision margin before building it, so a small chip —
## one voxel of a 0.055 m field, or a 0.018 m splinter — collapses and the build
## FAILS ("Could not find a suitable initial triangle because its area was too
## small"). The shape is then left unusable, and a piece with no working collider
## does not settle on the ground at all: it falls straight through and keeps going.
##
## Small pieces get a box off the mesh bounds instead. A box is a Jolt primitive
## rather than a hull, so it needs no margin and works at any size — and at splinter
## scale a box IS the shape, since that is what _stick_mesh builds.
## COLLISION SHAPES ARE CACHED PER MESH, and shared between every piece using it.
##
## `create_convex_shape()` runs a hull build — mesh arrays out, QuickHull, a new resource —
## and the retired tree game spawned about twelve chips per blow off a splinter mesh table
## with THREE entries in the whole game. So it was building the same three hulls twelve
## times a blow, for ever. MEASURED as the single largest slice of a blow's cost.
##
## A Shape3D is shareable by design: the per-body part is the CollisionShape3D's transform,
## which is still set per piece below. Keyed by the mesh's own instance id, so two pieces
## only share when they are genuinely the same mesh resource.
static var _shape_cache: Dictionary = {}


## Drop every cached shape. Call when a scene that built meshes of its own is torn down,
## or the cache holds them alive for the rest of the session.
static func clear_shape_cache() -> void:
	_shape_cache.clear()


func setup_mesh(m: Mesh, settle_timeout: float) -> void:
	_settle_timeout = settle_timeout
	if m == null:
		return
	_mesh.mesh = m
	var key := m.get_instance_id()
	var hit: Array = _shape_cache.get(key, [])
	if not hit.is_empty():
		_shape.shape = hit[0]
		_shape.position = hit[1]
		return
	var aabb := m.get_aabb()
	var shape: Shape3D
	var at := Vector3.ZERO
	if minf(aabb.size.x, minf(aabb.size.y, aabb.size.z)) >= _MIN_HULL_THICKNESS:
		shape = m.create_convex_shape()
	else:
		# Jolt shrinks a hull by its margin first, so a one-voxel chip or an 18 mm
		# splinter collapses and the piece gets no collider at all. A box is a Jolt
		# primitive and needs no margin.
		var box := BoxShape3D.new()
		box.size = aabb.size
		shape = box
		at = aabb.position + aabb.size * 0.5
	_shape_cache[key] = [shape, at]
	_shape.shape = shape
	_shape.position = at


func _physics_process(delta: float) -> void:
	if global_position.y < void_y:
		queue_free()   # out of the world — see void_y
		return
	if _is_settled:
		# Keep an eye on it for a beat: whatever it settled against may move off.
		if _confirms_left > 0:
			_confirm_in -= delta
			if _confirm_in <= 0.0:
				_confirm_in = _REST_INTERVAL
				_confirms_left -= 1
				_come_to_rest()
			return
		# NOTHING LEFT TO WATCH, SO STOP BEING CALLED. A settled piece is frozen STATIC:
		# it cannot move, cannot fall out of the world, and has finished confirming what
		# it is resting on. Leaving it processing costs a scripted call per physics tick
		# for the rest of the scene's life, and a felling leaves a lot of them lying
		# about — this was a hundred and fifty calls per tick by the end of one.
		set_physics_process(false)
		return
	_age += delta
	if _age >= _settle_timeout:
		_settle()


func _on_sleeping_state_changed() -> void:
	if sleeping and not _is_settled:
		_settle()


## Force this piece to settle now (used by the A12 budget when over cap).
func force_settle() -> void:
	_settle()


func _settle() -> void:
	if _is_settled:
		return
	_is_settled = true
	_come_to_rest()
	# Watch it either way. "It cannot move down" is not the same as "it is resting on
	# something that will still be there in a second": a splinter retired while it was
	# bedded INTO the falling trunk cannot move down at all, reports itself perfectly
	# settled, and is left standing in the air once the trunk has rotated away. That
	# was the last case of floating debris left, and it is why this is unconditional.
	_confirms_left = _REST_CONFIRMS
	_confirm_in = _REST_INTERVAL
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	settled.emit(self)


## Put the piece down before it is frozen. Sweeps its own collider straight down
## through the world and moves it as far as it can go without penetrating
## anything, so it ends up resting on the ground (or on the stump, or on the
## felled trunk) rather than stopping in mid-air.
##
## A piece that fell asleep on its own is already touching something, so the sweep
## finds no room and this costs one query and changes nothing — which is why it is
## safe to run on every settle rather than only the forced ones.
##
## Returns true when the piece is already hard up against something and so needs no
## watching: it did not have to be moved, and nothing it is leaning on can leave.
func _come_to_rest() -> bool:
	if _shape == null or _shape.shape == null:
		return true
	var world := get_world_3d()
	if world == null:
		return true
	var space := world.direct_space_state
	if space == null:
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape.shape
	# The shape can be offset from the body origin (the FragmentDef path centres it
	# on the mesh AABB), so the sweep starts from the SHAPE and the body moves by
	# whatever the shape found — they are rigidly attached, so the delta is shared.
	q.transform = _shape.global_transform
	q.motion = Vector3.DOWN * _MAX_DROP
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	var hit := space.cast_motion(q)
	if hit.size() < 1:
		return true
	var safe: float = hit[0]
	# 0 = it cannot move at all: already bedded into whatever is beneath it, which
	# is where a piece that fell asleep normally ends up. Nothing to do, nothing to
	# watch.
	if safe <= 0.0:
		return true
	# 1 = it swept the whole way without touching anything, so there is nothing
	# under it within reach and dropping it would be a guess. Leave it where it is,
	# but keep looking: usually this means the ground is hidden behind a body that
	# is still moving, and it will not be for long.
	if safe >= 1.0:
		return false
	# It was in the air, so it is being put down rather than found at rest — lay it
	# flat first if it was on end, then seat it.
	if _lay_down():
		q.transform = _shape.global_transform
		hit = space.cast_motion(q)
		safe = hit[0] if hit.size() > 0 else 0.0
		if safe <= 0.0 or safe >= 1.0:
			return false
	global_position += Vector3.DOWN * (_MAX_DROP * safe)
	return false


## Turn a piece that is standing on its end onto its side, facing anywhere. Returns
## true if it was moved. See _STANDING_DEG.
func _lay_down() -> bool:
	if _mesh == null or _mesh.mesh == null:
		return false
	var size := _mesh.mesh.get_aabb().size
	var long := Vector3.UP
	if size.x >= size.y and size.x >= size.z:
		long = Vector3.RIGHT
	elif size.z >= size.y:
		long = Vector3.BACK
	# ...and its longest dimension has to be a real length, or "on end" is meaningless.
	var dims: Array[float] = [size.x, size.y, size.z]
	dims.sort()
	if dims[2] < dims[0] * 2.0:
		return false
	var world := (global_transform.basis * long).normalized()
	if absf(world.dot(Vector3.UP)) < cos(deg_to_rad(_STANDING_DEG)):
		return false   # already lying over far enough to be believable
	var yaw := randf() * TAU
	var flat := Vector3(cos(yaw), 0.0, sin(yaw))
	var axis := world.cross(flat)
	if axis.length() < 0.0001:
		return false
	global_transform = Transform3D(
		Basis(axis.normalized(), world.angle_to(flat)) * global_transform.basis,
		global_position)
	return true


## NOTE on what the sweep does NOT exclude: bodies that are still moving.
##
## An earlier version filtered them out, on the reasoning that resting on something
## which has not stopped yet is how a piece ends up floating — the tree rotating over
## the stump while the hinge tear spits splinters underneath it being the case that
## actually happened. The confirm loop above covers that case and more (it also
## catches a support that leaves after the fact, which no filter can predict), so the
## filter was redundant, and it cost a walk of every sibling on every settle with a
## hundred and fifty of them in the scene by the end of a fell.


func is_settled() -> bool:
	return _is_settled


## SETTLED **AND** DONE CONFIRMING — the piece is where it is going to stay.
##
## `is_settled()` goes true the instant a piece is retired, which is BEFORE the confirm loop
## above has finished checking that what it came to rest on is still there. Anything that
## makes a piece's pose PERMANENT has to wait for this instead, or a splinter retired while it
## was bedded into the falling trunk is fixed in mid-air for good once the trunk rotates away.
##
## That is exactly what happened when settled debris started being baked into a MultiMesh
## (A12, 2026-07-26): baking reads the transform once and frees the body, so it froze poses the
## confirm loop would have corrected. Sam saw it as floating chips of wood. While the old
## behaviour was to DELETE the oldest settled piece a bad pose never had time to show.
func is_at_rest() -> bool:
	return _is_settled and _confirms_left <= 0


## FINISH CONFIRMING NOW, because something needs this piece's slot.
##
## The confirm loop runs for `_REST_CONFIRMS * _REST_INTERVAL` (six seconds), which is far
## longer than a player chopping hard will wait before the debris cap wants this piece — so
## without a way to cut it short, waiting for `is_at_rest()` lets debris pile up for a whole
## confirm window past the cap.
##
## It SWEEPS ONE LAST TIME before giving up the watch, and that is the point: a piece whose
## support has already gone gets put down on whatever is under it now, rather than being frozen
## where it was. What it cannot do is catch a support that leaves LATER — that is what the full
## six seconds buys, and a piece retired this way has traded it for the slot.
func force_at_rest() -> void:
	if not _is_settled:
		return
	_come_to_rest()
	_confirms_left = 0
