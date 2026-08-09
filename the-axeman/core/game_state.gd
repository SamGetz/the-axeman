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
## Gross gameplay income. Spending never lowers this reveal-band authority.
signal lifetime_cash_earned_changed(new_total: int)
signal earnings_band_changed(previous_band: int, new_band: int)
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
## Exact level reward after it has been committed. HUD celebrations never infer
## whether a level paid a point or cash from surrounding state.
signal level_reward_granted(receipt: LevelRewardReceipt)
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
signal reputation_changed(new_total: int)
signal craftsmanship_changed(grade: int, new_count: int)
signal manual_piece_settled(receipt: ManualPieceReceipt, craft_bonus: int)
signal company_logistics_changed
signal company_return_ledger_changed
signal regional_network_changed
signal company_strategy_changed
signal earth_campaign_changed
signal earth_finale_completed
signal earth_trees_changed(remaining: int, felled_delta: int)
signal manual_log_progress_changed(total_logs: int, logs_toward_next_tree: int)
signal earth_depleted
signal feature_introduced(feature_id: StringName)
signal launch_program_changed
signal expedition_changed
signal alien_campaign_changed
signal campaign_phase_changed(previous_phase: int, new_phase: int)
signal campaign_goal_changed(snapshot: CampaignGoalSnapshot)
signal campaign_completed

enum EarthFinaleState { LOCKED, READY, IN_PROGRESS, COMPLETE }
enum CampaignPhase {
	COZY_CLEARING,
	WORKING_YARD,
	REGIONAL_COMPANY,
	PLANETARY_MACHINE,
	COSMIC_FINALE,
	COMPLETE,
}
enum AlienDestinationState {
	UNSURVEYED, SURVEYED, QUARANTINED, IDENTIFIED, SPECIMEN_READY,
	CERTIFIED, REPEAT_CARGO, MASTERED,
}
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
## User-approved campaign total. Tree equivalents are an economy/progression
## counter; the retired tree-felling scene is not restored.
const TOTAL_EARTH_TREES := 3_040_000_000_000
const MANUAL_LOGS_PER_EARTH_TREE := 4
## Keep authored campaign arithmetic well below signed 64-bit overflow while
## still allowing quadrillion-scale cash and production.
const MAX_SAFE_ECONOMY_VALUE := 1_000_000_000_000_000_000

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
var _lifetime_cash_earned: int = 0
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
## Persisted entitlement, because completed visible trees temporarily turn
## levels into cash and Frontier later turns future levels back into points.
var _skill_points_earned_total: int = 0
var _last_rewarded_level: int = 1
var _masterwork_pending: int = 0
## Ranks carried forward from save v1. They remain part of `_skill_levels`; this
## parallel count says only how many of those ranks retain their prototype
## per-rank price. It is not a point purse and cannot be spent independently.
var _legacy_skill_ranks: Dictionary = {}
## Proc id (StringName) -> consecutive DRY (non-fired) rolls since it last
## fired. Bounded bad-luck protection (see ProcResolver) reads this so a
## reload cannot cheaply reroll a live streak — see the M7C brief's fairness
## contract: "Its state persists so save/reload cannot cheaply reroll."
var _proc_dry_streak: Dictionary = {}
## Short-lived idempotency for root-bound terrestrial mastery receipts. Manual
## log roots are scene-session identities; the awarded progress itself persists.
var _mastery_completion_sources: Dictionary = {}
## An approved economy sink rather than a tuning placeholder: respeccing always
## removes one fifth of the player's current purse, rounded down to whole coins.
const SKILL_RESPEC_CASH_FRACTION := 0.20
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
## V17 keeps old simultaneous commissions finishable, but all newly selected
## standing work is single-slot. These ids disappear as legacy work completes.
var _legacy_commission_ids: Dictionary = {}
var _standing_commission_cycles_completed := 0
## Exact-once sources cover milestone/commission rewards whose state transition
## and cash award must survive a save independently.
var _applied_progression_reward_sources: Dictionary = {}
var _reputation := 0
var _craft_grade_counts: Dictionary = {}
var _customer_completion_history: Array[Dictionary] = []
var _supplier_input_queues: Dictionary = {}
var _route_priorities: Array[StringName] = []
var _company_last_timestamp := 0
var _automated_log_equivalents := 0
var _company_return_ledger: Array[Dictionary] = []
var _applied_company_receipts: Dictionary = {}
var _discovered_regions: Dictionary = {}
var _regional_standing: Dictionary = {}
var _regional_depots: Dictionary = {}
var _regional_routes: Dictionary = {}
var _signature_log_records: Dictionary = {}
var _signature_log_sources: Dictionary = {}
var _company_doctrine: StringName = &""
var _infrastructure_projects: Dictionary = {}
var _manual_log_equivalents := 0
var _manual_logs_toward_next_tree := 0
var _manual_log_sources: Dictionary = {}
var _earth_trees_felled: int = 0
var _applied_earth_production_receipts: Dictionary = {}
var _introduced_feature_ids: Dictionary = {}
var _earth_finale_state: EarthFinaleState = EarthFinaleState.LOCKED
var _earth_finale_splits := 0
var _earth_master := false
var _launch_projects: Dictionary = {}
var _launch_contributions: Dictionary = {}
var _spacecraft_loadout: Dictionary = {}
var _active_expedition: Dictionary = {}
var _arrived_destinations: Dictionary = {}
var _applied_expedition_receipts: Dictionary = {}
var _alien_destination_states: Dictionary = {}
var _alien_manual_mastery: Dictionary = {}
var _alien_manual_sources: Dictionary = {}
var _cargo_fleets: Dictionary = {}
var _orbital_lines: Dictionary = {}
var _expedition_charter: StringName = &""
var _applied_alien_automation_receipts: Dictionary = {}
var _combined_orbital_receipt_received := false
var _campaign_completion_recorded := false
var _campaign_phase_cache: CampaignPhase = CampaignPhase.COZY_CLEARING

## ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	EventBus.gear_upgraded.connect(_on_gear_upgraded)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.environment_unlocked.connect(_on_environment_unlocked)
	EventBus.resource_gathered.connect(_on_resource_gathered)
	for progression_signal: Signal in [order_state_changed, building_tiers_changed,
			regional_network_changed, earth_campaign_changed, launch_program_changed,
			expedition_changed, alien_campaign_changed]:
		progression_signal.connect(_refresh_campaign_progression)
	species_purchased.connect(_refresh_campaign_progression.unbind(1))
	species_mastery_changed.connect(_refresh_campaign_progression.unbind(2))
	skill_level_changed.connect(_refresh_campaign_progression.unbind(2))
	_campaign_phase_cache = CampaignProgression.phase()

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


func get_lifetime_cash_earned() -> int:
	return _lifetime_cash_earned


func get_earnings_band() -> int:
	return ProductionEconomy.earnings_band_for(_lifetime_cash_earned)


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
	return false


## Skill-point entitlement is persisted because some levels legitimately award
## cash while every currently revealed node is already learned.
func get_skill_points_earned() -> int:
	return _skill_points_earned_total


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


func get_skill_respec_cost() -> int:
	return floori(float(_cash) * SKILL_RESPEC_CASH_FRACTION)


func can_respec_skills() -> bool:
	return get_skill_points_spent() > 0


## Returns every learned node to the player's existing point entitlement. The
## cash charge and reset are one synchronous transaction; proc protection and a
## queued Masterwork cannot survive after their granting skills are removed.
func respec_skills() -> bool:
	if not can_respec_skills():
		return false
	var cost := get_skill_respec_cost()
	if cost > 0 and not try_spend_cash(cost):
		return false
	var removed_ids: Array[StringName] = []
	for id: StringName in _skill_levels:
		removed_ids.append(id)
	_skill_levels.clear()
	_legacy_skill_ranks.clear()
	_proc_dry_streak.clear()
	_masterwork_pending = 0
	for id: StringName in removed_ids:
		skill_level_changed.emit(id, 0)
	skill_points_changed.emit(get_skill_points_available())
	return true


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
		var wood_trait := AlienCampaign.trait_by_id(species_id)
		return wood_trait != null and get_alien_destination_state(wood_trait.destination_id) \
			>= AlienDestinationState.SPECIMEN_READY
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
	if species_id == EarthCampaign.FINAL_SPECIES_ID \
			and not EarthCampaign.terrestrial_requirements_complete():
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
	if _selected_species != &"" and owns_species(_selected_species) \
			and (_selected_species != EarthCampaign.FINAL_SPECIES_ID \
			or _earth_finale_state in [EarthFinaleState.IN_PROGRESS, EarthFinaleState.COMPLETE]):
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
	return table.reached_threshold_count(species_id,
		get_species_mastery_progress(species_id))


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


func get_standing_commission_cycles_completed() -> int:
	return _standing_commission_cycles_completed


## Five campaign beats unlock at most one new standing choice each: opening
## yard, regional company, planetary readiness, Earth zero and first alien
## mastery. Fast fulfilment therefore never turns commissions into a menu loop.
func get_standing_commission_offer_moments_unlocked() -> int:
	var moments := 0
	if Orders.commissions_unlocked():
		moments = 1
	if get_regional_route_count() > 0 \
			or Shop.get_level(CompanyStrategy.machine().id) > 0:
		moments = 2
	if EarthCampaign.terrestrial_requirements_complete():
		moments = 3
	if is_earth_depleted():
		moments = 4
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		if get_alien_destination_state(wood_trait.destination_id) \
				== AlienDestinationState.MASTERED:
			moments = 5
			break
	return mini(Orders.standing_commission_limit(), moments)


func has_pending_standing_commission_choice() -> bool:
	return Orders.commissions_unlocked() \
		and _legacy_commission_ids.is_empty() \
		and _active_commissions.is_empty() \
		and _standing_commission_cycles_completed \
			< get_standing_commission_offer_moments_unlocked() \
		and not _commission_offers.is_empty()


func get_standing_commission_cycles_remaining() -> int:
	return maxi(0, Orders.standing_commission_limit() \
		- _standing_commission_cycles_completed)


