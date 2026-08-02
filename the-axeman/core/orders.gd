class_name Orders
extends RefCounted
## Stateless order catalogue and piece-routing service. Progress belongs to
## GameState, stock to InventoryManager, and money to GameState; this class only
## decides where a settled piece is credited.

const _TABLE_PATH := "res://data/order_table.tres"
static var _orders: OrderTable = null


static func all() -> Array[OrderDef]:
	var table := _table()
	return [] if table == null else table.orders.duplicate()


static func by_id(id: StringName) -> OrderDef:
	var table := _table()
	return null if table == null else table.by_id(id)


static func is_available(order: OrderDef) -> bool:
	if order == null or GameState.has_completed_order(order.id):
		return false
	return order.required_species == &"" or GameState.owns_species(order.required_species)


## Pay the unlimited buyer first. Only a piece the yard actually bought may
## advance an order; otherwise an unpriced or missing inventory item could earn
## a completion premium without leaving the player's stock.
static func settle_piece(item_id: StringName) -> int:
	var payout := Market.sell(item_id, 1)
	if payout > 0:
		GameState.record_order_piece(item_id)
	return payout


static func _table() -> OrderTable:
	if _orders == null:
		_orders = load(_TABLE_PATH) as OrderTable
		if _orders == null:
			push_error("Orders: failed to load '%s'; the contract board is empty." % _TABLE_PATH)
	return _orders
