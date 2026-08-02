extends Control
## FILE: res://scenes/2d_management/yard_hud.gd
## ATTACHES TO: YardHUD (Control), the root of res://scenes/2d_management/yard_hud.tscn.
## That scene is instanced under Main/UI_Overlay (A9: ALL gameplay UI lives in
## UI_Overlay, never inside UI_Canvas, which is the render pipeline's own layer).
##
## FULL NODE TREE (yard_hud.tscn):
##   YardHUD (Control, full rect, mouse_filter = IGNORE)
##   ├── TopBar (PanelContainer, top-left, mouse_filter = IGNORE)
##   │   └── CashRow (HBoxContainer)
##   │       ├── CashIcon (TextureRect — the coin)
##   │       └── CashLabel (Label)
##   ├── YardPanel (PanelContainer, right column — 2D management mode only)
##   │   └── Column (VBoxContainer)
##   │       ├── Title (Label)
##   │       ├── Blurb (Label)
##   │       ├── Spacer (Control)
##   │       ├── WoodButton (Button — names the wood currently on the block)
##   │       ├── ShopButton (Button — the coin icon)
##   │       └── ChopButton (Button)
##   ├── ShopPanel (PanelContainer, centred — hidden until the shop is opened)
##   │   └── Column (VBoxContainer)
##   │       ├── Header (HBoxContainer) → ShopIcon (TextureRect), ShopTitle (Label)
##   │       ├── ShopList (VBoxContainer)   <- rows are built at RUNTIME
##   │       ├── ShopEmpty (Label)
##   │       └── CloseShopButton (Button)
##   ├── WoodPanel (PanelContainer, centred — hidden until the woodshed is opened)
##   │   └── Column (VBoxContainer)
##   │       ├── WoodTitle (Label)
##   │       ├── WoodBlurb (Label)
##   │       ├── WoodScroll (ScrollContainer)  <- 25 woods do not fit on a panel
##   │       │   └── WoodList (VBoxContainer)  <- rows are built at RUNTIME
##   │       ├── NextWood (Label — the next milestone)
##   │       └── CloseWoodButton (Button)
##   └── BackButton (Button, bottom-left — chopping mode only)
##
## THERE IS NO SELLING TO DO HERE (Creative Director call, 2026-08-01). The yard
## buys every piece of firewood the moment it lands on the pile, so the player
## never manages stock — they chop, the money goes up, and they spend it in the
## shop. The sell rows and the "Sell all" button this HUD shipped with are gone.
##
## THE REAL ENTRY FLOW (M7A). "Go chopping" and "Back to the yard" emit the same
## A7 signals the temporary M key used to — `minigame_entered` /
## `minigame_exited` — so main.gd's A10 mode switch is driven by exactly the path
## it was always meant to be driven by. The M key is gone with this scene.
##
## CASH IS THE ONLY NUMBER ON SCREEN (Creative Director call, 2026-08-01: "we
## don't need to show the player how many are stacked in yard or how many you have
## chopped in your lifetime, those can stay as background stats"). Both are still
## counted and still saved — `GameState.get_yard_pile_count()` and
## `get_lifetime_wood_chopped()` are unchanged, and the pile itself is still the
## visible record of the stack. They simply have no readout.
##
## LIVE, NEVER POLLED: it listens to GameState.cash_changed, which is precisely
## what that local signal exists for (Amendment 2's precedent).
##
## THE SHOP ROWS ARE BUILT FROM DATA at runtime, from `Shop.get_upgrades()` — so
## a new thing to buy is a row in `res://data/upgrade_table.tres` and nothing else.
## Costs and level caps in that file are placeholders awaiting Sam; the two 5%
## effect steps are his.
##
## THE WOODSHED, added 2026-08-02 (Creative Director call: the player PICKS the
## wood that goes on the block, rather than it being rolled). Same shape as the
## shop — rows built at runtime from `res://data/species_table.tres`, so Sam's 25
## woods needed no UI code per wood.
##
## IT SHOWS EARNED WOODS PLUS EXACTLY ONE LOCKED ONE. A wall of 24 greyed-out
## rows would be a list of things the player cannot do; one named next goal with
## the chops still to go is a reason to pick the axe back up. `SpeciesTable.
## next_locked()` is what makes that one row cheap to find.
##
## THE SELECTOR NEVER DECIDES ANYTHING. `GameState.select_species()` refuses a
## wood that has not been earned and changes nothing when it does, so a row left
## stale by a background unlock cannot hand out Lignum Vitae — this file only
## asks. Same division as the shop, where `Shop.buy()` owns the refusal.
##
## Layout numbers and wording here are functional placeholders — art direction for
## the 2D side is still deferred (M2 sign-off).

