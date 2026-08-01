extends Node
## FILE: res://core/game_state.gd
## ATTACHES TO: nothing directly. Register as Autoload "GameState"
## (order 3, after EventBus).
##
## Owns ALL progression state: unlocked biomes, equipped tool tiers, building
## tiers (A5), and — added for the cozy lumberyard roadmap — CASH and LIFETIME
## WOOD CHOPPED. Writes occur ONLY here, either in response to EventBus signals
## or through the public methods below.
## Other modules (M5 gear gating, M7 upgrade UI) use direct read-only getters.

## ------------------------------------------------------------------ signals
## LOCAL signals — deliberately NOT added to EventBus, exactly as Amendment 2 did
## for InventoryManager.inventory_changed. A7 is frozen, and these do not cross
## the 2D/3D boundary: they exist so the M7 management UI can show cash and the
## lifetime counter without polling every frame.
signal cash_changed(new_amount: int)
signal lifetime_wood_chopped_changed(new_total: int)
## How much split firewood is currently STACKED IN THE YARD. Not inventory: since
## the yard sells a piece the moment it lands on the pile (Creative Director call,
## 2026-08-01), the wood is no longer owned by the time it is stacked — the pile is
## the visible record of work done since the last load left, and it is progression
## state, so it lives here.
signal yard_pile_changed(new_total: int)

## Fresh-save defaults (M1 acceptance: AXE tier == 1 on a fresh save).
const DEFAULT_TOOL_TIER := 1
const DEFAULT_BUILDING_TIER := 1
## PLACEHOLDER per Directive 3 — the starting purse is a tuning value, not a
## design fact. Sam sets the real number when M7A's prices are decided.
const DEFAULT_CASH := 0

## -------------------------------------------------------------------- state
## Keys are Enums.Biome ints; value is always true (presence = unlocked).
var _unlocked_biomes: Dictionary = { Enums.Biome.PINE_FOREST: true }
## Keys are Enums.ToolType ints -> int tier.
var _tool_tiers: Dictionary = {
	Enums.ToolType.AXE: DEFAULT_TOOL_TIER,
	Enums.ToolType.PICKAXE: DEFAULT_TOOL_TIER,
}
## Keys are building StringName ids -> int tier. Unknown ids read as tier 1.
var _building_tiers: Dictionary = {}
## The player's spendable money. INT, never float — currency accumulated in
## floating point drifts, and every price in this game is a whole number.
var _cash: int = DEFAULT_CASH
## Never decreases. The roadmap's "permanent celebratory number".
var _lifetime_wood_chopped: int = 0
## Firewood id -> pieces currently stacked on the yard's visible pile. Kept per
## species so a restored pile shows the same mix of woods it had when the player
## left, and emptied wholesale when a load is hauled away.
var _yard_pile: Dictionary = {}

## ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	EventBus.gear_upgraded.connect(_on_gear_upgraded)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.environment_unlocked.connect(_on_environment_unlocked)
	EventBus.resource_gathered.connect(_on_resource_gathered)

## -------------------------------------------------------- read-only queries
func get_tool_tier(tool_type: Enums.ToolType) -> int:
	return _tool_tiers.get(tool_type, DEFAULT_TOOL_TIER)


func get_building_tier(building_id: StringName) -> int:
	return _building_tiers.get(building_id, DEFAULT_BUILDING_TIER)


func is_biome_unlocked(biome: Enums.Biome) -> bool:
	return _unlocked_biomes.get(biome, false)


func get_unlocked_biomes() -> Array:
	## Array of Enums.Biome values. Defensive copy.
	return _unlocked_biomes.keys()


func get_cash() -> int:
	return _cash


func get_lifetime_wood_chopped() -> int:
	return _lifetime_wood_chopped


func can_afford_cash(amount: int) -> bool:
	return amount >= 0 and _cash >= amount


## { firewood id (StringName) -> pieces on the pile }. Defensive copy.
func get_yard_pile() -> Dictionary:
	return _yard_pile.duplicate()


func get_yard_pile_count() -> int:
	var total := 0
	for id: StringName in _yard_pile:
		total += int(_yard_pile[id])
	return total

