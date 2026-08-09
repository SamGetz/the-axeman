class_name SaveSystem
extends RefCounted
## FILE: res://core/save_system.gd
## ATTACHES TO: nothing. class_name + static methods only — do NOT register as an
## autoload. It holds no state, so it needs none of what an autoload provides,
## and adding a 5th autoload would need an amendment the way GameFeel did
## (Amendment 5). Call it as `SaveSystem.save_game()`.
##
## Orchestrates persistence WITHOUT owning any of it. Each system serialises
## itself — GameState.to_save_dict()/apply_save_dict() and the same pair on
## InventoryManager — so Directive 6 still holds: progression is only ever
## written inside GameState, item counts only inside InventoryManager. This file
## moves dictionaries to and from disk and does nothing else.
##
## The save is a ConfigFile because it stores Variants natively (ints stay ints,
## StringName keys survive), it is human-readable when a save goes wrong, and it
## tolerates unknown sections written by a future build.

enum LoadResult {
	OK,        ## loaded and applied
	NO_FILE,   ## nothing saved yet — a fresh game, not an error
	CORRUPT,   ## unreadable or malformed; caller should start fresh
	TOO_NEW,   ## written by a newer build; NOT applied, and preserved on disk
}

const SAVE_PATH := "user://the_axeman_save.cfg"
## Written beside the save and renamed over it only once fully flushed, so a
## crash or a pulled plug mid-write cannot leave a truncated save. Losing an
## incremental autosave is survivable; losing the whole yard is not.
const _TEMP_PATH := "user://the_axeman_save.cfg.tmp"
## Bumped whenever the on-disk shape changes in a way _migrate has to handle.
const SAVE_VERSION := 17

## Version-1's prototype ranks are an on-disk compatibility contract. These
## caps are intentionally pinned to that prototype rather than read from the
## live M7C tree: a later tuning pass must not change what a historical save is
## allowed to retain while it is being migrated.
const _V1_RETAINED_SKILLS := {
	"strong_arms": {"sources": ["strong_arms"], "cap": 10},
	"quick_hands": {"sources": ["quick_hands"], "cap": 10},
	"ready_stance": {"sources": ["keen_edge", "ready_stance"], "cap": 5},
	"quick_study": {"sources": ["woodsman", "quick_study"], "cap": 5},
}

