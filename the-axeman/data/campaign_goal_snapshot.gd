class_name CampaignGoalSnapshot
extends RefCounted
## Immutable presentation snapshot for the one persistent campaign objective.
## GameState owns progression; HUD consumers receive this read-only description.

var phase: int
var title: String
var detail: String
var current: int
var target: int
var action_id: StringName


func _init(p_phase: int, p_title: String, p_detail: String,
		p_current := 0, p_target := 0, p_action_id: StringName = &"") -> void:
	phase = p_phase
	title = p_title
	detail = p_detail
	current = maxi(0, p_current)
	target = maxi(0, p_target)
	action_id = p_action_id


func has_progress() -> bool:
	return target > 0


func progress_ratio() -> float:
	return 0.0 if target <= 0 else clampf(float(current) / float(target), 0.0, 1.0)
