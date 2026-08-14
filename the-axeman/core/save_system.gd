class_name SaveSystem
extends RefCounted
## Version-19 persistence. Profile, inventory and an optional suspended attempt
## remain distinct authorities. Migration is pure data conversion plus a required
## byte-for-byte source backup; it never tries to restore retired geometry.

enum LoadResult { OK, NO_FILE, CORRUPT, TOO_NEW }

const SAVE_VERSION := 19
const SAVE_PATH := "user://the_axeman_save.cfg"
const _SECTION_META := "meta"
const _SECTION_PROFILE := "profile"
const _SECTION_INVENTORY := "inventory"
const _SECTION_ATTEMPT := "attempt"

static var _loaded_attempt: Dictionary = {}
static var _loaded_from_legacy := false
static var _active_save_path := SAVE_PATH
## A legacy source may only be replaced after its exact bytes have been copied.
## This tracks the active path whose backup was verified during this process;
## direct New Profile replacement performs the same prerequisite check itself.
static var _legacy_backup_ready_path := ""
static var _force_legacy_backup_failure_for_tests := false


static func has_save() -> bool:
	if FileAccess.file_exists(_active_save_path):
		return true
	return _recover_interrupted_replacement()


static func has_suspended_attempt() -> bool:
	if not has_save():
		return false
	var cfg := ConfigFile.new()
	if cfg.load(_active_save_path) != OK:
		return false
	var attempt: Variant = cfg.get_value(_SECTION_ATTEMPT, "data", {})
	return int(cfg.get_value(_SECTION_META, "version", -1)) == SAVE_VERSION \
		and attempt is Dictionary and not (attempt as Dictionary).is_empty()


static func loaded_attempt_snapshot() -> Dictionary:
	return _loaded_attempt.duplicate(true)


static func loaded_from_legacy() -> bool:
	return _loaded_from_legacy


## Test seam. Production never calls this; tests must supply a unique user://
## filename and restore the default in teardown.
static func set_save_path_for_tests(path: String) -> bool:
	if not path.begins_with("user://") or path == "user://" \
			or path.contains("..") or path.ends_with("/"):
		return false
	_active_save_path = path
	_loaded_attempt.clear()
	_loaded_from_legacy = false
	_legacy_backup_ready_path = ""
	return true


static func reset_save_path_after_tests() -> void:
	_active_save_path = SAVE_PATH
	_loaded_attempt.clear()
	_loaded_from_legacy = false
	_legacy_backup_ready_path = ""
	_force_legacy_backup_failure_for_tests = false


static func set_force_legacy_backup_failure_for_tests(value: bool) -> void:
	_force_legacy_backup_failure_for_tests = value


static func active_save_path() -> String:
	return _active_save_path


static func save_game(attempt_snapshot: Dictionary) -> bool:
	return _write_current_save(attempt_snapshot)


## Home-only writes must not silently erase a suspended attempt.
static func save_profile_preserving_attempt() -> bool:
	var attempt := _loaded_attempt.duplicate(true)
	if attempt.is_empty() and has_save():
		var cfg := ConfigFile.new()
		if cfg.load(_active_save_path) == OK \
				and int(cfg.get_value(_SECTION_META, "version", -1)) == SAVE_VERSION:
			var raw: Variant = cfg.get_value(_SECTION_ATTEMPT, "data", {})
			if raw is Dictionary:
				attempt = (raw as Dictionary).duplicate(true)
	return _write_current_save(attempt)


static func clear_attempt_and_save() -> bool:
	return _write_current_save({})


