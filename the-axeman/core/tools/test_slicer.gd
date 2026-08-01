extends SceneTree
## DEV TEST for MeshSlicer (Amendment 6). Run:
##   godot --headless -s res://core/tools/test_slicer.gd
## Slices known primitives and checks the two pieces have the expected extents
## and a generated cap surface. PASS/FAIL lines; no engine window needed.

var _pass := 0
var _fail := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("PASS: " + label)
	else:
		_fail += 1
		print("FAIL: " + label)


func _approx(a: float, b: float, eps := 0.02) -> bool:
	return absf(a - b) <= eps


func _init() -> void:
	print("=== MeshSlicer test ===")
	_test_box_center()
	_test_box_offset()
	_test_plane_miss()
	_test_cylinder()
	_test_attributes_survive()
	_test_cap_winding()
	_test_plane_to_local()
	_test_cap_uv_fit()
	print("=== SLICER RESULT: %d passed, %d failed ===" % [_pass, _fail])
	if _fail == 0:
		print("=== ALL SLICER CHECKS PASS ===")
	quit()


func _test_box_center() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var res := MeshSlicer.slice(box, Plane(Vector3.RIGHT, 0.0))
	_check(res.above != null and res.below != null, "center cut: both pieces exist")
	if res.above == null or res.below == null:
		return
	var aa: AABB = res.above.get_aabb()
	var ba: AABB = res.below.get_aabb()
	_check(_approx(aa.position.x, 0.0) and _approx(aa.position.x + aa.size.x, 0.5),
		"center cut: above piece spans x in [0, 0.5]")
	_check(_approx(ba.position.x, -0.5) and _approx(ba.position.x + ba.size.x, 0.0),
		"center cut: below piece spans x in [-0.5, 0]")
	_check(res.above.get_surface_count() == 2 and res.below.get_surface_count() == 2,
		"center cut: each piece has body + cap surfaces")


func _test_box_offset() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	# Plane at x = 0.4 -> above is a thin slab x in [0.4, 0.5].
	var res := MeshSlicer.slice(box, Plane(Vector3.RIGHT, 0.4))
	_check(res.above != null and res.below != null, "offset cut: both pieces exist")
	if res.above == null:
		return
	var aa: AABB = res.above.get_aabb()
	_check(_approx(aa.position.x, 0.4) and _approx(aa.size.x, 0.1),
		"offset cut: thin above slab is ~0.1 thick at x>=0.4")


func _test_plane_miss() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	# Plane far outside the box -> no division.
	var res := MeshSlicer.slice(box, Plane(Vector3.RIGHT, 5.0))
	_check(res.above == null and res.below == null,
		"non-dividing plane returns null/null (caller keeps original)")


func _test_cylinder() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 0.8
	# Vertical plane through the axis.
	var res := MeshSlicer.slice(cyl, Plane(Vector3.RIGHT, 0.0))
	_check(res.above != null and res.below != null, "cylinder split: both halves exist")
	if res.above == null:
		return
	var aa: AABB = res.above.get_aabb()
	_check(_approx(aa.size.y, 0.8, 0.03), "cylinder half keeps full height (~0.8)")
	_check(res.above.get_surface_count() == 2, "cylinder half has a cap surface")


