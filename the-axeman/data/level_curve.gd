class_name LevelCurve
extends Resource
## FILE: res://data/level_curve.gd
## ATTACHES TO: nothing. The single instance is res://data/level_curve.tres,
## read through GameState (which owns XP) and the HUD's XP bar.
##
## HOW MUCH CHOPPING A LEVEL COSTS. Sam's rules, 2026-08-02: the player levels to
## a **max of 99**, and **higher levels require more XP**.
##
## THE LEVEL IS DERIVED FROM TOTAL XP, never stored — the same principle the wood
## ladder used before it became a shop: XP is monotonic (nothing takes it away),
## so a level computed from it cannot disagree with it, there is no second field
## to drift, and **retuning this curve re-levels an existing save** instead of
## leaving it on thresholds that no longer exist.
##
## `MAX_LEVEL = 99` IS SAM'S. Everything else here is a PLACEHOLDER per Directive
## 3: the shape is a defensible curve, not a signed-off one, and it wants tuning
## against real play once the orbs are landing.

## Sam's number. Level 1 is where every player starts, so there are 98 levels to
## earn and 98 skill points to spend if a level grants one.
const MAX_LEVEL := 99

## XP to get from level 1 to level 2. PLACEHOLDER.
@export var base_xp: int = 40
## How steeply the cost climbs. `xp_to_next(L) = base_xp * L^curve_power`, so a
## power of 1 is linear and anything above it makes late levels bite. PLACEHOLDER.
@export var curve_power: float = 1.8

## Cumulative XP needed to REACH each level, index 0 = level 1 = 0 XP. Built once
## on first use rather than authored: 99 hand-written thresholds would be 99
## chances to fat-finger a number, and the shape is the thing being tuned, not the
## individual rungs.
var _thresholds: PackedInt64Array = PackedInt64Array()


## XP to climb from `level` to `level + 1`. 0 at the cap — there is nowhere to go.
func xp_to_next(level: int) -> int:
	if level < 1 or level >= MAX_LEVEL:
		return 0
	return int(round(float(base_xp) * pow(float(level), curve_power)))


## Total XP at which `level` is reached. Level 1 is 0.
func total_xp_for_level(level: int) -> int:
	_ensure_thresholds()
	var i := clampi(level, 1, MAX_LEVEL) - 1
	return int(_thresholds[i])


## The level `total_xp` buys, clamped to [1, MAX_LEVEL].
func level_for_xp(total_xp: int) -> int:
	_ensure_thresholds()
	# Walk from the top: the common case late on is a high level, and the array is
	# 99 entries, so a scan is cheaper than it looks and needs no bookkeeping.
	for i in range(_thresholds.size() - 1, -1, -1):
		if total_xp >= int(_thresholds[i]):
			return i + 1
	return 1


## Progress through the CURRENT level as 0..1. Returns 1.0 at the cap, so a bar
## bound to it reads full rather than empty when there is nothing left to earn.
func progress_through_level(total_xp: int) -> float:
	var level := level_for_xp(total_xp)
	if level >= MAX_LEVEL:
		return 1.0
	var floor_xp := total_xp_for_level(level)
	var span := total_xp_for_level(level + 1) - floor_xp
	if span <= 0:
		return 1.0
	return clampf(float(total_xp - floor_xp) / float(span), 0.0, 1.0)


## XP still to earn before the next level. 0 at the cap.
func xp_remaining(total_xp: int) -> int:
	var level := level_for_xp(total_xp)
	if level >= MAX_LEVEL:
		return 0
	return maxi(0, total_xp_for_level(level + 1) - total_xp)


func _ensure_thresholds() -> void:
	if _thresholds.size() == MAX_LEVEL:
		return
	_thresholds = PackedInt64Array()
	_thresholds.resize(MAX_LEVEL)
	var running := 0
	_thresholds[0] = 0
	for level in range(1, MAX_LEVEL):
		running += xp_to_next(level)
		_thresholds[level] = running
