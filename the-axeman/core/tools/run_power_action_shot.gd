extends Node
## FILE: res://core/tools/run_power_action_shot.gd
## ATTACHES TO: the root Node of res://core/tools/run_power_action_shot.tscn.
##
## DEV TOOL — RUN NON-HEADLESS. Captures every run power triggering inside the
## real production composition: Main, the yard, the stump, live loose roots, the
## production camera and the HUD. Nothing is staged on a bare plane here.
##
## This is the counterpart to run_power_prop_shot: that tool asks "is this prop
## modelled right", this one asks "does the announcement read while the game is
## on screen behind it". Each power is given a real rank first, then fired
## through the production `present_run_power_trigger` seam, so the emblem count,
## the destroyed-log tally and the ground ring are all the values the live
## runtime would have produced.
##
## Output: user://run_power_action_<index>_<power>.png at 1280x720
## (macOS: ~/Library/Application Support/the-axeman/)

## Rank requested for every power before its shot. Clamped per power to its own
## authored cap, so this never invents a rank a power cannot reach.
const _SHOWCASE_RANK := 3
## Powers whose triggers really do destroy loose roots. Only these get a
## destroyed-log tally, so the shots do not imply a payload a power never has.
const _DESTRUCTIVE: Array[StringName] = [&"splinter_volley", &"powder_keg",
	&"kindling_chain", &"maul_drop", &"flying_wedge", &"double_chop",
	&"earthshaker", &"sawblade_halo", &"timber_burst", &"crosscut_sweep",
	&"whirling_axe"]
## Fraction of the burst lifetime to freeze at. The announcement is at its
## readable peak here: prop fully popped, tally in flight, action mid-sweep.
const _PEAK := 0.42

var _main: AxemanMain
var _game: Node3D
var _run: RunDirector


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_main = load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(_main)
	for _frame: int in range(8):
		await get_tree().process_frame
	_main.get_node("StartupOverlay").hide()
	_main.get_node("UI_Overlay/YardHUD").show()
	_main.call("_enter_world")
	_run = _main.get_node("RunDirector") as RunDirector
	_game = _main.get_node("UI_Canvas/SubViewportContainer/Action_Viewport/" \
		+ "3D_World_Root/Chopping_Minigame") as Node3D
	var arena := _game.get_node("LooseLogArena") as LooseLogArena
	_run.start_attempt(20260817)
	_populate_yard(arena)
	for _frame: int in range(8):
		await get_tree().process_frame

	var table := SurvivorsContent.run_powers()
	var index := 0
	for definition: RunPowerDef in table.powers:
		if definition == null:
			continue
		await _shoot_power(definition, index)
		index += 1
	print("=== run_power_action_shot: %d powers captured ===" % index)
	get_tree().quit()


## A yard that looks like a yard: loose roots parked in a ring, frozen so every
## shot shares the same composition and nothing drifts between captures.
func _populate_yard(arena: LooseLogArena) -> void:
	for index: int in range(7):
		var species := SpeciesTable.starting_species()
		var descriptor := LogDescriptor.create(
			StringName("action_shot_log_%d" % index), species.id,
			index % maxi(1, species.meshes.size()), 200 + index, 800 + index)
		arena.spawn_loose_log(descriptor, 9200 + index)
	var bodies := arena.call("_live_bodies") as Array[LooseLogBody]
	for index: int in range(bodies.size()):
		var angle := float(index) / maxf(1.0, float(bodies.size())) * TAU
		var radius := 1.15 + 0.10 * float(index)
		bodies[index].freeze = true
		bodies[index].global_position = Vector3(cos(angle) * radius, 0.42,
			sin(angle) * radius)
		bodies[index].rotation = Vector3(0.0, angle, PI * 0.5)
		bodies[index].landed = true


func _shoot_power(definition: RunPowerDef, index: int) -> void:
	# Give the power a real rank first. Every count and radius the shot shows is
	# then read back out of the authoritative runtime, not passed in by hand.
	var rank := clampi(_SHOWCASE_RANK, 1, maxi(1, definition.rank_cap))
	_run.debug_set_run_power_rank(definition.id, rank)
	if _game.has_method("refresh_run_power_visuals"):
		_game.call("refresh_run_power_visuals", true)
	# Granting the rank fires its own acquisition announcement. Retire that
	# before triggering, so each page shows one power doing one thing.
	await get_tree().process_frame
	_clear_bursts()
	var amount := 3 if definition.id in _DESTRUCTIVE else 1
	# Out in the yard, where loose-root triggers actually resolve. Firing on the
	# stump itself buries the emblem behind the log currently on the block.
	_game.call("present_run_power_trigger", definition.id,
		Vector3(-0.60, 0.40, 0.25), amount)
	for _frame: int in range(3):
		await get_tree().process_frame
	_freeze_bursts()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "user://run_power_action_%02d_%s.png" % [index, definition.id]
	if image != null and image.get_width() == 1280 \
			and image.get_height() == 720 and image.save_png(path) == OK:
		print("wrote %s [rank=%d amount=%d]" % [
			ProjectSettings.globalize_path(path), rank, amount])
	else:
		push_error("run_power_action_shot could not write %s" % path)
	_clear_bursts()
	await get_tree().process_frame


## Hold every live burst at the same phase so the pages are comparable and do
## not depend on how fast this machine rendered the previous one.
func _freeze_bursts() -> void:
	for node: Node in _game.find_children("*", "", true, false):
		var burst := node as RunPowerBurst
		if burst == null:
			continue
		burst.set_process(false)
		burst.call("_update_prop", _PEAK)
		burst.call("_update_tally", _PEAK)
		burst.call("_update_action", _PEAK)


## Collect first, then free. Freeing a burst mid-iteration invalidates the
## entries `find_children` already returned for its own descendants.
func _clear_bursts() -> void:
	var doomed: Array[Node] = []
	for node: Node in _game.find_children("*", "", true, false):
		if node is RunPowerBurst:
			doomed.append(node)
	for burst: Node in doomed:
		if is_instance_valid(burst):
			burst.free()
