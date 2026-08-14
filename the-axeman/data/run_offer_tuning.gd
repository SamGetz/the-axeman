class_name RunOfferTuning
extends Resource
## Explicit provisional weights and fallback reward values for run choices.
## Rarity remains a power identity; these values only affect offer frequency.

@export_group("Rarity weights — PLACEHOLDER")
@export_range(0.001, 1000.0, 0.001) var common_weight := 1.0
@export_range(0.001, 1000.0, 0.001) var rare_weight := 0.35
@export_range(0.001, 1000.0, 0.001) var epic_weight := 0.12

@export_group("Payday fallback — PLACEHOLDER")
@export_range(1, 1000000, 1) var payday_base_cash := 10
@export_range(0, 1000000, 1) var payday_cash_per_level := 2
@export_range(0, 1000000, 1) var payday_cash_per_pick := 5

@export_multiline var tuning_status := \
	"PLACEHOLDER — offer rarity weights and Payday cash require measured tuning approval"


func weight_for(rarity: RunPowerDef.Rarity) -> float:
	match rarity:
		RunPowerDef.Rarity.COMMON:
			return common_weight
		RunPowerDef.Rarity.RARE:
			return rare_weight
		RunPowerDef.Rarity.EPIC:
			return epic_weight
	return 0.0


func payday_amount(level: int, previous_picks: int) -> int:
	return maxi(1, payday_base_cash \
		+ maxi(0, level - 1) * payday_cash_per_level \
		+ maxi(0, previous_picks) * payday_cash_per_pick)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if common_weight <= 0.0 or rare_weight <= 0.0 or epic_weight <= 0.0:
		errors.append("run offer rarity weights must be positive")
	if payday_base_cash <= 0 or payday_cash_per_level < 0 \
			or payday_cash_per_pick < 0:
		errors.append("run offer Payday values are invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("run offer tuning must remain explicitly provisional")
	return errors
