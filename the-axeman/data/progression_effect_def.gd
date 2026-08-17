class_name ProgressionEffectDef
extends Resource
## One typed, cumulative rank ladder used by the survivors-style permanent and
## run catalogues. Values are authored explicitly: index zero is rank one.

enum Kind {
	INVALID,
	SPLIT_RELIABILITY,
	SWING_RECOVERY,
	RESERVED_RETIRED_WINDUP_TIME,
	RESERVED_RETIRED_BLOCK_WORK_RADIUS,
	RESERVED_RETIRED_BLOCK_SETTLE_TIME,
	RESERVED_RETIRED_BLOCK_HANDOFF_TIME,
	SCAR_RELIABILITY,
	RESERVED_RETIRED_BOSS_CUT_EFFECTIVENESS,
	RUN_XP_MULTIPLIER,
	SESSION_CASH_MULTIPLIER,
	FOURTH_CARD_CHANCE,
	RARE_QUALITY_WEIGHT,
	EPIC_QUALITY_WEIGHT,
	RESERVED_RETIRED_BLASTER_DROP_CHANCE,
	BOUNDARY_RADIUS,
	BOUNDARY_GRACE,
	RESERVED_RETIRED_BLASTER_DURATION,
	RESERVED_RETIRED_OFF_BLOCK_CUTTING,
	HOLD_TO_CHOP,
	CONTINUOUS_HANDOFF,
	FREQUENCY_TIER_UNLOCK,
	REROLL_CHARGES,
	BANISH_CHARGES,
	GUARANTEED_EXTRA_CUTS,
	FOLLOW_UP_CHANCE,
	FOLLOW_UP_DEPTH,
	SPLINTER_COUNT,
	FLYING_WEDGE_INTERVAL,
	FLYING_WEDGE_CUT_COUNT,
	YARD_MAGNET_FORCE,
	ARRIVAL_LATERAL_MULTIPLIER,
	ARRIVAL_BOUNCE_MULTIPLIER,
	ARRIVAL_OUTWARD_MULTIPLIER,
	GRAIN_MARK_CHANCE,
	GRAIN_BONUS_XP_MULTIPLIER,
	EARTHSHAKER_TRIGGER_CUTS,
	EARTHSHAKER_RADIUS,
	EARTHSHAKER_INWARD_FORCE,
	POWDER_KEG_RADIUS,
	POWDER_KEG_CUT_COUNT,
	POWDER_KEG_INWARD_FORCE,
	KINDLING_CHAIN_COUNT,
	KINDLING_CHAIN_RANGE,
	ORBITING_AXE_COUNT,
	ORBITING_AXE_CONTACT_COOLDOWN,
	CROSSCUT_SWEEP_INTERVAL,
	CROSSCUT_SWEEP_WIDTH,
	MAUL_DROP_INTERVAL,
	MAUL_DROP_CUT_COUNT,
	SPLITTER_RIG_INTERVAL,
	CANT_HOOK_FORCE,
	STUMP_PULSE_INTERVAL,
	STUMP_PULSE_FORCE,
	RESCUE_CHARGES,
	MOMENTUM_MAX_STACKS,
	MOMENTUM_SPEED_PER_STACK,
	MOMENTUM_RELIABILITY_PER_STACK,
	YARD_MAGNET_PULSE_INTERVAL,
	AREA_SIZE_MULTIPLIER,
	SAWBLADE_HALO_INTERVAL,
	SAWBLADE_HALO_RADIUS,
	TIMBER_BURST_RADIUS,
}

enum Operation { ADD, MULTIPLY, ENABLE, SET }

@export var kind: Kind = Kind.INVALID
@export var operation: Operation = Operation.ADD
@export var cumulative_values_by_rank := PackedFloat64Array()
@export_multiline var tuning_status := \
	"PLACEHOLDER — survivors progression effect requires measured tuning approval"


func value_at_rank(rank: int) -> float:
	if rank <= 0 or cumulative_values_by_rank.is_empty():
		return 1.0 if operation == Operation.MULTIPLY else 0.0
	return float(cumulative_values_by_rank[clampi(
		rank - 1, 0, cumulative_values_by_rank.size() - 1)])


func validate(expected_rank_cap: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if kind <= Kind.INVALID or kind > Kind.TIMBER_BURST_RADIUS:
		errors.append("progression effect has an invalid kind")
	if operation < Operation.ADD or operation > Operation.SET:
		errors.append("progression effect has an invalid operation")
	if expected_rank_cap <= 0 \
			or cumulative_values_by_rank.size() != expected_rank_cap:
		errors.append("progression effect rank array does not match its owner cap")
	for value: float in cumulative_values_by_rank:
		if not is_finite(value):
			errors.append("progression effect contains a non-finite value")
			break
		if operation == Operation.ENABLE and value not in [0.0, 1.0]:
			errors.append("enabled progression effects must use zero-or-one values")
			break
		if _is_count_kind(kind) and (value < 0.0 or not is_equal_approx(value, round(value))):
			errors.append("count progression effects must use non-negative whole values")
			break
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("progression effect tuning must remain explicitly provisional")
	return errors


static func _is_count_kind(effect_kind: Kind) -> bool:
	return effect_kind in [
		Kind.FREQUENCY_TIER_UNLOCK, Kind.REROLL_CHARGES, Kind.BANISH_CHARGES,
		Kind.GUARANTEED_EXTRA_CUTS, Kind.FOLLOW_UP_DEPTH, Kind.SPLINTER_COUNT,
		Kind.FLYING_WEDGE_CUT_COUNT, Kind.EARTHSHAKER_TRIGGER_CUTS,
		Kind.POWDER_KEG_CUT_COUNT, Kind.KINDLING_CHAIN_COUNT,
		Kind.ORBITING_AXE_COUNT, Kind.MAUL_DROP_CUT_COUNT, Kind.RESCUE_CHARGES,
		Kind.MOMENTUM_MAX_STACKS,
	]
