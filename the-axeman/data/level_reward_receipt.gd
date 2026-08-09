class_name LevelRewardReceipt
extends RefCounted

enum RewardType { SKILL_POINT, CASH }

var level: int
var reward_type: RewardType
var amount: int


func _init(p_level: int, p_reward_type: RewardType, p_amount: int) -> void:
	level = p_level
	reward_type = p_reward_type
	amount = p_amount
