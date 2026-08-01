extends Node
## FILE: res://core/inventory_manager.gd
## ATTACHES TO: nothing directly. Register as Autoload "InventoryManager"
## (order 2, after EventBus).
##
## Owns ALL item counts (A5). Writes to inventory occur ONLY inside this
## autoload — either in response to EventBus.resource_gathered, or via the
## public methods below (called by 2D-side systems such as M7 buildings).
## Other modules query counts with direct read-only calls (A5, amended rule).

## ------------------------------------------------------------------ signals
## M1 API ADDITION (local signal — NOT part of the A7 EventBus contract):
## Fired on EVERY count change, including consumption. Required so the M7
## inventory UI can "update live without polling"; EventBus.resource_gathered
## alone only covers gains, never building-input consumption or upgrade costs.
## This signal does not cross the 2D/3D boundary, so it does not violate the
## A5 communication rule.
signal inventory_changed(item_id: StringName, new_count: int)

## ------------------------------------------------------------------- config
const _REGISTRY_PATH := "res://data/item_registry.tres"

## -------------------------------------------------------------------- state
var _registry: ItemRegistry = null
var _defs: Dictionary[StringName, ItemDef] = {}   # id -> ItemDef (validation + lookup)
var _counts: Dictionary[StringName, int] = {}     # id -> owned amount

## ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	_registry = load(_REGISTRY_PATH) as ItemRegistry
	if _registry == null:
		push_error("InventoryManager: failed to load ItemRegistry at '%s'. Inventory disabled." % _REGISTRY_PATH)
		return
	for def: ItemDef in _registry.items:
		if def == null or def.id == &"":
			push_error("InventoryManager: item_registry.tres contains a null or id-less ItemDef entry — skipped.")
			continue
		if _defs.has(def.id):
			push_error("InventoryManager: duplicate item id '%s' in registry — skipped." % def.id)
			continue
		_defs[def.id] = def
		_counts[def.id] = 0
	EventBus.resource_gathered.connect(_on_resource_gathered)

## -------------------------------------------------------- read-only queries
func is_valid_id(item_id: StringName) -> bool:
	return _defs.has(item_id)


func get_item_def(item_id: StringName) -> ItemDef:
	## Returns null for unregistered ids.
	return _defs.get(item_id)


func get_count(item_id: StringName) -> int:
	return _counts.get(item_id, 0)


func get_all_counts() -> Dictionary[StringName, int]:
	## Defensive copy — callers can never mutate internal state through it.
	return _counts.duplicate()


func can_afford(costs: Array) -> bool:
	## costs: Array of Dictionaries { "item_id": StringName, "amount": int }
	## (the A8 cost format used by RecipeDef.inputs and BuildingDef.upgrade_costs).
	## Duplicate entries for the same id are summed before checking.
	if costs.is_empty():
		return true
	var agg := _aggregate_costs(costs)
	if agg.is_empty():
		return false # costs contained an invalid entry (error already pushed)
	for item_id: StringName in agg:
		if _counts.get(item_id, 0) < agg[item_id]:
			return false
	return true

## ------------------------------------------------------------------- writes
func add_item(item_id: StringName, amount: int) -> bool:
	## Registry-validated add. Unregistered ids: error + no change (A7 contract).
	if not _defs.has(item_id):
		push_error("InventoryManager: unregistered item id '%s' — ignored (A7 contract violation by emitter)." % item_id)
		return false
	if amount <= 0:
		push_error("InventoryManager: add_item amount must be > 0 (got %d for '%s') — ignored." % [amount, item_id])
		return false
	_counts[item_id] = _counts[item_id] + amount
	inventory_changed.emit(item_id, _counts[item_id])
	return true


func remove_items(costs: Array) -> bool:
	## ATOMIC (M7 rule): either every cost is paid or nothing is consumed.
	## Returns false — with zero state change — if any entry is invalid or
	## unaffordable. Never partial-consumes.
	if costs.is_empty():
		return true
	var agg := _aggregate_costs(costs)
	if agg.is_empty():
		return false
	for item_id: StringName in agg:
		if _counts.get(item_id, 0) < agg[item_id]:
			return false
	for item_id: StringName in agg:
		_counts[item_id] = _counts[item_id] - agg[item_id]
		inventory_changed.emit(item_id, _counts[item_id])
	return true

## ------------------------------------------------------------ persistence
## InventoryManager serialises ITSELF, for the same reason GameState does: A5
## says item counts are only ever written in here, and a save loader that poked
## _counts from outside would be exactly the violation that rule exists to stop.
func to_save_dict() -> Dictionary:
	## Only non-zero counts are written — a save should not grow every time an
	## item id is added to the registry.
	var out: Dictionary = {}
	for item_id: StringName in _counts:
		if _counts[item_id] > 0:
			out[String(item_id)] = _counts[item_id]
	return out


func apply_save_dict(data: Dictionary) -> void:
	## Registry-validated, exactly like add_item: an id that no longer exists (a
	## renamed or removed item) is dropped with an error rather than resurrected
	## into a count no UI can name. Everything absent resets to zero, so loading
	## is a true replace and not a merge with whatever was already in memory.
	for item_id: StringName in _counts:
		_counts[item_id] = 0
	for raw_id: Variant in data:
		var item_id := StringName(raw_id)
		if not _defs.has(item_id):
			push_error("InventoryManager: save contains unregistered item id '%s' — dropped." % item_id)
			continue
		_counts[item_id] = maxi(0, int(data[raw_id]))
	# Emit only after the whole load, so a listening UI never sees a torn state.
	for item_id: StringName in _counts:
		inventory_changed.emit(item_id, _counts[item_id])

## ---------------------------------------------------------------- internals
func _on_resource_gathered(resource_id: StringName, amount: int) -> void:
	add_item(resource_id, amount)


func _aggregate_costs(costs: Array) -> Dictionary[StringName, int]:
	## Sums duplicate ids so a cost list like [{stone,3},{stone,3}] is checked
	## as 6 stone, not 3 twice (prevents a partial-consume exploit).
	## Returns {} if ANY entry is malformed, unregistered, or non-positive.
	var agg: Dictionary[StringName, int] = {}
	for entry: Variant in costs:
		if not (entry is Dictionary):
			push_error("InventoryManager: cost entry must be a Dictionary {item_id, amount} — got %s." % type_string(typeof(entry)))
			return {}
		var raw_id: Variant = entry.get("item_id")
		if raw_id == null or not (raw_id is StringName or raw_id is String):
			push_error("InventoryManager: cost entry missing a valid 'item_id'.")
			return {}
		var item_id := StringName(raw_id)
		if not _defs.has(item_id):
			push_error("InventoryManager: unregistered item id '%s' in cost list — rejected." % item_id)
			return {}
		var amount := int(entry.get("amount", 0))
		if amount <= 0:
			push_error("InventoryManager: cost amount for '%s' must be > 0 (got %d)." % [item_id, amount])
			return {}
		agg[item_id] = agg.get(item_id, 0) + amount
	return agg
