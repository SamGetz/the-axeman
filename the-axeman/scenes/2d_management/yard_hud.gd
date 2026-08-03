extends Control
## FILE: res://scenes/2d_management/yard_hud.gd
## ATTACHES TO: YardHUD (Control), the root of res://scenes/2d_management/yard_hud.tscn.
## That scene is instanced under Main/UI_Overlay (A9: ALL gameplay UI lives in
## UI_Overlay, never inside UI_Canvas, which is the render pipeline's own layer).
##
## ALWAYS-ON CHOPPING HUD (Creative Director call, 2026-08-03). There is no
## separate yard screen. Contracts, wood, skills and shop live in four square
## icon buttons at bottom-right while the chopping game stays on screen.
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
##   ├── ModalBackdrop (ColorRect — catches clicks outside an open panel)
##   └── QuickMenu (HBoxContainer — four square icon buttons, bottom-right)
##
## THERE IS NO SELLING TO DO HERE (Creative Director call, 2026-08-01). The yard
## buys every piece of firewood the moment it lands on the pile, so the player
## never manages stock — they chop, the money goes up, and they spend it in the
## shop. The sell rows and the "Sell all" button this HUD shipped with are gone.
##
## CASH IS THE ONLY PERMANENT ECONOMY NUMBER ON SCREEN (Creative Director call,
## 2026-08-01: "we
## don't need to show the player how many are stacked in yard or how many you have
## chopped in your lifetime, those can stay as background stats"). Both are still
## counted and still saved — `GameState.get_yard_pile_count()` and
## `get_lifetime_wood_chopped()` are unchanged, and the pile itself is still the
## visible record of the stack. They simply have no readout. The haul-away has no
## progress bar either (Creative Director call, 2026-08-03): the physical pile
## and its animation communicate the event without another UI meter.
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
@onready var _shop_list: VBoxContainer = $ShopPanel/Column/ShopList
@onready var _shop_empty: Label = $ShopPanel/Column/ShopEmpty
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _shop_button: Button = $QuickMenu/ShopButton
@onready var _close_shop_button: Button = $ShopPanel/Column/CloseShopButton
@onready var _wood_button: Button = $QuickMenu/WoodButton
@onready var _wood_panel: PanelContainer = $WoodPanel
@onready var _wood_list: VBoxContainer = $WoodPanel/Column/WoodScroll/WoodList
@onready var _next_wood: Label = $WoodPanel/Column/NextWood
@onready var _close_wood_button: Button = $WoodPanel/Column/CloseWoodButton
@onready var _xp_level_label: Label = $XPBar/Column/LevelLabel
@onready var _xp_progress: ProgressBar = $XPBar/Column/Progress
@onready var _skills_button: Button = $QuickMenu/SkillsButton
@onready var _skill_panel: PanelContainer = $SkillPanel
@onready var _skill_list: VBoxContainer = $SkillPanel/Column/SkillScroll/SkillList
@onready var _points_label: Label = $SkillPanel/Column/PointsLabel
@onready var _close_skill_button: Button = $SkillPanel/Column/CloseSkillButton
@onready var _orders_button: Button = $QuickMenu/OrdersButton
@onready var _orders_panel: PanelContainer = $OrdersPanel
@onready var _orders_list: VBoxContainer = $OrdersPanel/Column/Scroll/List
@onready var _orders_active: Label = $OrdersPanel/Column/Active
@onready var _close_orders_button: Button = $OrdersPanel/Column/CloseButton
@onready var _modal_backdrop: ColorRect = $ModalBackdrop


