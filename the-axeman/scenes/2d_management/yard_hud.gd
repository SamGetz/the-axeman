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
##   │       ├── CashLabel (Label)
##   │       ├── StockValueLabel (Label)
##   │       └── LifetimeLabel (Label)
##   ├── YardPanel (PanelContainer, right column — 2D management mode only)
##   │   └── Column (VBoxContainer)
##   │       ├── Title (Label)
##   │       ├── StockList (VBoxContainer)   <- rows are built at RUNTIME
##   │       ├── EmptyHint (Label)
##   │       ├── SellAllButton (Button)
##   │       └── ChopButton (Button)
##   └── BackButton (Button, bottom-left — chopping mode only)
##
## THE REAL ENTRY FLOW (M7A). "Go chopping" and "Back to the yard" emit the same
## A7 signals the temporary M key used to — `minigame_entered` /
## `minigame_exited` — so main.gd's A10 mode switch is driven by exactly the path
## it was always meant to be driven by. The M key is gone with this scene.
##
## THE STOCK LIST IS BUILT FROM DATA, NOT AUTHORED. One row per sellable item the
## player actually holds, from Market.get_sellable_stock(), so an unlocked wood
## species appears here the moment it has a price and a piece in stock — no scene
## edit, no new label.
##
## LIVE, NEVER POLLED: it listens to GameState.cash_changed,
## GameState.lifetime_wood_chopped_changed and InventoryManager.inventory_changed,
## which is precisely what Amendment 2 added those local signals for.
##
## Layout numbers and wording here are functional placeholders — art direction for
## the 2D side is still deferred (M2 sign-off).

## Rebuilding the stock rows is deferred and coalesced for the same reason the
## autosave in main.gd is: finishing a log deposits its pieces one at a time, so a
## six-piece log fires inventory_changed six times in a single frame. Rebuilding
## the list six times would throw away and rebuild every row five times for one
## identical result.
var _rows_dirty := false

@onready var _cash_label: Label = $TopBar/Stats/CashLabel
@onready var _stock_value_label: Label = $TopBar/Stats/StockValueLabel
@onready var _lifetime_label: Label = $TopBar/Stats/LifetimeLabel
@onready var _yard_panel: PanelContainer = $YardPanel
@onready var _stock_list: VBoxContainer = $YardPanel/Column/StockList
@onready var _empty_hint: Label = $YardPanel/Column/EmptyHint
@onready var _sell_all_button: Button = $YardPanel/Column/SellAllButton
@onready var _chop_button: Button = $YardPanel/Column/ChopButton
@onready var _back_button: Button = $BackButton


func _ready() -> void:
	_chop_button.pressed.connect(_on_chop_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_sell_all_button.pressed.connect(_on_sell_all_pressed)

	GameState.cash_changed.connect(_on_cash_changed)
	GameState.lifetime_wood_chopped_changed.connect(_on_lifetime_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)

	# The game boots into 2D management mode (main.gd calls _enter_2d_mode), so the
	# yard starts open and the back button starts hidden.
	_show_yard(true)
	_refresh_stats()
	_rebuild_stock_rows()


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
	_rebuild_stock_rows()   # a chopping session almost certainly changed the stock


func _show_yard(yard_visible: bool) -> void:
	_yard_panel.visible = yard_visible
	_back_button.visible = not yard_visible
	# The stats bar stays up in BOTH modes on purpose: watching the stock value
	# climb while chopping is the whole "number go up" payoff.


## ---------------------------------------------------------------------- sales
func _on_sell_all_pressed() -> void:
	# With nothing sellable in stock this is a no-op that changes nothing, which
	# is also why the button disables itself in that state.
	Market.sell_everything()


func _on_sell_row_pressed(item_id: StringName) -> void:
	Market.sell_all_of(item_id)


## ----------------------------------------------------------------- live view
func _on_cash_changed(_new_amount: int) -> void:
	_refresh_stats()


func _on_lifetime_changed(_new_total: int) -> void:
	_refresh_stats()


func _on_inventory_changed(_item_id: StringName, _new_count: int) -> void:
	_refresh_stats()
	if _rows_dirty:
		return
	_rows_dirty = true
	_rebuild_stock_rows.call_deferred()


func _refresh_stats() -> void:
	_cash_label.text = "Cash: %d" % GameState.get_cash()
	_stock_value_label.text = "Stock value: %d" % Market.get_stock_value()
	_lifetime_label.text = "Wood chopped (lifetime): %d" % GameState.get_lifetime_wood_chopped()


func _rebuild_stock_rows() -> void:
	_rows_dirty = false
	for child in _stock_list.get_children():
		child.queue_free()
		# queue_free() only takes effect at the end of the frame, and this can be
		# called more than once before then (a sale, then its autosave). Removing
		# the child NOW means a rebuild can never see the previous pass's rows.
		_stock_list.remove_child(child)

	var rows := Market.get_sellable_stock()
	_empty_hint.visible = rows.is_empty()
	_sell_all_button.disabled = rows.is_empty()

	for row: Dictionary in rows:
		_stock_list.add_child(_build_row(row))


func _build_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "%s  x%d" % [row["display_name"], row["count"]]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)

	var sell := Button.new()
	var item_id: StringName = row["item_id"]
	sell.text = "Sell (%d)" % int(row["value"])
	sell.tooltip_text = "Sell all %d at %d each" % [int(row["count"]), int(row["unit_price"])]
	sell.pressed.connect(_on_sell_row_pressed.bind(item_id))
	line.add_child(sell)

	return line
