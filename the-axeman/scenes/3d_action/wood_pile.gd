extends RefCounted
## FILE: res://scenes/3d_action/wood_pile.gd
## ATTACHES TO: nothing — a plain RefCounted helper owned by chopping_minigame.gd.
##
## Port of the reference firewood chopper's pile builder (minified three.js class
## `QC`). When a log is fully chopped, the scattered firewood is GATHERED and
## flies into a neat stacked pile arranged on an arc around the stump, then a
## fresh log spawns. The pile PERSISTS and grows across logs (tiers advance when
## an arc row fills).
##
## Faithful parts:
##   * deterministic pyramid slot packing (_valid_slot / _slot_layout): fill a
##     base row, then stack pieces in the valleys between two lower pieces;
##   * arc placement (_sim_to_world): slots map onto a circle of `radius` around
##     the stump, tiers step outward by `tier_depth_spacing`;
##   * staggered fly-in (update): each piece arcs up, flips, and settles into its
##     slot with two decaying bounce+rock phases.
## Approximated (to avoid a 2D-physics dependency): the reference runs a Box2D
## settle pass to refine each piece's resting Y/angle. That is a refinement on top
## of the deterministic slot layout; here a piece rests at its slot's base height
## with the same small random angle the reference ends up applying. All layout,
## arc and animation feel is faithful.
##
## Owner sets the public tuning vars after `new()` (they mirror chopping_minigame.gd @exports,
## carried from the reference via ld = 0.0254 m/in). Real-time clock matches the
## reference performance.now(); a hit-pause won't corrupt an in-flight stack.

# --- tuning (set by the owner; reference defaults shown) -------------------
var radius := 1.524            # ref 60in: arc radius the pile sits on
var arc_span := deg_to_rad(230.0)
var start_angle := deg_to_rad(320.0)
var slot_spacing := 0.127      # ref XC = 5in: horizontal slot spacing along the arc
var tier_depth_spacing := 0.4572  # ref 18in: how far each new tier steps outward
var max_height := 0.4572       # ref 18in: a valley slot is only valid if its supports are below this
var ground_y := 0.0            # world y the pile sits on (ref cd = -0.33; our floor top = 0)
var jitter := 0.0254           # ref 1in: small random slide along the arc
var apex_extra := 0.3048       # ref 12in: how far above the pile a flung piece arcs
var fly_duration := 500.0      # ms; the actual travel takes fly_duration * 1.6
var stagger := 300.0           # ms spread across the batch so pieces cascade in

# --- haul-away tuning (set by the owner) ----------------------------------
var haul_distance := 9.0       # how far out a hauled piece flies before it is dropped (m)
var haul_rise := 2.2           # how high it arcs on the way (m)
var haul_duration := 700.0     # ms per piece
var haul_stagger := 600.0      # ms spread across the whole pile, so it leaves as a wave

# --- state ----------------------------------------------------------------
var is_animating := false
var is_hauling := false
var _tier := 0
var _filled := {}              # "x,y" -> true
var _slot_tops := {}           # "x,y" -> height of the top of that column
var _max_gx := -1.0
var _min_gx := 1.0
var _max_height := 0.0
var _needs_tier_advance := false
var _anim: Array = []
var _on_complete: Callable
var _haul: Array = []
var _on_hauled: Callable
var _on_piece_settled: Callable


func pile_height() -> float:
	return _max_height


