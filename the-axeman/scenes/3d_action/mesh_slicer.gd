class_name MeshSlicer
extends RefCounted
## FILE: res://scenes/3d_action/mesh_slicer.gd
## Runtime convex mesh plane-slicer for chopping and loose-root fragmentation.
##
## slice(source, plane, cut_mat) cuts `source` into an ABOVE piece (+normal
## side) and a BELOW piece, each closed with a generated cap on the cut face.
## Assumes a roughly CONVEX source (a log round). NOT general CSG.
##
## Per-surface materials are PRESERVED (so a log's bark/end-grain surfaces stay
## themselves) and the new cut face becomes an extra surface using `cut_mat`.
## Returns { "above": ArrayMesh|null, "below": ArrayMesh|null }; a side is null
## when the plane doesn't divide the mesh.
##
## Vertex attributes carried through a cut: POSITION, NORMAL, TANGENT, COLOR, UV.
## TANGENT and COLOR matter as much as the others — the log materials use normal
## maps AND `vertex_color_use_as_albedo`, so a surface that loses either shades
## differently after being sliced than it did whole. In particular, letting
## SurfaceTool regenerate tangents flips the binormal sign on the log's end-grain
## surface (authored w=-1 -> generated w=+1), which mirrors the normal map and
## makes the cut halves read flat and dark next to an uncut log.

const _WELD_EPS := 0.0005
## Where a piece's own radius lands in a single-round cut texture, 0..0.5.
const _RING_FIT := 0.48


## `cap_fit_round` fits one centred end-grain round to the cut face. False maps
## in metres for tiling cut materials.
static func slice(source: Mesh, plane: Plane, cut_mat: Material = null,
		cap_fit_round := false) -> Dictionary:
	var surf_count := source.get_surface_count()
	var above_sts: Array[SurfaceTool] = []
	var below_sts: Array[SurfaceTool] = []
	var above_counts: Array[int] = []
	var below_counts: Array[int] = []
	var mats: Array = []
	var cut_pts: Array[Vector3] = []

	for si in range(surf_count):
		var ab := SurfaceTool.new(); ab.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bl := SurfaceTool.new(); bl.begin(Mesh.PRIMITIVE_TRIANGLES)
		var counts := _process_surface(source, si, plane, ab, bl, cut_pts)
		above_sts.append(ab); below_sts.append(bl)
		above_counts.append(counts.x); below_counts.append(counts.y)
		mats.append(source.surface_get_material(si))

	var total_above := 0
	var total_below := 0
	for c in above_counts:
		total_above += c
	for c in below_counts:
		total_below += c
	if total_above == 0 or total_below == 0:
		return {"above": null, "below": null}

	var above_cap := SurfaceTool.new(); above_cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var below_cap := SurfaceTool.new(); below_cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var capped := _build_caps(cut_pts, plane, above_cap, below_cap, cap_fit_round)
	var cutm: Material = cut_mat if cut_mat != null else _default_cut_mat()

	var above_mesh := ArrayMesh.new()
	for si in range(surf_count):
		if above_counts[si] > 0:
			above_sts[si].set_material(mats[si])
			above_sts[si].commit(above_mesh)
	if capped:
		above_cap.set_material(cutm)
		above_cap.generate_tangents()   # so a normal-mapped cut_mat renders on the cap
		above_cap.commit(above_mesh)

	var below_mesh := ArrayMesh.new()
	for si in range(surf_count):
		if below_counts[si] > 0:
			below_sts[si].set_material(mats[si])
			below_sts[si].commit(below_mesh)
	if capped:
		below_cap.set_material(cutm)
		below_cap.generate_tangents()   # so a normal-mapped cut_mat renders on the cap
		below_cap.commit(below_mesh)

	return {"above": above_mesh, "below": below_mesh}


