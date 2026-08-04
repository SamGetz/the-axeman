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
##   - the CHOPPING HUD shows cash live and keeps contracts, wood, skills and shop
##     in compact icon buttons over the only production view
##   - panel Back buttons and outside clicks dismiss to chopping without emitting
##     a mode change or allowing a click through to the axe
##   - the haul-away has no progress UI; the physical pile is its own cue
##   - the YARD PILE is a view of GameState, survives a load that lands after the
##     scene is built, and is HAULED AWAY when it fills
##   - a piece PAYS FOR ITSELF as it lands on the pile — there is no manual selling
##   - the 25-WOOD LADDER is monotonic in price, difficulty, hardness and unlock
##     cost, so a wood cannot ship as the most valuable AND the easiest
##   - a WOOD IS EARNED BY CHOPPING, derived from lifetime chopped rather than
##     stored, and cannot be un-earned by selling the stock back
##   - the PLAYER PICKS the wood, an unearned one is refused, and the choice
##     survives a save and reaches the actual block
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
	await _test_14_hud_panels_dismiss_to_chopping()
	await _test_15_the_pile_is_a_view_of_stock()
	await _test_16_pieces_pay_as_they_land_and_the_load_is_hauled()
	await _test_17_a_swing_can_fail_and_scars_the_log()
	_test_18_tougher_wood_pays_better()
	_test_21_experience_makes_levels()
	_test_22_the_skill_tree_spends_levels()
	await _test_23_skills_change_the_game()
	_test_24_woods_are_level_gated_purchases()
	_test_25_progression_survives_a_save()
	await _test_26_the_block_holds_the_chosen_wood()
	await _test_27_a_finished_log_pays_experience()
	_test_28_orders_route_pay_and_persist()
	await _test_29_the_approved_catalogue_is_gated_and_physical()

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
	GameState.record_haul_away()

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
	_check(GameState.get_haul_aways_completed() == 1,
		"the physical haul-away milestone restored exactly once")
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
## It also proves a purchase persists without waiting for another inventory move.
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

	# A woodshed purchase does not move inventory. Seed its authored level and
	# price, let that setup autosave flush, delete it, then prove the purchase
	# creates a fresh save of its own.
	var species := GameState.get_next_unowned_species()
	var curve: LevelCurve = load("res://data/level_curve.tres")
	GameState.add_xp(curve.total_xp_for_level(species.unlock_level))
	EventBus.building_upgraded.emit(GameState.UPGRADE_SUPPLIER_LEDGER, 2)
	var cost := species.unlock_cost
	GameState.add_cash(cost + 7)
	await get_tree().process_frame
	SaveSystem.delete_save()
	_check(GameState.try_buy_species(species.id), "a progression-only woodshed purchase succeeds")
	_check(not SaveSystem.has_save(),
		"...and is coalesced instead of writing inside the transaction")
	await get_tree().process_frame
	_check(SaveSystem.has_save(), "...then autosaves without another chop or inventory change")

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
	_check(GameState.owns_species(species.id) and GameState.get_cash() == 7,
		"...and restores the purchased wood plus its post-purchase cash")
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
	var xp_bar: Control = hud.get_node("XPBar")
	var xp_progress: ProgressBar = hud.get_node("XPBar/Progress")
	var quick_menu: HBoxContainer = hud.get_node("QuickMenu")
	var shop_button: Button = hud.get_node("QuickMenu/ShopButton")
	var shop_panel: PanelContainer = hud.get_node("ShopPanel")
	var backdrop: ColorRect = hud.get_node("ModalBackdrop")
	var orders_button: Button = hud.get_node("QuickMenu/OrdersButton")
	var orders_panel: PanelContainer = hud.get_node("OrdersPanel")
	var orders_list: VBoxContainer = hud.get_node("OrdersPanel/Column/Scroll/List")

	_check(cash_label.text == "0", "a fresh chopping session reads 0 cash")
	_check(is_equal_approx(xp_bar.position.x, 0.0)
			and is_equal_approx(xp_bar.size.x, hud.size.x)
			and is_equal_approx(xp_bar.size.y, 24.0),
		"the XP bar is a full-width 1280x24 top strip (%dx%d)" % [
			int(xp_bar.size.x), int(xp_bar.size.y)])
	var xp_fill := xp_progress.get_theme_stylebox("fill") as StyleBoxFlat
	_check(xp_fill != null and xp_fill.bg_color == XPOrb.COLOR,
		"the XP fill uses the orb's exact reward colour (%s)" % XPOrb.COLOR)
	_check(quick_menu.visible and quick_menu.get_child_count() == 4,
		"contracts, wood, skills and shop are always available in one bottom-right dock")
	var square_icons := true
	for child in quick_menu.get_children():
		var button := child as Button
		square_icons = square_icons and button != null \
			and button.custom_minimum_size.x == button.custom_minimum_size.y \
			and button.custom_minimum_size.x > 0.0 and button.text.is_empty() \
			and button.icon != null
	_check(square_icons, "all four dock actions are compact square icon buttons")

	# Cash is the only number on screen; the pile count and the lifetime total are
	# background stats now, still counted and still saved but never shown.
	_check(hud.get_node_or_null("TopBar/PileLabel") == null
			and hud.get_node_or_null("TopBar/LifetimeLabel") == null,
		"the yard-pile and lifetime readouts remain absent from the HUD")
	_check(hud.get_node_or_null("PileProgress") == null,
		"the next-haul progress bar is GONE — the pile and animation are the cue")

	# There is nothing to sell by hand any more: the yard buys a piece as it lands.
	_check(hud.find_child("StockList", true, false) == null
			and hud.find_child("SellAllButton", true, false) == null,
		"the manual sell rows and 'Sell all' remain absent")

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
	_check(not shop_panel.visible and not backdrop.visible, "the shop starts closed over the live chopping view")
	shop_button.pressed.emit()
	_check(shop_panel.visible and backdrop.visible, "...the coin button opens it with an outside-click catcher")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()
	_check(not shop_panel.visible and not backdrop.visible, "...and Back returns straight to chopping")

	_check(not orders_panel.visible, "the contract board starts closed")
	orders_button.pressed.emit()
	_check(orders_panel.visible, "...and its square icon opens it")
	_check(orders_list.get_child_count() == Orders.visible().size()
			and Orders.visible().size() < Orders.all().size(),
		"...with the available order and one nearby tease, while distant work stays hidden (%d / %d)"
			% [orders_list.get_child_count(), Orders.all().size()])
	_check(orders_panel.get_theme_stylebox("panel") is StyleBoxFlat,
		"...using a replaceable basic-material board treatment while final art is pending")
	hud.get_node("OrdersPanel/Column/CloseButton").pressed.emit()
	_check(not orders_panel.visible, "...and Back puts the board away")

	hud.queue_free()
	await get_tree().process_frame


