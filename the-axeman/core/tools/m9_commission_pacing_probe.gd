extends Node
## Read-only-from-disk M9 commission snapshot. It mutates only in-memory test
## state, prints the provisional early/middle/late offer economics, and claims
## structural validity rather than final pacing approval.

const _LEVELS := [3, 49, 96]


func _ready() -> void:
	var curve := GameConfig.current().level_curve
	var failed := curve == null or not Orders.validate_live_commissions().is_empty()
	print("=== M9 COMMISSION PACING PROBE — PLACEHOLDER VALUES ===")
	print("level,generation,slot_role,effort,offer,target,unit_cash,pieces,ordinary_cash,premium,premium_of_anchor,cash_anchor,commissions_to_anchor,tuning")
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
		var anchor := Orders.commission_cash_anchor()
		var rotation_seen: Dictionary = {}
		for generation in range(3):
			var offers := Orders.generate_commission_offers(generation)
			failed = failed or offers.size() != Orders.COMMISSION_OFFER_COUNT
			for offer: Dictionary in offers:
				if int(offer.get("offer_role", -1)) == Orders.CommissionOfferRole.ROTATION:
					rotation_seen[StringName(offer.get("required_species", &""))] = true
				_print_offer(level, generation, offer, anchor)
				failed = failed or int(offer.get("required_count", 0)) <= 0 \
					or int(offer.get("cash_bonus", 0)) <= 0 \
					or not String(offer.get("tuning_status", "")).begins_with("PLACEHOLDER")
		failed = failed or rotation_seen.is_empty()
		print("level %d rotation coverage across sampled generations: %d species" % [
			level, rotation_seen.size()])
	GameState.reset_to_defaults()
	print("=== COMMISSION PACING PROBE RESULT: %s ===" % (
		"FAIL" if failed else "PASS — measured tuning still required"))
	get_tree().quit()


func _print_offer(level: int, generation: int, offer: Dictionary, anchor: int) -> void:
	var required_item := StringName(offer.get("required_item", &""))
	var target := "any_firewood"
	var unit_cash := _cheapest_owned_cash()
	if required_item != &"":
		target = String(offer.get("required_species", ""))
		unit_cash = Market.get_price(required_item)
	var pieces := int(offer.get("required_count", 0))
	var ordinary := unit_cash * pieces
	var premium := int(offer.get("cash_bonus", 0))
	var ratio := 0.0 if anchor <= 0 else float(premium) / float(anchor)
	var completions_to_anchor := 0 if anchor <= 0 or premium <= 0 \
		else int(ceil(float(anchor) / float(premium)))
	var tuning := String(offer.get("tuning_status", ""))
	print("%d,%d,%s,%s,%s,%s,%d,%d,%d,%d,%.3f,%d,%d,%s" % [
		level, generation, _role_name(int(offer.get("offer_role", -1))),
		_effort_name(int(offer.get("effort_band", -1))),
		String(offer.get("template_id", "")), target, unit_cash, pieces,
		ordinary, premium, ratio, anchor, completions_to_anchor, tuning])


func _role_name(role: int) -> String:
	match role:
		Orders.CommissionOfferRole.MIXED:
			return "mixed"
		Orders.CommissionOfferRole.FRONTIER:
			return "frontier"
		Orders.CommissionOfferRole.ROTATION:
			return "rotation"
	return "invalid"


func _effort_name(effort: int) -> String:
	match effort:
		CommissionTemplateDef.EffortBand.STANDING:
			return "standing"
		CommissionTemplateDef.EffortBand.MAJOR:
			return "major"
		CommissionTemplateDef.EffortBand.PROJECT:
			return "project"
	return "invalid"


func _cheapest_owned_cash() -> int:
	var cheapest := 0
	for species: SpeciesDef in GameState.get_owned_species():
		var price := Market.get_price(species.yield_item)
		if price > 0 and (cheapest == 0 or price < cheapest):
			cheapest = price
	return cheapest