static func load_game() -> LoadResult:
	_loaded_attempt.clear()
	_loaded_from_legacy = false
	if not has_save():
		return LoadResult.NO_FILE
	var cfg := ConfigFile.new()
	var err := cfg.load(_active_save_path)
	if err != OK:
		push_error("SaveSystem: save could not be parsed (error %d)." % err)
		return LoadResult.CORRUPT
	var version := int(cfg.get_value(_SECTION_META, "version", -1))
	if version < 0:
		return LoadResult.CORRUPT
	if version > SAVE_VERSION:
		_preserve_unreadable_save("newer")
		return LoadResult.TOO_NEW
	var content_errors := SurvivorsContent.validate_all()
	if not content_errors.is_empty():
		push_error("SaveSystem: required v19 progression content is invalid; save not applied.")
		return LoadResult.CORRUPT

	var profile: Variant
	var inventory: Variant
	if version == SAVE_VERSION:
		if not cfg.has_section_key(_SECTION_PROFILE, "data") \
				or not cfg.has_section_key(_SECTION_INVENTORY, "counts") \
				or not cfg.has_section_key(_SECTION_ATTEMPT, "data"):
			return LoadResult.CORRUPT
		profile = cfg.get_value(_SECTION_PROFILE, "data", {})
		inventory = cfg.get_value(_SECTION_INVENTORY, "counts", {})
		var attempt: Variant = cfg.get_value(_SECTION_ATTEMPT, "data", {})
		if not (profile is Dictionary) or not _is_valid_v19_profile_shape(
				profile as Dictionary) or not (inventory is Dictionary) \
				or not _is_valid_inventory_shape(inventory as Dictionary) \
				or not (attempt is Dictionary):
			return LoadResult.CORRUPT
		_loaded_attempt = (attempt as Dictionary).duplicate(true)
	elif version == 18:
		if not cfg.has_section_key(_SECTION_PROFILE, "data") \
				or not cfg.has_section_key(_SECTION_INVENTORY, "counts") \
				or not cfg.has_section_key(_SECTION_ATTEMPT, "data"):
			return LoadResult.CORRUPT
		var old_profile: Variant = cfg.get_value(_SECTION_PROFILE, "data", {})
		inventory = cfg.get_value(_SECTION_INVENTORY, "counts", {})
		var old_attempt: Variant = cfg.get_value(_SECTION_ATTEMPT, "data", {})
		if not (old_profile is Dictionary) or not (inventory is Dictionary) \
				or not (old_attempt is Dictionary) \
				or not _is_valid_inventory_shape(inventory as Dictionary) \
				or not _is_valid_legacy_source_shape(old_profile as Dictionary) \
				or not _is_valid_v18_attempt_shape(old_attempt as Dictionary):
			return LoadResult.CORRUPT
		if _preserve_legacy_save(version).is_empty():
			return LoadResult.CORRUPT
		_legacy_backup_ready_path = _active_save_path
		profile = migrate_v18_profile(old_profile as Dictionary,
			old_attempt as Dictionary)
		if (profile as Dictionary).is_empty():
			return LoadResult.CORRUPT
		_loaded_from_legacy = true
	else:
		if not cfg.has_section_key("progression", "data") \
				or not cfg.has_section_key(_SECTION_INVENTORY, "counts"):
			return LoadResult.CORRUPT
		var legacy: Variant = cfg.get_value("progression", "data", {})
		inventory = cfg.get_value(_SECTION_INVENTORY, "counts", {})
		if not (legacy is Dictionary) or not (inventory is Dictionary) \
				or not _is_valid_inventory_shape(inventory as Dictionary) \
				or not _is_valid_legacy_source_shape(legacy as Dictionary):
			return LoadResult.CORRUPT
		if _preserve_legacy_save(version).is_empty():
			return LoadResult.CORRUPT
		_legacy_backup_ready_path = _active_save_path
		profile = migrate_v17_or_earlier_profile(legacy as Dictionary, version)
		if (profile as Dictionary).is_empty():
			return LoadResult.CORRUPT
		_loaded_from_legacy = true
	if not (profile is Dictionary) or not (inventory is Dictionary):
		return LoadResult.CORRUPT
	GameState.apply_save_dict(profile as Dictionary)
	InventoryManager.apply_save_dict(inventory as Dictionary)
	GameState.set_permanent_controls_locked(not _loaded_attempt.is_empty())
	return LoadResult.OK


