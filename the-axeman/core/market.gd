class_name Market
extends RefCounted
## FILE: res://core/market.gd
## ATTACHES TO: nothing. class_name + static methods only — do NOT register as an
## autoload, exactly as SaveSystem is not one. It owns no state (the price table
## is immutable data, the stock lives in InventoryManager and the cash lives in
## GameState), so it needs nothing an autoload provides, and a 5th autoload would
## have required an amendment the way GameFeel did. Call it as `Market.sell(...)`.
##
## THE ALWAYS-AVAILABLE BASIC BUYER (roadmap pillar 5): it buys any priced item,
## any quantity, at any time, forever. There is no contract to accept and no
## stock limit, so the player can always relax and chop.
##
## DIRECTIVE 6 IS NOT BYPASSED HERE. This file writes NOTHING itself: stock only
## ever leaves through InventoryManager.remove_items and cash only ever arrives
## through GameState.add_cash. Market decides *what a sale is*; the two owners
## still perform it.
##
## A SALE IS ATOMIC, in both directions. Amendment 4 made remove_items
## all-or-nothing and try_spend_cash the same for money; a sale is the pair of
## them, so it is ordered to keep that property:
##   1. price everything and refuse the whole sale if any line is unsellable;
##   2. remove the stock in ONE aggregated remove_items call — all or nothing;
##   3. only then pay.
## The stock is taken before the cash is paid on purpose: if step 2 fails nothing
## has happened at all, whereas paying first and failing to collect would mint
## money out of nothing.

const _PRICE_TABLE_PATH := "res://data/price_table.tres"

## Loaded once and cached for the life of the process. Prices are static data;
## re-reading the file on every sale would be pure I/O for an identical answer.
static var _prices: PriceTable = null


## ------------------------------------------------------------------- pricing
static func get_price(item_id: StringName) -> int:
	## Cash the basic buyer pays per unit. 0 means "not sellable" — an unpriced id
	## must never fall through to a free sale.
	var table := _table()
	if table == null:
		return 0
	if not InventoryManager.is_valid_id(item_id):
		return 0
	return table.price_of(item_id)


static func is_sellable(item_id: StringName) -> bool:
	return get_price(item_id) > 0


## What the whole yard would fetch right now, at base prices. The HUD shows it so
## a pile of firewood reads as money before the player commits to selling it.
static func get_stock_value() -> int:
	var total := 0
	for item_id: StringName in InventoryManager.get_all_counts():
		total += get_price(item_id) * InventoryManager.get_count(item_id)
	return total


## Every sellable id the player currently holds, richest line first, as
## { "item_id": StringName, "display_name": String, "count": int, "unit_price": int, "value": int }.
## Built from the registry rather than an authored list, so a new wood species
## shows up in the UI the moment it has a price and a piece in stock.
static func get_sellable_stock() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id: StringName in InventoryManager.get_all_counts():
		var count := InventoryManager.get_count(item_id)
		var unit := get_price(item_id)
		if count <= 0 or unit <= 0:
			continue
		var def: ItemDef = InventoryManager.get_item_def(item_id)
		rows.append({
			"item_id": item_id,
			"display_name": def.display_name if def != null else String(item_id),
			"count": count,
			"unit_price": unit,
			"value": unit * count,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["value"]) > int(b["value"]))
	return rows


## --------------------------------------------------------------------- sales
## Sells `count` of one item. Returns the cash earned, or 0 if the sale did not
## happen — in which case NOTHING changed: no stock left, no cash arrived, no
## signal fired.
static func sell(item_id: StringName, count: int) -> int:
	if count <= 0:
		push_error("Market: sell count must be > 0 (got %d for '%s') — ignored." % [count, item_id])
		return 0
	return sell_batch([{"item_id": item_id, "amount": count}])


## Sells the player's entire holding of one item.
static func sell_all_of(item_id: StringName) -> int:
	var count := InventoryManager.get_count(item_id)
	if count <= 0:
		return 0
	return sell(item_id, count)


## Sells every sellable thing in the yard in ONE transaction. Not a loop over
## sell(): a single aggregated call means a partial failure cannot leave the
## player having sold three species and kept two.
static func sell_everything() -> int:
	var lines: Array = []
	for row: Dictionary in get_sellable_stock():
		lines.append({"item_id": row["item_id"], "amount": row["count"]})
	if lines.is_empty():
		return 0
	return sell_batch(lines)


## The one code path every sale goes through.
## `lines`: Array of { "item_id": StringName, "amount": int } — the same cost-list
## shape InventoryManager.remove_items already takes, so duplicate ids are summed
## by the aggregator there rather than double-counted here.
static func sell_batch(lines: Array) -> int:
	if lines.is_empty():
		return 0

	# Price the whole basket FIRST. A basket containing one unsellable line is
	# refused entirely, so a "sell all" can never quietly dump an item the buyer
	# does not pay for.
	var payout := 0
	for line: Variant in lines:
		if not (line is Dictionary):
			push_error("Market: sale line must be a Dictionary {item_id, amount}.")
			return 0
		var item_id := StringName((line as Dictionary).get("item_id", &""))
		var amount := int((line as Dictionary).get("amount", 0))
		if amount <= 0:
			push_error("Market: sale amount for '%s' must be > 0 (got %d)." % [item_id, amount])
			return 0
		var unit := get_price(item_id)
		if unit <= 0:
			push_error("Market: the basic buyer does not buy '%s' — sale refused." % item_id)
			return 0
		payout += unit * amount

	if payout <= 0:
		return 0

	# THE PLAYER'S REPUTATION, priced in. Master Axeman and its kin add a fraction
	# on top of the base prices, which is exactly the layering the price table was
	# kept separate for: the market's base value is one thing, what THIS axeman
	# gets for it is another. Applied to the whole basket after it is priced, so a
	# sale is still all-or-nothing and rounding cannot make a line free.
	# Skill and mastery percentages are same-stat contributions: add them first,
	# then round the basket once. Fixed order premiums are paid later by
	# GameState.record_order_piece(), so this ordinary-sale modifier cannot touch
	# them.
	var bonus := SkillTree.total_effect(SkillNodeDef.Effect.CASH_GAIN) \
		+ SpeciesMastery.total_effect(GameplayModifierDef.Kind.CASH_GAIN)
	if bonus > 0.0:
		payout = maxi(payout, int(round(float(payout) * (1.0 + bonus))))

	# Stock first: if the player cannot cover the basket, remove_items changes
	# nothing and we are done before any money exists.
	if not InventoryManager.remove_items(lines):
		return 0

	GameState.add_cash(payout)
	return payout


## ---------------------------------------------------------------- internals
static func _table() -> PriceTable:
	if _prices == null:
		_prices = load(_PRICE_TABLE_PATH) as PriceTable
		if _prices == null:
			push_error("Market: failed to load the price table at '%s' — nothing is sellable." % _PRICE_TABLE_PATH)
	return _prices
