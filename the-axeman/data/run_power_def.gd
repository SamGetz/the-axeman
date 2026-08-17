class_name RunPowerDef
extends Resource
## Immutable identity and fixed authored rank ladder for one temporary power.
## Power identities have no rarity or offer-frequency tier. Upgrade quality is
## rolled separately for each offered rank.

enum Pool { INVALID, CORE, BLUEPRINT }

@export_group("Identity and copy")
@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var pool: Pool = Pool.INVALID
@export_range(1, 99, 1) var rank_cap := 1

@export_group("Authored effects and presentation")
@export var effects: Array[ProgressionEffectDef] = []
@export var icon_path := ""
@export var vfx_path := ""
@export_multiline var tuning_status := \
	"PLACEHOLDER — run-power rank values and cadence require measured tuning approval"


func effect_value(effect_kind: ProgressionEffectDef.Kind, rank: int) -> float:
	for effect: ProgressionEffectDef in effects:
		if effect != null and effect.kind == effect_kind:
			return effect.value_at_rank(clampi(rank, 0, rank_cap))
	return 0.0


## Quality scales each owned rank's authored delta. Increasing effects extend
## beyond the ordinary Common ladder; decreasing positive effects compound their
## authored ratios so boosted intervals/multipliers stay positive and useful.
func effect_value_for_pick_multipliers(effect_kind: ProgressionEffectDef.Kind,
		pick_multipliers: Array[float]) -> float:
	for effect: ProgressionEffectDef in effects:
		if effect != null and effect.kind == effect_kind:
			return _quality_adjusted_effect_value(effect, pick_multipliers)
	return 0.0


func effect_summary_for_owned_pick_multipliers(
		pick_multipliers: Array[float]) -> String:
	var parts := PackedStringArray()
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			continue
		parts.append("%s %s" % [_effect_label(effect.kind),
			_format_effect_value(effect,
				_quality_adjusted_effect_value(effect, pick_multipliers))])
	return " · ".join(parts)


## Exact previous -> next text for one quality-weighted offer card. The pick
## still grants exactly one owned rank; only that rank's authored delta changes.
func effect_summary_for_pick_multipliers(
		existing_pick_multipliers: Array[float],
		next_quality_multiplier: float) -> String:
	var next_picks := existing_pick_multipliers.duplicate()
	if next_picks.size() < rank_cap:
		next_picks.append(maxf(1.0, next_quality_multiplier))
	var parts := PackedStringArray()
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			continue
		var previous_value := _quality_adjusted_effect_value(effect,
			existing_pick_multipliers)
		var next_value := _quality_adjusted_effect_value(effect, next_picks)
		parts.append("%s %s→%s" % [_effect_label(effect.kind),
			_format_effect_value(effect, previous_value),
			_format_effect_value(effect, next_value)])
	return " · ".join(parts)


## Exact authored values for one offer card. `previous_rank == 0` describes a
## first acquisition; later ranks show the cumulative value changing in place.
## Formatting lives with the typed definition so Home, HUD and future tooltips do
## not grow independent guesses about whether a value is a count, duration,
## distance, percentage or multiplier.
func effect_summary_for_rank(rank: int, previous_rank: int = 0) -> String:
	var safe_rank := clampi(rank, 1, rank_cap)
	var safe_previous := clampi(previous_rank, 0, safe_rank - 1)
	var parts := PackedStringArray()
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			continue
		var next_value := effect.value_at_rank(safe_rank)
		var value_text := _format_effect_value(effect, next_value)
		if safe_previous > 0:
			var previous_value := effect.value_at_rank(safe_previous)
			value_text = "%s→%s" % [
				_format_effect_value(effect, previous_value), value_text]
		parts.append("%s %s" % [_effect_label(effect.kind), value_text])
	return " · ".join(parts)


