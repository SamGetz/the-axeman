extends Control
## FILE: res://scenes/2d_management/yard_hud.gd
## ATTACHES TO: YardHUD (Control), the root of res://scenes/2d_management/yard_hud.tscn.
## That scene is instanced under Main/UI_Overlay (A9: ALL gameplay UI lives in
## UI_Overlay, never inside UI_Canvas, which is the render pipeline's own layer).
##
## ALWAYS-ON CHOPPING HUD (Creative Director call, 2026-08-03). There is no
## separate yard screen. Contracts, skills and shop live in three square icon
## buttons at bottom-right while the chopping game stays on screen. Trees are a
## tab of the shop, not a second storefront.
##   ├── ShopPanel (PanelContainer, centred — hidden until the shop is opened)
##   │   └── Column (VBoxContainer)
##   │       ├── Header (HBoxContainer) → ShopIcon (TextureRect), ShopTitle (Label)
##   │       ├── ShopTabs/Items              <- equipment rows at RUNTIME
##   │       ├── ShopTabs/Trees              <- species rows at RUNTIME
##   │       └── CloseShopButton (Button)
##   ├── ModalBackdrop (ColorRect — catches clicks outside an open panel)
##   └── QuickMenu (HBoxContainer — three square icon buttons, bottom-right)
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
## THE SHOP ROWS ARE BUILT FROM DATA at runtime, from the currently visible
## prefix of `Shop.get_upgrades()` — so
## a new thing to buy is a row in `res://data/upgrade_table.tres` and nothing else.
## Prices, effect magnitudes and later block ranks remain candidate tuning until
## the measured M7A session and Sam's sign-off.
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
const _ITEMS_TAB := 0
const _TREES_TAB := 1

@onready var _cash_label: Label = $TopBar/CashRow/CashLabel
@onready var _shop_tabs: TabContainer = $ShopPanel/Column/ShopTabs
@onready var _shop_list: VBoxContainer = $ShopPanel/Column/ShopTabs/Items/ShopScroll/ShopList
@onready var _shop_empty: Label = $ShopPanel/Column/ShopTabs/Items/ShopEmpty
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _shop_button: Button = $QuickMenu/ShopButton
@onready var _shop_badge: Label = $QuickMenu/ShopButton/Badge
@onready var _close_shop_button: Button = $ShopPanel/Column/CloseShopButton
@onready var _wood_list: VBoxContainer = $ShopPanel/Column/ShopTabs/Trees/WoodScroll/WoodList
@onready var _next_wood: Label = $ShopPanel/Column/ShopTabs/Trees/NextWood
@onready var _xp_level_label: Label = $XPBar/LevelLabel
@onready var _xp_progress: ProgressBar = $XPBar/Progress
@onready var _skills_button: Button = $QuickMenu/SkillsButton
@onready var _skills_badge: Label = $QuickMenu/SkillsButton/Badge
@onready var _skill_panel: PanelContainer = $SkillPanel
@onready var _skill_boughs: HBoxContainer = $SkillPanel/Column/SkillBody/BoughScroll/Boughs
@onready var _points_label: Label = $SkillPanel/Column/Header/PointsLabel
@onready var _skill_detail_panel: PanelContainer = $SkillPanel/Column/SkillBody/DetailPanel
@onready var _skill_detail_title: Label = $SkillPanel/Column/SkillBody/DetailPanel/Column/Title
@onready var _skill_detail_meta: Label = $SkillPanel/Column/SkillBody/DetailPanel/Column/Meta
@onready var _skill_detail_description: Label = $SkillPanel/Column/SkillBody/DetailPanel/Column/Description
@onready var _skill_detail_requirements: Label = $SkillPanel/Column/SkillBody/DetailPanel/Column/Requirements
@onready var _skill_detail_status: Label = $SkillPanel/Column/SkillBody/DetailPanel/Column/Status
@onready var _skill_detail_buy: Button = $SkillPanel/Column/SkillBody/DetailPanel/Column/BuyButton
@onready var _close_skill_button: Button = $SkillPanel/Column/CloseSkillButton
@onready var _orders_button: Button = $QuickMenu/OrdersButton
@onready var _orders_panel: PanelContainer = $OrdersPanel
@onready var _orders_list: VBoxContainer = $OrdersPanel/Column/Scroll/List
@onready var _orders_active: Label = $OrdersPanel/Column/Active
@onready var _close_orders_button: Button = $OrdersPanel/Column/CloseButton
@onready var _modal_backdrop: ColorRect = $ModalBackdrop

