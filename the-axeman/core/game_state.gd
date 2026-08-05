extends Node
## FILE: res://core/game_state.gd
## ATTACHES TO: nothing directly. Register as Autoload "GameState"
## (order 3, after EventBus).
##
## Owns ALL progression state: unlocked biomes, equipped tool tiers, building
## tiers (A5), and — added for the cozy lumberyard roadmap — CASH, LIFETIME WOOD
## CHOPPED, WHICH WOODS THE PLAYER OWNS AND IS CHOPPING, and (2026-08-02) XP,
## the level derived from it, and the skill tree that level pays for. Writes
## occur ONLY here, either in response to EventBus signals or through the public
## methods below.
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
## Completed physical 50-piece departures. This is a monotonic yard milestone,
## not a second capacity counter; Handcart uses the first one as its unlock.
signal haul_aways_changed(new_total: int)
## The player chose a different wood to put on the block.
signal selected_species_changed(species_id: StringName)
## Experience earned (2026-08-02). Carries the new TOTAL, like every other counter
## signal here, so a bar can repaint from one argument.
signal xp_changed(new_total: int)
## A LEVEL WAS GAINED. Fires once per level even when a single award crosses
## several, in ascending order — the same rule the wood milestones used, and for
## the same reason: a level-up is a moment, and three moments at once still owe
## the player three of them.
signal level_gained(new_level: int)
## Skill points available to spend changed — earned by levelling, spent in the
## tree. Separate from `level_gained` because spending moves it too.
signal skill_points_changed(available: int)
## A skill node's level moved.
signal skill_level_changed(skill_id: StringName, new_level: int)
## A wood was BOUGHT. Since 2026-08-02 species are owned, not derived (see
## `_owned_species`), so this is a real event rather than a threshold crossing.
signal species_purchased(species_id: StringName)
## One species' manual mastery progress changed. The total is carried so save,
## HUD and future reward readers never need to infer a delta or poll per frame.
signal species_mastery_changed(species_id: StringName, new_progress: int)
## Which certified installed profile the Mechanical Splitter should work when its
## watched runtime arrives. Empty means installed but deliberately idle.
signal splitter_assignment_changed(species_id: StringName)
## Introductory order state is local progression, never an A7 cross-mode event.
## The zero-argument repaint signal covers accept, progress and restore; the
## completion signal carries the celebratory facts a HUD needs.
signal order_state_changed
signal order_completed(order_id: StringName, cash_bonus: int)
## Repeatable commission offers/progress are also progression-owned here. The
## completion payload is a presentation receipt; cash is already authoritative
## before it fires.
signal commission_state_changed
signal commission_completed(offer: Dictionary, cash_bonus: int)
## Local repaint/restore notification for physical equipment. A7's
## building_upgraded remains the purchase command; this signal also fires after
## loading tiers from disk, when no purchase event exists to replay.
signal building_tiers_changed

## Fresh-save defaults (M1 acceptance: AXE tier == 1 on a fresh save).
const DEFAULT_TOOL_TIER := 1
const DEFAULT_BUILDING_TIER := 1
## Creative Director call, 2026-08-01: a full visible load is 50 pieces. This
## lives beside the yard-pile state so the chopping scene and the HUD never grow
## separate opinions about when a production load is ready to leave.
const YARD_PILE_CAPACITY := 50

## Shop upgrade ids. They are stored as BUILDING TIERS (see res://core/shop.gd for
## why that is the honest home and not a new contract), and they live here rather
## than on either the shop or the chopping game because both sides read them: the
## shop sells the level, the mini-game spends it.
const UPGRADE_BALANCED_AXE := &"balanced_axe"
const UPGRADE_REINFORCED_BLOCK := &"reinforced_chopping_block"
const UPGRADE_SUPPLIER_LEDGER := &"supplier_ledger"
const UPGRADE_HANDCART := &"handcart"
const UPGRADE_COFFEE_THERMOS := &"coffee_thermos"
## PLACEHOLDER per Directive 3 — the starting purse is a tuning value, not a
## design fact. Sam sets the real number when M7A's prices are decided.
const DEFAULT_CASH := 0

