class_name SkillTree
extends RefCounted
## FILE: res://core/skill_tree.gd
## ATTACHES TO: nothing. class_name + static methods only — do NOT register as an
## autoload, for the same reasons as Market, Shop and SaveSystem: the tree itself
## is immutable data and the player's spend lives in GameState, so it owns no
## state, and a 5th autoload would need an amendment the way GameFeel did.
##
## Retired v18 skill catalogue. The definitions remain available only to inspect
## legacy identities during the gated migration; ownership, effects and buying
## are deliberately neutral in live play.
##
## DIRECTIVE 6 IS NOT BYPASSED. This file writes nothing: `buy()` decides whether
## a purchase is legal and GameState performs it. SkillTree answers questions;
## GameState owns the answer's consequences.
##
## A PURCHASE IS ATOMIC and ordered so it cannot half-happen: refuse an unknown
## node, a maxed one, one whose prerequisites are not met, or one the player
## cannot afford — and only then spend. Nothing is emitted on a refusal, so a
## stale UI row cannot flicker the tree.

const _TABLE_PATH := "res://data/skill_tree.tres"

static var _table: SkillTreeTable = null
static var _validated := false


## ------------------------------------------------------------------ catalogue
static func get_nodes() -> Array[SkillNodeDef]:
	var t := _catalogue()
	return [] if t == null else t.nodes


static func get_node_def(id: StringName) -> SkillNodeDef:
	var t := _catalogue()
	return null if t == null else t.get_node_def(id)


static func children_of(id: StringName) -> Array[SkillNodeDef]:
	var t := _catalogue()
	return [] if t == null else t.children_of(id)


static func is_branch_revealed(branch_id: StringName) -> bool:
	var table := M7CContent.branches()
	var branch := table.by_id(branch_id) if table != null else null
	if branch == null:
		return false
	return branch.reveal_gate == SkillBranchDef.RevealGate.ALWAYS


static func get_revealed_nodes() -> Array[SkillNodeDef]:
	var out: Array[SkillNodeDef] = []
	for node: SkillNodeDef in get_nodes():
		if node != null and is_branch_revealed(node.branch_id):
			out.append(node)
	return out


static func is_branch_presented(branch_id: StringName) -> bool:
	if not is_branch_revealed(branch_id):
		return false
	match branch_id:
		&"strength", &"speed", &"mastery":
			return true
	return false


## All three terrestrial branches are presented together. Frontier uses its
## separate Earth Master reveal gate and therefore remains absent until endgame.
static func get_presented_nodes() -> Array[SkillNodeDef]:
	var out: Array[SkillNodeDef] = []
	for node: SkillNodeDef in get_revealed_nodes():
		if node != null and is_branch_presented(node.branch_id):
			out.append(node)
	return out


static func has_unfilled_revealed_nodes() -> bool:
	for node: SkillNodeDef in get_revealed_nodes():
		if not node.is_maxed(get_level(node.id)):
			return true
	return false


static func frontier_purchase_count() -> int:
	return 0


static func core_purchase_count() -> int:
	var total := 0
	for node: SkillNodeDef in get_nodes():
		if node != null:
			total += node.max_level
	return total


static func frontier_purchases_owned() -> int:
	return 0


## Levels bought of `id`. 0 = not taken. Unlike the cash shop, this is NOT stored
## as a building tier: a building tier is A7's frozen vocabulary for a thing in
## the yard going up a level, and a skill is a property of the PLAYER. GameState
## keeps it in its own dictionary with its own local signal, so A7 is untouched.
static func get_level(id: StringName) -> int:
	return 0


## --------------------------------------------------------------- eligibility
## Is at least one of `id`'s prerequisite branches fully ranked? A node with no
## prerequisites is a root and is always unlocked. A single-parent node still
## requires that parent; a merge node opens from either completed branch.
static func prerequisites_met(id: StringName) -> bool:
	var def := get_node_def(id)
	if def == null or not is_branch_revealed(def.branch_id):
		return false
	if def.requires.is_empty():
		return true
	for req: StringName in def.requires:
		var required := get_node_def(req)
		if required != null and required.is_maxed(get_level(req)):
			return true
	return false