func _ready() -> void:
	_shop_button.pressed.connect(_on_shop_pressed)
	_close_shop_button.pressed.connect(_on_close_shop_pressed)
	_wood_button.pressed.connect(_on_wood_pressed)
	_close_wood_button.pressed.connect(_on_close_wood_pressed)
	_skills_button.pressed.connect(_on_skills_pressed)
	_close_skill_button.pressed.connect(_on_close_skill_pressed)
	_orders_button.pressed.connect(_on_orders_pressed)
	_close_orders_button.pressed.connect(_on_close_orders_pressed)
	_modal_backdrop.gui_input.connect(_on_modal_backdrop_gui_input)

	GameState.cash_changed.connect(_on_cash_changed)
	# The woodshed's three live inputs, all local signals (Amendment 2's
	# precedent), so nothing here polls: what the player picked, what they have
	# just earned, and the counter the next milestone is measured against.
	GameState.selected_species_changed.connect(_on_selected_species_changed)
	GameState.species_purchased.connect(_on_species_purchased)
	# XP moves the level, the level opens woods AND pays for skills, so both
	# panels and the bar ride on it.
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.skill_points_changed.connect(_on_skill_points_changed)
	GameState.skill_level_changed.connect(_on_skill_level_changed)
	GameState.order_state_changed.connect(_on_order_state_changed)
	# A purchase moves a tier through A7's own signal, so the shelf repaints off
	# the same event that recorded the sale.
	EventBus.building_upgraded.connect(_on_building_upgraded)

	_close_panels()
	_refresh_stats()
	_refresh_xp_bar()
	_rebuild_shop()
	_rebuild_woodshed()
	_rebuild_skills()
	_rebuild_orders()


## -------------------------------------------------------------- modal panels
func _open_panel(panel: Control) -> void:
	_close_panels()
	_modal_backdrop.visible = true
	panel.visible = true


func _close_panels() -> void:
	_shop_panel.visible = false
	_wood_panel.visible = false
	_skill_panel.visible = false
	_orders_panel.visible = false
	_modal_backdrop.visible = false


## The backdrop consumes the outside click after closing the panel, so dismissing
## a window can never swing the axe at the same time.
func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_panels()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _modal_backdrop.visible and event.is_action_pressed("ui_cancel"):
		_close_panels()
		get_viewport().set_input_as_handled()


## ------------------------------------------------------------------- the shop
func _on_shop_pressed() -> void:
	_open_panel(_shop_panel)
	_rebuild_shop()   # levels and affordability may have moved while it was shut


func _on_close_shop_pressed() -> void:
	_close_panels()


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
	_open_panel(_wood_panel)
	_rebuild_woodshed()   # a wood may have been earned while it was shut


func _on_close_wood_pressed() -> void:
	_close_panels()


## Driven by the SIGNALS rather than by the row that was clicked, so the button
## and the list agree however the choice moved — including a selection GameState
## refused, which emits nothing and correctly leaves the display alone.
func _on_selected_species_changed(_id: StringName) -> void:
	_refresh_wood_button()
	if _wood_panel.visible:
		_rebuild_woodshed()


func _on_species_purchased(_id: StringName) -> void:
	_rebuild_woodshed()
	_rebuild_orders()


## XP moves the level, and the level is what puts a wood on sale — so the shed's
## "needs level N" rows can go live without the player touching anything. Only
## repaints an OPEN panel: this fires once per finished log.
func _on_xp_changed(_total: int) -> void:
	_refresh_xp_bar()
	if _wood_panel.visible:
		_rebuild_woodshed()
	if _skill_panel.visible:
		_rebuild_skills()


func _on_skill_points_changed(_available: int) -> void:
	_refresh_xp_bar()
	if _skill_panel.visible:
		_rebuild_skills()


func _on_skill_level_changed(_id: StringName, _level: int) -> void:
	_rebuild_skills()