func get_reputation() -> int:
	return _reputation


func get_craft_grade_count(grade: int) -> int:
	return maxi(0, int(_craft_grade_counts.get(grade, 0)))


func get_customer_completion_history() -> Array[Dictionary]:
	return _customer_completion_history.duplicate(true)


func get_supplier_input_queues() -> Dictionary:
	return _supplier_input_queues.duplicate(true)


func get_route_priorities() -> Array[StringName]:
	return _route_priorities.duplicate()


func get_automated_log_equivalents() -> int:
	return _automated_log_equivalents


func get_company_return_ledger() -> Array[Dictionary]:
	return _company_return_ledger.duplicate(true)


func is_region_discovered(region_id: StringName) -> bool:
	return _discovered_regions.has(region_id)


func get_regional_standing(region_id: StringName) -> int:
	return maxi(0, int(_regional_standing.get(region_id, 0)))


func has_regional_depot(region_id: StringName) -> bool:
	return _regional_depots.has(region_id)


func has_regional_route(region_id: StringName) -> bool:
	return _regional_routes.has(region_id)


func get_regional_route_count() -> int:
	return _regional_routes.size()


func get_signature_log_record(species_id: StringName) -> int:
	return maxi(0, int(_signature_log_records.get(species_id, 0)))


func get_company_doctrine() -> StringName:
	return _company_doctrine


func has_infrastructure_project(project_id: StringName) -> bool:
	return _infrastructure_projects.has(project_id)


func get_manual_log_equivalents() -> int:
	return _manual_log_equivalents


func get_manual_logs_toward_next_tree() -> int:
	return _manual_logs_toward_next_tree


func get_combined_company_log_total() -> int:
	return _manual_log_equivalents + _automated_log_equivalents


func get_earth_trees_felled() -> int:
	return _earth_trees_felled


func get_earth_trees_remaining() -> int:
	return TOTAL_EARTH_TREES - _earth_trees_felled


func is_earth_depleted() -> bool:
	return _earth_trees_felled >= TOTAL_EARTH_TREES


func has_introduced_feature(feature_id: StringName) -> bool:
	return _introduced_feature_ids.has(feature_id)


func mark_feature_introduced(feature_id: StringName) -> bool:
	if feature_id == &"" or _introduced_feature_ids.has(feature_id):
		return false
	_introduced_feature_ids[feature_id] = true
	feature_introduced.emit(feature_id)
	return true


func preview_earth_tree_felling(requested: int) -> int:
	if requested <= 0 or is_earth_depleted():
		return 0
	return mini(requested, get_earth_trees_remaining())


func get_earth_finale_state() -> EarthFinaleState:
	if is_earth_depleted():
		return EarthFinaleState.COMPLETE
	if _earth_finale_state == EarthFinaleState.LOCKED \
			and EarthCampaign.terrestrial_requirements_complete():
		return EarthFinaleState.READY
	return _earth_finale_state


func get_earth_finale_splits() -> int:
	return _earth_finale_splits


func is_earth_master() -> bool:
	return _earth_master and is_earth_depleted()


func has_launch_project(project_id: StringName) -> bool:
	return _launch_projects.has(project_id)


func get_launch_project_count() -> int:
	return _launch_projects.size()


func get_launch_contribution(project_id: StringName) -> int:
	var project := LaunchProgram.project_by_id(project_id)
	if project != null and ProductionEconomy.has_continuity_reserve():
		return project.contribution_amount
	return maxi(0, int(_launch_contributions.get(project_id, 0)))


func get_spacecraft_loadout() -> Dictionary:
	return _spacecraft_loadout.duplicate()


func get_spacecraft_capability(slot: SpacecraftComponentDef.Slot) -> int:
	var component := LaunchProgram.component_by_id(StringName(_spacecraft_loadout.get(slot, &"")))
	return 0 if component == null else component.capability


func get_active_expedition() -> Dictionary:
	return _active_expedition.duplicate(true)


func has_arrived_at(destination_id: StringName) -> bool:
	return _arrived_destinations.has(destination_id)


func get_alien_destination_state(destination_id: StringName) -> AlienDestinationState:
	return clampi(int(_alien_destination_states.get(destination_id,
		AlienDestinationState.UNSURVEYED)), AlienDestinationState.UNSURVEYED,
		AlienDestinationState.MASTERED)


func get_alien_manual_mastery(species_id: StringName) -> int:
	var wood_trait := AlienCampaign.trait_by_id(species_id)
	return 0 if wood_trait == null else clampi(int(_alien_manual_mastery.get(
		species_id, 0)), 0, wood_trait.manual_mastery_target)


func get_cargo_fleet_count(destination_id: StringName) -> int:
	return maxi(0, int(_cargo_fleets.get(destination_id, 0)))


func has_orbital_line(destination_id: StringName) -> bool:
	return _orbital_lines.has(destination_id)


func get_orbital_line_count() -> int:
	return _orbital_lines.size()


func has_combined_orbital_receipt() -> bool:
	return _combined_orbital_receipt_received


func get_campaign_phase() -> CampaignPhase:
	return CampaignProgression.phase()


func get_campaign_goal_snapshot() -> CampaignGoalSnapshot:
	return CampaignProgression.goal_snapshot()


func is_campaign_complete() -> bool:
	return is_earth_depleted() \
		and get_orbital_line_count() >= AlienCampaign.traits().size() \
		and SkillTree.get_level(&"frontier_master") > 0 \
		and _combined_orbital_receipt_received


func get_expedition_charter() -> StringName:
	return _expedition_charter


func get_alien_company_simulation_input() -> Dictionary:
	return {"fleets": _cargo_fleets.duplicate(),
		"orbital_lines": _orbital_lines.duplicate(), "charter": _expedition_charter}


func get_company_simulation_input() -> Dictionary:
	var planetary_species: Array[StringName] = []
	for species: SpeciesDef in SpeciesTable.all():
		if species != null and is_species_mastered(species.id):
			planetary_species.append(species.id)
	return {
		"queues": _supplier_input_queues.duplicate(true),
		"route_priorities": _route_priorities.duplicate(),
		"last_timestamp": _company_last_timestamp,
		"dispatch_capacity": CompanyStrategy.effective_dispatch_capacity(),
		"parallel_lines": ProductionEconomy.effective_parallel_lines(),
		"trees_per_cycle": ProductionEconomy.trees_per_cycle(),
		"logs_per_tree": ProductionEconomy.logs_per_tree(),
		"species_per_receipt": ProductionEconomy.species_per_receipt(),
		"interval_multiplier": ProductionEconomy.interval_multiplier(),
		"global_work_allocation": Shop.get_level(&"satellite_forest_survey") > 0,
		"planetary_species": planetary_species,
		"earth_trees_remaining": get_earth_trees_remaining(),
	}


func has_active_manual_job() -> bool:
	return not _active_orders.is_empty() or not _active_commissions.is_empty()


func get_active_manual_job_count() -> int:
	return _active_orders.size() + _active_commissions.size()


## First entry into the earned commission flow creates the persisted standing
## offer set. Save migration deliberately leaves it empty so loading never
## invents completed work or pays a reward.
func ensure_commission_offers() -> bool:
	if not Orders.commissions_unlocked() or not _commission_offers.is_empty() \
			or not _active_commissions.is_empty() \
			or not _legacy_commission_ids.is_empty() \
			or _standing_commission_cycles_completed \
				>= get_standing_commission_offer_moments_unlocked():
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
	if amount > MAX_SAFE_ECONOMY_VALUE - _cash:
		push_error("GameState: cash award would exceed the safe campaign envelope — ignored.")
		return false
	_cash += amount
	cash_changed.emit(_cash)
	return true


## Genuine earnings enter here. Raw setup, migration, save restore, refunds and
## deliberate test grants continue to use add_cash() and remain exact.
func award_cash(base_amount: int, origin: StringName = &"gameplay") -> int:
	if base_amount <= 0:
		return 0
	var multiplier := 1.0 + SkillTree.total_modifier(GameplayModifierDef.Kind.CASH_GAIN)
	var multiplied := float(base_amount) * multiplier
	if not is_finite(multiplied) or multiplied > MAX_SAFE_ECONOMY_VALUE:
		push_error("GameState: modified cash award exceeds the safe campaign envelope.")
		return 0
	var awarded := maxi(1, int(round(multiplied)))
	if awarded > MAX_SAFE_ECONOMY_VALUE - _lifetime_cash_earned \
			or not add_cash(awarded):
		return 0
	var previous_band := get_earnings_band()
	_lifetime_cash_earned += awarded
	lifetime_cash_earned_changed.emit(_lifetime_cash_earned)
	var new_band := get_earnings_band()
	if new_band != previous_band:
		earnings_band_changed.emit(previous_band, new_band)
	return awarded


func add_reputation(amount: int) -> bool:
	if amount <= 0:
		return false
	_reputation += amount
	reputation_changed.emit(_reputation)
	return true


func record_manual_craft_grade(grade: int) -> bool:
	if grade < Craftsmanship.Grade.ROUGH or grade > Craftsmanship.Grade.EXCEPTIONAL:
		return false
	var total := get_craft_grade_count(grade) + 1
	_craft_grade_counts[grade] = total
	craftsmanship_changed.emit(grade, total)
	return true


func present_manual_piece_settlement(receipt: ManualPieceReceipt,
		craft_bonus: int) -> void:
	if receipt != null and receipt.is_manual():
		manual_piece_settled.emit(receipt, maxi(0, craft_bonus))


func enqueue_supplier_input(species_id: StringName, amount: int) -> bool:
	var cfg := CompanySimulation.config()
	if cfg == null or amount <= 0 or not CompanyLogistics.is_owned(&"log_feeder") \
			or not MechanicalSplitter.can_accept_species(species_id):
		return false
	var current := maxi(0, int(_supplier_input_queues.get(species_id, 0)))
	if current + amount > CompanyLogistics.supplier_queue_capacity():
		return false
	_supplier_input_queues[species_id] = current + amount
	if not _route_priorities.has(species_id):
		_route_priorities.append(species_id)
	company_logistics_changed.emit()
	return true


