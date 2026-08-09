class_name ProductionEconomy
extends RefCounted
## Read-only composition of purchased production ranks. State stays in
## GameState building tiers; this service only interprets catalogue effects.


static func earnings_band_for(lifetime_cash: int) -> int:
	var band := 0
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if not upgrade is ProductionUpgradeDef:
			continue
		var production := upgrade as ProductionUpgradeDef
		if lifetime_cash >= production.required_lifetime_cash:
			band = maxi(band, maxi(1, int(production.required_milestone)))
	return band


static func minimum_lifetime_for_milestone(
		milestone: ProductionUpgradeDef.Milestone) -> int:
	var minimum := GameState.MAX_SAFE_ECONOMY_VALUE
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef:
			var production := upgrade as ProductionUpgradeDef
			if production.required_milestone == milestone:
				minimum = mini(minimum, production.required_lifetime_cash)
	return 0 if minimum == GameState.MAX_SAFE_ECONOMY_VALUE else minimum


static func prerequisite_met(def: ProductionUpgradeDef) -> bool:
	if def == null or GameState.get_lifetime_cash_earned() \
			< def.required_lifetime_cash:
		return false
	match def.required_milestone:
		ProductionUpgradeDef.Milestone.WATCHED_AUTOMATION:
			return GameState.get_automated_log_equivalents() > 0
		ProductionUpgradeDef.Milestone.TIMBER_DEPOT:
			return CompanyLogistics.all_owned()
		ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY:
			return GameState.get_regional_route_count() > 0
		ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY:
			return EarthCampaign.terrestrial_requirements_complete()
		ProductionUpgradeDef.Milestone.EARTH_DEPLETED:
			return GameState.is_earth_depleted()
		ProductionUpgradeDef.Milestone.FIRST_ALIEN_LINE:
			return GameState.get_orbital_line_count() >= 1
		ProductionUpgradeDef.Milestone.SECOND_ALIEN_LINE:
			return GameState.get_orbital_line_count() >= 2
		ProductionUpgradeDef.Milestone.THREE_ALIEN_LINES:
			return GameState.get_orbital_line_count() >= 3
	return false


static func total(kind: ProductionUpgradeDef.ProductionEffect) -> float:
	var amount := 0.0
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef:
			var production := upgrade as ProductionUpgradeDef
			if production.production_effect == kind:
				amount += float(Shop.get_level(production.id)) \
					* production.production_step
	return amount


static func interval_multiplier(alien := false) -> float:
	var kind := ProductionUpgradeDef.ProductionEffect.ALIEN_INTERVAL_REDUCTION \
		if alien else ProductionUpgradeDef.ProductionEffect.INTERVAL_REDUCTION
	var floor_value := 1.0
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef:
			var production := upgrade as ProductionUpgradeDef
			if production.production_effect == kind and Shop.get_level(production.id) > 0:
				floor_value = minf(floor_value, production.interval_floor)
	return maxf(floor_value, 1.0 - total(kind))


static func effective_parallel_lines() -> int:
	var additive := 1 + int(round(total(
		ProductionUpgradeDef.ProductionEffect.PARALLEL_LINES)))
	var multiplier := 1.0 + total(
		ProductionUpgradeDef.ProductionEffect.PARALLEL_MULTIPLIER)
	return maxi(1, int(round(float(additive) * multiplier)))


static func logs_per_tree() -> int:
	return maxi(1, int(round(1.0 + total(
		ProductionUpgradeDef.ProductionEffect.LOGS_PER_TREE))))


static func trees_per_cycle() -> int:
	return maxi(1, int(round(1.0 + total(
		ProductionUpgradeDef.ProductionEffect.TREES_PER_CYCLE))))


static func dispatch_capacity_bonus() -> int:
	return maxi(0, int(round(total(
		ProductionUpgradeDef.ProductionEffect.DISPATCH_CAPACITY))))


static func species_per_receipt() -> int:
	return maxi(1, 1 + int(round(total(
		ProductionUpgradeDef.ProductionEffect.SPECIES_PER_RECEIPT))))


static func automation_sale_bonus() -> float:
	return maxf(0.0, total(
		ProductionUpgradeDef.ProductionEffect.AUTOMATION_SALE_VALUE))


static func automation_xp_rate() -> float:
	var config := GameConfig.current().mechanical_splitter
	var base_rate := config.base_xp_rate
	return clampf(base_rate + Shop.total_effect(
		UpgradeDef.Effect.AUTOMATION_XP_GAIN), 0.0, 1.0)


static func alien_sale_bonus() -> float:
	return maxf(0.0, total(
		ProductionUpgradeDef.ProductionEffect.ALIEN_SALE_VALUE))


static func alien_cargo_capacity_bonus() -> int:
	return maxi(0, int(round(total(
		ProductionUpgradeDef.ProductionEffect.ALIEN_CARGO_CAPACITY))))


static func orbital_output_multiplier() -> float:
	return maxf(1.0, 1.0 + total(
		ProductionUpgradeDef.ProductionEffect.ORBITAL_OUTPUT))


static func has_continuity_reserve() -> bool:
	return total(ProductionUpgradeDef.ProductionEffect.CONTINUITY_RESERVE) > 0.0
