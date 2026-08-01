extends Node
## DEV TOOL. WHAT IT COSTS TO VOXELISE THE WHOLE STAND AT SPAWN instead of on each
## tree's first blow.
##
## Lazy building is plan §3a and is why a 25-tree stand is affordable at all — but it is
## also why the first strike on every tree pays a visible lag AND swaps the trunk's
## geometry under the player (2026-07-30, Sam: *"there is a small lag, then the texture of
## the tree rotates ... there doesn't need to be a sleight of hand texture swap"*). This
## measures the price of not doing it, so the trade is made on numbers.
##
##   godot --headless --path . --quit-after 200000 res://core/tools/eager_build_probe.tscn

func _ready() -> void:
	var game: Node = load("res://scenes/3d_action/tree_felling.tscn").instantiate()
	game.player_controlled = false
	game.natural_lean_deg = 0.0
	add_child(game)
	await get_tree().process_frame

	var trees: Array = game.debug_trees()
	var built := 0
	for t in trees:
		if not (t as TreeTrunk).is_preview():
			built += 1
	print("stand: %d trees, %d built at spawn (the lazy design builds exactly 1)"
		% [trees.size(), built])

	var t0 := Time.get_ticks_usec()
	var samples := 0
	var slowest := 0.0
	for t in trees:
		var trunk: TreeTrunk = t
		if not trunk.is_preview():
			continue
		var a := Time.get_ticks_usec()
		game.debug_engage(trunk)
		var ms := float(Time.get_ticks_usec() - a) / 1000.0
		slowest = maxf(slowest, ms)
		var v: WoodVolume = trunk.volume()
		if v != null:
			samples += v.nx * v.ny * v.nz
	var total := float(Time.get_ticks_usec() - t0) / 1000.0
	var n := trees.size() - built
	print("built the remaining %d: %.0f ms total, %.1f ms mean, %.1f ms worst"
		% [n, total, total / maxf(float(n), 1.0), slowest])

	for t in trees:
		var v: WoodVolume = (t as TreeTrunk).volume()
		if v != null and t == trees[0]:
			samples += 0
	print("field samples across the stand: %d" % samples)
	# `_d` and `_cut` are one float and one byte per sample; the cached surface adds a
	# vertex, a normal, a UV, an angle and a flag per CELL. That is what a field costs to
	# hold, and holding 25 of them instead of 1 is the whole question.
	var field_mb := float(samples) * 5.0 / 1048576.0
	var cache_mb := float(samples) * 37.0 / 1048576.0
	print("  ~%.1f MB of field, ~%.1f MB of cached surface, ~%.1f MB total"
		% [field_mb, cache_mb, field_mb + cache_mb])
	print("  (a lazy stand holds one tree's worth: ~%.1f MB)"
		% ((field_mb + cache_mb) / maxf(float(trees.size()), 1.0)))
	get_tree().quit()
