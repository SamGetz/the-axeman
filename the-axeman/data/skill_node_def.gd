class_name SkillNodeDef
extends Resource
## FILE: res://data/skill_node_def.gd
## ATTACHES TO: nothing. Schema only; instances live inside
## res://data/skill_tree.tres and are read through res://core/skill_tree.gd.
##
## ONE NODE OF THE SKILL TREE — a player enhancement bought with SKILL POINTS,
## which come from levelling, not from cash (Creative Director call, 2026-08-02:
## "the currency we generate goes to things like new axes, auto cutters,
## unlocking new logs etc and the skill tree goes towards player enhancements,
## like cutting speed, swing timers, strength").
##
## IT IS A REAL TREE, not a flat list (Sam's call when asked directly). `requires`
## names the nodes that must already be bought, so early picks gate later ones and
## two players' axemen can diverge.
##
## WHY EFFECTS ARE A NAMED KIND PLUS A STEP, rather than each node carrying code:
## the chopping game asks `SkillTree.total_effect(&"swing_speed")` and gets a
## number. A new node that makes swings faster is a row in the table; a new KIND
## of effect is the only thing that needs a line of gameplay code, and there is
## exactly one place to add it.

## Effect kinds a node can contribute to. Adding one here means teaching whatever
## system it belongs to to read it — see the callers of SkillTree.total_effect().
enum Effect {
	NONE,
	## Fraction off the wait between swings, compounding per level.
	SWING_SPEED,
	## Flat points added to the chance a swing cleaves the wood.
	SPLIT_STRENGTH,
	## Fraction off the axe's wind-up, so the chop itself lands sooner.
	CHOP_SPEED,
	## Fraction added to the XP a finished log awards.
	XP_GAIN,
	## Fraction added to what the yard pays for a piece.
	CASH_GAIN,
	## Provisional M12 handling margin for quarantined first-contact specimens.
	SPECIMEN_HANDLING,
	## Provisional M12 expedition preparation contribution efficiency.
	EXPEDITION_PREPARATION,
}

## M7C's semantic role. UI position and display copy are presentation only;
## gameplay and validation read this field directly.
enum NodeType { FOUNDATION, PROC, MODIFIER, CAPSTONE }

@export var id: StringName
@export var display_name: String
## Player-facing sentence. Says what a level DOES in the fiction — the roadmap is
## explicit that an upgrade must be felt or seen, never a hidden percentage.
@export var description: String

@export_group("M7C identity")
@export var branch_id: StringName
@export var node_type: NodeType = NodeType.FOUNDATION
## Address inside SkillBranchDef.layout_slots, not a pixel coordinate.
@export var presentation_position: Vector2i = Vector2i.ZERO
## Required only for PROC nodes; points at ProcTable by stable id.
@export var proc_id: StringName = &""
@export var modifiers: Array[GameplayModifierDef] = []
## The overhaul's ordinary skill effects. `modifiers` remains the proc/capability
## metadata field used by older content; callers aggregate both arrays so old
## hand-authored resources and the new 45-node graph share one typed vocabulary.
@export var effects: Array[GameplayModifierDef] = []

@export_group("The tree")
## Alternative parent branch ids. Fully ranking any one named parent unlocks
## this node. Empty means a ROOT — available from level 1. Cycles are refused at
## load; see SkillTree._validate().
@export var requires: Array[StringName] = []
## How many times this node can be bought. Each level applies `effect_step` again.
@export var max_level: int = 1
## Skill points for ONE level. Every level of a node costs the same — the tree's
## difficulty curve lives in its SHAPE and in the level curve, not in per-node
## price inflation, which would be a third thing to tune against the other two.
@export var cost: int = 1

@export_group("What it does")
@export var effect: Effect = Effect.NONE
## How much ONE level contributes. Read by whoever owns that effect kind, which
## decides whether it compounds (SWING_SPEED) or sums (SPLIT_STRENGTH).
## PLACEHOLDER per Directive 3 on every node except where noted in skill_tree.tres.
@export var effect_step: float = 0.05


func is_maxed(level: int) -> bool:
	return max_level > 0 and level >= max_level


func is_root() -> bool:
	return requires.is_empty()
