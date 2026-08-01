extends SceneTree
## DEV TOOL. Loads the imported chopping_stump_a scene and reports mesh stats
## (scale cm-vs-m, orientation, footprint) so we can place it as the stump.
## Run: godot --headless -s res://core/tools/inspect_stump.gd

func _walk(n: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var extra := ""
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		var aabb: AABB = mesh.get_aabb()
		var surf: int = mesh.get_surface_count()
		var tris := 0
		for s in range(surf):
			var arr: Array = mesh.surface_get_arrays(s)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				tris += arr[Mesh.ARRAY_INDEX].size() / 3
			elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
				tris += arr[Mesh.ARRAY_VERTEX].size() / 3
		extra = " | MESH surfaces=%d tris=%d aabb_size=%s aabb_pos=%s" % [surf, tris, aabb.size, aabb.position]
	print("%s- %s (%s)%s" % [indent, n.name, n.get_class(), extra])
	for c in n.get_children():
		_walk(c, depth + 1)

func _init() -> void:
	var scene: PackedScene = load("res://assets/models/chopping_stump_a/chopping_stump_a.fbx")
	if scene == null:
		push_error("inspect_stump: could not load chopping_stump_a.fbx")
		quit()
		return
	var root := scene.instantiate()
	print("=== chopping_stump_a.fbx scene tree ===")
	_walk(root, 0)
	quit()
