class_name RunOfferTuning
extends Resource
## Explicit provisional quality weights and fallback reward values for run
## choices. Every eligible power identity is sampled uniformly. Quality is
## rolled separately for every card: it improves that pick's authored rank
## increment without ever granting more than one owned rank.

enum Quality { INVALID, COMMON, RARE, EPIC, LEGENDARY }


static func quality_display_name(quality: int) -> String:
	if quality < Quality.COMMON or quality > Quality.LEGENDARY:
		return ""
	return String(Quality.keys()[quality]).capitalize()


static func color_for_quality(quality: int) -> Color:
	match quality:
		Quality.RARE:
			return Color(0.18, 0.50, 0.80, 1.0)
		Quality.EPIC:
			return Color(0.62, 0.28, 0.78, 1.0)
		Quality.LEGENDARY:
			return Color(0.96, 0.68, 0.14, 1.0)
	return Color(0.58, 0.39, 0.18, 1.0)

@export_group("Per-card quality weights — PLACEHOLDER")
@export_range(0.0001, 1000.0, 0.0001) var common_quality_weight := 1.0
@export_range(0.0001, 1000.0, 0.0001) var rare_quality_weight := 0.20
@export_range(0.0001, 1000.0, 0.0001) var epic_quality_weight := 0.05
@export_range(0.0001, 1000.0, 0.0001) var legendary_quality_weight := 0.005

@export_group("Per-pick value multipliers — PLACEHOLDER")
@export_range(1.0, 100.0, 0.01) var common_quality_multiplier := 1.0
@export_range(1.0, 100.0, 0.01) var rare_quality_multiplier := 2.0
@export_range(1.0, 100.0, 0.01) var epic_quality_multiplier := 3.0
@export_range(1.0, 100.0, 0.01) var legendary_quality_multiplier := 4.0

@export_group("Payday fallback — PLACEHOLDER")
@export_range(1, 1000000, 1) var payday_base_cash := 10
@export_range(0, 1000000, 1) var payday_cash_per_level := 2
@export_range(0, 1000000, 1) var payday_cash_per_pick := 5

@export_multiline var tuning_status := \
	"PLACEHOLDER — card-quality odds/value multipliers and Payday cash require measured tuning approval"


func quality_weight_for(quality: Quality) -> float:
	match quality:
		Quality.COMMON:
			return common_quality_weight
		Quality.RARE:
			return rare_quality_weight
		Quality.EPIC:
			return epic_quality_weight
		Quality.LEGENDARY:
			return legendary_quality_weight
	return 0.0


func quality_multiplier_for(quality: Quality) -> float:
	match quality:
		Quality.COMMON:
			return common_quality_multiplier
		Quality.RARE:
			return rare_quality_multiplier
		Quality.EPIC:
			return epic_quality_multiplier
		Quality.LEGENDARY:
			return legendary_quality_multiplier
	return 0.0


func payday_amount(level: int, previous_picks: int) -> int:
	return maxi(1, payday_base_cash \
		+ maxi(0, level - 1) * payday_cash_per_level \
		+ maxi(0, previous_picks) * payday_cash_per_pick)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if common_quality_weight <= 0.0 or rare_quality_weight <= 0.0 \
			or epic_quality_weight <= 0.0 or legendary_quality_weight <= 0.0:
		errors.append("run offer quality weights must be positive")
	if not (legendary_quality_weight < epic_quality_weight \
			and epic_quality_weight < rare_quality_weight \
			and rare_quality_weight < common_quality_weight):
		errors.append("run offer quality weights must make Legendary the rarest tier")
	if not is_equal_approx(common_quality_multiplier, 1.0) \
			or rare_quality_multiplier <= common_quality_multiplier \
			or epic_quality_multiplier <= rare_quality_multiplier \
			or legendary_quality_multiplier <= epic_quality_multiplier:
		errors.append("run offer quality value multipliers must increase from Common to Legendary")
	if payday_base_cash <= 0 or payday_cash_per_level < 0 \
			or payday_cash_per_pick < 0:
		errors.append("run offer Payday values are invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("run offer tuning must remain explicitly provisional")
	return errors