## A sliced piece must shade the same as the mesh it came from. The log materials
## use normal maps and `vertex_color_use_as_albedo`, so a body surface that loses
## its authored TANGENT or COLOR through a cut lights differently than an uncut
## log — the end grain in particular goes flat and dark when SurfaceTool is left
## to regenerate the tangent basis from the cut soup.
func _test_attributes_survive() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var arr := box.surface_get_arrays(0)
	var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	# Author a distinctive tangent + colour on every vertex so we can spot them
	# again on the other side of the cut.
	var tan := PackedFloat32Array()
	var col := PackedColorArray()
	for i in range(n):
		tan.append_array([0.0, 0.0, 1.0, -1.0])
		col.append(Color(0.25, 0.5, 0.75, 1.0))
	arr[Mesh.ARRAY_TANGENT] = tan
	arr[Mesh.ARRAY_COLOR] = col
	var src := ArrayMesh.new()
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var res := MeshSlicer.slice(src, Plane(Vector3.RIGHT, 0.0))
	if res.above == null:
		_check(false, "attributes: slice produced a piece")
		return
	var out := (res.above as ArrayMesh).surface_get_arrays(0)   # surface 0 = body, 1 = cap
	var ot: Variant = out[Mesh.ARRAY_TANGENT]
	var oc: Variant = out[Mesh.ARRAY_COLOR]
	var verts: int = (out[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_check(ot is PackedFloat32Array and (ot as PackedFloat32Array).size() == verts * 4,
		"body surface keeps a TANGENT for every vertex")
	_check(oc is PackedColorArray and (oc as PackedColorArray).size() == verts,
		"body surface keeps a COLOR for every vertex")
	if ot is PackedFloat32Array and (ot as PackedFloat32Array).size() >= 4:
		var t: PackedFloat32Array = ot
		var kept := true
		for i in range(0, t.size(), 4):
			# Authored (0,0,1) with binormal sign -1: regenerated tangents would
			# point along the box's UV axes instead and flip the sign to +1.
			if not (_approx(absf(t[i + 2]), 1.0, 0.05) and _approx(t[i + 3], -1.0, 0.05)):
				kept = false
				break
		_check(kept, "body surface keeps the AUTHORED tangent basis, not a regenerated one")
	if oc is PackedColorArray and (oc as PackedColorArray).size() > 0:
		var c: PackedColorArray = oc
		_check(_approx(c[0].r, 0.25) and _approx(c[0].g, 0.5) and _approx(c[0].b, 0.75),
			"body surface keeps the authored vertex colour")


## The generated CAP must be wound the way Godot renders front faces: RHR normal
## opposing the shading normal (see MeshUtils.winding_report). It was backwards
## until 2026-07-25 — invisible in the game only because every cut material in the
## project is CULL_DISABLED, so both sides drew. Asserted now so a culled cut
## material can never go see-through.
func _test_cap_winding() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)

	# The engine's own primitive first: if this ever fails, the convention moved
	# and the two lines below are measuring the wrong thing.
	var src := ArrayMesh.new()
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
	var prim := MeshUtils.winding_report(src)
	_check(prim.agree == 0 and prim.oppose > 0,
		"Godot's own BoxMesh winds RHR against the shading normal (%d agree, %d oppose)" % [
			prim.agree, prim.oppose])

	var res := MeshSlicer.slice(box, Plane(Vector3.UP, 0.0))
	for side in ["above", "below"]:
		var mesh: ArrayMesh = res[side]
		if mesh == null or mesh.get_surface_count() < 2:
			_check(false, "%s piece has a cap surface to check" % side)
			continue
		# Surface 0 is the carried-over body, surface 1 the fresh cap.
		var cap := ArrayMesh.new()
		cap.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(1))
		var w := MeshUtils.winding_report(cap)
		_check(w.oppose > 0 and w.agree == 0,
			"%s piece's cut cap faces outward (%d agree, %d oppose)" % [side, w.agree, w.oppose])