static func _effect_label(kind: ProgressionEffectDef.Kind) -> String:
	match kind:
		ProgressionEffectDef.Kind.SPLIT_RELIABILITY: return "Split"
		ProgressionEffectDef.Kind.SWING_RECOVERY: return "Recovery"
		ProgressionEffectDef.Kind.SCAR_RELIABILITY: return "Scar"
		ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER: return "Run XP"
		ProgressionEffectDef.Kind.SESSION_CASH_MULTIPLIER: return "Cash"
		ProgressionEffectDef.Kind.BOUNDARY_RADIUS: return "Ring radius"
		ProgressionEffectDef.Kind.BOUNDARY_GRACE: return "Grace"
		ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS: return "Extra cuts"
		ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE: return "Chance"
		ProgressionEffectDef.Kind.FOLLOW_UP_DEPTH: return "Repeats"
		ProgressionEffectDef.Kind.SPLINTER_COUNT: return "Splits"
		ProgressionEffectDef.Kind.FLYING_WEDGE_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.FLYING_WEDGE_CUT_COUNT: return "Cuts"
		ProgressionEffectDef.Kind.YARD_MAGNET_FORCE: return "Pull"
		ProgressionEffectDef.Kind.YARD_MAGNET_PULSE_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.ARRIVAL_LATERAL_MULTIPLIER: return "Lateral"
		ProgressionEffectDef.Kind.ARRIVAL_BOUNCE_MULTIPLIER: return "Bounce"
		ProgressionEffectDef.Kind.ARRIVAL_OUTWARD_MULTIPLIER: return "Outward"
		ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE: return "Mark chance"
		ProgressionEffectDef.Kind.GRAIN_BONUS_XP_MULTIPLIER: return "Marked XP"
		ProgressionEffectDef.Kind.EARTHSHAKER_TRIGGER_CUTS: return "Trigger"
		ProgressionEffectDef.Kind.EARTHSHAKER_RADIUS: return "Radius"
		ProgressionEffectDef.Kind.EARTHSHAKER_INWARD_FORCE: return "Pull"
		ProgressionEffectDef.Kind.POWDER_KEG_RADIUS: return "Radius"
		ProgressionEffectDef.Kind.POWDER_KEG_CUT_COUNT: return "Cuts"
		ProgressionEffectDef.Kind.POWDER_KEG_INWARD_FORCE: return "Pull"
		ProgressionEffectDef.Kind.KINDLING_CHAIN_COUNT: return "Chains"
		ProgressionEffectDef.Kind.KINDLING_CHAIN_RANGE: return "Range"
		ProgressionEffectDef.Kind.ORBITING_AXE_COUNT: return "Axes"
		ProgressionEffectDef.Kind.ORBITING_AXE_CONTACT_COOLDOWN: return "Contact"
		ProgressionEffectDef.Kind.CROSSCUT_SWEEP_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.CROSSCUT_SWEEP_WIDTH: return "Width"
		ProgressionEffectDef.Kind.MAUL_DROP_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.MAUL_DROP_CUT_COUNT: return "Cuts"
		ProgressionEffectDef.Kind.SPLITTER_RIG_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.CANT_HOOK_FORCE: return "Pull"
		ProgressionEffectDef.Kind.STUMP_PULSE_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.STUMP_PULSE_FORCE: return "Pull"
		ProgressionEffectDef.Kind.RESCUE_CHARGES: return "Rescues"
		ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS: return "Max stacks"
		ProgressionEffectDef.Kind.MOMENTUM_SPEED_PER_STACK: return "Speed/stack"
		ProgressionEffectDef.Kind.MOMENTUM_RELIABILITY_PER_STACK: return "Split/stack"
		ProgressionEffectDef.Kind.AREA_SIZE_MULTIPLIER: return "Area size"
		ProgressionEffectDef.Kind.SAWBLADE_HALO_INTERVAL: return "Every"
		ProgressionEffectDef.Kind.SAWBLADE_HALO_RADIUS: return "Radius"
		ProgressionEffectDef.Kind.TIMBER_BURST_RADIUS: return "Radius"
	return String(ProgressionEffectDef.Kind.keys()[int(kind)]).capitalize()


