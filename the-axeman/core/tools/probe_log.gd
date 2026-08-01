extends SceneTree
## Probe log_a geometry: is it a solid (capped) log or a hollow tube? Reports
## triangle normal distribution and whether top/bottom caps exist.

func _init() -> void:
	var scene: PackedScene = load("res://assets/models/log_a/log_a.fbx")
	var inst := scene.instantiate()
	var mi := _find_mesh(inst)
	var mesh: Mesh = mi.mesh
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var has_idx := idx.size() > 0
	var count := (idx.size() if has_idx else v.size()) / 3
	var top := 0
	var bottom := 0
	var side := 0
	var aabb: AABB = mesh.get_aabb()
	for t in range(count):
		var a: Vector3; var b: Vector3; var c: Vector3
		if has_idx:
			a = v[idx[t*3]]; b = v[idx[t*3+1]]; c = v[idx[t*3+2]]
		else:
			a = v[t*3]; b = v[t*3+1]; c = v[t*3+2]
		var n := (b - a).cross(c - a).normalized()
		if n.y > 0.7: top += 1
		elif n.y < -0.7: bottom += 1
		else: side += 1
	print("=== log_a geometry ===")
	print("tris=%d  aabb_size=%s" % [count, aabb.size])
	print("top-cap tris (n.y>0.7): %d" % top)
	print("bottom-cap tris (n.y<-0.7): %d" % bottom)
	print("side tris: %d" % side)
	print("VERDICT: %s" % ("SOLID (has caps)" if top > 0 and bottom > 0 else "HOLLOW/OPEN (no caps) — slicing will look wrong"))
	quit()

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m != null:
			return m
	return null
