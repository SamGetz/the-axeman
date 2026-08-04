class_name ProcTable
extends Resource

@export var procs: Array[ProcDef] = []


func by_id(id: StringName) -> ProcDef:
	for proc: ProcDef in procs:
		if proc != null and proc.id == id:
			return proc
	return null