## ------------------------------------------------- writes (public methods)
## Cash has no EventBus signal and does not get one: A7 is frozen, and a sale is
## a purely 2D-side event that never crosses into the action scene. The buyer and
## upgrade screens call these directly, the same way Amendment 5 let GameFeel
## expose register_impact() as a method rather than a signal.
func add_cash(amount: int) -> bool:
	if amount <= 0:
		push_error("GameState: add_cash amount must be > 0 (got %d) — ignored." % amount)
		return false
	_cash += amount
	cash_changed.emit(_cash)
	return true


func try_spend_cash(amount: int) -> bool:
	## ATOMIC, and the ONLY way cash leaves the purse: returns false with zero
	## state change if the player cannot afford it. Mirrors the all-or-nothing
	## rule Amendment 4 set for InventoryManager.remove_items, so a half-paid
	## upgrade is impossible.
	if amount <= 0:
		push_error("GameState: try_spend_cash amount must be > 0 (got %d) — ignored." % amount)
		return false
	if _cash < amount:
		return false
	_cash -= amount
	cash_changed.emit(_cash)
	return true

## ------------------------------------------------------------- the yard pile
## A piece of firewood landed on the pile. Called by the chopping game as each
## piece settles — the same moment it is sold — so the pile and the cash it earned
## are always the same event.
func add_to_yard_pile(item_id: StringName, amount := 1) -> void:
	if amount <= 0:
		push_error("GameState: add_to_yard_pile amount must be > 0 (got %d) — ignored." % amount)
		return
	_yard_pile[item_id] = int(_yard_pile.get(item_id, 0)) + amount
	yard_pile_changed.emit(get_yard_pile_count())


## The whole pile left the yard (the haul-away at `max_pile_pieces`). Wholesale on
## purpose: the pile is never partially removed, because the wood was paid for as
## it landed and there is nothing to reconcile.
func clear_yard_pile() -> void:
	if _yard_pile.is_empty():
		return
	_yard_pile = {}
	yard_pile_changed.emit(0)


## ------------------------------------------------------------ persistence
## GameState serialises ITSELF. SaveSystem orchestrates the file but never
## reaches into this state directly, so Directive 6 still holds: progression is
## only ever written in here.
func to_save_dict() -> Dictionary:
	var pile: Dictionary = {}
	for id: StringName in _yard_pile:
		pile[String(id)] = int(_yard_pile[id])
	return {
		"cash": _cash,
		"lifetime_wood_chopped": _lifetime_wood_chopped,
		"yard_pile": pile,
		"tool_tiers": _tool_tiers.duplicate(),
		"building_tiers": _building_tiers.duplicate(),
		"unlocked_biomes": _unlocked_biomes.keys(),
	}


func apply_save_dict(data: Dictionary) -> void:
	## Every field is optional and independently validated: a save written by an
	## older build must load, and a corrupted field must cost only that field.
	## Signals fire after the whole load so a UI never paints a half-restored state.
	_cash = maxi(0, int(data.get("cash", DEFAULT_CASH)))
	_lifetime_wood_chopped = maxi(0, int(data.get("lifetime_wood_chopped", 0)))

	_yard_pile = {}
	var pile: Variant = data.get("yard_pile")
	if pile is Dictionary:
		for key: Variant in pile as Dictionary:
			# String through the file, StringName to every reader — same trap the
			# building tiers hit.
			var n := maxi(0, int((pile as Dictionary)[key]))
			if n > 0:
				_yard_pile[StringName(key)] = n

	var tiers: Variant = data.get("tool_tiers")
	if tiers is Dictionary:
		_tool_tiers = {
			Enums.ToolType.AXE: maxi(DEFAULT_TOOL_TIER, int((tiers as Dictionary).get(Enums.ToolType.AXE, DEFAULT_TOOL_TIER))),
			Enums.ToolType.PICKAXE: maxi(DEFAULT_TOOL_TIER, int((tiers as Dictionary).get(Enums.ToolType.PICKAXE, DEFAULT_TOOL_TIER))),
		}

	var buildings: Variant = data.get("building_tiers")
	if buildings is Dictionary:
		_building_tiers = {}
		for key: Variant in buildings as Dictionary:
			# Keys come back as String through the file, but every reader looks
			# them up by StringName — normalise or every building reads as tier 1.
			_building_tiers[StringName(key)] = maxi(DEFAULT_BUILDING_TIER, int((buildings as Dictionary)[key]))

	var biomes: Variant = data.get("unlocked_biomes")
	if biomes is Array:
		_unlocked_biomes = {}
		for b: Variant in biomes as Array:
			_unlocked_biomes[int(b)] = true
		# The starting biome is never revocable; a save that lost it would strand
		# the player with nowhere to chop.
		_unlocked_biomes[Enums.Biome.PINE_FOREST] = true

	cash_changed.emit(_cash)
	lifetime_wood_chopped_changed.emit(_lifetime_wood_chopped)
	yard_pile_changed.emit(get_yard_pile_count())


