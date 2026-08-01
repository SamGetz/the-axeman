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
##   - the ALWAYS-AVAILABLE BASIC BUYER pays the price table, refuses anything it
##     is not priced for, and settles a sale atomically in both directions
##   - the YARD HUD shows cash/pile/lifetime live off the local signals, opens the
##     shop, and carries the REAL entry flow that replaced the M key
##   - the YARD PILE is a view of GameState, survives a load that lands after the
##     scene is built, and is HAULED AWAY when it fills
##   - a piece PAYS FOR ITSELF as it lands on the pile — there is no manual selling
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
	await _test_9_autosave_on_inventory_change()
	_test_10_buyer_prices_only_what_it_wants()
	_test_11_a_sale_is_atomic()
	_test_12_sell_everything_is_one_transaction()
	await _test_13_yard_hud_is_live_and_shops()
	await _test_14_hud_carries_the_entry_flow()
	await _test_15_the_pile_is_a_view_of_stock()
	await _test_16_pieces_pay_as_they_land_and_the_load_is_hauled()

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

	EventBus.resource_gathered.emit(&"oak_firewood", 4)
	EventBus.resource_gathered.emit(&"birch_firewood", 3)
	_check(GameState.get_lifetime_wood_chopped() == 7,
		"7 pieces of wood across two species count as exactly 7 (not 2 gathers, not 1 species)")

	# Category filter, not an id list. That choice is what let the whole registry
	# be renamed *_log -> *_firewood without touching a line of the counter.
	EventBus.resource_gathered.emit(&"stone", 50)
	EventBus.resource_gathered.emit(&"ruby", 5)
	_check(GameState.get_lifetime_wood_chopped() == 7,
		"55 units of non-wood do not inflate the wood counter (still 7)")
	_check(_lifetime_events.size() == 2,
		"lifetime_wood_chopped_changed fired only for the two wood gathers")


func _test_4_lifetime_never_decreases() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	EventBus.resource_gathered.emit(&"oak_firewood", 10)
	var peak := GameState.get_lifetime_wood_chopped()
	_check(peak == 10, "lifetime reached exactly 10")

	# Selling stock is the thing most likely to be wired into this by accident.
	var sold: bool = InventoryManager.remove_items([{"item_id": &"oak_firewood", "amount": 10}])
	_check(sold, "10 oak_firewood sold out of inventory")
	_check(InventoryManager.get_count(&"oak_firewood") == 0, "...stock is now 0")
	_check(GameState.get_lifetime_wood_chopped() == peak,
		"...but lifetime wood chopped still reads 10 — selling never un-chops wood")


# ------------------------------------------------------------- save / load
func _test_5_save_round_trip() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	GameState.add_cash(1234)
	EventBus.resource_gathered.emit(&"birch_firewood", 9)
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
	_check(InventoryManager.get_count(&"birch_firewood") == 9, "birch_firewood stock restored to exactly 9")
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
	InventoryManager.apply_save_dict({"oak_firewood": 5, "unobtanium": 99})
	_check(InventoryManager.get_count(&"oak_firewood") == 5,
		"a save's valid stock loads (oak_firewood == 5)")
	_check(InventoryManager.get_count(&"unobtanium") == 0,
		"...while an id no longer in the registry is dropped, not resurrected")


# ------------------------------------------------------------------ autosave
## Drives the REAL main scene, because the autosave lives there and a test of a
## reimplementation of it would prove nothing.
##
## The load-bearing check is the one asserting NO file exists immediately after
## the batch. Without it this test passes just as well against a naive
## save-per-signal implementation, which writes the file six times for one chop.
func _test_9_autosave_on_inventory_change() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame   # main._ready: loads, then connects

	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	await get_tree().process_frame   # let that reset's own autosave flush
	SaveSystem.delete_save()

	# One finished log: six pieces deposited one at a time, all in this frame.
	for i in range(6):
		EventBus.resource_gathered.emit(&"birch_firewood", 1)

	_check(not SaveSystem.has_save(),
		"six deposits in one frame wrote NOTHING yet — the autosave is coalesced, not per-signal")

	await get_tree().process_frame   # the deferred flush lands here
	_check(SaveSystem.has_save(), "...and one save appears at the end of the frame")

	# Drop main BEFORE trashing state to reload: while it is alive, clearing the
	# inventory is itself an inventory change, so it queues an autosave that would
	# overwrite the very file this is about to read. (That is not a bug in the
	# autosave — it is why main.gd connects only AFTER its own load.)
	main.queue_free()
	await get_tree().process_frame

	# Prove the single write captured the WHOLE batch, not just the first piece.
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "...which reloads cleanly")
	_check(InventoryManager.get_count(&"birch_firewood") == 6,
		"...holding all 6 pieces of the batch, not a partial write")
	SaveSystem.delete_save()


