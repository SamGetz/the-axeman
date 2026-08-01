extends SceneTree
## FILE: res://core/tools/inspect_materials.gd
## ATTACHES TO: nothing — a SceneTree dev tool, run with -s.
##
## DEV TOOL. Prints the ACTUAL texture bound to each surface of an imported FBX.
##
## Why this exists: Godot's scene importer binds an EXTERNAL material when it
## finds a .tres beside the source file whose name matches the FBX's material
## name. `assets/models/logs_export/` already contains `oak_bark.tres` and
## `oak_top.tres`, so any new log FBX authored with material slots of those names
## silently inherits the OAK look — even when the FBX shipped its own embedded
## textures and Godot extracted them to disk. The material NAME alone cannot tell
## the two cases apart; only the bound texture path can.
##
## Run: godot --headless --path . -s res://core/tools/inspect_materials.gd -- <res://path.fbx> [more...]

const _DEFAULTS := [
	"res://assets/models/logs_export/log_01.fbx",
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
		print("  !! could not load")
		return
	var root := packed.instantiate()
	_walk(root)
	root.free()


func _walk(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s in range(mesh.get_surface_count()):
			var m: Material = mesh.surface_get_material(s)
			if m == null:
				print("  surface %d: <null material>" % s)
				continue
			print("  surface %d: '%s'  (resource_path: %s)" % [s, m.resource_name, m.resource_path if m.resource_path != "" else "<embedded>"])
			var bm := m as BaseMaterial3D
			if bm == null:
				continue
			for slot in [
				["albedo", BaseMaterial3D.TEXTURE_ALBEDO],
				["normal", BaseMaterial3D.TEXTURE_NORMAL],
				["rough ", BaseMaterial3D.TEXTURE_ROUGHNESS],
			]:
				var tex: Texture2D = bm.get_texture(slot[1])
				var where: String = "<none>" if tex == null else (tex.resource_path if tex.resource_path != "" else "<embedded texture>")
				print("      %s: %s" % [slot[0], where])
	for c in n.get_children():
		_walk(c)
