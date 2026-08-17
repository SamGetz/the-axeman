extends Node
## Gated slice-one acceptance for immutable survivors catalogues, permanent
## profile transactions, exact-once banking, and typed root persistence.

const META_PATH := "res://data/meta_upgrade_catalogue_placeholder.tres"
const POWER_PATH := "res://data/run_power_catalogue_placeholder.tres"
const YARD_PATH := "res://data/yard_catalogue_placeholder.tres"
const V18_FIXTURE := "res://core/tests/fixtures/survivors_v18_structured.cfg"
const V17_FIXTURE := "res://core/tests/fixtures/survivors_v17_legacy.cfg"
const V17_WRONG_TYPES_FIXTURE := \
	"res://core/tests/fixtures/survivors_v17_wrong_types.cfg"
const V16_FIXTURE := "res://core/tests/fixtures/survivors_v16_alien_mastery.cfg"
const V14_FIXTURE := "res://core/tests/fixtures/survivors_v14_records.cfg"
const V1_FIXTURE := "res://core/tests/fixtures/survivors_v1_alias.cfg"

const META_CAPS := {
	&"axe_power": 8,
	&"swing_recovery": 8,
	&"ready_stance": 5,
	&"block_control": 8,
	&"scar_craft": 5,
	&"boss_handling": 5,
	&"run_xp": 5,
	&"session_cash": 5,
	&"luck": 5,
	&"boundary_radius": 5,
	&"boundary_grace": 5,
	&"blaster_duration": 5,
	&"off_block_cutting": 1,
	&"hold_to_chop": 1,
	&"continuous_handoff": 1,
	&"fall_frequency_control": 3,
	&"rerolls": 5,
	&"banishes": 5,
}

## [pool, rank cap]. Every eligible identity has the same offer chance; rolled
## upgrade quality is tested by the runtime suite.
const POWER_RULES := {
	&"deep_bite": [RunPowerDef.Pool.CORE, 8],
	&"quick_hands": [RunPowerDef.Pool.CORE, 8],
	&"scar_wisdom": [RunPowerDef.Pool.CORE, 5],
	&"double_chop": [RunPowerDef.Pool.CORE, 3],
	&"follow_up": [RunPowerDef.Pool.CORE, 5],
	&"splinter_volley": [RunPowerDef.Pool.CORE, 8],
	&"flying_wedge": [RunPowerDef.Pool.CORE, 8],
	&"yard_magnet": [RunPowerDef.Pool.CORE, 8],
	&"soft_landing": [RunPowerDef.Pool.CORE, 5],
	&"ring_reinforcement": [RunPowerDef.Pool.CORE, 5],
	&"quick_study": [RunPowerDef.Pool.CORE, 5],
	&"keen_appraisal": [RunPowerDef.Pool.CORE, 5],
	&"area_size": [RunPowerDef.Pool.CORE, 5],
	&"sawblade_halo": [RunPowerDef.Pool.CORE, 5],
	&"grain_reader": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"earthshaker": [RunPowerDef.Pool.BLUEPRINT, 3],
	&"powder_keg": [RunPowerDef.Pool.BLUEPRINT, 3],
	&"kindling_chain": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"whirling_axe": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"crosscut_sweep": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"maul_drop": [RunPowerDef.Pool.BLUEPRINT, 3],
	&"splitter_rig": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"cant_hook": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"stump_pulse": [RunPowerDef.Pool.BLUEPRINT, 5],
	&"last_ditch_rescue": [RunPowerDef.Pool.BLUEPRINT, 3],
	&"momentum": [RunPowerDef.Pool.BLUEPRINT, 8],
	&"timber_burst": [RunPowerDef.Pool.BLUEPRINT, 5],
}