static func load_or_start_fresh() -> LoadResult:
	var result := load_game()
	if result == LoadResult.NO_FILE:
		GameState.reset_to_defaults()
		InventoryManager.apply_save_dict({})
	return result


static func migrate_v18_profile(profile: Dictionary, attempt: Dictionary) -> Dictionary:
	if not SurvivorsContent.validate_all().is_empty() \
			or not _is_valid_legacy_source_shape(profile) \
			or not _is_valid_v18_attempt_shape(attempt):
		return {}
	var migration := _fresh_migrated_profile(18)
	var refunds := SurvivorsContent.legacy_refunds()
	var cash := 0
	if refunds != null:
		cash = _legacy_refund_total(profile, false, refunds, 18)
	var attempt_cash := clampi(int(attempt.get("cash", 0)), 0,
		GameState.MAX_SAFE_ECONOMY_VALUE)
	cash = _safe_sum(cash, attempt_cash)
	migration["home_cash"] = cash
	_apply_capability_seeds(migration, profile.get("skill_levels", {}), refunds)
	var frequency_rank := int((migration.meta_upgrade_ranks as Dictionary).get(
		String(GameState.META_FREQUENCY_CONTROL), 0))
	migration["selected_frequency_tier"] = clampi(
		int(attempt.get("delivery_tier", 0)), 0, frequency_rank)
	_copy_legacy_common(migration, profile, 18, refunds)
	var notice := migration.migration_notice as Dictionary
	notice["attempt_cash_transferred"] = attempt_cash
	notice["attempt_discarded"] = not attempt.is_empty()
	notice["message"] = (
		"Your previous progression was refunded into Home Cash. A suspended v18 "
		+ "purse was transferred, while incompatible Earth and attempt geometry were retired.")
	return migration


static func migrate_v17_or_earlier_profile(legacy: Dictionary, version: int) -> Dictionary:
	if version < 1 or version > 17 \
			or not SurvivorsContent.validate_all().is_empty() \
			or not _is_valid_legacy_source_shape(legacy):
		return {}
	var migration := _fresh_migrated_profile(version)
	var refunds := SurvivorsContent.legacy_refunds()
	var cash := clampi(int(legacy.get("cash", 0)), 0,
		GameState.MAX_SAFE_ECONOMY_VALUE)
	if refunds != null:
		cash = _safe_sum(cash, _legacy_refund_total(
			legacy, true, refunds, version))
	migration["home_cash"] = cash
	_apply_capability_seeds(migration, legacy.get("skill_levels", {}), refunds)
	_copy_legacy_common(migration, legacy, version, refunds)
	var notice := migration.migration_notice as Dictionary
	notice["message"] = (
		"Your legacy progression was converted to Home Cash. Retired campaign and "
		+ "attempt state is preserved only in Legacy Records.")
	return migration


## Transitional alias for the v18 survival acceptance seam. It now returns the
## v19 shape and never restores permanent XP or skills.
static func _migrate_legacy_profile(value: Variant, version: int) -> Dictionary:
	return migrate_v17_or_earlier_profile(value as Dictionary, version) \
		if value is Dictionary else {}


