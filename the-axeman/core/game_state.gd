extends Node
## Permanent survivors-style profile authority. Disposable attempt cash, XP,
## offers, powers, bosses, roots and presentation receipts belong to RunDirector.

signal home_cash_changed(new_total: int)
signal meta_upgrade_changed(id: StringName, rank: int, spent_total: int)
signal meta_upgrades_refunded(amount: int)
signal run_power_unlocked(id: StringName)
signal selected_yard_changed(id: StringName)
signal selected_frequency_tier_changed(tier: int)
signal yard_records_changed(yard_id: StringName)
signal run_banked(receipt: Dictionary)
signal migration_notice_changed
signal permanent_controls_lock_changed(locked: bool)
signal profile_changed

## Transitional repaint signals retained only until the home/stage presentation
## slice replaces the current survival HUD and equipment presenter.
signal building_tiers_changed
signal selected_species_changed(species_id: StringName)
signal species_purchased(species_id: StringName)
signal xp_changed(new_total: int)
signal level_gained(new_level: int)
signal skill_points_changed(available: int)
signal skill_level_changed(skill_id: StringName, new_level: int)
signal yard_pile_changed(new_total: int)
signal haul_aways_changed(new_total: int)
signal lifetime_wood_chopped_changed(new_total: int)
signal earth_clear_record_changed

const DEFAULT_TOOL_TIER := 1
const DEFAULT_BUILDING_TIER := 1
const DEFAULT_CASH := 0
const YARD_PILE_CAPACITY := 50
const TOTAL_EARTH_TREES := 3_040_000_000_000
const MAX_SAFE_ECONOMY_VALUE := 1_000_000_000_000_000_000
const DEFAULT_YARD_ID: StringName = &"yard_one"

## Legacy identifiers remain constants only so v18 migration and the temporary
## equipment presenter can recognise old ownership. They are not purchasable.
const UPGRADE_BALANCED_AXE := &"balanced_axe"
const UPGRADE_REINFORCED_BLOCK := &"reinforced_chopping_block"
const UPGRADE_SUPPLIER_LEDGER := &"supplier_ledger"
const UPGRADE_HANDCART := &"handcart"
const UPGRADE_COFFEE_THERMOS := &"coffee_thermos"
const UPGRADE_HARVEST_CAPACITY := &"harvest_capacity"
const XP_ORIGIN_MANUAL := &"manual"
const XP_ORIGIN_MANUAL_PROC := &"manual_proc"
const XP_ORIGIN_GRAIN := &"grain"

const META_AXE_POWER := &"axe_power"
const META_BLOCK_CONTROL := &"block_control"
const META_HOLD_TO_CHOP := &"hold_to_chop"
const META_CONTINUOUS_HANDOFF := &"continuous_handoff"
const META_FREQUENCY_CONTROL := &"fall_frequency_control"
const _LEGACY_AXE_IDS: Array[StringName] = [
	&"balanced_axe", &"tempered_woodsmans_axe", &"forged_splitting_maul",
	&"steel_cheek_axe", &"journeymans_bearded_axe", &"hardwood_pattern_axe",
	&"continental_mill_axe", &"earthmaster_axe",
]
const _LEGACY_BLOCK_IDS: Array[StringName] = [
	&"reinforced_chopping_block", &"iron_block_dogs", &"log_cradle",
	&"raised_split_stand", &"braced_yard_block", &"millhouse_chopping_block",
	&"continental_split_deck", &"earthmaster_ironwood_block",
]

var _home_cash := 0
var _meta_upgrade_ranks: Dictionary = {}
## Upgrade id -> Array[int], one exact amount actually paid for each owned rank.
var _meta_upgrade_spend_ledger: Dictionary = {}
var _unlocked_run_powers: Dictionary = {}
var _selected_yard: StringName = DEFAULT_YARD_ID
var _selected_frequency_tier := 0
## Run id -> true. Never truncate: this is the exact-once banking authority.
var _applied_run_settlements: Dictionary = {}
var _lifetime_stats: Dictionary = {}
var _yard_records: Dictionary = {}
var _yard_pile: Dictionary = {}
var _legacy_records: Dictionary = {}
var _migration_notice: Dictionary = {}
var _permanent_controls_locked := false
var _next_run_serial := 1


func _ready() -> void:
	if not SurvivorsContent.validate_all().is_empty():
		for error: String in SurvivorsContent.validate_all():
			push_error("Survivors content: " + error)


