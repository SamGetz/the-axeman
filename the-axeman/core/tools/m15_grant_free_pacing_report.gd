extends RefCounted
## Pure, deterministic M15 reinvestment projection.
##
## This tool never writes GameState, InventoryManager or SaveSystem. It reads the
## authored catalogues into a local ledger, earns every modeled coin from manual,
## terrestrial-company or alien-company throughput, and records where current
## placeholder values create droughts. It is a policy comparison, not a tuning
## approval and not a substitute for the uninterrupted Compatibility playthrough.

enum Policy { CAUTIOUS, EXPECTED, OPTIMIZED }

const _MAX_SECONDS := 4 * 60 * 60
const _STEP_SECONDS := 1
const _MANAGEMENT_ALLOWANCE_SECONDS := 15 * 60
const _COMPANY_BASE_INTERVAL := 5.0
const _ALIEN_RECEIPT_SECONDS := 60
const _POLICY_NAMES := {
	Policy.CAUTIOUS: "cautious",
	Policy.EXPECTED: "expected",
	Policy.OPTIMIZED: "optimized",
}


static func run_all() -> Array[Dictionary]:
	var manual := _manual_projection()
	var out: Array[Dictionary] = []
	for policy: Policy in [Policy.CAUTIOUS, Policy.EXPECTED, Policy.OPTIMIZED]:
		out.append(_run_policy(policy, manual))
	return out


static func validate_catalogues() -> PackedStringArray:
	var errors := PackedStringArray()
	var rows := _production_rows()
	if rows.size() != 16:
		errors.append("expected sixteen M15 production rows, found %d" % rows.size())
	var ids: Dictionary = {}
	for row: ProductionUpgradeDef in rows:
		if row == null:
			errors.append("production catalogue contains a null row")
			continue
		errors.append_array(row.validate_production())
		if ids.has(row.id):
			errors.append("duplicate production row:%s" % row.id)
		ids[row.id] = true
	return errors


