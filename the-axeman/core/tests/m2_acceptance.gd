extends Node
## FILE: res://core/tests/m2_acceptance.gd
## ATTACHES TO: the root Node of res://core/tests/m2_acceptance.tscn.
## Run that scene (F6 / Run Current Scene). Not shipped in builds.
##
## Verifies the M2 contracts:
##   A1  — pipeline settings (1280×720 Action_Viewport, LINEAR container,
##         canvas_items/keep project stretch). The smooth painterly direction
##         deliberately filters resized viewport output and uses a full-screen
##         edge-aware wash without UV snapping, colour quantization, or dither.
##         Jagged geometry edges are handled by a per-viewport `msaa_3d`
##         override on Action_Viewport (4x) instead of the project-wide MSAA
##         setting, since FSR/FSR2 `scaling_3d_mode` isn't supported under the
##         Compatibility renderer — left at default Bilinear.
##   A9  — exact root hierarchy (names, types, canvas layers).
##   A10 — after the startup decision the production game enters its chopping
##         view; an explicit 2D mode still disables viewport rendering + 3D
##         processing and restores both.
## No deliberate contract violations in this suite — any red error is real.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M2 ACCEPTANCE — main scene shell + painterly pipeline ===")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_check(main_scene != null, "res://scenes/main.tscn loads")
	if main_scene == null:
		_finish()
		return
	var main := main_scene.instantiate()
	add_child(main) # runs Main._ready(), which now waits safely at startup

	_test_a9_hierarchy(main)
	_test_a1_pipeline(main)
	_test_a10_mode_switching(main)

	main.queue_free()
	_finish()


func _finish() -> void:
	print("=== M2 RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M2 ACCEPTANCE CRITERIA PASS ===")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _test_a9_hierarchy(main: Node) -> void:
	_check(main.name == "Main" and main.get_class() == "Node",
		"root is Main (plain Node)")

	var ui_canvas := main.get_node_or_null("UI_Canvas")
	_check(ui_canvas is CanvasLayer and ui_canvas.layer == 0,
		"UI_Canvas is CanvasLayer on layer 0")

	var container := main.get_node_or_null("UI_Canvas/SubViewportContainer")
	_check(container is SubViewportContainer,
		"SubViewportContainer under UI_Canvas")

	var viewport := main.get_node_or_null(
		"UI_Canvas/SubViewportContainer/Action_Viewport")
	_check(viewport is SubViewport, "Action_Viewport is SubViewport")

	var world := main.get_node_or_null(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root")
	_check(world is Node3D, "3D_World_Root is Node3D inside Action_Viewport")

	var overlay := main.get_node_or_null("UI_Overlay")
	_check(overlay is CanvasLayer and overlay.layer == 2,
		"UI_Overlay is CanvasLayer on layer 2, sibling of UI_Canvas")


func _test_a1_pipeline(main: Node) -> void:
	var container: SubViewportContainer = main.get_node(
		"UI_Canvas/SubViewportContainer")
	var viewport: SubViewport = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport")
	var grade: ColorRect = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/"
		+ "PainterlyColorGrade/PainterlyWash")
	var distance_grade: MeshInstance3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/"
		+ "Chopping_Minigame/CameraPivot/Camera3D/DistancePixelGrade")

	_check(viewport.size == Vector2i(1280, 720), "Action_Viewport is 1280x720 (A1, Amendment 8)")
	_check(container.stretch, "SubViewportContainer.stretch is true")
	_check(container.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"SubViewportContainer filter is LINEAR for smooth resized output")
	_check(grade.material is ShaderMaterial
		and (grade.material as ShaderMaterial).shader.resource_path
		== "res://assets/shaders/painterly_color_grade.gdshader",
		"the 3D view uses the smooth painterly grade")
	_check(not distance_grade.visible,
		"the retired camera-distance pixel pass is disabled")

	_check(str(ProjectSettings.get_setting("display/window/stretch/mode"))
		== "canvas_items", "project stretch mode is canvas_items")
	_check(str(ProjectSettings.get_setting("display/window/stretch/aspect"))
		== "keep", "project stretch aspect is keep")
	# The base canvas is what ACTUALLY renders. SubViewportContainer.stretch = true
	# resizes Action_Viewport to the container's rect, and the container follows
	# this setting — so an Action_Viewport authored at 1280x720 rendered at
	# whatever this said, and canvas_items stretched the result back up. It said
	# 640x360 until Amendment 16 raised it to match. Assert them EQUAL as well as
	# correct: the moment they diverge, the authored size above is fiction again.
	var base_w := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var base_h := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	_check(base_w == 1280 and base_h == 720,
		"project base viewport is 1280x720 (A1, Amendment 16) — got %dx%d" % [base_w, base_h])
	_check(Vector2i(base_w, base_h) == viewport.size,
		"...and it MATCHES Action_Viewport, so the authored render size is the real one (no hidden upscale)")
	_check(int(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/msaa_3d", 0)) == 0,
		"project-wide MSAA 3D default is off (Action_Viewport overrides its own, below)")
	_check(viewport.msaa_3d == Viewport.MSAA_4X,
		"Action_Viewport.msaa_3d is 4x (A1, Amendment 8 — per-viewport override, smooths geometry edges without blur; Compatibility renderer doesn't support FSR/FSR2 scaling_3d_mode, so that's left at default Bilinear)")
	_check(viewport.anisotropic_filtering_level == 3,
		"Action_Viewport.anisotropic_filtering_level is 3 (A1, Amendment 8 — sharpens ground texture at grazing angles)")
	_check(int(ProjectSettings.get_setting(
		"rendering/anti_aliasing/quality/screen_space_aa", 0)) == 0,
		"screen-space AA is off")


func _test_a10_mode_switching(main: Node) -> void:
	var viewport: SubViewport = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport")
	var world: Node3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root")
	# Persistence behaviour and the visible choice are covered by the focused
	# startup suite. Activate the already-built shell without touching the save so
	# this frozen M2 contract can keep testing only A10 mode switching.
	main._finish_startup(false)

	_check(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"the startup decision enters chopping: viewport rendering is live")
	_check(world.process_mode == Node.PROCESS_MODE_INHERIT,
		"the startup decision enters chopping: 3D_World_Root processing is live")

	EventBus.minigame_exited.emit()
	_check(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"explicit 2D transition: viewport rendering disabled")
	_check(world.process_mode == Node.PROCESS_MODE_DISABLED,
		"explicit 2D transition: 3D_World_Root processing disabled")

	EventBus.minigame_entered.emit(Enums.Biome.PINE_FOREST)
	_check(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"minigame_entered: viewport rendering restored")
	_check(world.process_mode == Node.PROCESS_MODE_INHERIT,
		"minigame_entered: 3D_World_Root processing restored")
