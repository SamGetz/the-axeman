extends Node
## Read-only Slice 6 economy snapshot at the approved representative levels.
## These rows expose authored PLACEHOLDER values for measured review; they do
## not claim final pacing or mutate any player state.

const _LEVELS := [9, 49, 96]


func _ready() -> void:
	var failed := false
	print("=== M8 SLICE 6 PACING PROBE — PLACEHOLDER VALUES ===")
	print("level,species,unlock_cost,unit_cash,contract_pieces,base_delivery_cash,contract_bonus,profile_cost,mastery_logs,splitter_base_cash,splitter_time_budget_xp")
	for level in _LEVELS:
		var species := _species_at_level(level)
		if species == null:
			push_error("No species unlocks at representative level %d" % level)
			failed = true
			continue
		var order := Orders.by_id(StringName("%s_delivery" % species.id))
		var profile := MechanicalSplitter.profile_for_species(species.id)
		var mastery := M7CContent.mastery().by_species_id(species.id)
		if order == null or profile == null or mastery == null:
			push_error("Representative level %d has incomplete authored content" % level)
			failed = true
			continue
		var unit_cash := Market.get_price(species.yield_item)
		var splitter_logs := 5
		var splitter_cash := unit_cash * splitter_logs
		var splitter_xp := int(floor(GameConfig.current().xp_pacing \
			.watched_automation_base_xp_for_cycle(species, 5.0, 0.20)))
		print("%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
			level, species.display_name, species.unlock_cost, unit_cash,
			order.required_count, unit_cash * order.required_count,
			order.cash_bonus, profile.base_cost, mastery.mastery_target,
			splitter_cash, splitter_xp])
		failed = failed or not order.tuning_status.begins_with("PLACEHOLDER") \
			or not profile.tuning_status.begins_with("PLACEHOLDER")
	print("=== PACING PROBE RESULT: %s ===" % ("FAIL" if failed else "PASS — measured tuning still required"))
	get_tree().quit(1 if failed else 0)


func _species_at_level(level: int) -> SpeciesDef:
	for species: SpeciesDef in SpeciesTable.all():
		if species != null and species.unlock_level == level:
			return species
	return null