static func _write_current_save(attempt_snapshot: Dictionary) -> bool:
	if not SurvivorsContent.validate_all().is_empty():
		push_error("SaveSystem: refusing to write with invalid progression content.")
		return false
	if not FileAccess.file_exists(_active_save_path) \
			and FileAccess.file_exists(_active_save_path + ".replacing") \
			and not _recover_interrupted_replacement():
		return false
	var temp_path := _active_save_path + ".tmp"
	var replacing_path := _active_save_path + ".replacing"
	var cfg := ConfigFile.new()
	cfg.set_value(_SECTION_META, "version", SAVE_VERSION)
	cfg.set_value(_SECTION_META, "saved_at_unix", int(Time.get_unix_time_from_system()))
	cfg.set_value(_SECTION_PROFILE, "data", GameState.to_save_dict())
	cfg.set_value(_SECTION_INVENTORY, "counts", InventoryManager.to_save_dict())
	cfg.set_value(_SECTION_ATTEMPT, "data", attempt_snapshot.duplicate(true))
	var err := cfg.save(temp_path)
	if err != OK:
		push_error("SaveSystem: could not write temporary save (error %d)." % err)
		return false
	var save_absolute := ProjectSettings.globalize_path(_active_save_path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var replacing_absolute := ProjectSettings.globalize_path(replacing_path)
	if not _prepare_existing_save_for_replacement():
		DirAccess.remove_absolute(temp_absolute)
		return false
	if FileAccess.file_exists(replacing_path):
		DirAccess.remove_absolute(replacing_absolute)
	var moved_previous := false
	if FileAccess.file_exists(_active_save_path):
		err = DirAccess.rename_absolute(save_absolute, replacing_absolute)
		if err != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_error("SaveSystem: could not protect the previous save (error %d)." % err)
			return false
		moved_previous = true
	err = DirAccess.rename_absolute(temp_absolute, save_absolute)
	if err != OK:
		push_error("SaveSystem: could not finalise the save (error %d)." % err)
		if moved_previous:
			DirAccess.rename_absolute(replacing_absolute, save_absolute)
		return false
	if moved_previous:
		DirAccess.remove_absolute(replacing_absolute)
	_loaded_attempt = attempt_snapshot.duplicate(true)
	_loaded_from_legacy = false
	_legacy_backup_ready_path = ""
	GameState.set_permanent_controls_locked(not attempt_snapshot.is_empty())
	return true


## If the process stopped after protecting the previous save but before the
## temporary v19 file was installed, prefer restoring the known-good previous
## file. The leftover `.tmp` is deliberately ignored and will be replaced by
## the next successful save.
static func _recover_interrupted_replacement() -> bool:
	var replacing_path := _active_save_path + ".replacing"
	if not FileAccess.file_exists(replacing_path):
		return false
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(replacing_path),
		ProjectSettings.globalize_path(_active_save_path))
	if err != OK:
		push_error("SaveSystem: could not restore an interrupted save replacement (error %d)." % err)
		return false
	return true


static func _prepare_existing_save_for_replacement() -> bool:
	if not FileAccess.file_exists(_active_save_path):
		return true
	var existing := ConfigFile.new()
	var err := existing.load(_active_save_path)
	if err != OK:
		push_error("SaveSystem: refusing to replace an unreadable existing save.")
		return false
	var version := int(existing.get_value(_SECTION_META, "version", -1))
	if version < 0 or version > SAVE_VERSION:
		push_error("SaveSystem: refusing to replace an unknown or newer save version.")
		return false
	if version == SAVE_VERSION or _legacy_backup_ready_path == _active_save_path:
		return true
	if _preserve_legacy_save(version).is_empty():
		return false
	_legacy_backup_ready_path = _active_save_path
	return true


static func _fresh_migrated_profile(source_version: int) -> Dictionary:
	var fresh := _fresh_profile_dict()
	fresh["legacy_records"] = {
		"source_version": source_version,
		"earth": {},
		"old_progression": {},
	}
	fresh["migration_notice"] = {
		"id": "survivors_v19_%d" % source_version,
		"source_version": source_version,
	}
	return fresh