static func _run_policy(policy: Policy, manual: Dictionary) -> Dictionary:
	var manual_events: Array = manual.get("events", [])
	var event_index := 0
	var elapsed := 0
	var cash := 0
	var lifetime := 0
	var xp := 0
	var trees_remaining := GameState.TOTAL_EARTH_TREES
	var ranks: Dictionary = {}
	var purchases: Array[Dictionary] = []
	var reinvestment_spend := 0
	var mandatory_spend := 0
	var current_stage := ProductionUpgradeDef.Milestone.WATCHED_AUTOMATION
	var first_automation_seconds := -1
	var first_company_automation_seconds := -1
	var earth_zero_seconds := -1
	var terrestrial_output := 0
	var alien_lines := 0
	var alien_stage_ready_at := -1
	var alien_receipt_logs := 0
	var alien_receipt_cash := 0
	var next_mandatory := _mandatory_costs()
	var drought_started := -1
	var max_drought := 0
	var stage_history: Array[Dictionary] = []
	var latest_manual_species := 0
	var manual_complete := false

	while elapsed <= _MAX_SECONDS:
		while event_index < manual_events.size() \
				and int((manual_events[event_index] as Dictionary).get("time", 0)) <= elapsed:
			var event: Dictionary = manual_events[event_index]
			var earned := int(event.get("cash", 0))
			cash += earned
			lifetime += earned
			xp += int(event.get("xp", 0))
			latest_manual_species = int(event.get("species_index", latest_manual_species))
			event_index += 1
		manual_complete = event_index >= manual_events.size()

		# The watched splitter is a real intermediate milestone, not an invisible
		# portion of the company bill. Reserve its public purchase-chain cost first;
		# the remaining three logistics stages then fund unattended production.
		if first_automation_seconds < 0 \
				and elapsed >= int((manual.get("milestone_times", {}) as Dictionary).get(
					ProductionUpgradeDef.Milestone.TIMBER_DEPOT,
					GameState.MAX_SAFE_ECONOMY_VALUE)):
			var watched_cost := _watched_automation_cost()
			if cash >= watched_cost:
				cash -= watched_cost
				mandatory_spend += watched_cost
				first_automation_seconds = elapsed
				stage_history.append({
					"stage": "watched_automation",
					"seconds": elapsed,
					"cash_after": cash,
					"cost": watched_cost,
				})

		var target_stage := _target_stage(elapsed, manual, current_stage,
			trees_remaining, alien_lines, first_automation_seconds >= 0)
		if target_stage > current_stage:
			var stage_cost := int(next_mandatory.get(target_stage, 0))
			if cash >= stage_cost:
				cash -= stage_cost
				mandatory_spend += stage_cost
				current_stage = target_stage
				stage_history.append({
					"stage": _milestone_name(current_stage),
					"seconds": elapsed,
					"cash_after": cash,
					"cost": stage_cost,
				})
				if current_stage == ProductionUpgradeDef.Milestone.TIMBER_DEPOT:
					first_company_automation_seconds = elapsed
				if current_stage == ProductionUpgradeDef.Milestone.EARTH_DEPLETED:
					alien_stage_ready_at = elapsed + _frontier_fixed_seconds()
				drought_started = -1
			elif drought_started < 0:
				drought_started = elapsed
		elif drought_started >= 0:
			max_drought = maxi(max_drought, elapsed - drought_started)

		var bought := true
		while bought:
			bought = _buy_one(policy, elapsed, current_stage, cash, lifetime,
				trees_remaining, ranks, purchases)
			if bought:
				var purchase: Dictionary = purchases.back()
				var spent := int(purchase.get("cost", 0))
				cash -= spent
				reinvestment_spend += spent

		if current_stage >= ProductionUpgradeDef.Milestone.TIMBER_DEPOT \
				and current_stage < ProductionUpgradeDef.Milestone.EARTH_DEPLETED \
				and trees_remaining > 0:
			var rate := _terrestrial_rate(current_stage, latest_manual_species, ranks)
			var trees := mini(trees_remaining,
				maxi(0, int(floor(float(_STEP_SECONDS) * float(rate.trees_per_second)))))
			if trees > 0:
				var output := _multiply_capped(trees, int(rate.logs_per_tree),
					GameState.MAX_SAFE_ECONOMY_VALUE)
				var earned := _multiply_capped(output, int(rate.unit_cash),
					GameState.MAX_SAFE_ECONOMY_VALUE)
				earned = mini(GameState.MAX_SAFE_ECONOMY_VALUE,
					int(round(float(earned) * float(rate.cash_multiplier))))
				cash = mini(GameState.MAX_SAFE_ECONOMY_VALUE, cash + earned)
				lifetime = mini(GameState.MAX_SAFE_ECONOMY_VALUE, lifetime + earned)
				terrestrial_output = mini(GameState.MAX_SAFE_ECONOMY_VALUE,
					terrestrial_output + output)
				trees_remaining -= trees
				if trees_remaining == 0 and earth_zero_seconds < 0:
					earth_zero_seconds = elapsed

		if current_stage >= ProductionUpgradeDef.Milestone.EARTH_DEPLETED \
				and alien_stage_ready_at >= 0 and elapsed >= alien_stage_ready_at:
			alien_lines = _alien_lines_affordable(cash, alien_lines)
			var required := _alien_line_cost(alien_lines)
			if required > 0 and cash >= required:
				cash -= required
				mandatory_spend += required
				alien_lines += 1
				stage_history.append({
					"stage": "alien_line_%d" % alien_lines,
					"seconds": elapsed,
					"cash_after": cash,
					"cost": required,
				})
			if alien_lines >= 3 and (elapsed - alien_stage_ready_at) % \
					_ALIEN_RECEIPT_SECONDS == 0:
				var alien := _alien_receipt(ranks, alien_lines)
				alien_receipt_logs = int(alien.logs)
				alien_receipt_cash = int(alien.cash)
				cash = mini(GameState.MAX_SAFE_ECONOMY_VALUE, cash + alien_receipt_cash)
				lifetime = mini(GameState.MAX_SAFE_ECONOMY_VALUE,
					lifetime + alien_receipt_cash)
				break

		elapsed += _STEP_SECONDS

	if drought_started >= 0:
		max_drought = maxi(max_drought, elapsed - drought_started)
	var completion_seconds := elapsed + _MANAGEMENT_ALLOWANCE_SECONDS
	var manual_active_seconds := int(manual.get("seconds", 0))
	var complete := trees_remaining == 0 and alien_lines >= 3 \
		and alien_receipt_logs > 0
	return {
		"policy": _POLICY_NAMES[policy],
		"complete": complete,
		"modeled_seconds": elapsed,
		"modeled_minutes_with_management": completion_seconds / 60.0,
		"inside_two_to_four_hour_target": complete \
			and completion_seconds >= 2 * 60 * 60 \
			and completion_seconds <= 4 * 60 * 60,
		"manual_logs": int(manual.get("logs", 0)),
		"manual_active_seconds": manual_active_seconds,
		"tactile_share_with_management": 0.0 if completion_seconds <= 0 else \
			float(manual_active_seconds) / float(completion_seconds),
		"projected_xp": xp,
		"skill_purchase_target": SkillTree.core_purchase_count() \
			+ SkillTree.frontier_purchase_count(),
		"frontier_points_from_mastery": AlienCampaign.traits().size() * 3,
		"first_automation_seconds": first_automation_seconds,
		"first_automation_kind": "watched mechanical splitter",
		"first_company_automation_seconds": first_company_automation_seconds,
		"earth_zero_seconds": earth_zero_seconds,
		"cash_remaining": cash,
		"lifetime_cash": lifetime,
		"mandatory_spend": mandatory_spend,
		"reinvestment_spend": reinvestment_spend,
		"reinvestment_ratio": 0.0 if lifetime <= 0 else \
			float(reinvestment_spend) / float(lifetime),
		"max_decision_drought_seconds": max_drought,
		"earth_trees_remaining": trees_remaining,
		"terrestrial_output": terrestrial_output,
		"production_purchases": purchases,
		"stage_history": stage_history,
		"alien_lines": alien_lines,
		"m14_receipt_logs": alien_receipt_logs,
		"m14_receipt_cash": alien_receipt_cash,
		"tuning_status": "PLACEHOLDER — deterministic projection; real-time review required",
	}


