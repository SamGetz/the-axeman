extends SceneTree
## DEV TOOL. Loads the imported tree FBX and reports its node/mesh stats
## (surfaces, tris, AABB, materials) so M5 can size the trunk, pick the notch
## height and tell trunk geometry from foliage.
## Run: godot --headless --path . -s res://core/tools/inspect_tree.gd

const TREE_PATHS := [
	"res://assets/models/trees_export/tree_01.fbx",
	"res://assets/models/trees_export/tree_02.fbx",
]


func _walk(n: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var extra := ""
	if n is Node3D and not (n as Node3D).transform.is_equal_approx(Transform3D.IDENTITY):
		extra = " | transform=%s" % (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		var aabb: AABB = mesh.get_aabb()
		var surf: int = mesh.get_surface_count()
		extra += " | MESH surfaces=%d aabb_size=%s aabb_pos=%s" % [surf, aabb.size, aabb.position]
		for s in range(surf):
			var arr: Array = mesh.surface_get_arrays(s)
			var tris := 0
			if arr[Mesh.ARRAY_INDEX] != null:
				tris = arr[Mesh.ARRAY_INDEX].size() / 3
			elif arr[Mesh.ARRAY_VERTEX] != null:
				tris = arr[Mesh.ARRAY_VERTEX].size() / 3
			var mat: Material = mesh.surface_get_material(s)
			var mat_name := "<none>"
			if mat != null:
				mat_name = "%s '%s'" % [mat.get_class(), mat.resource_name]
			var has_uv: bool = arr[Mesh.ARRAY_TEX_UV] != null
			var has_col: bool = arr[Mesh.ARRAY_COLOR] != null
			var has_tan: bool = arr[Mesh.ARRAY_TANGENT] != null
			extra += "\n%s    surf %d: tris=%d uv=%s col=%s tan=%s mat=%s" % [
				indent, s, tris, has_uv, has_col, has_tan, mat_name]
	print("%s- %s (%s)%s" % [indent, n.name, n.get_class(), extra])
	for c in n.get_children():
		_walk(c, depth + 1)


func _init() -> void:
	for path in TREE_PATHS:
		var scene: PackedScene = load(path)
		if scene == null:
			push_error("inspect_tree: could not load " + path)
			continue
		var root := scene.instantiate()
		print("=== %s scene tree ===" % path)
		_walk(root, 0)
		root.free()
	quit()