static func _fresh_profile_dict() -> Dictionary:
	var powers: Array[String] = []
	for id: StringName in SurvivorsContent.core_power_ids():
		powers.append(String(id))
	powers.sort()
	return {
		"home_cash": 0,
		"meta_upgrade_ranks": {},
		"meta_upgrade_spend_ledger": {},
		"unlocked_run_powers": powers,
		"selected_yard": String(GameState.DEFAULT_YARD_ID),
		"selected_frequency_tier": 0,
		"applied_run_settlements": [],
		"lifetime_stats": {
			"roots_completed": 0,
			"cash_earned": 0,
			"runs_settled": 0,
			"bosses_defeated": 0,
			"haul_aways_completed": 0,
		},
		"yard_records": {},
		"yard_pile": {},
		"legacy_records": {},
		"migration_notice": {},
		"next_run_serial": 1,
	}


static func _legacy_refund_total(source: Dictionary, building_tiers_are_baseline_one: bool,
		refunds: LegacyProgressionRefundTable, source_version: int) -> int:
	var raw_skills: Variant = source.get("skill_levels", {})
	var skills: Dictionary = raw_skills as Dictionary if raw_skills is Dictionary else {}
	var saved_entitlement := clampi(int(source.get(
		"skill_points_earned_total", 0)), 0, GameState.MAX_SAFE_ECONOMY_VALUE)
	var alien_entitlement := refunds.pre_v17_alien_mastery_entitlement(
		source_version, source.get("alien_destination_states", {}))
	saved_entitlement = _safe_sum(saved_entitlement, alien_entitlement)
	## XP and spent/unspent skill entitlement describe the same progression. The
	## pinned table returns their larger conversion, never their sum.
	var total := refunds.progression_entitlement_refund(
		clampi(int(source.get("xp", 0)), 0, GameState.MAX_SAFE_ECONOMY_VALUE),
		skills, saved_entitlement, source_version)
	var upgrades: Variant = source.get("permanent_upgrades",
		source.get("building_tiers", {}))
	var baseline_one := not source.has("permanent_upgrades") \
		and building_tiers_are_baseline_one
	if upgrades is Dictionary:
		for raw_id: Variant in upgrades:
			if not (raw_id is String or raw_id is StringName) \
					or not (upgrades[raw_id] is int):
				continue
			var rank := maxi(0, int(upgrades[raw_id]) - (1 if baseline_one else 0))
			total = _safe_sum(total, refunds.upgrade_refund(StringName(raw_id), rank))
	var species: Variant = source.get("owned_species", [])
	var seen_species: Dictionary = {}
	if species is Array:
		for raw_id: Variant in species:
			if not (raw_id is String or raw_id is StringName):
				continue
			var id := StringName(raw_id)
			if id == &"" or seen_species.has(id):
				continue
			seen_species[id] = true
			total = _safe_sum(total, refunds.species_refund(id))
	elif species is Dictionary:
		for raw_id: Variant in species:
			if not (raw_id is String or raw_id is StringName) \
					or not (species[raw_id] is bool):
				continue
			var id := StringName(raw_id)
			if bool(species[raw_id]) and id != &"" and not seen_species.has(id):
				seen_species[id] = true
				total = _safe_sum(total, refunds.species_refund(id))
	return total


static func _apply_capability_seeds(profile: Dictionary, skill_value: Variant,
		refunds: LegacyProgressionRefundTable) -> void:
	if refunds == null or not (skill_value is Dictionary):
		return
	var ranks := profile.meta_upgrade_ranks as Dictionary
	var ledger := profile.meta_upgrade_spend_ledger as Dictionary
	for raw_id: Variant in skill_value:
		if not (raw_id is String or raw_id is StringName) \
				or not (skill_value[raw_id] is int):
			continue
		var source_id := StringName(raw_id)
		var source_rank := maxi(0, int(skill_value[raw_id]))
		for seed: LegacyCapabilitySeedDef in refunds.seed_for_source(source_id):
			var definition := SurvivorsContent.meta_upgrades().by_id(
				seed.target_meta_upgrade_id)
			if definition == null:
				continue
			var target_rank := clampi(seed.target_rank_for(source_rank), 0,
				definition.max_rank)
			if target_rank <= 0:
				continue
			if seed.target_meta_upgrade_id == GameState.META_CONTINUOUS_HANDOFF:
				_seed_free_rank(ranks, ledger, GameState.META_HOLD_TO_CHOP, 1)
			_seed_free_rank(ranks, ledger, seed.target_meta_upgrade_id, target_rank)


