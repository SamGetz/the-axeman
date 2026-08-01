extends SceneTree
## DEV TOOL (not shipped). Writes the M5 TreeDef resources so Godot itself
## serialises the typed `Array[FragmentDef]` correctly instead of us hand-editing
## .tres text. Re-run after changing the numbers below, then commit the .tres.
## Run: godot --headless --path . -s res://core/tools/build_tree_defs.gd
##
## EVERY value here is a PLACEHOLDER (Directive 3) — Sam owns the final numbers,
## and once the .tres exists they are edited in the inspector, not here.

const OUT_DIR := "res://data/trees"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_write_pine()
	quit()


func _write_pine() -> void:
	# A single LEAF FragmentDef: felling a pine is worth this much pine_log.
	# Leaf = no sub_fragments, so yield_item/yield_amount are the operative
	# fields (fragment_def.gd's contract). This is what lands in the inventory as
	# the felled tree dissolves.
	var pine_logs := FragmentDef.new()
	pine_logs.resource_name = "pine_tree_logs"
	pine_logs.size_tier = 3
	pine_logs.yield_item = &"pine_log"
	pine_logs.yield_amount = 4

	var pine := TreeDef.new()
	pine.resource_name = "pine_tree"
	pine.biome = Enums.Biome.PINE_FOREST
	pine.hardness_level = 1          # tier-1 axe (the fresh-save default) can fell it
	pine.integrity_per_cut = 1
	pine.quadrant_stage_meshes = []  # A2's authored fracture path is unused under Amendment 10
	pine.yields = [pine_logs]

	var path := OUT_DIR + "/pine_tree.tres"
	var err := ResourceSaver.save(pine, path)
	print("build_tree_defs: %s -> %s" % [path, "OK" if err == OK else "ERR %d" % err])