static func _format_effect_value(effect: ProgressionEffectDef, value: float) -> String:
	if effect.operation == ProgressionEffectDef.Operation.ENABLE:
		return "ON" if value >= 1.0 else "OFF"
	if effect.operation == ProgressionEffectDef.Operation.MULTIPLY \
			or effect.kind in [
				ProgressionEffectDef.Kind.ARRIVAL_LATERAL_MULTIPLIER,
				ProgressionEffectDef.Kind.ARRIVAL_BOUNCE_MULTIPLIER,
				ProgressionEffectDef.Kind.ARRIVAL_OUTWARD_MULTIPLIER,
			]:
		return "×%s" % _decimal(value, 3)
	if effect.kind in [
			ProgressionEffectDef.Kind.SPLIT_RELIABILITY,
			ProgressionEffectDef.Kind.SWING_RECOVERY,
			ProgressionEffectDef.Kind.SCAR_RELIABILITY,
			ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE,
			ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE,
			ProgressionEffectDef.Kind.MOMENTUM_SPEED_PER_STACK,
			ProgressionEffectDef.Kind.MOMENTUM_RELIABILITY_PER_STACK,
		]:
		return "+%s%%" % _decimal(value * 100.0, 2)
	if effect.kind in [
			ProgressionEffectDef.Kind.BOUNDARY_GRACE,
			ProgressionEffectDef.Kind.FLYING_WEDGE_INTERVAL,
			ProgressionEffectDef.Kind.ORBITING_AXE_CONTACT_COOLDOWN,
			ProgressionEffectDef.Kind.CROSSCUT_SWEEP_INTERVAL,
			ProgressionEffectDef.Kind.MAUL_DROP_INTERVAL,
			ProgressionEffectDef.Kind.SPLITTER_RIG_INTERVAL,
			ProgressionEffectDef.Kind.STUMP_PULSE_INTERVAL,
			ProgressionEffectDef.Kind.YARD_MAGNET_PULSE_INTERVAL,
			ProgressionEffectDef.Kind.SAWBLADE_HALO_INTERVAL,
		]:
		return "%ss" % _decimal(value, 3)
	if effect.kind in [
			ProgressionEffectDef.Kind.BOUNDARY_RADIUS,
			ProgressionEffectDef.Kind.EARTHSHAKER_RADIUS,
			ProgressionEffectDef.Kind.POWDER_KEG_RADIUS,
			ProgressionEffectDef.Kind.KINDLING_CHAIN_RANGE,
			ProgressionEffectDef.Kind.CROSSCUT_SWEEP_WIDTH,
			ProgressionEffectDef.Kind.SAWBLADE_HALO_RADIUS,
			ProgressionEffectDef.Kind.TIMBER_BURST_RADIUS,
		]:
		return "%sm" % _decimal(value, 3)
	if effect.operation == ProgressionEffectDef.Operation.SET \
			and is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return _decimal(value, 3)


func _quality_adjusted_effect_value(effect: ProgressionEffectDef,
		pick_multipliers: Array[float]) -> float:
	# Flying Wedge always carries one authored six-cut removal payload. Rank and
	# quality improve its separate interval effect; multiplying the payload would
	# silently turn one wedge into several deleted roots.
	if effect.kind == ProgressionEffectDef.Kind.FLYING_WEDGE_CUT_COUNT:
		return effect.value_at_rank(mini(rank_cap, pick_multipliers.size()))
	var neutral := _neutral_effect_value(effect)
	var value := neutral
	var previous_authored := neutral
	var decreases := effect.value_at_rank(rank_cap) < neutral
	var picked_ranks := mini(rank_cap, pick_multipliers.size())
	for rank_index: int in range(picked_ranks):
		var authored := effect.value_at_rank(rank_index + 1)
		var multiplier := maxf(1.0, float(pick_multipliers[rank_index]))
		if decreases and value > 0.0 and previous_authored > 0.0 \
				and authored >= 0.0:
			# Exponentiating the authored reduction ratio reproduces the exact
			# Common ladder at ×1 while stronger qualities can never cross zero.
			value *= pow(maxf(0.000001, authored / previous_authored), multiplier)
		else:
			value += (authored - previous_authored) * multiplier
		previous_authored = authored
	if ProgressionEffectDef._is_count_kind(effect.kind):
		if effect.value_at_rank(rank_cap) > neutral:
			value = ceilf(value - 0.000001)
		elif effect.value_at_rank(rank_cap) < neutral:
			value = floorf(value + 0.000001)
		else:
			value = round(value)
	return _clamp_effect_domain(effect, value)


