extends Node
## FILE: res://core/tools/split_odds.gd
## ATTACHES TO: root Node of res://core/tools/split_odds.tscn. DEV TOOL, not shipped.
##
## Answers the only question that matters about the split mechanic: HOW OFTEN DOES
## A PLAYER ACTUALLY SEE A FAILURE? The authored `split_chance` is the odds on the
## FIRST swing of a whole log, but almost every swing after that lands on a smaller
## piece, where `size_relief` has already made the wood easier — so the felt rate
## and the authored rate are different numbers, and only this one can be argued
## with.
##
## Chops whole logs down with REAL rolls (debug_split_roll = -1) and reports, per
## species: the first-swing odds, the share of all swings that failed, and how many
## logs went down without a single failed swing.
##
## Headless is fine — no rendering, no pile animation, just the roll.

const _LOGS_PER_SPECIES := 40
## Ladder indices to measure, or an empty array for the whole table. There are 25
## woods since 2026-08-02 and the full sweep is a thousand logs, so the usual
## working pattern is to name the two or three you just retuned.
const _ONLY_SPECIES: Array[int] = []


func _ready() -> void:
	print("=== SPLIT ODDS — measured over %d logs per species ===" % _LOGS_PER_SPECIES)
	for species in range(SpeciesTable.count()):
		if not _ONLY_SPECIES.is_empty() and not _ONLY_SPECIES.has(species):
			continue
		await _measure(species)
	get_tree().quit()


func _measure(species: int) -> void:
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = species
	add_child(mg)
	await get_tree().process_frame

	var first_chance: float = mg.debug_split_chance()
	var row := SpeciesTable.at(species)
	var yield_item: StringName = &"?" if row == null else row.yield_item
	var authored: float = mg.default_split_chance if row == null else row.split_chance

	var swings := 0
	var fails := 0
	var clean_logs := 0
	var first_swing_fails := 0

	for l in range(_LOGS_PER_SPECIES):
		var log_fails := 0
		var guard := 0
		var first := true
		while mg.cuttable_count() > 0 and guard < 400:
			var n := Vector3.RIGHT if guard % 2 == 0 else Vector3.BACK
			var split: bool = mg.debug_swing_world(Plane(n, 0.0))
			swings += 1
			if not split:
				fails += 1
				log_fails += 1
				if first:
					first_swing_fails += 1
			first = false
			guard += 1
			await get_tree().process_frame
		if log_fails == 0:
			clean_logs += 1
		mg._spawn_fresh_log()
		await get_tree().process_frame

	print("%s: authored %.2f, first swing %.2f -> FAILED %d of %d swings (%.0f%%); first swing failed %.0f%% of logs; %d of %d logs took no failure at all"
		% [yield_item, authored, first_chance, fails, swings,
			100.0 * float(fails) / maxf(1.0, float(swings)),
			100.0 * float(first_swing_fails) / float(_LOGS_PER_SPECIES),
			clean_logs, _LOGS_PER_SPECIES])

	mg.queue_free()
	await get_tree().process_frame
