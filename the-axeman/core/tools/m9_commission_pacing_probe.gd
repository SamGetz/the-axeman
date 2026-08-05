extends Node
## Read-only-from-disk M9 commission snapshot. It mutates only in-memory test
## state, prints the provisional early/middle/late offer economics, and claims
## structural validity rather than final pacing approval.

const _LEVELS := [3, 49, 96]


func _ready() -> void:
	var curve := load("res://data/level_curve.tres") as LevelCurve
	var failed := curve == null or not Orders.validate_live_commissions().is_empty()
	print("=== M9 COMMISSION PACING PROBE — PLACEHOLDER VALUES ===")
	print("level,offer,target,unit_cash,pieces,ordinary_cash,premium,premium_ratio,next_sink,commissions_to_sink,tuning")
	if curve == null:
		print("=== COMMISSION PACING PROBE RESULT: FAIL ===")
		get_tree().quit()
		return
	for level: int in _LEVELS:
		var owned_ids: Array[String] = []
		for species: SpeciesDef in SpeciesTable.all():
			if species != null and species.unlock_level <= level:
				owned_ids.append(String(species.id))
		GameState.apply_save_dict({
			"xp": curve.total_xp_for_level(level),
			"owned_species": owned_ids,
			"completed_orders": [String(Orders.COMMISSION_UNLOCK_ORDER_ID)],
		})
		GameState.ensure_commission_offers()
		var offers := GameState.get_commission_offers()
		failed = failed or offers.size() != Orders.COMMISSION_OFFER_COUNT
		var next_species := GameState.get_next_unowned_species()
		var next_sink := 0 if next_species == null else next_species.unlock_cost
		for offer: Dictionary in offers:
			var required_item := StringName(offer.get("required_item", &""))
			var target := "any_firewood"
			var unit_cash := _cheapest_owned_cash()
			if required_item != &"":
				target = String(offer.get("required_species", ""))
				unit_cash = Market.get_price(required_item)
			var pieces := int(offer.get("required_count", 0))
			var ordinary := unit_cash * pieces
			var premium := int(offer.get("cash_bonus", 0))
			var ratio := 0.0 if ordinary <= 0 else float(premium) / float(ordinary)
			var total_receipt := ordinary + premium
			var completions_to_sink := 0 if next_sink <= 0 or total_receipt <= 0 \
				else int(ceil(float(next_sink) / float(total_receipt)))
			var tuning := String(offer.get("tuning_status", ""))
			print("%d,%s,%s,%d,%d,%d,%d,%.3f,%d,%d,%s" % [
				level, String(offer.get("template_id", "")), target,
				unit_cash, pieces, ordinary, premium, ratio, next_sink,
				completions_to_sink, tuning])
			failed = failed or unit_cash <= 0 or pieces <= 0 or premium <= 0 \
				or not tuning.begins_with("PLACEHOLDER")
	print("=== COMMISSION PACING PROBE RESULT: %s ===" % (
		"FAIL" if failed else "PASS — measured tuning still required"))
	GameState.reset_to_defaults()
	get_tree().quit()


func _cheapest_owned_cash() -> int:
	var cheapest := 0
	for species: SpeciesDef in GameState.get_owned_species():
		var price := Market.get_price(species.yield_item)
		if price > 0 and (cheapest == 0 or price < cheapest):
			cheapest = price
	return cheapest
