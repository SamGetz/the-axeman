class_name MeshUtils
extends RefCounted
## FILE: res://scenes/3d_action/mesh_utils.gd
## ATTACHES TO: nothing — a static helper library (never instanced).
##
## The mesh maths shared by the runtime-slicing mini-games (M4 chopping, M5
## felling). Every function here was proven in M4's chopping_minigame.gd and was
## lifted out verbatim for M5 rather than copy-pasted — one implementation, one
## place to fix. Nothing here knows about gameplay.
##
## House rules baked in:
##   * Transforms preserve EVERY vertex array (normal/tangent/colour/UV/index)
##     and the per-surface materials. The log and tree materials are normal-
##     mapped and set `vertex_color_use_as_albedo`, so a surface that silently
##     drops TANGENT or COLOR shades differently from its uncut neighbour (the
##     2026-07-23 "sliced pieces look darker" bug — see MeshSlicer's header).
##   * Only uniform scale + translation is offered, so normals stay valid
##     without re-deriving them.


# ------------------------------------------------------------------ transforms
## Uniformly scale then translate every vertex, keeping all other arrays and the
## per-surface materials intact.
static func transformed(src: Mesh, scale := 1.0, offset := Vector3.ZERO) -> ArrayMesh:
	var out := ArrayMesh.new()
	if src == null:
		return out
	for si in range(src.get_surface_count()):
		var arrays := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in range(verts.size()):
			moved[i] = verts[i] * scale + offset
		arrays[Mesh.ARRAY_VERTEX] = moved
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := src.surface_get_material(si)
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


static func scaled(src: Mesh, s: float) -> ArrayMesh:
	return transformed(src, s, Vector3.ZERO)


