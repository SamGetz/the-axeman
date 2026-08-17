class_name LegacyProgressionRefundTable
extends Resource
## Explicit v19 conversion data. Upgrade arrays are cumulative refunds by owned
## rank; species values are one-time ownership refunds. Permanent XP and skill
## ranks overlap, so their explicit entitlement conversions use the larger value.

const MAX_SAFE_REFUND := 1_000_000_000_000_000_000

@export var cumulative_upgrade_refunds: Dictionary = {}
@export var species_ownership_refunds: Dictionary = {}
@export_range(1, 1000000000, 1) var legacy_xp_per_home_cash_unit := 10
## id -> Vector2i(max recognized rank, legacy skill-point cost per rank).
@export var legacy_skill_rank_contracts: Dictionary = {}
## Save-v1 used two retired ids and different per-rank costs. These mappings
## remain pinned migration data rather than borrowing values from the retired
## live progression catalogue.
@export var legacy_v1_skill_aliases: Dictionary = {}
@export var legacy_v1_skill_rank_contracts: Dictionary = {}
@export var legacy_alien_destination_ids := PackedStringArray()
@export_range(0, 100, 1) var legacy_mastered_destination_state := 7
@export_range(0, 100, 1) var legacy_alien_mastery_skill_points := 3
@export var legacy_lifetime_cash_upgrade_floors: Dictionary = {}
@export var legacy_timber_depot_lifetime_floor: int = 0
@export var legacy_continental_lifetime_floor: int = 0
@export var legacy_planetary_lifetime_floor: int = 0
@export var legacy_first_alien_line_lifetime_floor: int = 0
@export var legacy_second_alien_line_lifetime_floor: int = 0
@export var legacy_third_alien_line_lifetime_floor: int = 0
@export var legacy_total_earth_trees: int = 3_040_000_000_000
@export_range(1, 100, 1) var legacy_manual_logs_per_earth_tree := 4
@export_range(0, 20, 1) var legacy_complete_earth_finale_state := 3
@export_range(1, 1000000000, 1) var home_cash_per_legacy_skill_point := 100
@export var capability_seeds: Array[LegacyCapabilitySeedDef] = []
@export_range(1, 1000000000, 1) var exhausted_blueprint_home_cash := 250
@export_multiline var tuning_status := \
	"PLACEHOLDER — v19 migration refund rates require explicit measured approval"


func upgrade_refund(legacy_id: StringName, rank: int) -> int:
	if rank <= 0 or not cumulative_upgrade_refunds.has(legacy_id):
		return 0
	var raw: Variant = cumulative_upgrade_refunds[legacy_id]
	if not (raw is PackedInt64Array):
		return 0
	var values := raw as PackedInt64Array
	return 0 if values.is_empty() else int(values[clampi(rank - 1, 0, values.size() - 1)])


func species_refund(species_id: StringName) -> int:
	return maxi(0, int(species_ownership_refunds.get(species_id, 0)))


func xp_refund(permanent_xp: int) -> int:
	return maxi(0, permanent_xp) / maxi(1, legacy_xp_per_home_cash_unit)


func skill_entitlement_refund(skill_levels: Dictionary,
		saved_unspent_entitlement: int = 0, source_version: int = -1) -> int:
	var normalized_skills := _normalised_skill_levels(skill_levels, source_version)
	var contracts := legacy_v1_skill_rank_contracts \
		if source_version == 1 else legacy_skill_rank_contracts
	var recognized_spent_points := 0
	for raw_id: Variant in normalized_skills:
		if not (raw_id is String or raw_id is StringName) \
				or not (normalized_skills[raw_id] is int):
			continue
		var id := StringName(raw_id)
		var raw_contract: Variant = contracts.get(id, Vector2i.ZERO)
		if not (raw_contract is Vector2i):
			continue
		var contract := raw_contract as Vector2i
		var rank := clampi(int(normalized_skills[raw_id]), 0, contract.x)
		var point_cost := maxi(0, contract.y)
		var points := mini(rank, MAX_SAFE_REFUND / maxi(1, point_cost)) * point_cost
		recognized_spent_points = mini(MAX_SAFE_REFUND,
			recognized_spent_points + mini(points,
				MAX_SAFE_REFUND - recognized_spent_points))
	var entitlement_points := maxi(clampi(saved_unspent_entitlement, 0, MAX_SAFE_REFUND),
		recognized_spent_points)
	var rate := maxi(1, home_cash_per_legacy_skill_point)
	return mini(entitlement_points, MAX_SAFE_REFUND / rate) * rate


## Permanent XP and spent/unspent skill entitlement describe overlapping value.
## Migration takes the larger explicit conversion and never sums the two.
func progression_entitlement_refund(permanent_xp: int, skill_levels: Dictionary,
		saved_unspent_entitlement: int = 0, source_version: int = -1) -> int:
	return maxi(xp_refund(permanent_xp),
		skill_entitlement_refund(skill_levels, saved_unspent_entitlement,
			source_version))