## Assign slots to `proxies` (plain MeshInstance3D at each firewood's landed spot)
## and start the staggered fly-in. `on_complete` fires when the last piece rests;
## `on_piece_settled` fires for EACH piece the moment it comes to rest in its slot,
## which is when the yard pays for it — so the cash ticks up in the same cascade
## the player is watching, rather than in one lump before the wood has landed.
func start_stacking(proxies: Array, on_complete: Callable, on_piece_settled := Callable()) -> void:
	_on_piece_settled = on_piece_settled
	if proxies.is_empty():
		if on_complete.is_valid():
			on_complete.call()
		return
	if _needs_tier_advance:
		_advance_tier()
		_needs_tier_advance = false
	is_animating = true
	_anim = []
	_on_complete = on_complete

	var layouts: Array = []
	for p: MeshInstance3D in proxies:
		layouts.append(_slot_layout(p.mesh))

	# If a slot ran past the arc span, the NEXT batch starts a new outward tier.
	var arc_len := arc_span * (radius + _tier * tier_depth_spacing)
	for l: Dictionary in layouts:
		if absf(l.slotX * slot_spacing) >= arc_len:
			_needs_tier_advance = true
			break

	var s := stagger / float(proxies.size() - 1) if proxies.size() > 1 else 0.0
	var apex_base := _max_height + apex_extra
	var now := float(Time.get_ticks_msec())
	for idx in range(proxies.size()):
		var l: Dictionary = layouts[idx]
		var settle_angle := randf_range(-0.04, 0.04)   # ref (rand-0.5)*0.08
		var sim_y: float = l.physicalBaseY + l.T * 0.5
		var w := _sim_to_world(l, sim_y, settle_angle)
		_anim.append({
			"mesh": proxies[idx], "end_pos": w.pos, "end_quat": w.quat,
			"height": w.height, "start_ms": now + idx * s,
			"apex_base": apex_base, "grabbed": false, "done": false,
		})


## Place one piece straight into its slot with NO fly-in, and return the world
## transform it landed in.
##
## This is how a pile is REBUILT rather than earned: the yard's stockpile is a
## view of InventoryManager's firewood, so on a load — or after a sale — the whole
## pile has to appear at once, already settled. It shares `_slot_layout` and
## `_sim_to_world` with the animated path, so a restored pile packs identically to
## one the player watched being thrown together, and a piece added by either route
## lands in the same next slot.
##
## The tier-advance bookkeeping mirrors start_stacking's, per piece instead of per
## batch: once a slot runs past the arc span the next piece starts a new tier
## stepping outward, so a big yard piles up in rows rather than in one endless arc.
func place_settled(node: MeshInstance3D) -> void:
	if node == null or node.mesh == null:
		return
	if _needs_tier_advance:
		_advance_tier()
		_needs_tier_advance = false

	var l := _slot_layout(node.mesh)
	var sim_y: float = l.physicalBaseY + l.T * 0.5
	var w := _sim_to_world(l, sim_y, randf_range(-0.04, 0.04))
	node.position = w.pos
	node.quaternion = w.quat

	var arc_len := arc_span * (radius + _tier * tier_depth_spacing)
	if absf(l.slotX * slot_spacing) >= arc_len:
		_needs_tier_advance = true


## Drive the fly-in. Call once per frame from the owner while is_animating.
func update() -> void:
	if not is_animating:
		return
	var now := float(Time.get_ticks_msec())
	var all_done := true
	for n: Dictionary in _anim:
		if n.done:
			continue
		if not is_instance_valid(n.mesh):
			n.done = true
			continue
		if now < n.start_ms:
			all_done = false
			continue
		if not n.grabbed:
			n.grabbed = true
			n.start_pos = (n.mesh as Node3D).position
			n.start_quat = (n.mesh as Node3D).quaternion
			n.apex = maxf(n.apex_base, n.start_pos.y + 0.5)
			var e: Vector3 = n.end_pos - n.start_pos
			e.y = 0.0
			if e.length() < 0.001:
				e = Vector3(1, 0, 0)
			e = e.normalized()
			n.flip_axis = Vector3(-e.z, 0.0, e.x)
			n.rock_sign = 1.0 if randf() < 0.5 else -1.0

		var dur := fly_duration * 1.6
		var a := minf((now - n.start_ms) / dur, 1.0)
		var mesh: Node3D = n.mesh
		if a >= 1.0:
			mesh.position = n.end_pos
			mesh.quaternion = n.end_quat
			n.done = true
			if _on_piece_settled.is_valid():
				_on_piece_settled.call()
			continue
		all_done = false

		var p1 := 0.55
		var p2 := 0.75
		var p3 := 0.92
		var rock := deg_to_rad(10.0)
		if a < p1:                                   # arc up + flip toward the slot
			var e := a / p1
			var t := 2.0 * e * e if e < 0.5 else 1.0 - pow(-2.0 * e + 2.0, 2.0) / 2.0
			var x := lerpf(n.start_pos.x, n.end_pos.x, t)
			var z := lerpf(n.start_pos.z, n.end_pos.z, t)
			var y := lerpf(n.start_pos.y, n.end_pos.y, t)
			var arc: float = 4.0 * float(n.apex) * e * (1.0 - e)
			mesh.position = Vector3(x, y + arc, z)
			var flip := Quaternion(n.flip_axis, t * PI * 2.0 * 2.0)
			mesh.quaternion = flip * (n.start_quat as Quaternion).slerp(n.end_quat, t)
		elif a < p2:                                 # land + first bounce/rock
			var e := (a - p1) / (p2 - p1)
			mesh.position = n.end_pos + Vector3(0.0, sin(e * PI) * float(n.height), 0.0)
			var rr: float = sin(e * PI * 2.0) * rock * float(n.rock_sign)
			mesh.quaternion = Quaternion(n.flip_axis, rr) * (n.end_quat as Quaternion)
		elif a < p3:                                 # smaller settle bounce/rock
			var e := (a - p2) / (p3 - p2)
			mesh.position = n.end_pos + Vector3(0.0, sin(e * PI) * float(n.height) * 0.15, 0.0)
			var rr: float = sin(e * PI * 2.0) * rock * 0.3 * float(n.rock_sign)
			mesh.quaternion = Quaternion(n.flip_axis, rr) * (n.end_quat as Quaternion)
		else:
			mesh.position = n.end_pos
			mesh.quaternion = n.end_quat

	if all_done:
		is_animating = false
		_anim = []
		if _on_complete.is_valid():
			_on_complete.call()


