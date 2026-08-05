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
const SAVE_VERSION := 3

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
## save_game() replaces the old file atomically with a version-3 one.
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
	return migrated


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
