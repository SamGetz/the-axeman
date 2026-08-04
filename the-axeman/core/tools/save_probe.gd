extends Node
## FILE: res://core/tools/save_probe.gd
## ATTACHES TO: root Node of res://core/tools/save_probe.tscn.
##
## DEV TOOL. Inspect and drive the save file from outside the game, which is the
## only way to see it at all until the M7 management UI exists.
##
##   dump              (default) print the save file's raw contents, or say there is none
##   seed              write a save with recognisable values, to prove a LOAD
##   quit              boot main.tscn and fire the window-close notification,
##                     to prove a SAVE happens on the way out
##   wipe              delete the save
##   seed_double_strike   grant Double Strike (M7C) on top of whatever save
##                     already exists, for feel-testing the real proc in real
##                     play without a ~120-log grind. TEMPORARY dev convenience,
##                     not a shipped cheat.
##
## Runs as a SCENE, not with -s: a -s script replaces the main loop and the
## autoloads are never instantiated, so GameState/InventoryManager would not
## exist. Everything this tool does goes through them.
##
## Run: godot --headless --path . --quit-after 3000 res://core/tools/save_probe.tscn -- <mode>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "dump"
	match mode:
		"dump": _dump()
		"seed": _seed()
		"quit": await _quit_cycle()
		"wipe": _wipe()
		"seed_double_strike": _seed_double_strike()
		_:
			print("save_probe: unknown mode '%s' (dump | seed | quit | wipe | seed_double_strike)" % mode)
	if mode != "quit":
		get_tree().quit()


func _dump() -> void:
	print("save path: %s" % ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	if not SaveSystem.has_save():
		print("  <no save file>")
		return
	var f := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.READ)
	print("--- contents ---")
	print(f.get_as_text())
	print("--- end ---")


func _seed() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	GameState.add_cash(555)
	EventBus.resource_gathered.emit(&"birch_firewood", 77)
	EventBus.gear_upgraded.emit(Enums.ToolType.AXE, 4)
	var ok := SaveSystem.save_game()
	print("save_probe: seeded (cash 555, lifetime 77, axe tier 4) -> saved=%s" % ok)


## Boots the REAL main scene and sends it the notification a closing window
## sends, so the save-on-quit path is exercised end to end rather than reasoned
## about. main.gd calls get_tree().quit() itself, so this returns nothing —
## check the file afterwards.
func _quit_cycle() -> void:
	# Wait a frame before parenting: the root is still setting up this probe's own
	# children during _ready, and add_child() into a busy parent fails outright —
	# which then leaves main outside the tree, so its get_tree() reads null.
	await get_tree().process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame

	# Earn AFTER main's _ready, not before: booting main.tscn loads the save (or
	# starts fresh), which would otherwise overwrite whatever was staged here and
	# make this tool "prove" a save of the wrong numbers.
	GameState.add_cash(4321)
	EventBus.resource_gathered.emit(&"oak_firewood", 12)
	print("save_probe: staged cash=%d lifetime=%d, firing the close notification..." % [
		GameState.get_cash(), GameState.get_lifetime_wood_chopped(),
	])
	# Qualified: NOTIFICATION_WM_CLOSE_REQUEST is a Node constant.
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _wipe() -> void:
	print("save_probe: deleted=%s" % SaveSystem.delete_save())


## TEMPORARY dev convenience for feel-testing M7C's Double Strike proc in the
## real game — Strong Arms costs 1 point, Double Strike 3, Steady Continuation
## 2, and points only come from levelling, so seeing it organically means
## chopping roughly 120 logs first. Loads whatever save already exists (never
## wipes progress) and grants only what is still missing.
##
## Goes through the REAL GameState.add_xp + SkillTree.buy path, exactly like
## m7c_acceptance and proc_shot — never a direct state poke — so the resulting
## save is exactly what a player could have earned, just faster.
func _seed_double_strike() -> void:
	var result := SaveSystem.load_or_start_fresh()
	print("save_probe: loaded existing save (%s) before granting Double Strike"
		% SaveSystem.LoadResult.keys()[result])

	var curve := load("res://data/level_curve.tres") as LevelCurve
	var target_xp := curve.total_xp_for_level(7)
	if GameState.get_xp() < target_xp:
		GameState.add_xp(target_xp - GameState.get_xp())
	var strong := SkillTree.buy(&"strong_arms")
	var strike := SkillTree.buy(&"double_strike")
	var steady := SkillTree.buy(&"steady_continuation")
	var ok := SaveSystem.save_game()
	print(("save_probe: Double Strike test-seeded — level %d, %d skill points left, "
		+ "strong_arms=%d double_strike=%d steady_continuation=%d (-1 = already owned/maxed) -> saved=%s")
		% [GameState.get_level(), GameState.get_skill_points_available(), strong, strike, steady, ok])