## THE HAUL-AWAY. The pile is full, so the whole load leaves the yard: each piece
## lifts, arcs outward away from the stump and tumbles off past the horizon, in a
## staggered wave that reads as the reverse of the fly-in that built the pile.
##
## It runs on its OWN animation list, deliberately independent of the stacking
## one, so the player can go straight back to chopping while the load is still on
## its way out — the yard never stops to watch itself being tidied.
##
## Nodes are freed here as each finishes, because from the caller's point of view
## they left with the load; `on_hauled` fires once the last one is gone.
func start_hauling(nodes: Array, on_hauled := Callable()) -> void:
	if nodes.is_empty():
		if on_hauled.is_valid():
			on_hauled.call()
		return
	is_hauling = true
	_on_hauled = on_hauled
	_haul = []
	var now := float(Time.get_ticks_msec())
	var s := haul_stagger / float(nodes.size() - 1) if nodes.size() > 1 else 0.0
	for idx in range(nodes.size()):
		var node: Node3D = nodes[idx]
		var out := Vector3(node.position.x, 0.0, node.position.z)
		# A piece sitting dead centre still has to go somewhere.
		out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
		_haul.append({
			"mesh": node,
			"start_pos": node.position,
			"start_quat": node.quaternion,
			"end_pos": node.position + out * haul_distance + Vector3.UP * haul_rise,
			"spin_axis": Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(),
			"spin": randf_range(4.0, 9.0),
			"start_ms": now + idx * s,
			"done": false,
		})


## Drive the haul-away. Call once per frame from the owner while is_hauling.
func update_haul() -> void:
	if not is_hauling:
		return
	var now := float(Time.get_ticks_msec())
	var all_done := true
	for n: Dictionary in _haul:
		if n.done:
			continue
		if not is_instance_valid(n.mesh):
			n.done = true
			continue
		if now < n.start_ms:
			all_done = false
			continue
		var a := minf((now - float(n.start_ms)) / haul_duration, 1.0)
		var mesh: Node3D = n.mesh
		if a >= 1.0:
			n.done = true
			mesh.queue_free()
			continue
		all_done = false
		# Ease OUT of the pile and IN to the distance: a slow lift that turns into
		# a fling, so the wood looks thrown rather than slid.
		var t := a * a
		mesh.position = (n.start_pos as Vector3).lerp(n.end_pos, t) \
			+ Vector3.UP * sin(a * PI) * haul_rise * 0.35
		mesh.quaternion = Quaternion(n.spin_axis, float(n.spin) * a) * (n.start_quat as Quaternion)

	if all_done:
		is_hauling = false
		_haul = []
		if _on_hauled.is_valid():
			_on_hauled.call()