static func _manual_projection() -> Dictionary:
	var curve := GameConfig.current().level_curve
	var config := GameConfig.current().xp_pacing
	var events: Array[Dictionary] = []
	var total_xp := 0
	var seconds := 0.0
	var total_logs := 0
	var milestone_times := {}
	var species := SpeciesTable.all()
	for index in range(species.size()):
		var wood: SpeciesDef = species[index]
		var mastery := M7CContent.mastery().by_species_id(wood.id)
		var logs := mastery.mastery_target
		var awarded_xp := maxi(1, int(round(float(wood.xp_reward) \
			* config.global_xp_multiplier)))
		if index + 1 < species.size():
			var next_wood: SpeciesDef = species[index + 1]
			var target_xp := curve.total_xp_for_level(next_wood.unlock_level)
			while total_xp + logs * awarded_xp < target_xp:
				logs += 1
		for _log in range(logs):
			seconds += float(config.representative_terrestrial_active_seconds[index])
			events.append({
				"time": int(ceil(seconds)),
				"cash": Market.get_price(wood.yield_item),
				"xp": awarded_xp,
				"species_index": index,
			})
		total_xp += logs * awarded_xp
		total_logs += logs
		if index == 2:
			milestone_times[ProductionUpgradeDef.Milestone.TIMBER_DEPOT] = int(ceil(seconds))
		if index == 11:
			milestone_times[ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY] = int(ceil(seconds))
	milestone_times[ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY] = int(ceil(seconds))
	return {
		"events": events,
		"logs": total_logs,
		"seconds": int(ceil(seconds)),
		"xp": total_xp,
		"milestone_times": milestone_times,
	}