var _selected_skill_id: StringName = &""

const _SKILL_BG := Color(0.961, 0.918, 0.847, 1.0)
const _SKILL_SURFACE := Color(0.922, 0.867, 0.773, 1.0)
const _SKILL_CARD := Color(0.976, 0.957, 0.925, 1.0)
const _SKILL_TEXT := Color(0.125, 0.118, 0.114, 1.0)
const _SKILL_MUTED := Color(0.392, 0.361, 0.314, 1.0)


func _ready() -> void:
	_shop_button.pressed.connect(_on_shop_pressed)
	_close_shop_button.pressed.connect(_on_close_shop_pressed)
	_shop_tabs.tab_changed.connect(_on_shop_tab_changed)
	_skills_button.pressed.connect(_on_skills_pressed)
	_close_skill_button.pressed.connect(_on_close_skill_pressed)
	_skill_detail_buy.pressed.connect(_on_buy_selected_skill_pressed)
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
	GameState.haul_aways_changed.connect(_on_catalogue_gate_changed.unbind(1))
	GameState.level_gained.connect(_on_catalogue_gate_changed.unbind(1))
	GameState.building_tiers_changed.connect(_on_catalogue_gate_changed)
	# A purchase moves a tier through A7's own signal, so the shelf repaints off
	# the same event that recorded the sale.
	EventBus.building_upgraded.connect(_on_building_upgraded)

	_close_panels()
	_apply_skill_theme()
	_apply_xp_orb_color()
	_refresh_stats()
	_refresh_xp_bar()
	_rebuild_shop()
	_rebuild_woodshed()
	_rebuild_skills()
	_rebuild_orders()
	_refresh_badges()


## Slice 4 uses the approved mockup's warm organic hierarchy with native Godot
## controls and the project's fallback font. Caprasimo/Figtree stay unimported
## until their separate asset/provenance gate is approved.
func _apply_skill_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", _SKILL_TEXT)
	theme.set_color("font_color", "Button", _SKILL_TEXT)
	theme.set_color("font_hover_color", "Button", _SKILL_TEXT)
	theme.set_color("font_pressed_color", "Button", _SKILL_TEXT)
	theme.set_color("font_disabled_color", "Button", Color(_SKILL_MUTED, 0.7))
	theme.set_stylebox("panel", "PanelContainer", _skill_style(_SKILL_SURFACE, _SKILL_MUTED, 12, 1))
	theme.set_stylebox("normal", "Button", _skill_style(_SKILL_CARD, Color(_SKILL_MUTED, 0.45), 8, 1))
	theme.set_stylebox("hover", "Button", _skill_style(_SKILL_BG, _SKILL_MUTED, 8, 2))
	theme.set_stylebox("pressed", "Button", _skill_style(_SKILL_SURFACE, _SKILL_MUTED, 8, 2))
	theme.set_stylebox("disabled", "Button", _skill_style(Color(_SKILL_CARD, 0.55), Color(_SKILL_MUTED, 0.25), 8, 1))
	_skill_panel.theme = theme
	_skill_panel.add_theme_stylebox_override("panel", _skill_style(_SKILL_BG, _SKILL_MUTED, 18, 2, 16))
	_skill_detail_panel.add_theme_stylebox_override("panel", _skill_style(_SKILL_CARD, Color(_SKILL_MUTED, 0.5), 12, 1, 12))


