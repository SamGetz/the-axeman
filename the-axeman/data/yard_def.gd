class_name YardDef
extends Resource
## Immutable stage catalogue row. Yard one is the only live row in this slice;
## each selectable level owns one standalone YardDef `.tres`, and the schema
## deliberately carries future scene/unlock identities.

const MAX_DELIVERY_BATCH_SIZE := 100

@export_category("SELECTABLE LEVEL SETTINGS")
@export_group("Identity")
@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var scene_path := ""
@export_range(1.0, 86400.0, 1.0) var stage_duration_seconds := 900.0

@export_group("Timeline and ordinary rewards")
@export var species_timeline: Array[YardTimelineEntryDef] = []
@export var species_rewards: Array[YardSpeciesRewardDef] = []

@export_group("Log delivery curves by run level — PLACEHOLDER")
## Default plus the three tiers unlocked by Fall Frequency Control. These scale
## the interval curve: 1.0 is the authored curve, lower values fall faster.
@export var delivery_tier_interval_scales := PackedFloat64Array()
## X is the player's run level; Y is seconds between falling-log waves at the
## default frequency tier. Edit this native Curve directly in the Inspector.
@export var delivery_interval_seconds_by_level: Curve
## X is the player's run level; Y is logs spawned by each wave. Runtime samples
## whole levels and rounds Y to the nearest whole log.
@export var delivery_batch_size_by_level: Curve
## Safety floor after the selected frequency-tier scale is applied.
@export_range(0.05, 60.0, 0.05) var delivery_interval_floor := 0.5
## The final stage window and Endless can deliberately read the rightmost curve
## points, so their interval and amount remain curve-authored rather than code.
@export var force_curve_end_in_final_window := true
@export_range(1.0, 3600.0, 1.0) var final_pressure_remaining_seconds := 60.0
@export var force_curve_end_in_endless := true

@export_group("XP and hardness by run level — PLACEHOLDER")
## Index zero describes Level 1. The last authored row rolls into the endless tail.
@export var xp_to_next_by_level := PackedInt64Array()
@export var hardness_multiplier_by_level := PackedFloat64Array()
@export_range(1.0, 10.0, 0.01) var endless_xp_growth := 1.1
@export_range(0.01, 1.0, 0.001) var endless_delivery_multiplier_per_level := 0.98
@export_range(1.0, 10.0, 0.001) var endless_hardness_multiplier_per_level := 1.04

@export_group("Boss schedule")
@export var bosses: Array[YardBossDef] = []

@export_group("Future unlock metadata")
@export var prerequisite_yard_id: StringName = &""
@export_range(0, 999, 1) var prerequisite_clears := 0
@export var future_unlock_rule_id: StringName = &""

@export_multiline var tuning_status := \
	"PLACEHOLDER — yard-one pressure, rewards and roster require measured approval"

const _MAX_SAFE_RUN_XP := 1_000_000_000_000_000_000


func reward_for_species(species_id: StringName) -> YardSpeciesRewardDef:
	for reward: YardSpeciesRewardDef in species_rewards:
		if reward != null and reward.species_id == species_id:
			return reward
	return null


## Run levels are derived from disposable XP against the selected yard's authored
## curve. Index zero is the Level 1 -> 2 span; rows beyond the authored stage use
## the explicit endless multiplier without ever mutating this catalogue resource.
func xp_to_next(level: int) -> int:
	if xp_to_next_by_level.is_empty():
		return 1
	var safe_level := maxi(1, level)
	var index := safe_level - 1
	if index < xp_to_next_by_level.size():
		return maxi(1, int(xp_to_next_by_level[index]))
	var exponent := index - (xp_to_next_by_level.size() - 1)
	var scaled := float(xp_to_next_by_level[-1]) * pow(endless_xp_growth, exponent)
	if not is_finite(scaled) or scaled >= float(_MAX_SAFE_RUN_XP):
		return _MAX_SAFE_RUN_XP
	return clampi(int(round(scaled)), 1, _MAX_SAFE_RUN_XP)


func level_for_xp(total_xp: int) -> int:
	if xp_to_next_by_level.is_empty():
		return 1
	var remaining := clampi(total_xp, 0, _MAX_SAFE_RUN_XP)
	var level := 1
	for authored_span: int in xp_to_next_by_level:
		var span := maxi(1, authored_span)
		if remaining < span:
			return level
		remaining -= span
		level += 1
	if is_equal_approx(endless_xp_growth, 1.0):
		return level + int(remaining / maxi(1, int(xp_to_next_by_level[-1])))
	while remaining >= xp_to_next(level):
		remaining -= xp_to_next(level)
		level += 1
	return level


