class_name XPPacingConfig
extends Resource
## Central tuning surface for XP-orb and level-bar presentation. Gameplay XP
## amounts are owned by the run rewards and power-curve resources.

@export_group("XP orbs — PLACEHOLDER")
@export_range(1, 64, 1) var orb_minimum_count: int = 3
@export_range(1, 1000000, 1) var orb_reference_xp: int = 120
@export_range(1.01, 10.0, 0.01) var orb_logarithm_base: float = 2.0
@export_range(0.1, 20.0, 0.1) var orb_density: float = 3.0
@export_range(1, 128, 1) var orb_count_cap: int = 32
## Two maximum manual batches may overlap (routine completion plus grain). The
## resident pool is warmed to cover that authored concurrency without a hitch.
@export_range(1, 256, 1) var orb_pool_capacity: int = 64
@export_range(0.0, 2.0, 0.005) var capped_scale_growth: float = 0.035
@export_range(0.0, 4.0, 0.005) var capped_intensity_growth: float = 0.060
## Holds the completed bar long enough to establish cause and effect before the
## visible level rolls over. PLACEHOLDER pending a fresh-save feel pass.
@export_range(0.0, 1.0, 0.01) var level_up_bar_hold_seconds: float = 0.12

func orb_count_for_xp(final_xp: int) -> int:
	if final_xp <= 0:
		return 0
	var ratio := maxf(1.0, float(final_xp) / float(maxi(1, orb_reference_xp)))
	var growth := log(ratio) / log(maxf(1.01, orb_logarithm_base))
	return clampi(orb_minimum_count + int(floor(growth * orb_density)),
		orb_minimum_count, mini(orb_count_cap, orb_pool_capacity))


func capped_burst_growth(final_xp: int) -> float:
	if final_xp <= 0 or orb_count_for_xp(final_xp) < mini(orb_count_cap, orb_pool_capacity):
		return 0.0
	var ratio := maxf(1.0, float(final_xp) / float(maxi(1, orb_reference_xp)))
	return maxf(0.0, log(ratio) / log(maxf(1.01, orb_logarithm_base)))


func orb_shares_for_xp(final_xp: int) -> PackedInt32Array:
	var shares := PackedInt32Array()
	if final_xp <= 0:
		return shares
	var count := mini(orb_count_for_xp(final_xp), final_xp)
	shares.resize(count)
	var quotient := floori(float(final_xp) / float(count))
	var remainder := final_xp % count
	for index in range(count):
		shares[index] = quotient + (1 if index < remainder else 0)
	return shares


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if orb_count_cap < orb_minimum_count:
		errors.append("orb count cap is below the routine minimum")
	if orb_pool_capacity < orb_count_cap * 2:
		errors.append("orb pool cannot cover overlapping routine and grain maxima")
	if level_up_bar_hold_seconds < 0.0:
		errors.append("level-up bar hold cannot be negative")
	return errors
