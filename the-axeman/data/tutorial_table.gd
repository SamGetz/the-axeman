class_name TutorialTable
extends Resource

@export_group("Presentation — FINAL")
## Lets reward, unlock and receipt feedback settle before guidance enters.
@export_range(0.0, 15.0, 0.1) var event_delay_seconds: float = 2.0

@export var guides: Array[TutorialGuideDef] = []
@export var beats: Array[TutorialBeatDef] = []


func guide_by_id(id: StringName) -> TutorialGuideDef:
	for guide: TutorialGuideDef in guides:
		if guide != null and guide.id == id:
			return guide
	return null


func beat_by_id(id: StringName) -> TutorialBeatDef:
	for beat: TutorialBeatDef in beats:
		if beat != null and beat.id == id:
			return beat
	return null


func opening_beats() -> Array[TutorialBeatDef]:
	var result: Array[TutorialBeatDef] = []
	for beat: TutorialBeatDef in beats:
		if beat != null and beat.availability_kind == TutorialBeatDef.AvailabilityKind.OPENING:
			result.append(beat)
	result.sort_custom(func(a: TutorialBeatDef, b: TutorialBeatDef) -> bool:
		return a.opening_order < b.opening_order)
	return result


func contextual_beats() -> Array[TutorialBeatDef]:
	var result: Array[TutorialBeatDef] = []
	for beat: TutorialBeatDef in beats:
		if beat != null and beat.availability_kind != TutorialBeatDef.AvailabilityKind.OPENING:
			result.append(beat)
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if event_delay_seconds < 0.0:
		errors.append("tutorial event delay cannot be negative")
	var guide_ids := {}
	for guide: TutorialGuideDef in guides:
		if guide == null:
			errors.append("tutorial table contains a null guide")
			continue
		errors.append_array(guide.validate())
		if guide_ids.has(guide.id):
			errors.append("duplicate tutorial guide %s" % guide.id)
		guide_ids[guide.id] = true
	var beat_ids := {}
	var opening_orders := {}
	for beat: TutorialBeatDef in beats:
		if beat == null:
			errors.append("tutorial table contains a null beat")
			continue
		errors.append_array(beat.validate())
		if beat_ids.has(beat.id):
			errors.append("duplicate tutorial beat %s" % beat.id)
		beat_ids[beat.id] = true
		if not guide_ids.has(beat.guide_id):
			errors.append("tutorial beat %s names an unknown guide" % beat.id)
		if beat.availability_kind == TutorialBeatDef.AvailabilityKind.OPENING:
			if opening_orders.has(beat.opening_order):
				errors.append("duplicate tutorial opening order %d" % beat.opening_order)
			opening_orders[beat.opening_order] = true
	return errors