const _COIN := preload("res://assets/ui/coin.png")

@onready var _cash_label: Label = $TopBar/CashRow/CashLabel
@onready var _yard_panel: PanelContainer = $YardPanel
@onready var _shop_list: VBoxContainer = $ShopPanel/Column/ShopList
@onready var _shop_empty: Label = $ShopPanel/Column/ShopEmpty
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _shop_button: Button = $YardPanel/Column/ShopButton
@onready var _close_shop_button: Button = $ShopPanel/Column/CloseShopButton
@onready var _chop_button: Button = $YardPanel/Column/ChopButton
@onready var _back_button: Button = $BackButton
@onready var _wood_button: Button = $YardPanel/Column/WoodButton
@onready var _wood_panel: PanelContainer = $WoodPanel
@onready var _wood_list: VBoxContainer = $WoodPanel/Column/WoodScroll/WoodList
@onready var _next_wood: Label = $WoodPanel/Column/NextWood
@onready var _close_wood_button: Button = $WoodPanel/Column/CloseWoodButton


func _ready() -> void:
	_chop_button.pressed.connect(_on_chop_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_close_shop_button.pressed.connect(_on_close_shop_pressed)
	_wood_button.pressed.connect(_on_wood_pressed)
	_close_wood_button.pressed.connect(_on_close_wood_pressed)

	GameState.cash_changed.connect(_on_cash_changed)
	# The woodshed's three live inputs, all local signals (Amendment 2's
	# precedent), so nothing here polls: what the player picked, what they have
	# just earned, and the counter the next milestone is measured against.
	GameState.selected_species_changed.connect(_on_selected_species_changed)
	GameState.species_unlocked.connect(_on_species_unlocked)
	GameState.lifetime_wood_chopped_changed.connect(_on_lifetime_changed)
	# A purchase moves a tier through A7's own signal, so the shelf repaints off
	# the same event that recorded the sale.
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)

	# The game boots into 2D management mode (main.gd calls _enter_2d_mode), so the
	# yard starts open, the shop closed and the back button hidden.
	_shop_panel.visible = false
	_wood_panel.visible = false
	_show_yard(true)
	_refresh_stats()
	_rebuild_shop()
	_rebuild_woodshed()


## ------------------------------------------------------------------ entry flow
func _on_chop_pressed() -> void:
	EventBus.minigame_entered.emit(Enums.Biome.PINE_FOREST)


func _on_back_pressed() -> void:
	EventBus.minigame_exited.emit()


## Driven by the SIGNAL, not by the button, so the view is correct however the
## mode changed — a future cutscene, a save load or a test emitting it directly
## all land here.
func _on_minigame_entered(_biome: Enums.Biome) -> void:
	_show_yard(false)


func _on_minigame_exited() -> void:
	_show_yard(true)


func _show_yard(yard_visible: bool) -> void:
	_yard_panel.visible = yard_visible
	_back_button.visible = not yard_visible
	if not yard_visible:
		# Neither counter follows you to the block: the wood is already chosen and
		# on the stump by the time you are looking at it.
		_shop_panel.visible = false
		_wood_panel.visible = false
	# The stats bar stays up in BOTH modes on purpose: watching the cash climb
	# while chopping is the whole "number go up" payoff.


## ------------------------------------------------------------------- the shop
func _on_shop_pressed() -> void:
	_shop_panel.visible = true
	_rebuild_shop()   # levels and affordability may have moved while it was shut


func _on_close_shop_pressed() -> void:
	_shop_panel.visible = false


func _on_building_upgraded(_id: StringName, _tier: int) -> void:
	_rebuild_shop()


## One row per upgrade, straight from the table: what it is, what it does, what
## level you are on and what the next one costs.
func _rebuild_shop() -> void:
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()

	var upgrades := Shop.get_upgrades()
	_shop_empty.visible = upgrades.is_empty()
	for def: UpgradeDef in upgrades:
		if def != null:
			_shop_list.add_child(_build_shop_row(def))