# --------------------------------------------------------------- basic buyer
## Prices themselves are Sam's tuning call and WILL change, so nothing here
## asserts a literal price. Each check asserts the price is positive and that the
## payout is exactly price x count — a relationship that survives any retune but
## still fails on a buyer that pays a flat rate, double-pays, or pays nothing.
func _test_10_buyer_prices_only_what_it_wants() -> void:
	var oak := Market.get_price(&"oak_firewood")
	_check(oak > 0, "the basic buyer pays a positive price for oak_firewood (%d)" % oak)
	_check(Market.is_sellable(&"birch_firewood"), "...and buys birch_firewood too")

	# The load-bearing one: an item with no entry in the price table must read as
	# UNSELLABLE, not as free. A buyer that returns 0 and sells anyway would mint
	# stock into nothing.
	_check(Market.get_price(&"stone") == 0,
		"an item the table does not price reads as 0, not as a free sale")
	_check(not Market.is_sellable(&"stone"), "...and is refused by is_sellable()")
	_check(Market.get_price(&"unobtanium") == 0, "an unregistered id prices at 0")

	InventoryManager.apply_save_dict({})
	_check(Market.get_stock_value() == 0, "an empty yard is worth exactly 0")
	InventoryManager.add_item(&"oak_firewood", 5)
	_check(Market.get_stock_value() == oak * 5,
		"5 oak in stock is worth exactly 5 x %d" % oak)


func _test_11_a_sale_is_atomic() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	InventoryManager.add_item(&"oak_firewood", 4)
	var oak := Market.get_price(&"oak_firewood")

	_check(Market.sell(&"oak_firewood", 5) == 0,
		"selling 5 out of a stock of 4 earns nothing rather than overselling")
	_check(InventoryManager.get_count(&"oak_firewood") == 4,
		"...and the refused sale consumed NOTHING (still exactly 4 in stock)")
	_check(GameState.get_cash() == 0, "...and paid nothing (still 0 cash)")

	var earned := Market.sell(&"oak_firewood", 4)
	_check(earned == oak * 4, "selling all 4 earns exactly 4 x %d = %d" % [oak, oak * 4])
	_check(GameState.get_cash() == oak * 4, "...and the purse holds exactly that")
	_check(InventoryManager.get_count(&"oak_firewood") == 0, "...and the stock is gone")

	# Selling is not chopping. This runs through Market rather than the raw
	# remove_items of test 4, because that is the path the game will actually use.
	_check(GameState.get_lifetime_wood_chopped() == 0,
		"a sale never touches the lifetime chopped counter")

	InventoryManager.add_item(&"stone", 10)
	_check(Market.sell(&"stone", 10) == 0, "an unpriced item cannot be sold")
	_check(InventoryManager.get_count(&"stone") == 10, "...and none of it left the yard")

	# The mixed basket is where an unpriced line actually costs the player: the
	# priced half makes the payout positive, so only the per-line price check
	# stops the stone being handed over for nothing.
	InventoryManager.add_item(&"oak_firewood", 3)
	var mixed: Array = [
		{"item_id": &"oak_firewood", "amount": 3},
		{"item_id": &"stone", "amount": 10},
	]
	_check(Market.sell_batch(mixed) == 0,
		"a basket with one unsellable line is refused WHOLE, not part-sold")
	_check(InventoryManager.get_count(&"oak_firewood") == 3
			and InventoryManager.get_count(&"stone") == 10,
		"...and neither line left the yard")


func _test_12_sell_everything_is_one_transaction() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	InventoryManager.add_item(&"oak_firewood", 3)
	InventoryManager.add_item(&"birch_firewood", 2)
	InventoryManager.add_item(&"stone", 7)   # priced by nobody — must be left alone

	var expected := Market.get_price(&"oak_firewood") * 3 + Market.get_price(&"birch_firewood") * 2
	_check(expected > 0, "the two-species basket is worth a positive %d" % expected)
	_check(Market.get_stock_value() == expected,
		"stock value ignores the unsellable stone (%d)" % expected)

	var rows := Market.get_sellable_stock()
	_check(rows.size() == 2, "the sellable stock lists exactly the 2 priced species, not the stone")

	_check(Market.sell_everything() == expected, "selling everything earns exactly %d" % expected)
	_check(GameState.get_cash() == expected, "...and the purse agrees")
	_check(InventoryManager.get_count(&"oak_firewood") == 0
			and InventoryManager.get_count(&"birch_firewood") == 0,
		"...both species are sold out")
	_check(InventoryManager.get_count(&"stone") == 7,
		"...and the 7 stone the buyer does not want is still there")
	_check(Market.sell_everything() == 0, "selling an empty yard again earns 0 and is harmless")


