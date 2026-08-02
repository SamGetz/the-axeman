extends Node
## FILE: res://core/tools/orb_probe.gd
## ATTACHES TO: root Node of res://core/tools/orb_probe.tscn. DEV TOOL, RUN
## NON-HEADLESS. Not shipped.
##
## THE XP ORB'S GLOW, TAKEN APART. It dumps the halo's own gradient texture to disk
## AND parks halo quads at known distances down the camera's view axis, so the two
## halves of a glow bug can never be confused: if the PNG is a soft radial fade but
## the quads on screen are flat cards, the art is fine and the BLEND is wrong.
##
## That is exactly how the "square exp bubble" was pinned (2026-08-02). The texture
## dumped correct — centre alpha 0.53, corner 0.0 — while every quad rendered as a
## hard green square, because an additive surface adds its RGB whatever the alpha
## says, and the gradient faded only its alpha. Run this on any change to the halo
## material or its texture; orb_shot shows the effect, this shows why.
##
## Output: user://orb_probe_halo_tex.png (the texture) and
##         user://orb_probe_halo_ladder.png (the quads at 0.4 / 0.8 / 1.6 m)

const _SCENE := preload("res://scenes/3d_action/chopping_minigame.tscn")


func _ready() -> void:
	var game: Node3D = _SCENE.instantiate()
	game.debug_forced_species = 0
	game.auto_sell = false
	game.orbs_enabled = false
	add_child(game)
	for i in range(20):
		await get_tree().process_frame

	# Force the shared set to build, then photograph the texture ITSELF.
	XPOrb._shared()
	var tex: Texture2D = XPOrb._halo_mat.albedo_texture
	await RenderingServer.frame_post_draw
	var img := tex.get_image()
	if img == null:
		print("  halo texture: get_image() returned NULL")
	else:
		img.save_png("user://orb_probe_halo_tex.png")
		print("  halo texture -> %s  (%dx%d, fmt %d)"
			% [ProjectSettings.globalize_path("user://orb_probe_halo_tex.png"),
				img.get_width(), img.get_height(), img.get_format()])
		for uv: Vector2 in [Vector2(0.5, 0.5), Vector2(0.75, 0.5), Vector2(0.98, 0.5), Vector2(0.02, 0.02)]:
			var px := img.get_pixel(int(uv.x * (img.get_width() - 1)), int(uv.y * (img.get_height() - 1)))
			print("    uv %s -> %s" % [uv, px])

	var cam: Camera3D = game.get_node("CameraPivot/Camera3D")
	# A ladder of halos straight down the view axis, each at a known distance.
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	var i := 0
	for d: float in [0.4, 0.8, 1.6]:
		var mi := MeshInstance3D.new()
		mi.mesh = XPOrb._halo_mesh
		mi.material_override = XPOrb._halo_mat
		add_child(mi)
		mi.global_position = cam.global_position + fwd * d + right * (float(i) - 1.0) * d * 0.35
		i += 1

	for f in range(4):
		await get_tree().process_frame
	await _save("halo_ladder")
	for c in get_children():
		if c is MeshInstance3D:
			c.queue_free()

	await _draw_telemetry(game, cam)

	print("=== orb_probe: done ===")
	get_tree().quit()


## THE APPROACH, IN NUMBERS. A still cannot tell you how many FRAMES an orb spends
## looking like it is coming at you, and that is the whole question when the burst
## is meant to fly INTO the player rather than into the scenery.
##
## Prints, per frame, how many orbs are being drawn in, how close the nearest is,
## and its apparent size on screen. Apparent size must GROW: if it falls, the orb is
## shrinking faster than it closes and will read as going away however fast it moves.
func _draw_telemetry(game: Node3D, cam: Camera3D) -> void:
	game.orbs_enabled = true
	game._burst_xp_orbs(120)
	var frames := 0
	var seen_big := 0
	var prev_ang := -1.0
	var ever_drew := false
	print("  frame  drawing  nearest(m)  apparent(deg)")
	while frames < 140:
		await get_tree().process_frame
		frames += 1
		var drawing := 0
		var nearest := INF
		var ang := 0.0
		for o in game.get_children():
			if not (o is XPOrb) or o._phase != XPOrb.Phase.DRAW:
				continue
			drawing += 1
			var d: float = o.global_position.distance_to(cam.global_position)
			if d < nearest:
				nearest = d
				# Small-angle apparent diameter of the HALO, which is the part the
				# eye actually reads.
				ang = rad_to_deg(2.0 * 0.018 * 3.5 * o.scale.x / maxf(d, 0.01))
		if drawing == 0:
			# The burst spends its first second bursting, bouncing and resting; only
			# stop once the draw has actually happened and finished.
			if ever_drew:
				break
			continue
		ever_drew = true
		if ang >= 3.0:
			seen_big += 1
		var trend := "" if prev_ang < 0.0 else ("  up" if ang > prev_ang else "  DOWN")
		prev_ang = ang
		print("   %4d  %7d  %10.2f  %13.2f%s" % [frames, drawing, nearest, ang, trend])
	print("  frames with the nearest orb at 3 deg or more: %d" % seen_big)


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://orb_probe_%s.png" % tag
	img.save_png(path)
	print("  SHOT %s -> %s" % [tag, ProjectSettings.globalize_path(path)])