func set_route_priorities(species_ids: Array[StringName]) -> bool:
	if not CompanyLogistics.is_owned(&"order_router"):
		return false
	var canonical: Array[StringName] = []
	for species_id: StringName in species_ids:
		if _supplier_input_queues.has(species_id) and not canonical.has(species_id):
			canonical.append(species_id)
	if canonical.is_empty() and not _supplier_input_queues.is_empty():
		return false
	_route_priorities = canonical
	company_logistics_changed.emit()
	return true


func set_company_clock_anchor(timestamp: int) -> bool:
	if timestamp < 0:
		return false
	_company_last_timestamp = timestamp
	company_logistics_changed.emit()
	return true


func can_apply_earth_production(delta: EarthProductionDelta) -> bool:
	if delta == null or not delta.validate().is_empty() \
			or _applied_earth_production_receipts.has(delta.receipt_id):
		return false
	var trees := delta.total_trees()
	return trees > 0 and trees <= get_earth_trees_remaining()


func apply_earth_production(delta: EarthProductionDelta) -> bool:
	if not can_apply_earth_production(delta):
		return false
	var trees := delta.total_trees()
	_applied_earth_production_receipts[delta.receipt_id] = true
	_earth_trees_felled += trees
	if delta.source_kind != EarthProductionDelta.SourceKind.MANUAL:
		_automated_log_equivalents += trees
		company_logistics_changed.emit()
	earth_trees_changed.emit(get_earth_trees_remaining(), trees)
	earth_campaign_changed.emit()
	if is_earth_depleted() and not _earth_master:
		_earth_master = true
		_earth_finale_state = EarthFinaleState.COMPLETE
		earth_depleted.emit()
		earth_finale_completed.emit()
		skill_points_changed.emit(get_skill_points_available())
	return true


func record_watched_automation_logs(amount: int, receipt_id: StringName = &"",
		species_id: StringName = &"") -> bool:
	var accepted := preview_earth_tree_felling(amount)
	if accepted != amount:
		return false
	if species_id == &"":
		species_id = get_splitter_assigned_species()
	if species_id == &"" or SpeciesTable.by_id(species_id) == null:
		species_id = get_selected_species()
	if receipt_id == &"":
		receipt_id = StringName("legacy_watched_%d_%d" % [
			_automated_log_equivalents, amount])
	var delta := EarthProductionDelta.new(receipt_id,
		EarthProductionDelta.SourceKind.WATCHED_SPLITTER,
		{species_id: amount})
	return apply_earth_production(delta)


func discover_region(region_id: StringName) -> bool:
	var region := RegionalNetwork.region_by_id(region_id)
	if region == null or is_region_discovered(region_id) \
			or _reputation < region.reputation_required:
		return false
	_discovered_regions[region_id] = true
	regional_network_changed.emit()
	return true


func add_regional_standing(region_id: StringName, amount: int) -> bool:
	if amount <= 0 or not is_region_discovered(region_id) \
			or RegionalNetwork.region_by_id(region_id) == null:
		return false
	_regional_standing[region_id] = get_regional_standing(region_id) + amount
	regional_network_changed.emit()
	return true


func build_regional_depot(region_id: StringName) -> bool:
	var region := RegionalNetwork.region_by_id(region_id)
	if region == null or has_regional_depot(region_id) \
			or get_regional_standing(region_id) < region.depot_standing_required \
			or not try_spend_cash(region.depot_cost):
		return false
	_regional_depots[region_id] = true
	regional_network_changed.emit()
	return true


func establish_regional_route(region_id: StringName) -> bool:
	var route := RegionalNetwork.route_for_region(region_id)
	if route == null or not has_regional_depot(region_id) \
			or has_regional_route(region_id) or not try_spend_cash(route.cost):
		return false
	_regional_routes[region_id] = route.id
	regional_network_changed.emit()
	return true


func dispatch_regional_species(species_id: StringName, amount: int) -> bool:
	var region := RegionalNetwork.region_for_species(species_id)
	if region == null or not has_regional_route(region.id):
		return false
	return enqueue_supplier_input(species_id, amount)


func record_signature_log(receipt: ManualPieceReceipt) -> bool:
	if receipt == null or not receipt.is_manual() \
			or receipt.grade != Craftsmanship.Grade.EXCEPTIONAL \
			or receipt.source_log_id == &"" or receipt.species_id == &"" \
			or RegionalNetwork.region_for_species(receipt.species_id) == null \
			or _signature_log_sources.has(receipt.source_log_id):
		return false
	_signature_log_sources[receipt.source_log_id] = receipt.species_id
	_signature_log_records[receipt.species_id] = get_signature_log_record(receipt.species_id) + 1
	regional_network_changed.emit()
	return true


func set_company_doctrine(doctrine_id: StringName) -> bool:
	if doctrine_id != &"" and CompanyStrategy.doctrine_by_id(doctrine_id) == null:
		return false
	if _company_doctrine == doctrine_id:
		return false
	_company_doctrine = doctrine_id
	company_strategy_changed.emit()
	company_logistics_changed.emit()
	return true


func complete_infrastructure_project(project_id: StringName) -> bool:
	var project := RegionalNetwork.project_by_id(project_id)
	if project == null or has_infrastructure_project(project_id) \
			or get_lifetime_wood_chopped() + _automated_log_equivalents \
			< project.processed_output_required \
			or not try_spend_cash(project.cash_cost):
		return false
	_infrastructure_projects[project_id] = true
	company_strategy_changed.emit()
	building_tiers_changed.emit()
	earth_campaign_changed.emit()
	return true


func record_manual_log_equivalent(source_id: StringName,
		species_id: StringName = &"") -> bool:
	if source_id == &"" or _manual_log_sources.has(source_id) \
			or is_earth_depleted():
		return false
	if species_id == &"":
		species_id = get_selected_species()
	_manual_log_sources[source_id] = true
	while _manual_log_sources.size() > 64:
		_manual_log_sources.erase(_manual_log_sources.keys()[0])
	_manual_log_equivalents += 1
	_manual_logs_toward_next_tree += 1
	if _manual_logs_toward_next_tree >= MANUAL_LOGS_PER_EARTH_TREE:
		var delta := EarthProductionDelta.new(StringName("manual_tree_%s" % source_id),
			EarthProductionDelta.SourceKind.MANUAL, {species_id: 1})
		if not apply_earth_production(delta):
			_manual_log_equivalents -= 1
			_manual_logs_toward_next_tree -= 1
			_manual_log_sources.erase(source_id)
			return false
		_manual_logs_toward_next_tree -= MANUAL_LOGS_PER_EARTH_TREE
	manual_log_progress_changed.emit(_manual_log_equivalents,
		_manual_logs_toward_next_tree)
	return true


func begin_earth_finale() -> bool:
	if get_earth_finale_state() != EarthFinaleState.READY \
			or not owns_species(EarthCampaign.FINAL_SPECIES_ID):
		return false
	_earth_finale_state = EarthFinaleState.IN_PROGRESS
	_earth_finale_splits = 0
	select_species(EarthCampaign.FINAL_SPECIES_ID)
	earth_campaign_changed.emit()
	return true


func record_earth_finale_split(receipt: ManualPieceReceipt) -> bool:
	if _earth_finale_state != EarthFinaleState.IN_PROGRESS \
			or receipt == null or not receipt.is_manual() \
			or receipt.species_id != EarthCampaign.FINAL_SPECIES_ID:
		return false
	_earth_finale_splits = mini(3, _earth_finale_splits + 1)
	if _earth_finale_splits >= 3:
		# The Lignum Vitae showcase remains a terrestrial mastery beat, but Earth
		# depletion is now the only authority that opens Frontier and launch.
		_earth_finale_state = EarthFinaleState.COMPLETE
	earth_campaign_changed.emit()
	return true


func can_record_launch_contribution(project_id: StringName, amount: int) -> bool:
	var project := LaunchProgram.project_by_id(project_id)
	if project == null or amount <= 0 or has_launch_project(project_id) \
			or project != _next_launch_project() \
			or ProductionEconomy.has_continuity_reserve():
		return false
	return get_launch_contribution(project_id) + amount <= project.contribution_amount


func record_launch_contribution(project_id: StringName, amount: int) -> bool:
	if not can_record_launch_contribution(project_id, amount):
		return false
	var project := LaunchProgram.project_by_id(project_id)
	var efficiency := maxf(0.0, SkillTree.total_modifier(
		GameplayModifierDef.Kind.CONTRIBUTION_EFFICIENCY))
	var effective := maxi(amount, int(ceil(float(amount) * (1.0 + efficiency))))
	_launch_contributions[project_id] = mini(project.contribution_amount,
		get_launch_contribution(project_id) + effective)
	launch_program_changed.emit()
	return true


func complete_launch_project(project_id: StringName) -> bool:
	var project := LaunchProgram.project_by_id(project_id)
	if project == null or project != _next_launch_project() or not _earth_master \
			or get_combined_company_log_total() < project.processed_output_required \
			or get_mastered_species_count() < project.mastery_required \
			or get_launch_contribution(project_id) < project.contribution_amount:
		return false
	if not ProductionEconomy.has_continuity_reserve() \
			and not try_spend_cash(project.cash_cost):
		return false
	_launch_projects[project_id] = true
	launch_program_changed.emit()
	building_tiers_changed.emit()
	return true


func configure_spacecraft(component_id: StringName) -> bool:
	var component := LaunchProgram.component_by_id(component_id)
	if component == null or not has_launch_project(&"deep_space_vessel") \
			or not _active_expedition.is_empty():
		return false
	if component_id == &"resonance_dampener" \
			and get_alien_destination_state(&"kepler_grove") \
				< AlienDestinationState.CERTIFIED:
		return false
	if StringName(_spacecraft_loadout.get(component.slot, &"")) == component_id:
		return true
	_spacecraft_loadout[component.slot] = component_id
	launch_program_changed.emit()
	return true


