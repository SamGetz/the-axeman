class_name UpgradeDef
extends Resource
## FILE: res://data/upgrade_def.gd
## ATTACHES TO: nothing. Schema only; instances live inside
## res://data/upgrade_table.tres and are read through res://core/shop.gd.
##
## One thing the player can buy in the yard's shop, repeatedly, each purchase one
## level better. Levels are stored by GameState as BUILDING TIERS keyed by this
## `id` — see Shop.buy() for why that is the honest home for them rather than a
## new contract.
##
## EVERY NUMBER IN upgrade_table.tres IS A PLACEHOLDER except the two effect steps
## Sam named (5% each). Costs, growth and level caps are tuning calls.

@export var id: StringName
@export var display_name: String
## Player-facing sentence. Says what the level DOES, in the fiction — the roadmap
## is explicit that an upgrade must be felt or seen, never a hidden percentage.
@export var description: String
## Cash for the FIRST level. Each further level multiplies by `cost_growth`.
@export var base_cost: int = 10
@export var cost_growth: float = 1.6
## How many levels can be bought in total. 0 means unlimited.
@export var max_level: int = 10


## Cash to go from `level` to `level + 1`. Level 0 is "nothing bought yet".
func cost_for_level(level: int) -> int:
	if level < 0:
		return 0
	return int(round(float(base_cost) * pow(cost_growth, float(level))))


func is_maxed(level: int) -> bool:
	return max_level > 0 and level >= max_level
