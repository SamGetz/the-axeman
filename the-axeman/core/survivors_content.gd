class_name SurvivorsContent
extends RefCounted
## Stateless access and cross-table validation for the v19 progression pivot.
## Loaded Resources are catalogue data only; state owners never mutate them.

const META_UPGRADE_PATH := "res://data/meta_upgrade_catalogue_placeholder.tres"
const RUN_POWER_PATH := "res://data/run_power_catalogue_placeholder.tres"
const YARD_PATH := "res://data/yard_catalogue_placeholder.tres"
const LEGACY_REFUND_PATH := "res://data/legacy_progression_refund_placeholder.tres"
const RUN_OFFER_TUNING_PATH := "res://data/run_offer_tuning_placeholder.tres"

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

const CORE_POWER_CAPS := {
	&"deep_bite": 8,
	&"quick_hands": 8,
	&"scar_wisdom": 5,
	&"double_chop": 3,
	&"follow_up": 5,
	&"splinter_volley": 8,
	&"flying_wedge": 8,
	&"yard_magnet": 8,
	&"soft_landing": 5,
	&"ring_reinforcement": 5,
	&"quick_study": 5,
	&"keen_appraisal": 5,
	&"area_size": 5,
	&"sawblade_halo": 5,
}

const BLUEPRINT_POWER_CAPS := {
	&"grain_reader": 5,
	&"earthshaker": 3,
	&"powder_keg": 3,
	&"kindling_chain": 5,
	&"whirling_axe": 5,
	&"crosscut_sweep": 5,
	&"maul_drop": 3,
	&"splitter_rig": 5,
	&"cant_hook": 5,
	&"stump_pulse": 5,
	&"last_ditch_rescue": 3,
	&"momentum": 8,
	&"timber_burst": 5,
}

const YARD_ONE_SPECIES: Array[StringName] = [
	&"quaking_aspen", &"eastern_white_pine", &"norway_spruce",
	&"balsam_fir", &"lodgepole_pine", &"white_spruce",
]
## Existing presentation identities are pinned here instead of loading the
## retired EquipmentTable, whose query surface still depends on the old Shop.
const VISUAL_SLOTS := {
	&"balanced_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"tempered_woodsmans_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"forged_splitting_maul": MetaVisualMilestoneDef.Slot.AXE,
	&"steel_cheek_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"journeymans_bearded_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"hardwood_pattern_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"continental_mill_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"earthmaster_axe": MetaVisualMilestoneDef.Slot.AXE,
	&"reinforced_chopping_block": MetaVisualMilestoneDef.Slot.BLOCK,
	&"iron_block_dogs": MetaVisualMilestoneDef.Slot.BLOCK,
	&"log_cradle": MetaVisualMilestoneDef.Slot.BLOCK,
	&"raised_split_stand": MetaVisualMilestoneDef.Slot.BLOCK,
	&"braced_yard_block": MetaVisualMilestoneDef.Slot.BLOCK,
	&"millhouse_chopping_block": MetaVisualMilestoneDef.Slot.BLOCK,
	&"continental_split_deck": MetaVisualMilestoneDef.Slot.BLOCK,
	&"earthmaster_ironwood_block": MetaVisualMilestoneDef.Slot.BLOCK,
}

static var _meta_upgrades: MetaUpgradeTable
static var _run_powers: RunPowerTable
static var _yards: YardTable
static var _legacy_refunds: LegacyProgressionRefundTable
static var _run_offer_tuning: RunOfferTuning


static func meta_upgrades() -> MetaUpgradeTable:
	if _meta_upgrades == null:
		_meta_upgrades = load(META_UPGRADE_PATH) as MetaUpgradeTable
	return _meta_upgrades


static func run_powers() -> RunPowerTable:
	if _run_powers == null:
		_run_powers = load(RUN_POWER_PATH) as RunPowerTable
	return _run_powers


static func yards() -> YardTable:
	if _yards == null:
		_yards = load(YARD_PATH) as YardTable
	return _yards


static func legacy_refunds() -> LegacyProgressionRefundTable:
	if _legacy_refunds == null:
		_legacy_refunds = load(LEGACY_REFUND_PATH) as LegacyProgressionRefundTable
	return _legacy_refunds


static func run_offer_tuning() -> RunOfferTuning:
	if _run_offer_tuning == null:
		_run_offer_tuning = load(RUN_OFFER_TUNING_PATH) as RunOfferTuning
	return _run_offer_tuning


static func core_power_ids() -> Array[StringName]:
	return _dictionary_ids(CORE_POWER_CAPS)


static func blueprint_power_ids() -> Array[StringName]:
	return _dictionary_ids(BLUEPRINT_POWER_CAPS)


static func clear_cache() -> void:
	_meta_upgrades = null
	_run_powers = null
	_yards = null
	_legacy_refunds = null
	_run_offer_tuning = null


static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	if meta_upgrades() == null:
		errors.append("meta-upgrade catalogue failed to load")
	if run_powers() == null:
		errors.append("run-power catalogue failed to load")
	if yards() == null:
		errors.append("yard catalogue failed to load")
	if legacy_refunds() == null:
		errors.append("legacy-refund catalogue failed to load")
	if run_offer_tuning() == null:
		errors.append("run-offer tuning failed to load")
	if not errors.is_empty():
		return errors
	errors.append_array(meta_upgrades().validate())
	errors.append_array(run_powers().validate())
	errors.append_array(yards().validate())
	errors.append_array(legacy_refunds().validate())
	errors.append_array(run_offer_tuning().validate())
	errors.append_array(_validate_locked_meta_contract())
	errors.append_array(_validate_locked_power_contract())
	errors.append_array(_validate_locked_yard_contract())
	errors.append_array(_validate_refund_cross_references())
	return errors