func _normalised_skill_levels(skill_levels: Dictionary,
		source_version: int) -> Dictionary:
	if source_version != 1:
		return skill_levels
	var out: Dictionary = {}
	for raw_id: Variant in skill_levels:
		var raw_rank: Variant = skill_levels[raw_id]
		if typeof(raw_rank) != TYPE_INT:
			continue
		var source_id := StringName(raw_id)
		var id := StringName(legacy_v1_skill_aliases.get(source_id, source_id))
		var raw_contract: Variant = legacy_v1_skill_rank_contracts.get(
			id, Vector2i.ZERO)
		if not (raw_contract is Vector2i):
			continue
		var contract := raw_contract as Vector2i
		var rank := clampi(int(raw_rank), 0, contract.x)
		if rank > 0:
			out[id] = maxi(int(out.get(id, 0)), rank)
	return out


func pre_v17_alien_mastery_entitlement(source_version: int,
		destination_states: Variant) -> int:
	if source_version > 16 or not (destination_states is Dictionary):
		return 0
	var recognized: Dictionary = {}
	for id: String in legacy_alien_destination_ids:
		recognized[StringName(id)] = true
	var mastered := 0
	for raw_id: Variant in destination_states:
		if not (raw_id is String or raw_id is StringName) \
				or not (destination_states[raw_id] is int):
			continue
		var id := StringName(raw_id)
		if recognized.has(id) and int(destination_states[raw_id]) \
				== legacy_mastered_destination_state:
			mastered += 1
	return mastered * legacy_alien_mastery_skill_points


func pre_v15_earth_trees(source_version: int, source: Dictionary) -> int:
	if source_version > 14:
		return _typed_non_negative_int(source.get("earth_trees_felled", 0))
	var full_clear := source.get("earth_master", false) is bool \
		and bool(source.get("earth_master", false)) \
		and source.get("earth_finale_state", -1) is int \
		and int(source.get("earth_finale_state", -1)) \
			== legacy_complete_earth_finale_state \
		and source.get("earth_finale_splits", -1) is int \
		and int(source.get("earth_finale_splits", -1)) == 3
	if full_clear:
		return legacy_total_earth_trees
	var manual_logs := _typed_non_negative_int(
		source.get("manual_log_equivalents", 0))
	var automated_trees := _typed_non_negative_int(
		source.get("automated_log_equivalents", 0))
	var manual_trees := manual_logs / maxi(1, legacy_manual_logs_per_earth_tree)
	return mini(legacy_total_earth_trees, _safe_add(manual_trees, automated_trees))


func pre_v15_lifetime_cash_floor(source_version: int, source: Dictionary) -> int:
	if source_version > 14:
		return _typed_non_negative_int(source.get("lifetime_cash_earned", 0))
	var floor_value := _typed_non_negative_int(source.get("cash", 0))
	var buildings: Variant = source.get("building_tiers", {})
	if buildings is Dictionary:
		for raw_id: Variant in legacy_lifetime_cash_upgrade_floors:
			var tier: Variant = (buildings as Dictionary).get(raw_id,
				(buildings as Dictionary).get(String(raw_id), 1))
			if tier is int and int(tier) > 1:
				floor_value = maxi(floor_value,
					int(legacy_lifetime_cash_upgrade_floors[raw_id]))
		var dispatch_tier: Variant = (buildings as Dictionary).get(
			"dispatch_console", 1)
		if dispatch_tier is int and int(dispatch_tier) > 1:
			floor_value = maxi(floor_value, legacy_timber_depot_lifetime_floor)
	var routes: Variant = source.get("regional_routes", {})
	if routes is Dictionary and not (routes as Dictionary).is_empty():
		floor_value = maxi(floor_value, legacy_continental_lifetime_floor)
	var projects: Variant = source.get("infrastructure_projects", [])
	if projects is Array and not (projects as Array).is_empty():
		floor_value = maxi(floor_value, legacy_planetary_lifetime_floor)
	var lines: Variant = source.get("orbital_lines", [])
	if lines is Array:
		match (lines as Array).size():
			1:
				floor_value = maxi(floor_value,
					legacy_first_alien_line_lifetime_floor)
			2:
				floor_value = maxi(floor_value,
					legacy_second_alien_line_lifetime_floor)
			3, 4, 5, 6, 7, 8, 9, 10:
				floor_value = maxi(floor_value,
					legacy_third_alien_line_lifetime_floor)
			_:
				if (lines as Array).size() > 3:
					floor_value = maxi(floor_value,
						legacy_third_alien_line_lifetime_floor)
	return mini(MAX_SAFE_REFUND, floor_value)


