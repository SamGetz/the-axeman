extends Control
## FILE: res://scenes/2d_management/yard_hud.gd
## ATTACHES TO: YardHUD (Control), the root of res://scenes/2d_management/yard_hud.tscn.
## That scene is instanced under Main/UI_Overlay (A9: ALL gameplay UI lives in
## UI_Overlay, never inside UI_Canvas, which is the render pipeline's own layer).
##
## FULL NODE TREE (yard_hud.tscn):
##   YardHUD (Control, full rect, mouse_filter = IGNORE)
##   ├── TopBar (PanelContainer, top-left, mouse_filter = IGNORE)
##   │   └── Stats (VBoxContainer)
##   │       ├── CashRow (HBoxContainer)
##   │       │   ├── CashIcon (TextureRect — the coin)
##   │       │   └── CashLabel (Label)
##   │       ├── PileLabel (Label)
##   │       └── LifetimeLabel (Label)
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
## LIVE, NEVER POLLED: it listens to GameState.cash_changed,
## GameState.lifetime_wood_chopped_changed and GameState.yard_pile_changed, which
## is precisely what those local signals exist for (Amendment 2's precedent).
##
## Layout numbers and wording here are functional placeholders — art direction for
## the 2D side is still deferred (M2 sign-off). THE SHOP IS AN EMPTY ROOM ON
## PURPOSE: upgrades and new logs are blocked on Sam's numbers (Directive 3), so
## this is the door and the counter, with nothing on the shelves yet.

@onready var _cash_label: Label = $TopBar/Stats/CashRow/CashLabel
@onready var _pile_label: Label = $TopBar/Stats/PileLabel
@onready var _lifetime_label: Label = $TopBar/Stats/LifetimeLabel
@onready var _yard_panel: PanelContainer = $YardPanel
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
	GameState.lifetime_wood_chopped_changed.connect(_on_lifetime_changed)
	GameState.yard_pile_changed.connect(_on_yard_pile_changed)
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)

	# The game boots into 2D management mode (main.gd calls _enter_2d_mode), so the
	# yard starts open, the shop closed and the back button hidden.
	_shop_panel.visible = false
	_show_yard(true)
	_refresh_stats()


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


func _on_close_shop_pressed() -> void:
	_shop_panel.visible = false


## ----------------------------------------------------------------- live view
func _on_cash_changed(_new_amount: int) -> void:
	_refresh_stats()


func _on_lifetime_changed(_new_total: int) -> void:
	_refresh_stats()


func _on_yard_pile_changed(_new_total: int) -> void:
	_refresh_stats()


func _refresh_stats() -> void:
	_cash_label.text = str(GameState.get_cash())
	_pile_label.text = "Stacked in the yard: %d" % GameState.get_yard_pile_count()
	_lifetime_label.text = "Wood chopped (lifetime): %d" % GameState.get_lifetime_wood_chopped()