func total_xp_for_level(level: int) -> int:
	var wanted := maxi(1, level)
	var total := 0
	var authored_transitions := mini(wanted - 1, xp_to_next_by_level.size())
	for current_level: int in range(1, authored_transitions + 1):
		var span := xp_to_next(current_level)
		if total > _MAX_SAFE_RUN_XP - span:
			return _MAX_SAFE_RUN_XP
		total += span
	var endless_transitions := wanted - 1 - authored_transitions
	if endless_transitions <= 0:
		return total
	if is_equal_approx(endless_xp_growth, 1.0):
		var endless_span := xp_to_next(xp_to_next_by_level.size() + 1)
		if endless_span <= 0 \
				or endless_transitions > int((_MAX_SAFE_RUN_XP - total) / endless_span):
			return _MAX_SAFE_RUN_XP
		return total + endless_transitions * endless_span
	var offset := 0
	while offset < endless_transitions:
		var span := xp_to_next(xp_to_next_by_level.size() + 1 + offset)
		if total > _MAX_SAFE_RUN_XP - span:
			return _MAX_SAFE_RUN_XP
		total += span
		offset += 1
	return total


func progress_for_xp(total_xp: int) -> float:
	var safe_xp := clampi(total_xp, 0, _MAX_SAFE_RUN_XP)
	var level := level_for_xp(safe_xp)
	var level_start := total_xp_for_level(level)
	var span := xp_to_next(level)
	return clampf(float(safe_xp - level_start) / float(maxi(1, span)), 0.0, 1.0)


func xp_remaining_for_xp(total_xp: int) -> int:
	var safe_xp := clampi(total_xp, 0, _MAX_SAFE_RUN_XP)
	var level := level_for_xp(safe_xp)
	return maxi(1, total_xp_for_level(level) + xp_to_next(level) - safe_xp)


func delivery_interval_seconds(level: int, tier: int = 0,
		force_curve_end := false) -> float:
	if delivery_interval_seconds_by_level == null:
		return 1.0
	var curve := delivery_interval_seconds_by_level
	var safe_level := maxi(1, level)
	var sample_level := curve.max_domain if force_curve_end else clampf(
		float(safe_level), curve.min_domain, curve.max_domain)
	var seconds := maxf(0.0001, curve.sample(sample_level))
	if not force_curve_end and float(safe_level) > curve.max_domain:
		var tail_levels := safe_level - int(floor(curve.max_domain))
		seconds *= pow(endless_delivery_multiplier_per_level, tail_levels)
	var scale := 1.0
	if not delivery_tier_interval_scales.is_empty():
		var safe_tier := clampi(tier, 0,
			delivery_tier_interval_scales.size() - 1)
		scale = maxf(0.0001,
			float(delivery_tier_interval_scales[safe_tier]))
	return maxf(delivery_interval_floor, seconds * scale)


func delivery_batch_size(level: int, force_curve_end := false) -> int:
	if delivery_batch_size_by_level == null:
		return 1
	var curve := delivery_batch_size_by_level
	var sample_level := curve.max_domain if force_curve_end else clampf(
		float(maxi(1, level)), curve.min_domain, curve.max_domain)
	return clampi(int(round(curve.sample(sample_level))), 1,
		MAX_DELIVERY_BATCH_SIZE)


