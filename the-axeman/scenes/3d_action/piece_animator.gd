extends RefCounted
## FILE: res://scenes/3d_action/piece_animator.gd
## ATTACHES TO: nothing — a plain RefCounted helper owned by chopping_minigame.gd.
##
## Scripted motion for on-block Node3D pieces; finished firewood alone uses
## rigid-body motion.
##
## Timing is REAL time (Time.get_ticks_msec), matching the reference's
## performance.now(). A GameFeel hit-pause (Engine.time_scale) therefore freezes
## the visible moment without corrupting the animation clock — the hop resumes
## cleanly after the freeze.
##
## Two motions, both lifted phase-for-phase from the reference:
##   * "bounce" (150 ms): a piece pops up `pop_h`, tilts a few degrees, slides
##     `dist` along `dir`, then settles back to its start height. This is the
##     on-block hop / shockwave jostle.
##   * "drop"  (300 ms): a fresh log falls from `from_height`, lands (fires
##     `on_land`), and does two decaying settle-bounces. This is log spawn-in.

const _UP := Vector3.UP

var _anims: Array = []


func _now_ms() -> float:
	return float(Time.get_ticks_msec())


## Scripted hop. `dir` is a world direction (flattened to the ground plane);
## the piece slides to (current pos + dir*dist), popping `pop_h` metres up and
## tilting `3 * tilt_mult` degrees about a random horizontal axis on the way,
## landing back at its start height with a final yaw of `target_yaw`.
func animate(mesh: Node3D, dir: Vector3, dist: float, pop_h: float,
		delay_ms: float, tilt_mult: float, target_yaw: float,
		duration_ms := 150.0) -> void:
	# Fold any in-flight anim for this mesh into the new start (reference parity:
	# a re-jostled piece restarts from where its previous hop would have landed).
	var start := mesh.position
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		if a.mesh == mesh:
			if a.has("end_pos"):
				mesh.position = a.end_pos
			start = mesh.position
			_anims.remove_at(i)

	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.0001:
		flat = flat.normalized()
	var end := start + flat * dist

	var tilt_axis := Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	if tilt_axis.length() < 0.0001:
		tilt_axis = Vector3.RIGHT
	tilt_axis = tilt_axis.normalized()

	_anims.append({
		"mesh": mesh, "type": "bounce",
		"start_pos": start, "end_pos": end,
		"pop_h": pop_h, "tilt_axis": tilt_axis,
		"tilt_rad": deg_to_rad(3.0 * tilt_mult),
		"target_yaw": target_yaw,
		"start_ms": -1.0, "delay_ms": delay_ms, "duration": duration_ms,
	})


## Fresh-log drop-in: falls from `from_height` to `rest_y`, calls `on_land`
## as it touches down (drop SFX hook), then two decaying settle-bounces.
func animate_drop(mesh: Node3D, from_height: float, rest_y: float,
		on_land: Callable, duration_ms := 300.0) -> void:
	mesh.position.y = from_height
	var tilt_axis := Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	if tilt_axis.length() < 0.0001:
		tilt_axis = Vector3.RIGHT
	tilt_axis = tilt_axis.normalized()
	_anims.append({
		"mesh": mesh, "type": "drop",
		"start_y": from_height, "end_y": rest_y,
		"tilt_axis": tilt_axis, "tilt_rad": deg_to_rad(4.0),
		"start_ms": -1.0, "delay_ms": 0.0, "duration": duration_ms,
		"on_land": on_land, "land_fired": false,
	})


## Advance every live animation. Call once per frame from the owner's _process.
func update() -> void:
	var now := _now_ms()
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		if not is_instance_valid(a.mesh):
			_anims.remove_at(i)
			continue
		if a.start_ms < 0.0:
			a.start_ms = now + a.delay_ms
		var elapsed: float = now - a.start_ms
		if elapsed < 0.0:
			continue
		var t: float = clampf(elapsed / a.duration, 0.0, 1.0)
		match a.type:
			"bounce": _update_bounce(a, t)
			"drop": _update_drop(a, t)
		if t >= 1.0:
			_anims.remove_at(i)


func _update_bounce(a: Dictionary, t: float) -> void:
	var mesh: Node3D = a.mesh
	if t >= 1.0:
		mesh.position = a.end_pos
		mesh.quaternion = Quaternion(_UP, a.target_yaw)
		return
	var n := 1.0 - (1.0 - t) * (1.0 - t)          # ease-out for the horizontal slide
	var x := lerpf(a.start_pos.x, a.end_pos.x, n)
	var z := lerpf(a.start_pos.z, a.end_pos.z, n)
	var s: float = a.start_pos.y
	var c: float = a.tilt_rad
	var y := s
	var o := 0.0
	var k := 0.0
	if t < 0.3:                                    # rise + tilt in
		k = t / 0.3
		y = s + a.pop_h * (1.0 - (1.0 - k) * (1.0 - k))
		o = lerpf(0.0, c, k)
	elif t < 0.6:                                  # fall back, full tilt held
		k = (t - 0.3) / 0.3
		y = s + a.pop_h * (1.0 - k * k)
		o = c
	elif t < 0.8:                                  # small secondary bounce, tilt back past level
		k = (t - 0.6) / 0.2
		y = s + sin(k * PI) * a.pop_h * 0.3
		o = lerpf(c, -c * 0.5, k)
	else:                                          # settle flat
		k = (t - 0.8) / 0.2
		y = s
		o = lerpf(-c * 0.5, 0.0, k)
	mesh.position = Vector3(x, y, z)
	mesh.quaternion = Quaternion(_UP, a.target_yaw) * Quaternion(a.tilt_axis, o)


func _update_drop(a: Dictionary, t: float) -> void:
	var mesh: Node3D = a.mesh
	if t >= 1.0:
		mesh.position.y = a.end_y
		mesh.quaternion = Quaternion.IDENTITY
		return
	var fall: float = a.start_y - a.end_y
	var av: float = a.tilt_rad
	var y: float = a.end_y
	var r := 0.0
	var o := 0.0
	if t < 1.0 / 3.0:                              # accelerating fall
		var k := t / (1.0 / 3.0)
		y = lerpf(a.start_y, a.end_y, k * k)
		r = av
	elif t < 2.0 / 3.0:                            # land + first bounce
		if not a.land_fired and (a.on_land as Callable).is_valid():
			a.land_fired = true
			(a.on_land as Callable).call()
		o = (t - 1.0 / 3.0) / (1.0 / 3.0)
		y = a.end_y + (fall / 3.0) * (4.0 * o * (1.0 - o))
		r = lerpf(av, -av * 0.75, o)
	else:                                          # smaller second bounce
		o = (t - 2.0 / 3.0) / (1.0 / 3.0)
		y = a.end_y + (fall / 9.0) * (4.0 * o * (1.0 - o))
		r = lerpf(-av * 0.75, 0.0, o)
	mesh.position.y = y
	mesh.quaternion = Quaternion(a.tilt_axis, r)


## Snap the listed meshes to their final resting state and drop their anims.
## Used when a piece is about to be re-sliced (must be settled first).
func finish_for(meshes: Array) -> void:
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		if a.mesh in meshes and is_instance_valid(a.mesh):
			if a.type == "bounce":
				a.mesh.position = a.end_pos
				a.mesh.quaternion = Quaternion(_UP, a.target_yaw)
			elif a.type == "drop":
				a.mesh.position.y = a.end_y
				a.mesh.quaternion = Quaternion.IDENTITY
			_anims.remove_at(i)


func clear() -> void:
	_anims.clear()