# -------------------------------------------------------------------- the HUD
## Drives the REAL yard_hud.tscn. A reimplementation of it here would prove
## nothing about the scene the player actually sees.
func _test_13_yard_hud_is_live_and_shops() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame

	var cash_label: Label = hud.get_node("TopBar/CashRow/CashLabel")
	var cash_icon: TextureRect = hud.get_node("TopBar/CashRow/CashIcon")
	var shop_button: Button = hud.get_node("YardPanel/Column/ShopButton")
	var shop_panel: PanelContainer = hud.get_node("ShopPanel")

	_check(cash_label.text == "0", "a fresh yard reads 0 cash")

	# Cash is the only number on screen; the pile count and the lifetime total are
	# background stats now, still counted and still saved but never shown.
	_check(hud.get_node_or_null("TopBar/PileLabel") == null
			and hud.get_node_or_null("TopBar/LifetimeLabel") == null,
		"the yard-pile and lifetime readouts are GONE from the HUD")

	# There is nothing to sell by hand any more: the yard buys a piece as it lands.
	_check(hud.get_node_or_null("YardPanel/Column/StockList") == null
			and hud.get_node_or_null("YardPanel/Column/SellAllButton") == null,
		"the manual sell rows and 'Sell all' are GONE from the yard panel")

	# A finished log the way the mini-game reports it: the A7 gather, the sale, and
	# the piece landing on the pile.
	var birch := Market.get_price(&"birch_firewood")
	for i in range(6):
		EventBus.resource_gathered.emit(&"birch_firewood", 1)
		Market.sell(&"birch_firewood", 1)
		GameState.add_to_yard_pile(&"birch_firewood", 1)

	_check(GameState.get_cash() == birch * 6,
		"six birch pieces paid out %d as they landed" % (birch * 6))
	_check(cash_label.text == str(birch * 6),
		"...the cash label repainted off cash_changed: '%s'" % cash_label.text)
	_check(GameState.get_yard_pile_count() == 6 and GameState.get_lifetime_wood_chopped() == 6,
		"...and both hidden stats still counted all 6 behind the scenes")
	_check(InventoryManager.get_count(&"birch_firewood") == 0,
		"...leaving no stock to manage — the wood was bought, not stored")

	# Sam's coin, on the door of the shop.
	_check(shop_button.icon != null and shop_button.icon.resource_path.ends_with("coin.png"),
		"the shop button wears the coin icon (%s)" % ("none" if shop_button.icon == null else shop_button.icon.resource_path))
	_check(cash_icon.texture != null, "...and the cash readout has a coin beside it")
	_check(not shop_panel.visible, "the shop starts closed")
	shop_button.pressed.emit()
	_check(shop_panel.visible, "...the coin button opens it")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()
	_check(not shop_panel.visible, "...and Close shuts it again")

	hud.queue_free()
	await get_tree().process_frame


## The M key is gone; these two buttons are the only way in and out now, so they
## are worth a check that fails loudly if either comes unwired.
func _test_14_hud_carries_the_entry_flow() -> void:
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame

	var yard_panel: PanelContainer = hud.get_node("YardPanel")
	var chop: Button = hud.get_node("YardPanel/Column/ChopButton")
	var back: Button = hud.get_node("BackButton")

	_check(yard_panel.visible and not back.visible,
		"the game opens in the yard: the panel is up, the back button is not")

	var entered: Array[int] = []
	var exited := [0]
	var on_enter := func(b: Enums.Biome) -> void: entered.append(int(b))
	var on_exit := func() -> void: exited[0] += 1
	EventBus.minigame_entered.connect(on_enter)
	EventBus.minigame_exited.connect(on_exit)

	chop.pressed.emit()
	_check(entered.size() == 1 and entered[0] == Enums.Biome.PINE_FOREST,
		"'Go chopping' emits minigame_entered once — the same A7 path the M key used")
	_check(not yard_panel.visible and back.visible,
		"...and the HUD swapped to chopping mode off the SIGNAL, not off the click")

	back.pressed.emit()
	_check(exited[0] == 1, "'Back to the yard' emits minigame_exited once")
	_check(yard_panel.visible and not back.visible, "...and the yard panel is back up")

	EventBus.minigame_entered.disconnect(on_enter)
	EventBus.minigame_exited.disconnect(on_exit)
	hud.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------- the stockpile
