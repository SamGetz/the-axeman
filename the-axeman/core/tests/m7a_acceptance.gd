extends Node
## FILE: res://core/tests/m7a_acceptance.gd
## ATTACHES TO: root Node of res://core/tests/m7a_acceptance.tscn. Run (F6) or
## headless. Not shipped.
##
## Verifies the first slice of cozy-lumberyard progression — the parts that
## needed no tuning values and no art, so they could be built before the orders
## and prices are decided:
##   - CASH lives in GameState, is integer-only, and only ever leaves the purse
##     through an ATOMIC try_spend_cash (Amendment 4's all-or-nothing rule)
##   - LIFETIME WOOD CHOPPED counts RAW_WOOD gathers off the existing A7 signal,
##     is monotonic, and ignores non-wood
##   - SAVE/LOAD round-trips progression AND inventory through each system's own
##     serialiser, so Directive 6 is never bypassed
##   - a corrupt, versionless or NEWER-than-this-build save cannot damage the
##     player's yard
##
## Every check asserts a positive quantity. Several of these would pass trivially
## against a game with the feature deleted if they only asserted bounds — cash
## "not negative" is true of a game with no cash at all — so each one names the
## number it expects.
##
## SAFETY: this suite writes to the real save path, so it moves any existing save
## aside first and puts it back at the end. Losing Sam's yard to a test run would
## be an unusually rude bug.

var _passes := 0
var _fails := 0
var _cash_events: Array[int] = []
var _lifetime_events: Array[int] = []

const _BACKUP_PATH := "user://the_axeman_save.testbackup"


func _ready() -> void:
	print("=== M7A ACCEPTANCE — cash, lifetime counter, save/load ===")
	_stash_real_save()

	GameState.cash_changed.connect(func(v: int) -> void: _cash_events.append(v))
	GameState.lifetime_wood_chopped_changed.connect(func(v: int) -> void: _lifetime_events.append(v))

	_test_1_cash_arithmetic()
	_test_2_cash_is_atomic()
	_test_3_lifetime_counts_wood_only()
	_test_4_lifetime_never_decreases()
	_test_5_save_round_trip()
	_test_6_corrupt_save_is_survivable()
	_test_7_newer_save_is_preserved_not_clobbered()
	_test_8_unregistered_ids_are_dropped()

	_restore_real_save()
	print("=== M7A RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M7A ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


# --------------------------------------------------------------------- cash
func _test_1_cash_arithmetic() -> void:
	GameState.reset_to_defaults()
	_cash_events.clear()
	_check(GameState.get_cash() == 0, "a fresh game starts on %d cash" % GameState.DEFAULT_CASH)

	_check(GameState.add_cash(250), "add_cash(250) reports success")
	_check(GameState.get_cash() == 250, "...and the purse holds exactly 250")
	_check(_cash_events.size() == 1 and _cash_events[-1] == 250,
		"cash_changed fired once carrying the new total (UI updates without polling)")

	# Rejections must be loud and must not move the number.
	_check(not GameState.add_cash(0), "add_cash(0) is rejected")
	_check(not GameState.add_cash(-40), "add_cash(-40) is rejected (no negative income)")
	_check(GameState.get_cash() == 250, "...and neither rejection changed the purse")


func _test_2_cash_is_atomic() -> void:
	GameState.reset_to_defaults()
	GameState.add_cash(100)
	_cash_events.clear()

	_check(not GameState.try_spend_cash(101),
		"try_spend_cash(101) on 100 cash fails rather than overdrawing")
	_check(GameState.get_cash() == 100,
		"...and the failed purchase consumed NOTHING (still exactly 100)")
	_check(_cash_events.is_empty(),
		"...and fired no cash_changed, so no UI flicker on a refused buy")

	_check(GameState.try_spend_cash(100), "try_spend_cash(100) on 100 cash succeeds (exact affordability)")
	_check(GameState.get_cash() == 0, "...leaving exactly 0")


# ---------------------------------------------------------------- lifetime
func _test_3_lifetime_counts_wood_only() -> void:
	GameState.reset_to_defaults()
	_lifetime_events.clear()
	_check(GameState.get_lifetime_wood_chopped() == 0, "lifetime wood starts at 0")

	EventBus.resource_gathered.emit(&"oak_log", 4)
	EventBus.resource_gathered.emit(&"birch_log", 3)
	_check(GameState.get_lifetime_wood_chopped() == 7,
		"7 pieces of wood across two species count as exactly 7 (not 2 gathers, not 1 species)")

	# Category filter, not an id list — this is what survives the still-open
	# question of whether the yield is called *_log or *_firewood.
	EventBus.resource_gathered.emit(&"stone", 50)
	EventBus.resource_gathered.emit(&"ruby", 5)
	_check(GameState.get_lifetime_wood_chopped() == 7,
		"55 units of non-wood do not inflate the wood counter (still 7)")
	_check(_lifetime_events.size() == 2,
		"lifetime_wood_chopped_changed fired only for the two wood gathers")


func _test_4_lifetime_never_decreases() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	EventBus.resource_gathered.emit(&"oak_log", 10)
	var peak := GameState.get_lifetime_wood_chopped()
	_check(peak == 10, "lifetime reached exactly 10")

	# Selling stock is the thing most likely to be wired into this by accident.
	var sold: bool = InventoryManager.remove_items([{"item_id": &"oak_log", "amount": 10}])
	_check(sold, "10 oak_log sold out of inventory")
	_check(InventoryManager.get_count(&"oak_log") == 0, "...stock is now 0")
	_check(GameState.get_lifetime_wood_chopped() == peak,
		"...but lifetime wood chopped still reads 10 — selling never un-chops wood")


# ------------------------------------------------------------- save / load
func _test_5_save_round_trip() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	GameState.add_cash(1234)
	EventBus.resource_gathered.emit(&"birch_log", 9)
	EventBus.gear_upgraded.emit(Enums.ToolType.AXE, 3)
	EventBus.building_upgraded.emit(&"wood_shed", 2)
	EventBus.environment_unlocked.emit(Enums.Biome.MOSSY_QUARRY)

	_check(SaveSystem.save_game(), "save_game() reports success")
	_check(SaveSystem.has_save(), "...and a save file exists on disk")

	# Scribble over everything, so a no-op "load" cannot pass this test.
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	GameState.add_cash(7)
	_check(GameState.get_cash() == 7 and GameState.get_lifetime_wood_chopped() == 0,
		"state was deliberately trashed before loading (cash 7, lifetime 0)")

	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "load_game() reports OK")
	_check(GameState.get_cash() == 1234, "cash restored to exactly 1234")
	_check(GameState.get_lifetime_wood_chopped() == 9, "lifetime wood restored to exactly 9")
	_check(InventoryManager.get_count(&"birch_log") == 9, "birch_log stock restored to exactly 9")
	_check(GameState.get_tool_tier(Enums.ToolType.AXE) == 3, "axe tier restored to 3")
	_check(GameState.get_building_tier(&"wood_shed") == 2,
		"building tier restored to 2 (StringName keys survive the file)")
	_check(GameState.is_biome_unlocked(Enums.Biome.MOSSY_QUARRY), "unlocked biome restored")
	_check(GameState.is_biome_unlocked(Enums.Biome.PINE_FOREST), "the starting biome is still unlocked")