static func _process_surface(source: Mesh, si: int, plane: Plane,
		above_st: SurfaceTool, below_st: SurfaceTool, cut_pts: Array[Vector3]) -> Vector2i:
	var arr := source.surface_get_arrays(si)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var raw_norms: Variant = arr[Mesh.ARRAY_NORMAL]
	var has_n: bool = raw_norms is PackedVector3Array and (raw_norms as PackedVector3Array).size() == verts.size()
	var norms: PackedVector3Array = raw_norms if has_n else PackedVector3Array()
	var raw_uv: Variant = arr[Mesh.ARRAY_TEX_UV]
	var has_uv: bool = raw_uv is PackedVector2Array and (raw_uv as PackedVector2Array).size() == verts.size()
	var uvs: PackedVector2Array = raw_uv if has_uv else PackedVector2Array()
	var raw_tan: Variant = arr[Mesh.ARRAY_TANGENT]
	var has_t: bool = raw_tan is PackedFloat32Array and (raw_tan as PackedFloat32Array).size() == verts.size() * 4
	var tans: PackedFloat32Array = raw_tan if has_t else PackedFloat32Array()
	var raw_col: Variant = arr[Mesh.ARRAY_COLOR]
	var has_c: bool = raw_col is PackedColorArray and (raw_col as PackedColorArray).size() == verts.size()
	var cols: PackedColorArray = raw_col if has_c else PackedColorArray()
	var raw_idx: Variant = arr[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array
	if raw_idx is PackedInt32Array and (raw_idx as PackedInt32Array).size() > 0:
		idx = raw_idx
	else:
		idx = PackedInt32Array()
		for k in range(verts.size()):
			idx.append(k)

	var above_n := 0
	var below_n := 0
	for t in range(0, idx.size() - 2, 3):
		var ia := idx[t]; var ib := idx[t + 1]; var ic := idx[t + 2]
		var da := plane.distance_to(verts[ia])
		var db := plane.distance_to(verts[ib])
		var dc := plane.distance_to(verts[ic])
		var side_count := (1 if da >= 0.0 else 0) \
			+ (1 if db >= 0.0 else 0) + (1 if dc >= 0.0 else 0)
		# Most triangles never cross the cut. Emit their packed attributes directly
		# instead of allocating three vertex Dictionaries plus a temporary tri Array.
		# Only the narrow ring intersected by the plane needs interpolation records.
		if side_count == 3 or side_count == 0:
			var target := above_st if side_count == 3 else below_st
			var fallback_normal := Vector3.ZERO if has_n else _face_normal(
				verts[ia], verts[ib], verts[ic])
			_emit_indexed_tri(target, ia, ib, ic, fallback_normal,
				verts, norms, has_n, uvs, has_uv, tans, has_t, cols, has_c)
			if side_count == 3:
				above_n += 1
			else:
				below_n += 1
			continue
		var fn := _face_normal(verts[ia], verts[ib], verts[ic])
		var a := _vert(ia, plane, fn, verts, norms, has_n, uvs, has_uv, tans, has_t, cols, has_c)
		var b := _vert(ib, plane, fn, verts, norms, has_n, uvs, has_uv, tans, has_t, cols, has_c)
		var c := _vert(ic, plane, fn, verts, norms, has_n, uvs, has_uv, tans, has_t, cols, has_c)
		var counts := _split_tri(a, b, c, above_st, below_st, cut_pts)
		above_n += counts.x
		below_n += counts.y
	return Vector2i(above_n, below_n)


static func _emit_indexed_tri(st: SurfaceTool, ia: int, ib: int, ic: int,
		fallback_normal: Vector3, verts: PackedVector3Array,
		norms: PackedVector3Array, has_n: bool, uvs: PackedVector2Array,
		has_uv: bool, tans: PackedFloat32Array, has_t: bool,
		cols: PackedColorArray, has_c: bool) -> void:
	_emit_indexed_vertex(st, ia, fallback_normal, verts, norms, has_n,
		uvs, has_uv, tans, has_t, cols, has_c)
	_emit_indexed_vertex(st, ib, fallback_normal, verts, norms, has_n,
		uvs, has_uv, tans, has_t, cols, has_c)
	_emit_indexed_vertex(st, ic, fallback_normal, verts, norms, has_n,
		uvs, has_uv, tans, has_t, cols, has_c)


static func _emit_indexed_vertex(st: SurfaceTool, index: int,
		fallback_normal: Vector3, verts: PackedVector3Array,
		norms: PackedVector3Array, has_n: bool, uvs: PackedVector2Array,
		has_uv: bool, tans: PackedFloat32Array, has_t: bool,
		cols: PackedColorArray, has_c: bool) -> void:
	st.set_normal(norms[index] if has_n else fallback_normal)
	st.set_uv(uvs[index] if has_uv else Vector2.ZERO)
	if has_t:
		st.set_tangent(Plane(tans[index * 4], tans[index * 4 + 1],
			tans[index * 4 + 2], tans[index * 4 + 3]))
	if has_c:
		st.set_color(cols[index])
	st.add_vertex(verts[index])


## Gather vertex `i`'s attributes into the working dict the splitter passes around.
## Absent optional attributes come through as `null` so _emit knows to skip them
## (a SurfaceTool surface must be fed the same attribute set for every vertex).
static func _vert(i: int, plane: Plane, face_normal: Vector3,
		verts: PackedVector3Array, norms: PackedVector3Array, has_n: bool,
		uvs: PackedVector2Array, has_uv: bool,
		tans: PackedFloat32Array, has_t: bool,
		cols: PackedColorArray, has_c: bool) -> Dictionary:
	return {
		"p": verts[i],
		"n": norms[i] if has_n else face_normal,
		"uv": uvs[i] if has_uv else Vector2.ZERO,
		"t": Plane(tans[i * 4], tans[i * 4 + 1], tans[i * 4 + 2], tans[i * 4 + 3]) if has_t else null,
		"c": cols[i] if has_c else null,
		"d": plane.distance_to(verts[i]),
	}


static func _split_tri(a: Dictionary, b: Dictionary, c: Dictionary,
		above_st: SurfaceTool, below_st: SurfaceTool, cut_pts: Array[Vector3]) -> Vector2i:
	var tri := [a, b, c]
	var above_n := (1 if a.d >= 0.0 else 0) + (1 if b.d >= 0.0 else 0) + (1 if c.d >= 0.0 else 0)

	if above_n == 3:
		_emit(above_st, a, b, c)
		return Vector2i(1, 0)
	if above_n == 0:
		_emit(below_st, a, b, c)
		return Vector2i(0, 1)

	var singleton_above := above_n == 1
	var s := 0
	for i in range(3):
		if (tri[i].d >= 0.0) == singleton_above:
			s = i
			break
	var v0: Dictionary = tri[s]
	var v1: Dictionary = tri[(s + 1) % 3]
	var v2: Dictionary = tri[(s + 2) % 3]

	var i01 := _intersect(v0, v1)
	var i02 := _intersect(v0, v2)
	cut_pts.append(i01.p)
	cut_pts.append(i02.p)

	if singleton_above:
		_emit(above_st, v0, i01, i02)
		_emit(below_st, i01, v1, v2)
		_emit(below_st, i01, v2, i02)
		return Vector2i(1, 2)
	else:
		_emit(below_st, v0, i01, i02)
		_emit(above_st, i01, v1, v2)
		_emit(above_st, i01, v2, i02)
		return Vector2i(2, 1)


static func _build_caps(cut_pts: Array[Vector3], plane: Plane,
		above_cap: SurfaceTool, below_cap: SurfaceTool, cap_fit_round := false) -> bool:
	var loop := _weld(cut_pts)
	if loop.size() < 3:
		return false
	var centroid := Vector3.ZERO
	for p in loop:
		centroid += p
	centroid /= loop.size()

	var u := plane.normal.cross(Vector3.UP)
	if u.length() < 0.001:
		u = plane.normal.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := plane.normal.cross(u).normalized()
	loop.sort_custom(func(x, y):
		return atan2((x - centroid).dot(w), (x - centroid).dot(u)) \
			< atan2((y - centroid).dot(w), (y - centroid).dot(u)))

	# Fit mode scales UVs from the measured face extent so the complete irregular
	# cut stays inside the texture's growth-ring disc. Tiling mode uses metres.
	var k := 1.0
	if cap_fit_round:
		var reach := 0.0
		for p in loop:
			reach = maxf(reach, (p - centroid).length())
		k = _RING_FIT / maxf(reach, 0.0001)
	for i in range(loop.size()):
		var q1: Vector3 = loop[i]
		var q2: Vector3 = loop[(i + 1) % loop.size()]
		var uvc := Vector2(0.5, 0.5)
		var uv1 := Vector2((q1 - centroid).dot(u), (q1 - centroid).dot(w)) * k + Vector2(0.5, 0.5)
		var uv2 := Vector2((q2 - centroid).dot(u), (q2 - centroid).dot(w)) * k + Vector2(0.5, 0.5)
		# WINDING: the loop is sorted counter-clockwise as seen from the + side of
		# the plane, so (centroid, q1, q2) puts its right-hand-rule normal along
		# +plane.normal — and Godot's front face is the side the RHR normal points
		# AWAY from (its own generate_normals computes -(RHR) as the facing
		# direction). The below piece's cap faces +normal, so it must be wound the
		# other way round, and the above piece's cap likewise. Corrected
		# 2026-07-25 alongside the same error in the voxel mesher; here it was invisible
		# because every cut material in the project is CULL_DISABLED, which draws
		# both sides.
		_cap_tri(below_cap, plane.normal, centroid, q2, q1, uvc, uv2, uv1)
		_cap_tri(above_cap, -plane.normal, centroid, q1, q2, uvc, uv1, uv2)
	return true


## Cap tangents are left to `generate_tangents()` (the cap's UVs are freshly built
## here, so the generated basis is the correct one by construction — unlike the
## body surfaces, whose authored tangents must be preserved). White vertex colours
## so a `vertex_color_use_as_albedo` cut material isn't multiplied to black.
static func _cap_tri(st: SurfaceTool, n: Vector3, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_color(Color.WHITE); st.set_normal(n); st.set_uv(ua); st.add_vertex(a)
	st.set_color(Color.WHITE); st.set_normal(n); st.set_uv(ub); st.add_vertex(b)
	st.set_color(Color.WHITE); st.set_normal(n); st.set_uv(uc); st.add_vertex(c)


static func _emit(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for v: Dictionary in [a, b, c]:
		st.set_normal(v.n)
		st.set_uv(v.uv)
		if v.t != null:
			st.set_tangent(v.t)
		if v.c != null:
			st.set_color(v.c)
		st.add_vertex(v.p)


static func _intersect(p: Dictionary, q: Dictionary) -> Dictionary:
	var t: float = p.d / (p.d - q.d)
	var tan: Variant = null
	if p.t != null and q.t != null:
		var pt: Plane = p.t
		var qt: Plane = q.t
		var dir := pt.normal.lerp(qt.normal, t)
		if dir.length() < 0.0001:
			dir = pt.normal
		# Handedness is per-surface, not per-vertex; never lerp the binormal sign.
		tan = Plane(dir.normalized(), pt.d)
	var col: Variant = null
	if p.c != null and q.c != null:
		col = (p.c as Color).lerp(q.c, t)
	return {
		"p": (p.p as Vector3).lerp(q.p, t),
		"n": (p.n as Vector3).lerp(q.n, t).normalized(),
		"uv": (p.uv as Vector2).lerp(q.uv, t),
		"t": tan,
		"c": col,
		"d": 0.0,
	}


static func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a).normalized()


static func _weld(pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in pts:
		var dup := false
		for q in out:
			if p.distance_to(q) < _WELD_EPS:
				dup = true
				break
		if not dup:
			out.append(p)
	return out


static func _default_cut_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.72, 0.48)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
