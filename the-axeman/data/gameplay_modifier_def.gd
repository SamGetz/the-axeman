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
	## Global percentage added to ordinary firewood-sale payouts. Appended so
	## existing serialized Kind integers keep their M7C meaning.
	CASH_GAIN,
	## Global percentage added to every genuine XP receipt.
	GLOBAL_XP_GAIN,
	## Enables held primary input to request the next legal manual swing.
	HOLD_TO_CHOP,
	## Fraction reducing settle, gather and next-log turnaround durations.
	LOG_TURNAROUND,
	## Additional automatic cuts allowed when Double Strike fires.
	MULTI_CHOP_DEPTH,
	## Additional scar contribution on the next split roll.
	SCAR_RELIABILITY,
	## Fraction reducing player-requested camera orbit/correction duration.
	ORBIT_SPEED,
	## Additional bounded Follow-Up swings after the first proc swing.
	FOLLOW_UP_DEPTH,
	## Enables multi-chop during the precision guard.
	PRECISION_CHAIN_SAFETY,
	## Marks remaining pieces after a completed Strength continuation.
	EARTHSHAKER,
	## Keeps held input alive across a completed-log transition.
	CONTINUOUS_HANDOFF,
	## Guarantees a later grain opportunity after Quick Study fires.
	GRAIN_GUARANTEE,
	## Marks the first completed manual log after a level as a Masterwork.
	MASTERWORK,
	## Alien-only split and special-behaviour handling contribution.
	ALIEN_HANDLING,
	## Fraction of extra credited progress for unstarted launch contributions.
	CONTRIBUTION_EFFICIENCY,
	## Fraction reducing eligible late Frontier infrastructure costs.
	FRONTIER_LOGISTICS,
}

enum Operation { ADD, MULTIPLY, ENABLE }

@export var id: StringName
@export var kind: Kind = Kind.SPLIT_RELIABILITY
@export var operation: Operation = Operation.ADD
## PLACEHOLDER until the relevant Creative Director tuning gate. Validators
## require finite data but do not bless the magnitude as final.
@export var magnitude: float = 0.0
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
