class_name PriceTable
extends Resource
## FILE: res://data/price_table.gd
## ATTACHES TO: nothing. Resource schema; the single instance lives in
## res://data/price_table.tres and is read by res://core/market.gd.
##
## What the always-available basic buyer pays for one unit of an item.
##
## WHY THIS IS NOT A FIELD ON ItemDef: A8 (the item schema) is a FROZEN Part A
## contract, and Directive 2 forbids adding to it without an approved amendment.
## A price is also not a property of the thing — it is a property of the market
## for the thing — so a separate table is the honest shape as well as the legal
## one. When M7B adds per-customer multipliers or reputation pricing, they layer
## on top of these base values without touching the registry.
##
## EVERY NUMBER IN price_table.tres IS A PLACEHOLDER (Directive 3). Prices are a
## Creative Director tuning call and are deliberately data, never code.

## item id (StringName) -> price in cash per unit. An id that is absent, or
## priced at 0 or less, is NOT sellable — see Market.get_price().
@export var base_prices: Dictionary = {}


## Returns 0 for anything this table does not price, so an unpriced item reads as
## "the buyer does not want this" rather than as free money.
func price_of(item_id: StringName) -> int:
	var raw: Variant = base_prices.get(item_id)
	if raw == null:
		# Hand-authored .tres files can end up with String keys where StringName
		# was meant; both spellings mean the same item to a player.
		raw = base_prices.get(String(item_id))
	if raw == null:
		return 0
	return maxi(0, int(raw))