static func _validate_locked_meta_contract() -> PackedStringArray:
	var errors := PackedStringArray()
	var table := meta_upgrades()
	if table.upgrades.size() != META_CAPS.size():
		errors.append("meta catalogue must contain exactly 18 locked lines")
	for raw_id: Variant in META_CAPS:
		var id := StringName(raw_id)
		var definition := table.by_id(id)
		if definition == null:
			errors.append("meta catalogue is missing locked line:%s" % id)
			continue
		if definition.max_rank != int(META_CAPS[id]):
			errors.append("meta line %s has the wrong locked cap" % id)
		for milestone: MetaVisualMilestoneDef in definition.visual_milestones:
			if not VISUAL_SLOTS.has(milestone.equipment_id) \
					or int(VISUAL_SLOTS[milestone.equipment_id]) != int(milestone.slot):
				errors.append("meta line %s has an invalid visual milestone:%s" % [
					id, milestone.equipment_id])
	var continuous := table.by_id(&"continuous_handoff")
	if continuous == null or continuous.prerequisite_upgrade_id != &"hold_to_chop" \
			or continuous.prerequisite_rank != 1:
		errors.append("Continuous Handoff must require Hold-to-Chop rank one")
	return errors


static func _validate_locked_power_contract() -> PackedStringArray:
	var errors := PackedStringArray()
	var table := run_powers()
	if table.powers.size() != CORE_POWER_CAPS.size() + BLUEPRINT_POWER_CAPS.size():
		errors.append("run-power catalogue must match the locked power roster")
	if table.powers.size() > RunPowerTable.MAX_POWER_COUNT:
		errors.append("run-power catalogue exceeds its 32-power cap")
	for raw_id: Variant in CORE_POWER_CAPS:
		_validate_power_row(errors, table, StringName(raw_id),
			RunPowerDef.Pool.CORE, int(CORE_POWER_CAPS[raw_id]))
	for raw_id: Variant in BLUEPRINT_POWER_CAPS:
		_validate_power_row(errors, table, StringName(raw_id),
			RunPowerDef.Pool.BLUEPRINT, int(BLUEPRINT_POWER_CAPS[raw_id]))
	return errors


static func _validate_power_row(errors: PackedStringArray, table: RunPowerTable,
		id: StringName, expected_pool: RunPowerDef.Pool, expected_cap: int) -> void:
	var definition := table.by_id(id)
	if definition == null:
		errors.append("run-power catalogue is missing locked power:%s" % id)
		return
	if definition.pool != expected_pool or definition.rank_cap != expected_cap:
		errors.append("run power %s has the wrong locked pool or cap" % id)


static func _validate_locked_yard_contract() -> PackedStringArray:
	var errors := PackedStringArray()
	var table := yards()
	if table.yards.size() != 1 or table.by_id(&"yard_one") == null:
		errors.append("yard one must be the only playable yard in this milestone")
		return errors
	var yard := table.by_id(&"yard_one")
	if not is_equal_approx(yard.stage_duration_seconds, 900.0):
		errors.append("yard one must last exactly 900 gameplay seconds")
	if yard.delivery_tier_interval_scales.size() != 4:
		errors.append("yard one must expose default plus three starting tiers")
	if yard.bosses.size() != 3:
		errors.append("yard one must schedule exactly three bosses")
	var timeline_species: Dictionary = {}
	for entry: YardTimelineEntryDef in yard.species_timeline:
		if entry != null:
			timeline_species[entry.species_id] = true
	var reward_species: Dictionary = {}
	for reward: YardSpeciesRewardDef in yard.species_rewards:
		if reward != null:
			reward_species[reward.species_id] = true
	for species_id: StringName in YARD_ONE_SPECIES:
		if not timeline_species.has(species_id) or not reward_species.has(species_id):
			errors.append("yard one is missing its locked species:%s" % species_id)
	if timeline_species.size() != YARD_ONE_SPECIES.size() \
			or reward_species.size() != YARD_ONE_SPECIES.size():
		errors.append("yard one contains species outside its locked six-row roster")
	return errors


static func _validate_refund_cross_references() -> PackedStringArray:
	var errors := PackedStringArray()
	for seed: LegacyCapabilitySeedDef in legacy_refunds().capability_seeds:
		if seed == null:
			continue
		var target := meta_upgrades().by_id(seed.target_meta_upgrade_id)
		if target == null:
			errors.append("legacy capability seed has an unknown target:%s" \
				% seed.target_meta_upgrade_id)
		elif seed.copy_legacy_rank and target.max_rank < seed.minimum_legacy_rank:
			errors.append("legacy capability seed target cannot accept its source rank")
		elif not seed.copy_legacy_rank and seed.fixed_target_rank > target.max_rank:
			errors.append("legacy capability seed target rank exceeds its cap")
	return errors


static func _dictionary_ids(source: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw_id: Variant in source:
		out.append(StringName(raw_id))
	return out