static func _seed_free_rank(ranks: Dictionary, ledger: Dictionary,
		id: StringName, rank: int) -> void:
	var previous := maxi(0, int(ranks.get(String(id), ranks.get(id, 0))))
	var wanted := maxi(previous, rank)
	ranks[String(id)] = wanted
	var paid: Array[int] = []
	var existing: Variant = ledger.get(String(id), [])
	if existing is Array:
		for value: Variant in existing:
			paid.append(maxi(0, int(value)))
	while paid.size() < wanted:
		paid.append(0)
	ledger[String(id)] = paid


static func _copy_legacy_common(profile: Dictionary, source: Dictionary,
		source_version: int, refunds: LegacyProgressionRefundTable) -> void:
	profile["yard_pile"] = (source.get("yard_pile", {}) as Dictionary).duplicate(true) \
		if source.get("yard_pile", {}) is Dictionary else {}
	var stats := profile.lifetime_stats as Dictionary
	stats["roots_completed"] = maxi(0, int(source.get("lifetime_wood_chopped",
		source.get("manual_log_equivalents", 0))))
	stats["haul_aways_completed"] = maxi(0,
		int(source.get("haul_aways_completed", 0)))
	var lifetime_cash := refunds.pre_v15_lifetime_cash_floor(source_version, source)
	stats["cash_earned"] = lifetime_cash
	var legacy := profile.legacy_records as Dictionary
	var earth_trees := refunds.pre_v15_earth_trees(source_version, source)
	legacy["earth"] = {
		"earth_cleared": _typed_bool(source.get("earth_cleared",
			source.get("earth_master", false))),
		"best_earth_clear_ms": int(source.get("best_earth_clear_ms", -1)),
		"best_total_run_ms": int(source.get("best_total_run_ms", -1)),
		"best_overflow_ms": int(source.get("best_overflow_ms", -1)),
		"earth_trees_felled": earth_trees,
	}
	legacy["old_progression"] = {
		"permanent_xp": maxi(0, int(source.get("xp", 0))),
		"lifetime_cash_earned": lifetime_cash,
		"owned_species_count": _owned_species_count(source.get("owned_species", [])),
	}


static func _owned_species_count(value: Variant) -> int:
	var seen: Dictionary = {}
	if value is Array:
		for raw_id: Variant in value:
			if not (raw_id is String or raw_id is StringName):
				continue
			var id := StringName(raw_id)
			if id != &"":
				seen[id] = true
	elif value is Dictionary:
		for raw_id: Variant in value:
			if not (raw_id is String or raw_id is StringName) \
					or not (value[raw_id] is bool):
				continue
			var id := StringName(raw_id)
			if bool(value[raw_id]) and id != &"":
				seen[id] = true
	return seen.size()


static func _safe_sum(a: int, b: int) -> int:
	a = clampi(a, 0, GameState.MAX_SAFE_ECONOMY_VALUE)
	b = clampi(b, 0, GameState.MAX_SAFE_ECONOMY_VALUE)
	return mini(GameState.MAX_SAFE_ECONOMY_VALUE,
		a + mini(b, GameState.MAX_SAFE_ECONOMY_VALUE - a))


