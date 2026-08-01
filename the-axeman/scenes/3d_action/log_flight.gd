extends RefCounted
## FILE: res://scenes/3d_action/log_flight.gd
## ATTACHES TO: nothing — a plain RefCounted helper owned by tree_felling.gd.
##
## BUCKED LOGS FLYING TO THE PLAYER. Creative Director's direction, 2026-07-27: *"the logs can
## fly towards the character (in a similar way to the log chopping game) and then be added to
## their inventory."*
##
## It is the same IDEA as M4's `wood_pile.gd` — a physics body is baked to a frozen proxy at its
## resting transform and then script-animated to a destination, staggered so a batch cascades
## rather than snapping — but the destination here is a MOVING PLAYER rather than a slot on an
## arc, so none of the pile's deterministic packing applies and this is its own small thing.
##
## SCRIPTED, NOT PHYSICS, for exactly the reason `piece_animator.gd` gives: a thrown rigid body
## goes where the solver sends it, and a collectible has to arrive. It is also why the target is
## re-read EVERY FRAME — the player is walking, and a log launched at where they used to be
## would sail past them.
##
## REAL TIME (`Time.get_ticks_msec`), matching `piece_animator` and `wood_pile`: a GameFeel
## hit-pause freezes `Engine.time_scale` and must not corrupt an in-flight collect.
##
## Every tuning value is owned by `tree_felling.gd` and set on this object after `new()`
## (Directive 3) — nothing here is a final number.

## How long one log takes to reach the player (ms).
var fly_ms := 460.0
## Spread across a batch so a trunk's worth of logs cascades in rather than arriving as one
## clump (ms).
var stagger_ms := 110.0
## How far above the straight line the log arcs on the way (m).
var arc_height := 1.1
## Spin on the way in (turns over the whole flight), so it reads as thrown rather than slid.
var spin_turns := 1.35
## The log shrinks to nothing as it lands, so it is absorbed rather than clipping through the
## camera. 1.0 = full size on arrival (no shrink).
var land_scale := 0.15
## How far short of the target's own origin a log counts as arrived (m) — it is being absorbed
## by a body, not landing on a point.
var catch_radius := 0.35

var _live: Array[Dictionary] = []


func is_flying() -> bool:
	return not _live.is_empty()


func count() -> int:
	return _live.size()


## Launch `proxy` (a plain Node3D already in the tree at the log's resting transform) at
## whatever `target` returns each frame — a Callable giving a world position, so the flight
## tracks a walking player.
##
## `payload` is handed straight back to `on_arrive` when the log lands; tree_felling.gd uses it
## to carry the inventory units this particular log is worth. `index` staggers the batch.
func launch(proxy: Node3D, target: Callable, payload: Variant, index: int,
		on_arrive: Callable) -> void:
	if proxy == null or not is_instance_valid(proxy):
		return
	_live.append({
		"proxy": proxy,
		"target": target,
		"payload": payload,
		"on_arrive": on_arrive,
		"from": proxy.global_position,
		"basis": proxy.global_transform.basis,
		"axis": Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)).normalized(),
		"start_ms": Time.get_ticks_msec() + float(index) * stagger_ms,
	})


## Advance every flight. Call once per frame from the owner's _process.
func update() -> void:
	if _live.is_empty():
		return
	var now := Time.get_ticks_msec()
	var keep: Array[Dictionary] = []
	for f in _live:
		var proxy: Node3D = f.proxy
		if proxy == null or not is_instance_valid(proxy):
			continue
		var t := (float(now) - float(f.start_ms)) / maxf(fly_ms, 1.0)
		if t < 0.0:
			keep.append(f)   # still waiting out its stagger
			continue
		var to: Vector3 = (f.target as Callable).call()
		if t >= 1.0:
			_arrive(f)
			continue
		var e: float = clampf(t, 0.0, 1.0)
		# Ease out toward the player: quick off the ground, gathering in at the end.
		var s: float = 1.0 - pow(1.0 - e, 2.2)
		var pos: Vector3 = (f.from as Vector3).lerp(to, s)
		# ...over an arc, so it is thrown rather than dragged. sin() peaks at the midpoint and
		# is zero at both ends, so it never pulls the log below its own start or its target.
		pos.y += sin(e * PI) * arc_height
		proxy.global_position = pos
		proxy.global_transform = Transform3D(
			(f.basis as Basis).rotated(f.axis as Vector3, e * TAU * spin_turns)
				.scaled(Vector3.ONE * lerpf(1.0, land_scale, s)),
			pos)
		# Caught early if the player walked into it.
		if pos.distance_to(to) <= catch_radius:
			_arrive(f)
			continue
		keep.append(f)
	_live = keep


func _arrive(f: Dictionary) -> void:
	var proxy: Node3D = f.proxy
	if proxy != null and is_instance_valid(proxy):
		proxy.queue_free()
	var cb: Callable = f.on_arrive
	if cb.is_valid():
		cb.call(f.payload)


## Drop everything in flight without paying it out. The board is being torn down (the R key);
## anything owed has already been settled at LAUNCH, so nothing is lost by not calling back.
func clear() -> void:
	for f in _live:
		var proxy: Node3D = f.proxy
		if proxy != null and is_instance_valid(proxy):
			proxy.queue_free()
	_live.clear()
