class_name MeshUtils
extends RefCounted
## FILE: res://scenes/3d_action/mesh_utils.gd
## ATTACHES TO: nothing — a static helper library (never instanced).
##
## Shared mesh maths for chopping and loose-root fragmentation. Nothing here
## knows about gameplay.
##
## House rules baked in:
##   * Transforms preserve EVERY vertex array (normal/tangent/colour/UV/index)
##     and the per-surface materials. The log and tree materials are normal-
##     mapped and set `vertex_color_use_as_albedo`, so a surface that silently
##     drops TANGENT or COLOR shades differently from its uncut neighbour (the
##     2026-07-23 "sliced pieces look darker" bug — see MeshSlicer's header).
##   * Only uniform scale + translation is offered, so normals stay valid
##     without re-deriving them.

const _CONVEX_SHAPE_META := &"axeman_cached_convex_shape"
const _BOX_SHAPE_META := &"axeman_cached_box_shape"
static var _convex_shape_build_count := 0


## Runtime slices frequently move the same mesh between visual owners and rebuild
## compound bodies around unchanged descendants. QuickHull is synchronous and was
## being rerun for those identical resources on every cut. Shape3D resources are
## immutable/shareable here, so keep one beside the Mesh that owns its lifetime.
static func convex_shape(mesh: Mesh) -> Shape3D:
	if mesh == null:
		return null
	var cached := mesh.get_meta(_CONVEX_SHAPE_META) as Shape3D \
		if mesh.has_meta(_CONVEX_SHAPE_META) else null
	if cached != null:
		return cached
	var shape := mesh.create_convex_shape()
	if shape != null:
		_convex_shape_build_count += 1
		mesh.set_meta(_CONVEX_SHAPE_META, shape)
	return shape


## Sliced descendants already form a compound body. Tight per-descendant AABB
## primitives preserve that compound footprint while avoiding a synchronous
## QuickHull build for every fresh half on the exact trigger frame.
static func box_shape(mesh: Mesh) -> BoxShape3D:
	if mesh == null:
		return null
	var cached := mesh.get_meta(_BOX_SHAPE_META) as BoxShape3D \
		if mesh.has_meta(_BOX_SHAPE_META) else null
	if cached != null:
		return cached
	var shape := BoxShape3D.new()
	shape.size = mesh.get_aabb().size
	mesh.set_meta(_BOX_SHAPE_META, shape)
	return shape


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
## the mesh origin.
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
	var n_local := (xform.basis.transposed() * world_plane.normal).normalized()
	return Plane(n_local, n_local.dot(p_local))


## The inverse of `plane_to_local`: express a LOCAL plane (as stored against a
## node) as a WORLD plane under that node's current `xform`.
##
## `plane_to_local` transforms the normal by the TRANSPOSE of the forward basis
## (`n_local = B^T n_world`); going the other way therefore wants the inverse of
## that transpose, `n_world = (B^T)^-1 n_local = (B^-1)^T n_local`. `xform.basis`
## here is always a pure rotation (every caller bakes scale into the mesh, never
## the node — see this file's house rules), and a rotation's inverse IS its
## transpose, so `(B^-1)^T` collapses to `B` itself. This is not the general
## case: a scaled or sheared `xform` would need the real `(B^-1)^T`, not `B`.
static func plane_to_world(local_plane: Plane, xform: Transform3D) -> Plane:
	var n_world := (xform.basis * local_plane.normal).normalized()
	var p_world: Vector3 = xform * (local_plane.normal * local_plane.d)
	return Plane(n_world, n_world.dot(p_world))


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
