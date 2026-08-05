class_name CommissionTemplateDef
extends Resource
## Authored identity and provisional pacing for one repeatable yard commission.
## GameState persists generated offer snapshots; this resource remains immutable
## catalogue data read through the stateless Orders service.

enum GoalKind {
	ANY_FIREWOOD,
	SPECIFIC_SPECIES,
}

@export var id: StringName = &""
@export var customer_name := ""
## `{species}` is replaced with the generated species name. Any-firewood
## templates receive "Mixed Firewood".
@export var title_format := "{species} Commission"
@export_multiline var description := ""
@export var goal_kind: GoalKind = GoalKind.SPECIFIC_SPECIES
@export_range(1, 1000000, 1) var required_count := 1
## Fixed completion premium is snapshotted as
## `unit value * required_count * premium_ratio`. It never modifies ordinary
## per-piece Market receipts and never applies to splitter output.
@export_range(0.01, 10.0, 0.01) var premium_ratio := 0.1
@export var tuning_status := "PLACEHOLDER — M9 measured tuning required"