const YARD_ONE_SPECIES: Array[StringName] = [
	&"quaking_aspen", &"eastern_white_pine", &"norway_spruce",
	&"balsam_fir", &"lodgepole_pine", &"white_spruce",
]

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("=== SURVIVORS PROGRESSION SLICE 1 ACCEPTANCE ===")
	_test_shipping_catalogues()
	_test_clean_profile()
	_test_atomic_meta_transactions()
	_test_exact_ledger_refund_and_tier_clamp()
	_test_exact_once_banking_and_blueprints()
	_test_malformed_profile_sanitisation()
	_test_typed_root_round_trip()
	_test_isolated_save_migrations()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("SURVIVORS SLICE 1: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_shipping_catalogues() -> void:
	var meta := load(META_PATH) as MetaUpgradeTable
	var powers := load(POWER_PATH) as RunPowerTable
	var yards := load(YARD_PATH) as YardTable
	_check(meta != null and meta.validate().is_empty(),
		"the permanent-upgrade catalogue validates")
	_check(powers != null and powers.validate().is_empty(),
		"the run-power catalogue validates")
	_check(yards != null and yards.validate().is_empty(),
		"the yard catalogue validates")
	if meta == null or powers == null or yards == null:
		return

	var meta_shape_ok := meta.upgrades.size() == META_CAPS.size()
	for raw_id: Variant in META_CAPS:
		var definition := meta.by_id(StringName(raw_id))
		meta_shape_ok = meta_shape_ok and definition != null
		if definition == null:
			continue
		var cap := int(META_CAPS[raw_id])
		meta_shape_ok = meta_shape_ok and definition.max_rank == cap \
			and definition.costs_by_rank.size() == cap \
			and definition.tuning_status.begins_with("PLACEHOLDER")
		for effect: ProgressionEffectDef in definition.effects:
			meta_shape_ok = meta_shape_ok and effect != null \
				and effect.cumulative_values_by_rank.size() == cap \
				and effect.tuning_status.begins_with("PLACEHOLDER")
	_check(meta_shape_ok,
		"all 18 visible meta lines have their locked caps and explicit placeholder ladders")
	var handoff := meta.by_id(&"continuous_handoff")
	_check(handoff != null and handoff.prerequisite_upgrade_id == &"hold_to_chop" \
		and handoff.prerequisite_rank == 1,
		"Continuous Handoff has the sole Hold-to-Chop prerequisite")

	var power_shape_ok := powers.powers.size() == POWER_RULES.size()
	var core_count := 0
	var blueprint_count := 0
	for raw_id: Variant in POWER_RULES:
		var definition := powers.by_id(StringName(raw_id))
		power_shape_ok = power_shape_ok and definition != null
		if definition == null:
			continue
		var rule: Array = POWER_RULES[raw_id]
		power_shape_ok = power_shape_ok and definition.pool == int(rule[0]) \
			and definition.rank_cap == int(rule[1]) \
			and definition.tuning_status.begins_with("PLACEHOLDER")
		for effect: ProgressionEffectDef in definition.effects:
			power_shape_ok = power_shape_ok and effect != null \
				and effect.cumulative_values_by_rank.size() == definition.rank_cap \
				and effect.tuning_status.begins_with("PLACEHOLDER")
		if definition.pool == RunPowerDef.Pool.CORE:
			core_count += 1
		elif definition.pool == RunPowerDef.Pool.BLUEPRINT:
			blueprint_count += 1
	_check(power_shape_ok and core_count == 14 and blueprint_count == 13 \
		and powers.powers.size() <= RunPowerTable.MAX_POWER_COUNT,
		"all 27 equally weighted identities retain pool/cap contracts below the 32-power ceiling")

	var yard := yards.by_id(&"yard_one")
	var timeline_ids: Array[StringName] = []
	if yard != null:
		for entry: YardTimelineEntryDef in yard.species_timeline:
			if entry != null:
				timeline_ids.append(entry.species_id)
	timeline_ids.sort()
	var expected_species := YARD_ONE_SPECIES.duplicate()
	expected_species.sort()
	_check(yards.yards.size() == 1 and yard != null \
		and yard.resource_path == "res://data/yards/yard_one_placeholder.tres" \
		and is_equal_approx(yard.stage_duration_seconds, 900.0) \
		and yard.delivery_tier_interval_scales.size() == 4 \
		and yard.delivery_interval_seconds_by_level != null \
		and yard.delivery_interval_seconds_by_level.point_count == 35 \
		and yard.delivery_batch_size_by_level != null \
		and yard.delivery_batch_size_by_level.point_count == 35 \
		and is_equal_approx(yard.delivery_interval_seconds(1, 0), 6.5 / 3.0) \
		and is_equal_approx(yard.delivery_interval_seconds(1, 1), 5.2 / 3.0) \
		and is_equal_approx(yard.delivery_interval_seconds(1, 2), 4.1 / 3.0) \
		and is_equal_approx(yard.delivery_interval_seconds(1, 3), 3.2 / 3.0) \
		and is_equal_approx(yard.delivery_interval_floor, 0.2) \
		and yard.force_curve_end_in_final_window \
		and is_equal_approx(yard.final_pressure_remaining_seconds, 60.0) \
		and yard.force_curve_end_in_endless \
		and is_equal_approx(yard.delivery_interval_seconds(2), 1.906667) \
		and is_equal_approx(yard.delivery_interval_seconds(10), 0.69333345) \
		and is_equal_approx(yard.delivery_interval_seconds(15), 0.3683334) \
		and is_equal_approx(yard.delivery_interval_seconds(20), 0.2) \
		and yard.delivery_batch_size(19) == 1 \
		and yard.delivery_batch_size(20) == 2 \
		and yard.delivery_batch_size(21) == 3 \
		and yard.delivery_batch_size(28) == 10 \
		and yard.bosses.size() == 3 and timeline_ids == expected_species,
		"yard one is a standalone level resource with editable interval/amount curves and ten-root final pressure")
	var reward_pairs: Array[Vector2i] = []
	for reward: YardSpeciesRewardDef in yard.species_rewards:
		reward_pairs.append(Vector2i(reward.cash_reward, reward.xp_reward))
	var boss_pairs: Array[Vector2i] = []
	for boss: YardBossDef in yard.bosses:
		boss_pairs.append(Vector2i(boss.cash_jackpot, boss.xp_jackpot))
	_check(reward_pairs == [Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 5),
		Vector2i(4, 6), Vector2i(6, 8), Vector2i(8, 9)] \
		and boss_pairs == [Vector2i(13, 38), Vector2i(25, 75),
			Vector2i(50, 150)],
		"ordinary and boss rewards are nearest-whole 25% Cash / 50% XP values")

	var duplicate_meta := MetaUpgradeTable.new()
	duplicate_meta.upgrades = [meta.upgrades[0], meta.upgrades[0]]
	var duplicate_power := RunPowerTable.new()
	duplicate_power.powers = [powers.powers[0], powers.powers[0]]
	_check(_contains_error(duplicate_meta.validate(), "duplicate meta upgrade id") \
		and _contains_error(duplicate_power.validate(), "duplicate run-power id"),
		"catalogue validators reject duplicate stable identities")
	var oversized_power_table := RunPowerTable.new()
	for _index: int in range(RunPowerTable.MAX_POWER_COUNT + 1):
		oversized_power_table.powers.append(powers.powers[0])
	_check(_contains_error(oversized_power_table.validate(),
		"between 1 and 32 powers"),
		"the run-power catalogue validator rejects a thirty-third identity")


func _test_clean_profile() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var powers := load(POWER_PATH) as RunPowerTable
	var owned := GameState.get_unlocked_run_powers()
	var core_owned := 0
	var blueprint_owned := 0
	for power: RunPowerDef in powers.powers:
		if GameState.is_run_power_unlocked(power.id):
			if power.pool == RunPowerDef.Pool.CORE:
				core_owned += 1
			else:
				blueprint_owned += 1
	_check(GameState.get_home_cash() == 0 \
		and GameState.get_meta_upgrade_ranks().is_empty() \
		and GameState.get_meta_upgrade_spend_ledger().is_empty(),
		"a clean profile starts with zero home cash, ranks, and spend ledger")
	_check(owned.size() == 14 and core_owned == 14 and blueprint_owned == 0,
		"a clean profile owns all fourteen Core powers and no Blueprint powers")
	_check(GameState.get_selected_yard() == &"yard_one" \
		and GameState.get_selected_frequency_tier() == 0 \
		and GameState.get_yard_records().is_empty() \
		and GameState.get_migration_notice().is_empty(),
		"a clean profile selects yard one/default frequency with no records or migration notice")

	var clean_save := GameState.to_save_dict()
	GameState.apply_save_dict(clean_save)
	_check(GameState.to_save_dict() == clean_save,
		"the clean v19 profile is shape-stable through an in-memory round trip")


