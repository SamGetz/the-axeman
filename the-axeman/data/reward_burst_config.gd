class_name RewardBurstConfig
extends Resource
## Shared, presentation-only denomination planning for XP and cash receipts.
## Rewards are authoritative before this planner runs; every returned token is
## only a visual share and the shares always reconcile to the original integer.

enum Kind { XP, CASH }

@export_group("Tier unlocks — PLACEHOLDER")
@export var xp_tier_thresholds := PackedInt64Array([1, 120, 1000, 3000])
@export var cash_tier_thresholds := PackedInt64Array([1, 100, 1000, 10000])
@export var denomination_weights := PackedInt32Array([1, 10, 100, 1000])

@export_group("Tier presentation — PLACEHOLDER")
@export var xp_tier_colors := PackedColorArray([
	Color(0.55, 1.0, 0.42, 0.78),
	Color(0.30, 0.78, 1.0, 0.86),
	Color(0.76, 0.40, 1.0, 0.90),
	Color(1.0, 0.90, 0.42, 0.96),
])
@export var tier_scales := PackedFloat32Array([1.0, 1.18, 1.38, 1.68])
@export_range(1, 12, 1) var cash_tokens_per_receipt_cap := 6
@export var tuning_status := "PLACEHOLDER — measured reward feel pass required"


func tier_for_amount(kind: Kind, amount: int) -> int:
	if amount <= 0:
		return 0
	var thresholds := xp_tier_thresholds if kind == Kind.XP else cash_tier_thresholds
	var tier := 0
	for index in range(thresholds.size()):
		if amount >= thresholds[index]:
			tier = index
	return clampi(tier, 0, 3)


## Returns dictionaries shaped as {"amount": int, "tier": int}. The tier mix is
## deterministic: the highest unlocked tier leads, with a lower-denomination
## tail when the bounded token budget permits. Integer remainder is assigned to
## the leading tokens, so presentation can never lose XP/cash to rounding.
func plan_tokens(kind: Kind, amount: int, requested_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if amount <= 0 or requested_count <= 0:
		return result
	var count := mini(maxi(1, requested_count), amount)
	var highest := tier_for_amount(kind, amount)
	var tiers := PackedInt32Array()
	tiers.resize(count)
	for index in range(count):
		if highest == 0:
			tiers[index] = 0
		elif index == 0:
			tiers[index] = highest
		elif index % 4 == 3:
			tiers[index] = maxi(0, highest - 2)
		elif index % 3 == 2:
			tiers[index] = maxi(0, highest - 1)
		else:
			tiers[index] = highest

	var total_weight := 0
	for tier in tiers:
		total_weight += denomination_weights[clampi(tier, 0,
			denomination_weights.size() - 1)]
	var assigned := 0
	var weighted_unit := amount / maxi(1, total_weight)
	for index in range(count):
		var weight := denomination_weights[clampi(tiers[index], 0,
			denomination_weights.size() - 1)]
		# Divide before multiplying so MAX_SAFE_ECONOMY_VALUE cannot overflow int64.
		var share := maxi(1, int(weighted_unit * weight))
		# Reserve one unit for every later token.
		share = mini(share, amount - assigned - (count - index - 1))
		result.append({"amount": share, "tier": tiers[index]})
		assigned += share
	var remainder := amount - assigned
	var cursor := 0
	while remainder > 0:
		result[cursor % result.size()]["amount"] = int(
			result[cursor % result.size()]["amount"]) + 1
		remainder -= 1
		cursor += 1
	return result


func cash_token_count_for_amount(amount: int) -> int:
	if amount <= 0:
		return 0
	var magnitude := 1
	var remaining := amount
	while remaining >= 10:
		remaining /= 10
		magnitude += 1
	return clampi(magnitude, 1, cash_tokens_per_receipt_cap)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for thresholds: PackedInt64Array in [xp_tier_thresholds, cash_tier_thresholds]:
		if thresholds.size() != 4 or thresholds[0] != 1:
			errors.append("reward tier thresholds must contain four rows beginning at one")
			continue
		for index in range(1, thresholds.size()):
			if thresholds[index] <= thresholds[index - 1]:
				errors.append("reward tier thresholds must increase strictly")
	if denomination_weights.size() != 4 or xp_tier_colors.size() != 4 \
			or tier_scales.size() != 4:
		errors.append("all reward presentation arrays must define four tiers")
	if cash_tokens_per_receipt_cap < 1:
		errors.append("cash token cap must be positive")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("reward presentation tuning must remain provisional")
	return errors