func _skill_style(fill: Color, border: Color, radius: int, border_width: int,
		margin: float = 8.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style


## XPOrb owns the reward colour. The HUD reads it rather than copying the value,
## so a future orb art pass cannot leave the progress bar behind.
func _apply_xp_orb_color() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = XPOrb.COLOR
	_xp_progress.add_theme_stylebox_override("fill", fill)


## -------------------------------------------------------------- modal panels
func _open_panel(panel: Control) -> void:
	_close_panels()
	_modal_backdrop.visible = true
	panel.visible = true


func _close_panels() -> void:
	_shop_panel.visible = false
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
	_rebuild_woodshed()


func _on_shop_tab_changed(_tab: int) -> void:
	if _shop_tabs.current_tab == _TREES_TAB:
		_rebuild_woodshed()
	else:
		_rebuild_shop()


func _on_close_shop_pressed() -> void:
	_close_panels()


func _on_building_upgraded(_id: StringName, _tier: int) -> void:
	_rebuild_shop()


func _on_catalogue_gate_changed() -> void:
	_rebuild_shop()
	_rebuild_orders()
	_rebuild_woodshed()
	_refresh_badges()


## One row per upgrade, straight from the table: what it is, what it does, what
## level you are on and what the next one costs.
func _rebuild_shop() -> void:
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()

	var upgrades := Shop.get_visible_upgrades()
	_shop_empty.visible = upgrades.is_empty()
	for def: UpgradeDef in upgrades:
		if def != null:
			_shop_list.add_child(_build_shop_row(def))
	_refresh_badges()


func _build_shop_row(def: UpgradeDef) -> VBoxContainer:
	var level := Shop.get_level(def.id)
	var maxed := def.is_maxed(level)
	var unlocked := Shop.is_unlocked(def.id)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	var rank_word := "rank" if def.purchase_form == UpgradeDef.PurchaseForm.TIERED else "owned"
	name_label.text = "%s  (%s %d)" % [def.display_name, rank_word, level]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(92, 34)   # room for the coin beside the price
	if not unlocked:
		buy.text = _upgrade_unlock_text(def)
		buy.disabled = true
	elif maxed:
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
	if def.limitation != "":
		var limit := Label.new()
		limit.text = "Limit: " + def.limitation
		limit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		limit.add_theme_font_size_override("font_size", 12)
		limit.modulate = Color(0.78, 0.78, 0.78, 1.0)
		row.add_child(limit)
	return row


func _upgrade_unlock_text(def: UpgradeDef) -> String:
	if def.unlock_after_haul_aways > GameState.get_haul_aways_completed():
		return "After first haul"
	if def.unlock_order_id != &"" and not GameState.has_completed_order(def.unlock_order_id):
		var order := Orders.by_id(def.unlock_order_id)
		return "After %s" % (String(def.unlock_order_id) if order == null else order.title)
	return "Locked"


func _on_buy_pressed(id: StringName) -> void:
	# Shop.buy is atomic: a refused purchase spends nothing and moves no tier, so
	# there is nothing to undo here. The rebuild rides in on building_upgraded.
	Shop.buy(id)


## Driven by the SIGNALS rather than by the row that was clicked, so the button
## and the list agree however the choice moved — including a selection GameState
## refused, which emits nothing and correctly leaves the display alone.
func _on_selected_species_changed(_id: StringName) -> void:
	if _shop_panel.visible and _shop_tabs.current_tab == _TREES_TAB:
		_rebuild_woodshed()


func _on_species_purchased(_id: StringName) -> void:
	_rebuild_woodshed()
	_rebuild_orders()
	_refresh_badges()


## XP moves the level, and the level is what puts a wood on sale — so the shed's
## "needs level N" rows can go live without the player touching anything. Only
## repaints an OPEN panel: this fires once per finished log.
func _on_xp_changed(_total: int) -> void:
	_refresh_xp_bar()
	if _shop_panel.visible and _shop_tabs.current_tab == _TREES_TAB:
		_rebuild_woodshed()
	if _skill_panel.visible:
		_rebuild_skills()
	_refresh_badges()


func _on_skill_points_changed(_available: int) -> void:
	_refresh_xp_bar()
	if _skill_panel.visible:
		_rebuild_skills()
	_refresh_badges()


func _on_skill_level_changed(_id: StringName, _level: int) -> void:
	_rebuild_skills()
	_refresh_badges()


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
		var supplier_missing := next.supplier_upgrade_id != &"" and Shop.get_level(next.supplier_upgrade_id) <= 0
		if supplier_missing:
			var supplier := Shop.get_upgrade(next.supplier_upgrade_id)
			_next_wood.text = "Next: %s — requires %s before it can be ordered." % [
				next.display_name,
				String(next.supplier_upgrade_id) if supplier == null else supplier.display_name,
			]
		elif levels > 0:
			_next_wood.text = "Next: %s — reach level %d to put it up for sale (%d to go)." % [
				next.display_name, next.unlock_level, levels]
		else:
			_wood_list.add_child(_build_wood_row(next, false))
			_next_wood.text = "%s is in stock at the gate — %s to buy it." % [
				next.display_name, _thousands(next.unlock_cost)]


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
		pick.disabled = not GameState.can_species_be_bought(def.id) or not GameState.can_afford_cash(def.unlock_cost)
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
	_rebuild_shop()
	_refresh_badges()


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

	for order: OrderDef in Orders.visible():
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
	if not Orders.is_revealed(order):
		button.text = "Reveals at level %d" % order.unlock_level
		button.disabled = true
	elif GameState.has_completed_order(order.id):
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


## Three native boughs, authored by SkillBranchDef and SkillNodeDef semantic
## positions. Display strings never decide branch, role, proc family or layout.
func _rebuild_skills() -> void:
	if _skill_boughs == null:
		return   # _ready has not run yet; the initial build is at the end of it
	for child in _skill_boughs.get_children():
		_skill_boughs.remove_child(child)
		child.queue_free()

	var available := GameState.get_skill_points_available()
	_points_label.text = "%d point%s   ·   level %d" % [
		available, "" if available == 1 else "s", GameState.get_level()]

	for branch: SkillBranchDef in M7CContent.branches().branches:
		if branch != null:
			_skill_boughs.add_child(_build_skill_bough(branch))

	if SkillTree.get_node_def(_selected_skill_id) == null:
		_selected_skill_id = _default_selected_skill()
	_refresh_skill_detail()


func _build_skill_bough(branch: SkillBranchDef) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = String(branch.id).to_pascal_case() + "Bough"
	panel.custom_minimum_size = Vector2(224, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pale := branch.color.lerp(_SKILL_CARD, 0.82)
	panel.add_theme_stylebox_override("panel", _skill_style(pale, branch.color.darkened(0.2), 12, 2, 10))
	panel.set_meta("branch_id", branch.id)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)

	var title := Label.new()
	title.text = branch.display_name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", branch.color.darkened(0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var copy := Label.new()
	copy.text = branch.description
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 10)
	copy.add_theme_color_override("font_color", _SKILL_MUTED)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(copy)

	var nodes: Array[SkillNodeDef] = []
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node != null and node.branch_id == branch.id:
			nodes.append(node)
	nodes.sort_custom(func(a: SkillNodeDef, b: SkillNodeDef) -> bool:
		if a.presentation_position.y == b.presentation_position.y:
			return a.presentation_position.x < b.presentation_position.x
		return a.presentation_position.y < b.presentation_position.y)

	for i in range(nodes.size()):
		if i > 0:
			var connector := ColorRect.new()
			connector.custom_minimum_size = Vector2(0, 3)
			connector.color = Color(branch.color, 0.45)
			connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(connector)
		column.add_child(_build_skill_node_button(nodes[i], branch))

	if nodes.is_empty():
		var empty := Label.new()
		empty.text = "This bough is awaiting its first authored node."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 11)
		column.add_child(empty)
	return panel