## THE WOODSHED IS A STORE since 2026-08-02: one row per wood the player OWNS,
## plus exactly one row for the next wood up the ladder — showing either its price
## or the level still to reach. A wall of 24 locked rows would be a list of things
## the player cannot do; one named next wood is a reason to keep chopping.
func _rebuild_woodshed() -> void:
	for child in _wood_list.get_children():
		_wood_list.remove_child(child)
		child.queue_free()

	var chosen := GameState.get_selected_species()
	for def: SpeciesDef in GameState.get_owned_species():
		_wood_list.add_child(_build_wood_row(def, def.id == chosen))

	var next := GameState.get_next_unowned_species()
	if next == null:
		_next_wood.text = "Every wood on Earth is yours."
	else:
		var levels := next.levels_remaining(GameState.get_level())
		if levels > 0:
			_next_wood.text = "Next: %s — reach level %d to put it up for sale (%d to go)." % [
				next.display_name, next.unlock_level, levels]
		else:
			_wood_list.add_child(_build_wood_row(next, false))
			_next_wood.text = "%s is in stock at the gate — %s to buy it." % [
				next.display_name, _thousands(next.unlock_cost)]
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
	if not GameState.owns_species(def.id):
		# The one for-sale row. Its price is the cash sink the whole economy feeds.
		pick.text = str(_thousands(def.unlock_cost))
		pick.icon = _COIN
		pick.expand_icon = true
		pick.disabled = not GameState.can_afford_cash(def.unlock_cost)
		pick.pressed.connect(_on_buy_wood_pressed.bind(def.id))
	else:
		pick.text = "On the block" if is_chosen else "Chop this"
		pick.disabled = is_chosen
		if not is_chosen:
			pick.pressed.connect(_on_wood_row_pressed.bind(def.id))
	row.add_child(pick)
	return row


func _on_wood_row_pressed(id: StringName) -> void:
	# select_species is atomic and refuses anything unowned, so there is nothing
	# to undo here. The repaint rides in on selected_species_changed.
	GameState.select_species(id)


func _on_buy_wood_pressed(id: StringName) -> void:
	# try_buy_species is atomic and ordered — under-level, unaffordable or already
	# owned all change nothing. Buying it also puts it on the block, because a
	# player who just spent their yard on a wood means to chop it.
	if GameState.try_buy_species(id):
		GameState.select_species(id)


func _refresh_wood_button() -> void:
	var def := SpeciesTable.by_id(GameState.get_selected_species())
	_wood_button.tooltip_text = "Wood: %s" % ("—" if def == null else def.display_name)


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


## ------------------------------------------------------------- the skill tree
func _on_skills_pressed() -> void:
	_open_panel(_skill_panel)
	_rebuild_skills()


## --------------------------------------------------------- contract board
func _on_orders_pressed() -> void:
	_open_panel(_orders_panel)
	_rebuild_orders()


func _on_close_orders_pressed() -> void:
	_close_panels()


func _on_order_state_changed() -> void:
	_rebuild_orders()


func _rebuild_orders() -> void:
	for child in _orders_list.get_children():
		_orders_list.remove_child(child)
		child.queue_free()

	var active := GameState.get_active_order()
	if active == null:
		_orders_active.text = "No active order — ordinary chopping always pays."
	else:
		_orders_active.text = "Active: %s — %d / %d" % [
			active.title, GameState.get_active_order_progress(), active.required_count]

	for order: OrderDef in Orders.all():
		if order != null:
			_orders_list.add_child(_build_order_row(order))


func _build_order_row(order: OrderDef) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var heading := Label.new()
	heading.text = "%s — %s" % [order.customer_name, order.title]
	heading.add_theme_font_size_override("font_size", 17)
	row.add_child(heading)

	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "%s\n%d pieces · +%s coin bonus" % [
		order.description, order.required_count, _thousands(order.cash_bonus)]
	row.add_child(detail)

	if GameState.get_active_order_id() == order.id:
		var progress := ProgressBar.new()
		progress.max_value = order.required_count
		progress.value = GameState.get_active_order_progress()
		progress.show_percentage = false
		row.add_child(progress)

	var button := Button.new()
	button.custom_minimum_size.y = 34
	if GameState.has_completed_order(order.id):
		button.text = "Completed"
		button.disabled = true
	elif GameState.get_active_order_id() == order.id:
		button.text = "In progress"
		button.disabled = true
	elif GameState.get_active_order_id() != &"":
		button.text = "Finish the active order first"
		button.disabled = true
	elif not Orders.is_available(order):
		var species := SpeciesTable.by_id(order.required_species)
		button.text = "Requires %s" % (String(order.required_species) if species == null else species.display_name)
		button.disabled = true
	else:
		button.text = "Accept order"
		button.pressed.connect(_on_accept_order_pressed.bind(order.id))
	row.add_child(button)
	return row


func _on_accept_order_pressed(order_id: StringName) -> void:
	GameState.accept_order(order_id)