func _test_atomic_meta_transactions() -> void:
	GameState.reset_to_defaults()
	var meta := load(META_PATH) as MetaUpgradeTable
	var before := GameState.to_save_dict()
	_check(not GameState.purchase_meta_upgrade(&"axe_power") \
		and not GameState.purchase_meta_upgrade(&"not_an_upgrade") \
		and GameState.to_save_dict() == before,
		"invalid and unaffordable purchases leave every profile field unchanged")

	var hold := meta.by_id(&"hold_to_chop")
	var handoff := meta.by_id(&"continuous_handoff")
	var funds := hold.cost_for_rank(1) + handoff.cost_for_rank(1)
	var bank := _bank_cash(&"meta_prerequisite_funds", funds)
	var funded_cash := GameState.get_home_cash()
	_check(not bank.is_empty() and not GameState.purchase_meta_upgrade(&"continuous_handoff") \
		and GameState.get_home_cash() == funded_cash \
		and GameState.get_meta_upgrade_rank(&"continuous_handoff") == 0,
		"Continuous Handoff rejects atomically until Hold-to-Chop is owned")
	_check(GameState.purchase_meta_upgrade(&"hold_to_chop") \
		and GameState.purchase_meta_upgrade(&"continuous_handoff") \
		and GameState.get_home_cash() == 0 \
		and GameState.get_meta_upgrade_spend(&"hold_to_chop") == hold.cost_for_rank(1) \
		and GameState.get_meta_upgrade_spend(&"continuous_handoff") == handoff.cost_for_rank(1),
		"prerequisite purchases debit cash, rank, and exact ledger together")

	GameState.reset_to_defaults()
	var off_block := meta.by_id(&"off_block_cutting")
	_bank_cash(&"single_rank_cap_funds", off_block.cost_for_rank(1))
	_check(GameState.purchase_meta_upgrade(&"off_block_cutting") \
		and not GameState.purchase_meta_upgrade(&"off_block_cutting") \
		and GameState.get_meta_upgrade_rank(&"off_block_cutting") == 1 \
		and GameState.get_home_cash() == 0,
		"a capped line cannot charge or advance beyond its authored maximum")

	GameState.reset_to_defaults()
	var axe := meta.by_id(&"axe_power")
	_bank_cash(&"signal_count_funds", axe.cost_for_rank(1))
	var cash_signal_count := [0]
	var meta_signal_count := [0]
	var profile_signal_count := [0]
	var on_cash := func(_total: int) -> void: cash_signal_count[0] += 1
	var on_meta := func(_id: StringName, _rank: int, _spent: int) -> void: \
		meta_signal_count[0] += 1
	var on_profile := func() -> void: profile_signal_count[0] += 1
	GameState.home_cash_changed.connect(on_cash)
	GameState.meta_upgrade_changed.connect(on_meta)
	GameState.profile_changed.connect(on_profile)
	_check(GameState.purchase_meta_upgrade(&"axe_power") \
		and not GameState.purchase_meta_upgrade(&"axe_power") \
		and int(cash_signal_count[0]) == 1 and int(meta_signal_count[0]) == 1 \
		and int(profile_signal_count[0]) == 1,
		"one committed purchase emits each dedicated transaction signal exactly once")
	GameState.home_cash_changed.disconnect(on_cash)
	GameState.meta_upgrade_changed.disconnect(on_meta)
	GameState.profile_changed.disconnect(on_profile)

	GameState.reset_to_defaults()
	_bank_cash(&"suspended_control_funds", axe.cost_for_rank(1))
	GameState.set_permanent_controls_locked(true)
	var locked_state := GameState.to_save_dict()
	_check(not GameState.purchase_meta_upgrade(&"axe_power") \
		and GameState.refund_all_meta_upgrades() == 0 \
		and not GameState.select_frequency_tier(0) \
		and not GameState.unlock_run_power(&"grain_reader") \
		and GameState.to_save_dict() == locked_state,
		"a suspended-attempt lock makes every permanent, unlock, and loadout control read-only")
	GameState.set_permanent_controls_locked(false)


func _test_exact_ledger_refund_and_tier_clamp() -> void:
	GameState.reset_to_defaults()
	_check(GameState.unlock_run_power(&"grain_reader"),
		"a valid Blueprint power can be permanently unlocked")
	_check(not GameState.bank_run({
		"run_id": "refund_record_seed",
		"yard_id": "yard_one",
		"session_cash": 0,
		"cleared": true,
		"clear_ms": 1000,
		"endless_ms": 1500,
	}).is_empty(),
		"record fixtures enter through the same exact-once settlement authority")
	var profile := GameState.to_save_dict()
	profile["home_cash"] = 23
	profile["meta_upgrade_ranks"] = {
		"hold_to_chop": 1,
		"continuous_handoff": 1,
		"fall_frequency_control": 3,
	}
	## Deliberately differs from current catalogue pricing. These are historical
	## amounts actually paid and therefore the sole refund authority.
	profile["meta_upgrade_spend_ledger"] = {
		"hold_to_chop": [17],
		"continuous_handoff": [19],
		"fall_frequency_control": [7, 11, 13],
	}
	profile["selected_frequency_tier"] = 3
	GameState.apply_save_dict(profile)
	var record_before := GameState.get_yard_record(&"yard_one")
	_check(GameState.get_selected_frequency_tier() == 3 \
		and GameState.get_meta_upgrade_spend(&"fall_frequency_control") == 31,
		"saved ranks restore their selected tier and exact historical spend")
	var refunded := GameState.refund_all_meta_upgrades()
	_check(refunded == 67 and GameState.get_home_cash() == 90 \
		and GameState.get_meta_upgrade_ranks().is_empty() \
		and GameState.get_meta_upgrade_spend_ledger().is_empty() \
		and GameState.get_selected_frequency_tier() == 0,
		"free full refund returns exact paid amounts and clamps frequency to default")
	_check(GameState.is_run_power_unlocked(&"grain_reader") \
		and GameState.get_yard_record(&"yard_one") == record_before,
		"refund leaves boss-unlocked powers and yard records intact")


