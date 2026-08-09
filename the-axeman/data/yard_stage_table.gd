class_name YardStageTable
extends Resource

@export var stages: Array[YardStageDef] = []


func at(index: int) -> YardStageDef:
	return stages[index] if index >= 0 and index < stages.size() else null