## Management is an overlay, not another mode. Both dismissal paths must close
## the panel without sending the chopping world away.
func _test_14_hud_panels_dismiss_to_chopping() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame

	var backdrop: ColorRect = hud.get_node("ModalBackdrop")
	var skill_panel: PanelContainer = hud.get_node("SkillPanel")
	var wood_panel: PanelContainer = hud.get_node("WoodPanel")
	var skills: Button = hud.get_node("QuickMenu/SkillsButton")
	var wood: Button = hud.get_node("QuickMenu/WoodButton")

	_check(hud.get_node_or_null("YardPanel") == null
			and hud.get_node_or_null("BackButton") == null
			and hud.find_child("ChopButton", true, false) == null,
		"the separate yard screen and its Go/Back navigation are GONE")
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP,
		"the outside-click catcher consumes dismissal clicks before they reach the axe")

	var entered: Array[int] = []
	var exited := [0]
	var on_enter := func(b: Enums.Biome) -> void: entered.append(int(b))
	var on_exit := func() -> void: exited[0] += 1
	EventBus.minigame_entered.connect(on_enter)
	EventBus.minigame_exited.connect(on_exit)

	skills.pressed.emit()
	_check(skill_panel.visible and backdrop.visible, "the skills icon opens its panel over chopping")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	backdrop.gui_input.emit(outside_click)
	_check(not skill_panel.visible and not backdrop.visible,
		"clicking outside the panel dismisses it straight back to chopping")

	wood.pressed.emit()
	_check(wood_panel.visible and backdrop.visible, "the wood icon opens its panel over chopping")
	hud.get_node("WoodPanel/Column/CloseWoodButton").pressed.emit()
	_check(not wood_panel.visible and not backdrop.visible,
		"the panel's Back button dismisses it straight back to chopping")
	_check(entered.is_empty() and exited[0] == 0,
		"opening and closing management never emits a 2D/3D mode change")

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
	_check(game.max_pile_pieces == GameState.get_yard_pile_capacity(),
		"the production pile and HUD inherit one %d-piece capacity" % GameState.get_yard_pile_capacity())
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

	# The wood is forced so the payout is a known price, and the price is READ
	# FROM THE TABLE rather than spelled out — this test used to say "species 0 is
	# oak", which stopped being true when Sam's 25 woods reordered the ladder by
	# hardness on 2026-08-02.
	var wood := SpeciesTable.at(0)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0
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

	var unit := Market.get_price(wood.yield_item)
	_check(unit > 0, "%s has a price to pay out (%d)" % [wood.id, unit])
	_check(GameState.get_cash() == unit * pieces,
		"every piece paid %d as it landed — %d pieces, %d cash" % [unit, pieces, GameState.get_cash()])
	_check(InventoryManager.get_count(wood.yield_item) == 0,
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
	_check(GameState.get_cash() == unit * pieces,
		"...and hauling paid nothing extra — the wood was already bought (%d)" % GameState.get_cash())

	game.queue_free()
	await get_tree().process_frame
	InventoryManager.apply_save_dict({})


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


# --------------------------------------------------- splitting is not a given
## A swing is a ROLL now, not a guarantee: it either cleaves the wood or bites and
## leaves a scar, and every scar makes the next swing into that piece more likely
## (Creative Director call, 2026-08-01). Every check here forces the outcome
## through `debug_split_roll`, so the suite tests the mechanic and never the RNG.
func _test_17_a_swing_can_fail_and_scars_the_log() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	# The TOP of the ladder — the dearest wood and the most stubborn — so the scar
	# mechanic is exercised where it matters most. Read as "the last rung" rather
	# than as a literal index: this said `2 # birch` until Sam's 25 woods landed on
	# 2026-08-02, at which point index 2 was Norway Spruce and the test was
	# quietly measuring the wrong end of the ladder while still passing.
	var toughest := SpeciesTable.count() - 1

	# Exercise the REAL click/contact path once. A failed roll must branch away
	# from the successful follow-through into the authored bounce animation on the
	# same contact beat that leaves the scar.
	var bounce_game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	bounce_game.debug_forced_species = toughest
	bounce_game.debug_split_roll = 0
	add_child(bounce_game)
	await _wait(0.6)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var axe: Node = bounce_game.get_node("CameraPivot/Camera3D/AxeViewmodelAnchor")
	var axe_player: AnimationPlayer = axe.get_node("AnimationPlayer")
	var bounce_pieces_before: int = bounce_game.piece_count()
	bounce_game._on_click(get_viewport().get_visible_rect().size * 0.5)
	await _wait(axe.contact_time() + 0.04)
	_check(axe_player.current_animation == axe.bounce_anim and axe.is_swinging(),
		"a failed contact branches into the axe's bounce animation")
	_check(bounce_game.piece_count() == bounce_pieces_before and bounce_game.debug_scar_count() == 1,
		"the bounce accompanies one intact, newly scarred log")
	bounce_game.queue_free()
	await get_tree().process_frame

	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = toughest
	mg.debug_split_roll = 0          # every swing fails
	add_child(mg)
	await get_tree().process_frame

	var pieces_before: int = mg.piece_count()
	var chance_before: float = mg.debug_split_chance()
	_check(chance_before > 0.0 and chance_before < 1.0,
		"a fresh %s log is neither hopeless nor certain (%.2f)"
			% [SpeciesTable.at(toughest).id, chance_before])

	var split: bool = mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	_check(not split, "a failed swing does not split the log")
	_check(mg.piece_count() == pieces_before,
		"...the log is still one piece (%d)" % mg.piece_count())
	_check(mg.debug_scar_count() == 1, "...and it wears exactly one scar")

	# The scar is a real mesh on the real piece, not just a counter.
	var marks := 0
	for c in mg.get_node("OnBlock").get_child(0).get_children():
		if c is MeshInstance3D and c.name != "Mesh":
			marks += 1
	_check(marks == 1, "...which is an actual gouge mesh on the log (%d)" % marks)

	var chance_after: float = mg.debug_split_chance()
	_check(absf((chance_after - chance_before) - mg.scar_bonus) < 0.001,
		"the scar raised the next swing's odds by exactly one scar_bonus (%.2f -> %.2f)"
			% [chance_before, chance_after])

	# Keep failing: the pity bonus climbs, and stops at the ceiling. Without that
	# cap a long enough run of bad luck would make a swing a certainty, which is
	# the one thing Sam asked the mechanic never to become.
	for i in range(20):
		mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	_check(mg.debug_scar_count() == 21, "21 failed swings, 21 scars")
	_check(absf(mg.debug_split_chance() - mg.max_split_chance) < 0.001,
		"...and the odds are pinned at the %.2f ceiling, never 1.0" % mg.max_split_chance)

	# Equipment may WEIGHT a learned mechanic, but cannot turn it into certainty.
	GameState.add_cash(Shop.get_upgrade(GameState.UPGRADE_BALANCED_AXE).base_cost)
	_check(Shop.buy(GameState.UPGRADE_BALANCED_AXE) == 1, "the one-time Balanced Axe can be bought")
	_check(Shop.get_level(GameState.UPGRADE_BALANCED_AXE) == 1,
		"...and is recorded as one owned equipment purchase")
	_check(absf(mg.debug_split_chance() - mg.max_split_chance) < 0.001,
		"...while its reliability weighting still respects the split ceiling")

	# A swing that lands takes the scars with it: the cleave went through them.
	mg.debug_split_roll = 1
	_check(mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0)), "a successful swing splits the log")
	_check(mg.piece_count() > pieces_before,
		"...into more pieces than it was (%d)" % mg.piece_count())
	_check(mg.debug_scar_count() == 0, "...and the fresh piece on the block is unscarred")

	mg.queue_free()
	await get_tree().process_frame