func plan_expedition(destination_id: StringName, now_seconds: int) -> bool:
	var destination := LaunchProgram.expedition_by_id(destination_id)
	if destination == null or not has_launch_project(&"deep_space_vessel") \
			or not _active_expedition.is_empty() \
			or get_spacecraft_capability(SpacecraftComponentDef.Slot.RANGE) \
				< destination.range_required \
			or get_spacecraft_capability(SpacecraftComponentDef.Slot.CARGO) <= 0 \
			or get_spacecraft_capability(SpacecraftComponentDef.Slot.SHIELDING) \
				< destination.shielding_required:
		return false
	_active_expedition = ExpeditionSimulation.plan(destination, now_seconds)
	if _active_expedition.is_empty():
		return false
	expedition_changed.emit()
	return true


func resolve_expedition(now_seconds: int) -> ExpeditionReceipt:
	return ExpeditionSimulation.resolve(_active_expedition, now_seconds)


func apply_expedition_receipt(receipt: ExpeditionReceipt) -> bool:
	if receipt == null or receipt.receipt_id == &"" \
			or _applied_expedition_receipts.has(receipt.receipt_id) \
			or StringName(_active_expedition.get("destination_id", &"")) \
				!= receipt.destination_id \
			or int(_active_expedition.get("arrives_at", -1)) != receipt.arrives_at:
		return false
	_applied_expedition_receipts[receipt.receipt_id] = true
	_arrived_destinations[receipt.destination_id] = true
	if get_alien_destination_state(receipt.destination_id) \
			== AlienDestinationState.UNSURVEYED:
		_alien_destination_states[receipt.destination_id] = AlienDestinationState.SURVEYED
	_active_expedition = {}
	expedition_changed.emit()
	alien_campaign_changed.emit()
	return true


func advance_alien_protocol(destination_id: StringName, action: StringName) -> bool:
	var wood_trait := AlienCampaign.trait_for_destination(destination_id)
	if wood_trait == null:
		return false
	var state := get_alien_destination_state(destination_id)
	var expected := AlienDestinationState.UNSURVEYED
	var next := AlienDestinationState.UNSURVEYED
	match action:
		&"quarantine":
			expected = AlienDestinationState.SURVEYED
			next = AlienDestinationState.QUARANTINED
		&"identify":
			expected = AlienDestinationState.QUARANTINED
			next = AlienDestinationState.IDENTIFIED
		&"retrieve_specimen":
			expected = AlienDestinationState.IDENTIFIED
			next = AlienDestinationState.SPECIMEN_READY
		&"repeat_cargo":
			expected = AlienDestinationState.CERTIFIED
			next = AlienDestinationState.REPEAT_CARGO
		_:
			return false
	if state != expected:
		return false
	_alien_destination_states[destination_id] = next
	alien_campaign_changed.emit()
	return true


func record_alien_manual_completion(receipt: ManualPieceReceipt) -> bool:
	if receipt == null or not receipt.is_manual():
		return false
	var species_id := receipt.species_id
	var wood_trait := AlienCampaign.trait_by_id(species_id)
	if wood_trait == null or receipt.source_log_id == &"" \
			or _alien_manual_sources.has(receipt.source_log_id):
		return false
	var state := get_alien_destination_state(wood_trait.destination_id)
	if state < AlienDestinationState.SPECIMEN_READY:
		return false
	# Certification is the first manual specimen. Further commercial mastery is
	# deliberately held until repeat cargo is explicitly unlocked.
	if state == AlienDestinationState.CERTIFIED:
		return false
	var before := get_alien_manual_mastery(species_id)
	if before >= wood_trait.manual_mastery_target:
		return false
	var after := mini(wood_trait.manual_mastery_target, before + 1)
	_alien_manual_sources[receipt.source_log_id] = species_id
	while _alien_manual_sources.size() > 64:
		_alien_manual_sources.erase(_alien_manual_sources.keys()[0])
	_alien_manual_mastery[species_id] = after
	if state == AlienDestinationState.SPECIMEN_READY:
		_alien_destination_states[wood_trait.destination_id] = AlienDestinationState.CERTIFIED
	if after >= wood_trait.manual_mastery_target \
			and state >= AlienDestinationState.REPEAT_CARGO:
		_alien_destination_states[wood_trait.destination_id] = AlienDestinationState.MASTERED
		_grant_milestone_skill_points(StringName("alien_mastery:%s" % species_id), 3)
	alien_campaign_changed.emit()
	return true


func _grant_milestone_skill_points(source_id: StringName, amount: int) -> bool:
	if source_id == &"" or amount <= 0 \
			or _applied_progression_reward_sources.has(source_id):
		return false
	_applied_progression_reward_sources[source_id] = true
	_skill_points_earned_total += amount
	skill_points_changed.emit(get_skill_points_available())
	return true


func commission_cargo_fleet(destination_id: StringName) -> bool:
	var wood_trait := AlienCampaign.trait_for_destination(destination_id)
	var cfg := AlienCompanySimulation.config()
	if wood_trait == null or cfg == null \
			or get_alien_destination_state(destination_id) \
				< AlienDestinationState.REPEAT_CARGO \
			or get_cargo_fleet_count(destination_id) >= cfg.fleet_cap_per_destination \
			or not try_spend_cash(_frontier_cost(wood_trait.fleet_cost)):
		return false
	_cargo_fleets[destination_id] = get_cargo_fleet_count(destination_id) + 1
	alien_campaign_changed.emit()
	return true


func build_orbital_line(destination_id: StringName) -> bool:
	var wood_trait := AlienCampaign.trait_for_destination(destination_id)
	if wood_trait == null or has_orbital_line(destination_id) \
			or get_alien_destination_state(destination_id) \
				!= AlienDestinationState.MASTERED \
			or not try_spend_cash(_frontier_cost(wood_trait.orbital_line_cost)):
		return false
	_orbital_lines[destination_id] = true
	alien_campaign_changed.emit()
	return true


func _frontier_cost(authored_cost: int) -> int:
	var discount := clampf(SkillTree.total_modifier(
		GameplayModifierDef.Kind.FRONTIER_LOGISTICS), 0.0, 0.75)
	return maxi(1, int(round(float(authored_cost) * (1.0 - discount))))


func set_expedition_charter(destination_id: StringName) -> bool:
	if destination_id != &"" and AlienCampaign.trait_for_destination(destination_id) == null:
		return false
	if _expedition_charter == destination_id:
		return false
	_expedition_charter = destination_id
	alien_campaign_changed.emit()
	return true


func can_apply_alien_automation_receipt(receipt: AlienAutomationReceipt) -> bool:
	if receipt == null or receipt.receipt_id == &"" or receipt.total_logs() <= 0 \
			or _applied_alien_automation_receipts.has(receipt.receipt_id):
		return false
	if receipt.total_logs() > MAX_SAFE_ECONOMY_VALUE - _automated_log_equivalents:
		return false
	for raw_destination: Variant in receipt.processed_logs:
		if not has_orbital_line(StringName(raw_destination)):
			return false
	return true


func apply_alien_automation_receipt(receipt: AlienAutomationReceipt) -> bool:
	if not can_apply_alien_automation_receipt(receipt):
		return false
	_applied_alien_automation_receipts[receipt.receipt_id] = true
	_automated_log_equivalents += receipt.total_logs()
	if get_orbital_line_count() >= AlienCampaign.traits().size() \
			and receipt.processed_logs.size() >= AlienCampaign.traits().size():
		_combined_orbital_receipt_received = true
		_refresh_campaign_progression()
	company_logistics_changed.emit()
	alien_campaign_changed.emit()
	return true


func _refresh_campaign_progression() -> void:
	var next_phase := CampaignProgression.phase()
	if next_phase != _campaign_phase_cache:
		var previous := _campaign_phase_cache
		_campaign_phase_cache = next_phase
		campaign_phase_changed.emit(previous, next_phase)
	campaign_goal_changed.emit(CampaignProgression.goal_snapshot())
	ensure_commission_offers()
	if is_campaign_complete() and not _campaign_completion_recorded:
		_campaign_completion_recorded = true
		campaign_completed.emit()


func _next_launch_project() -> LaunchProjectDef:
	for project: LaunchProjectDef in LaunchProgram.projects():
		if not has_launch_project(project.id):
			return project
	return null


func can_apply_company_simulation_receipt(receipt: CompanySimulationReceipt) -> bool:
	if receipt == null or receipt.receipt_id == &"" \
			or receipt.processed_logs() <= 0 \
			or _applied_company_receipts.has(receipt.receipt_id):
		return false
	var delta := EarthProductionDelta.new(receipt.receipt_id,
		EarthProductionDelta.SourceKind.COMPANY_OFFLINE if receipt.offline \
		else EarthProductionDelta.SourceKind.COMPANY_ACTIVE,
		receipt.processed_by_species, receipt.outputs, receipt.elapsed_seconds,
		receipt.offline)
	return can_apply_earth_production(delta)


func apply_company_simulation_receipt(receipt: CompanySimulationReceipt,
		payout: int) -> bool:
	if payout <= 0 or not can_apply_company_simulation_receipt(receipt):
		return false
	var delta := EarthProductionDelta.new(receipt.receipt_id,
		EarthProductionDelta.SourceKind.COMPANY_OFFLINE if receipt.offline \
		else EarthProductionDelta.SourceKind.COMPANY_ACTIVE,
		receipt.processed_by_species, receipt.outputs, receipt.elapsed_seconds,
		receipt.offline)
	if not apply_earth_production(delta):
		return false
	_supplier_input_queues = receipt.remaining_queues.duplicate(true)
	_company_last_timestamp = receipt.next_timestamp
	_applied_company_receipts[receipt.receipt_id] = true
	while _applied_company_receipts.size() > 32:
		_applied_company_receipts.erase(_applied_company_receipts.keys()[0])
	_company_return_ledger.append({
		"receipt_id": String(receipt.receipt_id),
		"offline": receipt.offline,
		"elapsed_seconds": receipt.elapsed_seconds,
		"logs": receipt.processed_logs(),
		"cash": payout,
	})
	var cfg := CompanySimulation.config()
	var limit := 12 if cfg == null else cfg.return_ledger_limit
	while _company_return_ledger.size() > limit:
		_company_return_ledger.pop_front()
	company_logistics_changed.emit()
	company_return_ledger_changed.emit()
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
	var def := WoodCatalogue.by_id(species_id)
	if def == null:
		push_error("GameState: no wood species named '%s' — selection refused." % species_id)
		return false
	if not owns_species(species_id):
		return false
	if species_id == EarthCampaign.FINAL_SPECIES_ID \
			and _earth_finale_state not in [EarthFinaleState.IN_PROGRESS,
				EarthFinaleState.COMPLETE]:
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
			_grant_level_reward(level)
			level_gained.emit(level)
		skill_points_changed.emit(get_skill_points_available())
	return true


