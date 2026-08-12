class_name SkillVfxConfig
extends Resource
## Presentation-only tuning for particle-led skill procs and level-up.
## Every value remains a labelled PLACEHOLDER until a measured Compatibility
## feel session approves it. Gameplay outcomes never depend on this resource.

@export_group("Shared particle language — PLACEHOLDER")
@export var proc_core_size := 0.12
@export_range(0.0, 1.0, 0.01) var proc_core_opacity := 0.48
@export_range(0.0, 1.0, 0.01) var proc_overlay_strength := 0.035
@export var proc_light_range := 1.25
@export var proc_log_base_clearance := 0.025
@export var proc_log_base_viewer_offset := 0.045
@export_range(0.0, 1.0, 0.01) var particle_dither_strength := 0.42
@export_range(0.5, 5.0, 0.05) var particle_dither_pixel_size := 1.1
@export_range(0.02, 0.98, 0.01) var smooth_glow_softness := 0.82
@export_range(0.0, 1.0, 0.01) var smooth_glow_alpha := 0.20
@export var generic_duration := 0.58
@export_range(1, 128, 1) var generic_particle_count := 42
@export var generic_speed_min := 0.65
@export var generic_speed_max := 1.5

@export_group("Strength ember cloud — PLACEHOLDER")
@export var strength_duration := 0.68
@export_range(1, 160, 1) var strength_ember_count := 72
@export_range(1, 96, 1) var strength_hot_particle_count := 28
@export_range(1, 64, 1) var strength_glow_particle_count := 20
@export var strength_cloud_radius := 0.08
@export var strength_speed_min := 0.55
@export var strength_speed_max := 1.9
@export_range(0.0, 180.0, 1.0) var strength_spread_degrees := 76.0
@export var strength_light_energy := 0.8

@export_group("Speed spark spray — PLACEHOLDER")
@export var speed_duration := 0.52
@export_range(1, 128, 1) var speed_streak_count := 54
@export_range(1, 128, 1) var speed_mote_count := 40
@export_range(1, 64, 1) var speed_glow_particle_count := 16
@export var speed_emission_radius := 0.06
@export var speed_particle_speed_min := 0.95
@export var speed_particle_speed_max := 1.75
@export_range(0.0, 180.0, 1.0) var speed_spread_degrees := 18.0
@export var speed_light_energy := 0.55

@export_group("Mastery rising cloud — PLACEHOLDER")
@export var mastery_duration := 0.92
@export_range(1, 128, 1) var mastery_green_mote_count := 46
@export_range(1, 128, 1) var mastery_gold_mote_count := 34
@export_range(1, 64, 1) var mastery_glow_particle_count := 20
@export var mastery_emission_radius := 0.18
@export var mastery_particle_speed_min := 0.45
@export var mastery_particle_speed_max := 1.25
@export_range(0.0, 180.0, 1.0) var mastery_spread_degrees := 55.0
@export var mastery_light_energy := 0.9
@export var mastery_accent_color := Color(1.0, 0.78, 0.22, 1.0)

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
@export var level_crown_radius := 0.46
@export_range(0.0, 1.0, 0.01) var level_ray_alpha := 0.40
@export_range(0.0, 1.0, 0.01) var level_core_alpha := 0.50
@export_range(0.0, 1.0, 0.01) var level_smooth_glow_alpha := 0.20
@export var level_spark_speed_min := 1.25
@export var level_spark_speed_max := 2.0
@export var level_light_energy := 1.1
@export var level_light_range_multiplier := 3.0
@export_range(0.0, 1.0, 0.01) var level_overlay_strength := 0.03

@export var tuning_status := "PLACEHOLDER — measured particle VFX feel pass required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for duration: float in [generic_duration, strength_duration, speed_duration,
			mastery_duration, level_duration]:
		if duration <= 0.0:
			errors.append("skill VFX durations must be positive")
			break
	for count: int in [generic_particle_count, strength_ember_count,
			strength_hot_particle_count, strength_glow_particle_count,
			speed_streak_count, speed_mote_count, speed_glow_particle_count,
			mastery_green_mote_count, mastery_gold_mote_count,
			mastery_glow_particle_count, level_ray_count, level_spark_count,
			level_ember_count, level_glow_particle_count]:
		if count <= 0:
			errors.append("skill VFX particle counts must be positive")
			break
	if proc_core_size <= 0.0 or proc_light_range <= 0.0 \
			or proc_log_base_clearance < 0.0 \
			or proc_log_base_viewer_offset < 0.0 \
			or strength_cloud_radius <= 0.0 or speed_emission_radius <= 0.0 \
			or mastery_emission_radius <= 0.0 or level_cloud_radius <= 0.0 \
			or level_ray_height <= 0.0 or level_ray_width <= 0.0 \
			or level_crown_radius <= 0.0 or level_light_range_multiplier <= 0.0:
		errors.append("skill VFX dimensions must be positive")
	if generic_speed_min > generic_speed_max \
			or strength_speed_min > strength_speed_max \
			or speed_particle_speed_min > speed_particle_speed_max \
			or mastery_particle_speed_min > mastery_particle_speed_max \
			or level_particle_speed_min > level_particle_speed_max \
			or level_spark_speed_min > level_spark_speed_max:
		errors.append("skill VFX speed ranges must be ordered")
	if particle_dither_pixel_size <= 0.0:
		errors.append("skill VFX particle dither size must be positive")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("skill VFX tuning must remain provisional")
	return errors
