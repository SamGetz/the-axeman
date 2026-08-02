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

	print("=== orb_probe: done ===")
	get_tree().quit()


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://orb_probe_%s.png" % tag
	img.save_png(path)
	print("  SHOT %s -> %s" % [tag, ProjectSettings.globalize_path(path)])
