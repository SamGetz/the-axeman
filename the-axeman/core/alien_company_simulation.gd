class_name AlienCompanySimulation
extends RefCounted

static func config() -> AlienCompanyConfig:
	return GameConfig.current().alien_company


static func simulate(persisted: Dictionary, elapsed_seconds: int) -> AlienAutomationReceipt:
	var cfg := config()
	if cfg == null or not cfg.validate().is_empty() or elapsed_seconds <= 0:
		return AlienAutomationReceipt.new(&"alien_empty", {}, {}, 0)
	var seconds_per_cargo := maxf(1.0, float(cfg.seconds_per_cargo) \
		* ProductionEconomy.interval_multiplier(true))
	var cycles := int(floor(float(elapsed_seconds) / seconds_per_cargo))
	var fleets: Dictionary = persisted.get("fleets", {})
	var lines: Dictionary = persisted.get("orbital_lines", {})
	var charter := StringName(persisted.get("charter", &""))
	var processed: Dictionary = {}
	var outputs: Dictionary = {}
	var output_multiplier := ProductionEconomy.orbital_output_multiplier()
	var remaining_cap := mini(GameState.MAX_SAFE_ECONOMY_VALUE,
		int(round(float(cfg.receipt_log_cap) * output_multiplier)))
	var cargo_per_fleet := cfg.cargo_logs_per_fleet \
		+ ProductionEconomy.alien_cargo_capacity_bonus()
	var orbital_per_line := maxi(1, int(round(float(cfg.orbital_logs_per_line) \
		* output_multiplier)))
	var destinations: Array = fleets.keys()
	destinations.sort_custom(func(a: Variant, b: Variant) -> bool:
		if StringName(a) == charter:
			return true
		if StringName(b) == charter:
			return false
		return String(a) < String(b))
	for raw_destination: Variant in destinations:
		if remaining_cap <= 0:
			break
		var destination_id := StringName(raw_destination)
		var wood_trait := AlienCampaign.trait_for_destination(destination_id)
		if wood_trait == null or not lines.has(destination_id):
			continue
		var fleet_count := clampi(int(fleets.get(destination_id, 0)), 0,
			cfg.fleet_cap_per_destination)
		var per_cycle := fleet_count * cargo_per_fleet + orbital_per_line
		var logs := remaining_cap if cycles > remaining_cap / maxi(1, per_cycle) \
			else mini(remaining_cap, cycles * per_cycle)
		if logs <= 0:
			continue
		processed[destination_id] = logs
		outputs[wood_trait.yield_item] = logs
		remaining_cap -= logs
	return AlienAutomationReceipt.new(StringName("alien_%d_%d" % [
		elapsed_seconds, _stable_hash(processed)]), processed, outputs, elapsed_seconds)


static func _stable_hash(values: Dictionary) -> int:
	var keys := values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var value := 23
	for key: Variant in keys:
		value = value * 31 + String(key).hash() + int(values[key])
	return absi(value)
