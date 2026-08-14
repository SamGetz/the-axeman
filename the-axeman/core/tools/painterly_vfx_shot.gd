extends Node
## Focused non-headless proof for the shared world-space painterly VFX language.
## It renders proc, level-up, smoke and grain through the production camera and
## grade, then captures XP/cash separately to keep their art-authored reward
## materials visibly exempt. It never starts a session or touches the save.

const OUT := "/private/tmp/axeman_painterly_vfx_"


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for _frame in range(4):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	main.get_node("UI_Overlay/YardHUD").show()
	main.call("_enter_3d_mode")
	for _frame in range(12):
		await get_tree().process_frame

	var world: Node3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/"
		+ "Chopping_Minigame")
	var grade: CanvasLayer = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/PainterlyColorGrade")

	grade.hide()
	ProcBurst.spawn(world, Vector3(0.0, 0.86, 0.0),
		Color(0.82, 0.29, 0.20), &"strength")
	await _wait_ms(130)
	_save("off")

	await _wait_ms(900)
	grade.show()
	ProcBurst.spawn(world, Vector3(0.0, 0.86, 0.0),
		Color(0.82, 0.29, 0.20), &"strength")
	await _wait_ms(130)
	_save("proc_on")

	await _wait_ms(900)
	var level_up := LevelUpBurst.create_prewarmed(world, 0.46)
	level_up.play_at(Vector3(0.0, 0.66, 0.0))
	await _wait_ms(380)
	_save("level_on")
	level_up.hide_render_warmup()

	await _wait_ms(900)
	world.call("_spawn_log_smoke", world.get("_source_mesh"))
	await _wait_ms(120)
	_save("smoke_on")

	await _wait_ms(520)
	world.call("_burst_xp_orbs", 500)
	await _wait_ms(480)
	_save("xp_exempt")
	for orb: XPOrb in world.get("_xp_orb_pool"):
		orb.visible = false
		orb.set_process(false)

	await _wait_ms(240)
	var cash_pool := world.get_node("CoinRewardPool") as CoinRewardPool
	cash_pool.begin_burst(Vector3(0.0, 0.66, 0.0), 1, 0.025, 0.4, 1.15, 0.025)
	cash_pool.queue_payout(500)
	await _wait_ms(280)
	_save("cash_exempt")
	cash_pool.call("_finish_pending")

	await _wait_ms(240)
	_show_grain_mark(world)
	await _wait_ms(120)
	_save("grain_on")
	get_tree().quit()


func _wait_ms(ms: int) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < ms:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(label: String) -> void:
	var path := OUT + label + ".png"
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("painterly_vfx_shot: %s (%s)" % [path, error_string(error)])


func _show_grain_mark(world: Node3D) -> void:
	var pieces: Array = world.get("_on_block")
	if pieces.is_empty():
		return
	var target := pieces[0] as Area3D
	var mesh := target.get_meta("mesh_ref") as Mesh
	if mesh == null:
		return
	var camera := world.get_node("CameraPivot/Camera3D") as Camera3D
	var normal := camera.global_transform.basis.x
	normal.y = 0.0
	normal = normal.normalized()
	var world_anchor := target.global_position
	world_anchor.y += mesh.get_aabb().size.y * 0.5 \
		+ float(GameConfig.current().grain_cue.surface_lift)
	world.call("_build_grain_top_mark", target, world_anchor, normal)