func seed_for_source(legacy_source_id: StringName) -> Array[LegacyCapabilitySeedDef]:
	var out: Array[LegacyCapabilitySeedDef] = []
	for seed: LegacyCapabilitySeedDef in capability_seeds:
		if seed != null and seed.legacy_source_id == legacy_source_id:
			out.append(seed)
	return out


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if cumulative_upgrade_refunds.is_empty():
		errors.append("legacy refund table has no recognized upgrade ids")
	for raw_id: Variant in cumulative_upgrade_refunds:
		var id := StringName(raw_id)
		var raw: Variant = cumulative_upgrade_refunds[raw_id]
		if id == &"" or not (raw is PackedInt64Array) \
				or (raw as PackedInt64Array).is_empty():
			errors.append("legacy upgrade refund row is invalid:%s" % id)
			continue
		var previous := -1
		for value: int in raw as PackedInt64Array:
			if value < 0 or value < previous:
				errors.append("legacy upgrade refund must be non-negative and cumulative:%s" % id)
				break
			previous = value
	if species_ownership_refunds.is_empty():
		errors.append("legacy refund table has no recognized species ids")
	for raw_id: Variant in species_ownership_refunds:
		var id := StringName(raw_id)
		if id == &"" or SpeciesTable.by_id(id) == null \
				or int(species_ownership_refunds[raw_id]) < 0:
			errors.append("legacy species refund row is invalid:%s" % id)
	if legacy_skill_rank_contracts.is_empty():
		errors.append("legacy refund table has no recognized skill rank contracts")
	for raw_id: Variant in legacy_skill_rank_contracts:
		var id := StringName(raw_id)
		var raw_contract: Variant = legacy_skill_rank_contracts[raw_id]
		if id == &"" or not (raw_contract is Vector2i):
			errors.append("legacy skill rank contract is invalid:%s" % id)
			continue
		var contract := raw_contract as Vector2i
		if contract.x <= 0 or contract.y <= 0:
			errors.append("legacy skill rank contract has an invalid cap or cost:%s" % id)
	if legacy_v1_skill_aliases.is_empty() or legacy_v1_skill_rank_contracts.is_empty():
		errors.append("legacy v1 skill alias or rank-cost table is empty")
	for raw_source: Variant in legacy_v1_skill_aliases:
		var source_id := StringName(raw_source)
		var target_id := StringName(legacy_v1_skill_aliases[raw_source])
		if source_id == &"" or not legacy_v1_skill_rank_contracts.has(target_id):
			errors.append("legacy v1 skill alias is invalid:%s" % source_id)
	for raw_id: Variant in legacy_v1_skill_rank_contracts:
		var id := StringName(raw_id)
		var raw_contract: Variant = legacy_v1_skill_rank_contracts[raw_id]
		if id == &"" or not (raw_contract is Vector2i):
			errors.append("legacy v1 skill rank contract is invalid:%s" % id)
			continue
		var contract := raw_contract as Vector2i
		if contract.x <= 0 or contract.y <= 0:
			errors.append("legacy v1 skill rank contract has an invalid cap or cost:%s" % id)
	if legacy_alien_destination_ids.is_empty() \
			or legacy_mastered_destination_state <= 0 \
			or legacy_alien_mastery_skill_points <= 0:
		errors.append("legacy pre-v17 alien mastery entitlement table is invalid")
	var destination_ids: Dictionary = {}
	for raw_id: String in legacy_alien_destination_ids:
		var id := StringName(raw_id)
		if id == &"" or destination_ids.has(id):
			errors.append("legacy alien destination id is empty or duplicated")
		destination_ids[id] = true
	if legacy_lifetime_cash_upgrade_floors.is_empty() \
			or legacy_timber_depot_lifetime_floor <= 0 \
			or legacy_continental_lifetime_floor <= 0 \
			or legacy_planetary_lifetime_floor <= 0 \
			or legacy_first_alien_line_lifetime_floor <= 0 \
			or legacy_second_alien_line_lifetime_floor <= 0 \
			or legacy_third_alien_line_lifetime_floor <= 0 \
			or legacy_total_earth_trees <= 0 \
			or legacy_manual_logs_per_earth_tree <= 0 \
			or legacy_complete_earth_finale_state <= 0:
		errors.append("legacy pre-v15 Earth or lifetime-cash derivation is invalid")
	for raw_id: Variant in legacy_lifetime_cash_upgrade_floors:
		if StringName(raw_id) == &"" \
				or int(legacy_lifetime_cash_upgrade_floors[raw_id]) <= 0:
			errors.append("legacy lifetime-cash upgrade floor is invalid:%s" % raw_id)
	if legacy_xp_per_home_cash_unit <= 0 or home_cash_per_legacy_skill_point <= 0 \
			or exhausted_blueprint_home_cash <= 0:
		errors.append("legacy XP or exhausted-blueprint conversion is invalid")
	var seed_keys: Dictionary = {}
	for seed: LegacyCapabilitySeedDef in capability_seeds:
		if seed == null:
			errors.append("legacy capability seed table contains null")
			continue
		errors.append_array(seed.validate())
		var key := "%s:%s" % [seed.legacy_source_id, seed.target_meta_upgrade_id]
		if seed_keys.has(key):
			errors.append("legacy capability seed table contains a duplicate mapping")
		seed_keys[key] = true
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("legacy refund tuning must remain explicitly provisional")
	return errors


func _typed_non_negative_int(value: Variant) -> int:
	return clampi(int(value), 0, MAX_SAFE_REFUND) if value is int else 0


func _safe_add(a: int, b: int) -> int:
	a = clampi(a, 0, MAX_SAFE_REFUND)
	b = clampi(b, 0, MAX_SAFE_REFUND)
	return a + mini(b, MAX_SAFE_REFUND - a)
