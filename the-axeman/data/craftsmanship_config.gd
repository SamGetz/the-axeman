class_name CraftsmanshipConfig
extends Resource
## Provisional geometry-to-grade and value rules for forgiving manual craft.

@export_range(0.01, 1.0, 0.01) var target_piece_fraction := 0.25
@export_range(0.0, 1.0, 0.01) var clean_tolerance := 0.10
@export_range(0.0, 1.0, 0.01) var exceptional_tolerance := 0.04
@export_range(0.0, 10.0, 0.01) var clean_cash_bonus := 0.10
@export_range(0.0, 10.0, 0.01) var exceptional_cash_bonus := 0.25
@export var tuning_status := "PLACEHOLDER — M7B measured craftsmanship tuning required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_piece_fraction <= 0.0 or target_piece_fraction > 1.0:
		errors.append("target piece fraction must be in (0, 1]")
	if exceptional_tolerance < 0.0 or clean_tolerance < exceptional_tolerance:
		errors.append("exceptional tolerance must fit inside clean tolerance")
	if clean_cash_bonus < 0.0 or exceptional_cash_bonus < clean_cash_bonus:
		errors.append("craft cash bonuses must be monotonic")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("craftsmanship tuning must remain explicitly provisional")
	return errors