## Difficulty follows the money: the wood that pays most resists most, costs most
## and is gated highest. Asserted against the ladder IN ORDER, so a table shuffled
## into a random order fails where pairwise consistency would not — the order is
## load-bearing (the woodshed walks it to find the player's next wood).
func _test_18_tougher_wood_pays_better() -> void:
	var species := SpeciesTable.all()
	_check(species.size() >= 3, "at least three woods to rank (%d)" % species.size())

	var unpriced: Array[String] = []
	var cheaper: Array[String] = []
	var easier: Array[String] = []
	var earlier: Array[String] = []
	var free_wood: Array[String] = []
	var no_xp: Array[String] = []
	var softer: Array[String] = []
	for i in range(species.size()):
		var s := species[i]
		if Market.get_price(s.yield_item) <= 0:
			unpriced.append("%s (%s)" % [s.id, s.yield_item])
		if s.xp_reward <= 0:
			no_xp.append(String(s.id))
		if i == 0:
			continue
		var prev := species[i - 1]
		if Market.get_price(s.yield_item) <= Market.get_price(prev.yield_item):
			cheaper.append("%s <= %s" % [s.id, prev.id])
		if s.split_chance > prev.split_chance:
			easier.append("%s > %s" % [s.id, prev.id])
		if s.unlock_level <= prev.unlock_level:
			earlier.append("%s <= %s" % [s.id, prev.id])
		if s.unlock_cost <= prev.unlock_cost:
			free_wood.append("%s <= %s" % [s.id, prev.id])
		if s.xp_reward <= prev.xp_reward:
			no_xp.append("%s teaches no more than %s" % [s.id, prev.id])
		# NOT a strict per-rung comparison. Sam authored the ORDER and it is
		# authoritative; real Janka has near-ties inside it (Silver Birch 1110 sits
		# just above Pedunculate Oak 1120, and both beeches are level with Sugar
		# Maple), and bending a real-world figure to satisfy a test would corrupt
		# the very record the ladder was derived from. What is worth asserting is
		# that no rung is DRAMATICALLY softer, which is what a misfiled wood is.
		if float(s.janka) < float(prev.janka) * 0.9:
			softer.append("%s (%d) << %s (%d)" % [s.id, s.janka, prev.id, prev.janka])

	# A wood the buyer does not price is not free — it is UNSELLABLE, so a log of
	# it would be chopped for nothing at all.
	_check(unpriced.is_empty(),
		"the basic buyer prices all %d woods%s"
			% [species.size(), "" if unpriced.is_empty() else " — unpriced: " + ", ".join(unpriced)])
	_check(cheaper.is_empty(),
		"every rung up the ladder pays strictly more%s"
			% ["" if cheaper.is_empty() else " — broken at: " + ", ".join(cheaper)])
	_check(easier.is_empty(),
		"...and is no easier to split, so the wood that pays most resists most%s"
			% ["" if easier.is_empty() else " — broken at: " + ", ".join(easier)])
	_check(earlier.is_empty(),
		"...and goes on sale at a strictly higher level%s"
			% ["" if earlier.is_empty() else " — broken at: " + ", ".join(earlier)])
	_check(free_wood.is_empty(),
		"...and costs strictly more to buy%s"
			% ["" if free_wood.is_empty() else " — broken at: " + ", ".join(free_wood)])
	_check(no_xp.is_empty(),
		"...and teaches strictly more (higher woods drop more XP)%s"
			% ["" if no_xp.is_empty() else " — broken at: " + ", ".join(no_xp)])
	_check(softer.is_empty(),
		"...and is not dramatically softer than the wood below it%s"
			% ["" if softer.is_empty() else " — broken at: " + ", ".join(softer)])

	var first := SpeciesTable.starting_species()
	_check(first != null and first.is_starting_wood() and first == species[0],
		"the ladder starts with a wood that is free at level 1 (%s)"
			% ["none" if first == null else first.id])
	_check(species[species.size() - 1].janka > species[0].janka * 3,
		"the ladder actually SPANS hardness — %s at %d lbf against %s at %d"
			% [species[species.size() - 1].id, species[species.size() - 1].janka,
				species[0].id, species[0].janka])