## Genuine XP earnings enter here. The returned amount is the exact final award
## that presentation must distribute across orbs. Raw grants use add_xp().
func award_xp(base_amount: int, origin: StringName = &"manual") -> int:
	if base_amount <= 0:
		return 0
	var multiplier := _xp_pacing().global_xp_multiplier * (1.0 \
		+ SkillTree.total_modifier(GameplayModifierDef.Kind.GLOBAL_XP_GAIN))
	var awarded := maxi(1, int(round(float(base_amount) * multiplier)))
	return awarded if add_xp(awarded) else 0


func consume_masterwork() -> bool:
	if _masterwork_pending <= 0:
		return false
	_masterwork_pending -= 1
	return true


func get_masterwork_pending() -> int:
	return _masterwork_pending


func _grant_level_reward(level: int) -> void:
	if level <= _last_rewarded_level:
		return
	_last_rewarded_level = level
	var receipt: LevelRewardReceipt
	# Terrestrial levels build the 84-rank core. Frontier points come from the
	# three alien mastery milestones, preventing a grind or a cap-out mismatch.
	if not is_earth_master() \
			and _skill_points_earned_total < SkillTree.core_purchase_count():
		_skill_points_earned_total += 1
		receipt = LevelRewardReceipt.new(level,
			LevelRewardReceipt.RewardType.SKILL_POINT, 1)
	else:
		var cash_reward := _level_cash_reward()
		var awarded := award_cash(cash_reward, &"level")
		receipt = LevelRewardReceipt.new(level,
			LevelRewardReceipt.RewardType.CASH, awarded)
	if SkillTree.owns_modifier(GameplayModifierDef.Kind.MASTERWORK):
		_masterwork_pending += 1
	level_reward_granted.emit(receipt)


func _level_cash_reward() -> int:
	var pacing := _xp_pacing()
	var highest_unit_price := 1
	for species: SpeciesDef in SpeciesTable.all():
		if species != null and owns_species(species.id):
			highest_unit_price = maxi(highest_unit_price, Market.get_price(species.yield_item))
	return maxi(1, int(round(float(highest_unit_price * YARD_PILE_CAPACITY)
		* pacing.level_cash_load_fraction)))


## Credit one player-started completed log. The chopping scene calls this from
## its already de-duplicated manual root outcome, so a proc may land the final
## swing without turning one log into two mastery awards.
func record_species_completion(species_id: StringName, award: int = -1) -> bool:
	if species_id == EarthCampaign.FINAL_SPECIES_ID \
			and _earth_finale_state != EarthFinaleState.COMPLETE:
		return false
	var table := M7CContent.mastery()
	var definition: SpeciesMasteryDef = table.by_species_id(species_id) if table != null else null
	if definition == null:
		push_error("GameState: mastery completion names unknown species '%s' — ignored." % species_id)
		return false
	var before := get_species_mastery_progress(species_id)
	if before >= definition.mastery_target:
		return false
	var receipt_award := definition.manual_completion_award if award < 0 else award
	if receipt_award <= 0:
		return false
	var after := mini(definition.mastery_target, before + receipt_award)
	_species_mastery_progress[species_id] = after
	species_mastery_changed.emit(species_id, after)
	return true


func record_species_completion_receipt(species_id: StringName,
		root_event_id: StringName, award: int = 1) -> bool:
	if root_event_id == &"" or _mastery_completion_sources.has(root_event_id):
		return false
	if not record_species_completion(species_id, clampi(award, 1, 2)):
		return false
	_mastery_completion_sources[root_event_id] = species_id
	while _mastery_completion_sources.size() > 64:
		_mastery_completion_sources.erase(_mastery_completion_sources.keys()[0])
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


## Select one of three persisted long-term offers. New campaign work has exactly
## one active slot; only pre-v17 legacy work may contain multiple active ids.
func accept_commission(offer_id: StringName) -> bool:
	if is_commission_active(offer_id) or not Orders.commissions_unlocked() \
			or not _active_commissions.is_empty() \
			or not _legacy_commission_ids.is_empty() \
			or _standing_commission_cycles_completed \
				>= get_standing_commission_offer_moments_unlocked():
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
	return record_manual_delivery_receipt(ManualPieceReceipt.new(item_id))


func record_manual_delivery_receipt(receipt: ManualPieceReceipt) -> bool:
	if receipt == null or not receipt.is_manual():
		return false
	var order_moved := _record_active_order_piece(receipt)
	var commission_moved := _record_active_commission_piece(receipt)
	return order_moved or commission_moved


func record_automation_bulk_delivery(item_id: StringName, amount: int,
		source_id: StringName) -> int:
	if amount <= 0 or source_id == &"":
		return 0
	var advanced := 0
	for _index in range(amount):
		var receipt := ManualPieceReceipt.new(item_id, &"", 1.0,
			Craftsmanship.Grade.ROUGH, source_id,
			ManualPieceReceipt.Origin.AUTOMATION)
		if _record_active_commission_piece(receipt):
			advanced += 1
	return advanced


## Compatibility seam for existing tests/callers; all production settlement now
## names the shared manual-delivery contract explicitly above.
func record_order_piece(item_id: StringName) -> bool:
	return record_manual_delivery_piece(item_id)


func _record_active_order_piece(piece_receipt: ManualPieceReceipt) -> bool:
	var moved := false
	var completed: Array[Dictionary] = []
	for order: OrderDef in Orders.all():
		if order == null or not is_order_active(order.id) \
				or not order.matches(piece_receipt.item_id):
			continue
		moved = true
		var progress := get_active_order_progress_for(order.id) + 1
		if progress < order.required_count:
			_active_orders[order.id] = progress
			continue
		_active_orders.erase(order.id)
		_completed_orders[order.id] = true
		_append_customer_completion({
			"kind": "order",
			"id": String(order.id),
			"customer": order.customer_name,
			"grade": piece_receipt.grade,
		})
		completed.append({
			"id": order.id,
			"bonus": order.cash_bonus,
			"reputation": order.reputation_reward,
		})
	if not moved:
		return false
	for receipt: Dictionary in completed:
		var bonus := int(receipt.get("bonus", 0))
		if bonus > 0:
			bonus = award_cash(bonus, &"order")
			receipt["awarded_bonus"] = bonus
		var reputation := int(receipt.get("reputation", 0))
		if reputation > 0:
			add_reputation(reputation)
	if has_completed_order(Orders.COMMISSION_UNLOCK_ORDER_ID):
		ensure_commission_offers()
	order_state_changed.emit()
	for receipt: Dictionary in completed:
		order_completed.emit(StringName(receipt.get("id", &"")),
			int(receipt.get("awarded_bonus", receipt.get("bonus", 0))))
	return true


func _record_active_commission_piece(piece_receipt: ManualPieceReceipt) -> bool:
	var moved := false
	var completed: Array[Dictionary] = []
	for offer: Dictionary in _commission_offers.duplicate(true):
		var offer_id := StringName(offer.get("id", &""))
		if not is_commission_active(offer_id) \
				or not Orders.commission_matches_receipt(offer, piece_receipt):
			continue
		moved = true
		var progress := get_active_commission_progress_for(offer_id) + 1
		if progress < int(offer.get("required_count", 0)):
			_active_commissions[offer_id] = progress
			continue
		_active_commissions.erase(offer_id)
		completed.append(offer.duplicate(true))
		_append_customer_completion({
			"kind": "commission",
			"id": String(offer_id),
			"customer": String(offer.get("customer_name", "")),
			"grade": piece_receipt.grade,
		})
	if not moved:
		return false
	for completed_offer: Dictionary in completed:
		var completed_id := StringName(completed_offer.get("id", &""))
		var was_legacy := _legacy_commission_ids.has(completed_id)
		_legacy_commission_ids.erase(completed_id)
		if not was_legacy:
			_standing_commission_cycles_completed += 1
		_completed_commissions += 1
		var bonus := int(completed_offer.get("cash_bonus", 0))
		var reward_source := StringName("standing_commission:%s" % completed_id)
		if bonus > 0 and not _applied_progression_reward_sources.has(reward_source):
			_applied_progression_reward_sources[reward_source] = true
			bonus = award_cash(bonus, &"commission")
			completed_offer["awarded_cash_bonus"] = bonus
		var reputation := int(completed_offer.get("reputation_reward", 0)) \
			+ int(round(Shop.total_effect(UpgradeDef.Effect.COMMISSION_REPUTATION)))
		if reputation > 0:
			add_reputation(reputation)
		var region := RegionalNetwork.region_for_customer(
			StringName(completed_offer.get("customer_id", &"")))
		if region != null and is_region_discovered(region.id):
			add_regional_standing(region.id, 1 + int(round(CompanyStrategy.effect(
				CompanyDoctrineDef.Effect.REGIONAL_STANDING))))
	# Old simultaneous work remains visible until its last accepted contract is
	# done. New standing work clears the whole choice set, advances one generation,
	# and exposes the next compact choice without requiring the board.
	if _legacy_commission_ids.is_empty() and _active_commissions.is_empty():
		_commission_offers.clear()
		_commission_generation += 1
		ensure_commission_offers()
	commission_state_changed.emit()
	for completed_offer: Dictionary in completed:
		commission_completed.emit(completed_offer,
			int(completed_offer.get("awarded_cash_bonus",
				completed_offer.get("cash_bonus", 0))))
	return true