func _neutral_effect_value(effect: ProgressionEffectDef) -> float:
	if effect.operation == ProgressionEffectDef.Operation.MULTIPLY:
		return 1.0
	if effect.operation != ProgressionEffectDef.Operation.SET:
		return 0.0
	if _lower_is_better(effect.kind):
		var first := effect.value_at_rank(1)
		if rank_cap <= 1:
			return first
		var second := effect.value_at_rank(2)
		return first + maxf(0.0, first - second)
	if rank_cap > 1:
		var first := effect.value_at_rank(1)
		var second := effect.value_at_rank(2)
		if second < first:
			return first + (first - second)
	return 0.0


static func _lower_is_better(kind: ProgressionEffectDef.Kind) -> bool:
	return kind in [
		ProgressionEffectDef.Kind.ARRIVAL_LATERAL_MULTIPLIER,
		ProgressionEffectDef.Kind.ARRIVAL_BOUNCE_MULTIPLIER,
		ProgressionEffectDef.Kind.ARRIVAL_OUTWARD_MULTIPLIER,
		ProgressionEffectDef.Kind.EARTHSHAKER_TRIGGER_CUTS,
		ProgressionEffectDef.Kind.FLYING_WEDGE_INTERVAL,
		ProgressionEffectDef.Kind.ORBITING_AXE_CONTACT_COOLDOWN,
		ProgressionEffectDef.Kind.CROSSCUT_SWEEP_INTERVAL,
		ProgressionEffectDef.Kind.MAUL_DROP_INTERVAL,
		ProgressionEffectDef.Kind.SPLITTER_RIG_INTERVAL,
		ProgressionEffectDef.Kind.STUMP_PULSE_INTERVAL,
		ProgressionEffectDef.Kind.YARD_MAGNET_PULSE_INTERVAL,
		ProgressionEffectDef.Kind.SAWBLADE_HALO_INTERVAL,
	]


static func _clamp_effect_domain(effect: ProgressionEffectDef, value: float) -> float:
	const MAX_VALUE := 1000000.0
	if effect.operation == ProgressionEffectDef.Operation.ENABLE:
		return 1.0 if value >= 0.5 else 0.0
	if effect.kind in [
		ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE,
		ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE,
	]:
		return clampf(value, 0.0, 1.0)
	# Chopping's authored recovery reduction has a hard 0.8 ceiling before the
	# minimum swing-time floor. Keep cards and exact-value headroom on that same
	# intrinsic domain so a high-quality Quick Hands rank can never be a no-op.
	if effect.kind == ProgressionEffectDef.Kind.SWING_RECOVERY:
		return clampf(value, 0.0, 0.8)
	if effect.kind == ProgressionEffectDef.Kind.EARTHSHAKER_TRIGGER_CUTS:
		return clampf(value, 1.0, MAX_VALUE)
	if _lower_is_better(effect.kind) \
			or effect.operation == ProgressionEffectDef.Operation.MULTIPLY:
		return clampf(value, 0.001, MAX_VALUE)
	if ProgressionEffectDef._is_count_kind(effect.kind):
		return clampf(value, 0.0, MAX_VALUE)
	return clampf(value, -MAX_VALUE, MAX_VALUE)


static func _decimal(value: float, places: int) -> String:
	var text := ("%%.%df" % places) % value
	while text.contains(".") and text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty():
		errors.append("run power identity or copy is incomplete")
	if pool < Pool.CORE or pool > Pool.BLUEPRINT:
		errors.append("run power has an invalid pool")
	if rank_cap <= 0:
		errors.append("run power has an invalid rank cap")
	if effects.is_empty():
		errors.append("run power has no typed effects")
	var kinds: Dictionary = {}
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			errors.append("run power contains a null effect")
			continue
		if kinds.has(effect.kind):
			errors.append("run power contains a duplicate effect kind:%d" % effect.kind)
		kinds[effect.kind] = true
		errors.append_array(effect.validate(rank_cap))
	if icon_path.strip_edges().is_empty() or vfx_path.strip_edges().is_empty():
		errors.append("run power is missing provisional icon or VFX paths")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("run-power tuning must remain explicitly provisional")
	return errors