# ------------------------------------------------------------- XP and levels
## Levelling is the spine of the 2026-08-02 direction: XP gates woods and pays for
## the skill tree. The LEVEL IS DERIVED from XP, so these checks are what make
## that derivation safe to build two systems on.
func _test_21_experience_makes_levels() -> void:
	GameState.reset_to_defaults()
	_check(GameState.get_xp() == 0 and GameState.get_level() == 1,
		"a fresh axeman is level 1 on 0 XP (level %d)" % GameState.get_level())
	_check(GameState.get_skill_points_available() == 0,
		"...with no skill points to spend yet (%d)" % GameState.get_skill_points_available())

	var levels: Array[int] = []
	var conn := func(l: int) -> void: levels.append(l)
	GameState.level_gained.connect(conn)

	var to_2 := GameState.get_xp_to_next_level()
	_check(to_2 > 0, "level 2 costs a positive amount of XP (%d)" % to_2)

	GameState.add_xp(to_2 - 1)
	_check(GameState.get_level() == 1, "one XP short is still level 1")
	_check(levels.is_empty(), "...and nothing has levelled up")
	_check(GameState.get_level_progress() > 0.9,
		"...but the bar is nearly full (%.2f)" % GameState.get_level_progress())

	GameState.add_xp(1)
	_check(GameState.get_level() == 2, "the last XP levels the axeman to 2")
	_check(levels == [2], "...announcing exactly one level (%s)" % str(levels))
	_check(GameState.get_skill_points_available() == 1,
		"...and paying exactly one skill point (%d)" % GameState.get_skill_points_available())

	# A big log at low level can cross several levels at once, and three level-ups
	# still owe the player three moments.
	GameState.reset_to_defaults()
	levels.clear()
	var curve_target := 0
	for l in range(1, 5):
		curve_target += _xp_between(l, l + 1)
	GameState.add_xp(curve_target)
	_check(GameState.get_level() == 5, "one fat award reaches level 5 (%d)" % GameState.get_level())
	_check(levels == [2, 3, 4, 5],
		"...announcing every level it passed, in order (%s)" % str(levels))

	# XP is monotonic BY CONSTRUCTION: there is no spend, so a level can never be
	# taken back and skill points already spent can never go negative.
	_check(not GameState.add_xp(0), "add_xp(0) is rejected")
	_check(not GameState.add_xp(-500), "add_xp(-500) is rejected — XP never goes down")
	_check(GameState.get_level() == 5, "...and neither rejection moved the level")

	# The cap is Sam's number and must actually hold.
	GameState.add_xp(999999999)
	_check(GameState.get_level() == LevelCurve.MAX_LEVEL,
		"an absurd award caps at level %d, Sam's maximum (%d)"
			% [LevelCurve.MAX_LEVEL, GameState.get_level()])
	_check(GameState.get_xp_to_next_level() == 0 and GameState.get_level_progress() == 1.0,
		"...with nothing left to earn and the bar reading full")
	_check(GameState.get_skill_points_available() == LevelCurve.MAX_LEVEL - 1,
		"...and %d skill points earned over the run (%d)"
			% [LevelCurve.MAX_LEVEL - 1, GameState.get_skill_points_available()])

	GameState.level_gained.disconnect(conn)
	GameState.reset_to_defaults()


func _xp_between(from_level: int, to_level: int) -> int:
	var curve: LevelCurve = load("res://data/level_curve.tres")
	return curve.total_xp_for_level(to_level) - curve.total_xp_for_level(from_level)


