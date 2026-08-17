extends Node
## Compact production composition gate for Home, run HUD, pause, arrival, and
## settled failure. It uses an isolated save path and never touches player data.

const _SAVE_PATH := "user://survival_main_smoke.cfg"
const _WATCHDOG_SECONDS := 15.0

var _passed := 0
var _failed := 0
var _completed := false


func _ready() -> void:
	get_tree().create_timer(_WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	SaveSystem.set_save_path_for_tests(_SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var fresh_startup := load(
		"res://scenes/2d_management/startup_menu.tscn").instantiate() as StartupMenu
	add_child(fresh_startup)
	await get_tree().process_frame
	var fresh_title := fresh_startup.find_child("GameTitle", true, false) as Label
	var fresh_start := fresh_startup.find_child(
		"YardTabButton", true, false) as Button
	_check(ProjectSettings.get_setting("application/config/name") \
			== "Campfire Survivors" \
		and fresh_title.text == "CAMPFIRE\nSURVIVORS" \
		and fresh_start.visible and fresh_start.text == "START",
		"fresh startup presents the CAMPFIRE SURVIVORS brand and dominant START action")
	_check(ProjectSettings.get_setting("application/config/use_custom_user_dir", false) \
		and ProjectSettings.get_setting("application/config/custom_user_dir_name", "") \
			== "the-axeman",
		"the display-name pivot preserves the existing profile data directory")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture_rendered("/private/tmp/axeman_startup_menu.png")
	var new_profile_routes := [0]
	fresh_startup.new_profile_requested.connect(
		func() -> void: new_profile_routes[0] += 1)
	fresh_start.pressed.emit()
	await get_tree().process_frame
	fresh_startup.configure(true, false)
	await get_tree().process_frame
	var routed_level_start := fresh_startup.find_child(
		"StartRunButton", true, false) as Button
	_check(int(new_profile_routes[0]) == 1 \
		and routed_level_start != null and routed_level_start.visible,
		"fresh-profile START routes into Level Select after profile creation")
	fresh_startup.queue_free()
	await get_tree().process_frame
	SaveSystem.clear_attempt_and_save()
	var main := load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(main)
	for _frame: int in range(4):
		await get_tree().process_frame
	var world := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root") as Node3D
	var hud := main.get_node("UI_Overlay/YardHUD") as YardHUD
	var startup := main.get_node("StartupOverlay/StartupMenu") as StartupMenu
	_check(not main.has_started_session() and not hud.visible and startup.visible
		and world.process_mode == Node.PROCESS_MODE_DISABLED,
		"production startup stays dormant until an explicit profile choice")
	_check(startup.find_child("ResumeAttemptButton", true, false) != null
		and startup.find_child("AbandonAttemptButton", true, false) != null,
		"startup presents explicit resume and abandon routes for suspended attempts")
	main.get_node("StartupOverlay").hide()
	hud.show()
	main.call("_enter_world")
	var run := main.get_node("RunDirector") as RunDirector
	var game := main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	var arena := game.get_node("LooseLogArena") as LooseLogArena
	run.start_attempt(303)
	for _frame: int in range(3):
		await get_tree().process_frame
	_check(run.is_gameplay_active() and int(game.call("piece_count")) > 0
		and arena.get_node_or_null("RedBoundary") != null,
		"production start stages a choppable log inside the physical boundary")
	var xp_progress := hud.get_node("XPBar/Progress") as ProgressBar
	var stage_counter := hud.get_node("StageAndRunTimer/StageCountdown") as Label
	_check(xp_progress != null and hud.get_node_or_null("CashCounter/CashIcon") != null
		and stage_counter.text.contains("15:00")
		and hud.get_node_or_null("CashCounter/LockedHomeBank") != null
		and hud.get_node_or_null("StageAndRunTimer/RunTimer") != null
		and hud.get_node("RunPowerSlots").get_child_count() == 6,
		"XP, session cash, locked bank, stage timer, and six run slots are live")

	var presenter := game.get_node("YardEquipment") as YardEquipmentPresenter
	var clear_radius := run.tuning.boundary_radius + run.tuning.yard_prop_clearance
	var arena_is_clear := true
	for landmark: Node in presenter.get_children():
		if landmark is Node3D:
			var at := (landmark as Node3D).position
			arena_is_clear = arena_is_clear \
				and Vector2(at.x, at.z).length() >= clear_radius - 0.001
	_check(arena_is_clear,
		"all physical yard landmarks sit completely beyond the gameplay circle")

	var start := Vector3(run.tuning.boundary_radius + 0.8, 0.4, -0.2)
	var target := Vector3(0.0, 0.75, 0.0)
	var offscreen_y: float = game.call(
		"_vertical_handoff_offscreen_y", start, target)
	var base_handoff_duration := run.tuning.block_hop_seconds
	var handoff_timing: Vector2 = game.call(
		"_vertical_handoff_timing", base_handoff_duration)
	var lift_fraction := handoff_timing.y
	var old_lift_duration := base_handoff_duration \
		* run.tuning.block_handoff_lift_fraction
	var old_drop_duration := base_handoff_duration \
		* (1.0 - run.tuning.block_handoff_lift_fraction)
	var new_lift_duration := handoff_timing.x * lift_fraction
	var new_drop_duration := handoff_timing.x * (1.0 - lift_fraction)
	var lift_mid: Vector3 = game.call("_vertical_handoff_position",
		lift_fraction * 0.5, start, target, offscreen_y, lift_fraction)
	var source_out: Vector3 = game.call("_vertical_handoff_position",
		lift_fraction - 0.0001, start, target, offscreen_y, lift_fraction)
	var block_out: Vector3 = game.call("_vertical_handoff_position",
		lift_fraction, start, target, offscreen_y, lift_fraction)
	var drop_mid: Vector3 = game.call("_vertical_handoff_position",
		lift_fraction + (1.0 - lift_fraction) * 0.5,
		start, target, offscreen_y, lift_fraction)
	var landed: Vector3 = game.call("_vertical_handoff_position",
		1.0, start, target, offscreen_y, lift_fraction)
	_check(Vector2(lift_mid.x, lift_mid.z).is_equal_approx(
			Vector2(start.x, start.z)) \
		and Vector2(source_out.x, source_out.z).is_equal_approx(
			Vector2(start.x, start.z)) \
		and bool(game.call("_handoff_point_is_above_frame", source_out)) \
		and bool(game.call("_handoff_point_is_above_frame", block_out)) \
		and Vector2(block_out.x, block_out.z).is_equal_approx(
			Vector2(target.x, target.z)) \
		and Vector2(drop_mid.x, drop_mid.z).is_equal_approx(
			Vector2(target.x, target.z)) \
		and landed.is_equal_approx(target) \
		and is_equal_approx(
			run.tuning.block_handoff_lift_time_multiplier, 1.75) \
		and new_lift_duration > old_lift_duration \
		and is_equal_approx(new_drop_duration, old_drop_duration),
		"claimed logs rise more slowly straight out of frame, reposition unseen above the block, then retain the original vertical drop timing")
	if DisplayServer.get_name() != "headless":
		var visual_roots: Array = game.get("_on_block")
		if not visual_roots.is_empty():
			var visual_root := visual_roots[0] as Node3D
			var saved_transform := visual_root.global_transform
			var visual_start := Vector3(1.2, 0.4, -0.4)
			var visual_offscreen_y: float = game.call(
				"_vertical_handoff_offscreen_y", visual_start, target)
			for checkpoint: Dictionary in [
				{"name": "lift", "progress": lift_fraction * 0.15},
				{"name": "hidden", "progress": lift_fraction},
				{"name": "drop", "progress": lift_fraction \
					+ (1.0 - lift_fraction) * 0.93},
			]:
				game.call("_move_run_log_vertical_handoff",
					float(checkpoint.progress), visual_root, visual_start, target,
					visual_offscreen_y, lift_fraction, Quaternion.IDENTITY)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				_capture_rendered("/private/tmp/axeman_handoff_%s.png" \
					% String(checkpoint.name))
			visual_root.global_transform = saved_transform

	var probe_species := SpeciesTable.starting_species()
	var probe := LogDescriptor.create(&"handoff_probe", probe_species.id, 0,
		987, 654)
	probe.transfer_from = start
	probe.transfer_rotation = Quaternion(Vector3.RIGHT, 0.55)
	var ready_events := [0]
	game.run_log_ready.connect(func() -> void: ready_events[0] += 1)
	var handoff_started_ms := Time.get_ticks_msec()
	game.call("stage_run_log", probe, true)
	var staged_roots: Array = game.get("_on_block")
	var staged_root := staged_roots[0] as Node3D \
		if not staged_roots.is_empty() else null
	var staged_handoff := game.get("_run_handoff_visual") as Node3D
	var began_at_source := staged_handoff != null \
		and staged_handoff.global_position.is_equal_approx(start) \
		and staged_root != null and not staged_root.visible
	var actual_offscreen_y := float(game.call("_vertical_handoff_offscreen_y",
		start, staged_root.global_position, staged_handoff)) \
		if staged_handoff != null and staged_root != null else -INF
	var full_source_clear := staged_handoff != null \
		and bool(game.call("_handoff_visual_is_above_frame", staged_handoff,
			Vector3(start.x, actual_offscreen_y, start.z),
			Quaternion.IDENTITY))
	var full_target_clear := staged_handoff != null and staged_root != null \
		and bool(game.call("_handoff_visual_is_above_frame", staged_handoff,
			Vector3(staged_root.global_position.x, actual_offscreen_y,
				staged_root.global_position.z), Quaternion.IDENTITY))
	await get_tree().create_timer(
		run.tuning.block_hop_seconds + 0.15, true, false, true).timeout
	for _frame: int in range(4):
		if int(ready_events[0]) > 0:
			break
		await get_tree().process_frame
	var scheduled_position := staged_root.global_position \
		if is_instance_valid(staged_root) else Vector3.INF
	for _frame: int in range(120):
		if int(ready_events[0]) > 0:
			break
		await get_tree().process_frame
	var handoff_elapsed_ms := Time.get_ticks_msec() - handoff_started_ms
	_check(began_at_source and full_source_clear and full_target_clear \
		and staged_root != null \
		and Vector2(staged_root.global_position.x,
			staged_root.global_position.z).is_equal_approx(Vector2.ZERO) \
		and int(ready_events[0]) == 1,
		"the production handoff tween preserves the claimed pose and emits ready only after its vertical block landing [began=%s valid=%s scheduled=%s pos=%s ready=%d elapsed_ms=%d time_scale=%.3f]" % [
			began_at_source, is_instance_valid(staged_root),
			scheduled_position,
			staged_root.global_position if is_instance_valid(staged_root) \
				else Vector3.INF, int(ready_events[0]), handoff_elapsed_ms,
			Engine.time_scale])

	# Replacing a log mid-lift must synchronously hide and generation-cancel the
	# stale presentation. Its delayed callback may never land or mutate the new
	# root after wall time advances beyond both handoffs.
	var stale_probe := LogDescriptor.create(&"stale_handoff_probe",
		probe_species.id, 0, 988, 655)
	stale_probe.transfer_from = Vector3(-1.1, 0.4, 0.2)
	stale_probe.transfer_rotation = Quaternion(Vector3.FORWARD, 0.4)
	var replacement_probe := LogDescriptor.create(&"replacement_handoff_probe",
		probe_species.id, 0, 989, 656)
	replacement_probe.transfer_from = Vector3(1.0, 0.4, -0.25)
	replacement_probe.transfer_rotation = Quaternion(Vector3.RIGHT, -0.35)
	var replacement_ready := [0]
	game.run_log_ready.connect(func() -> void: replacement_ready[0] += 1)
	game.call("stage_run_log", stale_probe, true)
	var stale_visual := game.get("_run_handoff_visual") as Node3D
	var stale_generation := int(game.get("_run_handoff_generation"))
	game.call("stage_run_log", replacement_probe, true)
	var replacement_generation := int(game.get("_run_handoff_generation"))
	var stale_hidden_immediately := stale_visual != null \
		and (not is_instance_valid(stale_visual) or not stale_visual.visible)
	for _frame: int in range(120):
		if int(replacement_ready[0]) > 0:
			break
		await get_tree().process_frame
	await get_tree().create_timer(0.10, true, false, true).timeout
	var replacement_descriptor := game.get("_current_descriptor") \
		as LogDescriptor
	_check(stale_hidden_immediately \
		and replacement_generation > stale_generation \
		and int(replacement_ready[0]) == 1 \
		and replacement_descriptor != null \
		and replacement_descriptor.id == replacement_probe.id \
		and int(game.call("piece_count")) == 1,
		"replacing a mid-lift delivery hides it immediately, cancels its stale callback, and lands only the replacement")

	# Ordinary autosave must only observe an in-flight presentation. It records the
	# already-hidden authoritative landing state without killing the live tween or
	# emitting its ready callback early.
	var save_probe := LogDescriptor.create(&"saved_handoff_probe",
		probe_species.id, 0, 990, 657)
	save_probe.transfer_from = Vector3(0.9, 0.4, 0.3)
	save_probe.transfer_rotation = Quaternion(Vector3.FORWARD, -0.5)
	game.call("stage_run_log", save_probe, true)
	var save_visual := game.get("_run_handoff_visual") as Node3D
	var save_position := save_visual.global_position \
		if save_visual != null else Vector3.INF
	var save_generation := int(game.get("_run_handoff_generation"))
	var handoff_save := game.call("to_run_save_dict") as Dictionary
	var saved_descriptor: Variant = handoff_save.get("descriptor", {})
	_check(not bool(handoff_save.get("transitioning", true)) \
		and bool(handoff_save.get("handoff_active", false)) \
		and bool(game.get("_run_handoff_active")) \
		and int(game.get("_run_handoff_generation")) == save_generation \
		and save_visual != null and is_instance_valid(save_visual) \
		and save_visual.visible \
		and save_visual.global_position.is_equal_approx(save_position) \
		and saved_descriptor is Dictionary \
		and StringName((saved_descriptor as Dictionary).get("id", "")) \
			== save_probe.id \
		and int(game.call("piece_count")) == 1,
		"an ordinary mid-delivery snapshot is observational and leaves its live handoff untouched")

	# A process restart cannot resume a Tween, so restore consumes the saved
	# handoff marker as one canonical landing and emits ready exactly once.
	var restored_handoff_ready := [0]
	game.run_log_ready.connect(
		func() -> void: restored_handoff_ready[0] += 1, CONNECT_ONE_SHOT)
	game.call("restore_run_save_dict", handoff_save)
	for _frame: int in range(4):
		if int(restored_handoff_ready[0]) > 0:
			break
		await get_tree().process_frame
	var restored_save_descriptor := game.get("_current_descriptor") \
		as LogDescriptor
	_check(not bool(game.get("_run_handoff_active")) \
		and (save_visual == null or not is_instance_valid(save_visual) \
			or not save_visual.visible) \
		and restored_save_descriptor != null \
		and restored_save_descriptor.id == save_probe.id \
		and int(game.call("piece_count")) == 1 \
		and int(restored_handoff_ready[0]) == 1,
		"restoring an observed flight canonicalizes one landed root and releases its boundary pause exactly once")

	# Exercise the production flood, not just the isolated delivery seam. At the
	# 0.2-second floor the final minute must visibly instantiate the full wave and
	# advertise its batch size on the live HUD.
	var original_xp := run.get_xp()
	var original_elapsed := float(run.get("_elapsed_seconds"))
	arena.clear_all()
	run.set("_xp", 0)
	run.set("_elapsed_seconds", run.stage_duration_seconds() - 60.0)
	var flood_size := run.delivery_batch_size()
	var flood_interval := run.delivery_interval()
	var flood_spawned := int(run.call("_spawn_delivery_batch"))
	for _frame: int in range(36):
		await get_tree().process_frame
	hud.call("_on_delivery_changed", 0.2, 0)
	var delivery_label := hud.get("_delivery_label") as Label
	var live_flood_count := arena.loose_log_count()
	_check(flood_size == 10 and is_equal_approx(flood_interval, 0.2) \
		and flood_spawned == 10 \
		and live_flood_count >= 10 and live_flood_count % 10 == 0 \
		and delivery_label != null \
		and delivery_label.text.contains("0.2s ×10"),
		"the production final-minute flood forces ten physical roots every 0.2 seconds at Level 1 and labels the live wave [loose=%d]" \
		% live_flood_count)
	# Force one otherwise-impossible camera crossing while frozen. The physical
	# capsule is the first line of defence; this proves the invisible camera tunnel
	# removes only the occluder and never the active workpiece itself.
	var flood_bodies := arena.call("_live_bodies") as Array[LooseLogBody]
	var active_pieces: Array = game.get("_on_block")
	var visibility_probe := flood_bodies[0] if not flood_bodies.is_empty() \
		else null
	if visibility_probe != null and not active_pieces.is_empty():
		var camera := game.get_node("CameraPivot/Camera3D") as Camera3D
		var active_piece := active_pieces[0] as Node3D
		visibility_probe.freeze = true
		visibility_probe.linear_velocity = Vector3.ZERO
		visibility_probe.global_position = camera.global_position.lerp(
			active_piece.global_position, 0.48)
	var visibility_state := game.call(
		"debug_chopping_visibility_state") as Dictionary
	var dome_state := visibility_state.get("dome", {}) as Dictionary
	var probe_is_invisible := true
	if visibility_probe != null:
		for child: Node in visibility_probe.get_children():
			if child is GeometryInstance3D:
				probe_is_invisible = probe_is_invisible and is_equal_approx(
					(child as GeometryInstance3D).transparency,
					run.tuning.chopping_visibility_tunnel_transparency)
	_check(bool(dome_state.get("present", false)) \
		and is_equal_approx(float(dome_state.get("radius", 0.0)),
			run.tuning.chopping_visibility_dome_radius) \
		and is_equal_approx(float(dome_state.get("height", 0.0)),
			run.tuning.chopping_visibility_dome_height) \
		and visibility_probe != null \
		and (visibility_probe.collision_mask \
			& LooseLogArena.CHOPPING_VISIBILITY_DOME_LAYER) != 0 \
		and int(visibility_state.get("occluder_count", 0)) >= 1 \
		and int(visibility_state.get(
			"tunnel_hidden_geometry_count", 0)) >= 1 \
		and is_zero_approx(float(visibility_state.get(
			"active_max_transparency", -1.0))) \
		and not bool(visibility_state.get("active_self_hidden", true)) \
		and probe_is_invisible,
		"the full-height chopping dome blocks loose roots, while a forced camera crossing opens an invisible tunnel through only the occluder and keeps the active log fully opaque [state=%s]" \
		% [visibility_state])
	if DisplayServer.get_name() != "headless":
		run.pause_attempt()
		hud.call("_on_delivery_changed", 0.2, 0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_capture_rendered("/private/tmp/axeman_final_minute_flood.png")
		run.resume_attempt()
	var dome_collision_holds := false
	var dome_final_radius := 0.0
	if visibility_probe != null:
		for flood_body: LooseLogBody in flood_bodies:
			flood_body.freeze = true
		visibility_probe.global_position = Vector3(
			float(dome_state.get("radius", 0.0)) + 0.65, 1.0, 0.0)
		visibility_probe.linear_velocity = Vector3(-5.0, 0.0, 0.0)
		visibility_probe.angular_velocity = Vector3.ZERO
		visibility_probe.sleeping = false
		visibility_probe.freeze = false
		for _physics_frame: int in range(36):
			await get_tree().physics_frame
		dome_final_radius = Vector2(visibility_probe.global_position.x,
			visibility_probe.global_position.z).length()
		dome_collision_holds = dome_final_radius \
			>= float(dome_state.get("radius", 0.0)) - 0.01
	_check(dome_collision_holds,
		"a fast loose root cannot cross the chopping dome's protected radius [final_radius=%.3f dome_radius=%.3f]" % [
			dome_final_radius, float(dome_state.get("radius", 0.0))])
	var tunnel_restored := false
	if visibility_probe != null:
		var restore_camera := game.get_node("CameraPivot/Camera3D") as Camera3D
		visibility_probe.freeze = true
		visibility_probe.global_position = restore_camera.global_position \
			+ restore_camera.global_transform.basis.z * 2.0
		var restored_visibility := game.call(
			"debug_chopping_visibility_state") as Dictionary
		var restored_probe_transparency := 0.0
		for child: Node in visibility_probe.get_children():
			if child is GeometryInstance3D:
				restored_probe_transparency = maxf(
					restored_probe_transparency,
					(child as GeometryInstance3D).transparency)
		tunnel_restored = is_zero_approx(restored_probe_transparency) \
			and is_zero_approx(float(restored_visibility.get(
				"active_max_transparency", -1.0))) \
			and not bool(restored_visibility.get("active_self_hidden", true))
	_check(tunnel_restored,
		"leaving the camera tunnel restores the old occluder while the active log remains opaque")
	arena.clear_all()
	run.set("_xp", original_xp)
	run.set("_elapsed_seconds", original_elapsed)
	# The flood intentionally leaves the production delivery countdown at an
	# arbitrary sub-0.2-second phase. Reset it so this assertion exercises one
	# ordinary timer boundary instead of sometimes crossing two.
	run.set("_delivery_seconds_left", run.delivery_interval())

	run._process(run.delivery_interval() + 0.01)
	_check(arena.loose_log_count() == 1,
		"production timer instantiates a physical waiting log")
	hud.call("_open_panel", &"pause")
	_check(run.is_paused() and game.process_mode == Node.PROCESS_MODE_DISABLED,
		"production pause panel stops chopping and hazards")
	hud.call("_close_panel")
	_check(run.is_gameplay_active(), "closing production pause resumes the same attempt")

	var bodies := arena.call("_live_bodies") as Array[LooseLogBody]
	if not bodies.is_empty():
		bodies[0].global_position = Vector3(run.tuning.boundary_radius + 0.25, 0.4, 0.0)
		arena.advance_hazards(run.tuning.boundary_grace_seconds)
	_check(run.phase == RunDirector.Phase.FAILED
		and hud.get_node("ResultOverlay").visible
		and _visible_button_with_text(hud.get_node("ResultOverlay"), "GO HOME") != null
		and _visible_button_with_text(hud.get_node("ResultOverlay"), "START ANOTHER RUN") == null,
		"production boundary failure banks once and routes the result through Home")

	_completed = true
	_check(_completed, "the production Main smoke reached its completion sentinel")
	print("SURVIVAL MAIN SMOKE: %d passed, %d failed" % [_passed, _failed])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	SaveSystem.reset_save_path_after_tests()
	get_tree().quit(0 if _failed == 0 else 1)


func _visible_button_with_text(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.visible and button.text == text:
			return button
	return null


func _capture_rendered(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("survival_main_smoke: %s (%s)" % [path, error_string(error)])


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: production Main smoke timed out")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	SaveSystem.reset_save_path_after_tests()
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
