extends Node
## FILE: res://core/tools/probe_skin.gd
## ATTACHES TO: root Node of res://core/tools/probe_skin.tscn. DEV TOOL, not shipped.
##
## Prints what is ACTUALLY bound to each surface of the log on the block, per
## species: the albedo texture, the albedo tint, and whether the material is
## still multiplying the mesh's vertex colours over it.
##
## Written because a rendered PNG said "this log is too dark" and could not say
## WHY — the candidates (the species texture never bound, the oak material's 0.906
## grey, `vertex_color_use_as_albedo` doubling the painted shadows) all look
## identical on screen and are one print apart.

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")
const _SPECIES := [0, 1, 2, 3, 13]


func _ready() -> void:
	for i: int in _SPECIES:
		var row := SpeciesTable.at(i)
		var game: Node = _SCENE.instantiate()
		game.debug_forced_species = i
		game.debug_forced_mesh = 0
		add_child(game)
		await get_tree().process_frame

		print("\n=== [%d] %s ===" % [i, row.display_name])
		print("    table: bark_tex='%s' top_tex='%s' bark_tint=%s"
			% [row.bark_tex.get_file(), row.top_tex.get_file(), row.bark_tint])
		var mesh: Mesh = game._source_mesh
		for si in range(mesh.get_surface_count()):
			var m := mesh.surface_get_material(si) as BaseMaterial3D
			if m == null:
				print("    surface %d: <no BaseMaterial3D>" % si)
				continue
			var tex := m.albedo_texture
			print("    surface %d '%s': albedo=%s  color=%s  vtx_as_albedo=%s  normal=%s" % [
				si, m.resource_name,
				"<none>" if tex == null else tex.resource_path.get_file(),
				m.albedo_color, m.vertex_color_use_as_albedo,
				"<none>" if m.normal_texture == null else m.normal_texture.resource_path.get_file(),
			])
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()
