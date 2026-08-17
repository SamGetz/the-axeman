extends Node
## Non-destructive visual QA for the production survival composition. Main is
## driven in memory without beginning a Main session, so autosave remains gated.

const OUT := "/private/tmp/axeman_survival_"


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(main)
	for _frame: int in range(8):
		await get_tree().process_frame
	main.get_node("StartupOverlay").hide()
	main.get_node("UI_Overlay/YardHUD").show()
	main.call("_enter_world")
	var run := main.get_node("RunDirector") as RunDirector
	var arena := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame/LooseLogArena") as LooseLogArena
	run.start_attempt(20260813)
	for index: int in range(6):
		var species := SpeciesTable.starting_species()
		var descriptor := LogDescriptor.create(StringName("shot_log_%d" % index),
			species.id, index % maxi(1, species.meshes.size()), 100 + index, 700 + index)
		arena.spawn_loose_log(descriptor, 9100 + index)
	var bodies := arena.call("_live_bodies") as Array[LooseLogBody]
	for index: int in range(bodies.size()):
		var angle := float(index) / maxf(1.0, float(bodies.size())) * TAU
		bodies[index].freeze = true
		bodies[index].global_position = Vector3(cos(angle) * (1.05 + 0.13 * index),
			0.42, sin(angle) * (1.05 + 0.13 * index))
		bodies[index].rotation = Vector3(0.0, angle, PI * 0.5)
		bodies[index].landed = true
	for _frame: int in range(8):
		await get_tree().process_frame
	if not bodies.is_empty():
		bodies[0].global_position = Vector3(run.tuning.boundary_radius + 0.34, 0.42, 0.0)
		bodies[0].linear_velocity = Vector3.ZERO
		bodies[0].angular_velocity = Vector3.ZERO
		bodies[0].landed = true
		arena.advance_hazards(2.4)
	await RenderingServer.frame_post_draw
	_save("active")
	# Show the current one-hit loose-log contract in the same production camera:
	# three roots break into their deterministic-random real descendants at once.
	arena.destroy_power_logs(&"splinter_volley", 3, Vector3.ZERO, INF,
		&"nearest", [])
	for _frame: int in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("power_fragments")
	var hud := main.get_node("UI_Overlay/YardHUD") as YardHUD
	hud.call("_open_panel", &"shop")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("shop_paused")
	hud.call("_close_panel")
	if not bodies.is_empty():
		arena.advance_hazards(run.tuning.boundary_grace_seconds)
	# Result text and containers change size together. Give Control layout and the
	# compatibility renderer a complete frame before reading the viewport.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("death")
	get_tree().quit()


func _save(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := OUT + label + ".png"
	var error := image.save_png(path)
	print("survival_visual_shot: %s (%s, %dx%d)" % [
		path, error_string(error), image.get_width(), image.get_height(),
	])