## The skill tree: a real DAG, bought with levels rather than cash.
func _test_22_the_skill_tree_spends_levels() -> void:
	GameState.reset_to_defaults()
	var nodes := SkillTree.get_nodes()
	_check(nodes.size() >= 3, "the tree has nodes to spend on (%d)" % nodes.size())

	var roots := 0
	var gated := 0
	for n: SkillNodeDef in nodes:
		if n.is_root():
			roots += 1
		else:
			gated += 1
	_check(roots > 0, "...at least one root, or the tree cannot be entered (%d)" % roots)
	_check(gated > 0, "...and at least one gated node, or it is not a tree (%d)" % gated)

	# Broke: a node the player cannot pay for must change nothing.
	var root: SkillNodeDef = null
	for n: SkillNodeDef in nodes:
		if n.is_root():
			root = n
			break
	_check(SkillTree.get_level(root.id) == 0, "%s starts unbought" % root.id)
	_check(not SkillTree.can_buy(root.id), "...and cannot be bought on 0 points")
	_check(SkillTree.buy(root.id) == -1, "...so the purchase is refused")
	_check(SkillTree.get_level(root.id) == 0, "...leaving it at level 0")

	# Earn a point and take it.
	GameState.add_xp(_xp_between(1, 2))
	_check(GameState.get_skill_points_available() == 1, "one level, one point")
	_check(SkillTree.buy(root.id) == 1, "%s can now be bought" % root.id)
	_check(SkillTree.get_level(root.id) == 1, "...and is owned at level 1")
	_check(GameState.get_skill_points_available() == 0,
		"...spending the point (%d left)" % GameState.get_skill_points_available())

	# A gated node stays shut until its prerequisites are owned, however rich the
	# player is — this is the difference between a tree and a shopping list.
	var deep: SkillNodeDef = null
	for n: SkillNodeDef in nodes:
		if not n.is_root() and not SkillTree.prerequisites_met(n.id):
			deep = n
			break
	_check(deep != null, "there is a node whose prerequisites are not met")
	GameState.add_xp(999999999)   # max level: every point in the game
	_check(GameState.get_skill_points_available() > deep.cost,
		"the player can afford %s many times over" % deep.id)
	_check(not SkillTree.can_buy(deep.id),
		"...but %s is still shut, because its prerequisites are not met" % deep.id)
	_check(SkillTree.buy(deep.id) == -1, "...and buying it is refused")
	_check(not SkillTree.missing_prerequisites(deep.id).is_empty(),
		"...and it can say what it is waiting for (%s)" % str(SkillTree.missing_prerequisites(deep.id)))

	# Caps hold.
	for i in range(root.max_level + 5):
		SkillTree.buy(root.id)
	_check(SkillTree.get_level(root.id) == root.max_level,
		"%s stops at its cap of %d" % [root.id, root.max_level])
	_check(SkillTree.buy(root.id) == -1, "...and a mastered skill refuses to sell again")

	GameState.reset_to_defaults()


## The tree actually changes the game — the effects the cash shop used to sell.
func _test_23_skills_change_the_game() -> void:
	GameState.reset_to_defaults()
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame

	var cooldown0: float = mg.current_swing_cooldown()
	var chance0: float = mg.debug_split_chance()
	GameState.add_xp(999999999)   # max level, so every root is affordable

	_check(SkillTree.buy(&"quick_hands") == 1, "Quick Hands is bought")
	var cooldown1: float = mg.current_swing_cooldown()
	_check(absf(cooldown1 - cooldown0 * (1.0 - mg.coffee_step)) < 0.0001,
		"one level cuts the wait between swings by 5%% (%.3fs -> %.3fs)" % [cooldown0, cooldown1])
	_check(cooldown1 < cooldown0, "...which is genuinely shorter, not merely different")

	_check(SkillTree.buy(&"strong_arms") == 1, "Strong Arms is bought")
	_check(absf((mg.debug_split_chance() - chance0) - 0.05) < 0.001,
		"one level adds 5 points to the odds of splitting (%.2f -> %.2f)"
			% [chance0, mg.debug_split_chance()])

	# Two nodes feeding the same effect must SUM, which is the whole reason the
	# tree is queried by effect kind rather than by node id.
	SkillTree.buy(&"splitter")
	_check(SkillTree.total_levels(SkillNodeDef.Effect.SPLIT_STRENGTH) == 2,
		"two different nodes both feed split strength")
	_check(SkillTree.total_effect(SkillNodeDef.Effect.SPLIT_STRENGTH) > 0.05,
		"...and their contributions sum (%.3f)"
			% SkillTree.total_effect(SkillNodeDef.Effect.SPLIT_STRENGTH))

	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()


