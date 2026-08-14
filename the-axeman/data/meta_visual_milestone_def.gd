class_name MetaVisualMilestoneDef
extends Resource
## A permanent-rank threshold selecting an existing equipment presentation.

enum Slot { AXE, BLOCK }

@export_range(1, 99, 1) var rank := 1
@export var slot: Slot = Slot.AXE
@export var equipment_id: StringName = &""


func validate(rank_cap: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if rank <= 0 or rank > rank_cap:
		errors.append("meta visual milestone rank is outside its owner cap")
	if slot < Slot.AXE or slot > Slot.BLOCK:
		errors.append("meta visual milestone has an invalid slot")
	if equipment_id == &"":
		errors.append("meta visual milestone has no equipment identity")
	return errors