func _build_skill_node_button(def: SkillNodeDef, branch: SkillBranchDef) -> Button:
	var level := SkillTree.get_level(def.id)
	var maxed := def.is_maxed(level)
	var locked := not SkillTree.prerequisites_met(def.id)
	var state := "available"
	var state_label := "Available"
	if maxed:
		state = "mastered"
		state_label = "Mastered"
	if locked:
		state = "locked"
		state_label = "Locked"
	elif level > 0:
		state = "learned"
		state_label = "Learned"
	elif not SkillTree.can_buy(def.id):
		state = "insufficient"
		state_label = "Need points"

	var button := Button.new()
	button.name = String(def.id).to_pascal_case()
	button.custom_minimum_size = Vector2(0, 66)
	button.text = "%s\n%d/%d  ·  %s" % [def.display_name, level, def.max_level, state_label]
	# Compact cards already own an explicit line break. Godot's smart wrapping
	# can elide the middle of a selected two-word label at this width (observed as
	# "QStudy" in the 1280x720 render), so do not ask it to reshape this text.
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = def.description
	button.set_meta("skill_id", def.id)
	button.set_meta("skill_state", state)
	button.pressed.connect(_on_select_skill_pressed.bind(def.id))

	var fill := _SKILL_CARD
	if state == "learned" or state == "mastered":
		fill = branch.color.lerp(_SKILL_CARD, 0.68)
	elif state == "locked":
		fill = Color(_SKILL_CARD, 0.55)
	var width := 3 if def.id == _selected_skill_id else 1
	button.add_theme_stylebox_override("normal", _skill_style(fill, branch.color.darkened(0.15), 8, width, 8))
	button.add_theme_stylebox_override("hover", _skill_style(branch.color.lerp(_SKILL_CARD, 0.78), branch.color, 8, 2, 8))
	button.add_theme_stylebox_override("pressed", _skill_style(branch.color.lerp(_SKILL_CARD, 0.62), branch.color.darkened(0.2), 8, 3, 8))
	return button


func _on_select_skill_pressed(id: StringName) -> void:
	_selected_skill_id = id
	_rebuild_skills()


