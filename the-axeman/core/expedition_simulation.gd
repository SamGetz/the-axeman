class_name ExpeditionSimulation
extends RefCounted
## Pure injected-clock expedition timing. Construction output never enters this
## service, so no production path can shorten an already-departed flight.


static func plan(destination: ExpeditionDef, now_seconds: int) -> Dictionary:
	if destination == null or not destination.validate().is_empty() or now_seconds < 0:
		return {}
	return {
		"id": StringName("flight_%s_%d" % [destination.id, now_seconds]),
		"destination_id": destination.id,
		"planned_at": now_seconds,
		"arrives_at": now_seconds + destination.flight_seconds,
	}


static func resolve(plan_data: Dictionary, now_seconds: int) -> ExpeditionReceipt:
	var plan_id := StringName(plan_data.get("id", &""))
	var destination_id := StringName(plan_data.get("destination_id", &""))
	var planned_at := maxi(0, int(plan_data.get("planned_at", 0)))
	var arrives_at := maxi(planned_at, int(plan_data.get("arrives_at", planned_at)))
	if plan_id == &"" or destination_id == &"" or now_seconds < arrives_at:
		return null
	return ExpeditionReceipt.new(StringName("arrival_%s" % plan_id),
		destination_id, planned_at, arrives_at)