## -------------------------------------------------------------------- state
## Keys are Enums.Biome ints; value is always true (presence = unlocked).
var _unlocked_biomes: Dictionary = { Enums.Biome.PINE_FOREST: true }
## Keys are Enums.ToolType ints -> int tier.
var _tool_tiers: Dictionary = {
	Enums.ToolType.AXE: DEFAULT_TOOL_TIER,
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
var _haul_aways_completed := 0
## Which wood the player has chosen to chop (a SpeciesDef.id, see
## res://data/species_table.tres). Empty means "never chosen" and reads as the
## starting species — see get_selected_species().
##
var _selected_species: StringName = &""
## Species ids the player has BOUGHT. Stored, and this is a deliberate reversal:
## until 2026-08-02 the unlocked set was derived from `_lifetime_wood_chopped`,
## which was safe because that counter is monotonic and could not disagree with
## itself. Sam then made a wood a LEVEL-GATED CASH PURCHASE, and a purchase is a
## discrete event that nothing else implies — the player's level says they *may*
## buy it, never that they *did*. So this has to persist.
##
## The starting wood is never in here; `owns_species()` grants it, so a fresh save
## and a corrupted one both still have something to chop.
var _owned_species: Dictionary = {}
## Species id -> bounded manual log completions. Reached reward thresholds and
## certification are derived from this one persisted counter; no parallel
## booleans can drift when the shared threshold ladder is retuned.
var _species_mastery_progress: Dictionary = {}
## One species at a time. Eligibility is derived from current certification and
## purchased profile ownership; this stores only the player's routing choice.
var _splitter_assigned_species: StringName = &""
## Total experience, monotonic — nothing takes XP away, which is what lets the
## LEVEL be derived from it (see LevelCurve) rather than stored alongside it.
var _xp: int = 0
## Skill node id -> levels bought. Skill POINTS available are derived from level
## minus what this has cost, so there is no separate purse to drift out of step.
var _skill_levels: Dictionary = {}
## Ranks carried forward from save v1. They remain part of `_skill_levels`; this
## parallel count says only how many of those ranks retain their prototype
## per-rank price. It is not a point purse and cannot be spent independently.
var _legacy_skill_ranks: Dictionary = {}
## Proc id (StringName) -> consecutive DRY (non-fired) rolls since it last
## fired. Bounded bad-luck protection (see ProcResolver) reads this so a
## reload cannot cheaply reroll a live streak — see the M7C brief's fairness
## contract: "Its state persists so save/reload cannot cheaply reroll."
var _proc_dry_streak: Dictionary = {}
const _V1_SKILL_COSTS := {
	&"strong_arms": 1,
	&"quick_hands": 1,
	&"ready_stance": 2,
	&"quick_study": 3,
}
## Multiple patient manual deliveries may be active together. Dictionary keys
## are authored/generated ids and values are bounded progress counts.
var _active_orders: Dictionary = {}
var _completed_orders: Dictionary = {}
## M9 repeatable manual work. Offers are immutable generated snapshots until one
## is completed; the generation serial is the only replacement authority.
var _commission_offers: Array[Dictionary] = []
var _commission_generation := 0
var _active_commissions: Dictionary = {}
var _completed_commissions := 0

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


func get_yard_pile_capacity() -> int:
	return YARD_PILE_CAPACITY


func get_haul_aways_completed() -> int:
	return _haul_aways_completed


## ---------------------------------------------------- experience and levels
func get_xp() -> int:
	return _xp


## DERIVED from XP, never stored — XP is monotonic, so a level computed from it
## cannot disagree with it, and retuning the curve re-levels an existing save
## instead of leaving it on thresholds that no longer exist.
func get_level() -> int:
	return _level_curve().level_for_xp(_xp)


## 0..1 through the current level. 1.0 at the cap, so a bar reads full.
func get_level_progress() -> float:
	return _level_curve().progress_through_level(_xp)


## Presentation may trail the authoritative total while XP orbs are in flight.
## These read-only helpers let the HUD draw that earlier total without owning or
## mutating progression itself.
func get_level_for_xp(total_xp: int) -> int:
	return _level_curve().level_for_xp(maxi(0, total_xp))


func get_level_progress_for_xp(total_xp: int) -> float:
	return _level_curve().progress_through_level(maxi(0, total_xp))


func get_xp_to_next_level_for_xp(total_xp: int) -> int:
	return _level_curve().xp_remaining(maxi(0, total_xp))


func get_xp_to_next_level() -> int:
	return _level_curve().xp_remaining(_xp)


func is_max_level() -> bool:
	return get_level() >= LevelCurve.MAX_LEVEL


## Skill points EARNED over the run: one per level gained, so level 1 has none and
## level 99 has 98. Derived from the level, which is derived from XP.
func get_skill_points_earned() -> int:
	return maxi(0, get_level() - 1)


func get_skill_points_spent() -> int:
	var spent := 0
	for id: StringName in _skill_levels:
		var def := SkillTree.get_node_def(id)
		if def != null:
			var level := int(_skill_levels[id])
			var legacy := mini(level, int(_legacy_skill_ranks.get(id, 0)))
			spent += legacy * int(_V1_SKILL_COSTS.get(id, def.cost))
			spent += (level - legacy) * def.cost
	return spent


## What is left to spend. Computed rather than banked so a retuned tree or a
## renamed node cannot leave the player holding points for a skill that is gone.
func get_skill_points_available() -> int:
	return maxi(0, get_skill_points_earned() - get_skill_points_spent())


func get_skill_level(skill_id: StringName) -> int:
	return int(_skill_levels.get(skill_id, 0))


func get_skill_levels() -> Dictionary:
	return _skill_levels.duplicate()


## ---------------------------------------------------- proc fairness (M7C)
func get_proc_dry_streak(proc_id: StringName) -> int:
	return int(_proc_dry_streak.get(proc_id, 0))


## Records one resolved roll. Called by ProcResolver only — GameState remains
## the sole progression writer (Directive 6); the resolver decides the
## outcome, this owns its consequence, the same split SkillTree.buy() /
## set_skill_level() already use. No signal: this is fairness bookkeeping, not
## a celebratory event, and nothing paints from it directly.
func note_proc_result(proc_id: StringName, fired: bool) -> void:
	if fired:
		_proc_dry_streak.erase(proc_id)
	else:
		_proc_dry_streak[proc_id] = get_proc_dry_streak(proc_id) + 1


## ------------------------------------------------------- wood species (M7A)
## Does the player OWN this wood? The starting species is always owned, so a fresh
## save, a wiped one and a save whose purchases were corrupted all still have
## something to put on the block.
func owns_species(species_id: StringName) -> bool:
	if SpeciesTable.by_id(species_id) == null:
		return false
	var start := SpeciesTable.starting_species()
	if start != null and start.id == species_id:
		return true
	return _owned_species.get(species_id, false)


## Is the player high enough level for this wood to be FOR SALE? Separate from
## owning it: the level gate says a wood may be bought, never that it was.
func can_species_be_bought(species_id: StringName) -> bool:
	var def := SpeciesTable.by_id(species_id)
	if def == null or owns_species(species_id):
		return false
	if def.supplier_upgrade_id != &"" and get_building_tier(def.supplier_upgrade_id) <= DEFAULT_BUILDING_TIER:
		return false
	return get_level() >= def.unlock_level


## Every species the player owns, in ladder order.
func get_owned_species() -> Array[SpeciesDef]:
	var out: Array[SpeciesDef] = []
	for s: SpeciesDef in SpeciesTable.all():
		if s != null and owns_species(s.id):
			out.append(s)
	return out


## The next wood up the ladder the player does not own — the goal the woodshed
## dangles, whether it is affordable yet or not.
func get_next_unowned_species() -> SpeciesDef:
	for s: SpeciesDef in SpeciesTable.all():
		if s != null and not owns_species(s.id):
			return s
	return null


## The wood that goes on the block. ALWAYS returns something choppable: a save
## that predates the selector, a species id deleted from the table, or a choice
## that a retuned ladder has put back out of reach all fall through to the
## starting wood rather than leaving the block empty.
func get_selected_species() -> StringName:
	if _selected_species != &"" and owns_species(_selected_species):
		return _selected_species
	var start := SpeciesTable.starting_species()
	return &"" if start == null else start.id


## ------------------------------------------------------ species mastery (M8)
func get_species_mastery_progress(species_id: StringName) -> int:
	var table := M7CContent.mastery()
	var definition: SpeciesMasteryDef = table.by_species_id(species_id) \
		if table != null else null
	if definition == null:
		return 0
	return clampi(int(_species_mastery_progress.get(species_id, 0)), 0,
		definition.mastery_target)


func get_species_mastery_threshold_count(species_id: StringName) -> int:
	var table := M7CContent.mastery()
	if table == null or table.by_species_id(species_id) == null:
		return 0
	return table.reached_threshold_count(get_species_mastery_progress(species_id))


func is_species_mastered(species_id: StringName) -> bool:
	var table := M7CContent.mastery()
	var definition: SpeciesMasteryDef = table.by_species_id(species_id) if table != null else null
	return definition != null \
		and get_species_mastery_progress(species_id) >= definition.mastery_target


## Derived certification total for M8 catalogue gates. It is deliberately not
## persisted beside per-species progress: a retuned mastery table must never
## leave a saved count disagreeing with the species that actually qualify.
func get_mastered_species_count() -> int:
	var total := 0
	for species: SpeciesDef in SpeciesTable.all():
		if species != null and is_species_mastered(species.id):
			total += 1
	return total


func get_splitter_assigned_species() -> StringName:
	return _splitter_assigned_species


## ------------------------------------------------------------- orders (M7A)
func get_active_order_id() -> StringName:
	var ids := get_active_order_ids()
	return &"" if ids.is_empty() else ids[0]


func get_active_order() -> OrderDef:
	return Orders.by_id(get_active_order_id())


func get_active_order_progress() -> int:
	return get_active_order_progress_for(get_active_order_id())


func get_active_order_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for order: OrderDef in Orders.all():
		if order != null and _active_orders.has(order.id):
			out.append(order.id)
	return out


func get_active_order_progress_for(order_id: StringName) -> int:
	return maxi(0, int(_active_orders.get(order_id, 0)))


func is_order_active(order_id: StringName) -> bool:
	return _active_orders.has(order_id)


func has_completed_order(order_id: StringName) -> bool:
	return _completed_orders.get(order_id, false)


func get_completed_order_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for order: OrderDef in Orders.all():
		if order != null and has_completed_order(order.id):
			out.append(order.id)
	return out


## ------------------------------------------------ commissions (M9)
func get_commission_offers() -> Array[Dictionary]:
	return _commission_offers.duplicate(true)


func get_active_commission_id() -> StringName:
	var ids := get_active_commission_ids()
	return &"" if ids.is_empty() else ids[0]


func get_active_commission() -> Dictionary:
	var active_id := get_active_commission_id()
	for offer: Dictionary in _commission_offers:
		if StringName(offer.get("id", &"")) == active_id:
			return offer.duplicate(true)
	return {}


func get_active_commission_progress() -> int:
	return get_active_commission_progress_for(get_active_commission_id())


func get_active_commission_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for offer: Dictionary in _commission_offers:
		var offer_id := StringName(offer.get("id", &""))
		if _active_commissions.has(offer_id):
			out.append(offer_id)
	return out


func get_active_commissions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for offer: Dictionary in _commission_offers:
		var offer_id := StringName(offer.get("id", &""))
		if not _active_commissions.has(offer_id):
			continue
		var active := offer.duplicate(true)
		active["progress"] = get_active_commission_progress_for(offer_id)
		out.append(active)
	return out


func get_active_commission_progress_for(offer_id: StringName) -> int:
	return maxi(0, int(_active_commissions.get(offer_id, 0)))


func is_commission_active(offer_id: StringName) -> bool:
	return _active_commissions.has(offer_id)


func get_completed_commission_count() -> int:
	return _completed_commissions


func has_active_manual_job() -> bool:
	return not _active_orders.is_empty() or not _active_commissions.is_empty()


func get_active_manual_job_count() -> int:
	return _active_orders.size() + _active_commissions.size()


## First entry into the earned commission flow creates the persisted standing
## offer set. Save migration deliberately leaves it empty so loading never
## invents completed work or pays a reward.
func ensure_commission_offers() -> bool:
	if not Orders.commissions_unlocked() or not _commission_offers.is_empty():
		return false
	_commission_offers = Orders.generate_commission_offers(_commission_generation)
	if _commission_offers.is_empty():
		return false
	commission_state_changed.emit()
	return true

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


## Called exactly when a full physical load is handed to WoodPile's haul
## animation. Separate from clear_yard_pile so tests, save recovery and debug
## rebuilds cannot accidentally unlock the Handcart by merely emptying state.
func record_haul_away() -> void:
	_haul_aways_completed += 1
	haul_aways_changed.emit(_haul_aways_completed)


## ------------------------------------------------- choosing the wood (M7A)
## Put a different wood on the block. Returns false and changes NOTHING — no
## state, no signal — if the species is unknown or has not been earned yet, so a
## stale HUD row or a crafted save can never hand the player Lignum Vitae on
## their first log. Same all-or-nothing shape as try_spend_cash.
func select_species(species_id: StringName) -> bool:
	var def := SpeciesTable.by_id(species_id)
	if def == null:
		push_error("GameState: no wood species named '%s' — selection refused." % species_id)
		return false
	if not owns_species(species_id):
		return false
	if _selected_species == species_id:
		return true   # already on the block; not a failure, just nothing to do
	_selected_species = species_id
	selected_species_changed.emit(species_id)
	return true


## ------------------------------------------------ experience (public writes)
## Award experience. Monotonic on purpose — there is no `spend_xp`, because the
## level is DERIVED from this number and taking XP away would silently un-level
## the player and strand skill points they had already spent.
##
## Levels are announced ONE AT A TIME even when a single award crosses several: a
## fat log at low level can jump two, and two level-ups still owe the player two
## moments. Same rule the wood milestones used before they became purchases.
func add_xp(amount: int) -> bool:
	if amount <= 0:
		push_error("GameState: add_xp amount must be > 0 (got %d) — ignored." % amount)
		return false
	var before := get_level()
	_xp += amount
	xp_changed.emit(_xp)
	var after := get_level()
	if after > before:
		for level in range(before + 1, after + 1):
			level_gained.emit(level)
		skill_points_changed.emit(get_skill_points_available())
	return true


## Credit one player-started completed log. The chopping scene calls this from
## its already de-duplicated manual root outcome, so a proc may land the final
## swing without turning one log into two mastery awards.
func record_species_completion(species_id: StringName) -> bool:
	var table := M7CContent.mastery()
	var definition: SpeciesMasteryDef = table.by_species_id(species_id) if table != null else null
	if definition == null:
		push_error("GameState: mastery completion names unknown species '%s' — ignored." % species_id)
		return false
	var before := get_species_mastery_progress(species_id)
	if before >= definition.mastery_target:
		return false
	var after := mini(definition.mastery_target,
		before + definition.manual_completion_award)
	_species_mastery_progress[species_id] = after
	species_mastery_changed.emit(species_id, after)
	return true


## Routes the installed splitter to one certified, purchased profile. Invalid
## requests change nothing and emit nothing; assignment is progression state, so
## the tree window asks here rather than mutating a UI-local selection.
func assign_splitter_species(species_id: StringName) -> bool:
	if not MechanicalSplitter.can_accept_species(species_id):
		return false
	if _splitter_assigned_species == species_id:
		return true
	_splitter_assigned_species = species_id
	splitter_assignment_changed.emit(species_id)
	return true


## Can the player cover `amount` skill points right now?
##
## DELIBERATELY NOT `try_spend_*`, which everywhere else in this file means "take
## it or change nothing". There is no pool to take from: points spent are DERIVED
## by summing what the owned skills cost, so recording the skill IS the spend, and
## a method named `try_spend` that decremented nothing would be a lie a reader
## would have to go and disprove. Atomicity still holds — SkillTree.buy() asks
## this and then calls set_skill_level(), and nothing observes the gap.
func can_afford_skill_points(amount: int) -> bool:
	if amount <= 0:
		push_error("GameState: can_afford_skill_points amount must be > 0 (got %d) — ignored." % amount)
		return false
	return get_skill_points_available() >= amount


## Records a bought skill level. Called by SkillTree.buy(), which has already
## checked cost, cap and prerequisites — Directive 6: the tree decides, the owner
## of progression writes.
func set_skill_level(skill_id: StringName, new_level: int) -> void:
	var current := get_skill_level(skill_id)
	if new_level <= current:
		push_warning("GameState: set_skill_level for '%s' with non-increasing level %d (current %d) — ignored."
			% [skill_id, new_level, current])
		return
	_skill_levels[skill_id] = new_level
	skill_level_changed.emit(skill_id, new_level)
	skill_points_changed.emit(get_skill_points_available())


## ------------------------------------------------- buying a wood (2026-08-02)
## Buys a species outright. ATOMIC and ordered so it cannot half-happen: refuse an
## unknown wood, one already owned, one the player is too low a level for, or one
## they cannot afford — then take the cash, and only once it is actually gone,
## grant the wood. Granting first and failing to charge would be a free hardwood.
func try_buy_species(species_id: StringName) -> bool:
	var def := SpeciesTable.by_id(species_id)
	if def == null:
		push_error("GameState: no wood species named '%s' — purchase refused." % species_id)
		return false
	if not can_species_be_bought(species_id):
		return false
	if not try_spend_cash(def.unlock_cost):
		return false
	_owned_species[species_id] = true
	species_purchased.emit(species_id)
	return true


## ------------------------------------------------------ manual job writes
## Accept one authored order. Contracts remain one-time, but the player may keep
## several patient deliveries active and let one matching sale serve each.
func accept_order(order_id: StringName) -> bool:
	var order := Orders.by_id(order_id)
	if order == null:
		push_error("GameState: no order named '%s' — acceptance refused." % order_id)
		return false
	if is_order_active(order_id) or has_completed_order(order_id):
		return false
	if not Orders.is_available(order):
		return false
	_active_orders[order_id] = 0
	order_state_changed.emit()
	return true


## Accept one of the three persisted standing offers. Each offer is independently
## active, and accepting one never rerolls or displaces the others.
func accept_commission(offer_id: StringName) -> bool:
	if is_commission_active(offer_id) or not Orders.commissions_unlocked():
		return false
	if _commission_offers.is_empty():
		ensure_commission_offers()
	for offer: Dictionary in _commission_offers:
		if StringName(offer.get("id", &"")) != offer_id:
			continue
		if Orders.normalise_commission_offer(offer).is_empty():
			return false
		_active_commissions[offer_id] = 0
		commission_state_changed.emit()
		return true
	return false


## Credit one successfully sold MANUAL piece to every matching active delivery.
## Orders calls this only after Market.sell succeeds. The Mechanical Splitter
## uses its separate Market.sell_automation path and never reaches this method.
func record_manual_delivery_piece(item_id: StringName) -> bool:
	var order_moved := _record_active_order_piece(item_id)
	var commission_moved := _record_active_commission_piece(item_id)
	return order_moved or commission_moved


## Compatibility seam for existing tests/callers; all production settlement now
## names the shared manual-delivery contract explicitly above.
func record_order_piece(item_id: StringName) -> bool:
	return record_manual_delivery_piece(item_id)


func _record_active_order_piece(item_id: StringName) -> bool:
	var moved := false
	var completed: Array[Dictionary] = []
	for order: OrderDef in Orders.all():
		if order == null or not is_order_active(order.id) or not order.matches(item_id):
			continue
		moved = true
		var progress := get_active_order_progress_for(order.id) + 1
		if progress < order.required_count:
			_active_orders[order.id] = progress
			continue
		_active_orders.erase(order.id)
		_completed_orders[order.id] = true
		completed.append({"id": order.id, "bonus": order.cash_bonus})
	if not moved:
		return false
	for receipt: Dictionary in completed:
		var bonus := int(receipt.get("bonus", 0))
		if bonus > 0:
			add_cash(bonus)
	order_state_changed.emit()
	for receipt: Dictionary in completed:
		order_completed.emit(StringName(receipt.get("id", &"")),
			int(receipt.get("bonus", 0)))
	return true


func _record_active_commission_piece(item_id: StringName) -> bool:
	var moved := false
	var completed: Array[Dictionary] = []
	for offer: Dictionary in _commission_offers.duplicate(true):
		var offer_id := StringName(offer.get("id", &""))
		if not is_commission_active(offer_id) \
				or not Orders.commission_matches(offer, item_id):
			continue
		moved = true
		var progress := get_active_commission_progress_for(offer_id) + 1
		if progress < int(offer.get("required_count", 0)):
			_active_commissions[offer_id] = progress
			continue
		_active_commissions.erase(offer_id)
		completed.append(offer.duplicate(true))
	if not moved:
		return false
	for completed_offer: Dictionary in completed:
		var completed_id := StringName(completed_offer.get("id", &""))
		var slot := -1
		for index in range(_commission_offers.size()):
			if StringName(_commission_offers[index].get("id", &"")) == completed_id:
				slot = index
				break
		_commission_generation += 1
		var replacements := Orders.generate_commission_offers(_commission_generation)
		if slot >= 0 and slot < replacements.size():
			_commission_offers[slot] = replacements[slot]
		_completed_commissions += 1
		var bonus := int(completed_offer.get("cash_bonus", 0))
		if bonus > 0:
			add_cash(bonus)
	commission_state_changed.emit()
	for completed_offer: Dictionary in completed:
		commission_completed.emit(completed_offer,
			int(completed_offer.get("cash_bonus", 0)))
	return true


## ------------------------------------------------------------ persistence
## GameState serialises ITSELF. SaveSystem orchestrates the file but never
## reaches into this state directly, so Directive 6 still holds: progression is
## only ever written in here.
func to_save_dict() -> Dictionary:
	var pile: Dictionary = {}
	for id: StringName in _yard_pile:
		pile[String(id)] = int(_yard_pile[id])
	var proc_streaks: Dictionary = {}
	for id: StringName in _proc_dry_streak:
		proc_streaks[String(id)] = int(_proc_dry_streak[id])
	var mastery_progress: Dictionary = {}
	for id: StringName in _species_mastery_progress:
		mastery_progress[String(id)] = int(_species_mastery_progress[id])
	var commission_offers: Array = []
	for offer: Dictionary in _commission_offers:
		var normalised := Orders.normalise_commission_offer(offer)
		if normalised.is_empty():
			continue
		commission_offers.append({
			"id": String(normalised.get("id", &"")),
			"template_id": String(normalised.get("template_id", &"")),
			"customer_name": String(normalised.get("customer_name", "")),
			"title": String(normalised.get("title", "")),
			"description": String(normalised.get("description", "")),
			"goal_kind": int(normalised.get("goal_kind", -1)),
			"required_species": String(normalised.get("required_species", &"")),
			"required_item": String(normalised.get("required_item", &"")),
			"required_count": int(normalised.get("required_count", 0)),
			"cash_bonus": int(normalised.get("cash_bonus", 0)),
		})
	var active_orders: Array = []
	for order_id: StringName in get_active_order_ids():
		active_orders.append({
			"id": String(order_id),
			"progress": get_active_order_progress_for(order_id),
		})
	var active_commissions: Array = []
	for offer_id: StringName in get_active_commission_ids():
		active_commissions.append({
			"id": String(offer_id),
			"progress": get_active_commission_progress_for(offer_id),
		})
	var legacy_order_id := get_active_order_id()
	var legacy_commission_id := get_active_commission_id()
	return {
		"cash": _cash,
		"lifetime_wood_chopped": _lifetime_wood_chopped,
		"yard_pile": pile,
		"haul_aways_completed": _haul_aways_completed,
		# The player's CHOICE of wood. The unlocked SET is deliberately not saved:
		# it is re-derived from lifetime_wood_chopped on load, so a retuned ladder
		# applies to an existing save instead of freezing its old thresholds in.
		"selected_species": String(_selected_species),
		# XP is saved; the LEVEL is not, because it is derived from XP and a
		# saved level would be a second opinion that could disagree.
		"xp": _xp,
		"owned_species": _owned_species.keys(),
		"species_mastery_progress": mastery_progress,
		"splitter_assigned_species": String(_splitter_assigned_species),
		"skill_levels": _skill_levels.duplicate(),
		"legacy_skill_ranks": _legacy_skill_ranks.duplicate(),
		"proc_dry_streak": proc_streaks,
		"active_orders": active_orders,
		"active_order": String(legacy_order_id),
		"active_order_progress": get_active_order_progress_for(legacy_order_id),
		"completed_orders": _completed_orders.keys(),
		"commission_offers": commission_offers,
		"commission_generation": _commission_generation,
		"active_commissions": active_commissions,
		"active_commission": String(legacy_commission_id),
		"active_commission_progress": get_active_commission_progress_for(legacy_commission_id),
		"completed_commissions": _completed_commissions,
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
	_haul_aways_completed = maxi(0, int(data.get("haul_aways_completed", 0)))

	_yard_pile = {}
	var pile: Variant = data.get("yard_pile")
	if pile is Dictionary:
		for key: Variant in pile as Dictionary:
			# String through the file, StringName to every reader — same trap the
			# building tiers hit.
			var n := maxi(0, int((pile as Dictionary)[key]))
			if n > 0:
				_yard_pile[StringName(key)] = n

	# Stored as a plain String through the file; every reader wants a StringName.
	# NOT validated against the table here — get_selected_species() already falls
	# back to the starting wood for anything unknown or not yet earned, so a save
	# written before a species was renamed loads without losing anything else.
	_selected_species = StringName(String(data.get("selected_species", "")))
	_xp = maxi(0, int(data.get("xp", 0)))

	_owned_species = {}
	var owned: Variant = data.get("owned_species")
	if owned is Array:
		for id: Variant in owned as Array:
			# String through the file, StringName to every reader — the same trap
			# the building tiers hit. A wood no longer in the table is dropped
			# rather than kept, so a renamed species cannot haunt the woodshed.
			var sid := StringName(String(id))
			if SpeciesTable.by_id(sid) != null:
				_owned_species[sid] = true

	_species_mastery_progress = {}
	var mastery_progress: Variant = data.get("species_mastery_progress")
	if mastery_progress is Dictionary:
		var mastery_table := M7CContent.mastery()
		for key: Variant in mastery_progress as Dictionary:
			var species_id := StringName(String(key))
			var definition: SpeciesMasteryDef = mastery_table.by_species_id(species_id) \
				if mastery_table != null else null
			if definition == null:
				continue
			var progress := clampi(int((mastery_progress as Dictionary)[key]),
				0, definition.mastery_target)
			if progress > 0:
				_species_mastery_progress[species_id] = progress

	_skill_levels = {}
	var skills: Variant = data.get("skill_levels")
	if skills is Dictionary:
		for key: Variant in skills as Dictionary:
			var nid := StringName(String(key))
			var lv := maxi(0, int((skills as Dictionary)[key]))
			# Clamp to the node's CURRENT cap and drop skills that no longer
			# exist: a retuned tree must not leave the player owing more points
			# than they have earned, which would read as a negative balance.
			var def := SkillTree.get_node_def(nid)
			if def != null and lv > 0:
				_skill_levels[nid] = mini(lv, def.max_level) if def.max_level > 0 else lv

	_legacy_skill_ranks = {}
	var legacy_skills: Variant = data.get("legacy_skill_ranks")
	if legacy_skills is Dictionary:
		for key: Variant in legacy_skills as Dictionary:
			var nid := StringName(String(key))
			if not _skill_levels.has(nid) or not _V1_SKILL_COSTS.has(nid):
				continue
			var rank_value: Variant = (legacy_skills as Dictionary)[key]
			if typeof(rank_value) != TYPE_INT:
				continue
			var ranks := clampi(int(rank_value), 0, int(_skill_levels[nid]))
			if ranks > 0:
				_legacy_skill_ranks[nid] = ranks

	# A proc removed or retuned since this save was written is dropped or
	# reclamped rather than kept, the same rule species/skills already use —
	# a lowered bad_luck_bound must not leave a save holding an impossibly
	# long streak.
	_proc_dry_streak = {}
	var proc_streaks: Variant = data.get("proc_dry_streak")
	if proc_streaks is Dictionary:
		var proc_table := M7CContent.procs()
		for key: Variant in proc_streaks as Dictionary:
			var pid := StringName(String(key))
			var proc_def: ProcDef = proc_table.by_id(pid) if proc_table != null else null
			if proc_def == null:
				continue
			var n := maxi(0, int((proc_streaks as Dictionary)[key]))
			if n > 0:
				_proc_dry_streak[pid] = mini(n, proc_def.bad_luck_bound)

	_completed_orders = {}
	var completed: Variant = data.get("completed_orders")
	if completed is Array:
		for id: Variant in completed as Array:
			var order_id := StringName(String(id))
			if Orders.by_id(order_id) != null:
				_completed_orders[order_id] = true

	_active_orders = {}
	var saved_orders: Variant = data.get("active_orders")
	if saved_orders is Array:
		for raw_active: Variant in saved_orders as Array:
			if not (raw_active is Dictionary):
				continue
			var saved_id := StringName(String((raw_active as Dictionary).get("id", "")))
			var saved_def := Orders.by_id(saved_id)
			if saved_def == null or has_completed_order(saved_id) \
					or not Orders.is_available(saved_def):
				continue
			_active_orders[saved_id] = clampi(
				int((raw_active as Dictionary).get("progress", 0)), 0,
				saved_def.required_count - 1)
	else:
		# Experimental v5 compatibility: the first M9 checkpoint stored one active
		# authored delivery in scalar fields.
		var saved_order := StringName(String(data.get("active_order", "")))
		var order := Orders.by_id(saved_order)
		if order != null and not has_completed_order(saved_order) and Orders.is_available(order):
			_active_orders[saved_order] = clampi(
				int(data.get("active_order_progress", 0)), 0,
				order.required_count - 1)

	_commission_offers = []
	_commission_generation = maxi(0, int(data.get("commission_generation", 0))) \
		if Orders.commissions_unlocked() else 0
	_active_commissions = {}
	_completed_commissions = maxi(0, int(data.get("completed_commissions", 0))) \
		if Orders.commissions_unlocked() else 0
	var saved_commissions: Variant = data.get("commission_offers")
	if Orders.commissions_unlocked() and saved_commissions is Array:
		var restored_offers: Array[Dictionary] = []
		var seen_offer_ids: Dictionary = {}
		for raw_offer: Variant in saved_commissions as Array:
			var offer := Orders.normalise_commission_offer(raw_offer)
			var offer_id := StringName(offer.get("id", &""))
			if offer.is_empty() or seen_offer_ids.has(offer_id):
				continue
			seen_offer_ids[offer_id] = true
			restored_offers.append(offer)
		# Generated sets are atomic. A partial/corrupt set becomes empty and will
		# be replaced only when the player next enters the commission board.
		if restored_offers.size() == Orders.COMMISSION_OFFER_COUNT:
			_commission_offers = restored_offers
	if not _commission_offers.is_empty():
		var saved_active_commissions: Variant = data.get("active_commissions")
		if saved_active_commissions is Array:
			for raw_active: Variant in saved_active_commissions as Array:
				if not (raw_active is Dictionary):
					continue
				var saved_id := StringName(String((raw_active as Dictionary).get("id", "")))
				for offer: Dictionary in _commission_offers:
					if StringName(offer.get("id", &"")) != saved_id:
						continue
					_active_commissions[saved_id] = clampi(
						int((raw_active as Dictionary).get("progress", 0)), 0,
						int(offer.get("required_count", 1)) - 1)
					break
		else:
			var saved_commission := StringName(String(data.get("active_commission", "")))
			for offer: Dictionary in _commission_offers:
				if StringName(offer.get("id", &"")) != saved_commission:
					continue
				_active_commissions[saved_commission] = clampi(
					int(data.get("active_commission_progress", 0)), 0,
					int(offer.get("required_count", 1)) - 1)
				break

	var tiers: Variant = data.get("tool_tiers")
	if tiers is Dictionary:
		_tool_tiers = {
			Enums.ToolType.AXE: maxi(DEFAULT_TOOL_TIER, int((tiers as Dictionary).get(Enums.ToolType.AXE, DEFAULT_TOOL_TIER))),
		}

	var buildings: Variant = data.get("building_tiers")
	if buildings is Dictionary:
		_building_tiers = {}
		for key: Variant in buildings as Dictionary:
			# Keys come back as String through the file, but every reader looks
			# them up by StringName — normalise or every building reads as tier 1.
			_building_tiers[StringName(key)] = maxi(DEFAULT_BUILDING_TIER, int((buildings as Dictionary)[key]))

	# Assignment is validated only after both mastery and building tiers have
	# loaded, because those two fields jointly decide whether a profile is real.
	_splitter_assigned_species = &""
	var assigned_species := StringName(String(data.get("splitter_assigned_species", "")))
	if MechanicalSplitter.can_accept_species(assigned_species):
		_splitter_assigned_species = assigned_species

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
	haul_aways_changed.emit(_haul_aways_completed)
	# The RESOLVED choice, not the raw field: a save whose wood no longer exists
	# must repaint the HUD as the wood that will actually be on the block.
	selected_species_changed.emit(get_selected_species())
	for species: SpeciesDef in SpeciesTable.all():
		if species != null:
			species_mastery_changed.emit(species.id,
				get_species_mastery_progress(species.id))
	splitter_assignment_changed.emit(_splitter_assigned_species)
	xp_changed.emit(_xp)
	skill_points_changed.emit(get_skill_points_available())
	order_state_changed.emit()
	commission_state_changed.emit()
	building_tiers_changed.emit()


func reset_to_defaults() -> void:
	## Fresh save. Used by SaveSystem when no file exists and by the test suites,
	## which need a known slate without restarting the process.
	_cash = DEFAULT_CASH
	_lifetime_wood_chopped = 0
	_yard_pile = {}
	_haul_aways_completed = 0
	_selected_species = &""
	_owned_species = {}
	_species_mastery_progress = {}
	_splitter_assigned_species = &""
	_xp = 0
	_skill_levels = {}
	_legacy_skill_ranks = {}
	_proc_dry_streak = {}
	_active_orders = {}
	_completed_orders = {}
	_commission_offers = []
	_commission_generation = 0
	_active_commissions = {}
	_completed_commissions = 0
	_tool_tiers = {
		Enums.ToolType.AXE: DEFAULT_TOOL_TIER,
	}
	_building_tiers = {}
	_unlocked_biomes = { Enums.Biome.PINE_FOREST: true }
	cash_changed.emit(_cash)
	lifetime_wood_chopped_changed.emit(_lifetime_wood_chopped)
	yard_pile_changed.emit(0)
	haul_aways_changed.emit(0)
	selected_species_changed.emit(get_selected_species())
	for species: SpeciesDef in SpeciesTable.all():
		if species != null:
			species_mastery_changed.emit(species.id, 0)
	splitter_assignment_changed.emit(&"")
	xp_changed.emit(0)
	skill_points_changed.emit(0)
	order_state_changed.emit()
	commission_state_changed.emit()
	building_tiers_changed.emit()

## The XP curve, loaded once. Data, so the whole 99-level shape is one file
## edit — see LevelCurve for why the level is derived from it rather than
## stored beside it.
const _LEVEL_CURVE_PATH := "res://data/level_curve.tres"
static var _curve: LevelCurve = null

func _level_curve() -> LevelCurve:
	if _curve == null:
		_curve = load(_LEVEL_CURVE_PATH) as LevelCurve
		if _curve == null:
			push_error("GameState: failed to load '%s'; falling back to defaults." % _LEVEL_CURVE_PATH)
			_curve = LevelCurve.new()
	return _curve


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
	building_tiers_changed.emit()


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