const _SECTION_META := "meta"
const _SECTION_PROGRESSION := "progression"
const _SECTION_INVENTORY := "inventory"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes the current game to disk. Returns false (and leaves any existing save
## untouched) if the write fails.
static func save_game() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value(_SECTION_META, "version", SAVE_VERSION)
	cfg.set_value(_SECTION_META, "saved_at_unix", int(Time.get_unix_time_from_system()))
	cfg.set_value(_SECTION_PROGRESSION, "data", GameState.to_save_dict())
	cfg.set_value(_SECTION_INVENTORY, "counts", InventoryManager.to_save_dict())

	var err := cfg.save(_TEMP_PATH)
	if err != OK:
		push_error("SaveSystem: could not write '%s' (error %d) — existing save left intact." % [_TEMP_PATH, err])
		return false

	# Replace only now that the bytes are safely down.
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveSystem: could not open user:// to finalise the save.")
		return false
	if dir.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	err = dir.rename(_TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveSystem: could not move the temp save into place (error %d)." % err)
		return false
	return true


## Reads the save and hands each dictionary back to the system that owns it.
## Applies NOTHING unless the whole file parses, so a bad save cannot leave the
## game half-loaded.
static func load_game() -> LoadResult:
	if not has_save():
		return LoadResult.NO_FILE

	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		push_error("SaveSystem: save at '%s' could not be parsed (error %d)." % [SAVE_PATH, err])
		return LoadResult.CORRUPT

	var version := int(cfg.get_value(_SECTION_META, "version", -1))
	if version < 0:
		push_error("SaveSystem: save has no version stamp — treating as corrupt.")
		return LoadResult.CORRUPT
	if version > SAVE_VERSION:
		# Do NOT load, and do not let the next autosave quietly overwrite it: a
		# player who ran a newer build and then an older one would lose the yard.
		push_warning("SaveSystem: save version %d is newer than this build understands (%d). Not loaded; preserved as a backup." % [version, SAVE_VERSION])
		_preserve_unreadable_save("newer")
		return LoadResult.TOO_NEW

	var progression: Variant = cfg.get_value(_SECTION_PROGRESSION, "data", {})
	var inventory: Variant = cfg.get_value(_SECTION_INVENTORY, "counts", {})
	if not (progression is Dictionary) or not (inventory is Dictionary):
		push_error("SaveSystem: save sections are malformed — treating as corrupt.")
		return LoadResult.CORRUPT

	progression = _migrate(progression as Dictionary, version)

	GameState.apply_save_dict(progression as Dictionary)
	InventoryManager.apply_save_dict(inventory as Dictionary)
	return LoadResult.OK


## Loads if there is something to load, otherwise starts a clean game. This is
## the call a boot sequence wants; load_game() is for when the result matters.
static func load_or_start_fresh() -> LoadResult:
	var result := load_game()
	if result != LoadResult.OK:
		GameState.reset_to_defaults()
		InventoryManager.apply_save_dict({})
	return result


static func delete_save() -> bool:
	if not has_save():
		return true
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.remove(SAVE_PATH) == OK


## Forward migration is PURE: it works on a deep copy and never rewrites the
## older file. load_game() applies the copy in memory; only the next complete
## save_game() replaces the old file atomically with a current-version one.
static func _migrate(progression: Dictionary, from_version: int) -> Dictionary:
	if from_version == SAVE_VERSION:
		return progression
	var migrated := progression.duplicate(true)
	var version := from_version
	if version == 1:
		migrated = _migrate_v1_to_v2(migrated)
		version = 2
	if version == 2:
		# Mastery is an additive field. Explicitly seed it so a migrated save has
		# the same byte-shape as a fresh v3 save and later migrations can rely on
		# the field existing without ever inventing historical progress.
		if not (migrated.get("species_mastery_progress") is Dictionary):
			migrated["species_mastery_progress"] = {}
		version = 3
	if version == 3:
		# Slice 3 adds one optional routing choice. Older saves start deliberately
		# idle; migration must never auto-assign a certified profile on the player's
		# behalf.
		migrated["splitter_assigned_species"] = ""
		version = 4
	if version == 4:
		# M9 adds generated repeatable manual work. Older yards receive no
		# retroactive offers, active progress, completion count or premium. Their
		# first eligible board entry creates a fresh persisted offer set through
		# GameState after the player has deliberately started the session.
		migrated["commission_offers"] = []
		migrated["commission_generation"] = 0
		migrated["active_commission"] = ""
		migrated["active_commission_progress"] = 0
		migrated["active_orders"] = []
		migrated["active_commissions"] = []
		migrated["completed_commissions"] = 0
		version = 5
	if version == 5:
		# V6 gives each of the three stable slots a semantic role. Accepted v5
		# snapshots keep their exact work and premium; GameState uses this marker
		# to rebuild inactive slots only after active identities are restored.
		var offers: Variant = migrated.get("commission_offers", [])
		if offers is Array:
			var role_offers: Array = []
			for index in range((offers as Array).size()):
				var raw_offer: Variant = (offers as Array)[index]
				if not raw_offer is Dictionary:
					continue
				var offer := (raw_offer as Dictionary).duplicate(true)
				offer["offer_role"] = clampi(index, 0, Orders.COMMISSION_OFFER_COUNT - 1)
				role_offers.append(offer)
			migrated["commission_offers"] = role_offers
		migrated["refresh_inactive_commission_slots_v6"] = true
		version = 6
	if version == 6:
		migrated["reputation"] = 0
		migrated["craft_grade_counts"] = {}
		migrated["customer_completion_history"] = []
		# Existing accepted commissions remain ordinary quantity/species work.
		# New craft-family rules must never be retroactively attached to active
		# snapshots during an additive migration.
		var offers: Variant = migrated.get("commission_offers", [])
		if offers is Array:
			for raw_offer: Variant in offers as Array:
				if raw_offer is Dictionary:
					(raw_offer as Dictionary)["craft_family"] = CraftRequirementDef.Family.QUANTITY
					(raw_offer as Dictionary)["min_normalized_size"] = 0.0
					(raw_offer as Dictionary)["max_normalized_size"] = 1.0
					(raw_offer as Dictionary)["minimum_grade"] = Craftsmanship.Grade.ROUGH
					(raw_offer as Dictionary)["require_source_identity"] = false
					(raw_offer as Dictionary)["automation_eligible"] = false
		version = 7
	if version == 7:
		migrated["supplier_input_queues"] = {}
		migrated["route_priorities"] = []
		migrated["company_last_timestamp"] = 0
		migrated["automated_log_equivalents"] = 0
		migrated["company_return_ledger"] = []
		migrated["applied_company_receipts"] = []
		version = 8
	if version == 8:
		migrated["discovered_regions"] = []
		migrated["regional_standing"] = {}
		migrated["regional_depots"] = []
		migrated["regional_routes"] = {}
		migrated["signature_log_records"] = {}
		migrated["signature_log_sources"] = {}
		version = 9
	if version == 9:
		migrated["company_doctrine"] = ""
		migrated["infrastructure_projects"] = []
		migrated["manual_log_equivalents"] = 0
		migrated["manual_log_sources"] = []
		version = 10
	if version == 10:
		migrated["earth_finale_state"] = GameState.EarthFinaleState.LOCKED
		migrated["earth_finale_splits"] = 0
		migrated["earth_master"] = false
		migrated["launch_projects"] = []
		migrated["launch_contributions"] = {}
		migrated["spacecraft_loadout"] = {}
		migrated["active_expedition"] = {}
		migrated["arrived_destinations"] = []
		migrated["applied_expedition_receipts"] = []
		version = 11
	if version == 11:
		migrated["alien_destination_states"] = {}
		migrated["alien_manual_mastery"] = {}
		migrated["alien_manual_sources"] = {}
		migrated["cargo_fleets"] = {}
		migrated["orbital_lines"] = []
		migrated["expedition_charter"] = ""
		migrated["applied_alien_automation_receipts"] = []
		version = 12
	if version == 12:
		# V13 is the approved full skill refund. XP and its uncapped derived level
		# survive; old nodes, prototype price bases and affected fairness streaks do
		# not. Historical levels seed point entitlement but never retroactive cash.
		var curve := GameConfig.current().level_curve
		if curve == null:
			curve = LevelCurve.new()
		var derived_level := curve.level_for_xp(maxi(0, int(migrated.get("xp", 0))))
		migrated["skill_levels"] = {}
		migrated["legacy_skill_ranks"] = {}
		migrated["proc_dry_streak"] = {}
		migrated["skill_points_earned_total"] = maxi(0, derived_level - 1)
		migrated["last_rewarded_level"] = derived_level
		migrated["masterwork_pending"] = 0
		version = 13
	if version == 13:
		# V14 introduces fully-ranked prerequisites. A v13 player may legitimately
		# own a child above what is now a partial 1/5 parent, so retaining that shape
		# would create an impossible tree. Preserve earned entitlement and every
		# unrelated field, but refund the node choices and their proc carry-over.
		migrated["skill_levels"] = {}
		migrated["legacy_skill_ranks"] = {}
		migrated["proc_dry_streak"] = {}
		migrated["masterwork_pending"] = 0
		version = 14
	if version == 14:
		# V15 replaces the manual three-split launch authority with the approved
		# 3.04-trillion Earth depletion counter and adds gross earned cash for
		# fixed earning-band reveals. Compatible Earth Master saves retain launch;
		# other saves receive their conservative persisted tree-equivalent work.
		var legacy_master := bool(migrated.get("earth_master", false)) \
			and int(migrated.get("earth_finale_state",
				GameState.EarthFinaleState.LOCKED)) == GameState.EarthFinaleState.COMPLETE \
			and int(migrated.get("earth_finale_splits", 0)) == 3
		var historical_trees := floori(float(maxi(0,
			int(migrated.get("manual_log_equivalents", 0)))) \
			/ GameState.MANUAL_LOGS_PER_EARTH_TREE) + maxi(0,
			int(migrated.get("automated_log_equivalents", 0)))
		migrated["earth_trees_felled"] = GameState.TOTAL_EARTH_TREES \
			if legacy_master else mini(GameState.TOTAL_EARTH_TREES, historical_trees)
		migrated["applied_earth_production_receipts"] = []
		migrated["lifetime_cash_earned"] = _migrated_lifetime_cash_floor(migrated)
		# Existing saves have already seen everything their current progression
		# exposes. Later reveal-policy slices will seed concrete ids from live state.
		migrated["introduced_feature_ids"] = []
		version = 15
	if version == 15:
		# V16 defines four completed manual logs as one Earth tree. V15 saves have
		# already committed their historical authoritative tree total, so only the
		# new partial-log accumulator starts empty; no old work is counted twice.
		migrated["manual_logs_toward_next_tree"] = 0
		version = 16
	if version == 16:
		# V17 replaces three repeatable active commission slots with one long-term
		# standing slot. Already accepted work is explicitly tagged as legacy so
		# every old promise remains finishable; it never consumes one of the five
		# new campaign offer moments or silently pays during migration.
		var legacy_ids: Array = []
		var active: Variant = migrated.get("active_commissions", [])
		if active is Array:
			for raw_active: Variant in active as Array:
				if raw_active is Dictionary:
					var active_id := String((raw_active as Dictionary).get("id", ""))
					if not active_id.is_empty() and not legacy_ids.has(active_id):
						legacy_ids.append(active_id)
		migrated["legacy_commission_ids"] = legacy_ids
		migrated["standing_commission_cycles_completed"] = 0
		var reward_sources: Array = []
		var alien_states: Variant = migrated.get("alien_destination_states", {})
		if alien_states is Dictionary:
			for raw_destination: Variant in alien_states as Dictionary:
				if int((alien_states as Dictionary)[raw_destination]) \
						!= GameState.AlienDestinationState.MASTERED:
					continue
				var wood_trait := AlienCampaign.trait_for_destination(StringName(raw_destination))
				if wood_trait != null:
					reward_sources.append("alien_mastery:%s" % wood_trait.id)
		migrated["skill_points_earned_total"] = mini(SkillTree.core_purchase_count(),
			maxi(0, int(migrated.get("skill_points_earned_total", 0)))) \
			+ reward_sources.size() * 3
		migrated["applied_progression_reward_sources"] = reward_sources
		migrated["combined_orbital_receipt_received"] = false
		migrated["campaign_completion_recorded"] = false
		version = 17
	return migrated


static func _migrated_lifetime_cash_floor(data: Dictionary) -> int:
	var floor_value := clampi(int(data.get("cash", 0)), 0,
		GameState.MAX_SAFE_ECONOMY_VALUE)
	var buildings: Variant = data.get("building_tiers", {})
	if buildings is Dictionary:
		for upgrade: UpgradeDef in Shop.get_upgrades():
			if not upgrade is ProductionUpgradeDef:
				continue
			var tier := int((buildings as Dictionary).get(upgrade.id,
				(buildings as Dictionary).get(String(upgrade.id), 1)))
			if tier > GameState.DEFAULT_BUILDING_TIER:
				floor_value = maxi(floor_value,
					(upgrade as ProductionUpgradeDef).required_lifetime_cash)
		if int((buildings as Dictionary).get("dispatch_console", 1)) > 1:
			floor_value = maxi(floor_value,
				ProductionEconomy.minimum_lifetime_for_milestone(
					ProductionUpgradeDef.Milestone.TIMBER_DEPOT))
	var routes: Variant = data.get("regional_routes", {})
	if routes is Dictionary and not (routes as Dictionary).is_empty():
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(
				ProductionUpgradeDef.Milestone.CONTINENTAL_COMPANY))
	var projects: Variant = data.get("infrastructure_projects", [])
	if projects is Array and not (projects as Array).is_empty():
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(
				ProductionUpgradeDef.Milestone.PLANETARY_INDUSTRY))
	var lines: Variant = data.get("orbital_lines", [])
	var line_count := (lines as Array).size() if lines is Array else 0
	if line_count > 0:
		var milestone := ProductionUpgradeDef.Milestone.FIRST_ALIEN_LINE
		if line_count >= 3:
			milestone = ProductionUpgradeDef.Milestone.THREE_ALIEN_LINES
		elif line_count >= 2:
			milestone = ProductionUpgradeDef.Milestone.SECOND_ALIEN_LINE
		floor_value = maxi(floor_value,
			ProductionEconomy.minimum_lifetime_for_milestone(milestone))
	return mini(floor_value, GameState.MAX_SAFE_ECONOMY_VALUE)


