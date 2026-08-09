class_name ProcDef
extends Resource
## One named chance-driven family. The later resolver reads this definition;
## this resource neither rolls nor owns fairness/progression state.

## Append only: these integer values are serialized in proc_table.tres.
enum Family { DOUBLE_STRIKE, FOLLOW_UP, QUICK_STUDY, GRAIN_READ, MASTERY_ECHO, EXPRESS_HANDOFF }
## MANUAL_PIECE_OFFER: rolled once when a fresh on-block piece is created (a
## new log or a freshly split half), deciding whether that piece carries a
## permanent gold grain mark. Distinct from MANUAL_SWING (rolled per landed
## strike) and MANUAL_LOG_COMPLETION (rolled once per finished log) — a grain
## offer is neither of those, it is per piece-creation.
enum Eligibility { MANUAL_SWING, MANUAL_LOG_COMPLETION, MANUAL_PIECE_OFFER }

@export var id: StringName
@export var display_name: String
@export var family: Family = Family.DOUBLE_STRIKE
@export var eligibility: Eligibility = Eligibility.MANUAL_SWING
@export var announcement_key: StringName
## Presentation family used by ProcBurst. Kept explicit so equipment-only
## access has the same authored colour branch as its matching skill tree.
@export var presentation_branch_id: StringName
## Authored chance shown to the player in the owning skill's hover card.
@export_range(0.0, 1.0, 0.001) var base_chance: float = 0.1
## Additional chance contributed by each owned rank after the first. The live
## value belongs in proc_table.tres; code only clamps the resulting probability.
@export_range(0.0, 1.0, 0.001) var chance_per_rank: float = 0.0
@export var chain_cap: int = 1
@export var bad_luck_bound: int = 10
@export var bad_luck_policy_key: StringName = &"bounded_dry_streak"
@export var modifiers: Array[GameplayModifierDef] = []
@export var tuning_status: String = "FINAL — approved skill-tree balance"
