class_name Craftsmanship
extends RefCounted
## Stateless, forgiving craft grading. A rough grade is always valid and keeps
## the ordinary Market path; higher grades add only a labelled manual bonus.

enum Grade {
	ROUGH,
	CLEAN,
	EXCEPTIONAL,
}

static func config() -> CraftsmanshipConfig:
	return GameConfig.current().craftsmanship


static func grade_piece(normalized_size: float) -> Grade:
	var cfg := config()
	if cfg == null or not cfg.validate().is_empty():
		return Grade.ROUGH
	var error := absf(clampf(normalized_size, 0.0, 1.0) - cfg.target_piece_fraction)
	var lamp_tolerance := Shop.total_effect(UpgradeDef.Effect.CRAFT_TOLERANCE)
	if error <= cfg.exceptional_tolerance + lamp_tolerance * 0.5:
		return Grade.EXCEPTIONAL
	if error <= cfg.clean_tolerance + lamp_tolerance:
		return Grade.CLEAN
	return Grade.ROUGH


static func cash_bonus(item_id: StringName, grade: Grade) -> int:
	var cfg := config()
	if cfg == null or not cfg.validate().is_empty():
		return 0
	var ratio := 0.0
	if grade == Grade.CLEAN:
		ratio = cfg.clean_cash_bonus
	elif grade == Grade.EXCEPTIONAL:
		ratio = cfg.exceptional_cash_bonus
	ratio += CompanyStrategy.effect(CompanyDoctrineDef.Effect.CRAFT_VALUE) \
		if grade != Grade.ROUGH else 0.0
	return maxi(0, int(round(float(Market.get_price(item_id)) * ratio)))


static func grade_name(grade: Grade) -> String:
	match grade:
		Grade.CLEAN:
			return "Clean"
		Grade.EXCEPTIONAL:
			return "Exceptional"
	return "Rough"
