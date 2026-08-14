extends Node
## Deterministic, grant-free pacing projection. These calculations approve only
## that the PLACEHOLDER curve is internally capable of the requested mature-run
## band; a human feel session remains the tuning authority.

const REPRESENTATIVE_MANUAL_SECONDS := [6.0, 8.0, 10.0]
const TARGET_MINUTES_LOW := 25.0
const TARGET_MINUTES_HIGH := 40.0


func _ready() -> void:
	var tuning := load("res://data/survival_run_tuning_placeholder.tres") as SurvivalRunTuning
	var failures := PackedStringArray()
	if tuning == null:
		failures.append("missing survival tuning")
		_finish(failures, {})
		return
	failures.append_array(tuning.validate())
	var batch := int(tuning.earth_batch_sizes[-1])
	var events := int(ceil(float(GameState.TOTAL_EARTH_TREES) / float(batch)))
	var max_splitter_chance := clampf(tuning.splitter_base_chance
		+ float(tuning.splitter_reliability_costs.size())
		* tuning.splitter_chance_per_rank, 0.0, 1.0)
	var splitter_rate := max_splitter_chance / tuning.splitter_cycle_seconds
	var minutes: Array[float] = []
	for cadence: float in REPRESENTATIVE_MANUAL_SECONDS:
		var clear_rate := 1.0 / cadence + splitter_rate
		minutes.append(float(events) / clear_rate / 60.0)
	if minutes.is_empty() or minutes[0] < TARGET_MINUTES_LOW or minutes[-1] > TARGET_MINUTES_HIGH:
		failures.append("mature optimistic splitter band falls outside 25–40 minutes")
	var report := {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"tuning": "PLACEHOLDER",
		"earth_trees": GameState.TOTAL_EARTH_TREES,
		"mature_batch": batch,
		"represented_clear_events": events,
		"manual_seconds_per_log": REPRESENTATIVE_MANUAL_SECONDS,
		"max_splitter_chance": max_splitter_chance,
		"projected_minutes": minutes,
		"target_minutes": [TARGET_MINUTES_LOW, TARGET_MINUTES_HIGH],
		"assumption": "a max-reliability run splitter always has an eligible loose log; management and death retries excluded",
	}
	_finish(failures, report)


func _finish(failures: PackedStringArray, report: Dictionary) -> void:
	report["failures"] = Array(failures)
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
