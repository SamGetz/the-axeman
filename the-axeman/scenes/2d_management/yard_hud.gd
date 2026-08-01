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
##   │       ├── ShopButton (Button — the coin icon)
##   │       └── ChopButton (Button)
##   ├── ShopPanel (PanelContainer, centred — hidden until the shop is opened)
##   │   └── Column (VBoxContainer)
##   │       ├── Header (HBoxContainer) → ShopIcon (TextureRect), ShopTitle (Label)
##   │       ├── ShopList (VBoxContainer)   <- rows are built at RUNTIME
##   │       ├── ShopEmpty (Label)
##   │       └── CloseShopButton (Button)
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


func _ready() -> void:
	_chop_button.pressed.connect(_on_chop_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_close_shop_button.pressed.connect(_on_close_shop_pressed)

	GameState.cash_changed.connect(_on_cash_changed)
	# A purchase moves a tier through A7's own signal, so the shelf repaints off
	# the same event that recorded the sale.
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)

	# The game boots into 2D management mode (main.gd calls _enter_2d_mode), so the
	# yard starts open, the shop closed and the back button hidden.
	_shop_panel.visible = false
	_show_yard(true)
	_refresh_stats()
	_rebuild_shop()


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
		_shop_panel.visible = false   # the shop does not follow you to the block
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


## ----------------------------------------------------------------- live view
func _on_cash_changed(_new_amount: int) -> void:
	_refresh_stats()
	if _shop_panel.visible:
		_rebuild_shop()   # what you can afford changed while you were looking at it


func _refresh_stats() -> void:
	_cash_label.text = str(GameState.get_cash())