## The yard's visible woodpile is a VIEW of GameState's yard pile, so it survives
## a reload — including the one that matters, where the save lands AFTER this
## scene has already built itself empty.
##
## Every check here counts pieces AND looks at where they are. A pile check that
## only counted would pass just as well on a build that dropped every piece at the
## origin inside the stump — this project has shipped that exact kind of empty
## guard before.
func _test_15_the_pile_is_a_view_of_stock() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var pile: Node3D = game.get_node("Pile")
	_check(pile.get_child_count() == 0, "an empty yard shows an empty pile")

	# A save landing on a scene that is already running — the real boot order, since
	# a child's _ready runs before its parent's and main.gd loads the save in its.
	GameState.apply_save_dict({"cash": 40, "yard_pile": {"oak_firewood": 5, "birch_firewood": 3}})
	await get_tree().process_frame
	_check(GameState.get_yard_pile_count() == 8, "the save restored a yard pile of 8")
	_check(pile.get_child_count() == 8,
		"...and the scene rebuilt it as exactly 8 stacked pieces (got %d)" % pile.get_child_count())

	# ...and they are actually stacked somewhere, in two different woods.
	var positions: Array[Vector3] = []
	var meshes := {}
	var highest := 0.0
	for c in pile.get_children():
		var m: MeshInstance3D = c
		positions.append(m.position)
		meshes[m.mesh] = true
		highest = maxf(highest, m.position.y)
	var distinct := 0
	for i in range(positions.size()):
		var unique := true
		for j in range(i):
			if positions[i].distance_to(positions[j]) < 0.001:
				unique = false
		if unique:
			distinct += 1
	_check(distinct == 8, "...each piece sits in its own slot (%d distinct positions)" % distinct)
	_check(highest > 0.0, "...and the pile stacks upward (top piece at y=%.3f)" % highest)
	_check(meshes.size() >= 2,
		"...built from more than one billet mesh, so two woods are not one repeated block")

	# The pile is NOT inventory: owning firewood puts nothing on it, because by the
	# time a piece is stacked the yard has already bought it.
	InventoryManager.apply_save_dict({"oak_firewood": 20})
	await get_tree().process_frame
	_check(pile.get_child_count() == 8,
		"20 pieces of stock add nothing to the pile — it shows work done, not property")

	game.queue_free()
	await get_tree().process_frame
	InventoryManager.apply_save_dict({})


## The loop Sam asked for, end to end on the real scene: chop a log down, watch
## each piece pay for itself as it lands, and watch the full load leave the yard.
##
## The pile's fly-in runs on a REAL-TIME clock, so the timings are turned right
## down here rather than waited out — a headless frame loop outruns a real-time
## animation, which is exactly why pile_smoke has to run non-headless.
func _test_16_pieces_pay_as_they_land_and_the_load_is_hauled() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0        # oak, so the payout is a known price
	game.pile_fly_ms = 20.0
	game.pile_stagger_ms = 10.0
	game.firewood_settle_timeout = 0.2
	game.max_pile_pieces = 3             # a load small enough to fill in one log
	game.haul_ms = 20.0
	game.haul_stagger_ms = 10.0
	add_child(game)
	await get_tree().process_frame

	var pile: Node3D = game.get_node("Pile")
	var safety := 0
	while game.cuttable_count() > 0 and safety < 60:
		game.debug_slice_world(Plane(Vector3.RIGHT if safety % 2 == 0 else Vector3.BACK, 0.0))
		safety += 1
		await get_tree().process_frame
	var pieces: int = game.piece_count()
	_check(pieces > 0, "the log chopped down into %d pieces of firewood" % pieces)

	await _wait(1.2)   # settle timeout, then the whole (shortened) fly-in

	var oak := Market.get_price(&"oak_firewood")
	_check(GameState.get_cash() == oak * pieces,
		"every piece paid %d as it landed — %d pieces, %d cash" % [oak, pieces, GameState.get_cash()])
	_check(InventoryManager.get_count(&"oak_firewood") == 0,
		"...and none of it is left in stock: the yard bought it, the player never sold it")
	_check(GameState.get_lifetime_wood_chopped() == pieces,
		"...while lifetime chopped counts all %d" % pieces)

	# The load filled the yard, so it was hauled off.
	_check(pieces >= 3, "the load reached the %d-piece haul threshold" % 3)
	_check(GameState.get_yard_pile_count() == 0,
		"...so the yard pile emptied (got %d)" % GameState.get_yard_pile_count())
	await _wait(1.0)
	_check(pile.get_child_count() == 0,
		"...and the pieces are gone from the pile, hauled off screen (got %d)" % pile.get_child_count())
	_check(GameState.get_cash() == oak * pieces,
		"...and hauling paid nothing extra — the wood was already bought (%d)" % GameState.get_cash())

	game.queue_free()
	await get_tree().process_frame
	InventoryManager.apply_save_dict({})


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


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
