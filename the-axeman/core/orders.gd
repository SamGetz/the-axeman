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


static func is_revealed(order: OrderDef) -> bool:
	return order != null and GameState.get_level() >= order.unlock_level


## Only revealed orders. The XP strip advertises the next contract as a level
## reward, so the board itself never contains disabled future work.
static func visible() -> Array[OrderDef]:
	var out: Array[OrderDef] = []
	for order: OrderDef in all():
		if is_revealed(order):
			out.append(order)
	return out


static func next_unrevealed() -> OrderDef:
	for order: OrderDef in all():
		if order != null and not is_revealed(order):
			return order
	return null


static func is_available(order: OrderDef) -> bool:
	if order == null or GameState.has_completed_order(order.id):
		return false
	if not is_revealed(order):
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


## Cross-table validation for the authored one-time ladder. This remains a
## read-only service: it reports malformed data but never repairs progression.
static func validate_live_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	var previous_level := 0
	for index in range(all().size()):
		var order: OrderDef = all()[index]
		if order == null:
			errors.append("null order at index:%d" % index)
			continue
		if order.id == &"":
			errors.append("order has empty id at index:%d" % index)
		elif seen_ids.has(order.id):
			errors.append("duplicate order id:%s" % order.id)
		else:
			seen_ids[order.id] = true
		if order.required_count <= 0 or order.cash_bonus <= 0:
			errors.append("order %s has non-positive count/bonus" % order.id)
		if order.unlock_level < previous_level:
			errors.append("order %s breaks authored reveal ordering" % order.id)
		previous_level = order.unlock_level
		if order.required_item != &"" and not Market.is_sellable(order.required_item):
			errors.append("order %s requires unsellable item:%s" % [order.id, order.required_item])
		if order.required_species == &"":
			continue
		var species := SpeciesTable.by_id(order.required_species)
		if species == null:
			errors.append("order %s requires unknown species:%s" % [order.id, order.required_species])
			continue
		if species.yield_item != order.required_item:
			errors.append("order %s item does not match species yield" % order.id)
		if order.id == StringName("%s_delivery" % species.id):
			if order.unlock_level != species.unlock_level:
				errors.append("order %s reveal level does not match species" % order.id)
			if order.required_count != 20:
				errors.append("order %s breaks the Slice 6 placeholder count" % order.id)
			var expected_bonus := maxi(400,
				int(ceil(float(species.unlock_cost) * 0.10 / 50.0)) * 50)
			if order.cash_bonus != expected_bonus:
				errors.append("order %s breaks the Slice 6 placeholder bonus formula" % order.id)
			if not order.tuning_status.begins_with("PLACEHOLDER"):
				errors.append("order %s lacks a PLACEHOLDER tuning label" % order.id)
	return errors


static func _table() -> OrderTable:
	if _orders == null:
		_orders = load(_TABLE_PATH) as OrderTable
		if _orders == null:
			push_error("Orders: failed to load '%s'; the contract board is empty." % _TABLE_PATH)
	return _orders
