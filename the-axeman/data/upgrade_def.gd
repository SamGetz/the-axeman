class_name UpgradeDef
extends Resource
## FILE: res://data/upgrade_def.gd
## ATTACHES TO: nothing. Schema only; instances live inside
## res://data/upgrade_table.tres and are read through res://core/shop.gd.
##
## One physical/business purchase in the yard shop. Levels are stored by
## GameState as BUILDING TIERS keyed by `id`; this resource owns only immutable
## catalogue data. M7A uses both one-time items and the first authored rank of a
## tiered chopping-block line.

enum PurchaseForm { ONE_TIME, TIERED }
enum AutomationRole {
	NONE,
	MECHANICAL_SPLITTER,
	CUTTING_PROFILE,
	SPLITTER_UPGRADE,
}
enum Effect {
	NONE,
	SPLIT_RELIABILITY,
	WORK_RADIUS,
	DELIVERY_TIME,
	SWING_RECOVERY,
	AUTOMATION_SPEED,
	AUTOMATION_AUTO_LOAD,
	AUTOMATION_LOGS_PER_SPLIT,
	AUTOMATION_XP_GAIN,
	AUTOMATION_CASH_GAIN,
}

@export var id: StringName
@export var display_name: String
## Player-facing sentence. Says what the level DOES, in the fiction — the roadmap
## is explicit that an upgrade must be felt or seen, never a hidden percentage.
@export var description: String
## The honest boundary printed on the card. A substantial purchase must say what
## it does NOT do as clearly as what it does.
@export_multiline var limitation: String

@export_group("Catalogue")
@export var purchase_form: PurchaseForm = PurchaseForm.ONE_TIME
## Both requirements are cumulative. Empty/zero means no requirement.
@export var unlock_order_id: StringName = &""
@export var unlock_after_haul_aways: int = 0
## Optional M8 gates. Ownership remains authoritative in Shop.is_unlocked(), so
## a paid-for machine/profile can never be re-locked by later tuning changes.
@export var required_upgrade_id: StringName = &""
@export var required_mastery_species_id: StringName = &""
@export var required_mastered_species_count: int = 0

@export_group("Price")
## Cash for the FIRST level. Each further level multiplies by `cost_growth`.
@export var base_cost: int = 10
@export var cost_growth: float = 1.6
## How many levels can be bought in total. 0 means unlimited.
@export var max_level: int = 10

@export_group("Effect")
@export var effect: Effect = Effect.NONE
## Per purchased level. Every live value is a measured-tuning placeholder until
## Sam signs off the relevant band; approved values still live only here.
@export var effect_step: float = 0.0

@export_group("M8 Automation")
## Typed catalogue metadata for the machine, species profiles and its five
## dedicated progression lines. Automation effects are read only by the watched
## runtime; they never leak into manual chopping through Shop.total_effect().
@export var automation_role: AutomationRole = AutomationRole.NONE
@export var automation_species_id: StringName = &""
## Automation prices, certification count and rates carry their review state in
## resource data so approved tuning cannot be mistaken for a placeholder band.
@export var tuning_status: String = ""


## Cash to go from `level` to `level + 1`. Level 0 is "nothing bought yet".
func cost_for_level(level: int) -> int:
	if level < 0:
		return 0
	return int(round(float(base_cost) * pow(cost_growth, float(level))))


func is_maxed(level: int) -> bool:
	return max_level > 0 and level >= max_level
