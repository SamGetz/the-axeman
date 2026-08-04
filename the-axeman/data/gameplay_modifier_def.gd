class_name GameplayModifierDef
extends Resource
## Typed, immutable description of one gameplay weighting. A modifier is data;
## the system named by `kind` decides how to apply it in its later vertical
## slice. Merely existing in a resource grants no live effect.

enum Kind {
	SPLIT_RELIABILITY,
	SWING_RECOVERY,
	WINDUP_TIME,
	MANUAL_XP,
	FORCED_SEAM,
	PRECISION_SAFETY,
	HARD_WOOD_WEIGHT,
	GRAIN_CUE,
}

enum Operation { ADD, MULTIPLY, ENABLE }

@export var id: StringName
@export var kind: Kind = Kind.SPLIT_RELIABILITY
@export var operation: Operation = Operation.ADD
## PLACEHOLDER until the relevant Creative Director tuning gate. Validators
## require finite data but do not bless the magnitude as final.
@export var magnitude: float = 0.0
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