static func _target_stage(elapsed: int, manual: Dictionary, current_stage: int,
		trees_remaining: int, alien_lines: int, watched_ready: bool) -> int:
	var times: Dictionary = manual.get("milestone_times", {})
	# Milestones are paid and recorded one at a time. Returning the highest elapsed
	# milestone would skip the timber/continental cash gates when a drought delayed
	# them past the next representative timestamp.
	match current_stage:
		ProductionUpgradeDef.Milestone.WATCHED_AUTOMATION:
			if watched_ready and elapsed >= int(times.get(
				ProductionUpgradeDef.Milestone.TIMBER_DEPOT,
				GameState.MAX_SAFE_ECONOMY_VALUE)):
				return ProductionUpgradeDef.Milestone.TIMBER_DEPOT
		ProductionUpgradeDef.Milestone.TIMBER_DEPOT:
			if elapsed >= int(times.get(ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY,
				GameState.MAX_SAFE_ECONOMY_VALUE)):
				return ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY
		ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY:
			if elapsed >= int(times.get(ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY,
				GameState.MAX_SAFE_ECONOMY_VALUE)):
				return ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY
		ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY:
			if trees_remaining == 0:
				return ProductionUpgradeDef.Milestone.EARTH_DEPLETED
		ProductionUpgradeDef.Milestone.EARTH_DEPLETED:
			if alien_lines >= 1:
				return ProductionUpgradeDef.Milestone.FIRST_ALIEN_LINE
		ProductionUpgradeDef.Milestone.FIRST_ALIEN_LINE:
			if alien_lines >= 2:
				return ProductionUpgradeDef.Milestone.SECOND_ALIEN_LINE
		ProductionUpgradeDef.Milestone.SECOND_ALIEN_LINE:
			if alien_lines >= 3:
				return ProductionUpgradeDef.Milestone.THREE_ALIEN_LINES
	return current_stage


static func _buy_one(policy: Policy, elapsed: int, stage: int, cash: int,
		lifetime: int, trees_remaining: int, ranks: Dictionary,
		purchases: Array[Dictionary]) -> bool:
	var candidates: Array[Dictionary] = []
	for row: ProductionUpgradeDef in _production_rows():
		var level := int(ranks.get(row.id, 0))
		if level >= row.max_level or lifetime < row.required_lifetime_cash \
				or stage < row.required_milestone:
			continue
		if row.required_upgrade_id != &"" and int(ranks.get(
				row.required_upgrade_id, 0)) <= 0:
			continue
		if row.id == &"planetary_dispatch_core" and level == row.max_level - 1 \
				and int(ranks.get(&"continuity_reserve", 0)) <= 0:
			continue
		var cost := row.cost_for_level(level)
		if cost <= 0 or cost > cash:
			continue
		var before := _cash_rate(stage, ranks)
		var trial := ranks.duplicate()
		trial[row.id] = level + 1
		var after := _cash_rate(stage, trial)
		var gain := maxf(0.0, after - before)
		var score := 0.0
		match policy:
			Policy.CAUTIOUS:
				score = 1000000000000000.0 if row.id == &"continuity_reserve" \
					else 1.0 / float(cost)
			Policy.EXPECTED:
				score = gain / float(cost)
			Policy.OPTIMIZED:
				score = gain
		candidates.append({
			"row": row,
			"cost": cost,
			"level": level,
			"rate_before": before,
			"rate_after": after,
			"score": score,
		})
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a.score), float(b.score)):
			return int(a.cost) < int(b.cost)
		return float(a.score) > float(b.score))
	var chosen: Dictionary = candidates[0]
	var row: ProductionUpgradeDef = chosen.row
	var next_level := int(chosen.level) + 1
	ranks[row.id] = next_level
	var gain := float(chosen.rate_after) - float(chosen.rate_before)
	purchases.append({
		"seconds": elapsed,
		"id": String(row.id),
		"rank": next_level,
		"cost": int(chosen.cost),
		"cash_before": cash,
		"lifetime_cash": lifetime,
		"trees_remaining": trees_remaining,
		"rate_before": float(chosen.rate_before),
		"rate_after": float(chosen.rate_after),
		"payback_seconds": -1.0 if gain <= 0.0 else float(chosen.cost) / gain,
		"tuning_status": row.tuning_status,
	})
	return true


