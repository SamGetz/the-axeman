class_name PainterlyVFXStyle
extends Resource
## Shared art-direction knobs for the world-space paint treatment. These are
## explicitly provisional: the approved screenshots establish the language,
## while a measured in-game feel pass still owns final density and scale.

@export_group("Shared pigment")
@export_range(0.0, 1.0, 0.01) var daub_dry_amount := 0.12
@export_range(0.0, 1.0, 0.01) var slash_dry_amount := 0.18
@export_range(0.0, 1.0, 0.01) var soft_dry_amount := 0.05
@export_range(0.0, 1.0, 0.01) var soft_opacity := 0.66

@export_group("Grain cue")
@export_range(0.0, 1.0, 0.01) var grain_dry_amount := 0.12

@export_group("Status")
@export var tuning_status := \
	"PLACEHOLDER — approved art direction; measured VFX feel pass still required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("painterly VFX tuning must remain provisional")
	return errors
