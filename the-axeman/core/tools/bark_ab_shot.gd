extends Node
## DEV TOOL (not shipped). THE SAME TREE, FROM THE SAME CAMERA, BEFORE AND AFTER THE
## VOXEL BAND REPLACES ITS TRUNK. This is the tool for "it looks fine before it is cut
## and wrong afterwards": the band's bark is regenerated off a voxel field and can only
## ever INFER the artist's mapping, so the only honest check is an A/B at one camera.
##
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##     --position 3000,3000 res://core/tools/bark_ab_shot.tscn -- species=1
##
## Output: %APPDATA%/Godot/app_userdata/the-axeman/barkab_*.png
##
## It shoots a tree the game has NOT built. `_spawn_stand` deliberately builds the one
## the player starts next to, so a stand of two is planted and the previewed one is used.

const OUT := "user://barkab"

@export var species := 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	var forced := species
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("species="):
			forced = int(arg.split("=")[1])

	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = forced
	game.natural_lean_deg = 0.0
	game.player_controlled = false
	game.tree_count = 2
	game.tree_size_variation = 0.0
	# ...and the LAZY build, because the whole point of this tool is to see a tree before
	# and after its band replaces its trunk. The game ships `prebuild_stand` ON precisely
	# so a player never sees that, which leaves nothing to shoot unless it is turned off
	# here (2026-07-30).
	game.prebuild_stand = false
	game.trunk_persists = false
	game.gravity = 9.8
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	add_child(game)
	await _wait(1.2)

	var subject: TreeTrunk = null
	for t in game.debug_trees():
		if (t as TreeTrunk).is_preview():
			subject = t
			break
	if subject == null:
		push_error("bark_ab_shot: every tree was built at load — nothing to shoot 'before'.")
		get_tree().quit()
		return
	# Square on, so the two shots differ only in what replaced the trunk.
	subject.rotation.y = 0.0

	# A previewed tree has already been measured, so it knows where its band would start
	# and therefore where the roots will hand over. Frame that height CLOSE and nearly
	# LEVEL — the first pass of this tool shot the butt from 2.6 m looking down from eye
	# height, which foreshortens a strip 5 cm tall into a hairline and is why the first
	# reading of this bug was far too optimistic.
	# ...from `voxel_cell`, not from the trunk's own WoodVolume: a PREVIEWED tree has no
	# field yet, which is the whole reason it is the subject.
	var join_y: float = subject.band_lo + float(game.voxel_cell) * 2.5

	for framing in [
		{"tag": "join", "dist": 1.3, "focus": join_y, "eye": join_y + 0.35},
		# ...and LOOKING DOWN ON IT, which is how Sam's screenshots are taken and is the
		# framing that shows a horizontal ring for what it is. Level with a ring you see an
		# edge; above it you see its whole width.
		{"tag": "down", "dist": 1.2, "focus": join_y, "eye": join_y + 0.95},
		{"tag": "butt", "dist": 2.6, "focus": 0.75, "eye": 0.0},
		{"tag": "eye", "dist": 3.4, "focus": 1.65, "eye": 0.0},
	]:
		game.debug_stand_at_tree(subject, framing["dist"], framing["focus"])
		if framing["eye"] > 0.0:
			game.cam_height = framing["eye"]
		await _wait(0.6)
		_save("_%s_1_before" % framing["tag"])
		if subject.is_preview():
			game.debug_engage(subject)
			var v: WoodVolume = subject.volume()
			print("built: band %.3f..%.3f  crown_base %.3f  radius %.3f" % [
				subject.band_lo, subject.band_hi, subject.crown_base(), subject.radius])
			print("  bark fit: fitted=%s  u/turn %.4f  v/m %.4f  offset (%.4f, %.4f)" % [
				v.bark_uv_fitted, v.bark_uv.x, v.bark_uv.y,
				v.bark_uv_offset.x, v.bark_uv_offset.y])
			await _wait(0.6)
		_save("_%s_2_after" % framing["tag"])
	# AND THE THING THE PLAYER ACTUALLY DOES: chop it, and look at the cut from where they
	# are standing. Sam's screenshots are of a CHOPPED trunk; every earlier shot in this
	# tool was of a built-but-never-struck one, which is not the same picture at all.
	# THE SHIPPING SCENE'S OWN CUT SETTINGS, not this tool's. `tree_felling.tscn` chops with
	# a 3 cm bite on a 5.5 cm grid — barely a voxel deep — so a blow leaves a shallow, wide
	# scallop whose faces are nearly TANGENT to the trunk, i.e. nearly vertical. That is the
	# exact case the end-grain projection smears, and testing with a 6.5 cm gouge (which is
	# mostly roof and floor) is why the first look at this badly understated it.
	game.bite_depth = 0.03
	game.cut_span = 0.5
	game.cut_reach = 0.01
	var cut_y: float = subject.band_lo + 0.9
	game.debug_stand_at_tree(subject, 1.6, cut_y)
	game.cam_height = cut_y + 0.15
	await _wait(0.5)
	_save("_cut_0_before")
	for i in range(4):
		game.debug_chop_tree(subject, 1, cut_y)
		await _wait(0.3)
	await _wait(0.5)
	_save("_cut_1_chopped")
	game.debug_orbit_camera(35.0)
	await _wait(0.5)
	_save("_cut_2_from_the_side")
	# ...and the SAME CUT with the grain routing switched off, which is the behaviour
	# before 2026-07-30: every cut face on the end-grain ring projection, including the
	# near-vertical wall at the back of the kerf. One run, one camera, one cut — the only
	# honest way to show what the change did.
	var vol: WoodVolume = subject.volume()
	# How much of the cut actually IS long grain — a routing change nobody can count is a
	# routing change nobody can trust.
	var whole: Mesh = subject.band_mesh()
	for si in range(whole.get_surface_count()):
		var arr := whole.surface_get_arrays(si)
		print("  band surface %d: %d verts, material %s" % [si,
			(arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
			str(whole.surface_get_material(si))])
	var keep: Material = vol.side_mat
	vol.side_mat = null
	_force_remesh(subject)
	await _wait(0.5)
	_save("_cut_3_rings_everywhere")
	vol.side_mat = keep
	_force_remesh(subject)
	await _wait(0.4)
	game.debug_orbit_camera(-35.0)
	await _wait(0.4)

	# ...and the pieces on their own, which is the only way to attribute a line at the
	# join to one of them rather than guess (the trick `seam_layers` uses at the crown).
	#
	game.debug_stand_at_tree(subject, 1.3, join_y)
	game.cam_height = join_y + 0.35
	await _wait(0.5)
	var band: Node3D = subject.get_node_or_null("Butt")
	var roots: MeshInstance3D = subject.get_node_or_null("Roots")
	if band != null and roots != null:
		roots.visible = false
		await _wait(0.4)
		_save("_layer_band_only")
		roots.visible = true
		band.visible = false
		await _wait(0.4)
		_save("_layer_roots_only")
		band.visible = true
		# ...and WHICH PIXELS ARE WHOSE, flat-shaded. A ledge at the join is either the
		# roots' rim or the band's; a photograph of bark cannot tell you which.
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color(0.0, 0.9, 1.0)
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		roots.material_override = flat
		await _wait(0.4)
		_save("_layer_roots_flagged")
		roots.material_override = null
		# ...and BOTH PIECES UNSHADED, same bark texture. A line that survives this is
		# geometry or UV; a line that vanishes is the imported mesh's authored normals
		# meeting the band's SDF-gradient ones, which no amount of radius fitting touches.
		var unlit: Material = subject._bark_mat
		if unlit is StandardMaterial3D:
			var u := (unlit as StandardMaterial3D).duplicate() as StandardMaterial3D
			u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			roots.material_override = u
			for c in band.get_children():
				(c as MeshInstance3D).material_override = u
			await _wait(0.4)
			_save("_butt_3_unshaded")
			roots.material_override = null
			for c in band.get_children():
				(c as MeshInstance3D).material_override = null
			await _wait(0.3)
		# ...and the roots' own CUT CAP on its own. The slicer caps the roots' top with the
		# end-grain material, and that disc is meant to be buried inside the band. If the
		# strip at the join lights up, it is not buried.
		for si in range(roots.mesh.get_surface_count()):
			var m := roots.mesh.surface_get_material(si)
			if m != null and m == subject._cut_mat:
				var pick := StandardMaterial3D.new()
				pick.albedo_color = Color(0.1, 1.0, 0.1)
				pick.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				roots.set_surface_override_material(si, pick)
		await _wait(0.4)
		_save("_layer_root_cap_flagged")
		for si in range(roots.mesh.get_surface_count()):
			roots.set_surface_override_material(si, null)
		var flat2 := StandardMaterial3D.new()
		flat2.albedo_color = Color(1.0, 0.1, 0.6)
		flat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for c in band.get_children():
			(c as MeshInstance3D).material_override = flat2
		await _wait(0.4)
		_save("_layer_band_flagged")
	get_tree().quit()


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)


## Re-surface the WHOLE band. `TreeTrunk._remesh()` only rebuilds the chunks a blow marked
## dirty, so changing a rendering knob and calling it re-meshes NOTHING and the A/B comes
## out as two identical pictures — which is exactly what happened, twice, on 2026-07-30.
func _force_remesh(trunk: TreeTrunk) -> void:
	var v: WoodVolume = trunk.volume()
	v._mark_chunks(0, maxi(v.ny - 2, 0))
	trunk._remesh()