func hardness_multiplier(level: int) -> float:
	if hardness_multiplier_by_level.is_empty():
		return 1.0
	var index := maxi(0, level - 1)
	if index < hardness_multiplier_by_level.size():
		return maxf(0.0001, float(hardness_multiplier_by_level[index]))
	var tail_levels := index - (hardness_multiplier_by_level.size() - 1)
	return maxf(0.0001, float(hardness_multiplier_by_level[-1]) \
		* pow(endless_hardness_multiplier_per_level, tail_levels))


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or scene_path.strip_edges().is_empty():
		errors.append("yard identity, copy or scene path is incomplete")
	if stage_duration_seconds <= 0.0:
		errors.append("yard duration must be positive")
	if species_timeline.is_empty():
		errors.append("yard has no species timeline")
	var timeline_species: Dictionary = {}
	for entry: YardTimelineEntryDef in species_timeline:
		if entry == null:
			errors.append("yard timeline contains null")
			continue
		errors.append_array(entry.validate(stage_duration_seconds))
		timeline_species[entry.species_id] = true
	var reward_species: Dictionary = {}
	for reward: YardSpeciesRewardDef in species_rewards:
		if reward == null:
			errors.append("yard reward table contains null")
			continue
		errors.append_array(reward.validate())
		if reward_species.has(reward.species_id):
			errors.append("yard has duplicate species reward:%s" % reward.species_id)
		reward_species[reward.species_id] = true
	for raw_species: Variant in timeline_species:
		if not reward_species.has(raw_species):
			errors.append("yard timeline species has no fixed reward:%s" % raw_species)
	if delivery_tier_interval_scales.is_empty():
		errors.append("yard has no starting delivery tiers")
	var previous_scale := INF
	for scale: float in delivery_tier_interval_scales:
		if scale <= 0.0 or scale >= previous_scale:
			errors.append("yard delivery-tier scales must be positive and strictly faster")
		previous_scale = scale
	if delivery_interval_floor <= 0.0:
		errors.append("yard delivery interval floor must be positive")
	if delivery_interval_seconds_by_level == null \
			or delivery_interval_seconds_by_level.point_count < 2:
		errors.append("yard requires an editable delivery-interval curve")
	if delivery_batch_size_by_level == null \
			or delivery_batch_size_by_level.point_count < 2:
		errors.append("yard requires an editable delivery-amount curve")
	if force_curve_end_in_final_window \
			and (final_pressure_remaining_seconds <= 0.0 \
			or final_pressure_remaining_seconds >= stage_duration_seconds):
		errors.append("yard final-pressure curve window is invalid")
	var level_rows := xp_to_next_by_level.size()
	if level_rows <= 0 or hardness_multiplier_by_level.size() != level_rows:
		errors.append("yard XP and hardness rows must match")
	if delivery_interval_seconds_by_level != null \
			and (delivery_interval_seconds_by_level.min_domain > 1.0 \
			or delivery_interval_seconds_by_level.max_domain < float(level_rows)):
		errors.append("yard delivery-interval curve must cover every authored run level")
	if delivery_batch_size_by_level != null \
			and (delivery_batch_size_by_level.min_domain > 1.0 \
			or delivery_batch_size_by_level.max_domain < float(level_rows)):
		errors.append("yard delivery-amount curve must cover every authored run level")
	var previous_interval := INF
	var previous_batch := 0
	var previous_hardness := 0.0
	for index: int in range(level_rows):
		var xp := int(xp_to_next_by_level[index])
		var interval := delivery_interval_seconds(index + 1) \
			if delivery_interval_seconds_by_level != null else 1.0
		var batch := delivery_batch_size(index + 1) \
			if delivery_batch_size_by_level != null else 1
		var hardness := float(hardness_multiplier_by_level[index])
		if xp <= 0:
			errors.append("yard XP curve must remain positive")
		if interval <= 0.0 or interval > previous_interval:
			errors.append("yard delivery interval curve must not get slower at later levels")
		if batch <= 0 or batch < previous_batch:
			errors.append("yard delivery amount curve must not fall at later levels")
		if hardness <= 0.0 or hardness < previous_hardness:
			errors.append("yard hardness pressure must not fall at later levels")
		previous_interval = interval
		previous_batch = batch
		previous_hardness = hardness
	if endless_xp_growth < 1.0 or endless_delivery_multiplier_per_level <= 0.0 \
			or endless_delivery_multiplier_per_level > 1.0 \
			or endless_hardness_multiplier_per_level < 1.0:
		errors.append("yard endless tail multipliers are invalid")
	var boss_ids: Dictionary = {}
	var previous_boss_time := 0.0
	for boss: YardBossDef in bosses:
		if boss == null:
			errors.append("yard boss schedule contains null")
			continue
		errors.append_array(boss.validate(stage_duration_seconds))
		if boss_ids.has(boss.id):
			errors.append("yard has duplicate boss id:%s" % boss.id)
		if boss.scheduled_seconds <= previous_boss_time:
			errors.append("yard boss schedule must be strictly ordered")
		boss_ids[boss.id] = true
		previous_boss_time = boss.scheduled_seconds
	if prerequisite_yard_id == &"" and prerequisite_clears != 0:
		errors.append("yard has a clear prerequisite without a prerequisite yard")
	if prerequisite_yard_id != &"" and prerequisite_clears <= 0:
		errors.append("yard prerequisite must require a positive clear count")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("yard tuning must remain explicitly provisional")
	return errors