func _append_customer_completion(entry: Dictionary) -> void:
	_customer_completion_history.append(entry.duplicate(true))
	while _customer_completion_history.size() > Orders.customer_history_limit():
		_customer_completion_history.pop_front()


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
			"customer_id": String(normalised.get("customer_id", &"")),
			"title": String(normalised.get("title", "")),
			"description": String(normalised.get("description", "")),
			"offer_role": int(normalised.get("offer_role", -1)),
			"goal_kind": int(normalised.get("goal_kind", -1)),
			"required_species": String(normalised.get("required_species", &"")),
			"required_item": String(normalised.get("required_item", &"")),
			"required_count": int(normalised.get("required_count", 0)),
			"cash_bonus": int(normalised.get("cash_bonus", 0)),
			"reputation_reward": int(normalised.get("reputation_reward", 0)),
			"craft_family": int(normalised.get("craft_family", 0)),
			"min_normalized_size": float(normalised.get("min_normalized_size", 0.0)),
			"max_normalized_size": float(normalised.get("max_normalized_size", 1.0)),
			"minimum_grade": int(normalised.get("minimum_grade", 0)),
			"require_source_identity": bool(normalised.get("require_source_identity", false)),
			"automation_eligible": bool(normalised.get("automation_eligible", false)),
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
	var legacy_commission_ids: Array = []
	for offer_id: StringName in _legacy_commission_ids:
		legacy_commission_ids.append(String(offer_id))
	var legacy_order_id := get_active_order_id()
	var legacy_commission_id := get_active_commission_id()
	return {
		"cash": _cash,
		"lifetime_cash_earned": _lifetime_cash_earned,
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
		"skill_points_earned_total": _skill_points_earned_total,
		"last_rewarded_level": _last_rewarded_level,
		"masterwork_pending": _masterwork_pending,
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
		"legacy_commission_ids": legacy_commission_ids,
		"standing_commission_cycles_completed": \
			_standing_commission_cycles_completed,
		"applied_progression_reward_sources": \
			_applied_progression_reward_sources.keys(),
		"reputation": _reputation,
		"craft_grade_counts": _craft_grade_counts.duplicate(),
		"customer_completion_history": _customer_completion_history.duplicate(true),
		"supplier_input_queues": _supplier_input_queues.duplicate(true),
		"route_priorities": _route_priorities.duplicate(),
		"company_last_timestamp": _company_last_timestamp,
		"automated_log_equivalents": _automated_log_equivalents,
		"company_return_ledger": _company_return_ledger.duplicate(true),
		"applied_company_receipts": _applied_company_receipts.keys(),
		"discovered_regions": _discovered_regions.keys(),
		"regional_standing": _regional_standing.duplicate(true),
		"regional_depots": _regional_depots.keys(),
		"regional_routes": _regional_routes.duplicate(true),
		"signature_log_records": _signature_log_records.duplicate(true),
		"signature_log_sources": _signature_log_sources.duplicate(true),
		"company_doctrine": String(_company_doctrine),
		"infrastructure_projects": _infrastructure_projects.keys(),
		"manual_log_equivalents": _manual_log_equivalents,
		"manual_logs_toward_next_tree": _manual_logs_toward_next_tree,
		"manual_log_sources": _manual_log_sources.keys(),
		"earth_trees_felled": _earth_trees_felled,
		"applied_earth_production_receipts": \
			_applied_earth_production_receipts.keys(),
		"introduced_feature_ids": _introduced_feature_ids.keys(),
		"earth_finale_state": int(_earth_finale_state),
		"earth_finale_splits": _earth_finale_splits,
		"earth_master": _earth_master,
		"launch_projects": _launch_projects.keys(),
		"launch_contributions": _launch_contributions.duplicate(),
		"spacecraft_loadout": _spacecraft_loadout.duplicate(),
		"active_expedition": _active_expedition.duplicate(true),
		"arrived_destinations": _arrived_destinations.keys(),
		"applied_expedition_receipts": _applied_expedition_receipts.keys(),
		"alien_destination_states": _alien_destination_states.duplicate(),
		"alien_manual_mastery": _alien_manual_mastery.duplicate(),
		"alien_manual_sources": _alien_manual_sources.duplicate(),
		"cargo_fleets": _cargo_fleets.duplicate(),
		"orbital_lines": _orbital_lines.keys(),
		"expedition_charter": String(_expedition_charter),
		"applied_alien_automation_receipts": _applied_alien_automation_receipts.keys(),
		"combined_orbital_receipt_received": _combined_orbital_receipt_received,
		"campaign_completion_recorded": _campaign_completion_recorded,
		"tool_tiers": _tool_tiers.duplicate(),
		"building_tiers": _building_tiers.duplicate(),
		"unlocked_biomes": _unlocked_biomes.keys(),
	}