func _test_exact_once_banking_and_blueprints() -> void:
	GameState.reset_to_defaults()
	var settlement := {
		"run_id": "bank_round_trip",
		"yard_id": "yard_one",
		"session_cash": 125,
		"pending_blueprint_rolls": [0, 0],
		"bosses_defeated": 2,
		"cleared": true,
		"stage_ms": 1_200_000,
	}
	var receipt := GameState.bank_run(settlement)
	var unlocked: Array = receipt.get("unlocked_power_ids", [])
	_check(not receipt.is_empty() and int(receipt.get("cash_banked", -1)) == 125 \
		and GameState.get_home_cash() == 125 \
		and unlocked.size() == 2 and unlocked[0] != unlocked[1],
		"one settlement banks its purse and resolves distinct Blueprint unlocks")
	var profile_after_bank := GameState.to_save_dict()
	_check(GameState.bank_run(settlement).is_empty() \
		and GameState.to_save_dict() == profile_after_bank,
		"the same run settlement cannot bank twice in one process")

	GameState.reset_to_defaults()
	GameState.apply_save_dict(profile_after_bank)
	_check(GameState.has_banked_run(&"bank_round_trip") \
		and GameState.bank_run(settlement).is_empty() \
		and GameState.get_home_cash() == 125,
		"the exact-once settlement identity survives profile save and reload")
	_check(GameState.bank_run({"run_id": "", "session_cash": 20}).is_empty() \
		and GameState.bank_run({"run_id": "negative", "session_cash": -1}).is_empty(),
		"untraceable or negative settlements cannot mutate the home bank")

	var powers := load(POWER_PATH) as RunPowerTable
	var locked_blueprint: RunPowerDef = null
	for power: RunPowerDef in powers.from_pool(RunPowerDef.Pool.BLUEPRINT):
		if not GameState.is_run_power_unlocked(power.id):
			locked_blueprint = power
			break
	_check(locked_blueprint != null \
		and GameState.unlock_run_power(locked_blueprint.id) \
		and not GameState.unlock_run_power(locked_blueprint.id) \
		and not GameState.unlock_run_power(&"not_a_power"),
		"Blueprint ownership accepts a known identity exactly once")

	var saturated := GameState.to_save_dict()
	saturated["home_cash"] = GameState.MAX_SAFE_ECONOMY_VALUE - 5
	GameState.apply_save_dict(saturated)
	var before_overflow := GameState.to_save_dict()
	_check(GameState.bank_run({
		"run_id": "overflowing_settlement",
		"session_cash": 6,
		"pending_blueprint_rolls": [1],
	}).is_empty() and GameState.to_save_dict() == before_overflow,
		"a purse that cannot fit is rejected atomically without consuming its run or Blueprint")

	GameState.reset_to_defaults()
	var all_power_ids: Array[String] = []
	for power: RunPowerDef in powers.powers:
		all_power_ids.append(String(power.id))
	var exhausted := GameState.to_save_dict()
	exhausted["unlocked_run_powers"] = all_power_ids
	GameState.apply_save_dict(exhausted)
	var conversion_value := SurvivorsContent.legacy_refunds().exhausted_blueprint_home_cash
	var conversion_receipt := GameState.bank_run({
		"run_id": "exhausted_blueprint_conversion",
		"yard_id": "yard_one",
		"session_cash": 10,
		"pending_blueprint_rolls": [1],
	})
	_check(int(conversion_receipt.get("blueprint_conversion_cash", -1)) \
		== conversion_value \
		and int(conversion_receipt.get("cash_banked", -1)) == 10 + conversion_value \
		and (conversion_receipt.get("unlocked_power_ids", []) as Array).is_empty(),
		"an exhausted Blueprint converts once through its explicit Home Cash row")
	GameState.reset_to_defaults()
	exhausted = GameState.to_save_dict()
	exhausted["unlocked_run_powers"] = all_power_ids
	GameState.apply_save_dict(exhausted)
	var before_conversion_overflow := GameState.to_save_dict()
	_check(GameState.bank_run({
		"run_id": "conversion_overflow",
		"session_cash": GameState.MAX_SAFE_ECONOMY_VALUE,
		"pending_blueprint_rolls": [1],
	}).is_empty() and GameState.to_save_dict() == before_conversion_overflow,
		"an exhausted-Blueprint conversion cannot clip a full purse or consume its run")

	GameState.reset_to_defaults()
	var first_issued_id := GameState.issue_run_id()
	_check(first_issued_id != &"" and not GameState.bank_run({
		"run_id": String(first_issued_id), "yard_id": "yard_one", "session_cash": 0,
	}).is_empty(),
		"the permanent profile issues and settles its first monotonic run identity")
	var stale_serial_profile := GameState.to_save_dict()
	stale_serial_profile["next_run_serial"] = 1
	GameState.reset_to_defaults()
	GameState.apply_save_dict(stale_serial_profile)
	var next_issued_id := GameState.issue_run_id()
	_check(next_issued_id != &"" and next_issued_id != first_issued_id \
		and not GameState.has_banked_run(next_issued_id),
		"a restarted profile skips a settled id even when its saved serial is stale")


func _test_malformed_profile_sanitisation() -> void:
	GameState.apply_save_dict({
		"home_cash": -50,
		"meta_upgrade_ranks": {
			"axe_power": 999,
			"block_control": 2,
			"continuous_handoff": 1,
			"fall_frequency_control": 999,
			"not_an_upgrade": 7,
		},
		"meta_upgrade_spend_ledger": {
			"axe_power": [10, -3],
			"block_control": [GameState.MAX_SAFE_ECONOMY_VALUE,
				GameState.MAX_SAFE_ECONOMY_VALUE],
			"continuous_handoff": [99],
			"fall_frequency_control": [1, 2, 3],
			"not_an_upgrade": [999],
		},
		"unlocked_run_powers": ["not_a_power"],
		"selected_yard": "not_a_yard",
		"selected_frequency_tier": 999,
		"applied_run_settlements": ["", "known_run", "known_run"],
		"lifetime_stats": {"runs_settled": -8},
		"yard_records": {"not_a_yard": {"clears": 99}},
	})
	_check(GameState.get_home_cash() == 0 \
		and GameState.get_meta_upgrade_rank(&"axe_power") == 8 \
		and GameState.get_meta_upgrade_rank(&"continuous_handoff") == 0 \
		and GameState.get_meta_upgrade_rank(&"fall_frequency_control") == 3 \
		and not GameState.get_meta_upgrade_ranks().has("not_an_upgrade"),
		"malformed ranks clamp to known bounds and cannot bypass prerequisites")
	_check(GameState.get_meta_upgrade_spend(&"axe_power") == 10 \
		and GameState.get_meta_upgrade_spend(&"fall_frequency_control") == 6 \
		and GameState.get_meta_upgrade_spend(&"continuous_handoff") == 0 \
		and not GameState.get_meta_upgrade_spend_ledger().has("not_an_upgrade"),
		"malformed spend data is non-negative, rank-aligned, and drops unknown IDs")
	_check(GameState.get_selected_yard() == &"yard_one" \
		and GameState.get_selected_frequency_tier() == 3 \
		and GameState.get_unlocked_run_powers().size() == 14 \
		and not GameState.is_run_power_unlocked(&"not_a_power"),
		"invalid yard and power IDs fall back while all Core powers are restored")
	_check(GameState.has_banked_run(&"known_run") and not GameState.has_banked_run(&""),
		"settlement sanitisation preserves only non-empty exact-once identities")
	var defensive_ledger := GameState.get_meta_upgrade_spend_ledger()
	(defensive_ledger["axe_power"] as Array)[0] = 999999
	_check(GameState.get_meta_upgrade_spend(&"axe_power") == 10,
		"public spend-ledger queries are defensive copies")
	var aggregate_refund := GameState.refund_all_meta_upgrades()
	_check(aggregate_refund >= 0 \
		and aggregate_refund <= GameState.MAX_SAFE_ECONOMY_VALUE \
		and GameState.get_meta_upgrade_ranks().is_empty(),
		"aggregate corrupt ledgers normalise to a refundable safe total")


