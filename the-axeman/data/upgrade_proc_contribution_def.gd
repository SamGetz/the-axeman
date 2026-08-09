class_name UpgradeProcContributionDef
extends Resource
## A shop purchase's independent contribution to one shared proc family.
## Skill values remain in proc_table.tres; equipment values are deliberately
## separate so buying gear never impersonates learning a skill.

@export var proc_id: StringName
@export_range(0.0, 1.0, 0.0005) var chance_per_level: float = 0.0
## Maximum bonus depth made available by this source (one = one bonus action).
@export_range(0, 3, 1) var chain_cap: int = 0
@export_multiline var player_copy: String
@export var tuning_status: String = "PLACEHOLDER — pacing and feel review required"