func apply_save_dict(data: Dictionary) -> void:
	## Every field is optional and independently validated: a save written by an
	## older build must load, and a corrupted field must cost only that field.
	## Signals fire after the whole load so a UI never paints a half-restored state.
	_cash = maxi(0, int(data.get("cash", DEFAULT_CASH)))
	_lifetime_cash_earned = clampi(int(data.get("lifetime_cash_earned", _cash)),
		0, MAX_SAFE_ECONOMY_VALUE)
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
	_skill_points_earned_total = maxi(0,
		int(data.get("skill_points_earned_total", maxi(0, get_level() - 1))))
	_last_rewarded_level = clampi(int(data.get("last_rewarded_level", get_level())),
		1, get_level())
	_masterwork_pending = maxi(0, int(data.get("masterwork_pending", 0)))

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
	_mastery_completion_sources = {}
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
	_legacy_commission_ids = {}
	_standing_commission_cycles_completed = clampi(int(data.get(
		"standing_commission_cycles_completed", 0)), 0,
		Orders.standing_commission_limit()) if Orders.commissions_unlocked() else 0
	_applied_progression_reward_sources = {}
	var saved_reward_sources: Variant = data.get(
		"applied_progression_reward_sources", [])
	if saved_reward_sources is Array:
		for raw_source: Variant in saved_reward_sources as Array:
			var source_id := StringName(String(raw_source))
			if source_id != &"":
				_applied_progression_reward_sources[source_id] = true
	# Hoarded terrestrial points stop at the exact core-tree cost. Alien mastery
	# contributes the only nine further entitlements, so the finale cannot begin
	# with a misleading surplus that has nowhere to go.
	var alien_point_sources := 0
	for source_id: StringName in _applied_progression_reward_sources:
		if String(source_id).begins_with("alien_mastery:"):
			alien_point_sources += 1
	var entitlement_cap := SkillTree.core_purchase_count() + alien_point_sources * 3
	_skill_points_earned_total = maxi(get_skill_points_spent(),
		mini(_skill_points_earned_total, entitlement_cap))
	_combined_orbital_receipt_received = false
	_campaign_completion_recorded = false
	_reputation = maxi(0, int(data.get("reputation", 0)))
	_craft_grade_counts = {}
	_customer_completion_history = []
	_supplier_input_queues = {}
	_route_priorities = []
	_company_last_timestamp = maxi(0, int(data.get("company_last_timestamp", 0)))
	_automated_log_equivalents = maxi(0, int(data.get("automated_log_equivalents", 0)))
	_company_return_ledger = []
	_applied_company_receipts = {}
	_discovered_regions = {}
	_regional_standing = {}
	_regional_depots = {}
	_regional_routes = {}
	_signature_log_records = {}
	_signature_log_sources = {}
	_company_doctrine = &""
	_infrastructure_projects = {}
	_manual_log_equivalents = maxi(0, int(data.get("manual_log_equivalents", 0)))
	_manual_logs_toward_next_tree = clampi(
		int(data.get("manual_logs_toward_next_tree", 0)), 0,
		MANUAL_LOGS_PER_EARTH_TREE - 1)
	_manual_log_sources = {}
	var saved_earth_master_compat := bool(data.get("earth_master", false)) \
		and int(data.get("earth_finale_state", EarthFinaleState.LOCKED)) \
			== EarthFinaleState.COMPLETE \
		and int(data.get("earth_finale_splits", 0)) == 3
	var historical_tree_floor := mini(TOTAL_EARTH_TREES,
		floori(float(_manual_log_equivalents) / MANUAL_LOGS_PER_EARTH_TREE) \
			+ _automated_log_equivalents)
	_earth_trees_felled = TOTAL_EARTH_TREES if saved_earth_master_compat else clampi(
		int(data.get("earth_trees_felled", historical_tree_floor)), 0,
		TOTAL_EARTH_TREES)
	_applied_earth_production_receipts = {}
	var saved_earth_receipts: Variant = data.get(
		"applied_earth_production_receipts", [])
	if saved_earth_receipts is Array:
		for raw_receipt: Variant in saved_earth_receipts as Array:
			var receipt_id := StringName(raw_receipt)
			if receipt_id != &"":
				_applied_earth_production_receipts[receipt_id] = true
	_introduced_feature_ids = {}
	var saved_introductions: Variant = data.get("introduced_feature_ids", [])
	if saved_introductions is Array:
		for raw_feature: Variant in saved_introductions as Array:
			var feature_id := StringName(raw_feature)
			if feature_id != &"" and _introduced_feature_ids.size() < 256:
				_introduced_feature_ids[feature_id] = true
	_earth_finale_state = EarthFinaleState.LOCKED
	_earth_finale_splits = 0
	_earth_master = false
	_launch_projects = {}
	_launch_contributions = {}
	_spacecraft_loadout = {}
	_active_expedition = {}
	_arrived_destinations = {}
	_applied_expedition_receipts = {}
	_alien_destination_states = {}
	_alien_manual_mastery = {}
	_alien_manual_sources = {}
	_cargo_fleets = {}
	_orbital_lines = {}
	_expedition_charter = &""
	_applied_alien_automation_receipts = {}
	var saved_craft_counts: Variant = data.get("craft_grade_counts")
	if saved_craft_counts is Dictionary:
		for raw_grade: Variant in saved_craft_counts as Dictionary:
			var grade := int(raw_grade)
			var count := maxi(0, int((saved_craft_counts as Dictionary)[raw_grade]))
			if grade >= Craftsmanship.Grade.ROUGH \
					and grade <= Craftsmanship.Grade.EXCEPTIONAL and count > 0:
				_craft_grade_counts[grade] = count
	var saved_customer_history: Variant = data.get("customer_completion_history", [])
	if saved_customer_history is Array:
		for raw_entry: Variant in saved_customer_history as Array:
			if raw_entry is Dictionary:
				var entry := (raw_entry as Dictionary).duplicate(true)
				if not String(entry.get("customer", "")).strip_edges().is_empty():
					_customer_completion_history.append(entry)
		while _customer_completion_history.size() > Orders.customer_history_limit():
			_customer_completion_history.pop_front()
	var cfg := CompanySimulation.config()
	var saved_queues: Variant = data.get("supplier_input_queues", {})
	if cfg != null and saved_queues is Dictionary:
		for raw_species: Variant in saved_queues as Dictionary:
			var species_id := StringName(raw_species)
			# Building tiers are restored later in this routine. Preserve the saved
			# bounded count here, then clamp against the restored rack capacity below.
			var count := clampi(int((saved_queues as Dictionary)[raw_species]), 0, 1000000)
			if SpeciesTable.by_id(species_id) != null and count > 0:
				_supplier_input_queues[species_id] = count
	var saved_priorities: Variant = data.get("route_priorities", [])
	if saved_priorities is Array:
		for raw_species: Variant in saved_priorities as Array:
			var species_id := StringName(raw_species)
			if _supplier_input_queues.has(species_id) \
					and not _route_priorities.has(species_id):
				_route_priorities.append(species_id)
	var saved_ledger: Variant = data.get("company_return_ledger", [])
	if saved_ledger is Array:
		for raw_entry: Variant in saved_ledger as Array:
			if raw_entry is Dictionary and int((raw_entry as Dictionary).get("logs", 0)) > 0:
				_company_return_ledger.append((raw_entry as Dictionary).duplicate(true))
		var ledger_limit := 12 if cfg == null else cfg.return_ledger_limit
		while _company_return_ledger.size() > ledger_limit:
			_company_return_ledger.pop_front()
	var saved_receipts: Variant = data.get("applied_company_receipts", [])
	if saved_receipts is Array:
		for raw_receipt: Variant in saved_receipts as Array:
			var receipt_id := StringName(raw_receipt)
			if receipt_id != &"" and _applied_company_receipts.size() < 32:
				_applied_company_receipts[receipt_id] = true
	var saved_regions: Variant = data.get("discovered_regions", [])
	if saved_regions is Array:
		for raw_region: Variant in saved_regions as Array:
			var region_id := StringName(raw_region)
			if RegionalNetwork.region_by_id(region_id) != null:
				_discovered_regions[region_id] = true
	var saved_standing: Variant = data.get("regional_standing", {})
	if saved_standing is Dictionary:
		for raw_region: Variant in saved_standing as Dictionary:
			var region_id := StringName(raw_region)
			if _discovered_regions.has(region_id):
				_regional_standing[region_id] = maxi(0,
					int((saved_standing as Dictionary)[raw_region]))
	var saved_depots: Variant = data.get("regional_depots", [])
	if saved_depots is Array:
		for raw_region: Variant in saved_depots as Array:
			var region_id := StringName(raw_region)
			if _discovered_regions.has(region_id):
				_regional_depots[region_id] = true
	var saved_routes: Variant = data.get("regional_routes", {})
	if saved_routes is Dictionary:
		for raw_region: Variant in saved_routes as Dictionary:
			var region_id := StringName(raw_region)
			var route := RegionalNetwork.route_for_region(region_id)
			if _regional_depots.has(region_id) and route != null \
					and StringName((saved_routes as Dictionary)[raw_region]) == route.id:
				_regional_routes[region_id] = route.id
	var saved_signature_records: Variant = data.get("signature_log_records", {})
	if saved_signature_records is Dictionary:
		for raw_species: Variant in saved_signature_records as Dictionary:
			var species_id := StringName(raw_species)
			var count := maxi(0, int((saved_signature_records as Dictionary)[raw_species]))
			if RegionalNetwork.region_for_species(species_id) != null and count > 0:
				_signature_log_records[species_id] = count
	var saved_signature_sources: Variant = data.get("signature_log_sources", {})
	if saved_signature_sources is Dictionary:
		for raw_source: Variant in saved_signature_sources as Dictionary:
			var source_id := StringName(raw_source)
			var species_id := StringName((saved_signature_sources as Dictionary)[raw_source])
			if source_id != &"" and RegionalNetwork.region_for_species(species_id) != null:
				_signature_log_sources[source_id] = species_id
	var saved_doctrine := StringName(String(data.get("company_doctrine", "")))
	if CompanyStrategy.doctrine_by_id(saved_doctrine) != null:
		_company_doctrine = saved_doctrine
	var saved_projects: Variant = data.get("infrastructure_projects", [])
	if saved_projects is Array:
		for raw_project: Variant in saved_projects as Array:
			var project_id := StringName(raw_project)
			if RegionalNetwork.project_by_id(project_id) != null:
				_infrastructure_projects[project_id] = true
	var saved_manual_sources: Variant = data.get("manual_log_sources", [])
	if saved_manual_sources is Array:
		for raw_source: Variant in saved_manual_sources as Array:
			var source_id := StringName(raw_source)
			if source_id != &"" and _manual_log_sources.size() < 64:
				_manual_log_sources[source_id] = true
	var saved_finale_state := clampi(int(data.get("earth_finale_state",
		EarthFinaleState.LOCKED)), EarthFinaleState.LOCKED, EarthFinaleState.COMPLETE)
	var saved_finale_splits := clampi(int(data.get("earth_finale_splits", 0)), 0, 3)
	var saved_earth_master := bool(data.get("earth_master", false))
	# V14 Earth Master saves were migrated to the depleted total. In v15 only the
	# tree counter opens launch; the old three-field agreement remains the safe
	# compatibility test for direct pre-migration fixtures.
	if is_earth_depleted() and (saved_earth_master or saved_earth_master_compat):
		_earth_finale_state = EarthFinaleState.COMPLETE
		_earth_finale_splits = saved_finale_splits
		_earth_master = true
	elif saved_finale_state in [EarthFinaleState.IN_PROGRESS, EarthFinaleState.COMPLETE]:
		_earth_finale_state = saved_finale_state
		_earth_finale_splits = saved_finale_splits
	var saved_launch_projects: Variant = data.get("launch_projects", [])
	if saved_launch_projects is Array and _earth_master:
		for project: LaunchProjectDef in LaunchProgram.projects():
			if not (saved_launch_projects as Array).has(String(project.id)) \
					and not (saved_launch_projects as Array).has(project.id):
				break
			_launch_projects[project.id] = true
	var saved_launch_contributions: Variant = data.get("launch_contributions", {})
	var next_launch := _next_launch_project()
	if saved_launch_contributions is Dictionary and next_launch != null:
		var amount := clampi(int((saved_launch_contributions as Dictionary).get(
			String(next_launch.id), (saved_launch_contributions as Dictionary).get(
				next_launch.id, 0))), 0, next_launch.contribution_amount)
		if amount > 0:
			_launch_contributions[next_launch.id] = amount
	var saved_loadout: Variant = data.get("spacecraft_loadout", {})
	if saved_loadout is Dictionary and has_launch_project(&"deep_space_vessel"):
		for raw_slot: Variant in saved_loadout as Dictionary:
			var component_id := StringName((saved_loadout as Dictionary)[raw_slot])
			var component := LaunchProgram.component_by_id(component_id)
			if component != null and int(raw_slot) == component.slot:
				_spacecraft_loadout[component.slot] = component.id
	var saved_arrivals: Variant = data.get("arrived_destinations", [])
	if saved_arrivals is Array:
		for raw_destination: Variant in saved_arrivals as Array:
			var destination_id := StringName(raw_destination)
			if LaunchProgram.expedition_by_id(destination_id) != null:
				_arrived_destinations[destination_id] = true
	var saved_expedition_receipts: Variant = data.get("applied_expedition_receipts", [])
	if saved_expedition_receipts is Array:
		for raw_receipt: Variant in saved_expedition_receipts as Array:
			var receipt_id := StringName(raw_receipt)
			if receipt_id != &"" and _applied_expedition_receipts.size() < 16:
				_applied_expedition_receipts[receipt_id] = true
	var saved_active_expedition: Variant = data.get("active_expedition", {})
	if saved_active_expedition is Dictionary and has_launch_project(&"deep_space_vessel"):
		var active_destination := LaunchProgram.expedition_by_id(StringName(
			(saved_active_expedition as Dictionary).get("destination_id", &"")))
		var active_id := StringName((saved_active_expedition as Dictionary).get("id", &""))
		var planned_at := maxi(0, int((saved_active_expedition as Dictionary).get(
			"planned_at", 0)))
		var arrives_at := maxi(planned_at, int((saved_active_expedition as Dictionary).get(
			"arrives_at", planned_at)))
		if active_destination != null and active_id != &"" \
				and arrives_at - planned_at == active_destination.flight_seconds:
			_active_expedition = {
				"id": active_id,
				"destination_id": active_destination.id,
				"planned_at": planned_at,
				"arrives_at": arrives_at,
			}
	var saved_alien_states: Variant = data.get("alien_destination_states", {})
	if saved_alien_states is Dictionary:
		for raw_destination: Variant in saved_alien_states as Dictionary:
			var destination_id := StringName(raw_destination)
			if not _arrived_destinations.has(destination_id) \
					or AlienCampaign.trait_for_destination(destination_id) == null:
				continue
			var state := clampi(int((saved_alien_states as Dictionary)[raw_destination]),
				AlienDestinationState.SURVEYED, AlienDestinationState.MASTERED)
			_alien_destination_states[destination_id] = state
	var saved_alien_mastery: Variant = data.get("alien_manual_mastery", {})
	if saved_alien_mastery is Dictionary:
		for raw_species: Variant in saved_alien_mastery as Dictionary:
			var species_id := StringName(raw_species)
			var wood_trait := AlienCampaign.trait_by_id(species_id)
			if wood_trait == null or get_alien_destination_state(wood_trait.destination_id) \
					< AlienDestinationState.CERTIFIED:
				continue
			var count := clampi(int((saved_alien_mastery as Dictionary)[raw_species]),
				1, wood_trait.manual_mastery_target)
			_alien_manual_mastery[species_id] = count
			if get_alien_destination_state(wood_trait.destination_id) \
					== AlienDestinationState.MASTERED and count < wood_trait.manual_mastery_target:
				_alien_destination_states[wood_trait.destination_id] = \
					AlienDestinationState.REPEAT_CARGO
	var saved_alien_sources: Variant = data.get("alien_manual_sources", {})
	if saved_alien_sources is Dictionary:
		for raw_source: Variant in saved_alien_sources as Dictionary:
			var source_id := StringName(raw_source)
			var species_id := StringName((saved_alien_sources as Dictionary)[raw_source])
			if source_id != &"" and AlienCampaign.trait_by_id(species_id) != null \
					and _alien_manual_sources.size() < 64:
				_alien_manual_sources[source_id] = species_id
	var cfg_alien := AlienCompanySimulation.config()
	var saved_fleets: Variant = data.get("cargo_fleets", {})
	if cfg_alien != null and saved_fleets is Dictionary:
		for raw_destination: Variant in saved_fleets as Dictionary:
			var destination_id := StringName(raw_destination)
			if get_alien_destination_state(destination_id) \
					< AlienDestinationState.REPEAT_CARGO:
				continue
			var count := clampi(int((saved_fleets as Dictionary)[raw_destination]),
				0, cfg_alien.fleet_cap_per_destination)
			if count > 0:
				_cargo_fleets[destination_id] = count
	var saved_lines: Variant = data.get("orbital_lines", [])
	if saved_lines is Array:
		for raw_destination: Variant in saved_lines as Array:
			var destination_id := StringName(raw_destination)
			if get_alien_destination_state(destination_id) \
					== AlienDestinationState.MASTERED:
				_orbital_lines[destination_id] = true
	var saved_charter := StringName(data.get("expedition_charter", &""))
	if saved_charter == &"" or AlienCampaign.trait_for_destination(saved_charter) != null:
		_expedition_charter = saved_charter
	var saved_alien_receipts: Variant = data.get("applied_alien_automation_receipts", [])
	if saved_alien_receipts is Array:
		for raw_receipt: Variant in saved_alien_receipts as Array:
			var receipt_id := StringName(raw_receipt)
			if receipt_id != &"" and _applied_alien_automation_receipts.size() < 24:
				_applied_alien_automation_receipts[receipt_id] = true
	_combined_orbital_receipt_received = bool(data.get(
		"combined_orbital_receipt_received", false)) \
		and get_orbital_line_count() >= AlienCampaign.traits().size()
	_campaign_completion_recorded = bool(data.get(
		"campaign_completion_recorded", false)) \
		and is_campaign_complete()
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
		var saved_legacy_ids: Variant = data.get("legacy_commission_ids", [])
		if saved_legacy_ids is Array:
			for raw_id: Variant in saved_legacy_ids as Array:
				var legacy_id := StringName(String(raw_id))
				if _active_commissions.has(legacy_id):
					_legacy_commission_ids[legacy_id] = true
	if bool(data.get("refresh_inactive_commission_slots_v6", false)) \
			and not _commission_offers.is_empty():
		var preserved_slots: Dictionary = {}
		for index in range(_commission_offers.size()):
			var offer: Dictionary = _commission_offers[index]
			var offer_id := StringName(offer.get("id", &""))
			if _active_commissions.has(offer_id):
				preserved_slots[index] = offer
		var refreshed := Orders.generate_commission_offers(
			_commission_generation + 1, preserved_slots)
		if refreshed.size() == Orders.COMMISSION_OFFER_COUNT:
			_commission_generation += 1
			_commission_offers = refreshed
	# V17 no longer relies on entering the Contract Board. A deterministic pending
	# choice is ordinary session state, not a reward, and cannot be rerolled.
	ensure_commission_offers()

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
	var restored_queue_capacity := CompanyLogistics.supplier_queue_capacity()
	for species_id: StringName in _supplier_input_queues.keys():
		_supplier_input_queues[species_id] = mini(
			int(_supplier_input_queues[species_id]), restored_queue_capacity)
	_lifetime_cash_earned = maxi(_lifetime_cash_earned,
		_minimum_lifetime_cash_for_loaded_progression())

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
	lifetime_cash_earned_changed.emit(_lifetime_cash_earned)
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
	reputation_changed.emit(_reputation)
	for grade in range(Craftsmanship.Grade.EXCEPTIONAL + 1):
		craftsmanship_changed.emit(grade, get_craft_grade_count(grade))
	company_logistics_changed.emit()
	company_return_ledger_changed.emit()
	regional_network_changed.emit()
	company_strategy_changed.emit()
	earth_trees_changed.emit(get_earth_trees_remaining(), 0)
	manual_log_progress_changed.emit(_manual_log_equivalents,
		_manual_logs_toward_next_tree)
	earth_campaign_changed.emit()
	launch_program_changed.emit()
	expedition_changed.emit()
	alien_campaign_changed.emit()
	building_tiers_changed.emit()


