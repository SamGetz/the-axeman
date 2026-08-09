class_name XPPacingConfig
extends Resource
## Central tuning surface for XP cadence, level cash, and XP-orb presentation.
## Fields explicitly labelled PLACEHOLDER still await measured Compatibility
## sessions; Masterwork values are finalized with the skill-tree balance pass.

@export_group("Acceptance anchors — PLACEHOLDER")
@export_range(1.0, 60.0, 0.5) var opening_target_logs_per_level: float = 4.0
@export_range(1.0, 100.0, 0.5) var terrestrial_end_target_logs_per_level: float = 14.0
## Derived from the campaign-calibrated plateau span and Cinderheart's authored
## XP. This remains a placeholder until the uninterrupted fresh-save review.
@export_range(60.0, 3600.0, 1.0) var final_frontier_target_seconds: float = 114.0
@export_range(1.0, 180.0, 0.5) var expected_active_seconds_per_endgame_log: float = 42.0
@export var representative_terrestrial_levels := PackedInt32Array([
	1, 3, 6, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45,
	49, 53, 57, 61, 65, 69, 73, 77, 81, 86, 91, 96])
@export var representative_terrestrial_active_seconds := PackedFloat32Array([
	42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42, 42,
	42, 42, 42, 42, 42, 42, 42, 42, 42, 42.5, 43.5, 44.5])
@export var representative_alien_levels := PackedInt32Array([101, 106, 111])
@export var representative_alien_active_seconds := PackedFloat32Array([55.0, 60.0, 70.0])

@export_group("Level cash — PLACEHOLDER")
@export_range(0.01, 10.0, 0.01) var level_cash_load_fraction: float = 0.20

@export_group("Global XP playtest — PLACEHOLDER")
## Neutral by default. This scales every genuine XP award before skill bonuses,
## so pacing sessions can compare speeds without rewriting individual woods.
@export_range(0.10, 10.0, 0.05) var global_xp_multiplier: float = 1.0

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

@export_group("Masterwork — FINAL")
@export_range(0.0, 5.0, 0.01) var masterwork_xp_bonus: float = 0.50
@export_range(0.0, 10.0, 0.01) var masterwork_cash_units: float = 2.0


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
	if final_frontier_target_seconds <= 0.0 or expected_active_seconds_per_endgame_log <= 0.0:
		errors.append("XP pacing time anchors must be positive")
	if not is_finite(global_xp_multiplier) or global_xp_multiplier <= 0.0:
		errors.append("global XP playtest multiplier must be positive and finite")
	if representative_terrestrial_levels.size() != SpeciesTable.count():
		errors.append("terrestrial representative levels do not cover the species table")
	if representative_terrestrial_active_seconds.size() != SpeciesTable.count():
		errors.append("terrestrial active-time anchors do not cover the species table")
	if representative_alien_levels.size() != AlienCampaign.traits().size() \
			or representative_alien_active_seconds.size() != AlienCampaign.traits().size():
		errors.append("alien representative anchors do not cover the alien table")
	return errors
