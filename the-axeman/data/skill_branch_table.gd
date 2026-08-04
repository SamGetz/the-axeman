class_name SkillBranchTable
extends Resource

@export var branches: Array[SkillBranchDef] = []


func by_id(id: StringName) -> SkillBranchDef:
	for branch: SkillBranchDef in branches:
		if branch != null and branch.id == id:
			return branch
	return null