func reset() -> void:
	_tier = 0
	_filled = {}
	_slot_tops = {}
	_max_gx = -1.0
	_min_gx = 1.0
	_max_height = 0.0
	_needs_tier_advance = false
	_anim = []
	is_animating = false
	start_angle = deg_to_rad(320.0)


# ------------------------------------------------------- slot packing (QC)
func _advance_tier() -> void:
	_tier += 1
	_filled = {}
	_slot_tops = {}
	_max_gx = -1.0
	_min_gx = 1.0
	_max_height = 0.0
	start_angle = deg_to_rad(320.0)


func _key(x: float, y: int) -> String:
	return "%.1f,%d" % [x, y]


## Next free slot: prefer stacking in a valley between two adjacent lower pieces,
## else extend the base row outward. Reference _getValidSlots.
func _valid_slot() -> Vector2:
	if _filled.is_empty():
		return Vector2(0.0, 0.0)
	var candidates: Array = [Vector2(_min_gx - 1.0, 0.0)]
	for key: String in _filled:
		var parts := key.split(",")
		var r := float(parts[0])
		var i := int(parts[1])
		var left := _key(r - 1.0, i)
		if _filled.has(left):
			var tx := r - 0.5
			var ny := i + 1
			var vk := _key(tx, ny)
			if not _filled.has(vk):
				var top_a: float = _slot_tops.get(_key(r, i), 0.0)
				var top_b: float = _slot_tops.get(left, 0.0)
				if maxf(top_a, top_b) < max_height:
					candidates.append(Vector2(tx, float(ny)))
	candidates.sort_custom(Callable(self, "_slot_less"))
	return candidates[0]


func _slot_less(e: Vector2, t: Vector2) -> bool:
	if e.y != t.y:
		return e.y > t.y                 # higher tier first
	return absf(e.x) < absf(t.x)         # then nearer the centre


func _slot_layout(mesh: Mesh) -> Dictionary:
	var sz := mesh.get_aabb().size
	var thick := minf(sz.x, sz.z)
	var is_x_thinner := sz.x < sz.z
	var slot := _valid_slot()
	var gy := int(slot.y)
	var base_y := 0.0
	if gy > 0:
		var lt: float = _slot_tops.get(_key(slot.x - 0.5, gy - 1), 0.0)
		var rt: float = _slot_tops.get(_key(slot.x + 0.5, gy - 1), 0.0)
		base_y = maxf(lt, rt)
	_filled[_key(slot.x, gy)] = true
	_slot_tops[_key(slot.x, gy)] = base_y + thick
	_max_gx = maxf(_max_gx, slot.x)
	_min_gx = minf(_min_gx, slot.x)
	_max_height = maxf(_max_height, base_y + thick)
	return {
		"slotX": slot.x, "slotGridY": gy, "physicalBaseY": base_y, "T": thick,
		"isXThinner": is_x_thinner, "sizeH": sz.y, "tierLevel": _tier,
	}


## Map a settled slot to a world position + orientation on the arc. Reference
## _simToWorld.
func _sim_to_world(l: Dictionary, sim_y: float, sim_angle: float) -> Dictionary:
	var depth: float = l.tierLevel * tier_depth_spacing
	var sim_x: float = l.slotX * slot_spacing
	var ang: float = start_angle + sim_x / (radius + depth)
	var u := Vector3(cos(ang), 0.0, sin(ang))
	var up := Vector3(0.0, 1.0, 0.0)
	var f := up.cross(u).normalized()
	var pos := u * (radius + depth)
	pos.y = ground_y + sim_y
	pos += u * (randf_range(-1.0, 1.0) * jitter)
	var basis := Basis(up, u, f) if l.isXThinner else Basis(-f, u, up)
	var q := basis.get_rotation_quaternion()
	q = Quaternion(u, sim_angle) * q
	q = Quaternion(Vector3.UP, PI) * q
	return {"pos": pos, "quat": q, "height": l.sizeH}
