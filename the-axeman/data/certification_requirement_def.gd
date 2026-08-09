class_name CertificationRequirementDef
extends Resource
## Authored, deterministic manual evidence. Skill ownership and random procs are
## intentionally absent from this enum, so certification cannot require either.

enum Kind { MANUAL_LOGS, PERFECT_LOGS, GRAIN_READS }

@export var kind: Kind = Kind.MANUAL_LOGS
@export var required_count: int = 1
## When true, each SpeciesMasteryDef supplies its own authored target. This keeps
## one semantic manual-evidence rule while allowing the 25 woods to pace apart.
@export var use_mastery_target := false
@export var label: String