func reset_to_defaults() -> void:
	## Fresh save. Used by SaveSystem when no file exists and by the test suites,
	## which need a known slate without restarting the process.
	_cash = DEFAULT_CASH
	_lifetime_cash_earned = 0
	_lifetime_wood_chopped = 0
	_yard_pile = {}
	_haul_aways_completed = 0
	_selected_species = &""
	_owned_species = {}
	_species_mastery_progress = {}
	_splitter_assigned_species = &""
	_xp = 0
	_skill_levels = {}
	_skill_points_earned_total = 0
	_last_rewarded_level = 1
	_masterwork_pending = 0
	_legacy_skill_ranks = {}
	_proc_dry_streak = {}
	_mastery_completion_sources = {}
	_active_orders = {}
	_completed_orders = {}
	_commission_offers = []
	_commission_generation = 0
	_active_commissions = {}
	_completed_commissions = 0
	_legacy_commission_ids = {}
	_standing_commission_cycles_completed = 0
	_applied_progression_reward_sources = {}
	_reputation = 0
	_craft_grade_counts = {}
	_customer_completion_history = []
	_supplier_input_queues = {}
	_route_priorities = []
	_company_last_timestamp = 0
	_automated_log_equivalents = 0
	_company_return_ledger = []
	_applied_company_receipts = {}
	_discovered_regions = {}
	_regional_standing = {}
	_regional_depots = {}
	_regional_routes = {}
	_signature_log_records = {}
	_signature_log_sources = {}
	_company_doctrine = &""
	_infrastructure_projects = {}
	_manual_log_equivalents = 0
	_manual_logs_toward_next_tree = 0
	_manual_log_sources = {}
	_earth_trees_felled = 0
	_applied_earth_production_receipts = {}
	_introduced_feature_ids = {}
	_earth_finale_state = EarthFinaleState.LOCKED
	_earth_finale_splits = 0
	_earth_master = false
	_launch_projects = {}
	_launch_contributions = {}
	_spacecraft_loadout = {}
	_active_expedition = {}
	_arrived_destinations = {}
	_applied_expedition_receipts = {}
	_alien_destination_states = {}
	_alien_manual_mastery = {}
	_alien_manual_sources = {}
	_cargo_fleets = {}
	_orbital_lines = {}
	_expedition_charter = &""
	_applied_alien_automation_receipts = {}
	_combined_orbital_receipt_received = false
	_campaign_completion_recorded = false
	_campaign_phase_cache = CampaignPhase.COZY_CLEARING
	_tool_tiers = {
		Enums.ToolType.AXE: DEFAULT_TOOL_TIER,
	}
	_building_tiers = {}
	_unlocked_biomes = { Enums.Biome.PINE_FOREST: true }
	cash_changed.emit(_cash)
	lifetime_cash_earned_changed.emit(0)
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
	reputation_changed.emit(0)
	for grade in range(Craftsmanship.Grade.EXCEPTIONAL + 1):
		craftsmanship_changed.emit(grade, 0)
	company_logistics_changed.emit()
	company_return_ledger_changed.emit()
	regional_network_changed.emit()
	company_strategy_changed.emit()
	earth_trees_changed.emit(TOTAL_EARTH_TREES, 0)
	manual_log_progress_changed.emit(0, 0)
	earth_campaign_changed.emit()
	launch_program_changed.emit()
	expedition_changed.emit()
	alien_campaign_changed.emit()
	building_tiers_changed.emit()


func _minimum_lifetime_cash_for_loaded_progression() -> int:
	var floor_value := 0
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade is ProductionUpgradeDef and Shop.get_level(upgrade.id) > 0:
			floor_value = maxi(floor_value,
				(upgrade as ProductionUpgradeDef).required_lifetime_cash)
	if CompanyLogistics.all_owned():
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(
				ProductionUpgradeDef.Milestone.TIMBER_DEPOT))
	if get_regional_route_count() > 0:
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(
				ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY))
	if EarthCampaign.terrestrial_requirements_complete():
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(
				ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY))
	var line_count := get_orbital_line_count()
	if line_count > 0:
		var milestone := ProductionUpgradeDef.Milestone.FIRST_ALIEN_LINE
		if line_count >= 3:
			milestone = ProductionUpgradeDef.Milestone.THREE_ALIEN_LINES
		elif line_count >= 2:
			milestone = ProductionUpgradeDef.Milestone.SECOND_ALIEN_LINE
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(milestone))
	return mini(floor_value, MAX_SAFE_ECONOMY_VALUE)

## Progression tuning is part of the single global GameConfig resource; level is
## derived from XP and this curve rather than persisted as a second authority.

func _level_curve() -> LevelCurve:
	return GameConfig.current().level_curve


func _xp_pacing() -> XPPacingConfig:
	return GameConfig.current().xp_pacing


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
