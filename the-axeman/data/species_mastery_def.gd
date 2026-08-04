class_name SpeciesMasteryDef
extends Resource
## Knowledge layered on an existing SpeciesDef id. Price, hardness, meshes and
## supplier ownership remain in SpeciesDef and are never duplicated here.

@export var species_id: StringName
@export var mastery_target: int = 10
@export var manual_completion_award: int = 1
@export var reveal_thresholds: PackedInt32Array = PackedInt32Array()
@export var certification_requirements: Array[CertificationRequirementDef] = []
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