static func _terrestrial_rate(stage: int, species_index: int,
		ranks: Dictionary) -> Dictionary:
	var base_dispatch := 0
	match stage:
		ProductionUpgradeDef.Milestone.TIMBER_DEPOT:
			base_dispatch = 6
		ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY:
			base_dispatch = _route_capacity()
		_:
			base_dispatch = _route_capacity()
	var dispatch := base_dispatch + int(round(_effect_total(
		ProductionUpgradeDef.ProductionEffect.DISPATCH_CAPACITY, ranks)))
	var parallel := 1 + int(round(_effect_total(
		ProductionUpgradeDef.ProductionEffect.PARALLEL_LINES, ranks)))
	parallel = maxi(1, int(round(float(parallel) * (1.0 + _effect_total(
		ProductionUpgradeDef.ProductionEffect.PARALLEL_MULTIPLIER, ranks)))))
	var trees_per_cycle := maxi(1, int(round(1.0 + _effect_total(
		ProductionUpgradeDef.ProductionEffect.TREES_PER_CYCLE, ranks))))
	var interval := _interval_multiplier(
		ProductionUpgradeDef.ProductionEffect.INTERVAL_REDUCTION, ranks)
	var trees_per_second := float(dispatch * parallel * trees_per_cycle) \
		/ (_COMPANY_BASE_INTERVAL * interval)
	var logs_per_tree := maxi(1, int(round(1.0 + _effect_total(
		ProductionUpgradeDef.ProductionEffect.LOGS_PER_TREE, ranks))))
	var species := SpeciesTable.at(clampi(species_index, 0, SpeciesTable.count() - 1))
	return {
		"trees_per_second": trees_per_second,
		"logs_per_tree": logs_per_tree,
		"unit_cash": Market.get_price(species.yield_item),
		"cash_multiplier": 1.0 + _effect_total(
			ProductionUpgradeDef.ProductionEffect.AUTOMATION_SALE_VALUE, ranks),
	}


static func _cash_rate(stage: int, ranks: Dictionary) -> float:
	if stage >= ProductionUpgradeDef.Milestone.EARTH_DEPLETED:
		return _alien_receipt(ranks, 3).cash / float(_ALIEN_RECEIPT_SECONDS)
	var rate := _terrestrial_rate(stage, SpeciesTable.count() - 1, ranks)
	return float(rate.trees_per_second) * float(rate.logs_per_tree) \
		* float(rate.unit_cash) * float(rate.cash_multiplier)


static func _alien_receipt(ranks: Dictionary, line_count: int) -> Dictionary:
	var cfg := GameConfig.current().alien_company
	var interval := _interval_multiplier(
		ProductionUpgradeDef.ProductionEffect.ALIEN_INTERVAL_REDUCTION, ranks)
	var cycles := int(floor(float(_ALIEN_RECEIPT_SECONDS) \
		/ (float(cfg.seconds_per_cargo) * interval)))
	var capacity := cfg.cargo_logs_per_fleet + int(round(_effect_total(
		ProductionUpgradeDef.ProductionEffect.ALIEN_CARGO_CAPACITY, ranks)))
	var output_multiplier := 1.0 + _effect_total(
		ProductionUpgradeDef.ProductionEffect.ORBITAL_OUTPUT, ranks)
	var cash_multiplier := 1.0 + _effect_total(
		ProductionUpgradeDef.ProductionEffect.ALIEN_SALE_VALUE, ranks)
	var logs := 0
	var cash := 0
	var traits := AlienCampaign.traits()
	for index in range(mini(line_count, traits.size())):
		var wood: AlienWoodTraitDef = traits[index]
		var line_logs := int(round(float(cycles \
			* (capacity + cfg.orbital_logs_per_line)) * output_multiplier))
		logs += line_logs
		cash += int(round(float(line_logs * Market.get_price(wood.yield_item)) \
			* cash_multiplier))
	return {"logs": logs, "cash": cash}


static func _effect_total(kind: ProductionUpgradeDef.ProductionEffect,
		ranks: Dictionary) -> float:
	var total := 0.0
	for row: ProductionUpgradeDef in _production_rows():
		if row.production_effect == kind:
			total += float(int(ranks.get(row.id, 0))) * row.production_step
	return total


static func _interval_multiplier(kind: ProductionUpgradeDef.ProductionEffect,
		ranks: Dictionary) -> float:
	var floor_value := 1.0
	var reduction := 0.0
	for row: ProductionUpgradeDef in _production_rows():
		if row.production_effect != kind:
			continue
		var level := int(ranks.get(row.id, 0))
		if level > 0:
			floor_value = minf(floor_value, row.interval_floor)
		reduction += float(level) * row.production_step
	return maxf(floor_value, 1.0 - reduction)


