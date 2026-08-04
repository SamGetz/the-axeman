class_name CertificationRequirementDef
extends Resource
## Authored, deterministic manual evidence. Skill ownership and random procs are
## intentionally absent from this enum, so certification cannot require either.

enum Kind { MANUAL_LOGS, PERFECT_LOGS, GRAIN_READS }

@export var kind: Kind = Kind.MANUAL_LOGS
@export var required_count: int = 1
@export var label: String
