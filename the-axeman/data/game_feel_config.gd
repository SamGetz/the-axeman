class_name GameFeelConfig
extends Resource
## Schema per A8. The single authored instance is embedded in
## res://data/game_config.tres and loaded through GameConfig. ALL values below
## are PLACEHOLDERS per Operational Directive 4 — final numbers come from the
## Creative Director during measured tuning, never from code defaults.

@export var hit_pause_duration: float = 0.06
@export var camera_shake_amplitude: float = 0.15
@export var camera_shake_decay: float = 6.0
@export var log_hop_force: float = 3.0
@export var perfect_cut_throw_force: float = 7.0
@export var size_threshold: int = 1


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if hit_pause_duration < 0.0 or camera_shake_amplitude < 0.0 \
			or camera_shake_decay < 0.0:
		errors.append("pause and shake values must be non-negative")
	if log_hop_force < 0.0 or perfect_cut_throw_force < 0.0:
		errors.append("piece feedback forces must be non-negative")
	if size_threshold < 1:
		errors.append("piece size threshold must be at least one")
	return errors