static func _mandatory_costs() -> Dictionary:
	var timber := 0
	var continental := 0
	var seen: Dictionary = {}
	for upgrade: LogisticsUpgradeDef in CompanyLogistics.upgrades():
		timber += upgrade.cost
	for species: SpeciesDef in SpeciesTable.all():
		continental += species.unlock_cost
		if species.supplier_upgrade_id != &"" and not seen.has(species.supplier_upgrade_id):
			var supplier := Shop.get_upgrade(species.supplier_upgrade_id)
			if supplier != null:
				continental += supplier.base_cost
				seen[species.supplier_upgrade_id] = true
	for region: RegionDef in RegionalNetwork.regions():
		continental += region.depot_cost
		var route := RegionalNetwork.route_for_region(region.id)
		if route != null:
			continental += route.cost
	for project: InfrastructureProjectDef in RegionalNetwork.projects():
		continental += project.cash_cost
	var launch := 0
	for project: LaunchProjectDef in LaunchProgram.projects():
		launch += project.cash_cost
	return {
		ProductionUpgradeDef.Milestone.TIMBER_DEPOT: timber,
		ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY: continental,
		ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY: 0,
		ProductionUpgradeDef.Milestone.EARTH_DEPLETED: launch,
	}


static func _watched_automation_cost() -> int:
	var total := 0
	var seen: Dictionary = {}
	for id: StringName in [GameState.UPGRADE_SUPPLIER_LEDGER,
			GameState.UPGRADE_HANDCART, GameState.UPGRADE_COFFEE_THERMOS,
			&"mechanical_splitter", &"splitter_profile_quaking_aspen"]:
		var upgrade := Shop.get_upgrade(id)
		if upgrade != null and not seen.has(id):
			total += upgrade.base_cost
			seen[id] = true
	return total


static func _frontier_fixed_seconds() -> int:
	var seconds := 0
	for expedition: ExpeditionDef in LaunchProgram.expedition_table().expeditions:
		seconds += expedition.flight_seconds
	var config := GameConfig.current().xp_pacing
	for index in range(AlienCampaign.traits().size()):
		seconds += int(ceil(float(AlienCampaign.traits()[index].manual_mastery_target) \
			* float(config.representative_alien_active_seconds[index])))
	return seconds


static func _alien_line_cost(index: int) -> int:
	var traits := AlienCampaign.traits()
	if index < 0 or index >= traits.size():
		return 0
	return traits[index].fleet_cost + traits[index].orbital_line_cost


static func _alien_lines_affordable(_cash: int, current: int) -> int:
	return clampi(current, 0, AlienCampaign.traits().size())


static func _route_capacity() -> int:
	var capacity := 0
	for region: RegionDef in RegionalNetwork.regions():
		var route := RegionalNetwork.route_for_region(region.id)
		if route != null:
			capacity += route.capacity
	return maxi(1, capacity)


static func _production_rows() -> Array[ProductionUpgradeDef]:
	var rows: Array[ProductionUpgradeDef] = []
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef:
			rows.append(upgrade as ProductionUpgradeDef)
	return rows


static func _milestone_name(stage: int) -> String:
	match stage:
		ProductionUpgradeDef.Milestone.WATCHED_AUTOMATION:
			return "watched_automation"
		ProductionUpgradeDef.Milestone.TIMBER_DEPOT:
			return "timber_depot"
		ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY:
			return "continental_company"
		ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY:
			return "planetary_industry"
		ProductionUpgradeDef.Milestone.EARTH_DEPLETED:
			return "earth_depleted"
		ProductionUpgradeDef.Milestone.FIRST_ALIEN_LINE:
			return "first_alien_line"
		ProductionUpgradeDef.Milestone.SECOND_ALIEN_LINE:
			return "second_alien_line"
		ProductionUpgradeDef.Milestone.THREE_ALIEN_LINES:
			return "three_alien_lines"
	return "unknown"


static func _multiply_capped(a: int, b: int, cap: int) -> int:
	if a <= 0 or b <= 0 or cap <= 0:
		return 0
	if a >= cap or b > cap / a:
		return cap
	return mini(cap, a * b)