# --------------------------------------------------------- buying a wood
## A wood is LEVEL-GATED and BOUGHT (Creative Director call, 2026-08-02). This
## replaced the lifetime-chopped milestone, and the consequence worth testing is
## that ownership is now real state: the level says a wood MAY be bought, and only
## the purchase says it was.
func _test_24_woods_are_level_gated_purchases() -> void:
	GameState.reset_to_defaults()
	var species := SpeciesTable.all()
	var start := species[0]
	var second := species[1]
	var top := species[species.size() - 1]

	_check(GameState.owns_species(start.id), "a fresh save owns the starting wood (%s)" % start.id)
	_check(GameState.get_owned_species().size() == 1,
		"...and only that one (%d)" % GameState.get_owned_species().size())
	_check(not GameState.owns_species(second.id), "...not the one above it")
	_check(GameState.get_next_unowned_species() == second,
		"the next wood is the next rung, not an arbitrary one")
	_check(GameState.get_selected_species() == start.id,
		"...and the starting wood is on the block")

	# Too low a level: refused even with the cash in hand.
	_check(second.unlock_level > 1, "%s is gated above level 1 (%d)" % [second.id, second.unlock_level])
	GameState.add_cash(second.unlock_cost * 10)
	var purse := GameState.get_cash()
	_check(not GameState.can_species_be_bought(second.id),
		"%s is not for sale at level 1" % second.id)
	_check(not GameState.try_buy_species(second.id), "...so buying it is refused")
	_check(GameState.get_cash() == purse, "...and it cost nothing (%d)" % GameState.get_cash())
	_check(not GameState.owns_species(second.id), "...and is still not owned")

	# High enough, but broke: also refused, and atomically.
	GameState.reset_to_defaults()
	GameState.add_xp(999999999)
	_check(not GameState.can_species_be_bought(second.id),
		"level alone does not bypass %s's supplier relationship" % second.id)
	EventBus.building_upgraded.emit(GameState.UPGRADE_SUPPLIER_LEDGER, 2)
	_check(GameState.can_species_be_bought(second.id),
		"with the Supplier Ledger, max-level %s is on sale" % second.id)
	_check(GameState.get_cash() == 0, "...but the purse is empty")
	_check(not GameState.try_buy_species(second.id), "...so the purchase is refused")
	_check(not GameState.owns_species(second.id), "...and nothing was granted")

	# Paid for: owned, and the cash is gone.
	GameState.add_cash(second.unlock_cost)
	var events: Array[StringName] = []
	var conn := func(id: StringName) -> void: events.append(id)
	GameState.species_purchased.connect(conn)
	_check(GameState.try_buy_species(second.id), "with the money in hand, %s is bought" % second.id)
	_check(GameState.owns_species(second.id), "...and owned")
	_check(GameState.get_cash() == 0, "...having cost exactly %d" % second.unlock_cost)
	_check(events == [second.id], "...emitting once (%s)" % str(events))
	_check(not GameState.try_buy_species(second.id), "...and it cannot be bought twice")
	GameState.species_purchased.disconnect(conn)

	# The richest wood in the game is never a first-log accident.
	_check(not GameState.owns_species(top.id),
		"the richest wood (%s, %d/piece) is not owned" % [top.id, Market.get_price(top.yield_item)])
	_check(not GameState.select_species(top.id), "...and cannot be put on the block")
	_check(GameState.get_selected_species() != top.id, "...so the block does not hold it")

	_check(GameState.select_species(second.id), "an OWNED wood can be chosen")
	_check(GameState.get_selected_species() == second.id, "...and goes on the block")
	GameState.reset_to_defaults()


## Ownership, XP and skills all survive a save — and the derived things are
## re-derived rather than restored.
func _test_25_progression_survives_a_save() -> void:
	GameState.reset_to_defaults()
	var species := SpeciesTable.all()
	var second := species[1]

	GameState.add_xp(999999999)
	EventBus.building_upgraded.emit(GameState.UPGRADE_SUPPLIER_LEDGER, 2)
	GameState.add_cash(second.unlock_cost)
	GameState.try_buy_species(second.id)
	GameState.select_species(second.id)
	SkillTree.buy(&"strong_arms")
	var xp := GameState.get_xp()
	var spent := GameState.get_skill_points_spent()
	_check(spent > 0, "a skill point was spent (%d)" % spent)
	_check(SaveSystem.save_game(), "the yard saves")

	GameState.reset_to_defaults()
	_check(GameState.get_level() == 1 and not GameState.owns_species(second.id),
		"a wiped GameState is back to level 1 with one wood")

	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "the save loads")
	_check(GameState.get_xp() == xp, "XP came back (%d)" % GameState.get_xp())
	_check(GameState.get_level() == LevelCurve.MAX_LEVEL,
		"...and the LEVEL was re-derived from it, not restored (%d)" % GameState.get_level())
	_check(GameState.owns_species(second.id), "the bought wood came back")
	_check(GameState.get_selected_species() == second.id, "...and is still on the block")
	_check(SkillTree.get_level(&"strong_arms") == 1, "the bought skill came back")
	_check(GameState.get_skill_points_spent() == spent,
		"...and still costs what it cost (%d)" % GameState.get_skill_points_spent())

	# A save naming a wood that no longer exists must not strand the player.
	GameState.apply_save_dict({"owned_species": ["a_wood_that_was_renamed"], "selected_species": "gone"})
	_check(GameState.get_selected_species() == species[0].id,
		"a save full of woods that no longer exist still puts the starting wood on the block")
	_check(not GameState.owns_species(&"a_wood_that_was_renamed"),
		"...and does not resurrect the missing one")

	# A skill that left the tree must not leave the player owing points.
	GameState.apply_save_dict({"xp": 0, "skill_levels": {"a_skill_that_was_cut": 5}})
	_check(GameState.get_skill_points_spent() == 0,
		"a skill that is no longer in the tree costs nothing (%d)" % GameState.get_skill_points_spent())
	_check(GameState.get_skill_points_available() >= 0,
		"...so the player is never in skill-point debt (%d)" % GameState.get_skill_points_available())

	GameState.reset_to_defaults()


## The block puts up the wood the player chose, and a finished log pays XP.
func _test_26_the_block_holds_the_chosen_wood() -> void:
	GameState.reset_to_defaults()
	var species := SpeciesTable.all()
	var second := species[1]
	GameState.add_xp(999999999)
	EventBus.building_upgraded.emit(GameState.UPGRADE_SUPPLIER_LEDGER, 2)
	GameState.add_cash(second.unlock_cost)
	GameState.try_buy_species(second.id)
	GameState.select_species(second.id)

	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame

	_check(mg._current_species != null and mg._current_species.id == second.id,
		"the log on the block is the wood the player chose (%s)"
			% ["none" if mg._current_species == null else mg._current_species.id])

	GameState.select_species(species[0].id)
	mg._spawn_fresh_log()
	await get_tree().process_frame
	_check(mg._current_species != null and mg._current_species.id == species[0].id,
		"changing the choice changes the next log (%s)"
			% ["none" if mg._current_species == null else mg._current_species.id])

	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()