func reset_to_defaults() -> void:
	## Fresh save. Used by SaveSystem when no file exists and by the test suites,
	## which need a known slate without restarting the process.
	_cash = DEFAULT_CASH
	_lifetime_wood_chopped = 0
	_yard_pile = {}
	_tool_tiers = {
		Enums.ToolType.AXE: DEFAULT_TOOL_TIER,
		Enums.ToolType.PICKAXE: DEFAULT_TOOL_TIER,
	}
	_building_tiers = {}
	_unlocked_biomes = { Enums.Biome.PINE_FOREST: true }
	cash_changed.emit(_cash)
	lifetime_wood_chopped_changed.emit(_lifetime_wood_chopped)
	yard_pile_changed.emit(0)

## ------------------------------------------- writes (EventBus-driven ONLY)
func _on_gear_upgraded(tool_type: Enums.ToolType, new_tier: int) -> void:
	## Tiers only ever move up. A non-increasing "upgrade" is almost certainly
	## an emitter bug, so it is warned about and ignored rather than applied.
	var current := get_tool_tier(tool_type)
	if new_tier <= current:
		push_warning("GameState: gear_upgraded for tool %d with non-increasing tier %d (current %d) — ignored." % [tool_type, new_tier, current])
		return
	_tool_tiers[tool_type] = new_tier


func _on_building_upgraded(building_id: StringName, new_tier: int) -> void:
	var current := get_building_tier(building_id)
	if new_tier <= current:
		push_warning("GameState: building_upgraded for '%s' with non-increasing tier %d (current %d) — ignored." % [building_id, new_tier, current])
		return
	_building_tiers[building_id] = new_tier


## Lifetime wood chopped, fed by the A7 signal the chopping game already emits —
## no new contract, no change to the mini-game.
##
## Filtered by ItemCategory.RAW_WOOD rather than by a list of wood ids ON PURPOSE:
## whether the registry ends up calling the yield `oak_firewood` or `oak_firewood` is
## still an open Creative Director question, and a category filter survives that
## rename untouched. It also picks up a new species for free.
##
## Monotonic BY CONSTRUCTION: this listens only to gathers. Selling wood goes
## through InventoryManager.remove_items, which this never sees, so the
## celebratory number can never tick down.
##
## KNOWN BOUNDARY, revisit at M8: this counts wood GATHERED, which today can only
## happen by chopping. If yard staff ever deposit wood they gathered themselves,
## their haul would be counted as the player's chopping unless this is narrowed.
func _on_resource_gathered(resource_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var def: ItemDef = InventoryManager.get_item_def(resource_id)
	if def == null or def.category != Enums.ItemCategory.RAW_WOOD:
		return
	_lifetime_wood_chopped += amount
	lifetime_wood_chopped_changed.emit(_lifetime_wood_chopped)


func _on_environment_unlocked(biome_id: Enums.Biome) -> void:
	if _unlocked_biomes.get(biome_id, false):
		push_warning("GameState: environment_unlocked for already-unlocked biome %d — ignored." % biome_id)
		return
	_unlocked_biomes[biome_id] = true