## Prerequisite ids not yet owned — what a UI prints under a locked node.
static func missing_prerequisites(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var def := get_node_def(id)
	if def == null or prerequisites_met(id):
		return out
	for req: StringName in def.requires:
		var required := get_node_def(req)
		if required == null or not required.is_maxed(get_level(req)):
			out.append(req)
	return out


## Skill points for the next level of `id`, or 0 if there is nothing to buy.
static func get_next_cost(id: StringName) -> int:
	var def := get_node_def(id)
	if def == null or def.is_maxed(get_level(id)):
		return 0
	return def.cost


static func can_buy(id: StringName) -> bool:
	return false


## ------------------------------------------------------------------- effects
## The summed contribution of every owned node with this effect kind, as
## `levels x effect_step`. Whether that number then compounds or adds is the
## CALLER's business, because only the caller knows what the number means: 5% off
## a swing timer ten times over is not the same as 50% off.
static func total_effect(kind: SkillNodeDef.Effect) -> float:
	return 0.0


## Levels owned across every node of one effect kind. The compounding callers need
## this rather than the summed magnitude — see chopping_minigame's swing cooldown.
static func total_levels(kind: SkillNodeDef.Effect) -> int:
	return 0


## Summed typed contribution across every owned rank. ENABLE effects return a
## positive value when present; duration/probability composition stays with the
## gameplay caller, matching the existing `total_effect()` contract.
static func total_modifier(kind: GameplayModifierDef.Kind) -> float:
	return 0.0


## Which branch a proc's home skill node belongs to — a node names its proc,
## not the other way round, so this walks the live tree once rather than
## authoring a second id->branch mapping. Used to derive a fired proc's color
## for VFX (ProcBurst) from data instead of a branch name hardcoded per proc.
static func branch_for_proc(proc_id: StringName) -> SkillBranchDef:
	for n: SkillNodeDef in get_nodes():
		if n != null and n.proc_id == proc_id:
			return M7CContent.branches().by_id(n.branch_id) if M7CContent.branches() != null else null
	return null


## Whether an OWNED player-skill node carries one typed modifier. Equipment
## definitions are intentionally not consulted: gear may weight a learned proc,
## but it cannot grant Technique's grain-reading capability by itself.
static func owns_modifier(kind: GameplayModifierDef.Kind,
		operation: GameplayModifierDef.Operation = GameplayModifierDef.Operation.ENABLE) -> bool:
	return false


## ------------------------------------------------------------------ purchase
## Buys one level. Returns the NEW level, or -1 if nothing happened — in which
## case nothing happened at all: no points spent, no level moved, no signal.
static func buy(id: StringName) -> int:
	return -1


## ---------------------------------------------------------------- internals
static func _catalogue() -> SkillTreeTable:
	if _table == null:
		_table = load(_TABLE_PATH) as SkillTreeTable
		if _table == null:
			push_error("SkillTree: failed to load '%s' — there is no tree." % _TABLE_PATH)
			return null
	if not _validated:
		_validated = true
		_validate(_table)
		# Run slice 3's semantic validation on the shipping load path too, so a
		# malformed hand-edited resource is loud outside acceptance.
		for error: String in M7CContent.validate_all():
			push_error("M7C content: " + error)
	return _table


## A tree with a dangling or circular prerequisite is unplayable in a way that is
## invisible until someone reaches that branch: `prerequisites_met` would simply
## return false forever and the node would sit there looking merely expensive. It
## is cheap to catch at load, so it is caught at load.
static func _validate(table: SkillTreeTable) -> void:
	var seen: Dictionary = {}
	for n: SkillNodeDef in table.nodes:
		if n == null:
			push_error("SkillTree: the table contains a null node.")
			continue
		if seen.has(n.id):
			push_error("SkillTree: duplicate skill id '%s'." % n.id)
		seen[n.id] = true

	for n: SkillNodeDef in table.nodes:
		if n == null:
			continue
		for req: StringName in n.requires:
			if not seen.has(req):
				push_error("SkillTree: '%s' requires '%s', which is not in the tree." % [n.id, req])
			elif req == n.id:
				push_error("SkillTree: '%s' requires itself." % n.id)

	# Depth-first cycle hunt. A cycle cannot be spotted by looking at one row, and
	# it is exactly the mistake a hand-edited .tres invites.
	var state: Dictionary = {}   # id -> 1 visiting, 2 done
	for n: SkillNodeDef in table.nodes:
		if n != null:
			_visit(table, n.id, state, [])


static func _visit(table: SkillTreeTable, id: StringName, state: Dictionary, path: Array) -> void:
	var mark := int(state.get(id, 0))
	if mark == 2:
		return
	if mark == 1:
		push_error("SkillTree: prerequisite cycle: %s -> %s" % [" -> ".join(path), id])
		return
	state[id] = 1
	var def := table.get_node_def(id)
	if def != null:
		var next := path.duplicate()
		next.append(String(id))
		for req: StringName in def.requires:
			_visit(table, req, state, next)
	state[id] = 2