## A FINISHED LOG PAYS EXPERIENCE — once, for the whole log, which is the moment
## the orbs burst (Creative Director call: "when the log is finally split").
func _test_27_a_finished_log_pays_experience() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	var wood := SpeciesTable.at(0)
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0
	game.pile_fly_ms = 20.0
	game.pile_stagger_ms = 10.0
	game.firewood_settle_timeout = 0.2
	add_child(game)
	await get_tree().process_frame

	_check(wood.xp_reward > 0, "%s is worth XP (%d)" % [wood.id, wood.xp_reward])
	_check(GameState.get_xp() == 0, "no XP before the log is chopped")

	var safety := 0
	while game.cuttable_count() > 0 and safety < 60:
		game.debug_slice_world(Plane(Vector3.RIGHT if safety % 2 == 0 else Vector3.BACK, 0.0))
		safety += 1
		await get_tree().process_frame
	var pieces: int = game.piece_count()
	_check(pieces > 1, "the log chopped into %d pieces" % pieces)
	await _wait(1.2)

	# ONE award for the whole log, not one per piece — the count is the check that
	# says so, since a per-piece award would read as a multiple.
	_check(GameState.get_xp() == wood.xp_reward,
		"a finished log paid exactly its %d XP once, not once per piece (got %d)"
			% [wood.xp_reward, GameState.get_xp()])

	game.queue_free()
	await get_tree().process_frame
	InventoryManager.apply_save_dict({})
	GameState.reset_to_defaults()


## Optional orders sit on TOP of the unlimited buyer: every piece still sells at
## base price, only matching pieces advance, and the one-time premium/save state
## cannot be duplicated by reaccepting or reloading.
func _test_28_orders_route_pay_and_persist() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var authored := Orders.all()
	_check(authored.size() == 3, "the introductory board has exactly three authored orders")

	var ids: Dictionary = {}
	var data_is_valid := true
	for order: OrderDef in authored:
		data_is_valid = data_is_valid and order != null and order.id != &""
		data_is_valid = data_is_valid and order.required_count > 0 and order.cash_bonus > 0
		data_is_valid = data_is_valid and not ids.has(order.id)
		if order.required_item != &"":
			data_is_valid = data_is_valid and Market.is_sellable(order.required_item)
		ids[order.id] = true
	_check(data_is_valid, "all three orders have unique ids, positive data and sellable requirements")
	_check([authored[0].cash_bonus, authored[1].cash_bonus, authored[2].cash_bonus] == [50, 150, 400],
		"the approved introductory bonuses are exactly 50 / 150 / 400")

	var first_order := Orders.by_id(&"campfire_warmup")
	var aspen_order := Orders.by_id(&"aspen_hearth_load")
	var pine_order := Orders.by_id(&"pine_campsite_load")
	_check(first_order != null and Orders.is_available(first_order),
		"the Campfire Warm-up order is available on a fresh yard")
	_check(aspen_order != null and not Orders.is_available(aspen_order),
		"the Aspen order is visible nearby but waits for its reveal level")
	_check(pine_order != null and not Orders.is_available(pine_order),
		"the distant Pine order waits for later progression")
	_check(GameState.accept_order(first_order.id), "the player can accept one available order")
	_check(not GameState.accept_order(aspen_order.id), "a second order cannot replace the active load")

	var completion_events: Array[StringName] = []
	var on_completed := func(id: StringName, _bonus: int) -> void: completion_events.append(id)
	GameState.order_completed.connect(on_completed)

	# Make partial progress, persist it, wipe memory, and restore it.
	for _i in range(2):
		EventBus.resource_gathered.emit(&"aspen_firewood", 1)
		Orders.settle_piece(&"aspen_firewood")
	_check(GameState.get_active_order_progress() == 2, "two matching pieces advance the load to 2")
	_check(SaveSystem.save_game(), "partial order progress saves")
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "the partial order save loads")
	_check(GameState.get_active_order_id() == first_order.id
			and GameState.get_active_order_progress() == 2,
		"...restoring the same active order at 2 / %d" % first_order.required_count)

	for _i in range(2, first_order.required_count):
		EventBus.resource_gathered.emit(&"aspen_firewood", 1)
		Orders.settle_piece(&"aspen_firewood")
	var expected := (Market.get_price(&"aspen_firewood") * first_order.required_count
		+ first_order.cash_bonus)
	_check(GameState.get_cash() == expected,
		"completion keeps every base sale and adds the authored bonus exactly once (%d)" % expected)
	_check(GameState.get_active_order_id() == &"" and GameState.has_completed_order(first_order.id),
		"the finished load leaves the slot free and enters one-time history")
	_check(completion_events == [first_order.id],
		"completion announces exactly once (%s)" % str(completion_events))
	_check(not GameState.accept_order(first_order.id), "a completed order cannot be claimed twice")

	# Once revealed, a species-specific order still lets unmatched wood sell but
	# does not mis-credit it to the contract.
	GameState.add_xp(GameState.get_xp_to_next_level())
	_check(Orders.is_available(aspen_order) and GameState.accept_order(aspen_order.id),
		"level 2 reveals and enables the Aspen Hearth Load")
	EventBus.resource_gathered.emit(&"pine_firewood", 1)
	var pine_cash := Orders.settle_piece(&"pine_firewood")
	_check(pine_cash == Market.get_price(&"pine_firewood")
			and GameState.get_active_order_progress() == 0,
		"unmatched Pine sells for %d without advancing the Aspen load" % pine_cash)

	GameState.order_completed.disconnect(on_completed)
	InventoryManager.apply_save_dict({})
	GameState.reset_to_defaults()


