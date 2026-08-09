class_name TutorialBeatDef
extends Resource
## Data-authored tutorial dialogue. Completion conditions observe public game
## state and HUD actions; tutorial presentation never grants progression.

enum CompletionKind {
	ACKNOWLEDGE,
	MANUAL_LOG_FINISHED,
	HUD_ACTION,
	SHOP_AVAILABLE,
	FIRST_UPGRADE_BOUGHT,
	FIRST_ORDER_ACCEPTED,
	FIRST_SKILL_SPENT,
	FIRST_EXTRA_WOOD_OWNED,
	SPLITTER_ASSIGNED,
	FIRST_ORDER_COMPLETED,
}

enum AvailabilityKind {
	OPENING,
	SKILL_POINT_AVAILABLE,
	ORDERS_ACTIONABLE,
	CATALOG_ACTIONABLE,
	COMMISSIONS_AVAILABLE,
	SPLITTER_INSTALLED,
	ATLAS_ACTIONABLE,
	EARTH_DEPLETED,
}

@export var id: StringName
@export var guide_id: StringName
@export var title := ""
@export_multiline var dialogue := ""
@export var objective := ""
@export var completion_kind := CompletionKind.ACKNOWLEDGE
@export var completion_value: StringName
@export var availability_kind := AvailabilityKind.OPENING
@export var opening_order := -1
@export var focus_target: StringName
@export var continue_label := "Continue"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("tutorial beat has an empty id")
	if guide_id == &"":
		errors.append("tutorial beat %s has no guide" % id)
	if title.strip_edges().is_empty() or dialogue.strip_edges().is_empty():
		errors.append("tutorial beat %s is missing copy" % id)
	if completion_kind == CompletionKind.HUD_ACTION and completion_value == &"":
		errors.append("tutorial beat %s has no HUD action" % id)
	if availability_kind == AvailabilityKind.OPENING and opening_order < 0:
		errors.append("opening tutorial beat %s has no order" % id)
	return errors
