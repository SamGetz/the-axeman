class_name CompanySimulation
extends RefCounted
## Pure deterministic queue simulation. It accepts persisted facts and an
## injected timestamp, and returns an unapplied receipt.

static func config() -> CompanySimulationConfig:
	return GameConfig.current().company_simulation


static func simulate(persisted: Dictionary, now_seconds: int,
		offline := false) -> CompanySimulationReceipt:
	var cfg := config()
	if cfg == null or not cfg.validate().is_empty():
		return CompanySimulationReceipt.new(&"invalid", 0, {}, {}, {},
			maxi(0, now_seconds), offline)
	var last := maxi(0, int(persisted.get("last_timestamp", now_seconds)))
	var raw_elapsed := maxi(0, now_seconds - last)
	var elapsed := mini(raw_elapsed, cfg.offline_cap_seconds) if offline else raw_elapsed
	var interval_multiplier := clampf(float(persisted.get(
		"interval_multiplier", 1.0)), 0.05, 1.0)
	var seconds_per_cycle := cfg.seconds_per_log * interval_multiplier
	var cycles := int(floor(float(elapsed) / seconds_per_cycle))
	var dispatch := clampi(int(persisted.get("dispatch_capacity",
		cfg.dispatch_capacity)), 1, 1000000)
	var parallel_lines := clampi(int(persisted.get("parallel_lines", 1)), 1, 1000000)
	var trees_per_cycle := clampi(int(persisted.get("trees_per_cycle", 1)),
		1, 1000000)
	# Depletion is an input to the pure simulation so output and payout are
	# calculated only from trees that still exist, including the final offline run.
	var earth_remaining := clampi(int(persisted.get("earth_trees_remaining",
		GameState.TOTAL_EARTH_TREES)), 0, GameState.TOTAL_EARTH_TREES)
	var budget := _multiply_capped(cycles, dispatch, earth_remaining)
	budget = _multiply_capped(budget, parallel_lines, earth_remaining)
	budget = _multiply_capped(budget, trees_per_cycle, earth_remaining)
	var logs_per_tree := clampi(int(persisted.get("logs_per_tree", 1)), 1, 1000000)
	var species_per_receipt := clampi(int(persisted.get(
		"species_per_receipt", 1)), 1, 25)
	var remaining: Dictionary = {}
	var raw_queues: Variant = persisted.get("queues", {})
	if raw_queues is Dictionary:
		for raw_species: Variant in raw_queues as Dictionary:
			var species_id := StringName(raw_species)
			var species := SpeciesTable.by_id(species_id)
			var count := clampi(int((raw_queues as Dictionary)[raw_species]), 0,
				CompanyLogistics.supplier_queue_capacity())
			if species != null and count > 0:
				remaining[species_id] = count
	var priority: Array[StringName] = []
	var raw_priority: Variant = persisted.get("route_priorities", [])
	if raw_priority is Array:
		for raw_species: Variant in raw_priority as Array:
			var species_id := StringName(raw_species)
			if remaining.has(species_id) and not priority.has(species_id):
				priority.append(species_id)
	for raw_species: Variant in remaining:
		var species_id := StringName(raw_species)
		if not priority.has(species_id):
			priority.append(species_id)
	var global_work_allocation := bool(persisted.get("global_work_allocation", false))
	if global_work_allocation:
		priority.clear()
		var raw_planetary_species: Variant = persisted.get("planetary_species", [])
		if raw_planetary_species is Array:
			for raw_species: Variant in raw_planetary_species as Array:
				var species_id := StringName(raw_species)
				if SpeciesTable.by_id(species_id) != null and not priority.has(species_id):
					priority.append(species_id)
	if priority.size() > species_per_receipt:
		priority.resize(species_per_receipt)
	var processed: Dictionary = {}
	var outputs: Dictionary = {}
	if global_work_allocation and not priority.is_empty():
		for index in range(priority.size()):
			if budget <= 0:
				break
			var species_id: StringName = priority[index]
			var slots_left := priority.size() - index
			var amount := int(ceil(float(budget) / float(slots_left)))
			processed[species_id] = amount
			_add_output(outputs, species_id, amount, cfg.output_pieces_per_log,
				logs_per_tree)
			budget -= amount
	while not global_work_allocation and budget > 0:
		var moved := false
		for species_id: StringName in priority:
			var queued := int(remaining.get(species_id, 0))
			if queued <= 0 or budget <= 0:
				continue
			var amount := mini(queued, budget)
			remaining[species_id] = queued - amount
			processed[species_id] = int(processed.get(species_id, 0)) + amount
			_add_output(outputs, species_id, amount, cfg.output_pieces_per_log,
				logs_per_tree)
			budget -= amount
			moved = true
		if not moved:
			break
	for species_id: StringName in remaining.keys():
		if int(remaining[species_id]) <= 0:
			remaining.erase(species_id)
	var next_timestamp := last + int(floor(float(elapsed) / seconds_per_cycle) \
		* seconds_per_cycle)
	if raw_elapsed > cfg.offline_cap_seconds and offline:
		next_timestamp = now_seconds
	var signature := "%d_%d_%d_%d" % [last, now_seconds,
		1 if offline else 0, _stable_queue_hash(processed)]
	return CompanySimulationReceipt.new(StringName("company_%s" % signature),
		elapsed, processed, outputs, remaining, next_timestamp, offline)


static func simulate_duration(persisted: Dictionary, elapsed_seconds: int) \
		-> CompanySimulationReceipt:
	var start := maxi(0, int(persisted.get("last_timestamp", 0)))
	return simulate(persisted, start + maxi(0, elapsed_seconds), false)


static func _stable_queue_hash(values: Dictionary) -> int:
	var keys: Array = values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var hash_value := 17
	for key: Variant in keys:
		hash_value = hash_value * 31 + String(key).hash()
		hash_value = hash_value * 31 + int(values[key])
	return absi(hash_value)


static func _multiply_capped(a: int, b: int, cap: int) -> int:
	if a <= 0 or b <= 0 or cap <= 0:
		return 0
	if a >= cap or b > cap / a:
		return cap
	return mini(cap, a * b)


static func _add_output(outputs: Dictionary, species_id: StringName, trees: int,
		base_output: int, logs_per_tree: int) -> void:
	var species := SpeciesTable.by_id(species_id)
	if species == null:
		return
	var output_per_tree := base_output * logs_per_tree
	var added_output := _multiply_capped(trees, output_per_tree,
		GameState.MAX_SAFE_ECONOMY_VALUE)
	var existing_output := int(outputs.get(species.yield_item, 0))
	outputs[species.yield_item] = mini(GameState.MAX_SAFE_ECONOMY_VALUE,
		existing_output + added_output)