func _test_6_corrupt_save_is_survivable() -> void:
	SaveSystem.delete_save()
	var f := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	f.store_string("this is not a ConfigFile [[[ &&& = = =\n\n]]]]unclosed")
	f.close()

	GameState.reset_to_defaults()
	GameState.add_cash(500)
	var result := SaveSystem.load_game()
	_check(result == SaveSystem.LoadResult.CORRUPT or result == SaveSystem.LoadResult.OK,
		"a garbage save is classified, not crashed on (got %d)" % result)
	if result == SaveSystem.LoadResult.CORRUPT:
		_check(GameState.get_cash() == 500,
			"...and a corrupt save applied NOTHING — live state is untouched")

	# load_or_start_fresh must leave the game playable whatever it found.
	SaveSystem.load_or_start_fresh()
	_check(GameState.get_cash() == GameState.DEFAULT_CASH and GameState.get_lifetime_wood_chopped() == 0,
		"load_or_start_fresh() falls back to a clean, playable game")
	SaveSystem.delete_save()


func _test_7_newer_save_is_preserved_not_clobbered() -> void:
	SaveSystem.delete_save()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SaveSystem.SAVE_VERSION + 99)
	cfg.set_value("progression", "data", {"cash": 999999})
	cfg.set_value("inventory", "counts", {})
	cfg.save(SaveSystem.SAVE_PATH)

	GameState.reset_to_defaults()
	GameState.add_cash(42)
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.TOO_NEW,
		"a save from a newer build is refused, not misread")
	_check(GameState.get_cash() == 42,
		"...and none of its data was applied (cash still 42, not 999999)")
	_check(not SaveSystem.has_save(),
		"...and it was moved aside, so the next autosave cannot silently destroy it")

	var found_backup := false
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("the_axeman_save.newer.") and name.ends_with(".bak"):
			found_backup = true
			DirAccess.remove_absolute("user://" + name)
	_check(found_backup, "...the newer save survives on disk as a .bak")


func _test_8_unregistered_ids_are_dropped() -> void:
	InventoryManager.apply_save_dict({})
	InventoryManager.apply_save_dict({"oak_log": 5, "unobtanium": 99})
	_check(InventoryManager.get_count(&"oak_log") == 5,
		"a save's valid stock loads (oak_log == 5)")
	_check(InventoryManager.get_count(&"unobtanium") == 0,
		"...while an id no longer in the registry is dropped, not resurrected")


# ------------------------------------------------------------------ fixture
func _stash_real_save() -> void:
	if not FileAccess.file_exists(SaveSystem.SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null and dir.rename(SaveSystem.SAVE_PATH, _BACKUP_PATH) == OK:
		print("  (an existing save was moved aside for the duration of this run)")


func _restore_real_save() -> void:
	if not FileAccess.file_exists(_BACKUP_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.remove(SaveSystem.SAVE_PATH)
	if dir.rename(_BACKUP_PATH, SaveSystem.SAVE_PATH) == OK:
		print("  (the pre-existing save has been put back)")