## Bake an imported node transform into a mesh while preserving its authored
## vertex payload and materials. FBX scenes are allowed to carry unit conversion
## on their MeshInstance3D (tree_02 carries a 180x child transform); extracting
## only `mesh` silently discards that authored scale.
static func transformed_by(src: Mesh, xform: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	if src == null:
		return out
	var normal_basis := xform.basis.inverse().transposed()
	for si in range(src.get_surface_count()):
		var arrays := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in range(verts.size()):
			moved[i] = xform * verts[i]
		arrays[Mesh.ARRAY_VERTEX] = moved

		var raw_n: Variant = arrays[Mesh.ARRAY_NORMAL]
		if raw_n is PackedVector3Array and (raw_n as PackedVector3Array).size() == verts.size():
			var norms: PackedVector3Array = raw_n
			var moved_n := PackedVector3Array()
			moved_n.resize(norms.size())
			for i in range(norms.size()):
				moved_n[i] = (normal_basis * norms[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = moved_n

		var raw_t: Variant = arrays[Mesh.ARRAY_TANGENT]
		if raw_t is PackedFloat32Array and (raw_t as PackedFloat32Array).size() == verts.size() * 4:
			var tans: PackedFloat32Array = raw_t
			var moved_t := PackedFloat32Array()
			moved_t.resize(tans.size())
			var handedness := -1.0 if xform.basis.determinant() < 0.0 else 1.0
			for i in range(verts.size()):
				var tangent := xform.basis * Vector3(
					tans[i * 4], tans[i * 4 + 1], tans[i * 4 + 2])
				tangent = tangent.normalized()
				moved_t[i * 4] = tangent.x
				moved_t[i * 4 + 1] = tangent.y
				moved_t[i * 4 + 2] = tangent.z
				moved_t[i * 4 + 3] = tans[i * 4 + 3] * handedness
			arrays[Mesh.ARRAY_TANGENT] = moved_t

		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := src.surface_get_material(si)
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Rotate every vertex of `src` by `basis` about `pivot`, carrying NORMAL and
## TANGENT round with it (a rotation is the one transform under which they
## transform by the same matrix as the positions, which is why only rotations are
## offered here). Everything else is preserved exactly as `transformed` does.
##
## M5 uses this to bake a tree's natural lean into its geometry before it is
## stood up: leaning the NODE instead would fight the spawn animation and would
## put the voxel band in a tilted frame for no gain.
static func rotated(src: Mesh, basis: Basis, pivot := Vector3.ZERO) -> ArrayMesh:
	var out := ArrayMesh.new()
	if src == null:
		return out
	for si in range(src.get_surface_count()):
		var arrays := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in range(verts.size()):
			moved[i] = pivot + basis * (verts[i] - pivot)
		arrays[Mesh.ARRAY_VERTEX] = moved
		var raw_n: Variant = arrays[Mesh.ARRAY_NORMAL]
		if raw_n is PackedVector3Array and (raw_n as PackedVector3Array).size() == verts.size():
			var norms: PackedVector3Array = raw_n
			var spun := PackedVector3Array()
			spun.resize(norms.size())
			for i in range(norms.size()):
				spun[i] = basis * norms[i]
			arrays[Mesh.ARRAY_NORMAL] = spun
		var raw_t: Variant = arrays[Mesh.ARRAY_TANGENT]
		if raw_t is PackedFloat32Array and (raw_t as PackedFloat32Array).size() == verts.size() * 4:
			var tans: PackedFloat32Array = raw_t
			var spun_t := PackedFloat32Array()
			spun_t.resize(tans.size())
			for i in range(verts.size()):
				var t := basis * Vector3(tans[i * 4], tans[i * 4 + 1], tans[i * 4 + 2])
				spun_t[i * 4] = t.x
				spun_t[i * 4 + 1] = t.y
				spun_t[i * 4 + 2] = t.z
				spun_t[i * 4 + 3] = tans[i * 4 + 3]   # handedness is not a direction
			arrays[Mesh.ARRAY_TANGENT] = spun_t
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := src.surface_get_material(si)
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


static func translated(src: Mesh, offset: Vector3) -> ArrayMesh:
	return transformed(src, 1.0, offset)


## The AABB centre of `src` — the offset you must SUBTRACT to centre it.
static func center_of(src: Mesh) -> Vector3:
	var aabb := src.get_aabb()
	return aabb.position + aabb.size * 0.5


## Re-origin a mesh on its AABB centre (what every spawned piece wants, so its
## node position is its visual centre).
static func centered(src: Mesh) -> ArrayMesh:
	return translated(src, -center_of(src))


# ------------------------------------------------------------- measurement
## Every vertex of every surface, concatenated. Cheap enough for our meshes
## (a few thousand verts); callers that need it per-frame should cache.
static func vertices(mesh: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mesh == null:
		return out
	for si in range(mesh.get_surface_count()):
		out.append_array(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	return out


## Extent of `mesh` projected on `dir`, as (lo, hi). Pass `xform` to measure in
## world space. Returns (INF, -INF) for an empty mesh.
static func extent_along(mesh: Mesh, dir: Vector3, xform := Transform3D.IDENTITY) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in vertices(mesh):
		var d := (xform * p).dot(dir)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)


## 2D convex hull of a mesh in the ground plane, rotated by `q` and centred on
## the mesh origin. Used by M4's separation solver.
static func hull2d(mesh: Mesh, q: Quaternion) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if mesh == null:
		return pts
	for p in vertices(mesh):
		var rp := q * p
		pts.append(Vector2(rp.x, rp.z))
	if pts.size() < 3:
		return pts
	return Geometry2D.convex_hull(pts)


## The largest distance from `axis_xz` reached by the ring where `plane` cuts
## `mesh` — i.e. how wide the cross-section is at that plane. Returns -1.0 when
## the plane misses the mesh entirely.
##
## M5 uses this to place its slab cuts: on a tree, a plane through bare
## trunk gives roughly the trunk radius, while a plane through a branch gives a
## much larger value AND a second cut loop, which MeshSlicer's cap builder (one
## convex loop only) cannot close correctly.
static func cross_section_max_radius(mesh: Mesh, plane: Plane, axis_xz := Vector2.ZERO) -> float:
	var best := -1.0
	if mesh == null:
		return best
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_idx: Variant = arr[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array
		if raw_idx is PackedInt32Array and (raw_idx as PackedInt32Array).size() > 0:
			idx = raw_idx
		else:
			idx = PackedInt32Array()
			for k in range(verts.size()):
				idx.append(k)
		for t in range(0, idx.size() - 2, 3):
			for e in range(3):
				var a := verts[idx[t + e]]
				var b := verts[idx[t + (e + 1) % 3]]
				var da := plane.distance_to(a)
				var db := plane.distance_to(b)
				if (da >= 0.0) == (db >= 0.0):
					continue
				var p := a.lerp(b, da / (da - db))
				best = maxf(best, Vector2(p.x, p.z).distance_to(axis_xz))
	return best


## SOLID width of the horizontal cross-section at height `y`, measured along the
## horizontal direction `dir`: the merged length of every triangle/plane crossing
## projected onto `dir`. Unlike an AABB extent this does not count the AIR between
## disconnected remnants — a trunk chopped clean through at `y`, with corner
## slivers surviving either side, reads as the slivers' wood and nothing else.
## That distinction is the whole fell condition (extent-based thickness left trees
## visibly floating above an empty band while reading as full-width wood).
## Returns 0.0 when the plane misses the mesh entirely.
static func section_width(mesh: Mesh, y: float, dir: Vector3) -> float:
	return section_interval(mesh, y, dir).width


## The full cross-section measurement behind section_width: `width` is the merged
## material length along `dir`, `center` is the material-weighted midpoint of
## that length (in `dir` projection units — comparable with `point.dot(dir)`).
## The M5 load model leans on `center`: as the wedge eats one side of the neck,
## the remaining wood's centre shifts AWAY from the notch, and that shift is the
## moment arm gravity gets to bend the tree with.
static func section_interval(mesh: Mesh, y: float, dir: Vector3) -> Dictionary:
	var out := {"width": 0.0, "center": 0.0}
	if mesh == null:
		return out
	var plane := Plane(Vector3.UP, y)
	var spans: Array[Vector2] = []
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_idx: Variant = arr[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array
		if raw_idx is PackedInt32Array and (raw_idx as PackedInt32Array).size() > 0:
			idx = raw_idx
		else:
			idx = PackedInt32Array()
			for k in range(verts.size()):
				idx.append(k)
		for t in range(0, idx.size() - 2, 3):
			var lo := INF
			var hi := -INF
			for e in range(3):
				var a := verts[idx[t + e]]
				var b := verts[idx[t + (e + 1) % 3]]
				var da := plane.distance_to(a)
				var db := plane.distance_to(b)
				if (da >= 0.0) == (db >= 0.0):
					continue
				var d := a.lerp(b, da / (da - db)).dot(dir)
				lo = minf(lo, d)
				hi = maxf(hi, d)
			if hi >= lo:
				spans.append(Vector2(lo, hi))
	if spans.is_empty():
		return out
	# Merge the per-triangle intervals; the union's length is the visible wood,
	# and its length-weighted midpoint is where that wood sits.
	spans.sort_custom(func(a, b): return a.x < b.x)
	var total := 0.0
	var weighted := 0.0
	var cur := spans[0]
	for i in range(1, spans.size()):
		if spans[i].x <= cur.y + 0.001:
			cur.y = maxf(cur.y, spans[i].y)
		else:
			total += cur.y - cur.x
			weighted += (cur.y - cur.x) * (cur.x + cur.y) * 0.5
			cur = spans[i]
	total += cur.y - cur.x
	weighted += (cur.y - cur.x) * (cur.x + cur.y) * 0.5
	out.width = total
	out.center = weighted / total if total > 0.0001 else 0.0
	return out


## Signed-tetrahedron volume and centroid of a CLOSED mesh (divergence theorem:
## every triangle forms a tetra with the origin; consistent winding makes the
## signs cancel to the enclosed volume). Slicer output and sane DCC exports are
## closed; an open or inside-out mesh reads near zero, so callers must treat a
## tiny |volume| as "unmeasurable" and fall back to an estimate.
static func mesh_volume_centroid(mesh: Mesh) -> Dictionary:
	var vol := 0.0
	var cen := Vector3.ZERO
	if mesh == null:
		return {"volume": 0.0, "centroid": Vector3.ZERO}
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_idx: Variant = arr[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array
		if raw_idx is PackedInt32Array and (raw_idx as PackedInt32Array).size() > 0:
			idx = raw_idx
		else:
			idx = PackedInt32Array()
			for k in range(verts.size()):
				idx.append(k)
		for t in range(0, idx.size() - 2, 3):
			var a := verts[idx[t]]
			var b := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			var v := a.dot(b.cross(c)) / 6.0
			vol += v
			cen += (a + b + c) * 0.25 * v   # tetra centroid, 4th vertex at origin
	if absf(vol) < 0.0001:
		return {"volume": 0.0, "centroid": Vector3.ZERO}
	return {"volume": absf(vol), "centroid": cen / vol}


## Search outward from `target` for a height whose horizontal cross-section is no
## wider than `max_radius` — i.e. a height where the cut passes through bare
## trunk and not through a branch. Returns `target` unchanged if the search
## window holds nothing clean, so a caller always gets a usable height.
static func nearest_clean_height(mesh: Mesh, target: float, lo: float, hi: float,
		max_radius: float, axis_xz := Vector2.ZERO, step := 0.02, max_steps := 40) -> float:
	for i in range(max_steps):
		for h in ([target] if i == 0 else [target + i * step, target - i * step]):
			if h < lo or h > hi:
				continue
			var r := cross_section_max_radius(mesh, Plane(Vector3.UP, h), axis_xz)
			if r > 0.0 and r <= max_radius:
				return h
	return target


# ------------------------------------------------------------------ planes
## Express a WORLD plane in the local space of a node with transform `xform`.
static func plane_to_local(world_plane: Plane, xform: Transform3D) -> Plane:
	var inv := xform.affine_inverse()
	var p_local := inv * (world_plane.normal * world_plane.d)
	# A PLANE'S NORMAL TRANSFORMS BY THE TRANSPOSE OF THE FORWARD BASIS, and that is not the
	# same thing as the transpose of the inverse. For `p_world = B * p_local + t`, substituting
	# into `n_world . p_world = d` gives `(B^T n_world) . p_local = d - n_world . t`, so
	# `n_local = B^T n_world`.
	#
	# This used to read `inv.basis.transposed()`, which for a rotation R evaluates to R rather
	# than R^T — the rotation applied the WRONG WAY ROUND. It was invisible for as long as
	# every caller passed a translation-only transform, which every caller did: the slicer's
	# mesh children sit at offsets, and every tree stood unrotated at the world origin.
	#
	# The moment the forest gave each tree a random YAW it mattered enormously. At 310 degrees
	# the blow's cut planes came out about 98 degrees off, so the convex solid the axe displaces
	# missed the trunk entirely — and because `_cut_slab` advances the site's depth whether or
	# not the carve found wood, the tree reported a notch getting deeper and deeper while not a
	# single voxel was ever removed. `MeshUtils.winding_report`'s sibling lesson: verify the
	# maths against the engine rather than against a case where it cannot be wrong.
	var n_local := (xform.basis.transposed() * world_plane.normal).normalized()
	return Plane(n_local, n_local.dot(p_local))


## Nudge a cut plane so neither side of the split is thinner than `min_size`
## along the cut normal. Keeps the slicer from producing paper slivers.
static func sliver_guard(mesh: Mesh, local_plane: Plane, min_size: float) -> Plane:
	var e := extent_along(mesh, local_plane.normal)
	var o := local_plane.d
	if e.y - o < min_size:
		o = e.y - min_size
	elif o - e.x < min_size:
		o = e.x + min_size
	return Plane(local_plane.normal, o)


# --------------------------------------------------------------- cut faces
## Roughen a fresh cut face so the split reads as cloven wood, not a laser cut.
## Every vertex lying ON `plane` is pushed along its normal by value noise. The
## cap face and the side-wall rim share exact vertex positions and so get the
## SAME displacement — no cracks open between them. The cut surface (the one
## wearing `cut_mat`) is rebuilt as a soup with fresh flat normals so the bumps
## actually shade; other surfaces keep their normals and only their rim moves.
static func jag_cut(mesh: ArrayMesh, plane: Plane, cut_mat: Material,
		amount: float, noise: FastNoiseLite) -> ArrayMesh:
	if amount <= 0.0 or mesh == null or noise == null:
		return mesh
	const EPS := 0.0015
	var n := plane.normal
	var out := ArrayMesh.new()
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var mat := mesh.surface_get_material(si)
		var moved := PackedVector3Array()
		moved.resize(verts.size())
		for i in range(verts.size()):
			var v := verts[i]
			if absf(plane.distance_to(v)) < EPS:
				v += n * (noise.get_noise_3d(v.x, v.y, v.z) * amount)
			moved[i] = v
		if mat == cut_mat:
			_commit_soup(arr, moved, mat, out)
		else:
			arr[Mesh.ARRAY_VERTEX] = moved
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Rebuild one surface as an un-indexed soup with regenerated flat normals and
## tangents. Only ever used on a freshly displaced CUT face, whose UVs are
## generated by the slicer — so a regenerated tangent basis is the correct one
## (unlike an authored surface's, which must be preserved).
static func _commit_soup(arr: Array, moved: PackedVector3Array, mat: Material, out: ArrayMesh) -> void:
	var raw_uv: Variant = arr[Mesh.ARRAY_TEX_UV]
	var uvs: PackedVector2Array = raw_uv if raw_uv is PackedVector2Array else PackedVector2Array()
	var raw_i: Variant = arr[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array
	if raw_i is PackedInt32Array and (raw_i as PackedInt32Array).size() > 0:
		idx = raw_i
	else:
		idx = PackedInt32Array()
		for k in range(moved.size()):
			idx.append(k)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, idx.size() - 2, 3):
		for j in [idx[t], idx[t + 1], idx[t + 2]]:
			if uvs.size() == moved.size():
				st.set_uv(uvs[j])
			st.set_color(Color.WHITE)   # cut_mat may use vertex colour as albedo
			st.add_vertex(moved[j])
	st.generate_normals()
	st.generate_tangents()             # a normal-mapped cut_mat needs a tangent basis
	st.set_material(mat)
	st.commit(out)


# --------------------------------------------------------------- loading
## First MeshInstance3D mesh found depth-first in a node tree.
static func find_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := find_mesh(c)
		if m != null:
			return m
	return null


## First mesh plus its accumulated transform from an imported scene root.
static func _find_mesh_entry(n: Node, parent_xform := Transform3D.IDENTITY) -> Dictionary:
	var here := parent_xform
	if n is Node3D:
		here = parent_xform * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return {"mesh": (n as MeshInstance3D).mesh, "transform": here}
	for child in n.get_children():
		var found := _find_mesh_entry(child, here)
		if not found.is_empty():
			return found
	return {}


## Pull the first mesh out of an imported .fbx/.tscn, BAKING the transforms
## authored on its scene nodes, without leaving the instantiated scene alive.
## Returns a BoxMesh placeholder if nothing is found, so a bad path degrades to
## a visible box instead of a crash.
static func mesh_from_scene(packed: PackedScene) -> Mesh:
	if packed == null:
		return BoxMesh.new()
	var inst := packed.instantiate()
	var found := _find_mesh_entry(inst)
	inst.free()
	if found.is_empty():
		return BoxMesh.new()
	return transformed_by(found.mesh, found.transform)


# ------------------------------------------------------------------- winding
## Does every triangle face the way its shading normal says it does?
##
## Godot's front face is the CLOCKWISE one: the visible side of a triangle is the
## side its right-hand-rule normal `(b-a)x(c-a)` points AWAY from. (The engine's
## own `SurfaceTool.generate_normals` computes `-(RHR)` and calls that the facing
## direction, and every triangle of Godot's BoxMesh, of tree_01.fbx and of
## forest_floor_a.fbx obeys it.) So on correctly wound geometry the RHR normal
## OPPOSES the shading normal, and `agree > 0` means those triangles are inside
## out — under a CULL_BACK material their outer skin is culled and you see
## straight through the surface to the inside of the far wall.
##
## This exists because the voxel mesher got it backwards and it shipped: nothing
## caught it, because the one material involved that culls anything is the bark,
## and the notch's own cut material draws both sides. Cheap to assert, so it is
## asserted.
##
## Returns { "agree", "oppose", "ambiguous" } summed over every surface.
static func winding_report(mesh: Mesh) -> Dictionary:
	var out := {"agree": 0, "oppose": 0, "ambiguous": 0}
	if mesh == null:
		return out
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var raw_n: Variant = arr[Mesh.ARRAY_NORMAL]
		if not (raw_n is PackedVector3Array) or (raw_n as PackedVector3Array).size() != verts.size():
			continue
		var norms: PackedVector3Array = raw_n
		var idx: PackedInt32Array
		var raw_i: Variant = arr[Mesh.ARRAY_INDEX]
		if raw_i is PackedInt32Array and (raw_i as PackedInt32Array).size() > 0:
			idx = raw_i
		else:
			idx = PackedInt32Array()
			idx.resize(verts.size())
			for k in range(verts.size()):
				idx[k] = k
		for t in range(0, idx.size() - 2, 3):
			var a := verts[idx[t]]
			var rhr := (verts[idx[t + 1]] - a).cross(verts[idx[t + 2]] - a)
			if rhr.length() < 1e-9:
				out.ambiguous += 1
				continue
			var sn := norms[idx[t]] + norms[idx[t + 1]] + norms[idx[t + 2]]
			if sn.length() < 1e-9:
				out.ambiguous += 1
				continue
			var d := rhr.normalized().dot(sn.normalized())
			if d > 0.1:
				out.agree += 1
			elif d < -0.1:
				out.oppose += 1
			else:
				out.ambiguous += 1
	return out


static func mesh_from_path(path: String) -> Mesh:
	return mesh_from_scene(load(path) as PackedScene)
