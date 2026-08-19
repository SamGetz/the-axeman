extends Node
## FILE: res://core/tools/run_power_prop_shot.gd
## ATTACHES TO: the root Node of res://core/tools/run_power_prop_shot.tscn.
##
## DEV TOOL — RUN NON-HEADLESS. Lays every authored run-power prop out on a grid
## and writes one PNG per page, plus close-up pages for the counts and areas that
## are supposed to change the geometry.
##
## This exists because the props replaced the old particle announcement: a prop
## can register the right mesh count, pass every numeric check and still be an
## unreadable tangle, an inside-out silhouette or a ring standing on its edge.
## Only a render answers that. Run it on any prop or shader change.
##
## Output: user://run_power_props_<page>.png
## (macOS: ~/Library/Application Support/Godot/app_userdata/<project>/)

const _COLUMNS := 5
const _SPACING := 0.62
## Counts and spans exercised by the dedicated pages. These are presentation
## probes only; the authored ladders still live in the curve resource.
const _COUNT_PROBES: Array[int] = [1, 2, 3, 5, 8]
const _SPAN_PROBES: Array[float] = [0.6, 1.2, 2.0, 3.0]

var _grid_centre_y := 0.0


func _ready() -> void:
	var table := SurvivorsContent.run_powers()
	var ids: Array[StringName] = []
	for definition: RunPowerDef in table.powers:
		if definition != null:
			ids.append(definition.id)
	print("=== run_power_prop_shot: %d powers ===" % ids.size())
	await _shoot_catalogue(ids)
	await _shoot_count_ladder()
	await _shoot_span_ladder()
	await _shoot_live_bursts()
	print("=== run_power_prop_shot: done ===")
	get_tree().quit()


func _shoot_catalogue(ids: Array[StringName]) -> void:
	var page := 0
	var per_page := _COLUMNS * 3
	while page * per_page < ids.size():
		var slice := ids.slice(page * per_page,
			mini((page + 1) * per_page, ids.size()))
		var stage := _stage()
		for index: int in range(slice.size()):
			var holder := _slot(stage, index, slice.size())
			RunPowerPropLibrary.build_emblem(holder, slice[index],
				RunPowerBurst.default_power_color(), 1.2, 3)
			_caption(holder, String(slice[index]))
		await _capture(stage, "catalogue_%d" % page)
		page += 1


func _shoot_count_ladder() -> void:
	for power_id: StringName in [&"whirling_axe", &"momentum", &"area_size",
			&"splinter_volley", &"kindling_chain", &"double_chop", &"follow_up"]:
		var stage := _stage()
		for index: int in range(_COUNT_PROBES.size()):
			var holder := _slot(stage, index, _COUNT_PROBES.size())
			RunPowerPropLibrary.build_emblem(holder, power_id,
				RunPowerBurst.default_power_color(), 1.2,
				_COUNT_PROBES[index])
			_caption(holder, "%s ×%d" % [power_id, _COUNT_PROBES[index]])
		await _capture(stage, "count_%s" % power_id)


func _shoot_span_ladder() -> void:
	for power_id: StringName in [&"sawblade_halo", &"earthshaker",
			&"timber_burst", &"stump_pulse", &"whirling_axe", &"powder_keg"]:
		var stage := _stage()
		for index: int in range(_SPAN_PROBES.size()):
			var holder := _slot(stage, index, _SPAN_PROBES.size())
			RunPowerPropLibrary.build_emblem(holder, power_id,
				RunPowerBurst.default_power_color(), _SPAN_PROBES[index], 3)
			_caption(holder, "%s r=%.1f" % [power_id, _SPAN_PROBES[index]])
		await _capture(stage, "span_%s" % power_id)


## Whole live bursts at the chopping camera's distance and pitch. The grid pages
## answer "is this prop modelled right"; only this one answers "can a player read
## it over the yard", which is where the first pass was wrong — the emblems were
## authored at a size that vanished at play distance.
func _shoot_live_bursts() -> void:
	var probes: Array[Dictionary] = [
		{"id": &"powder_keg", "amount": 5, "span": 1.75, "action": true},
		{"id": &"timber_burst", "amount": 3, "span": 1.2, "action": true},
		{"id": &"crosscut_sweep", "amount": 2, "span": 1.6, "action": true},
		{"id": &"splinter_volley", "amount": 4, "span": 0.0, "action": false},
		{"id": &"whirling_axe", "amount": 1, "span": 0.0, "action": false},
	]
	var table := SurvivorsContent.run_powers()
	for probe: Dictionary in probes:
		var stage := Node3D.new()
		add_child(stage)
		var light := DirectionalLight3D.new()
		light.rotation = Vector3(-0.95, -0.7, 0.0)
		stage.add_child(light)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(12.0, 12.0)
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_color = Color(0.24, 0.27, 0.19, 1.0)
		plane.material = floor_material
		floor_mesh.mesh = plane
		stage.add_child(floor_mesh)
		# The chopping camera looks down on the stump from a few metres out.
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 1.75, 3.1)
		camera.rotation.x = -0.38
		camera.current = true
		stage.add_child(camera)
		var definition := table.by_id(probe["id"] as StringName)
		var burst := RunPowerBurst.spawn(stage, Vector3(0.0, 0.35, 0.0),
			definition, "x%d" % int(probe["amount"]), null,
			bool(probe["action"]), float(probe["span"]), 0,
			float(probe["span"]), int(probe["amount"]), 4)
		# Hold the announcement at its readable peak instead of racing the
		# real-time retire curve, so the page is the same every run.
		for _frame: int in range(3):
			await get_tree().process_frame
		if is_instance_valid(burst):
			burst.set_process(false)
			burst.call("_update_prop", 0.42)
			burst.call("_update_tally", 0.42)
			burst.call("_update_action", 0.42)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "user://run_power_props_live_%s.png" % probe["id"]
		if image != null and image.save_png(path) == OK:
			print("wrote %s" % ProjectSettings.globalize_path(path))
		stage.queue_free()
		await get_tree().process_frame


func _stage() -> Node3D:
	var stage := Node3D.new()
	add_child(stage)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, -0.6, 0.0)
	stage.add_child(light)
	return stage


func _slot(stage: Node3D, index: int, total: int) -> Node3D:
	var columns := mini(_COLUMNS, maxi(1, total))
	var rows := int(ceil(float(maxi(1, total)) / float(columns)))
	_grid_centre_y = -float(rows - 1) * 0.5 * _SPACING
	var holder := Node3D.new()
	holder.position = Vector3(
		(float(index % columns) - float(columns - 1) * 0.5) * _SPACING,
		-(float(index / columns)) * _SPACING, 0.0)
	stage.add_child(holder)
	return holder


func _caption(holder: Node3D, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.outline_size = 8
	label.pixel_size = 0.0016
	label.position.y = -0.24
	holder.add_child(label)


func _capture(stage: Node3D, page: String) -> void:
	# Look down on the grid at roughly the chopping camera's pitch. Ground-plane
	# rings are a large part of the area props and a level camera renders them
	# edge-on, which is not how they are ever seen in play.
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, _grid_centre_y + 1.05, 2.05)
	camera.rotation.x = -0.44
	camera.current = true
	stage.add_child(camera)
	for _frame: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://run_power_props_%s.png" % page
	if image != null and image.save_png(path) == OK:
		print("wrote %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("run_power_prop_shot could not write %s" % path)
	stage.queue_free()
	await get_tree().process_frame