# ---------------------------------------------------------------- profile reset
func reset_to_defaults() -> void:
	_home_cash = 0
	_meta_upgrade_ranks.clear()
	_meta_upgrade_spend_ledger.clear()
	_unlocked_run_powers.clear()
	_unlock_all_core_powers(false)
	_selected_yard = DEFAULT_YARD_ID
	_selected_frequency_tier = 0
	_applied_run_settlements.clear()
	_lifetime_stats = _default_lifetime_stats()
	_yard_records.clear()
	_yard_pile.clear()
	_legacy_records.clear()
	_migration_notice.clear()
	_permanent_controls_locked = false
	_next_run_serial = 1
	_emit_full_refresh()


# --------------------------------------------------------- permanent controls
func set_permanent_controls_locked(locked: bool) -> void:
	if locked == _permanent_controls_locked:
		return
	_permanent_controls_locked = locked
	permanent_controls_lock_changed.emit(locked)


func are_permanent_controls_locked() -> bool:
	return _permanent_controls_locked


# ---------------------------------------------------------------- home cash
func get_home_cash() -> int:
	return _home_cash


## Run ids come from a persisted monotonic namespace. Even if a corrupt/stale
## serial is restored, already-settled ids are skipped before one is issued.
func issue_run_id() -> StringName:
	var serial := clampi(_next_run_serial, 1, MAX_SAFE_ECONOMY_VALUE)
	var id := StringName("run_v19_%d" % serial)
	while has_banked_run(id) and serial < MAX_SAFE_ECONOMY_VALUE:
		serial += 1
		id = StringName("run_v19_%d" % serial)
	if has_banked_run(id):
		return &""
	_next_run_serial = mini(MAX_SAFE_ECONOMY_VALUE, serial + 1)
	profile_changed.emit()
	return id


func can_purchase_meta_upgrade(id: StringName) -> bool:
	if _permanent_controls_locked or not SurvivorsContent.validate_all().is_empty():
		return false
	var definition := _meta_definition(id)
	if definition == null:
		return false
	var rank := get_meta_upgrade_rank(id)
	if definition.is_maxed(rank):
		return false
	if definition.prerequisite_upgrade_id != &"" \
			and get_meta_upgrade_rank(definition.prerequisite_upgrade_id) \
			< definition.prerequisite_rank:
		return false
	var cost := definition.cost_for_rank(rank + 1)
	return cost > 0 and _home_cash >= cost


func purchase_meta_upgrade(id: StringName) -> bool:
	if not can_purchase_meta_upgrade(id):
		return false
	var definition := _meta_definition(id)
	var previous_rank := get_meta_upgrade_rank(id)
	var cost := definition.cost_for_rank(previous_rank + 1)
	## All eligibility and arithmetic are checked before any field moves.
	if cost <= 0 or cost > _home_cash:
		return false
	var ledger: Array[int] = _ledger_for(id)
	if ledger.size() != previous_rank:
		return false
	ledger.append(cost)
	_home_cash -= cost
	_meta_upgrade_ranks[id] = previous_rank + 1
	_meta_upgrade_spend_ledger[id] = ledger
	home_cash_changed.emit(_home_cash)
	meta_upgrade_changed.emit(id, previous_rank + 1, _ledger_total(ledger))
	building_tiers_changed.emit()
	profile_changed.emit()
	return true


func refund_all_meta_upgrades() -> int:
	if _permanent_controls_locked or not SurvivorsContent.validate_all().is_empty():
		return 0
	var refund := 0
	for raw_ledger: Variant in _meta_upgrade_spend_ledger.values():
		if not (raw_ledger is Array):
			return 0
		for raw_amount: Variant in raw_ledger:
			var amount := int(raw_amount)
			if amount < 0 or refund > MAX_SAFE_ECONOMY_VALUE - amount:
				return 0
			refund += amount
	if refund > MAX_SAFE_ECONOMY_VALUE - _home_cash:
		return 0
	var previous_ids := _meta_upgrade_ranks.keys()
	_home_cash += refund
	_meta_upgrade_ranks.clear()
	_meta_upgrade_spend_ledger.clear()
	var old_tier := _selected_frequency_tier
	_selected_frequency_tier = 0
	home_cash_changed.emit(_home_cash)
	for raw_id: Variant in previous_ids:
		meta_upgrade_changed.emit(StringName(raw_id), 0, 0)
	meta_upgrades_refunded.emit(refund)
	if old_tier != 0:
		selected_frequency_tier_changed.emit(0)
	building_tiers_changed.emit()
	profile_changed.emit()
	return refund


func get_meta_upgrade_rank(id: StringName) -> int:
	var definition := _meta_definition(id)
	if definition == null:
		return 0
	return clampi(int(_meta_upgrade_ranks.get(id, 0)), 0, definition.max_rank)


func get_meta_upgrade_spend(id: StringName) -> int:
	return _ledger_total(_ledger_for(id))


func get_meta_upgrade_ranks() -> Dictionary:
	return _string_keyed(_meta_upgrade_ranks)