func _default_selected_skill() -> StringName:
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node != null and SkillTree.can_buy(node.id):
			return node.id
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node != null:
			return node.id
	return &""


func _refresh_skill_detail() -> void:
	var def := SkillTree.get_node_def(_selected_skill_id)
	if def == null:
		_skill_detail_title.text = "Select a skill"
		_skill_detail_meta.text = ""
		_skill_detail_description.text = ""
		_skill_detail_requirements.text = ""
		_skill_detail_status.text = ""
		_skill_detail_buy.text = "Select a skill"
		_skill_detail_buy.disabled = true
		return

	var branch := M7CContent.branches().by_id(def.branch_id)
	var level := SkillTree.get_level(def.id)
	var maxed := def.is_maxed(level)
	var locked := not SkillTree.prerequisites_met(def.id)
	_skill_detail_title.text = def.display_name
	_skill_detail_meta.text = "%s  ·  %s  ·  rank %d/%d" % [
		String(def.branch_id).capitalize() if branch == null else branch.display_name,
		_node_type_label(def.node_type), level, def.max_level]
	_skill_detail_description.text = def.description

	var requirement_names: Array[String] = []
	for missing: StringName in SkillTree.missing_prerequisites(def.id):
		var required := SkillTree.get_node_def(missing)
		requirement_names.append(String(missing) if required == null else required.display_name)
	_skill_detail_requirements.text = "Prerequisite: none" if def.requires.is_empty() else (
		"Still needs: %s" % " and ".join(requirement_names) if not requirement_names.is_empty()
		else "Prerequisites learned")

	if maxed:
		_skill_detail_status.text = "This skill is mastered."
		_skill_detail_buy.text = "Mastered"
		_skill_detail_buy.disabled = true
	elif locked:
		_skill_detail_status.text = "Learn the prerequisite before spending here."
		_skill_detail_buy.text = "Locked"
		_skill_detail_buy.disabled = true
	elif not SkillTree.can_buy(def.id):
		_skill_detail_status.text = "You have %d; the next rank costs %d." % [
			GameState.get_skill_points_available(), def.cost]
		_skill_detail_buy.text = "Need %d point%s" % [def.cost, "" if def.cost == 1 else "s"]
		_skill_detail_buy.disabled = true
	else:
		_skill_detail_status.text = "Spend one earned skill point choice here."
		_skill_detail_buy.text = "Learn rank %d  ·  %d pt%s" % [
			level + 1, def.cost, "" if def.cost == 1 else "s"]
		_skill_detail_buy.disabled = false


func _node_type_label(node_type: SkillNodeDef.NodeType) -> String:
	match node_type:
		SkillNodeDef.NodeType.FOUNDATION:
			return "Foundation"
		SkillNodeDef.NodeType.PROC:
			return "Proc"
		SkillNodeDef.NodeType.MODIFIER:
			return "Modifier"
		SkillNodeDef.NodeType.CAPSTONE:
			return "Capstone"
	return "Unknown"


func _on_buy_selected_skill_pressed() -> void:
	if _selected_skill_id != &"":
		SkillTree.buy(_selected_skill_id)


## Deterministic shot/acceptance seam: selection only, no ownership mutation.
func debug_select_skill(id: StringName) -> bool:
	if SkillTree.get_node_def(id) == null:
		return false
	_selected_skill_id = id
	_rebuild_skills()
	return true


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
	_refresh_badges()
	if _shop_panel.visible:
		if _shop_tabs.current_tab == _ITEMS_TAB:
			_rebuild_shop()
		else:
			_rebuild_woodshed()


func _refresh_stats() -> void:
	_cash_label.text = str(GameState.get_cash())


## Red icon badges are a call to action, not a second economy display. Skills
## shows unspent points; Shop counts only purchases the player can make NOW
## across both Items and Trees.
func _refresh_badges() -> void:
	if _skills_badge == null or _shop_badge == null:
		return
	_set_badge(_skills_badge, GameState.get_skill_points_available())
	var affordable := 0
	for def: UpgradeDef in Shop.get_visible_upgrades():
		if def != null and Shop.can_buy(def.id):
			affordable += 1
	var next := GameState.get_next_unowned_species()
	if next != null and GameState.can_species_be_bought(next.id) \
			and GameState.can_afford_cash(next.unlock_cost):
		affordable += 1
	_set_badge(_shop_badge, affordable)


func _set_badge(badge: Label, amount: int) -> void:
	badge.visible = amount > 0
	badge.text = "99+" if amount > 99 else str(amount)
