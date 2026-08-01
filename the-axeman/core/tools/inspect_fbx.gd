extends SceneTree
## FILE: res://core/tools/inspect_fbx.gd
## ATTACHES TO: nothing — a SceneTree dev tool, run with -s.
##
## DEV TOOL. Reports the node tree, mesh stats, surface materials and (critically)
## the MEASURED SIZE of any imported FBX, so a new art drop can be checked before
## it is wired into anything. `_fit_scale` normalises a log by its own height, so
## the raw size below does NOT need to match the others — but the surface COUNT
## and the material names do need checking, because MeshUtils.mesh_from_scene
## takes only the FIRST MeshInstance3D it finds.
##
## Run: godot --headless --path . -s res://core/tools/inspect_fbx.gd -- <res://path.fbx> [more...]
##
## Defaults to the three live log meshes when given no paths, so a drop can be
## compared against the logs already shipping.

const _DEFAULTS := [
	"res://assets/models/logs_export/log_01.fbx",
	"res://assets/models/logs_export/log_02.fbx",
	"res://assets/models/logs_export/birch_log_01.fbx",
]


func _init() -> void:
	var paths: Array = []
	for a in OS.get_cmdline_user_args():
		paths.append(a)
	if paths.is_empty():
		paths = _DEFAULTS

	for p: String in paths:
		_report(p)
	quit()


func _report(path: String) -> void:
	print("\n=== %s ===" % path)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("  !! could not load (unimported, or not a scene)")
		return
	var root := packed.instantiate()
	_walk(root, 1)

	# What the game would ACTUALLY get: mesh_from_scene bakes the node transform
	# of the first MeshInstance3D it finds, so report that baked result too.
	var baked := MeshUtils.mesh_from_scene(packed)
	var size := baked.get_aabb().size
	print("  -> mesh_from_scene(): aabb_size=%s  (tallest axis: %s)" % [size, _tallest(size)])
	print("     _fit_scale to 0.42 m => x%.4f" % (0.42 / maxf(size.y, 0.0001)))
	root.free()


func _walk(n: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var extra := ""
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		var tris := 0
		var mats: Array[String] = []
		for s in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(s)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				tris += arr[Mesh.ARRAY_INDEX].size() / 3
			elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
				tris += arr[Mesh.ARRAY_VERTEX].size() / 3
			var m: Material = mesh.surface_get_material(s)
			mats.append("null" if m == null else "%s[%s]" % [m.resource_name, m.get_class()])
		extra = "\n%s    surfaces=%d tris=%d aabb=%s node_scale=%s\n%s    materials: %s" % [
			indent, mesh.get_surface_count(), tris, mesh.get_aabb().size, mi.transform.basis.get_scale(),
			indent, ", ".join(mats),
		]
	print("%s- %s (%s)%s" % [indent, n.name, n.get_class(), extra])
	for c in n.get_children():
		_walk(c, depth + 1)


func _tallest(v: Vector3) -> String:
	if v.y >= v.x and v.y >= v.z:
		return "Y (upright)"
	return "X" if v.x >= v.z else "Z"
