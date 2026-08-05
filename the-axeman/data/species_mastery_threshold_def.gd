class_name SpeciesMasteryThresholdDef
extends Resource
## One shared progress rung in the species-mastery ladder. Reaching this amount
## on any species makes every typed reward in `rewards` active for that species.
## Slice 1 records and validates these rewards; Slice 2 applies their effects.

@export var required_progress: int = 1
@export var rewards: Array[GameplayModifierDef] = []
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