## PLANE_TO_LOCAL UNDER ROTATION. A plane's normal transforms by the TRANSPOSE OF THE FORWARD
## basis, and this once read `inv.basis.transposed()` — which for a rotation R evaluates to R
## instead of R^T, i.e. the rotation applied the wrong way round.
##
## It was invisible for years because every caller passed a translation-only transform: the
## slicer's mesh children sit at offsets, and every tree stood unrotated at the world origin.
## The forest gave trees a random yaw and it broke chopping outright — the blow's cut planes
## came out ~98 degrees off, the convex solid missed the trunk, and the tree reported a notch
## getting deeper while nothing was ever removed.
##
## The invariant, and it is the whole test: a point ON the world plane must land ON the local
## plane, and a point clearly on one side must stay on that side.
func _test_plane_to_local() -> void:
	for deg in [0.0, 37.0, 90.0, 180.0, 310.8]:
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(deg)), Vector3(3.3, 0.0, 10.0))
		var world := Plane(Vector3(0.6, 0.2, -0.77).normalized(), 2.4)
		var local := MeshUtils.plane_to_local(world, xform)
		# Three points on the world plane, well spread, so a wrong ROTATION cannot pass by
		# accident the way a single point on the normal could.
		var on_plane := world.normal * world.d
		var tangent := world.normal.cross(Vector3.UP).normalized()
		var worst := 0.0
		for k: float in [0.0, 1.7, -2.9]:
			var pw: Vector3 = on_plane + tangent * k
			worst = maxf(worst, absf(local.distance_to(xform.affine_inverse() * pw)))
		_check(worst < 0.0001,
			"plane_to_local keeps points on the plane at %.1f deg yaw (worst %.5f)" % [deg, worst])
		# ...and sidedness is preserved, which is what a convex carve actually depends on.
		var outside := on_plane + world.normal * 1.5
		var inside := on_plane - world.normal * 1.5
		_check(local.distance_to(xform.affine_inverse() * outside) > 0.0
				and local.distance_to(xform.affine_inverse() * inside) < 0.0,
			"...and which side of it a point is on (%.1f deg)" % deg)


## CAP UVs MUST FIT THE ROUND, at any size. `cap_fit_round` maps a cut face as a single
## growth-ring disc fitted to that face; the default maps it in METRES.
##
## The metres mapping only lands inside 0..1 when the piece is about a metre across, which
## tree_01's ~0.5 m radius made true BY ACCIDENT — so M5's bucked ends worked until
## `tree_size_variation` made trunks wider, at which point the UVs ran off the disc and
## (`texture_repeat` being off) clamped to the WHITE field around it. Sam saw it as the cut
## textures being "all wrong". Nothing measured cap UVs before this.
func _test_cap_uv_fit() -> void:
	for r: float in [0.15, 0.5, 1.4]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = 2.0
		cyl.radial_segments = 20
		var res := MeshSlicer.slice(cyl, Plane(Vector3.UP, 0.0), null, true)
		var mesh: ArrayMesh = res["above"]
		if mesh == null or mesh.get_surface_count() < 2:
			_check(false, "a cylinder of radius %.2f slices with a cap" % r)
			continue
		var uvs: PackedVector2Array = mesh.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV]
		var lo := 1.0
		var hi := 0.0
		for uv in uvs:
			lo = minf(lo, minf(uv.x, uv.y))
			hi = maxf(hi, maxf(uv.x, uv.y))
		_check(uvs.size() > 0 and lo >= 0.0 and hi <= 1.0,
			"a fitted cap's UVs stay inside the round at radius %.2f (%.3f..%.3f)" % [r, lo, hi])
		# ...and it really does FILL it, or the rings would be a dot in the middle.
		_check(hi - lo > 0.8,
			"...and fill it rather than shrinking to the centre (span %.3f)" % (hi - lo))

	# The DEFAULT is unchanged, because M4's cut material tiles and wants metres.
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 2)
	var plain := MeshSlicer.slice(box, Plane(Vector3.UP, 0.0))
	var pm: ArrayMesh = plain["above"]
	if pm != null and pm.get_surface_count() >= 2:
		var puv: PackedVector2Array = pm.surface_get_arrays(1)[Mesh.ARRAY_TEX_UV]
		var pspan := 0.0
		for uv in puv:
			pspan = maxf(pspan, absf(uv.x - 0.5))
		_check(pspan > 0.6,
			"the default cap mapping is still in metres, as M4's tiling cut material needs (%.2f)" % pspan)
	else:
		_check(false, "a box slices with a cap for the default-mapping check")