func _build_shop_row(def: UpgradeDef) -> VBoxContainer:
	var level := Shop.get_level(def.id)
	var maxed := def.is_maxed(level)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = "%s  (level %d)" % [def.display_name, level]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(92, 34)   # room for the coin beside the price
	if maxed:
		buy.text = "Maxed"
		buy.disabled = true
	else:
		buy.text = str(Shop.get_next_cost(def.id))
		buy.icon = _COIN
		buy.expand_icon = true
		buy.disabled = not Shop.can_buy(def.id)
		buy.pressed.connect(_on_buy_pressed.bind(def.id))
	top.add_child(buy)
	row.add_child(top)

	var blurb := Label.new()
	blurb.text = def.description
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 13)
	row.add_child(blurb)
	return row


func _on_buy_pressed(id: StringName) -> void:
	# Shop.buy is atomic: a refused purchase spends nothing and moves no tier, so
	# there is nothing to undo here. The rebuild rides in on building_upgraded.
	Shop.buy(id)


## ---------------------------------------------------------------- the woodshed
func _on_wood_pressed() -> void:
	_wood_panel.visible = true
	_rebuild_woodshed()   # a wood may have been earned while it was shut


func _on_close_wood_pressed() -> void:
	_wood_panel.visible = false


## Driven by the SIGNALS rather than by the row that was clicked, so the button
## and the list agree however the choice moved — including a selection GameState
## refused, which emits nothing and correctly leaves the display alone.
func _on_selected_species_changed(_id: StringName) -> void:
	_refresh_wood_button()
	if _wood_panel.visible:
		_rebuild_woodshed()


func _on_species_unlocked(_id: StringName) -> void:
	_rebuild_woodshed()   # cheap, and it can fire mid-chop with the panel shut


## The next milestone is measured against this counter, so the woodshed's "N more
## to go" has to move with it. Only repaints while the panel is open — this fires
## once per piece of firewood.
func _on_lifetime_changed(_total: int) -> void:
	if _wood_panel.visible:
		_rebuild_woodshed()


## One row per EARNED wood, plus exactly one locked row as the next goal.
func _rebuild_woodshed() -> void:
	for child in _wood_list.get_children():
		_wood_list.remove_child(child)
		child.queue_free()

	var chosen := GameState.get_selected_species()
	for def: SpeciesDef in GameState.get_unlocked_species():
		_wood_list.add_child(_build_wood_row(def, def.id == chosen))

	var next := GameState.get_next_locked_species()
	if next == null:
		_next_wood.text = "Every wood on Earth is yours."
	else:
		_next_wood.text = "Next: %s — %s more pieces to go." % [
			next.display_name,
			_thousands(next.chops_remaining(GameState.get_lifetime_wood_chopped())),
		]
	_refresh_wood_button()


func _build_wood_row(def: SpeciesDef, is_chosen: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# What the player is actually choosing between: what it pays, and how hard it
	# fights. Janka is the honest one-number answer to "how hard" and it is the
	# number the whole ladder was derived from, so it is the one shown.
	var stat := Label.new()
	stat.text = "%s per piece   ·   %d lbf" % [_thousands(Market.get_price(def.yield_item)), def.janka]
	stat.add_theme_font_size_override("font_size", 13)
	row.add_child(stat)

	var pick := Button.new()
	pick.custom_minimum_size = Vector2(112, 32)
	pick.text = "On the block" if is_chosen else "Chop this"
	pick.disabled = is_chosen
	if not is_chosen:
		pick.pressed.connect(_on_wood_row_pressed.bind(def.id))
	row.add_child(pick)
	return row


func _on_wood_row_pressed(id: StringName) -> void:
	# select_species is atomic and refuses anything unearned, so there is nothing
	# to undo here. The repaint rides in on selected_species_changed.
	GameState.select_species(id)


func _refresh_wood_button() -> void:
	var def := SpeciesTable.by_id(GameState.get_selected_species())
	_wood_button.text = "Wood:  %s" % ("—" if def == null else def.display_name)


## 70000 -> "70,000". The late ladder deals in tens of thousands of pieces, and an
## unpunctuated number that long stops being readable as a quantity.
func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out


## ----------------------------------------------------------------- live view
func _on_cash_changed(_new_amount: int) -> void:
	_refresh_stats()
	if _shop_panel.visible:
		_rebuild_shop()   # what you can afford changed while you were looking at it


func _refresh_stats() -> void:
	_cash_label.text = str(GameState.get_cash())
