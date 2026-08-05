class_name Shop
extends RefCounted
## FILE: res://core/shop.gd
## ATTACHES TO: nothing. class_name + static methods only — do NOT register as an
## autoload, for the same reasons as SaveSystem and Market: it owns no state (the
## catalogue is immutable data, the levels live in GameState, the cash lives in
## GameState), and a 5th autoload would need an amendment the way GameFeel did.
##
## The yard's shop counter: what is for sale, what the next level costs, and the
## one code path a purchase goes through.
##
## LEVELS ARE STORED AS BUILDING TIERS. `GameState.get_building_tier(id)` is where
## each owned catalogue level lives, bumped through the existing A7
## `building_upgraded(StringName, int)` signal. That is deliberate: A7 is frozen
## (Directive 2), and a shop upgrade is exactly what that signal already
## describes — a named thing that goes up a tier and has to persist. Nothing new
## was added to the contract to sell physical equipment.
##
## NOTE the off-by-one that comes with that home: `DEFAULT_BUILDING_TIER` is 1, so
## an upgrade nobody has bought reads as tier 1. LEVEL = TIER - 1, and level 0
## means "no bonus". Every reader goes through `get_level()` so that conversion
## lives in exactly one place.
##
## A PURCHASE IS ATOMIC, and ordered so it cannot half-happen: refuse anything
## already maxed, then spend the cash (Amendment 4's all-or-nothing rule — a
## refused purchase changes nothing and emits nothing), and only once the money is
## actually gone, raise the tier. Raising the tier first and failing to charge
## would hand out a free upgrade.

const _TABLE_PATH := "res://data/upgrade_table.tres"

## Loaded once and cached for the life of the process — a catalogue is static data.
static var _table: UpgradeTable = null


## ----------------------------------------------------------------- catalogue
static func get_upgrades() -> Array[UpgradeDef]:
	var table := _catalogue()
	if table == null:
		return []
	return table.upgrades


static func get_upgrade(id: StringName) -> UpgradeDef:
	var table := _catalogue()
	return null if table == null else table.get_upgrade(id)


## Catalogue rows visible right now: unlocked or already-owned rows only, in
## approved order. Locked content is advertised by the reward that reveals it,
## never by a disabled shelf row.
static func get_visible_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for def: UpgradeDef in get_upgrades():
		if def == null:
			continue
		if is_unlocked(def.id):
			out.append(def)
	return out


static func is_visible(id: StringName) -> bool:
	for def: UpgradeDef in get_visible_upgrades():
		if def.id == id:
			return true
	return false


static func is_unlocked(id: StringName) -> bool:
	var def := get_upgrade(id)
	if def == null:
		return false
	# Ownership is authoritative. If an old save predates an unlock-history field,
	# or a later data pass changes a prerequisite, equipment the player paid for
	# must remain visible and usable rather than appearing re-locked.
	if get_level(id) > 0:
		return true
	if def.unlock_order_id != &"" and not GameState.has_completed_order(def.unlock_order_id):
		return false
	if GameState.get_haul_aways_completed() < def.unlock_after_haul_aways:
		return false
	if def.required_upgrade_id != &"" and get_level(def.required_upgrade_id) <= 0:
		return false
	if def.required_mastery_species_id != &"" \
			and not GameState.is_species_mastered(def.required_mastery_species_id):
		return false
	if GameState.get_mastered_species_count() < def.required_mastered_species_count:
		return false
	return true


## How many levels of `id` the player has bought. 0 = none.
static func get_level(id: StringName) -> int:
	return maxi(0, GameState.get_building_tier(id) - GameState.DEFAULT_BUILDING_TIER)


## Completed ownership is derived from the same persisted building tier used by
## every effect reader. There is deliberately no separate purchase-history list
## for the Purchased tab to save, migrate or let drift out of sync.
static func is_fully_purchased(id: StringName) -> bool:
	var def := get_upgrade(id)
	if def == null:
		return false
	var level := get_level(id)
	return level > 0 and def.is_maxed(level)


## Every completed row in authored catalogue order. This walks the full table,
## not only the current reveal prefix: ownership remains visible even if a later
## tuning pass changes a prerequisite that sits before an old paid purchase.
static func get_purchased_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for def: UpgradeDef in get_upgrades():
		if def != null and is_fully_purchased(def.id):
			out.append(def)
	return out


## Cash for the next level, or 0 if it is maxed or unknown (nothing to buy).
static func get_next_cost(id: StringName) -> int:
	var def := get_upgrade(id)
	if def == null:
		return 0
	var level := get_level(id)
	if def.is_maxed(level):
		return 0
	return def.cost_for_level(level)


static func can_buy(id: StringName) -> bool:
	var def := get_upgrade(id)
	if def == null or not is_visible(id) or not is_unlocked(id) or def.is_maxed(get_level(id)):
		return false
	return GameState.can_afford_cash(get_next_cost(id))


## Summed equipment contribution. Skills have their own equivalent; keeping the
## two queries separate makes it impossible for equipment to grant a named skill
## identity by accident.
static func total_effect(kind: UpgradeDef.Effect) -> float:
	var total := 0.0
	for def: UpgradeDef in get_upgrades():
		if def != null and def.effect == kind:
			total += float(get_level(def.id)) * def.effect_step
	return total


## ------------------------------------------------------------------ purchase
## Buys one level. Returns the NEW level, or -1 if nothing happened — in which
## case nothing happened at all: no cash left the purse, no tier moved, no signal
## fired.
static func buy(id: StringName) -> int:
	var def := get_upgrade(id)
	if def == null:
		push_error("Shop: no upgrade named '%s' — purchase refused." % id)
		return -1
	var level := get_level(id)
	if not is_visible(id) or not is_unlocked(id) or def.is_maxed(level):
		return -1

	var cost := def.cost_for_level(level)
	if not GameState.try_spend_cash(cost):
		return -1

	# Paid for: now it is owned. A7's own signal, so GameState stores and
	# persists the new tier through the path it already had.
	EventBus.building_upgraded.emit(id, GameState.get_building_tier(id) + 1)
	return get_level(id)


## ---------------------------------------------------------------- internals
static func _catalogue() -> UpgradeTable:
	if _table == null:
		_table = load(_TABLE_PATH) as UpgradeTable
		if _table == null:
			push_error("Shop: failed to load '%s' — the shop is empty." % _TABLE_PATH)
	return _table
