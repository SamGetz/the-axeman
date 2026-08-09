class_name ProgressionProcs
extends RefCounted
## One query surface for independent gear access plus learned-skill additions.

const GLOBAL_BONUS_CAP := 3


static func proc_def(proc_id: StringName) -> ProcDef:
	var table := M7CContent.procs()
	return null if table == null else table.by_id(proc_id)


static func skill_chance(proc_id: StringName) -> float:
	var proc := proc_def(proc_id)
	if proc == null:
		return 0.0
	match proc_id:
		&"double_strike", &"follow_up", &"quick_study":
			return proc.base_chance if SkillTree.get_level(proc_id) > 0 else 0.0
		&"grain_read":
			return proc.base_chance if SkillTree.owns_modifier(
				GameplayModifierDef.Kind.GRAIN_CUE) else 0.0
	return 0.0


static func equipment_chance(proc_id: StringName) -> float:
	return Shop.equipment_proc_chance(proc_id)


static func effective_chance(proc_id: StringName) -> float:
	return clampf(skill_chance(proc_id) + equipment_chance(proc_id), 0.0, 1.0)


static func is_available(proc_id: StringName) -> bool:
	return effective_chance(proc_id) > 0.0


static func effective_chain_cap(proc_id: StringName) -> int:
	var skill_cap := 0
	match proc_id:
		&"double_strike":
			if SkillTree.get_level(&"double_strike") > 0:
				skill_cap = int(round(SkillTree.total_modifier(
					GameplayModifierDef.Kind.MULTI_CHOP_DEPTH)))
		&"follow_up":
			if SkillTree.get_level(&"follow_up") > 0:
				skill_cap = 1 + int(round(SkillTree.total_modifier(
					GameplayModifierDef.Kind.FOLLOW_UP_DEPTH)))
	return mini(GLOBAL_BONUS_CAP, maxi(skill_cap,
		Shop.equipment_proc_chain_cap(proc_id)))


static func branch_for_proc(proc_id: StringName) -> SkillBranchDef:
	var proc := proc_def(proc_id)
	var branch_id := proc.presentation_branch_id if proc != null else &""
	if branch_id != &"" and M7CContent.branches() != null:
		return M7CContent.branches().by_id(branch_id)
	return SkillTree.branch_for_proc(proc_id)
