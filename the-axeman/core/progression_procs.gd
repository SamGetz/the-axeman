class_name ProgressionProcs
extends RefCounted
## Retired v18 proc composition. Run powers replace this live authority in slice
## four; until then every availability/effect query is deliberately neutral.

const GLOBAL_BONUS_CAP := 3


static func proc_def(proc_id: StringName) -> ProcDef:
	var table := M7CContent.procs()
	return null if table == null else table.by_id(proc_id)


static func skill_chance(proc_id: StringName) -> float:
	return 0.0


static func equipment_chance(proc_id: StringName) -> float:
	return 0.0


static func effective_chance(proc_id: StringName) -> float:
	return 0.0


static func is_available(proc_id: StringName) -> bool:
	return false


static func effective_chain_cap(proc_id: StringName) -> int:
	return 0


static func branch_for_proc(proc_id: StringName) -> SkillBranchDef:
	var proc := proc_def(proc_id)
	var branch_id := proc.presentation_branch_id if proc != null else &""
	if branch_id != &"" and M7CContent.branches() != null:
		return M7CContent.branches().by_id(branch_id)
	return SkillTree.branch_for_proc(proc_id)
