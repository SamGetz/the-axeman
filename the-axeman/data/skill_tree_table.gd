class_name SkillTreeTable
extends Resource
## FILE: res://data/skill_tree_table.gd
## ATTACHES TO: nothing. The single instance is res://data/skill_tree.tres, read
## through res://core/skill_tree.gd.
##
## Every node in the skill tree. Order here is DISPLAY order (roots first, then
## outward), not dependency order — `requires` is what actually says what gates
## what, and SkillTree validates that the graph is acyclic and complete.

@export var nodes: Array[SkillNodeDef] = []


func get_node_def(id: StringName) -> SkillNodeDef:
	for n: SkillNodeDef in nodes:
		if n != null and n.id == id:
			return n
	return null


## Every node that names `id` as a prerequisite — the tree read downward, which is
## what a UI needs to draw branches.
func children_of(id: StringName) -> Array[SkillNodeDef]:
	var out: Array[SkillNodeDef] = []
	for n: SkillNodeDef in nodes:
		if n != null and n.requires.has(id):
			out.append(n)
	return out
