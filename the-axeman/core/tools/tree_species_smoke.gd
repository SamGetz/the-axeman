extends Node
## FILE: res://core/tools/tree_species_smoke.gd
## ATTACHES TO: the root Node of res://core/tools/tree_species_smoke.tscn.
##
## DEV/REGRESSION TOOL. Proves that the forest is assembled from every registered
## visual tree type, that source-unit normalisation puts each at a playable scale,
## that the seeded mix is repeatable, and that each asset survives the complete
## preview -> voxel build -> first chop path.
##
## Run:
## godot --headless --path . --quit-after 120000 \
##   res://core/tools/tree_species_smoke.tscn

var _passes := 0
var _fails := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _make_game(forced_species := -1, count := 12) -> Node3D:
	var game: Node3D = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.debug_forced_species = forced_species
	game.player_controlled = false
	game.natural_lean_deg = 0.0
	game.tree_size_variation = 0.0
	game.tree_count = count
	game.forest_radius = 20.0
	game.voxel_cell = 0.055
	game.bite_depth = 0.065
	game.cut_span = 1.6
	game.cut_reach = 0.3
	game.entry_angle_deg = 30.0
	return game


func _ready() -> void:
	print("=== TREE SPECIES SMOKE ===")
	var game := _make_game()
	add_child(game)
	await get_tree().process_frame

	var catalog: Array = game.debug_species_catalog()
	_check(catalog.size() == 2, "two visual tree types are registered")
	var registered := {}
	for row: Dictionary in catalog:
		var id: StringName = row.get("id", &"")
		registered[id] = true
		print("%s: model=%s source_scale=%.1f" % [
			id, row.get("model", ""), float(row.get("source_scale", 0.0))])
		_check(ResourceLoader.exists(row.get("model", "")),
			"%s model exists" % id)
		_check(ResourceLoader.exists(row.get("def", "")),
			"%s TreeDef exists" % id)
		_check(float(row.get("source_scale", 0.0)) > 0.0,
			"%s has positive source-unit normalisation" % id)
	_check(registered.has(&"tree_01") and registered.has(&"tree_02"),
		"the catalog contains tree_01 and tree_02")

	var trees: Array = game.debug_trees()
	var by_type := {}
	var sequence: Array[StringName] = []
	for raw_tree in trees:
		var tree := raw_tree as TreeTrunk
		sequence.append(tree.species_id)
		if not by_type.has(tree.species_id):
			by_type[tree.species_id] = tree
	_check(by_type.has(&"tree_01") and by_type.has(&"tree_02"),
		"the seeded stand contains both registered visual types")

	# A second stand with the same seed must receive the same type in every slot.
	var game2 := _make_game()
	add_child(game2)
	await get_tree().process_frame
	var trees2: Array = game2.debug_trees()
	var same_mix := trees2.size() == sequence.size()
	if same_mix:
		for i in range(trees2.size()):
			if (trees2[i] as TreeTrunk).species_id != sequence[i]:
				same_mix = false
				break
	_check(same_mix, "forest_seed reproduces the same type in every tree slot")
	game2.queue_free()
	await get_tree().process_frame

	# Every scattered yaw/size must take a first blow, not merely one friendly
	# representative of each model. Hold failure out of the way so a broad tree's
	# load cannot stop the test after the first few slots.
	game.fail_stress = 1000000.0
	var missed_first := 0
	var recovered_second := 0
	for raw_tree in trees:
		var tree := raw_tree as TreeTrunk
		game.debug_stand_at_tree(tree)
		game.debug_engage(tree)
		var cut_y := lerpf(tree.band_lo, tree.band_hi, 0.5)
		if not game.debug_chop_tree(tree, 1, cut_y):
			missed_first += 1
			if game.debug_chop_tree(tree, 1, cut_y):
				recovered_second += 1
		await get_tree().process_frame
	print("mixed stand first-blow misses: %d; recovered on second: %d" % [
		missed_first, recovered_second])
	_check(missed_first == 0,
		"every seeded yaw and size accepts its first felling blow (%d misses)" % missed_first)

	game.queue_free()
	await get_tree().process_frame

	# Exercise the actual M5 geometry path for both assets in isolated games. A
	# catalog entry is not support unless its mesh can become wood and a blow
	# measurably removes some; isolation also proves one tree's fall state cannot
	# make the other type look unchoppable.
	for species_index in range(catalog.size()):
		var row: Dictionary = catalog[species_index]
		var id: StringName = row.id
		# Use slot 1: the forest gives every non-first tree a seeded yaw, so this
		# checks the rotated-world-plane path as well as the source mesh itself.
		var species_game := _make_game(species_index, 2)
		add_child(species_game)
		await get_tree().process_frame
		var species_trees: Array = species_game.debug_trees()
		var tree: TreeTrunk = species_trees[1] if species_trees.size() > 1 else null
		_check(tree != null, "%s has a representative in the stand" % id)
		if tree == null:
			species_game.queue_free()
			await get_tree().process_frame
			continue
		var height := tree.source_mesh.get_aabb().size.y
		_check(height >= 5.0 and height <= 20.0,
			"%s is normalised to a playable height (%.2f m)" % [id, height])
		_check(tree.def != null, "%s carries its TreeDef" % id)
		_check(tree.trunk_surface == int(row.trunk_surface),
			"%s carries its declared trunk surface (%d)" % [id, tree.trunk_surface])
		var declared_canopy: Array[int] = []
		for surface in row.canopy_surfaces:
			declared_canopy.append(int(surface))
		_check(tree.canopy_surfaces == declared_canopy,
			"%s carries every declared canopy surface %s" % [id, declared_canopy])
		species_game.debug_stand_at_tree(tree)
		var built: bool = species_game.debug_engage(tree)
		_check(built and tree.is_built(), "%s builds a voxel trunk" % id)
		if not built:
			species_game.queue_free()
			await get_tree().process_frame
			continue
		var bark_found := false
		var band: Mesh = tree.band_mesh()
		for surface in range(band.get_surface_count()):
			var material := band.surface_get_material(surface)
			if material != null and "bark" in material.resource_name.to_lower():
				bark_found = true
				break
		_check(bark_found, "%s voxel trunk keeps its bark material" % id)

		# A BLOW MUST LAND IN WOOD THE PLAYER CAN SEE, and that is a per-ASSET claim, which
		# is why it lives here rather than in m5_acceptance's one pinned tree.
		#
		# Two things conspired to hide every cut, and this asserts the ONE invariant that
		# closes both. `TreeTrunk._clear_trunk_height` scans up the mesh for the first thing
		# wider than a trunk and calls that the branches; both FBXs splay at the butt well
		# past that line (tree_01 to 1.56x the trunk radius in the first 10 cm, tree_02 to
		# 1.77x), so the scan stopped in its first bin and `_MIN_BAND` collapsed the band to
		# 0.9 m on every tree in the forest. And the crown's imported mesh is clipped
		# `_CROWN_OVERLAP` cells BELOW the band top and laps down over it, so the top 0.14 m
		# of any band is behind the crown — while `_aim` clamped an eye-height crosshair to
		# `band_hi`, i.e. into exactly that strip. MEASURED before the fix: nine blows took
		# 0.139 m³ out of tree_01 and changed ZERO pixels on screen.
		#
		# So: aim at eye height and check the blow is placed in the VISIBLE band. A band
		# length would not do it — the second half of the bug is scale-free and bites a
		# 0.9 m band and a 3.9 m one identically.
		var eye: float = (species_game.get_node("Player") as Node3D).get("eye_height")
		var capped: float = species_game.debug_max_cut_height(tree)
		_check(capped <= tree.crown_base() + 0.001,
			"%s places an eye-height blow in wood that is drawn (%.2f m, crown starts %.2f m)" % [
				id, capped, tree.crown_base()])
		_check(capped > tree.band_lo + 0.4,
			"%s has real trunk to chop below that (%.2f m of eye height %.2f m)" % [
				id, capped - tree.band_lo, eye])
		# ...and the band must still stop BELOW the branches, or the field's radial profile
		# clamps them back to the trunk and the tree comes out a bare pole.
		_check(tree.band_hi < tree.source_mesh.get_aabb().end.y * 0.75,
			"%s stops the band below its crown (%.2f m of %.2f m)" % [
				id, tree.band_hi, tree.source_mesh.get_aabb().end.y])

		# THE AXE REACHES THE ROOTS (`voxel_roots`, 2026-07-31). Sam: *"I want to be able to
		# cut all the way down to the roots on the trunk"*, and before that *"this shelf looks
		# really bad and just feels like a removal of player agency"*. The shelf WAS the
		# uncarveable roots piece: the band's floor sat on top of the flare, so the lowest a
		# blow could land was 0.60 m (tree_01) / 0.40 m (tree_02) and a cut that went right
		# through the stem left the flare standing as a plinth.
		#
		# Asserted against the FLARE, per asset, because that is the thing that was out of
		# reach — a bare metre value would pass on a tree whose flare happens to be short.
		#
		# ASSERTED EITHER WAY ROUND THE SWITCH (2026-07-31, later the same day). `voxel_roots`
		# went back OFF because it is what makes the flare's bark smear and doubles the cost
		# of a blow — so these cannot demand the ON behaviour unconditionally, and deleting
		# them would leave the ON path uncovered the next time Sam wants it. Each one states
		# what the CONFIGURED game should do.
		var roots_on: bool = species_game.voxel_roots
		var low: float = species_game.debug_min_cut_height(tree)
		if roots_on:
			_check(low < tree.debug_flare_top(),
				"%s lets the axe reach INTO the root flare (lowest blow %.2f m, flare top %.2f m)" % [
					id, low, tree.debug_flare_top()])
			_check(tree.band_lo <= tree.ground_y + 0.001,
				"%s carves from the dirt up — no plinth (band floor %.3f m, dirt %.3f m)" % [
					id, tree.band_lo, tree.ground_y])
		else:
			# The flare stays the artist's mesh, and the band's floor sits on top of it. That
			# is the whole difference, and it is what keeps the bark the artist's bark.
			_check(tree.band_lo >= tree.debug_flare_top() - 0.001,
				"%s keeps the root flare as authored mesh (band floor %.2f m, flare top %.2f m)" % [
					id, tree.band_lo, tree.debug_flare_top()])
			_check(low >= tree.band_lo - 0.001,
				"%s puts every blow in the voxel band (lowest blow %.2f m, band floor %.2f m)" % [
					id, low, tree.band_lo])
		# ...and a blow down there takes real wood, rather than reporting a cut in thin air.
		var root_wood: float = tree.volume().volume()
		var root_hit: bool = species_game.debug_chop_tree(tree, 1, low + 0.02)
		await get_tree().process_frame
		_check(root_hit and tree.volume().volume() < root_wood - 0.0001,
			"%s loses real wood to a blow in the flare (%.4f -> %.4f m3)" % [
				id, root_wood, tree.volume().volume()])
		# ...and the END GRAIN on it is wood, not the white field around the ring texture.
		# `_cut_mat` is a SINGLE growth-ring round on white with `texture_repeat` off, so any
		# cut face mapped past the disc clamps to that white — tinted by `cut_wood_tint` it
		# comes out as a FLAT GREY PATCH, which is what a chopped flare rendered as until
		# 2026-07-31. The ring is fitted from the RADIAL PROFILE, and `voxel_roots` builds
		# that from the clear stem only while filling the buttresses from the mesh, so the
		# fit has to be widened to the wood that is actually there. Third time this mapping
		# has overflowed on an unmeasured path — hence a check.
		# Asked at TWO heights, because the failure is at both ends: fit the round once to the
		# stem and a flare cut clamps to white; fit it once to the flare and a stem cut uses
		# the inner third of the disc and goes dark. It is per level (`WoodVolume.ring_at`).
		var flare_ring: float = tree.volume().ring_at(low + 0.02)
		var stem_ring: float = tree.volume().ring_at(tree.crown_base() - 0.2)
		if roots_on:
			_check(flare_ring > stem_ring * 1.2,
				"%s fits the end-grain round where the cut is (flare %.2f m vs stem %.2f m)" % [
					id, flare_ring, stem_ring])
		else:
			# No buttresses in the band, so the round barely varies over it — but it must
			# still be fitted to real wood at both ends rather than collapsing to nothing.
			_check(flare_ring > 0.05 and stem_ring > 0.05,
				"%s fits the end-grain round to real wood at both ends (%.2f m / %.2f m)" % [
					id, flare_ring, stem_ring])
		_check(flare_ring >= tree.band_max_radius * 0.7,
			"%s covers the buttresses, so a flare cut is wood not white (%.2f m of %.2f m)" % [
				id, flare_ring, tree.band_max_radius])

		var before: float = tree.volume().volume()
		# Deliberately use the old gameplay/test aim height. tree_02's clear
		# voxel stem ends just below this, so the strike must clamp into its
		# own band rather than create a cut in empty space.
		var cut_y := 0.5
		var landed: bool = species_game.debug_chop_tree(tree, 1, cut_y)
		await get_tree().process_frame
		var after: float = tree.volume().volume()
		_check(landed, "%s accepts a felling blow" % id)
		_check(after < before - 0.0001,
			"%s loses measured wood (%.4f -> %.4f m3)" % [id, before, after])
		_check(not species_game.is_felling(),
			"%s remains standing after its opening blow" % id)
		var blows := 1
		while blows < 60 and not species_game.is_felling():
			species_game.debug_chop_tree(tree, 1, cut_y)
			blows += 1
			await get_tree().process_frame
		print("%s felled after %d repeated blows" % [id, blows])
		_check(species_game.is_felling(),
			"%s eventually fells from continued chopping" % id)
		_check(blows > 1,
			"%s takes repeated blows rather than one swing (%d)" % [id, blows])
		var falling_canopies := species_game.find_children(
			"ShedCanopy", "MeshInstance3D", true, false)
		var canopy_surface_count := 0
		if falling_canopies.size() == 1:
			var canopy_mesh := (falling_canopies[0] as MeshInstance3D).mesh
			canopy_surface_count = canopy_mesh.get_surface_count() if canopy_mesh != null else 0
		_check(canopy_surface_count == declared_canopy.size(),
			"%s carries all %d canopy surfaces through the fall" % [
				id, declared_canopy.size()])
		species_game.queue_free()
		await get_tree().process_frame

	print("=== TREE SPECIES SMOKE: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== TREE SPECIES SMOKE OK ===")
	get_tree().quit()