func get_meta_upgrade_spend_ledger() -> Dictionary:
	var out: Dictionary = {}
	for raw_id: Variant in _meta_upgrade_spend_ledger:
		out[String(raw_id)] = (_meta_upgrade_spend_ledger[raw_id] as Array).duplicate()
	return out


func get_meta_effect(kind: ProgressionEffectDef.Kind) -> float:
	var value := 0.0
	var multiply_value := 1.0
	var found_multiply := false
	var table := SurvivorsContent.meta_upgrades()
	if table == null:
		return value
	for definition: MetaUpgradeDef in table.upgrades:
		if definition == null:
			continue
		var rank := get_meta_upgrade_rank(definition.id)
		if rank <= 0:
			continue
		for effect: ProgressionEffectDef in definition.effects:
			if effect == null or effect.kind != kind:
				continue
			var authored := effect.value_at_rank(rank)
			match effect.operation:
				ProgressionEffectDef.Operation.ADD:
					value += authored
				ProgressionEffectDef.Operation.MULTIPLY:
					multiply_value *= authored
					found_multiply = true
				ProgressionEffectDef.Operation.ENABLE:
					value = maxf(value, authored)
				ProgressionEffectDef.Operation.SET:
					value = authored
	return multiply_value if found_multiply else value


func has_meta_capability(capability: MetaUpgradeDef.Capability) -> bool:
	var table := SurvivorsContent.meta_upgrades()
	if table == null:
		return false
	for definition: MetaUpgradeDef in table.upgrades:
		if definition != null and definition.granted_capability == capability \
				and get_meta_upgrade_rank(definition.id) > 0:
			return true
	return false


# ------------------------------------------------------------ run power book
func get_unlocked_run_powers() -> Array[StringName]:
	var out: Array[StringName] = []
	for raw_id: Variant in _unlocked_run_powers:
		if bool(_unlocked_run_powers[raw_id]):
			out.append(StringName(raw_id))
	out.sort()
	return out


func is_run_power_unlocked(id: StringName) -> bool:
	return _power_definition(id) != null and bool(_unlocked_run_powers.get(id, false))


func unlock_run_power(id: StringName) -> bool:
	if _permanent_controls_locked or not SurvivorsContent.validate_all().is_empty() \
			or _power_definition(id) == null \
			or is_run_power_unlocked(id):
		return false
	_unlocked_run_powers[id] = true
	run_power_unlocked.emit(id)
	profile_changed.emit()
	return true


# -------------------------------------------------------------- yard choice
func get_selected_yard() -> StringName:
	return _selected_yard if _yard_definition(_selected_yard) != null else DEFAULT_YARD_ID


func select_yard(id: StringName) -> bool:
	if _permanent_controls_locked or id == get_selected_yard() \
			or _yard_definition(id) == null or id != DEFAULT_YARD_ID:
		return false
	_selected_yard = id
	_selected_frequency_tier = mini(_selected_frequency_tier, get_max_frequency_tier())
	selected_yard_changed.emit(id)
	profile_changed.emit()
	return true


func get_selected_frequency_tier() -> int:
	return clampi(_selected_frequency_tier, 0, get_max_frequency_tier())


func get_max_frequency_tier() -> int:
	var yard := _yard_definition(get_selected_yard())
	var yard_max := 0 if yard == null else maxi(0, yard.starting_delivery_intervals.size() - 1)
	return mini(get_meta_upgrade_rank(META_FREQUENCY_CONTROL), yard_max)


func select_frequency_tier(tier: int) -> bool:
	if _permanent_controls_locked or tier < 0 or tier > get_max_frequency_tier() \
			or tier == get_selected_frequency_tier():
		return false
	_selected_frequency_tier = tier
	selected_frequency_tier_changed.emit(tier)
	profile_changed.emit()
	return true


# -------------------------------------------------------------- run banking
func has_banked_run(run_id: StringName) -> bool:
	return run_id != &"" and bool(_applied_run_settlements.get(run_id, false))


