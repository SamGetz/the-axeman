extends Node
## DEV DIAGNOSTIC: verify (1) cuts are forced onto the long horizontal axis and
## (2) fly-off ignores height. Run:
## godot --path . --rendering-driver opengl3 --position 3000,3000 --quit-after 300 res://core/tools/chop_diag.tscn

func _ready() -> void:
	print("=== CHOP DIAG ===")
	var poc: Node = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(poc)
	await get_tree().process_frame
	await get_tree().process_frame

	print("width_depth_ratio=%.2f aspect_limit=%.2f min_vol=%.4f long_axis_bias=%.2f" %
		[poc.width_depth_ratio, poc.aspect_limit, poc.min_vol, poc.long_axis_bias])

	# One center cut along X -> two 0.21(X) x 0.40(Y) x 0.48(Z) halves. Z is now the
	# long axis, so a CLICK (camera still facing X) must TURN, not cut.
	poc.debug_slice_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_report("after center cut", poc)

	var half: Node3D = poc._on_block[0]
	var yaw_before: int = poc._yaw_steps
	var screen: Vector2 = poc._camera.unproject_position(half.global_position)
	poc._on_click(screen)
	await get_tree().process_frame
	var turned: bool = poc._yaw_steps != yaw_before
	var cut_started: bool = not poc._pending.is_empty()
	print("FIX1 clicking the short (X) axis of a slab-in-waiting: turned=%s cut_started=%s -> %s" %
		[turned, cut_started, "PASS (forced to long axis)" if turned and not cut_started else "FAIL"])

	# FIX2: a tall-but-square-footprint piece must NOT be firewood. Cut the half
	# along its long Z axis a couple times (debug) and confirm pieces stay while
	# their x:z footprint is square, even though they're tall.
	print("\n--- reducing along Z (debug), checking fly-off uses footprint only ---")
	for i in range(3):
		if poc.cuttable_count() == 0:
			break
		poc.debug_slice_world(Plane(Vector3.FORWARD, 0.10 - i * 0.08))
		await get_tree().process_frame
	_report("after Z cuts", poc)

	print("=== CHOP DIAG DONE ===")
	get_tree().quit()


func _report(tag: String, poc: Node) -> void:
	print("[%s] on_block=%d firewood=%d" % [tag, poc._on_block.size(), poc._firewood.size()])
	for p in poc._on_block:
		_line("  STAY  ", p)
	for f in poc._firewood:
		_line("  FLYOFF", f)


func _line(kind: String, node: Node) -> void:
	var mi: MeshInstance3D = node.get_node_or_null("Mesh")
	if mi == null or mi.mesh == null:
		return
	var s: Vector3 = mi.mesh.get_aabb().size
	var horiz_mx: float = maxf(s.x, s.z)
	var horiz_mn: float = maxf(minf(s.x, s.z), 0.0001)
	print("%s XxYxZ = %.3f x %.3f x %.3f | vol=%.4f | footprint-aspect(x:z)=%.2f | 3D-aspect=%.2f" % [
		kind, s.x, s.y, s.z, s.x * s.y * s.z, horiz_mx / horiz_mn,
		maxf(s.x, maxf(s.y, s.z)) / maxf(minf(s.x, minf(s.y, s.z)), 0.0001)])
