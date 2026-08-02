class_name OrderTable
extends Resource
## Authored introductory orders, in the order shown on the contract board.

@export var orders: Array[OrderDef] = []


func by_id(id: StringName) -> OrderDef:
	for order: OrderDef in orders:
		if order != null and order.id == id:
			return order
	return null