func bank_run(settlement: Dictionary) -> Dictionary:
	if not SurvivorsContent.validate_all().is_empty() \
			or not _is_valid_bank_settlement(settlement):
		return {}
	var run_id := StringName(settlement.get("run_id", ""))
	var session_cash := int(settlement.get("session_cash", 0))
	if run_id == &"" or session_cash < 0 or session_cash > MAX_SAFE_ECONOMY_VALUE \
			or has_banked_run(run_id):
		return {}

	var next_powers := _unlocked_run_powers.duplicate()
	var unlocked: Array[StringName] = []
	var conversion_cash := 0
	var blueprint_rolls := _blueprint_rolls_from(settlement, run_id)
	for roll: int in blueprint_rolls:
		var remaining := _locked_blueprint_ids(next_powers)
		if remaining.is_empty():
			var conversion := _blueprint_conversion_cash()
			if conversion < 0 or conversion_cash > MAX_SAFE_ECONOMY_VALUE - conversion:
				return {}
			conversion_cash += conversion
			continue
		var unlocked_id: StringName = remaining[posmod(roll, remaining.size())]
		next_powers[unlocked_id] = true
		unlocked.append(unlocked_id)

	var requested_total := session_cash
	if requested_total > MAX_SAFE_ECONOMY_VALUE - conversion_cash:
		return {}
	requested_total += conversion_cash
	## A settlement is all-or-nothing. Silently clipping a purse would still mark
	## its run id as consumed and make the rejected remainder unrecoverable.
	if requested_total > MAX_SAFE_ECONOMY_VALUE - _home_cash:
		return {}
	var accepted := requested_total
	var yard_id := StringName(settlement.get("yard_id", get_selected_yard()))
	if _yard_definition(yard_id) == null:
		return {}
	var next_record := _updated_yard_record(yard_id, settlement, session_cash)
	var next_stats := _lifetime_stats.duplicate(true)
	next_stats["cash_earned"] = _safe_counter_add(
		int(next_stats.get("cash_earned", 0)), accepted)
	next_stats["runs_settled"] = _safe_counter_add(
		int(next_stats.get("runs_settled", 0)), 1)
	next_stats["bosses_defeated"] = _safe_counter_add(
		int(next_stats.get("bosses_defeated", 0)),
		blueprint_rolls.size())

	## Commit only after every derived value has validated.
	_home_cash += accepted
	_unlocked_run_powers = next_powers
	_yard_records[yard_id] = next_record
	_lifetime_stats = next_stats
	_applied_run_settlements[run_id] = true
	var receipt := {
		"receipt_id": "bank::%s" % run_id,
		"run_id": String(run_id),
		"yard_id": String(yard_id),
		"session_cash": session_cash,
		"blueprint_conversion_cash": conversion_cash,
		"cash_banked": accepted,
		"unlocked_power_ids": _string_array(unlocked),
	}
	home_cash_changed.emit(_home_cash)
	for id: StringName in unlocked:
		run_power_unlocked.emit(id)
	yard_records_changed.emit(yard_id)
	run_banked.emit(receipt.duplicate(true))
	profile_changed.emit()
	return receipt


# ------------------------------------------------------------ records/stats
func get_lifetime_stats() -> Dictionary:
	return _lifetime_stats.duplicate(true)