func _on_close_skill_pressed() -> void:
	_close_panels()


## THE TREE IS DRAWN AS AN INDENTED LIST, not as a graph with lines. A real node
## graph is a layout problem and a design pass of its own; what the player needs
## to answer right now is "what can I take next and what does it need", and depth
## plus a named prerequisite says that without either. The DATA is a real DAG
## (SkillNodeDef.requires, validated for cycles at load), so a graph view later is
## a rendering change, not a rewrite.
func _rebuild_skills() -> void:
	if _skill_list == null:
		return   # _ready has not run yet; the initial build is at the end of it
	for child in _skill_list.get_children():
		_skill_list.remove_child(child)
		child.queue_free()

	var available := GameState.get_skill_points_available()
	_points_label.text = "%d point%s to spend   ·   level %d" % [
		available, "" if available == 1 else "s", GameState.get_level()]

	# Roots first, then each node under the prerequisite that opens it, so the
	# order on screen is the order the player can actually take them in.
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node != null and node.is_root():
			_add_skill_row(node, 0)


func _add_skill_row(def: SkillNodeDef, depth: int) -> void:
	_skill_list.add_child(_build_skill_row(def, depth))
	for child: SkillNodeDef in SkillTree.children_of(def.id):
		# A node with two prerequisites (Woodsman needs both branches) would
		# otherwise be listed twice — show it under the LAST one it needs, so it
		# never appears above something it depends on.
		if child.requires[child.requires.size() - 1] == def.id:
			_add_skill_row(child, depth + 1)


func _build_skill_row(def: SkillNodeDef, depth: int) -> HBoxContainer:
	var level := SkillTree.get_level(def.id)
	var maxed := def.is_maxed(level)
	var locked := not SkillTree.prerequisites_met(def.id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var indent := Control.new()
	indent.custom_minimum_size = Vector2(depth * 22, 0)
	row.add_child(indent)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.text = "%s   (%d/%d)" % [def.display_name, level, def.max_level]
	text.add_child(name_label)
	var blurb := Label.new()
	blurb.add_theme_font_size_override("font_size", 12)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if locked:
		var missing: Array[StringName] = SkillTree.missing_prerequisites(def.id)
		var names: Array[String] = []
		for m: StringName in missing:
			var req := SkillTree.get_node_def(m)
			names.append(def.display_name if req == null else req.display_name)
		blurb.text = "Needs %s." % " and ".join(names)
	else:
		blurb.text = def.description
	text.add_child(blurb)
	row.add_child(text)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(96, 32)
	if maxed:
		buy.text = "Mastered"
		buy.disabled = true
	elif locked:
		buy.text = "Locked"
		buy.disabled = true
	else:
		buy.text = "%d pt%s" % [def.cost, "" if def.cost == 1 else "s"]
		buy.disabled = not SkillTree.can_buy(def.id)
		buy.pressed.connect(_on_buy_skill_pressed.bind(def.id))
	row.add_child(buy)
	return row


func _on_buy_skill_pressed(id: StringName) -> void:
	# SkillTree.buy is atomic — an unaffordable or gated node spends nothing and
	# moves nothing. The repaint rides in on skill_level_changed.
	SkillTree.buy(id)


func _refresh_xp_bar() -> void:
	if _xp_level_label == null:
		return
	var level := GameState.get_level()
	_xp_progress.value = GameState.get_level_progress()
	if GameState.is_max_level():
		_xp_level_label.text = "Level %d — master axeman" % level
		return
	var available := GameState.get_skill_points_available()
	var points := "   ·   %d pt%s" % [available, "" if available == 1 else "s"] if available > 0 else ""
	_xp_level_label.text = "Level %d   ·   %s XP to go%s" % [
		level, _thousands(GameState.get_xp_to_next_level()), points]


## ----------------------------------------------------------------- live view
func _on_cash_changed(_new_amount: int) -> void:
	_refresh_stats()
	if _shop_panel.visible:
		_rebuild_shop()   # what you can afford changed while you were looking at it


func _refresh_stats() -> void:
	_cash_label.text = str(GameState.get_cash())