static func _migrate_v1_to_v2(progression: Dictionary) -> Dictionary:
	var migrated := progression.duplicate(true)

	var source: Variant = progression.get("skill_levels", {})
	if not source is Dictionary:
		migrated["skill_levels"] = {}
		migrated["legacy_skill_ranks"] = {}
		return migrated

	var retained: Dictionary = {}
	var legacy: Dictionary = {}
	for destination: String in _V1_RETAINED_SKILLS:
		var rule: Dictionary = _V1_RETAINED_SKILLS[destination]
		var best := 0
		for old_id: String in rule["sources"]:
			best = maxi(best, _valid_rank((source as Dictionary).get(old_id, 0)))
		best = mini(best, int(rule["cap"]))
		if best > 0:
			retained[destination] = best
			# This is a rank cost basis, not banked points. GameState still derives
			# the balance from earned levels minus spend; these ranks merely keep
			# paying their v1 per-rank price after later M7C retuning.
			legacy[destination] = best

	# Anything not explicitly retained is retired. In particular, Splitter is
	# NOT a source for Double Strike, and both sale-value prototype ids vanish.
	migrated["skill_levels"] = retained
	migrated["legacy_skill_ranks"] = legacy
	return migrated


static func _valid_rank(value: Variant) -> int:
	# ConfigFile preserves integers. Treat every other type as corrupt instead of
	# coercing strings/floats into ownership the player never actually had.
	return maxi(0, int(value)) if typeof(value) == TYPE_INT else 0


## Move a save this build must not load out of the way, keeping the newest few
## rather than overwriting a single backup slot.
static func _preserve_unreadable_save(tag: String) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var backup := "user://the_axeman_save.%s.%d.bak" % [tag, int(Time.get_unix_time_from_system())]
	if dir.rename(SAVE_PATH, backup) != OK:
		push_error("SaveSystem: could not preserve the unreadable save — it is still at '%s'." % SAVE_PATH)
