class_name RunVfxConfig
extends Resource
## Presentation-only tuning for run powers, XP splinters, and level-up.
## Every value remains a labelled PLACEHOLDER until a measured Compatibility
## feel session approves it. Gameplay outcomes never depend on this resource.

@export_group("Shared run-power language — PLACEHOLDER")
@export var proc_light_range := 1.25
@export var proc_log_base_clearance := 0.025
@export var generic_duration := 0.58
@export var generic_light_energy := 0.9

@export_group("Run-power 3D props — PLACEHOLDER")
## Uniform multiplier over every authored emblem envelope in
## RunPowerPropLibrary. The per-power proportions are authored there; this only
## scales the whole announcement against the yard.
@export var prop_scale := 1.15
## Height of the emblem above the trigger point, so a prop reads clear of the
## root or stump that produced it instead of intersecting it.
@export var prop_ground_clearance := 0.46
@export var prop_rise := 0.16
@export_range(0.02, 0.9, 0.01) var prop_pop_fraction := 0.24
@export var prop_spin_turns := 0.35
@export var prop_label_height := 0.80

@export_group("Destroyed-log tally — PLACEHOLDER")
## One real billet per destroyed log. The ceiling only bounds pathological
## counts; every authored ladder sits far below it.
@export_range(1, 32, 1) var prop_tally_max := 16
@export var prop_tally_radius := 0.44
@export var prop_tally_rise := 0.34

@export_group("Splinter Volley projectile — PLACEHOLDER")
@export var splinter_projectile_size := Vector3(0.055, 0.055, 0.34)
@export var splinter_projectile_height := 0.14
@export_range(0.0, 1.0, 0.01) var splinter_projectile_white_mix := 0.28
@export var splinter_projectile_emission_energy := 1.6

@export_group("Level-up golden shower — PLACEHOLDER")
@export var level_duration := 1.45
@export_range(1, 24, 1) var level_ray_count := 10
@export_range(1, 48, 1) var level_spark_count := 18
@export_range(1, 192, 1) var level_ember_count := 92
@export_range(1, 96, 1) var level_glow_particle_count := 26
@export var level_cloud_radius := 0.22
@export var level_particle_speed_min := 0.7
@export var level_particle_speed_max := 1.85
@export var level_ray_height := 0.72
@export var level_ray_width := 0.08
@export_range(1, 24, 1) var level_pine_count := 10
@export var level_pine_height := 0.16
@export var level_pine_width := 0.11
@export var level_crown_radius := 0.46
@export_range(0.0, 1.0, 0.01) var level_ray_alpha := 0.40
@export_range(0.0, 1.0, 0.01) var level_core_alpha := 0.50
@export_range(0.0, 1.0, 0.01) var level_smooth_glow_alpha := 0.20
@export var level_spark_speed_min := 1.25
@export var level_spark_speed_max := 2.0
@export var level_light_energy := 1.1
@export var level_light_range_multiplier := 3.0

@export_group("Level-up offer rain — PLACEHOLDER")
@export_range(3, 60, 1) var level_offer_rain_count := 27
@export_range(8.0, 48.0, 1.0) var level_offer_rain_size_min := 14.0
@export_range(8.0, 64.0, 1.0) var level_offer_rain_size_max := 28.0
@export_range(10.0, 240.0, 1.0) var level_offer_rain_speed_min := 52.0
@export_range(10.0, 300.0, 1.0) var level_offer_rain_speed_max := 105.0
@export_range(-80.0, 80.0, 1.0) var level_offer_rain_drift_min := -20.0
@export_range(-80.0, 80.0, 1.0) var level_offer_rain_drift_max := 20.0
@export_range(0.0, 4.0, 0.05) var level_offer_rain_spin_min := 0.25
@export_range(0.0, 6.0, 0.05) var level_offer_rain_spin_max := 1.25
@export_range(0.0, 1.0, 0.01) var level_offer_rain_opacity := 0.18

@export var tuning_status := "PLACEHOLDER — measured particle VFX feel pass required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for duration: float in [generic_duration, level_duration]:
		if duration <= 0.0:
			errors.append("run VFX durations must be positive")
			break
	for count: int in [prop_tally_max, level_ray_count, level_spark_count,
			level_ember_count, level_glow_particle_count, level_pine_count,
			level_offer_rain_count]:
		if count <= 0:
			errors.append("run VFX particle counts must be positive")
			break
	if prop_scale <= 0.0 or proc_light_range <= 0.0 \
			or proc_log_base_clearance < 0.0 \
			or prop_ground_clearance < 0.0 or prop_rise < 0.0 \
			or prop_label_height <= 0.0 or prop_tally_radius <= 0.0 \
			or prop_tally_rise < 0.0 \
			or splinter_projectile_size.x <= 0.0 \
			or splinter_projectile_size.y <= 0.0 \
			or splinter_projectile_size.z <= 0.0 \
			or splinter_projectile_height < 0.0 \
			or splinter_projectile_emission_energy <= 0.0 \
			or level_cloud_radius <= 0.0 \
			or level_ray_height <= 0.0 or level_ray_width <= 0.0 \
			or level_pine_height <= 0.0 or level_pine_width <= 0.0 \
			or level_crown_radius <= 0.0 or level_light_range_multiplier <= 0.0 \
			or level_offer_rain_size_min <= 0.0 \
			or level_offer_rain_size_min > level_offer_rain_size_max:
		errors.append("run VFX dimensions must be positive")
	if level_particle_speed_min > level_particle_speed_max \
			or level_spark_speed_min > level_spark_speed_max \
			or level_offer_rain_speed_min > level_offer_rain_speed_max \
			or level_offer_rain_drift_min > level_offer_rain_drift_max \
			or level_offer_rain_spin_min > level_offer_rain_spin_max:
		errors.append("run VFX speed ranges must be ordered")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("run VFX tuning must remain provisional")
	return errors
