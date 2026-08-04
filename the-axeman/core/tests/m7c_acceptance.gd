extends Node
## FILE: res://core/tests/m7c_acceptance.gd
## ATTACHES TO: res://core/tests/m7c_acceptance.tscn. Not shipped.
##
## M7C SLICE 2 ONLY: version-1 skill migration. Later M7C groups are appended
## slice by slice; this scene is deliberately useful before any proc or mastery
## gameplay exists.

const _FIXTURES := "res://core/tests/fixtures/"
const _BACKUP_PATH := "user://the_axeman_save.m7c_testbackup"

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M7C ACCEPTANCE — slice 2 save-v2 migration ===")
	_stash_real_save()
	_test_all_mappings_and_exact_refunds()
	_test_duplicates_caps_and_corrupt_ranks()
	_test_partial_fixture_and_idempotence()
	_test_load_save_reload_and_source_preservation()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M7C RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M7C ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _fixture_progression(name: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(_FIXTURES + name)
	_check(err == OK, "hand-authored fixture %s parses" % name)
	var data: Variant = cfg.get_value("progression", "data", {})
	return data as Dictionary if data is Dictionary else {}


func _test_all_mappings_and_exact_refunds() -> void:
	var migrated := SaveSystem._migrate(
		_fixture_progression("m7c_v1_all_skill_mappings.cfg"), 1)
	var skills: Dictionary = migrated.get("skill_levels", {})
	var legacy: Dictionary = migrated.get("legacy_skill_ranks", {})
	_check(skills.get("strong_arms", 0) == 3, "Strong Arms retains all 3 valid ranks")
	_check(skills.get("quick_hands", 0) == 4, "Quick Hands retains all 4 valid ranks")
	_check(skills.get("ready_stance", 0) == 2 and not skills.has("keen_edge"),
		"Keen Edge renames to Ready Stance without leaving its old id")
	_check(skills.get("quick_study", 0) == 2 and not skills.has("woodsman"),
		"Woodsman renames to Quick Study without leaving its old id")
	_check(not skills.has("splitter"), "Splitter is retired, never converted to Double Strike")
	_check(not skills.has("double_strike"), "migration does not silently award Double Strike")
	_check(not skills.has("master_axeman") and not skills.has("negotiator"),
		"Master Axeman and Negotiator are both absent from version 2")
	_check(legacy == {"strong_arms": 3, "quick_hands": 4, "ready_stance": 2, "quick_study": 2},
		"retained ranks carry their exact prototype-cost basis")

	GameState.apply_save_dict(migrated)
	_check(GameState.get_skill_points_spent() == 17,
		"retained ranks spend exactly 17 prototype points")
	_check(GameState.get_skill_points_available() == 81,
		"the removed 16-point spend is refunded through the derived balance (81 available)")


func _test_duplicates_caps_and_corrupt_ranks() -> void:
	var migrated := SaveSystem._migrate(
		_fixture_progression("m7c_v1_duplicate_caps_corrupt.cfg"), 1)
	var skills: Dictionary = migrated.get("skill_levels", {})
	_check(skills.get("ready_stance", 0) == 5,
		"old/new Ready Stance ids keep the greater rank and clamp to cap 5")
	_check(skills.get("quick_study", 0) == 4,
		"old/new Quick Study ids keep the greater rank, never add to 6")
	_check(not skills.has("strong_arms"), "a non-numeric retained rank is dropped safely")
	_check(not skills.has("splitter") and not skills.has("negotiator"),
		"negative retired/corrupt ranks cannot survive migration")


func _test_partial_fixture_and_idempotence() -> void:
	var original := _fixture_progression("m7c_v1_partial.cfg")
	var migrated := SaveSystem._migrate(original, 1)
	_check(migrated.get("cash", 0) == 73, "unrelated progression survives migration unchanged")
	_check((migrated.get("skill_levels", {}) as Dictionary).get("ready_stance", 0) == 1,
		"a partial skill dictionary migrates its one known rank")
	var twice := SaveSystem._migrate(migrated.duplicate(true), 2)
	_check(twice == migrated, "a version-2 dictionary is byte-shape idempotent")
	var malformed := SaveSystem._migrate({"skill_levels": ["not", "a", "dictionary"]}, 1)
	_check(malformed.get("skill_levels", null) == {}, "a malformed skill field degrades to an empty tree")


func _test_load_save_reload_and_source_preservation() -> void:
	SaveSystem.delete_save()
	var fixture := ConfigFile.new()
	_check(fixture.load(_FIXTURES + "m7c_v1_all_skill_mappings.cfg") == OK,
		"round-trip fixture opens")
	_check(fixture.save(SaveSystem.SAVE_PATH) == OK, "version-1 fixture is installed as the live test save")

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "a version-1 file loads through migration")
	_check(GameState.get_skill_level(&"ready_stance") == 2
		and GameState.get_skill_level(&"quick_study") == 2,
		"renamed ranks are live after the complete state validates")
	var untouched := ConfigFile.new()
	untouched.load(SaveSystem.SAVE_PATH)
	_check(int(untouched.get_value("meta", "version", -1)) == 1,
		"loading leaves the original version-1 file untouched")

	_check(SaveSystem.save_game(), "the next atomic save succeeds")
	var upgraded := ConfigFile.new()
	upgraded.load(SaveSystem.SAVE_PATH)
	_check(int(upgraded.get_value("meta", "version", -1)) == 2,
		"only that successful save replaces it with version 2")
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "the version-2 save reloads")
	_check(GameState.get_skill_level(&"ready_stance") == 2
		and GameState.get_skill_level(&"quick_study") == 2,
		"renamed ranks survive load-save-reload")
	_check(GameState.get_skill_points_spent() == 17,
		"prototype cost basis survives load-save-reload exactly")


func _stash_real_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(_BACKUP_PATH):
		dir.remove(_BACKUP_PATH)
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP_PATH)


func _restore_real_save() -> void:
	SaveSystem.delete_save()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(_BACKUP_PATH):
		dir.rename(_BACKUP_PATH, SaveSystem.SAVE_PATH)
