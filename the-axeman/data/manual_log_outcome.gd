class_name ManualLogOutcome
extends RefCounted
## One immutable-in-practice completion fact passed into the manual XP
## transaction. It is created only when a log root resolves; the resolver and
## progression systems never infer source from presentation state.

enum Source { MANUAL, AUTOMATION, RESTORED }

var root_event_id: StringName
var source: Source
var completed: bool
var is_bonus_event: bool
var base_xp: int


func _init(p_root_event_id: StringName, p_source: Source, p_completed: bool,
		p_is_bonus_event: bool, p_base_xp: int) -> void:
	root_event_id = p_root_event_id
	source = p_source
	completed = p_completed
	is_bonus_event = p_is_bonus_event
	base_xp = p_base_xp


func is_manual_root_completion() -> bool:
	return root_event_id != &"" \
		and source == Source.MANUAL \
		and completed \
		and not is_bonus_event \
		and base_xp > 0
