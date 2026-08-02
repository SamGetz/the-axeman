class_name SkillTree
extends RefCounted
## FILE: res://core/skill_tree.gd
## ATTACHES TO: nothing. class_name + static methods only — do NOT register as an
## autoload, for the same reasons as Market, Shop and SaveSystem: the tree itself
## is immutable data and the player's spend lives in GameState, so it owns no
## state, and a 5th autoload would need an amendment the way GameFeel did.
##
## THE SKILL TREE: what a level buys. Skill points come from LEVELLING, cash buys
## nothing here — that split is the whole point of the 2026-08-02 direction
## ("the currency we generate goes to things like new axes, auto cutters,
## unlocking new logs etc and the skill tree goes towards player enhancements").
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


## Levels bought of `id`. 0 = not taken. Unlike the cash shop, this is NOT stored
## as a building tier: a building tier is A7's frozen vocabulary for a thing in
## the yard going up a level, and a skill is a property of the PLAYER. GameState
## keeps it in its own dictionary with its own local signal, so A7 is untouched.
static func get_level(id: StringName) -> int:
	return GameState.get_skill_level(id)


## --------------------------------------------------------------- eligibility
## Are every one of `id`'s prerequisites owned? A node with none is a root and is
## always unlocked, which is what makes the tree enterable at level 1.
static func prerequisites_met(id: StringName) -> bool:
	var def := get_node_def(id)
	if def == null:
		return false
	for req: StringName in def.requires:
		if get_level(req) <= 0:
			return false
	return true


## Prerequisite ids not yet owned — what a UI prints under a locked node.
static func missing_prerequisites(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var def := get_node_def(id)
	if def == null:
		return out
	for req: StringName in def.requires:
		if get_level(req) <= 0:
			out.append(req)
	return out


## Skill points for the next level of `id`, or 0 if there is nothing to buy.
static func get_next_cost(id: StringName) -> int:
	var def := get_node_def(id)
	if def == null or def.is_maxed(get_level(id)):
		return 0
	return def.cost


static func can_buy(id: StringName) -> bool:
	var def := get_node_def(id)
	if def == null or def.is_maxed(get_level(id)):
		return false
	if not prerequisites_met(id):
		return false
	return GameState.get_skill_points_available() >= def.cost


## ------------------------------------------------------------------- effects
## The summed contribution of every owned node with this effect kind, as
## `levels x effect_step`. Whether that number then compounds or adds is the
## CALLER's business, because only the caller knows what the number means: 5% off
## a swing timer ten times over is not the same as 50% off.
static func total_effect(kind: SkillNodeDef.Effect) -> float:
	var total := 0.0
	for n: SkillNodeDef in get_nodes():
		if n != null and n.effect == kind:
			total += float(get_level(n.id)) * n.effect_step
	return total


## Levels owned across every node of one effect kind. The compounding callers need
## this rather than the summed magnitude — see chopping_minigame's swing cooldown.
static func total_levels(kind: SkillNodeDef.Effect) -> int:
	var total := 0
	for n: SkillNodeDef in get_nodes():
		if n != null and n.effect == kind:
			total += get_level(n.id)
	return total


## ------------------------------------------------------------------ purchase
## Buys one level. Returns the NEW level, or -1 if nothing happened — in which
## case nothing happened at all: no points spent, no level moved, no signal.
static func buy(id: StringName) -> int:
	var def := get_node_def(id)
	if def == null:
		push_error("SkillTree: no skill named '%s' — purchase refused." % id)
		return -1
	var level := get_level(id)
	if def.is_maxed(level):
		return -1
	if not prerequisites_met(id):
		return -1
	if not GameState.can_afford_skill_points(def.cost):
		return -1
	GameState.set_skill_level(id, level + 1)
	return level + 1


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
