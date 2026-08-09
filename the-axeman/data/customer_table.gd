class_name CustomerTable
extends Resource

@export var customers: Array[CustomerDef] = []
@export_range(1, 100, 1) var completion_history_limit := 20
@export var tuning_status := "PLACEHOLDER — M7B customer cadence review required"


func by_id(id: StringName) -> CustomerDef:
	for customer: CustomerDef in customers:
		if customer != null and customer.id == id:
			return customer
	return null