func _test_typed_root_round_trip() -> void:
	var species := SpeciesTable.starting_species()
	var descriptor := LogDescriptor.create_run(
		&"root_17", species.id, 2, 17, 991, &"run_typed", &"yard_one",
		1.75, 42, 18, 12.5, &"boss_typed", 2)
	descriptor.transfer_from = Vector3(1.0, 2.0, 3.0)
	descriptor.transfer_rotation = Quaternion(Vector3.UP, 0.4)
	var restored_descriptor := LogDescriptor.from_save_dict(descriptor.to_dict())
	_check(descriptor.is_valid_run_snapshot() \
		and restored_descriptor.is_valid_run_snapshot() \
		and restored_descriptor.id == descriptor.id \
		and restored_descriptor.run_id == descriptor.run_id \
		and restored_descriptor.yard_id == descriptor.yard_id \
		and restored_descriptor.boss_id == descriptor.boss_id \
		and is_equal_approx(restored_descriptor.hardness_snapshot, 1.75) \
		and restored_descriptor.cash_reward_snapshot == 42 \
		and restored_descriptor.xp_reward_snapshot == 18 \
		and is_equal_approx(restored_descriptor.original_mass, 12.5) \
		and restored_descriptor.has_transfer_pose(),
		"a run descriptor round-trips stable identity, rewards, hardness, mass, boss, and transfer data")

	var receipt := RootCompletionReceipt.new(
		&"run_typed", &"root_17", RootCompletionReceipt.Source.OFF_BLOCK,
		42, 18, &"boss_typed", 1, species.yield_item, 6)
	var restored_receipt := RootCompletionReceipt.from_dict(receipt.to_dict())
	_check(receipt.is_valid() and restored_receipt.is_valid() \
		and restored_receipt.receipt_id == &"run_typed::root::root_17" \
		and restored_receipt.source == RootCompletionReceipt.Source.OFF_BLOCK \
		and restored_receipt.cash_total == 42 and restored_receipt.xp_total == 18 \
		and restored_receipt.pending_blueprints == 1 \
		and restored_receipt.settled_piece_count == 6,
		"a typed root receipt round-trips one deterministic exact-once completion identity")
	var impossible := RootCompletionReceipt.new(
		&"run_typed", &"ordinary_root", RootCompletionReceipt.Source.BLOCK,
		1, 1, &"", 1)
	_check(not impossible.is_valid(),
		"an ordinary root cannot manufacture a boss Blueprint receipt")

	var descendant := LogDescendantState.new()
	descendant.id = &"root_17/a"
	descendant.parent_id = &"root_17"
	descendant.mass = 5.25
	descendant.projection_offset = Vector3(0.1, 0.0, -0.2)
	descendant.scar_records = [{"local_plane": Plane(Vector3.RIGHT, 0.2)}]
	var root := LogRootState.new()
	root.descriptor = descriptor
	root.descendants = [descendant]
	root.cut_journal = [{"piece_id": "root", "child_ids": ["root/a", "root/b"]}]
	root.boundary_exposure = 2.25
	root.arena_sliced = true
	var restored_root := LogRootState.from_dict(root.to_dict())
	_check(root.is_valid() and restored_root.is_valid() \
		and restored_root.descendants.size() == 1 \
		and restored_root.descendants[0].id == &"root_17/a" \
		and is_equal_approx(restored_root.descendants[0].mass, 5.25) \
		and restored_root.descendants[0].scar_records.size() == 1 \
		and restored_root.cut_journal.size() == 1 \
		and is_equal_approx(restored_root.boundary_exposure, 2.25) \
		and restored_root.arena_sliced,
		"shared root state preserves descendants, scars, cut journal, and boundary exposure")
	var completed := LogRootState.from_dict(root.to_dict())
	completed.completion_state = LogRootState.CompletionState.COMPLETED
	completed.completion_receipt = receipt
	_check(completed.is_valid(),
		"a completed root accepts its one matching snapshotted completion receipt")

	var mismatched := LogRootState.from_dict(root.to_dict())
	mismatched.completion_state = LogRootState.CompletionState.COMPLETED
	mismatched.completion_receipt = RootCompletionReceipt.new(
		&"another_run", descriptor.id, RootCompletionReceipt.Source.BLOCK,
		descriptor.cash_reward_snapshot, descriptor.xp_reward_snapshot,
		descriptor.boss_id, 1)
	_check(not mismatched.is_valid(),
		"a root cannot accept a completion receipt from another run identity")
	var wrong_reward := LogRootState.from_dict(root.to_dict())
	wrong_reward.completion_state = LogRootState.CompletionState.COMPLETED
	wrong_reward.completion_receipt = RootCompletionReceipt.new(
		descriptor.run_id, descriptor.id, RootCompletionReceipt.Source.BLOCK,
		descriptor.cash_reward_snapshot + 1, descriptor.xp_reward_snapshot,
		descriptor.boss_id, 1)
	_check(not wrong_reward.is_valid(),
		"a completion receipt cannot differ from its root's snapshotted rewards")
	var malformed_descendant_data := descendant.to_dict()
	malformed_descendant_data["transform"] = "not a transform"
	var malformed_descriptor_data := descriptor.to_dict()
	malformed_descriptor_data["yard_id"] = "unknown_yard"
	var zero_reward_descriptor_data := descriptor.to_dict()
	zero_reward_descriptor_data["cash_reward_snapshot"] = 0
	_check(not LogDescendantState.from_dict(malformed_descendant_data).is_valid() \
		and not LogDescriptor.from_save_dict(
			malformed_descriptor_data).is_valid_run_snapshot() \
		and not LogDescriptor.from_save_dict(
			zero_reward_descriptor_data).is_valid_run_snapshot(),
		"typed decoders reject malformed transforms, unknown yards, and zero reward snapshots")
	descendant.id = &"another_root/a"
	_check(not root.is_valid(),
		"a descendant path and direct parent must belong to its descriptor root")