## The approved five purchases are one ordered catalogue, not five unrelated
## buttons. This pins reveal adjacency, event gates, identity-safe effects and
## the immediate physical greybox consequences that final art will replace.
func _test_29_the_approved_catalogue_is_gated_and_physical() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var defs := Shop.get_upgrades()
	var ids: Array[StringName] = []
	for def: UpgradeDef in defs:
		ids.append(def.id)
	var approved: Array[StringName] = [
		GameState.UPGRADE_BALANCED_AXE,
		GameState.UPGRADE_REINFORCED_BLOCK,
		GameState.UPGRADE_SUPPLIER_LEDGER,
		GameState.UPGRADE_HANDCART,
		GameState.UPGRADE_COFFEE_THERMOS,
	]
	_check(ids == approved, "the shop preserves the approved five-item catalogue order")
	_check(defs[0].purchase_form == UpgradeDef.PurchaseForm.ONE_TIME
			and defs[1].purchase_form == UpgradeDef.PurchaseForm.TIERED
			and defs[1].max_level == 1,
		"M7A ships one Balanced Axe and only the first authored block rank")
	_check(Shop.get_visible_upgrades().size() == 3
			and not Shop.is_unlocked(GameState.UPGRADE_SUPPLIER_LEDGER)
			and not Shop.is_visible(GameState.UPGRADE_HANDCART),
		"a fresh shop shows two choices plus the adjacent Ledger lock, hiding distant items")

	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
	var base_chance: float = game.debug_split_chance()
	var base_radius: float = game.current_work_radius()
	var base_cooldown: float = game.current_swing_cooldown()

	var candidate_total := 0
	for def: UpgradeDef in defs:
		candidate_total += def.base_cost
	GameState.add_cash(candidate_total)
	_check(Shop.buy(GameState.UPGRADE_BALANCED_AXE) == 1
			and game.debug_split_chance() > base_chance,
		"the Balanced Axe immediately weights split reliability without granting a skill")
	var axe: AxeViewmodel = game.get_node("CameraPivot/Camera3D/AxeViewmodelAnchor")
	_check(axe.has_balanced_color_variant(),
		"the purchased axe immediately recolours the existing authored asset")

	_check(Shop.buy(GameState.UPGRADE_REINFORCED_BLOCK) == 1
			and game.current_work_radius() > base_radius,
		"the first block rank immediately broadens the manual work surface")
	_check(presenter.has_physical(GameState.UPGRADE_REINFORCED_BLOCK),
		"the reinforced block immediately appears in the yard")
	_check(presenter.has_block_color_variant(),
		"...as a colour variant of the existing authored chopping block")

	var first := Orders.by_id(&"campfire_warmup")
	_check(GameState.accept_order(first.id), "the introductory order is the route to the Ledger")
	for _i in range(first.required_count):
		GameState.record_order_piece(&"aspen_firewood")
	_check(Shop.is_unlocked(GameState.UPGRADE_SUPPLIER_LEDGER)
			and Shop.is_visible(GameState.UPGRADE_HANDCART),
		"finishing it unlocks the Ledger and reveals only the adjacent Handcart lock")
	_check(Shop.buy(GameState.UPGRADE_SUPPLIER_LEDGER) == 1
			and presenter.has_physical(GameState.UPGRADE_SUPPLIER_LEDGER),
		"the Ledger purchase appears immediately and opens supplier eligibility")

	GameState.record_haul_away()
	_check(Shop.is_unlocked(GameState.UPGRADE_HANDCART),
		"the first real 50-piece haul-away unlocks the Handcart")
	_check(Shop.buy(GameState.UPGRADE_HANDCART) == 1
			and presenter.has_physical(GameState.UPGRADE_HANDCART),
		"the bought Handcart appears immediately")
	game._stage_next_log()
	_check(game.debug_has_staged_log(),
		"the Handcart stages exactly the selected next log without chopping or paying it")

	GameState.add_xp(GameState.get_xp_to_next_level())
	var aspen := Orders.by_id(&"aspen_hearth_load")
	_check(GameState.accept_order(aspen.id), "the level-gated Aspen order can now be accepted")
	for _i in range(aspen.required_count):
		GameState.record_order_piece(&"aspen_firewood")
	_check(Shop.is_unlocked(GameState.UPGRADE_COFFEE_THERMOS),
		"the completed Aspen load unlocks the permanent Thermos")
	_check(Shop.buy(GameState.UPGRADE_COFFEE_THERMOS) == 1
			and game.current_swing_cooldown() < base_cooldown,
		"the Thermos modestly shortens baseline recovery without creating a follow-up")
	_check(presenter.has_physical(GameState.UPGRADE_COFFEE_THERMOS),
		"the Thermos appears immediately as a physical yard prop")
	_check(Shop.get_level(GameState.UPGRADE_COFFEE_THERMOS) == 1
			and Shop.get_next_cost(GameState.UPGRADE_COFFEE_THERMOS) == 0,
		"the Thermos is permanent one-time equipment, not a consumable")
	_check(Shop.get_visible_upgrades().size() == approved.size(),
		"all five owned catalogue rows remain visible after their gates are behind the player")
	var missing_art_is_visible := true
	for id: StringName in [GameState.UPGRADE_SUPPLIER_LEDGER,
			GameState.UPGRADE_HANDCART, GameState.UPGRADE_COFFEE_THERMOS]:
		var art_target := presenter.get_node_or_null(String(id))
		missing_art_is_visible = missing_art_is_visible and art_target != null \
			and String(art_target.get_meta("art_status", "")).begins_with("greybox_missing_authored_")
	_check(missing_art_is_visible,
		"every purchase missing authored art stays visible and tagged for artist replacement")

	game.queue_free()
	await get_tree().process_frame
	InventoryManager.apply_save_dict({})
	GameState.reset_to_defaults()

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
