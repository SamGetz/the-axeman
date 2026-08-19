extends Node
## Repeatable high-volume gate for the live survivors yard. Timings are printed
## for tuning/release evidence; structural checks make the expensive work-count
## regressions deterministic across machines.

const ROOT_COUNT := 256
const HAZARD_STEPS := 600
const VFX_TRIGGER_COUNT := 100

var _passed := 0
var _failed := 0


func _ready() -> void:
	GameState.reset_to_defaults()
	var game := load(
		"res://scenes/3d_action/chopping_minigame.tscn").instantiate() as Node3D
	add_child(game)
	await get_tree().process_frame
	game.call("clear_run_log")
	var arena := game.get_node("LooseLogArena") as LooseLogArena
	var tuning := load(
		"res://data/survival_run_tuning_placeholder.tres") as SurvivalRunTuning
	arena.bind_run(null, game, tuning)

	var species := SpeciesTable.at(0)
	var hulls_before := MeshUtils._convex_shape_build_count
	var spawn_started := Time.get_ticks_usec()
	var bodies: Array[LooseLogBody] = []
	for index: int in range(ROOT_COUNT):
		var descriptor := LogDescriptor.create(
			StringName("perf_root_%d" % index), species.id, 0, index, index + 1)
		var body := arena.spawn_loose_log(descriptor, index + 1000)
		if body != null:
			bodies.append(body)
	var spawn_ms := float(Time.get_ticks_usec() - spawn_started) / 1000.0
	var hulls_after_spawn := MeshUtils._convex_shape_build_count
	_check(bodies.size() == ROOT_COUNT,
		"the stress fixture creates all %d physical roots" % ROOT_COUNT)
	_check(int(game.get("_run_log_mesh_cache").size()) == 1 \
			and hulls_after_spawn - hulls_before == 1,
		"identical delivery geometry and its QuickHull build are shared once")

	for body: LooseLogBody in bodies:
		body.landed = true
		body.freeze = true
		arena.try_batch_visual(body)
	arena.call("_flush_visual_batches")
	var batched_instances := 0
	for entry: Dictionary in arena.get("_visual_batches").values():
		var instance := entry.get("instance") as MultiMeshInstance3D
		if is_instance_valid(instance) and instance.multimesh != null:
			batched_instances += instance.multimesh.instance_count
	_check(batched_instances == ROOT_COUNT,
		"%d settled intact roots collapse into shared MultiMesh submissions" \
			% ROOT_COUNT)

	arena.set("_paused", false)
	var hazard_started := Time.get_ticks_usec()
	for _step: int in range(HAZARD_STEPS):
		arena.advance_hazards(1.0 / 60.0)
	var hazard_ms := float(Time.get_ticks_usec() - hazard_started) / 1000.0
	_check(hazard_ms / float(HAZARD_STEPS) < 4.0,
		"a %d-root hazard tick stays below the 4ms stress budget" % ROOT_COUNT)

	var cut_body := bodies[0]
	var hulls_before_cuts := MeshUtils._convex_shape_build_count
	var cuts_started := Time.get_ticks_usec()
	var cut_count := 0
	for _index: int in range(5):
		if bool(arena.call("_apply_power_cut", cut_body, &"perf", false, false)):
			cut_count += 1
	var cuts_ms := float(Time.get_ticks_usec() - cuts_started) / 1000.0
	var hulls_after_cuts := MeshUtils._convex_shape_build_count
	_check(cut_count == 5 and hulls_after_cuts == hulls_before_cuts,
		"five loose slices use primitive compound bounds without new QuickHull work")

	var definition := SurvivorsContent.run_powers().by_id(&"double_chop")
	RunPowerBurst.spawn(game, Vector3.ZERO, definition)
	var power_materials := RunPowerPropLibrary._material_cache.size()
	var power_meshes := RunPowerPropLibrary._mesh_cache.size()
	var vfx_started := Time.get_ticks_usec()
	for index: int in range(VFX_TRIGGER_COUNT):
		var offset := Vector3(float(index % 10) * 0.01, 0.0,
			float(index / 10) * 0.01)
		RunPowerBurst.spawn(game, offset, definition)
	var vfx_ms := float(Time.get_ticks_usec() - vfx_started) / 1000.0
	_check(RunPowerPropLibrary._material_cache.size() == power_materials \
			and RunPowerPropLibrary._mesh_cache.size() == power_meshes,
		"repeat trigger props reuse their warmed prop meshes and materials")

	print(("SURVIVAL PERFORMANCE: roots=%d spawn=%.2fms (%.3fms/root) " \
		+ "hazards=%d×%.3fms cuts=%.2fms (%.2fms/cut) vfx=%d %.2fms") \
		% [ROOT_COUNT, spawn_ms, spawn_ms / float(ROOT_COUNT),
			HAZARD_STEPS, hazard_ms / float(HAZARD_STEPS), cuts_ms,
			cuts_ms / 5.0, VFX_TRIGGER_COUNT, vfx_ms])
	print("SURVIVAL PERFORMANCE STRESS: %d passed, %d failed" % [
		_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
