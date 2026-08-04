class_name ProcDef
extends Resource
## One named chance-driven family. The later resolver reads this definition;
## this resource neither rolls nor owns fairness/progression state.

enum Family { DOUBLE_STRIKE, FOLLOW_UP, QUICK_STUDY }
enum Eligibility { MANUAL_SWING, MANUAL_LOG_COMPLETION }

@export var id: StringName
@export var display_name: String
@export var family: Family = Family.DOUBLE_STRIKE
@export var eligibility: Eligibility = Eligibility.MANUAL_SWING
@export var announcement_key: StringName
## All values below are labelled placeholders pending Sam's tuning pass.
@export_range(0.0, 1.0, 0.001) var base_chance: float = 0.1
## Additional chance contributed by each owned rank after the first. The live
## value belongs in proc_table.tres; code only clamps the resulting probability.
@export_range(0.0, 1.0, 0.001) var chance_per_rank: float = 0.0
@export var chain_cap: int = 1
@export var bad_luck_bound: int = 10
@export var bad_luck_policy_key: StringName = &"bounded_dry_streak"
@export var modifiers: Array[GameplayModifierDef] = []
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