func _test_isolated_save_migrations() -> void:
	var token := "%d_%d" % [
		int(Time.get_unix_time_from_system()), Time.get_ticks_usec(),
	]
	var v18_path := "user://the_axeman_slice1_v18_%s.cfg" % token
	var v17_path := "user://the_axeman_slice1_v17_%s.cfg" % token
	var v16_path := "user://the_axeman_slice1_v16_%s.cfg" % token
	var v14_path := "user://the_axeman_slice1_v14_%s.cfg" % token
	var v1_path := "user://the_axeman_slice1_v1_%s.cfg" % token
	var direct_path := "user://the_axeman_slice1_direct_%s.cfg" % token
	var malformed_path := "user://the_axeman_slice1_malformed_%s.cfg" % token
	var corrupt_v18_path := "user://the_axeman_slice1_corrupt_v18_%s.cfg" % token
	var corrupt_v17_path := "user://the_axeman_slice1_corrupt_v17_%s.cfg" % token
	var wrong_types_path := "user://the_axeman_slice1_wrong_types_%s.cfg" % token
	var backup_failure_path := "user://the_axeman_slice1_backup_failure_%s.cfg" % token
	var bank_retry_path := "user://the_axeman_slice1_bank_retry_%s.cfg" % token
	_cleanup_isolated_save(v18_path)
	_cleanup_isolated_save(v17_path)
	_cleanup_isolated_save(v16_path)
	_cleanup_isolated_save(v14_path)
	_cleanup_isolated_save(v1_path)
	_cleanup_isolated_save(direct_path)
	_cleanup_isolated_save(malformed_path)
	_cleanup_isolated_save(corrupt_v18_path)
	_cleanup_isolated_save(corrupt_v17_path)
	_cleanup_isolated_save(wrong_types_path)
	_cleanup_isolated_save(backup_failure_path)
	_cleanup_isolated_save(bank_retry_path)
	_test_v18_load_backup_and_replacement(v18_path)
	_cleanup_isolated_save(v18_path)
	_test_v17_load_backup_and_replacement(v17_path)
	_cleanup_isolated_save(v17_path)
	_test_v16_entitlement_migration(v16_path)
	_cleanup_isolated_save(v16_path)
	_test_v14_record_derivations(v14_path)
	_cleanup_isolated_save(v14_path)
	_test_v1_alias_migration(v1_path)
	_cleanup_isolated_save(v1_path)
	_test_direct_legacy_replacement_backup(direct_path)
	_cleanup_isolated_save(direct_path)
	_test_truncated_v19_is_rejected(malformed_path)
	_cleanup_isolated_save(malformed_path)
	_test_legacy_corruption_is_rejected(
		corrupt_v18_path, corrupt_v17_path, wrong_types_path)
	_cleanup_isolated_save(corrupt_v18_path)
	_cleanup_isolated_save(corrupt_v17_path)
	_cleanup_isolated_save(wrong_types_path)
	_test_backup_failure_preserves_source(backup_failure_path)
	_cleanup_isolated_save(backup_failure_path)
	_test_disk_exact_once_bank_retry(bank_retry_path)
	_cleanup_isolated_save(bank_retry_path)
	SaveSystem.reset_save_path_after_tests()
	_check(SaveSystem.active_save_path() == SaveSystem.SAVE_PATH,
		"isolated migration tests restore the production save path")


func _test_v18_load_backup_and_replacement(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path) \
		and SaveSystem.active_save_path() == path,
		"v18 migration uses a unique isolated user save path")
	if not _install_fixture(V18_FIXTURE, path):
		_check(false, "the structured v18 fixture installs at the isolated path")
		return
	_check(true, "the structured v18 fixture installs at the isolated path")
	var original_bytes := _read_bytes(path)
	var first_load := SaveSystem.load_game()
	var first_backups := _backup_paths(path, 18)
	_check(first_load == SaveSystem.LoadResult.OK and SaveSystem.loaded_from_legacy() \
		and SaveSystem.loaded_attempt_snapshot().is_empty() \
		and not GameState.are_permanent_controls_locked(),
		"v18 loads as migration while incompatible attempt geometry is discarded")
	_check(GameState.get_home_cash() == 4381 \
		and int(GameState.get_migration_notice().get("attempt_cash_transferred", -1)) == 321 \
		and bool(GameState.get_migration_notice().get("attempt_discarded", false)),
		"v18 banks the attempt purse and explicit refunds while ignoring stale profile cash")
	_check(GameState.get_meta_upgrade_rank(&"hold_to_chop") == 1 \
		and GameState.get_meta_upgrade_rank(&"continuous_handoff") == 1 \
		and GameState.get_meta_upgrade_rank(&"fall_frequency_control") == 3 \
		and GameState.get_meta_upgrade_spend(&"hold_to_chop") == 0 \
		and GameState.get_meta_upgrade_spend(&"continuous_handoff") == 0 \
		and GameState.get_meta_upgrade_spend(&"fall_frequency_control") == 0 \
		and GameState.get_selected_frequency_tier() == 2,
		"v18 seeds only safe capabilities as free ranks and clamps its selected delivery tier")
	var legacy := GameState.get_legacy_records()
	_check(InventoryManager.get_count(&"aspen_firewood") == 3 \
		and GameState.get_yard_pile().get(&"aspen_firewood", 0) == 4 \
		and GameState.get_lifetime_wood_chopped() == 88 \
		and GameState.get_haul_aways_completed() == 7 \
		and bool((legacy.get("earth", {}) as Dictionary).get("earth_cleared", false)),
		"v18 preserves inventory, pile, lifetime totals, and read-only Earth records")
	_check(first_backups.size() == 1 \
		and _read_bytes(first_backups[0]) == original_bytes,
		"v18 load creates a required byte-for-byte timestamped backup")
	var still_v18 := ConfigFile.new()
	_check(still_v18.load(path) == OK \
		and int(still_v18.get_value("meta", "version", -1)) == 18,
		"migration load leaves the source untouched until a successful replacement save")

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var second_load := SaveSystem.load_game()
	var second_backups := _backup_paths(path, 18)
	_check(second_load == SaveSystem.LoadResult.OK \
		and GameState.get_home_cash() == 4381 \
		and InventoryManager.get_count(&"aspen_firewood") == 3 \
		and second_backups.size() == 2,
		"repeated pre-replacement v18 load is deterministic and chooses a collision-safe backup")
	var all_backups_match := true
	for backup_path: String in second_backups:
		all_backups_match = all_backups_match \
			and _read_bytes(backup_path) == original_bytes
	_check(all_backups_match,
		"every collision-safe v18 backup retains the exact legacy bytes")
	_check(SaveSystem.clear_attempt_and_save(),
		"the migrated profile replaces v18 only through an atomic current-version save")
	var upgraded := ConfigFile.new()
	_check(upgraded.load(path) == OK \
		and int(upgraded.get_value("meta", "version", -1)) == SaveSystem.SAVE_VERSION \
		and (upgraded.get_value("attempt", "data", {}) as Dictionary).is_empty(),
		"the isolated replacement is v19 and carries no incompatible attempt")


