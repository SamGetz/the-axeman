class_name SpeciesMasteryThresholdDef
extends Resource
## One shared progress rung in the species-mastery ladder. Reaching this amount
## on any species makes every typed reward in `rewards` active for that species.
## M8 Slice 2 applies these global effects cumulatively across every reached
## threshold and every species.

@export var required_progress: int = 1
@export var rewards: Array[GameplayModifierDef] = []
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