func get_yard_record(yard_id: StringName) -> Dictionary:
	var raw: Variant = _yard_records.get(yard_id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary \
		else _default_yard_record()


func get_yard_records() -> Dictionary:
	return _yard_records.duplicate(true)


func get_legacy_records() -> Dictionary:
	return _legacy_records.duplicate(true)


func get_migration_notice() -> Dictionary:
	return _migration_notice.duplicate(true)


func acknowledge_migration_notice(id: StringName) -> bool:
	if id == &"" or _migration_notice.is_empty() \
			or StringName(_migration_notice.get("id", "")) != id:
		return false
	_migration_notice.clear()
	migration_notice_changed.emit()
	profile_changed.emit()
	return true


# -------------------------------------------------------- temporary yard pile
func add_to_yard_pile(item_id: StringName, count: int) -> void:
	if item_id == &"" or count <= 0:
		return
	_yard_pile[item_id] = _safe_counter_add(int(_yard_pile.get(item_id, 0)), count)
	yard_pile_changed.emit(get_yard_pile_count())
	profile_changed.emit()


func get_yard_pile() -> Dictionary:
	return _yard_pile.duplicate()


func get_yard_pile_count() -> int:
	var total := 0
	for amount: Variant in _yard_pile.values():
		total = _safe_counter_add(total, maxi(0, int(amount)))
	return total


func get_yard_pile_capacity() -> int:
	return YARD_PILE_CAPACITY


func clear_yard_pile() -> void:
	_yard_pile.clear()
	yard_pile_changed.emit(0)
	profile_changed.emit()


func record_haul_away() -> void:
	_lifetime_stats["haul_aways_completed"] = _safe_counter_add(
		int(_lifetime_stats.get("haul_aways_completed", 0)), 1)
	haul_aways_changed.emit(get_haul_aways_completed())
	profile_changed.emit()


func get_haul_aways_completed() -> int:
	return maxi(0, int(_lifetime_stats.get("haul_aways_completed", 0)))


func record_manual_completion() -> void:
	_lifetime_stats["roots_completed"] = _safe_counter_add(
		int(_lifetime_stats.get("roots_completed", 0)), 1)
	lifetime_wood_chopped_changed.emit(get_lifetime_wood_chopped())
	profile_changed.emit()


func get_lifetime_wood_chopped() -> int:
	return maxi(0, int(_lifetime_stats.get("roots_completed", 0)))


# ----------------------------------------------------- transitional read seams
## These reads keep the block and current smoke scene alive during gate one.
## No retired XP, skill, species or shop method below can mutate the profile.
func get_tool_tier(tool_type: Enums.ToolType) -> int:
	return DEFAULT_TOOL_TIER + get_meta_upgrade_rank(META_AXE_POWER) \
		if tool_type == Enums.ToolType.AXE else DEFAULT_TOOL_TIER


func get_building_tier(id: StringName) -> int:
	return DEFAULT_BUILDING_TIER + get_permanent_upgrade_level(id)


func get_permanent_upgrade_level(id: StringName) -> int:
	var axe_index := _LEGACY_AXE_IDS.find(id)
	if axe_index >= 0:
		return 1 if get_meta_upgrade_rank(META_AXE_POWER) > axe_index else 0
	var block_index := _LEGACY_BLOCK_IDS.find(id)
	if block_index >= 0:
		return 1 if get_meta_upgrade_rank(META_BLOCK_CONTROL) > block_index else 0
	return 0


func set_permanent_upgrade_level(_id: StringName, _new_level: int) -> bool:
	return false


func get_permanent_upgrades() -> Dictionary:
	return get_meta_upgrade_ranks()


func owns_species(species_id: StringName) -> bool:
	return species_id in get_owned_species()


func get_owned_species() -> Array[StringName]:
	var out: Array[StringName] = []
	var yard := _yard_definition(get_selected_yard())
	if yard != null:
		for entry: YardTimelineEntryDef in yard.species_timeline:
			if entry != null and entry.species_id not in out:
				out.append(entry.species_id)
	return out


func get_selected_species() -> StringName:
	var species := get_owned_species()
	return SpeciesTable.starting_species().id if species.is_empty() else species[0]


func select_species(_species_id: StringName) -> bool:
	return false


func can_species_be_bought(_species_id: StringName) -> bool:
	return false


func unlock_species_after_payment(_species_id: StringName) -> bool:
	return false


func get_xp() -> int:
	return 0


func get_level() -> int:
	return 1


func get_level_for_xp(_value: int) -> int:
	return 1


func get_xp_to_next_level() -> int:
	return 0


func get_level_progress() -> float:
	return 0.0


func award_xp(_amount: int, _origin: StringName = XP_ORIGIN_MANUAL) -> int:
	return 0


func add_xp(_amount: int) -> void:
	pass


func get_skill_level(_skill_id: StringName) -> int:
	return 0


func get_skill_points_earned() -> int:
	return 0


func get_skill_points_spent() -> int:
	return 0


func get_skill_points_available() -> int:
	return 0


func can_afford_skill_points(_cost: int) -> bool:
	return false


func set_skill_level(_skill_id: StringName, _new_level: int) -> bool:
	return false


func get_skill_levels() -> Dictionary:
	return {}


func get_proc_dry_streak(_proc_id: StringName) -> int:
	return 0


func note_proc_result(_proc_id: StringName, _fired: bool) -> void:
	pass


func has_cleared_earth() -> bool:
	return int(get_yard_record(DEFAULT_YARD_ID).get("clears", 0)) > 0


func is_earth_master() -> bool:
	return has_cleared_earth()


func get_run_records() -> Dictionary:
	var record := get_yard_record(DEFAULT_YARD_ID)
	return {
		"earth_cleared": int(record.get("clears", 0)) > 0,
		"best_earth_clear_ms": int(record.get("best_clear_ms", -1)),
		"best_total_run_ms": int(record.get("longest_endless_ms", -1)),
		"best_overflow_ms": int(record.get("longest_endless_ms", -1)),
	}


# ---------------------------------------------------------------- persistence
func to_save_dict() -> Dictionary:
	return {
		"home_cash": _home_cash,
		"meta_upgrade_ranks": _string_keyed(_meta_upgrade_ranks),
		"meta_upgrade_spend_ledger": get_meta_upgrade_spend_ledger(),
		"unlocked_run_powers": _string_array(get_unlocked_run_powers()),
		"selected_yard": String(get_selected_yard()),
		"selected_frequency_tier": get_selected_frequency_tier(),
		"applied_run_settlements": _string_array(_settled_run_ids()),
		"lifetime_stats": _lifetime_stats.duplicate(true),
		"yard_records": _string_keyed_deep(_yard_records),
		"yard_pile": _string_keyed(_yard_pile),
		"legacy_records": _legacy_records.duplicate(true),
		"migration_notice": _migration_notice.duplicate(true),
		"next_run_serial": _next_run_serial,
	}


func apply_save_dict(data: Dictionary) -> void:
	_home_cash = clampi(int(data.get("home_cash", 0)), 0, MAX_SAFE_ECONOMY_VALUE)
	_meta_upgrade_ranks.clear()
	var saved_ranks: Variant = data.get("meta_upgrade_ranks", {})
	if saved_ranks is Dictionary:
		for raw_id: Variant in saved_ranks:
			if not (raw_id is String or raw_id is StringName) \
					or not (saved_ranks[raw_id] is int):
				continue
			var id := StringName(raw_id)
			var definition := _meta_definition(id)
			if definition == null:
				continue
			var rank := clampi(int(saved_ranks[raw_id]), 0, definition.max_rank)
			if rank > 0:
				_meta_upgrade_ranks[id] = rank
	_sanitise_meta_prerequisites()

	_meta_upgrade_spend_ledger.clear()
	var saved_ledger: Variant = data.get("meta_upgrade_spend_ledger", {})
	var remaining_refund_room := MAX_SAFE_ECONOMY_VALUE - _home_cash
	var meta_table := SurvivorsContent.meta_upgrades()
	var definitions: Array[MetaUpgradeDef] = [] if meta_table == null \
		else meta_table.upgrades
	for definition: MetaUpgradeDef in definitions:
		if definition == null or not _meta_upgrade_ranks.has(definition.id):
			continue
		var id := definition.id
		var rank := int(_meta_upgrade_ranks[id])
		var ledger: Array[int] = []
		var raw_values: Variant = (saved_ledger as Dictionary).get(String(id), []) \
			if saved_ledger is Dictionary else []
		if raw_values is Array:
			for index: int in range(mini(rank, raw_values.size())):
				var raw_amount: Variant = raw_values[index]
				var amount := int(raw_amount) if raw_amount is int else -1
				if amount < 0 or amount > remaining_refund_room:
					ledger.append(0)
				else:
					ledger.append(amount)
					remaining_refund_room -= amount
		while ledger.size() < rank:
			ledger.append(0)
		_meta_upgrade_spend_ledger[id] = ledger

	_unlocked_run_powers.clear()
	var saved_powers: Variant = data.get("unlocked_run_powers", [])
	if saved_powers is Array:
		for raw_id: Variant in saved_powers:
			if not (raw_id is String or raw_id is StringName):
				continue
			var id := StringName(raw_id)
			if _power_definition(id) != null:
				_unlocked_run_powers[id] = true
	_unlock_all_core_powers(false)

	var raw_saved_yard: Variant = data.get("selected_yard", String(DEFAULT_YARD_ID))
	var saved_yard := StringName(raw_saved_yard) \
		if raw_saved_yard is String or raw_saved_yard is StringName \
		else DEFAULT_YARD_ID
	_selected_yard = saved_yard if _yard_definition(saved_yard) != null \
		else DEFAULT_YARD_ID
	var saved_frequency: Variant = data.get("selected_frequency_tier", 0)
	_selected_frequency_tier = clampi(int(saved_frequency), 0,
		get_max_frequency_tier()) if saved_frequency is int else 0

	_applied_run_settlements.clear()
	var settled: Variant = data.get("applied_run_settlements", [])
	if settled is Array:
		for raw_id: Variant in settled:
			if not (raw_id is String or raw_id is StringName):
				continue
			var id := StringName(raw_id)
			if id != &"":
				_applied_run_settlements[id] = true
	elif settled is Dictionary:
		for raw_id: Variant in settled:
			if not (raw_id is String or raw_id is StringName) \
					or not (settled[raw_id] is bool):
				continue
			var id := StringName(raw_id)
			if id != &"" and bool(settled[raw_id]):
				_applied_run_settlements[id] = true

	_lifetime_stats = _sanitise_lifetime_stats(data.get("lifetime_stats", {}))
	_yard_records = _sanitise_yard_records(data.get("yard_records", {}))
	_yard_pile = _registered_inventory_dictionary(data.get("yard_pile", {}))
	_legacy_records = (data.get("legacy_records", {}) as Dictionary).duplicate(true) \
		if data.get("legacy_records", {}) is Dictionary else {}
	_migration_notice = (data.get("migration_notice", {}) as Dictionary).duplicate(true) \
		if data.get("migration_notice", {}) is Dictionary else {}
	_next_run_serial = clampi(int(data.get("next_run_serial", 1)), 1,
		MAX_SAFE_ECONOMY_VALUE)
	_permanent_controls_locked = false
	_emit_full_refresh()


# ---------------------------------------------------------------- internals
func _meta_definition(id: StringName) -> MetaUpgradeDef:
	var table := SurvivorsContent.meta_upgrades()
	return null if table == null else table.by_id(id)


func _power_definition(id: StringName) -> RunPowerDef:
	var table := SurvivorsContent.run_powers()
	return null if table == null else table.by_id(id)


func _yard_definition(id: StringName) -> YardDef:
	var table := SurvivorsContent.yards()
	return null if table == null else table.by_id(id)


func _sanitise_meta_prerequisites() -> void:
	var table := SurvivorsContent.meta_upgrades()
	if table == null:
		_meta_upgrade_ranks.clear()
		return
	## Iterate to a fixed point so future catalogue chains cannot retain a child
	## whose own prerequisite was removed later in the same sanitation pass.
	var changed := true
	while changed:
		changed = false
		for definition: MetaUpgradeDef in table.upgrades:
			if definition == null or definition.prerequisite_upgrade_id == &"" \
					or not _meta_upgrade_ranks.has(definition.id):
				continue
			if int(_meta_upgrade_ranks.get(
					definition.prerequisite_upgrade_id, 0)) < definition.prerequisite_rank:
				_meta_upgrade_ranks.erase(definition.id)
				changed = true


func _unlock_all_core_powers(emit_signals: bool) -> void:
	var table := SurvivorsContent.run_powers()
	if table == null:
		return
	for power: RunPowerDef in table.powers:
		if power == null or power.pool != RunPowerDef.Pool.CORE:
			continue
		var newly_unlocked := not bool(_unlocked_run_powers.get(power.id, false))
		_unlocked_run_powers[power.id] = true
		if newly_unlocked and emit_signals:
			run_power_unlocked.emit(power.id)


func _ledger_for(id: StringName) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = _meta_upgrade_spend_ledger.get(id, [])
	if raw is Array:
		for amount: Variant in raw:
			out.append(maxi(0, int(amount)))
	return out


func _ledger_total(ledger: Array[int]) -> int:
	var total := 0
	for amount: int in ledger:
		if amount < 0 or total > MAX_SAFE_ECONOMY_VALUE - amount:
			return MAX_SAFE_ECONOMY_VALUE
		total += amount
	return total


func _blueprint_rolls_from(settlement: Dictionary, run_id: StringName) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = settlement.get("pending_blueprint_rolls", [])
	if raw is Array:
		for value: Variant in raw:
			if out.size() >= 3:
				break
			if value is Dictionary:
				out.append(int((value as Dictionary).get("roll", 0)))
			else:
				out.append(int(value))
	if out.is_empty():
		var count := clampi(int(settlement.get("pending_blueprints", 0)), 0, 3)
		for index: int in range(count):
			out.append(hash("%s::blueprint::%d" % [run_id, index]))
	return out


func _locked_blueprint_ids(ownership: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var table := SurvivorsContent.run_powers()
	if table == null:
		return out
	for power: RunPowerDef in table.powers:
		if power != null and power.pool == RunPowerDef.Pool.BLUEPRINT \
				and not bool(ownership.get(power.id, false)):
			out.append(power.id)
	out.sort()
	return out


func _blueprint_conversion_cash() -> int:
	var table := SurvivorsContent.legacy_refunds()
	if table == null or not table.validate().is_empty():
		return -1
	return table.exhausted_blueprint_home_cash


func _updated_yard_record(yard_id: StringName, settlement: Dictionary,
		session_cash: int) -> Dictionary:
	var record := get_yard_record(yard_id)
	record["attempts"] = _safe_counter_add(int(record.get("attempts", 0)), 1)
	var cleared := bool(settlement.get("cleared", false))
	if cleared:
		record["clears"] = _safe_counter_add(int(record.get("clears", 0)), 1)
	var clear_ms := int(settlement.get("clear_ms", -1))
	if cleared and clear_ms >= 0:
		var old_best := int(record.get("best_clear_ms", -1))
		record["best_clear_ms"] = clear_ms if old_best < 0 else mini(old_best, clear_ms)
	var endless_ms := int(settlement.get("endless_ms", -1))
	if endless_ms >= 0:
		record["longest_endless_ms"] = maxi(
			int(record.get("longest_endless_ms", -1)), endless_ms)
	record["highest_level"] = maxi(int(record.get("highest_level", 1)),
		maxi(1, int(settlement.get("level", 1))))
	record["best_session_cash"] = maxi(int(record.get("best_session_cash", 0)),
		session_cash)
	return record


func _default_lifetime_stats() -> Dictionary:
	return {
		"roots_completed": 0,
		"cash_earned": 0,
		"runs_settled": 0,
		"bosses_defeated": 0,
		"haul_aways_completed": 0,
	}


func _default_yard_record() -> Dictionary:
	return {
		"attempts": 0,
		"clears": 0,
		"best_clear_ms": -1,
		"longest_endless_ms": -1,
		"highest_level": 1,
		"best_session_cash": 0,
	}


func _sanitise_lifetime_stats(value: Variant) -> Dictionary:
	var out := _default_lifetime_stats()
	if value is Dictionary:
		for key: String in out.keys():
			var raw: Variant = (value as Dictionary).get(key, out[key])
			if raw is int:
				out[key] = clampi(int(raw), 0, MAX_SAFE_ECONOMY_VALUE)
	return out


func _sanitise_yard_records(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	for raw_id: Variant in value:
		var id := StringName(raw_id)
		var raw: Variant = value[raw_id]
		if _yard_definition(id) == null or not (raw is Dictionary):
			continue
		var record := _default_yard_record()
		for key: String in ["attempts", "clears", "best_session_cash"]:
			var raw_value: Variant = (raw as Dictionary).get(key, record[key])
			if raw_value is int:
				record[key] = clampi(int(raw_value), 0, MAX_SAFE_ECONOMY_VALUE)
		var raw_level: Variant = (raw as Dictionary).get("highest_level", 1)
		if raw_level is int:
			record["highest_level"] = maxi(1, int(raw_level))
		for key: String in ["best_clear_ms", "longest_endless_ms"]:
			var raw_time: Variant = (raw as Dictionary).get(key, -1)
			if raw_time is int:
				record[key] = maxi(-1, int(raw_time))
		out[id] = record
	return out


func _positive_dictionary(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if value is Dictionary:
		for raw_id: Variant in value:
			if not (raw_id is String or raw_id is StringName) \
					or not (value[raw_id] is int):
				continue
			var amount := clampi(int(value[raw_id]), 0, MAX_SAFE_ECONOMY_VALUE)
			if amount > 0:
				out[StringName(raw_id)] = amount
	return out


func _registered_inventory_dictionary(value: Variant) -> Dictionary:
	var out := _positive_dictionary(value)
	for raw_id: Variant in out.keys():
		if not InventoryManager.is_valid_id(StringName(raw_id)):
			out.erase(raw_id)
	return out


func _safe_counter_add(current: int, amount: int) -> int:
	if amount <= 0:
		return clampi(current, 0, MAX_SAFE_ECONOMY_VALUE)
	return mini(MAX_SAFE_ECONOMY_VALUE, maxi(0, current) + mini(
		amount, MAX_SAFE_ECONOMY_VALUE - maxi(0, current)))


func _is_valid_bank_settlement(settlement: Dictionary) -> bool:
	if not settlement.has("run_id") \
			or not (settlement.run_id is String or settlement.run_id is StringName) \
			or not settlement.has("session_cash") or not (settlement.session_cash is int):
		return false
	if settlement.has("yard_id") \
			and not (settlement.yard_id is String or settlement.yard_id is StringName):
		return false
	for key: String in ["pending_blueprints", "bosses_defeated", "clear_ms",
			"endless_ms", "level", "stage_ms"]:
		if settlement.has(key) and not (settlement[key] is int):
			return false
	if settlement.has("cleared") and not (settlement.cleared is bool):
		return false
	if settlement.has("pending_blueprint_rolls"):
		if not (settlement.pending_blueprint_rolls is Array):
			return false
		for raw_roll: Variant in settlement.pending_blueprint_rolls:
			if raw_roll is int:
				continue
			if not (raw_roll is Dictionary) or not raw_roll.has("roll") \
					or not (raw_roll.roll is int):
				return false
	return true


func _settled_run_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for raw_id: Variant in _applied_run_settlements:
		if bool(_applied_run_settlements[raw_id]):
			out.append(StringName(raw_id))
	out.sort()
	return out


func _string_keyed(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key: Variant in source:
		out[String(raw_key)] = source[raw_key]
	return out


func _string_keyed_deep(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key: Variant in source:
		var value: Variant = source[raw_key]
		out[String(raw_key)] = value.duplicate(true) if value is Dictionary else value
	return out


func _string_array(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(String(value))
	return out


func _emit_full_refresh() -> void:
	home_cash_changed.emit(_home_cash)
	building_tiers_changed.emit()
	selected_yard_changed.emit(get_selected_yard())
	selected_species_changed.emit(get_selected_species())
	selected_frequency_tier_changed.emit(get_selected_frequency_tier())
	xp_changed.emit(0)
	skill_points_changed.emit(0)
	yard_pile_changed.emit(get_yard_pile_count())
	haul_aways_changed.emit(get_haul_aways_completed())
	lifetime_wood_chopped_changed.emit(get_lifetime_wood_chopped())
	earth_clear_record_changed.emit()
	migration_notice_changed.emit()
	profile_changed.emit()