func _test_v17_load_backup_and_replacement(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"v17 migration uses a second unique isolated user save path")
	if not _install_fixture(V17_FIXTURE, path):
		_check(false, "the flat v17 fixture installs at the isolated path")
		return
	_check(true, "the flat v17 fixture installs at the isolated path")
	var original_bytes := _read_bytes(path)
	var result := SaveSystem.load_game()
	var backups := _backup_paths(path, 17)
	_check(result == SaveSystem.LoadResult.OK and SaveSystem.loaded_from_legacy() \
		and SaveSystem.loaded_attempt_snapshot().is_empty(),
		"v17 flat progression migrates without inventing a suspended attempt")
	_check(GameState.get_home_cash() == 4287,
		"v17 keeps old unspent cash, uses tier-minus-one refunds, and does not double-count XP/skills")
	_check(GameState.get_meta_upgrade_rank(&"hold_to_chop") == 1 \
		and GameState.get_meta_upgrade_rank(&"continuous_handoff") == 1 \
		and GameState.get_meta_upgrade_rank(&"fall_frequency_control") == 3 \
		and GameState.get_meta_upgrade_spend(&"fall_frequency_control") == 0,
		"v17 maps its three safe capabilities with zero refundable spend")
	var legacy := GameState.get_legacy_records()
	_check(InventoryManager.get_count(&"aspen_firewood") == 5 \
		and GameState.get_yard_pile().get(&"aspen_firewood", 0) == 2 \
		and GameState.get_lifetime_wood_chopped() == 66 \
		and int(legacy.get("source_version", -1)) == 17,
		"v17 preserves inventory, pile, lifetime work, and legacy source identity")
	_check(backups.size() == 1 and _read_bytes(backups[0]) == original_bytes,
		"v17 receives its own required byte-for-byte timestamped backup")
	_check(SaveSystem.clear_attempt_and_save(),
		"the migrated v17 profile writes through the v19 atomic replacement path")
	var upgraded := ConfigFile.new()
	_check(upgraded.load(path) == OK \
		and int(upgraded.get_value("meta", "version", -1)) == 19,
		"the isolated v17 replacement has the v19 schema version")


func _test_direct_legacy_replacement_backup(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"direct replacement uses a third isolated save path")
	if not _install_fixture(V18_FIXTURE, path):
		_check(false, "the direct-replacement v18 fixture installs")
		return
	_check(true, "the direct-replacement v18 fixture installs")
	var original_bytes := _read_bytes(path)
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.clear_attempt_and_save(),
		"a deliberate fresh-profile replacement succeeds without a prior migration load")
	var backups := _backup_paths(path, 18)
	var current := ConfigFile.new()
	_check(backups.size() == 1 and _read_bytes(backups[0]) == original_bytes \
		and current.load(path) == OK \
		and int(current.get_value("meta", "version", -1)) == SaveSystem.SAVE_VERSION,
		"direct replacement still creates the required byte-identical legacy backup first")

	var current_bytes := _read_bytes(path)
	var replacing_path := path + ".replacing"
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(replacing_path))
	_check(rename_error == OK and not FileAccess.file_exists(path) \
		and FileAccess.file_exists(replacing_path),
		"the interrupted-replacement fixture reaches the protected-old-save window")
	_check(SaveSystem.has_save() and FileAccess.file_exists(path) \
		and not FileAccess.file_exists(replacing_path) \
		and _read_bytes(path) == current_bytes \
		and SaveSystem.load_game() == SaveSystem.LoadResult.OK,
		"startup restores a byte-identical protected save after an interrupted atomic replacement")
	var second_rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(replacing_path))
	_check(second_rename_error == OK and SaveSystem.clear_attempt_and_save() \
		and FileAccess.file_exists(path) and not FileAccess.file_exists(replacing_path),
		"a direct save also restores the protected predecessor before replacing it")


func _test_v16_entitlement_migration(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"v16 entitlement migration uses an isolated save path")
	if not _install_fixture(V16_FIXTURE, path):
		_check(false, "the v16 alien-mastery fixture installs")
		return
	_check(true, "the v16 alien-mastery fixture installs")
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK \
		and GameState.get_home_cash() == 825,
		"pre-v17 recognized alien mastery restores its pinned skill entitlement once")
	_check(_backup_paths(path, 16).size() == 1,
		"v16 receives the same required legacy backup protection")