static func _preserve_legacy_save(version: int) -> String:
	if _force_legacy_backup_failure_for_tests:
		push_error("SaveSystem: forced legacy backup failure for isolated acceptance.")
		return ""
	var source := ProjectSettings.globalize_path(_active_save_path)
	var stem := _active_save_path.trim_suffix(".cfg")
	var timestamp := int(Time.get_unix_time_from_system())
	for serial: int in range(1000):
		var suffix := "%d" % timestamp if serial == 0 else "%d.%d" % [timestamp, serial]
		var target_path := "%s.v%d.%s.backup.cfg" % [stem, version, suffix]
		if FileAccess.file_exists(target_path):
			continue
		var err := DirAccess.copy_absolute(source,
			ProjectSettings.globalize_path(target_path))
		if err == OK:
			return target_path
		push_error("SaveSystem: required legacy backup failed (error %d)." % err)
		return ""
	push_error("SaveSystem: could not choose a collision-free legacy backup name.")
	return ""


static func _is_valid_v19_profile_shape(profile: Dictionary) -> bool:
	var required_types := {
		"home_cash": TYPE_INT,
		"meta_upgrade_ranks": TYPE_DICTIONARY,
		"meta_upgrade_spend_ledger": TYPE_DICTIONARY,
		"unlocked_run_powers": TYPE_ARRAY,
		"selected_frequency_tier": TYPE_INT,
		"lifetime_stats": TYPE_DICTIONARY,
		"yard_records": TYPE_DICTIONARY,
		"yard_pile": TYPE_DICTIONARY,
		"legacy_records": TYPE_DICTIONARY,
		"migration_notice": TYPE_DICTIONARY,
		"next_run_serial": TYPE_INT,
	}
	for key: String in required_types:
		if not profile.has(key) or typeof(profile[key]) != int(required_types[key]):
			return false
	if not profile.has("selected_yard") \
			or not (profile.selected_yard is String or profile.selected_yard is StringName):
		return false
	if not profile.has("applied_run_settlements") \
			or not (profile.applied_run_settlements is Array \
				or profile.applied_run_settlements is Dictionary):
		return false
	return true


static func _is_valid_legacy_source_shape(source: Dictionary) -> bool:
	for key: String in [
		"cash", "xp", "skill_points_earned_total", "lifetime_cash_earned",
		"lifetime_wood_chopped", "manual_log_equivalents",
		"automated_log_equivalents", "haul_aways_completed",
		"earth_trees_felled", "earth_finale_state", "earth_finale_splits",
		"best_earth_clear_ms", "best_total_run_ms", "best_overflow_ms",
	]:
		if source.has(key) and not (source[key] is int):
			return false
	for key: String in ["earth_cleared", "earth_master"]:
		if source.has(key) and not (source[key] is bool):
			return false
	for key: String in [
		"skill_levels", "permanent_upgrades", "building_tiers", "yard_pile",
		"alien_destination_states", "regional_routes",
	]:
		if source.has(key) and not (source[key] is Dictionary):
			return false
	for key: String in ["infrastructure_projects", "orbital_lines"]:
		if source.has(key) and not (source[key] is Array):
			return false
	if source.has("owned_species") and not (source.owned_species is Array \
			or source.owned_species is Dictionary):
		return false
	return true


static func _is_valid_v18_attempt_shape(attempt: Dictionary) -> bool:
	for key: String in ["cash", "delivery_tier"]:
		if attempt.has(key) and not (attempt[key] is int):
			return false
	return true


static func _is_valid_inventory_shape(inventory: Dictionary) -> bool:
	for raw_id: Variant in inventory:
		if not (raw_id is String or raw_id is StringName) \
				or not (inventory[raw_id] is int) or int(inventory[raw_id]) < 0:
			return false
	return true


static func _typed_bool(value: Variant) -> bool:
	return bool(value) if value is bool else false


static func _preserve_unreadable_save(reason: String) -> void:
	var source := ProjectSettings.globalize_path(_active_save_path)
	var target_path := "%s.%s.%d.backup.cfg" % [
		_active_save_path.trim_suffix(".cfg"), reason,
		int(Time.get_unix_time_from_system()),
	]
	DirAccess.copy_absolute(source, ProjectSettings.globalize_path(target_path))
