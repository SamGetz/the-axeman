class_name Market
extends RefCounted
## Immutable unit-price lookup. RunDirector performs the inventory removal and
## attempt-cash credit so this service cannot bypass either state owner.

const _PRICE_TABLE_PATH := "res://data/price_table.tres"
static var _prices: PriceTable


static func get_price(item_id: StringName) -> int:
	var table := _table()
	# Retired alien/industrial registry rows may remain for migration safety, but
	# only the 25 live terrestrial species participate in the survival economy.
	if table == null or not InventoryManager.is_valid_id(item_id) \
			or SpeciesTable.by_yield_item(item_id) == null:
		return 0
	return maxi(0, table.price_of(item_id))


static func is_sellable(item_id: StringName) -> bool:
	return get_price(item_id) > 0


static func _table() -> PriceTable:
	if _prices == null:
		_prices = load(_PRICE_TABLE_PATH) as PriceTable
	return _prices
