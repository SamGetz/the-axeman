class_name LevelCurve
extends Resource
## Uncapped, authored XP curve. Levels rise smoothly until the configured
## endgame level, then use a repeatable plateau span forever.

## Every value in this resource remains a tuning placeholder until the pacing
## probe and representative Compatibility play session are approved.
@export_group("Opening cadence — PLACEHOLDER")
@export_range(1, 20, 1) var opening_levels: int = 9
@export_range(0.1, 1.0, 0.01) var opening_scale: float = 0.42

@export_group("Terrestrial ramp — PLACEHOLDER")
@export_range(1, 100000, 1) var base_xp: int = 26
@export_range(1.0, 3.0, 0.01) var curve_power: float = 1.30

@export_group("Infinite endgame — PLACEHOLDER")
@export_range(10, 500, 1) var endgame_plateau_level: int = 112

var _thresholds: PackedInt64Array = PackedInt64Array()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if opening_levels < 1 or opening_levels > endgame_plateau_level:
		errors.append("opening levels must fit inside the authored curve")
	if opening_scale <= 0.0 or opening_scale > 1.0:
		errors.append("opening scale must be in (0, 1]")
	if base_xp <= 0 or curve_power < 1.0:
		errors.append("terrestrial curve inputs are invalid")
	if endgame_plateau_level < 2:
		errors.append("endgame plateau must begin at level two or later")
	return errors


func xp_to_next(level: int) -> int:
	if level < 1:
		return 0
	var authored_level := mini(level, maxi(2, endgame_plateau_level))
	var span := float(base_xp) * pow(float(authored_level), curve_power)
	if authored_level <= opening_levels:
		var opening_t := float(authored_level - 1) / float(maxi(1, opening_levels - 1))
		span *= lerpf(opening_scale, 1.0, opening_t)
	return maxi(1, int(round(span)))


func total_xp_for_level(level: int) -> int:
	var wanted := maxi(1, level)
	_ensure_thresholds()
	var plateau := maxi(2, endgame_plateau_level)
	if wanted <= plateau:
		return int(_thresholds[wanted - 1])
	var plateau_total := int(_thresholds[plateau - 1])
	return plateau_total + (wanted - plateau) * xp_to_next(plateau)


func level_for_xp(total_xp: int) -> int:
	var safe_xp := maxi(0, total_xp)
	_ensure_thresholds()
	var plateau := maxi(2, endgame_plateau_level)
	var plateau_total := int(_thresholds[plateau - 1])
	if safe_xp >= plateau_total:
		return plateau + int((safe_xp - plateau_total) / xp_to_next(plateau))
	var low := 0
	var high := _thresholds.size() - 1
	while low <= high:
		var mid: int = (low + high) >> 1
		if int(_thresholds[mid]) <= safe_xp:
			low = mid + 1
		else:
			high = mid - 1
	return high + 1


func progress_through_level(total_xp: int) -> float:
	var level := level_for_xp(total_xp)
	var floor_xp := total_xp_for_level(level)
	var span := xp_to_next(level)
	return clampf(float(maxi(0, total_xp) - floor_xp) / float(maxi(1, span)), 0.0, 1.0)


func xp_remaining(total_xp: int) -> int:
	var level := level_for_xp(total_xp)
	return maxi(0, total_xp_for_level(level + 1) - maxi(0, total_xp))


func _ensure_thresholds() -> void:
	var plateau := maxi(2, endgame_plateau_level)
	if _thresholds.size() == plateau:
		return
	_thresholds = PackedInt64Array()
	_thresholds.resize(plateau)
	var running: int = 0
	_thresholds[0] = 0
	for level in range(1, plateau):
		running += xp_to_next(level)
		_thresholds[level] = running
