class_name GameFeelConfig
extends Resource
## Camera-shake and hit-pause placeholders embedded in survival_game_config.tres.

@export var hit_pause_duration: float = 0.06
@export var camera_shake_amplitude: float = 0.15
@export var camera_shake_decay: float = 6.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if hit_pause_duration < 0.0 or camera_shake_amplitude < 0.0 \
			or camera_shake_decay < 0.0:
		errors.append("pause and shake values must be non-negative")
	return errors