func _test_v14_record_derivations(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"v14 record migration uses an isolated save path")
	if not _install_fixture(V14_FIXTURE, path):
		_check(false, "the v14 Earth/lifetime fixture installs")
		return
	_check(true, "the v14 Earth/lifetime fixture installs")
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK \
		and GameState.get_home_cash() == 42,
		"v14 carries unspent cash without refunding retired record counters")
	var legacy := GameState.get_legacy_records()
	_check(int((legacy.get("earth", {}) as Dictionary).get(
		"earth_trees_felled", -1)) == 5 \
		and int((legacy.get("old_progression", {}) as Dictionary).get(
			"lifetime_cash_earned", -1)) == 8_000_000 \
		and int(GameState.get_lifetime_stats().get("cash_earned", -1)) == 8_000_000,
		"pre-v15 partial Earth work and the pinned lifetime-cash floor survive as records")
	var full_clear := SaveSystem.migrate_v17_or_earlier_profile({
		"cash": 0,
		"earth_master": true,
		"earth_finale_state": 3,
		"earth_finale_splits": 3,
		"skill_levels": {},
		"xp": 0,
	}, 14)
	_check(int((full_clear.get("legacy_records", {}).get(
		"earth", {}) as Dictionary).get("earth_trees_felled", -1)) \
		== 3_040_000_000_000,
		"a completed pre-v15 finale preserves the full historical Earth record")


func _test_v1_alias_migration(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"v1 alias migration uses an isolated save path")
	if not _install_fixture(V1_FIXTURE, path):
		_check(false, "the true v1 alias fixture installs")
		return
	_check(true, "the true v1 alias fixture installs")
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK \
		and GameState.get_home_cash() == 1133 \
		and InventoryManager.get_count(&"aspen_firewood") == 2,
		"v1 aliases use pinned prototype caps/costs and duplicate species refund once")
	_check(int(GameState.get_legacy_records().get(
		"old_progression", {}).get("owned_species_count", -1)) == 1,
		"legacy ownership records count duplicate species identities once")
	_check(_backup_paths(path, 1).size() == 1,
		"v1 receives a byte-preserving timestamped migration backup")


func _test_truncated_v19_is_rejected(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"truncated-v19 validation uses an isolated save path")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SaveSystem.SAVE_VERSION)
	_check(cfg.save(path) == OK, "the parseable but truncated v19 fixture writes")
	var profile_before := GameState.to_save_dict()
	var inventory_before := InventoryManager.to_save_dict()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.CORRUPT \
		and GameState.to_save_dict() == profile_before \
		and InventoryManager.to_save_dict() == inventory_before,
		"missing mandatory v19 sections are corrupt and apply no partial state")


func _test_legacy_corruption_is_rejected(v18_path: String, v17_path: String,
		wrong_types_path: String) -> void:
	var profile_before := GameState.to_save_dict()
	var inventory_before := InventoryManager.to_save_dict()
	for row: Array in [[v18_path, 18], [v17_path, 17]]:
		var path := String(row[0])
		var cfg := ConfigFile.new()
		cfg.set_value("meta", "version", int(row[1]))
		_check(SaveSystem.set_save_path_for_tests(path) and cfg.save(path) == OK,
			"the truncated v%d legacy fixture writes" % int(row[1]))
		_check(SaveSystem.load_game() == SaveSystem.LoadResult.CORRUPT \
			and GameState.to_save_dict() == profile_before \
			and InventoryManager.to_save_dict() == inventory_before \
			and _backup_paths(path, int(row[1])).is_empty(),
			"truncated v%d is rejected before backup or partial application" % int(row[1]))
	_check(SaveSystem.set_save_path_for_tests(wrong_types_path) \
		and _install_fixture(V17_WRONG_TYPES_FIXTURE, wrong_types_path),
		"the wrong-scalar-type legacy fixture installs")
	var wrong_bytes := _read_bytes(wrong_types_path)
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.CORRUPT \
		and _read_bytes(wrong_types_path) == wrong_bytes \
		and GameState.to_save_dict() == profile_before,
		"string cash cannot become authority and the malformed source stays untouched")
	var dropped_ownership := SaveSystem.migrate_v17_or_earlier_profile({
		"cash": 7,
		"xp": 0,
		"skill_levels": {"strong_arms": "5"},
		"owned_species": {"eastern_white_pine": 1},
	}, 17)
	_check(int(dropped_ownership.get("home_cash", -1)) == 7,
		"wrong-type skill ranks and ownership flags are dropped instead of coerced")


func _test_backup_failure_preserves_source(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path) \
		and _install_fixture(V18_FIXTURE, path),
		"the backup-failure v18 fixture installs in isolation")
	var original_bytes := _read_bytes(path)
	SaveSystem.set_force_legacy_backup_failure_for_tests(true)
	var result := SaveSystem.load_game()
	SaveSystem.set_force_legacy_backup_failure_for_tests(false)
	_check(result == SaveSystem.LoadResult.CORRUPT \
		and _read_bytes(path) == original_bytes \
		and _backup_paths(path, 18).is_empty(),
		"a failed required backup leaves the sole legacy source byte-identical")


func _test_disk_exact_once_bank_retry(path: String) -> void:
	_check(SaveSystem.set_save_path_for_tests(path),
		"disk exact-once banking uses an isolated save path")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var run_id := GameState.issue_run_id()
	var settlement := {
		"run_id": String(run_id), "yard_id": "yard_one", "session_cash": 55,
	}
	_check(not GameState.bank_run(settlement).is_empty() \
		and SaveSystem.save_game({"schema_version": 1,
			"run_id": String(run_id), "cash": 55}),
		"a banked profile and retained attempt write atomically to disk")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK \
		and GameState.get_home_cash() == 55 \
		and GameState.has_banked_run(run_id) \
		and not SaveSystem.loaded_attempt_snapshot().is_empty() \
		and GameState.bank_run(settlement).is_empty(),
		"disk reload refuses a retained attempt's already-applied settlement identity")


func _install_fixture(source_path: String, target_path: String) -> bool:
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(target_path)) == OK


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _backup_paths(path: String, version: int) -> Array[String]:
	var out: Array[String] = []
	var prefix := path.get_file().trim_suffix(".cfg") + ".v%d." % version
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(prefix) and file_name.ends_with(".backup.cfg"):
			out.append("user://" + file_name)
	out.sort()
	return out


func _cleanup_isolated_save(path: String) -> void:
	var exact_paths: Array[String] = [path, path + ".tmp", path + ".replacing"]
	for exact_path: String in exact_paths:
		if FileAccess.file_exists(exact_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(exact_path))
	var prefix := path.get_file().trim_suffix(".cfg") + ".v"
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with(prefix) and file_name.ends_with(".backup.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
				"user://" + file_name))


func _bank_cash(run_id: StringName, amount: int) -> Dictionary:
	return GameState.bank_run({
		"run_id": String(run_id),
		"yard_id": "yard_one",
		"session_cash": amount,
	})


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
