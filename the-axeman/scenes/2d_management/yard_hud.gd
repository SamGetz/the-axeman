extends Control
## FILE: res://scenes/2d_management/yard_hud.gd
## ATTACHES TO: YardHUD (Control), the root of res://scenes/2d_management/yard_hud.tscn.
## That scene is instanced under Main/UI_Overlay (A9: ALL gameplay UI lives in
## UI_Overlay, never inside UI_Canvas, which is the render pipeline's own layer).
##
## ALWAYS-ON CHOPPING HUD (Creative Director call, 2026-08-03). There is no
## separate yard screen. Contracts, skills, shop and the frequently checked Tree
## Catalog live in four square icon buttons at bottom-right while the chopping
## game stays on screen.
##   ├── ShopPanel (PanelContainer, centred — hidden until the shop is opened)
##   │   └── Column (VBoxContainer)
##   │       ├── Header (HBoxContainer) → ShopIcon (TextureRect), ShopTitle (Label)
##   │       ├── ShopTabs/Items              <- equipment rows at RUNTIME
##   │       ├── ShopTabs/Splitter           <- M8 machine/profile rows at RUNTIME
##   │       ├── ShopTabs/Purchased          <- completed rows, derived read-only
##   │       └── CloseShopButton (Button)
##   ├── TreesPanel                           <- species/mastery/assignment rows
##   ├── SplitterRuntimeCard                  <- watched one-slot cycle state
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
## THE SHOP ROWS ARE BUILT FROM DATA at runtime, from currently unlocked
## `Shop.get_upgrades()` entries — so
## a new thing to buy is a row in `res://data/upgrade_table.tres` and nothing else.
## Prices, effect magnitudes and later block ranks remain candidate tuning until
## the measured M7A session and Sam's sign-off.
##
## THE TREE CATALOG, added 2026-08-02 (Creative Director call: the player PICKS the
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

signal displayed_level_gained(new_level: int)

const _COIN := preload("res://assets/ui/coin.png")
const _SPLITTER_TAB := 1
const _PURCHASED_TAB := 2
const _OPEN_ORDERS_TAB := 0
const _COMMISSIONS_TAB := 1
const _COMPLETED_ORDERS_TAB := 2

@onready var _cash_label: Label = $TopBar/CashRow/CashLabel
@onready var _earth_trees_label: Label = $EarthTreesRemaining
@onready var _campaign_goal: PanelContainer = $CampaignGoal
@onready var _campaign_goal_phase: Label = $CampaignGoal/Column/Phase
@onready var _campaign_goal_title: Label = $CampaignGoal/Column/Title
@onready var _campaign_goal_detail: Label = $CampaignGoal/Column/Detail
@onready var _campaign_goal_progress: ProgressBar = $CampaignGoal/Column/Progress
@onready var _campaign_goal_progress_text: Label = $CampaignGoal/Column/ProgressText
@onready var _credits_panel: ColorRect = $CreditsPanel
@onready var _credits_column: VBoxContainer = $CreditsPanel/CreditsColumn
@onready var _credits_stats: Label = $CreditsPanel/CreditsColumn/Stats
@onready var _credits_close: Button = $CreditsPanel/CreditsColumn/ContinueButton
@onready var _feature_introduction: Label = $FeatureIntroduction
@onready var _feature_introduction_timer: Timer = $FeatureIntroductionTimer
@onready var _craft_feedback: Label = $CraftFeedback
@onready var _splitter_runtime_state: Label = $SplitterRuntimeCard/Column/State
@onready var _splitter_runtime_card: PanelContainer = $SplitterRuntimeCard
@onready var _splitter_runtime_detail: Label = $SplitterRuntimeCard/Column/Detail
@onready var _splitter_runtime_progress: ProgressBar = $SplitterRuntimeCard/Column/Progress
@onready var _splitter_runtime_action: Button = $SplitterRuntimeCard/Column/Action
@onready var _splitter_runtime_receipt: Label = $SplitterRuntimeCard/Column/Receipt
@onready var _shop_tabs: TabContainer = $ShopPanel/Column/ShopTabs
@onready var _shop_list: VBoxContainer = $ShopPanel/Column/ShopTabs/Items/ShopScroll/ShopList
@onready var _shop_empty: Label = $ShopPanel/Column/ShopTabs/Items/ShopEmpty
@onready var _shop_unlock_hint: Label = $ShopPanel/Column/ShopTabs/Items/UnlockHint
@onready var _splitter_list: VBoxContainer = $ShopPanel/Column/ShopTabs/Splitter/Scroll/List
@onready var _splitter_empty: Label = $ShopPanel/Column/ShopTabs/Splitter/Empty
@onready var _splitter_status: Label = $ShopPanel/Column/ShopTabs/Splitter/Status
@onready var _purchased_list: VBoxContainer = $ShopPanel/Column/ShopTabs/Purchased/Scroll/List
@onready var _purchased_empty: Label = $ShopPanel/Column/ShopTabs/Purchased/Empty
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _shop_button: Button = $QuickMenu/ShopButton
@onready var _shop_badge: Label = $QuickMenu/ShopButton/Badge
@onready var _close_shop_button: Button = $ShopPanel/Column/CloseShopButton
@onready var _trees_panel: PanelContainer = $TreesPanel
@onready var _trees_button: Button = $QuickMenu/TreesButton
@onready var _trees_badge: Label = $QuickMenu/TreesButton/Badge
@onready var _trees_blurb: Label = $TreesPanel/Column/Blurb
@onready var _close_trees_button: Button = $TreesPanel/Column/CloseButton
@onready var _wood_list: VBoxContainer = $TreesPanel/Column/WoodScroll/WoodList
@onready var _next_wood: Label = $TreesPanel/Column/NextWood
@onready var _xp_level_label: Label = $XPBar/LevelLabel
@onready var _xp_progress: ProgressBar = $XPBar/Progress
@onready var _skills_button: Button = $QuickMenu/SkillsButton
@onready var _skills_badge: Label = $QuickMenu/SkillsButton/Badge
@onready var _skill_panel: PanelContainer = $SkillPanel
@onready var _skill_branch_tabs: TabBar = $SkillPanel/Column/BranchTabs
@onready var _skill_boughs: HBoxContainer = $SkillPanel/Column/SkillBody/BoughScroll/Boughs
@onready var _points_label: Label = $SkillPanel/Column/Header/PointsLabel
@onready var _skill_respec_button: Button = $SkillPanel/Column/SkillFooter/RespecButton
@onready var _close_skill_button: Button = $SkillPanel/Column/CloseSkillButton
@onready var _orders_button: Button = $QuickMenu/OrdersButton
@onready var _orders_badge: Label = $QuickMenu/OrdersButton/Badge
@onready var _atlas_button: Button = $QuickMenu/AtlasButton
@onready var _atlas_panel: PanelContainer = $AtlasPanel
@onready var _atlas_list: VBoxContainer = $AtlasPanel/Column/Scroll/List
@onready var _close_atlas_button: Button = $AtlasPanel/Column/CloseButton
@onready var _earth_master_headline: Control = $EarthMasterHeadline
@onready var _orders_panel: PanelContainer = $OrdersPanel
@onready var _orders_tabs: TabContainer = $OrdersPanel/Column/Tabs
@onready var _orders_list: VBoxContainer = $OrdersPanel/Column/Tabs/Open/Scroll/List
@onready var _commissions_list: VBoxContainer = $OrdersPanel/Column/Tabs/Commissions/Scroll/List
@onready var _commissions_empty: Label = $OrdersPanel/Column/Tabs/Commissions/Empty
@onready var _orders_completed_list: VBoxContainer = $OrdersPanel/Column/Tabs/Completed/Scroll/List
@onready var _orders_active: Label = $OrdersPanel/Column/Active
@onready var _close_orders_button: Button = $OrdersPanel/Column/CloseButton
@onready var _modal_backdrop: ColorRect = $ModalBackdrop
@onready var _active_job_chip: PanelContainer = $ActiveJobChip
@onready var _active_job_button: Button = $ActiveJobChip/Column/Header/Button
@onready var _active_job_toggle: Button = $ActiveJobChip/Column/Header/Toggle
@onready var _active_job_scroll: ScrollContainer = $ActiveJobChip/Column/Scroll
@onready var _active_job_list: VBoxContainer = $ActiveJobChip/Column/Scroll/List
@onready var _delivery_receipt: PanelContainer = $DeliveryReceipt
@onready var _delivery_receipt_title: Label = $DeliveryReceipt/Column/Title
@onready var _delivery_receipt_detail: Label = $DeliveryReceipt/Column/Detail
@onready var _tutorial: TutorialDirector = $TutorialOverlay

var _splitter_runtime: MechanicalSplitterRuntime
var _displayed_xp_total := 0
var _pending_orb_xp := 0
var _inflight_orb_xp := 0
var _xp_delivery_queue: Array[int] = []
var _xp_delivery_animating := false
var _xp_delivery_generation := 0
var _xp_level_up_hold_level := 0
var _displayed_skill_points_earned := 0
var _pending_skill_point_rewards: Dictionary = {}
var _displayed_cash := 0
var _pending_coin_count := 0
var _cash_ui_refresh_queued := false
var _xp_delivery_flush_queued := false
var _cash_bounce_tween: Tween
var _xp_pulse_tween: Tween
var _craft_feedback_tween: Tween
var _delivery_receipt_tween: Tween
var _delivery_receipt_pending: Array[Dictionary] = []
var _delivery_receipt_queue: Array[Dictionary] = []
var _delivery_receipt_flush_queued := false
var _delivery_receipt_showing := false
var _active_tasks_collapsed := true
var _presented_skill_branch: StringName = &""
var _rebuilding_skill_tabs := false

# PLACEHOLDER — adaptive non-blocking receipt timing pending measured review.
const _RECEIPT_SINGLE_HOLD := 2.2
const _RECEIPT_AGGREGATE_HOLD := 2.8
const _RECEIPT_PER_EXTRA_HOLD := 0.45
const _RECEIPT_FADE := 0.4

const _SKILL_BG := Color(0.961, 0.918, 0.847, 1.0)
const _SKILL_SURFACE := Color(0.922, 0.867, 0.773, 1.0)
const _SKILL_CARD := Color(0.976, 0.957, 0.925, 1.0)
const _SKILL_TEXT := Color(0.125, 0.118, 0.114, 1.0)
const _SKILL_MUTED := Color(0.392, 0.361, 0.314, 1.0)
const _SKILL_PANEL_MIN_HEIGHT := 340.0
const _SKILL_PANEL_MAX_HEIGHT := 640.0
const _SKILL_PANEL_CHROME_HEIGHT := 200.0
const _TUTORIAL_ARMED_ID := &"tutorial_armed"
const _TUTORIAL_STARTED_ID := &"tutorial_started"
const _TUTORIAL_OPENING_COMPLETE_ID := &"tutorial_opening_complete"
const _TUTORIAL_SKIPPED_ID := &"tutorial_all_skipped"

var _xp_pacing: XPPacingConfig


func _ready() -> void:
	_xp_pacing = GameConfig.current().xp_pacing
	_displayed_xp_total = GameState.get_xp()
	_displayed_skill_points_earned = GameState.get_skill_points_earned()
	_displayed_cash = GameState.get_cash()
	_splitter_runtime_action.pressed.connect(_on_splitter_runtime_action_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	_close_shop_button.pressed.connect(_on_close_shop_pressed)
	_shop_tabs.tab_changed.connect(_on_shop_tab_changed)
	_shop_tabs.set_tab_title(_SPLITTER_TAB, "Mechanical Splitter")
	_shop_tabs.set_tab_title(_PURCHASED_TAB, "Purchased")
	_trees_button.pressed.connect(_on_trees_pressed)
	_close_trees_button.pressed.connect(_on_close_trees_pressed)
	_skills_button.pressed.connect(_on_skills_pressed)
	_close_skill_button.pressed.connect(_on_close_skill_pressed)
	_skill_respec_button.pressed.connect(_on_respec_skills_pressed)
	_skill_branch_tabs.tab_changed.connect(_on_skill_branch_tab_changed)
	_orders_button.pressed.connect(_on_orders_pressed)
	_active_job_button.pressed.connect(_on_active_job_pressed)
	_active_job_toggle.pressed.connect(_on_active_job_toggle_pressed)
	_close_orders_button.pressed.connect(_on_close_orders_pressed)
	_atlas_button.pressed.connect(_on_atlas_pressed)
	_close_atlas_button.pressed.connect(_on_player_closed_panels)
	_orders_tabs.set_tab_title(_OPEN_ORDERS_TAB, "Open")
	_orders_tabs.set_tab_title(_COMMISSIONS_TAB, "Commissions")
	_orders_tabs.set_tab_title(_COMPLETED_ORDERS_TAB, "Completed")
	_modal_backdrop.gui_input.connect(_on_modal_backdrop_gui_input)

	GameState.cash_changed.connect(_on_cash_changed)
	GameState.lifetime_cash_earned_changed.connect(
		_on_lifetime_cash_earned_changed)
	# The Tree Catalog's three live inputs, all local signals (Amendment 2's
	# precedent), so nothing here polls: what the player picked, what they have
	# just earned, and the counter the next milestone is measured against.
	GameState.selected_species_changed.connect(_on_selected_species_changed)
	GameState.species_purchased.connect(_on_species_purchased)
	GameState.species_mastery_changed.connect(_on_species_mastery_changed)
	GameState.splitter_assignment_changed.connect(_on_splitter_assignment_changed)
	# XP moves the level, the level opens woods AND pays for skills, so both
	# panels and the bar ride on it.
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.skill_points_changed.connect(_on_skill_points_changed)
	GameState.level_reward_granted.connect(_on_level_reward_granted)
	GameState.skill_level_changed.connect(_on_skill_level_changed)
	GameState.order_state_changed.connect(_on_order_state_changed)
	GameState.order_completed.connect(_on_order_completed)
	GameState.commission_state_changed.connect(_on_commission_state_changed)
	GameState.commission_completed.connect(_on_commission_completed)
	GameState.reputation_changed.connect(_on_reputation_changed)
	GameState.manual_piece_settled.connect(_on_manual_piece_settled)
	GameState.regional_network_changed.connect(_on_regional_network_changed)
	GameState.company_strategy_changed.connect(_on_company_strategy_changed)
	GameState.earth_campaign_changed.connect(_on_earth_campaign_changed)
	GameState.earth_trees_changed.connect(_on_earth_trees_changed)
	GameState.earth_finale_completed.connect(_on_earth_finale_completed)
	GameState.launch_program_changed.connect(_on_launch_program_changed)
	GameState.expedition_changed.connect(_on_launch_program_changed)
	GameState.alien_campaign_changed.connect(_on_launch_program_changed)
	GameState.campaign_goal_changed.connect(_on_campaign_goal_changed)
	GameState.campaign_phase_changed.connect(_on_campaign_phase_changed)
	GameState.campaign_completed.connect(_show_campaign_credits)
	GameState.haul_aways_changed.connect(_on_catalogue_gate_changed.unbind(1))
	GameState.building_tiers_changed.connect(_on_catalogue_gate_changed)
	GameState.feature_introduced.connect(_on_feature_introduced)
	# A purchase moves a tier through A7's own signal, so the shelf repaints off
	# the same event that recorded the sale.
	EventBus.building_upgraded.connect(_on_building_upgraded)
	_feature_introduction_timer.timeout.connect(
		func() -> void: _feature_introduction.visible = false)
	_credits_close.pressed.connect(_on_close_credits_pressed)

	_close_panels()
	_apply_skill_theme()
	_apply_xp_orb_color()
	_refresh_stats()
	_refresh_earth_trees()
	_refresh_campaign_goal(GameState.get_campaign_goal_snapshot())
	_refresh_reveal_visibility()
	_refresh_xp_bar()
	_rebuild_shop()
	_rebuild_woodshed()
	_rebuild_skills()
	_rebuild_orders()
	_rebuild_atlas()
	_refresh_active_job_chip()
	_refresh_badges()
	_refresh_splitter_runtime_card()


func bind_splitter_runtime(runtime: MechanicalSplitterRuntime) -> void:
	if _splitter_runtime != null:
		if _splitter_runtime.state_changed.is_connected(_on_splitter_runtime_state_changed):
			_splitter_runtime.state_changed.disconnect(_on_splitter_runtime_state_changed)
		if _splitter_runtime.progress_changed.is_connected(_on_splitter_runtime_progress_changed):
			_splitter_runtime.progress_changed.disconnect(_on_splitter_runtime_progress_changed)
		if _splitter_runtime.cycle_completed.is_connected(_on_splitter_cycle_completed):
			_splitter_runtime.cycle_completed.disconnect(_on_splitter_cycle_completed)
	_splitter_runtime = runtime
	if _splitter_runtime != null:
		_splitter_runtime.state_changed.connect(_on_splitter_runtime_state_changed)
		_splitter_runtime.progress_changed.connect(_on_splitter_runtime_progress_changed)
		_splitter_runtime.cycle_completed.connect(_on_splitter_cycle_completed)
	_refresh_splitter_runtime_card()


func begin_tutorial(is_fresh_game: bool) -> void:
	_tutorial.begin_for_session(is_fresh_game, self)


func tutorial_director() -> TutorialDirector:
	return _tutorial


## The chopping scene owns orb timing; this HUD owns only their screen target and
## the displayed (never authoritative) XP total while those receipts are moving.
func bind_xp_source(source: Node) -> void:
	if source == null:
		return
	var batch_callback := Callable(self, "_on_xp_orb_batch_started")
	var collected_callback := Callable(self, "_on_xp_orb_collected")
	if not source.is_connected(&"xp_orb_batch_started", batch_callback):
		source.connect(&"xp_orb_batch_started", batch_callback)
	if not source.is_connected(&"xp_orb_collected", collected_callback):
		source.connect(&"xp_orb_collected", collected_callback)
	var level_callback := Callable(source, "present_level_gain")
	if source.has_method("present_level_gain") \
			and not displayed_level_gained.is_connected(level_callback):
		displayed_level_gained.connect(level_callback)
	var coin_batch_callback := Callable(self, "_on_coin_batch_started")
	var coin_collected_callback := Callable(self, "_on_coin_collected")
	var coins_cancelled_callback := Callable(self, "_on_coins_cancelled")
	var coin_finished_callback := Callable(self, "_on_coin_batch_finished")
	if not source.is_connected(&"coin_batch_started", coin_batch_callback):
		source.connect(&"coin_batch_started", coin_batch_callback)
	if not source.is_connected(&"coin_collected", coin_collected_callback):
		source.connect(&"coin_collected", coin_collected_callback)
	if not source.is_connected(&"coins_cancelled", coins_cancelled_callback):
		source.connect(&"coins_cancelled", coins_cancelled_callback)
	if not source.is_connected(&"coin_batch_finished", coin_finished_callback):
		source.connect(&"coin_batch_finished", coin_finished_callback)
	source.call("set_xp_screen_target", Callable(self, "xp_orb_target_normalized"))
	source.call("set_coin_screen_target", Callable(self, "coin_target_normalized"))


func _on_splitter_runtime_state_changed(_state: MechanicalSplitterRuntime.State) -> void:
	_refresh_splitter_runtime_card()


func _on_splitter_runtime_progress_changed(value: float) -> void:
	_splitter_runtime_progress.value = value


func _on_splitter_cycle_completed(_species_id: StringName, item_id: StringName,
		amount: int, _receipt_id: StringName) -> void:
	var item := InventoryManager.get_item_def(item_id)
	var item_name := String(item_id) if item == null else item.display_name
	_splitter_runtime_receipt.text = "Sold %d %s · +%d cash · +%d XP" % [
		amount, item_name, _splitter_runtime.last_cash_earned(),
		_splitter_runtime.last_xp_earned()]
	_refresh_splitter_runtime_card(false)


func _on_splitter_runtime_action_pressed() -> void:
	var state := MechanicalSplitterRuntime.State.LOCKED if _splitter_runtime == null \
		else _splitter_runtime.current_state()
	match state:
		MechanicalSplitterRuntime.State.LOCKED, \
				MechanicalSplitterRuntime.State.MISSING_PROFILE:
			_open_splitter_shop()
		MechanicalSplitterRuntime.State.UNASSIGNED:
			_on_trees_pressed()
		MechanicalSplitterRuntime.State.OUTPUT_BLOCKED:
			_splitter_runtime.retry_blocked_output()
		MechanicalSplitterRuntime.State.READY:
			if _splitter_runtime.try_queue_assigned_input():
				_tutorial.notify_hud_action(&"splitter_loaded")


func _refresh_splitter_runtime_card(reset_receipt := true) -> void:
	_splitter_runtime_card.visible = MechanicalSplitter.is_installed()
	if not _splitter_runtime_card.visible:
		return
	var state := MechanicalSplitterRuntime.State.LOCKED
	if _splitter_runtime != null:
		state = _splitter_runtime.current_state()
	elif MechanicalSplitter.is_installed():
		var assigned := GameState.get_splitter_assigned_species()
		state = MechanicalSplitterRuntime.State.UNASSIGNED if assigned == &"" \
			else MechanicalSplitterRuntime.State.READY
	_splitter_runtime_state.text = MechanicalSplitterRuntime.state_title(state)
	_splitter_runtime_progress.value = 0.0 if _splitter_runtime == null \
		else _splitter_runtime.progress()
	if _splitter_runtime != null:
		_splitter_runtime_detail.text = _splitter_runtime.state_detail()
	else:
		_splitter_runtime_detail.text = "Purchase the machine in Shop." if state == \
			MechanicalSplitterRuntime.State.LOCKED else "Watched runtime is not bound."
	_splitter_runtime_action.disabled = true
	match state:
		MechanicalSplitterRuntime.State.LOCKED:
			_splitter_runtime_action.text = "Buy in Shop"
			_splitter_runtime_action.disabled = false
		MechanicalSplitterRuntime.State.UNASSIGNED:
			_splitter_runtime_action.text = "Assign in Tree Catalog"
			_splitter_runtime_action.disabled = false
		MechanicalSplitterRuntime.State.MISSING_PROFILE:
			_splitter_runtime_action.text = "Install assigned profile"
			_splitter_runtime_action.disabled = false
		MechanicalSplitterRuntime.State.READY:
			if _splitter_runtime != null and _splitter_runtime.auto_loading_enabled():
				_splitter_runtime_action.text = "Auto loading enabled"
			else:
				_splitter_runtime_action.text = "Load assigned log"
				_splitter_runtime_action.disabled = _splitter_runtime == null \
					or not _splitter_runtime.is_yard_active()
		MechanicalSplitterRuntime.State.PROCESSING:
			_splitter_runtime_action.text = "Input slot full · Processing"
		MechanicalSplitterRuntime.State.OUTPUT_BLOCKED:
			_splitter_runtime_action.text = "Retry blocked output"
			_splitter_runtime_action.disabled = _splitter_runtime == null
		MechanicalSplitterRuntime.State.EXHAUSTED:
			_splitter_runtime_action.text = "Earth exhausted"
	if reset_receipt:
		if state == MechanicalSplitterRuntime.State.EXHAUSTED:
			_splitter_runtime_receipt.text = "Terrestrial production ended · stock remains sellable"
		elif _splitter_runtime != null and _splitter_runtime.has_completed_receipt():
			_splitter_runtime_receipt.text = "Last cycle · %d log(s) · +%d cash · +%d XP" % [
				_splitter_runtime.last_logs_processed(),
				_splitter_runtime.last_cash_earned(),
				_splitter_runtime.last_xp_earned()]
		else:
			var queued := 0 if _splitter_runtime == null else _splitter_runtime.queued_count()
			_splitter_runtime_receipt.text = "Input %d / 1 · watched yard time only" % queued


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
	_refresh_active_job_chip()


func _close_panels() -> void:
	_shop_panel.visible = false
	_trees_panel.visible = false
	_skill_panel.visible = false
	_orders_panel.visible = false
	_atlas_panel.visible = false
	_modal_backdrop.visible = false
	_refresh_active_job_chip()


## The backdrop consumes the outside click after closing the panel, so dismissing
## a window can never swing the axe at the same time.
func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_player_closed_panels()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _modal_backdrop.visible and event.is_action_pressed("ui_cancel"):
		_on_player_closed_panels()
		get_viewport().set_input_as_handled()


func _on_player_closed_panels() -> void:
	_close_panels()
	_tutorial.notify_hud_action(&"panel_closed")


## ------------------------------------------------------------------- the shop
func _on_shop_pressed() -> void:
	_open_panel(_shop_panel)
	_rebuild_shop()   # levels and affordability may have moved while it was shut
	_tutorial.notify_hud_action(&"shop_opened")


func _open_splitter_shop() -> void:
	_open_panel(_shop_panel)
	_shop_tabs.current_tab = _SPLITTER_TAB
	_rebuild_shop()


func _on_shop_tab_changed(_tab: int) -> void:
	_rebuild_shop()


func _on_close_shop_pressed() -> void:
	_on_player_closed_panels()


func _on_trees_pressed() -> void:
	_open_panel(_trees_panel)
	_rebuild_woodshed()
	_tutorial.notify_hud_action(&"catalog_opened")


func _on_close_trees_pressed() -> void:
	_on_player_closed_panels()


func _on_atlas_pressed() -> void:
	_open_panel(_atlas_panel)
	_rebuild_atlas()
	_tutorial.notify_hud_action(&"atlas_opened")


func _on_regional_network_changed() -> void:
	_refresh_reveal_visibility()
	_rebuild_atlas()
	_rebuild_woodshed()


func _on_company_strategy_changed() -> void:
	_rebuild_atlas()


func _on_earth_campaign_changed() -> void:
	_refresh_reveal_visibility()
	_rebuild_atlas()
	_rebuild_woodshed()


func _on_earth_trees_changed(_remaining: int, _felled_delta: int) -> void:
	_refresh_earth_trees()


func _refresh_earth_trees() -> void:
	if _earth_trees_label == null:
		return
	if GameState.is_earth_depleted():
		_earth_trees_label.text = "Earth · 0 trees remaining"
	else:
		var phase := GameState.get_campaign_phase()
		_earth_trees_label.text = ("EARTH REMAINING · %s" if phase \
			>= GameState.CampaignPhase.PLANETARY_MACHINE else "Trees remaining · %s") \
			% _thousands(GameState.get_earth_trees_remaining())
		_earth_trees_label.add_theme_font_size_override("font_size",
			18 if phase >= GameState.CampaignPhase.PLANETARY_MACHINE else 13)


func _on_campaign_goal_changed(snapshot: CampaignGoalSnapshot) -> void:
	_refresh_campaign_goal(snapshot)
	_refresh_earth_trees()


func _on_campaign_phase_changed(_previous: int, next: int) -> void:
	_rebuild_skills()
	_refresh_reveal_visibility()
	_show_phase_introduction(next)


func _show_phase_introduction(phase: int) -> void:
	var feature_id := StringName("campaign_phase_%d" % phase)
	if GameState.has_introduced_feature(feature_id) \
			or not GameState.mark_feature_introduced(feature_id):
		return
	match phase:
		GameState.CampaignPhase.WORKING_YARD:
			_feature_introduction.text = "WORKING YARD · The block has acquired colleagues."
		GameState.CampaignPhase.REGIONAL_COMPANY:
			_feature_introduction.text = "REGIONAL COMPANY · The forest is now an input."
		GameState.CampaignPhase.PLANETARY_MACHINE:
			_feature_introduction.text = "PLANETARY MACHINE · 3.04 trillion is a target now."
		GameState.CampaignPhase.COSMIC_FINALE:
			_feature_introduction.text = "COSMIC FINALE · Earth is empty. Space still has wood."
		_:
			return
	_feature_introduction.visible = true
	_feature_introduction_timer.start()
	AudioDirector.play_ui(&"level_up")


func _refresh_campaign_goal(snapshot: CampaignGoalSnapshot) -> void:
	if snapshot == null or _campaign_goal == null:
		return
	_campaign_goal.visible = not _credits_panel.visible
	_campaign_goal_phase.text = CampaignProgression.phase_name(snapshot.phase).to_upper()
	_campaign_goal_title.text = snapshot.title
	_campaign_goal_detail.text = snapshot.detail
	_campaign_goal_progress.visible = snapshot.has_progress()
	_campaign_goal_progress_text.visible = snapshot.has_progress()
	if snapshot.has_progress():
		_campaign_goal_progress.max_value = maxi(1, snapshot.target)
		_campaign_goal_progress.value = mini(snapshot.current, snapshot.target)
		_campaign_goal_progress_text.text = "%s / %s" % [
			_thousands(snapshot.current), _thousands(snapshot.target)]
		_campaign_goal_progress.tooltip_text = _campaign_goal_progress_text.text


func _show_campaign_credits() -> void:
	_campaign_goal.visible = false
	_credits_stats.text = "25 Earth woods mastered\n%s trees removed\n3 alien woods mastered\n3 orbital lines running\nFrontier Master" % \
		_thousands(GameState.TOTAL_EARTH_TREES)
	_credits_panel.visible = true
	# The roll begins on-screen: a blank dark frame after the final receipt reads
	# like a hang, while this still gives the copy a slow upward credits drift.
	_credits_column.position.y = 160.0
	var roll := create_tween()
	roll.set_trans(Tween.TRANS_LINEAR)
	roll.tween_property(_credits_column, "position:y", 96.0, 12.0)


func _on_close_credits_pressed() -> void:
	_credits_panel.visible = false
	_campaign_goal.visible = true


func _on_earth_finale_completed() -> void:
	_show_earth_master_headline()


func _show_earth_master_headline() -> void:
	_earth_master_headline.visible = true
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(_earth_master_headline):
		_earth_master_headline.visible = false


func _on_launch_program_changed() -> void:
	_refresh_reveal_visibility()
	_rebuild_atlas()


func _refresh_reveal_visibility() -> void:
	var shop_actionable := Shop.is_entry_revealed()
	var staged_opening := _tutorial_opening_is_staged()
	_shop_button.visible = shop_actionable
	_orders_button.visible = displayed_level() >= Orders.JOBS_UNLOCK_LEVEL
	_skills_button.visible = _displayed_skill_points_earned > 0
	_trees_button.visible = not staged_opening and _catalogue_is_actionable()
	var atlas_actionable := GameState.is_earth_master()
	for region: RegionDef in RegionalNetwork.regions():
		if GameState.is_region_discovered(region.id) \
				or (GameState.get_reputation() > 0 \
					and GameState.get_reputation() >= region.reputation_required):
			atlas_actionable = true
			break
	_atlas_button.visible = atlas_actionable
	if (not shop_actionable and _shop_panel.visible) \
			or (not _orders_button.visible and _orders_panel.visible) \
			or (not _skills_button.visible and _skill_panel.visible) \
			or (not _trees_button.visible and _trees_panel.visible) \
			or (not atlas_actionable and _atlas_panel.visible):
		_close_panels()


func _tutorial_opening_is_staged() -> bool:
	var tutorial_save := GameState.has_introduced_feature(_TUTORIAL_ARMED_ID) \
		or GameState.has_introduced_feature(_TUTORIAL_STARTED_ID)
	return tutorial_save \
		and not GameState.has_introduced_feature(_TUTORIAL_OPENING_COMPLETE_ID) \
		and not GameState.has_introduced_feature(_TUTORIAL_SKIPPED_ID)


func _on_feature_introduced(feature_id: StringName) -> void:
	if feature_id == _TUTORIAL_OPENING_COMPLETE_ID \
		or feature_id == _TUTORIAL_SKIPPED_ID:
		_refresh_reveal_visibility.call_deferred()


func _catalogue_is_actionable() -> bool:
	if GameState.get_owned_species().size() > 1 or MechanicalSplitter.is_installed():
		return true
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		if GameState.owns_species(wood_trait.id):
			return true
	var next_species := GameState.get_next_unowned_species()
	if next_species == null or next_species.unlock_level > displayed_level() \
			or not GameState.can_species_be_bought(next_species.id):
		return false
	var reveal_id := StringName("catalogue_actionable_%s" % next_species.id)
	if GameState.has_introduced_feature(reveal_id):
		return true
	if GameState.get_cash() < next_species.unlock_cost:
		return false
	GameState.mark_feature_introduced(reveal_id)
	return true


func _rebuild_atlas() -> void:
	if _atlas_list == null:
		return
	for child in _atlas_list.get_children():
		_atlas_list.remove_child(child)
		child.queue_free()
	if not _atlas_button.visible:
		return
	_atlas_list.add_child(_build_company_strategy_card())
	if GameState.is_earth_master():
		_atlas_list.add_child(_build_launch_program_card())
	for region: RegionDef in RegionalNetwork.regions():
		if GameState.is_region_discovered(region.id) \
				or (GameState.get_reputation() > 0 \
					and GameState.get_reputation() >= region.reputation_required):
			_atlas_list.add_child(_build_region_card(region))


func _build_company_strategy_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "CompanyStrategy"
	var title := Label.new()
	title.text = "Continental company · %s manual + %s automated = %s log-equivalents" % [
		_compact_number(GameState.get_manual_log_equivalents()),
		_compact_number(GameState.get_automated_log_equivalents()),
		_compact_number(GameState.get_combined_company_log_total())]
	title.add_theme_font_size_override("font_size", 18)
	card.add_child(title)
	var next_goal := Label.new()
	next_goal.name = "AntiStallGoal"
	next_goal.text = "NEXT CAMPAIGN GOAL · %s" % String(
		EarthCampaign.next_anti_stall_goal().get("text", "Review the catalogue"))
	next_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_goal.modulate = Color(0.98, 0.79, 0.40, 1.0)
	card.add_child(next_goal)
	var doctrines := HBoxContainer.new()
	for doctrine: CompanyDoctrineDef in CompanyStrategy.doctrines():
		var button := Button.new()
		button.text = doctrine.display_name
		button.tooltip_text = doctrine.description
		button.disabled = GameState.get_company_doctrine() == doctrine.id
		button.pressed.connect(_on_doctrine_pressed.bind(doctrine.id))
		doctrines.add_child(button)
	card.add_child(doctrines)
	var machine := CompanyStrategy.machine()
	if machine != null:
		var machine_button := Button.new()
		machine_button.text = "%s · %s" % [machine.display_name,
			"Owned" if Shop.get_level(machine.id) > 0 else "%s coins" % _thousands(machine.cost)]
		machine_button.disabled = Shop.get_level(machine.id) > 0 \
			or not MechanicalSplitter.is_installed() or not GameState.can_afford_cash(machine.cost)
		machine_button.pressed.connect(_on_buy_company_machine_pressed)
		card.add_child(machine_button)
	for project: InfrastructureProjectDef in RegionalNetwork.projects():
		if project.region_id != &"" \
				and not GameState.is_region_discovered(project.region_id):
			continue
		var project_button := Button.new()
		project_button.text = "%s · %s" % [project.display_name,
			"Complete" if GameState.has_infrastructure_project(project.id) \
			else "%s coins · %d output" % [_thousands(project.cash_cost),
				project.processed_output_required]]
		project_button.tooltip_text = project.description
		project_button.disabled = GameState.has_infrastructure_project(project.id) \
			or not GameState.can_afford_cash(project.cash_cost) \
			or GameState.get_lifetime_wood_chopped() + GameState.get_automated_log_equivalents() \
			< project.processed_output_required
		project_button.pressed.connect(_on_infrastructure_project_pressed.bind(project.id))
		card.add_child(project_button)
		if not GameState.has_infrastructure_project(project.id):
			break
	var finale_state := GameState.get_earth_finale_state()
	var finale := Button.new()
	finale.name = "EarthFinale"
	match finale_state:
		GameState.EarthFinaleState.LOCKED:
			finale.text = "Lignum Vitae showcase · master the other 24 species and global projects"
			finale.disabled = true
		GameState.EarthFinaleState.READY:
			if GameState.owns_species(EarthCampaign.FINAL_SPECIES_ID):
				finale.text = "Deliver Lignum Vitae to the original block"
				finale.pressed.connect(_on_begin_earth_finale_pressed)
			else:
				finale.text = "Lignum Vitae showcase unlocked · acquire it in the catalogue"
				finale.disabled = true
		GameState.EarthFinaleState.IN_PROGRESS:
			finale.text = "Earth finale · %d / 3 manual splits" % GameState.get_earth_finale_splits()
			finale.disabled = true
		GameState.EarthFinaleState.COMPLETE:
			finale.text = "EARTH DEPLETED · Launch programme is next" \
				if GameState.is_earth_depleted() \
				else "Lignum Vitae showcase complete · planetary production remains"
			finale.disabled = true
	card.add_child(finale)
	return card


func _build_launch_program_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "LaunchProgramme"
	var title := Label.new()
	title.text = "LAUNCH PROGRAMME · existing cash, output, mastery and timber contributions"
	title.add_theme_font_size_override("font_size", 18)
	card.add_child(title)
	for project: LaunchProjectDef in LaunchProgram.projects():
		var contribution := GameState.get_launch_contribution(project.id)
		var button := Button.new()
		button.name = String(project.id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if GameState.has_launch_project(project.id):
			button.text = "%s · COMPLETE" % project.display_name
			button.disabled = true
		elif contribution < project.contribution_amount:
			var remaining := project.contribution_amount - contribution
			button.text = "%s · contribute %d %s (%d/%d)" % [project.display_name,
				remaining, project.contribution_item_id, contribution,
				project.contribution_amount]
			button.disabled = InventoryManager.get_count(project.contribution_item_id) <= 0
			button.pressed.connect(_on_launch_contribution_pressed.bind(project.id,
				mini(remaining, InventoryManager.get_count(project.contribution_item_id))))
		elif ProductionEconomy.has_continuity_reserve():
			button.text = "%s · build from Continuity Reserve · %d log-eq · %d masteries" % [
				project.display_name, project.processed_output_required,
				project.mastery_required]
			button.disabled = GameState.get_combined_company_log_total() \
				< project.processed_output_required \
				or GameState.get_mastered_species_count() < project.mastery_required
			button.pressed.connect(_on_complete_launch_project_pressed.bind(project.id))
		else:
			button.text = "%s · build for %s coins · %d log-eq · %d masteries" % [
				project.display_name, _thousands(project.cash_cost),
				project.processed_output_required, project.mastery_required]
			button.disabled = not GameState.can_afford_cash(project.cash_cost) \
				or GameState.get_combined_company_log_total() \
					< project.processed_output_required \
				or GameState.get_mastered_species_count() < project.mastery_required
			button.pressed.connect(_on_complete_launch_project_pressed.bind(project.id))
		button.tooltip_text = project.description
		card.add_child(button)
		if not GameState.has_launch_project(project.id):
			break
	if GameState.has_launch_project(&"deep_space_vessel"):
		var component_title := Label.new()
		component_title.text = "VESSEL LOADOUT · range / cargo / shielding"
		component_title.modulate = Color(0.66, 0.82, 0.98, 1.0)
		card.add_child(component_title)
		var loadout := GameState.get_spacecraft_loadout()
		for component: SpacecraftComponentDef in LaunchProgram.components():
			var component_button := Button.new()
			component_button.text = "%s · capability %d%s" % [component.display_name,
				component.capability, " · FITTED" if StringName(loadout.get(
					component.slot, &"")) == component.id else ""]
			component_button.disabled = not GameState.get_active_expedition().is_empty() \
				or StringName(loadout.get(component.slot, &"")) == component.id
			component_button.pressed.connect(_on_spacecraft_component_pressed.bind(
				component.id))
			card.add_child(component_button)
		_build_expedition_controls(card)
	return card


func _build_expedition_controls(card: VBoxContainer) -> void:
	var active := GameState.get_active_expedition()
	if not active.is_empty():
		var now := int(Time.get_unix_time_from_system())
		var receive := Button.new()
		var left := maxi(0, int(active.get("arrives_at", now)) - now)
		receive.text = "Receive %s expedition · %ds remaining" % [
			String(active.get("destination_id", "flight")), left]
		receive.disabled = left > 0
		receive.pressed.connect(_on_receive_expedition_pressed)
		card.add_child(receive)
		return
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		var destination := LaunchProgram.expedition_by_id(wood_trait.destination_id)
		var state := GameState.get_alien_destination_state(destination.id)
		var heading := Label.new()
		heading.text = "%s / %s · %s" % [destination.display_name,
			wood_trait.display_name, _alien_state_title(state)]
		heading.add_theme_font_size_override("font_size", 16)
		heading.modulate = wood_trait.inside_tint
		card.add_child(heading)
		var action := Button.new()
		action.name = String(destination.id)
		match state:
			GameState.AlienDestinationState.UNSURVEYED:
				action.text = "Survey and retrieve first specimen · %ds fixed flight" % \
					destination.flight_seconds
				action.disabled = GameState.get_spacecraft_capability(
					SpacecraftComponentDef.Slot.RANGE) < destination.range_required \
					or GameState.get_spacecraft_capability(
						SpacecraftComponentDef.Slot.CARGO) <= 0 \
					or GameState.get_spacecraft_capability(
						SpacecraftComponentDef.Slot.SHIELDING) \
						< destination.shielding_required
				action.pressed.connect(_on_plan_expedition_pressed.bind(destination.id))
			GameState.AlienDestinationState.SURVEYED:
				action.text = "Quarantine returned specimen"
				action.pressed.connect(_on_alien_protocol_pressed.bind(destination.id,
					&"quarantine"))
			GameState.AlienDestinationState.QUARANTINED:
				action.text = "Identify specimen"
				action.pressed.connect(_on_alien_protocol_pressed.bind(destination.id,
					&"identify"))
			GameState.AlienDestinationState.IDENTIFIED:
				action.text = "Deliver specimen to the orbital stump rig"
				action.pressed.connect(_on_alien_protocol_pressed.bind(destination.id,
					&"retrieve_specimen"))
			GameState.AlienDestinationState.SPECIMEN_READY:
				action.text = "Chop first specimen manually · certification required"
				action.pressed.connect(_on_select_alien_species_pressed.bind(wood_trait.id))
			GameState.AlienDestinationState.CERTIFIED:
				action.text = "Unlock repeat cargo · %s" % wood_trait.premium_order_name
				action.pressed.connect(_on_alien_protocol_pressed.bind(destination.id,
					&"repeat_cargo"))
			GameState.AlienDestinationState.REPEAT_CARGO:
				action.text = "Continue manual mastery · %d/%d logs" % [
					GameState.get_alien_manual_mastery(wood_trait.id), wood_trait.manual_mastery_target]
				action.pressed.connect(_on_select_alien_species_pressed.bind(wood_trait.id))
			GameState.AlienDestinationState.MASTERED:
				action.text = "MASTERED · repeat cargo and orbital routing available"
				action.disabled = true
		card.add_child(action)
		if state >= GameState.AlienDestinationState.CERTIFIED:
			var premium := Label.new()
			premium.text = "Premium family: %s · ×%.2f provisional" % [
				wood_trait.premium_order_name, wood_trait.premium_multiplier]
			card.add_child(premium)
		if state >= GameState.AlienDestinationState.REPEAT_CARGO:
			var fleet := Button.new()
			fleet.text = "Cargo fleet %d/%d · %s coins" % [
				GameState.get_cargo_fleet_count(destination.id),
				AlienCompanySimulation.config().fleet_cap_per_destination,
				_thousands(wood_trait.fleet_cost)]
			fleet.disabled = GameState.get_cargo_fleet_count(destination.id) \
				>= AlienCompanySimulation.config().fleet_cap_per_destination \
				or not GameState.can_afford_cash(wood_trait.fleet_cost)
			fleet.pressed.connect(_on_buy_alien_fleet_pressed.bind(destination.id))
			card.add_child(fleet)
			var charter := Button.new()
			charter.text = "Charter priority%s" % (" · ACTIVE" if \
				GameState.get_expedition_charter() == destination.id else "")
			charter.disabled = GameState.get_expedition_charter() == destination.id
			charter.pressed.connect(_on_alien_charter_pressed.bind(destination.id))
			card.add_child(charter)
		if state == GameState.AlienDestinationState.MASTERED:
			var orbital := Button.new()
			orbital.text = "Orbital auto-cutting line · %s" % ("ONLINE" if \
				GameState.has_orbital_line(destination.id) else "%s coins" % \
					_thousands(wood_trait.orbital_line_cost))
			orbital.disabled = GameState.has_orbital_line(destination.id) \
				or not GameState.can_afford_cash(wood_trait.orbital_line_cost)
			orbital.pressed.connect(_on_build_orbital_line_pressed.bind(destination.id))
			card.add_child(orbital)
		if state < GameState.AlienDestinationState.MASTERED:
			break


func _alien_state_title(state: int) -> String:
	return ["Unsurveyed", "Surveyed", "Quarantined", "Identified", "Specimen ready",
		"Manually certified", "Repeat cargo", "Mastered"][clampi(state, 0, 7)]


func _build_region_card(region: RegionDef) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = String(region.id)
	var heading := Label.new()
	heading.text = "%s · Standing %d" % [region.display_name,
		GameState.get_regional_standing(region.id)]
	heading.add_theme_font_size_override("font_size", 18)
	card.add_child(heading)
	var detail := Label.new()
	detail.text = region.description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	card.add_child(detail)
	if not GameState.is_region_discovered(region.id):
		var discover := Button.new()
		discover.text = "Discover at reputation %d" % region.reputation_required
		discover.disabled = GameState.get_reputation() < region.reputation_required
		discover.pressed.connect(_on_discover_region_pressed.bind(region.id))
		card.add_child(discover)
		return card
	var route := RegionalNetwork.route_for_region(region.id)
	var state := Label.new()
	if not GameState.has_regional_depot(region.id):
		state.text = "Next: standing %d, then depot · %s coins" % [
			region.depot_standing_required, _thousands(region.depot_cost)]
	elif not GameState.has_regional_route(region.id):
		state.text = "Depot built · Next: %s · %s coins" % [route.display_name,
			_thousands(route.cost)]
	else:
		state.text = "%s ACTIVE · capacity %d · %ds provisional travel" % [
			route.display_name, route.capacity, route.travel_seconds]
	state.modulate = Color(0.78, 0.88, 0.64, 1.0)
	card.add_child(state)
	var action := Button.new()
	if not GameState.has_regional_depot(region.id):
		action.text = "Build depot"
		action.disabled = GameState.get_regional_standing(region.id) \
			< region.depot_standing_required or not GameState.can_afford_cash(region.depot_cost)
		action.pressed.connect(_on_build_region_depot_pressed.bind(region.id))
	elif not GameState.has_regional_route(region.id):
		action.text = "Establish freight route"
		action.disabled = not GameState.can_afford_cash(route.cost)
		action.pressed.connect(_on_establish_region_route_pressed.bind(region.id))
	else:
		action.text = "Route connected"
		action.disabled = true
	card.add_child(action)
	for species_id: StringName in region.species_ids:
		var species := SpeciesTable.by_id(species_id)
		if species == null:
			continue
		var status := RegionalNetwork.supply_status(species_id)
		var line := Button.new()
		line.text = "%s — %s · %s" % [species.display_name,
			String(status.detail), String(status.action)]
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.disabled = int(status.reason) != RegionalNetwork.DelayReason.READY \
			or not MechanicalSplitter.can_accept_species(species_id)
		if not line.disabled:
			line.pressed.connect(_on_dispatch_region_species_pressed.bind(species_id))
		card.add_child(line)
	return card


func _on_discover_region_pressed(region_id: StringName) -> void:
	GameState.discover_region(region_id)


func _on_build_region_depot_pressed(region_id: StringName) -> void:
	GameState.build_regional_depot(region_id)


func _on_establish_region_route_pressed(region_id: StringName) -> void:
	GameState.establish_regional_route(region_id)


func _on_dispatch_region_species_pressed(species_id: StringName) -> void:
	GameState.dispatch_regional_species(species_id, 1)


func _on_doctrine_pressed(doctrine_id: StringName) -> void:
	GameState.set_company_doctrine(doctrine_id)


func _on_buy_company_machine_pressed() -> void:
	CompanyStrategy.buy_machine()


func _on_infrastructure_project_pressed(project_id: StringName) -> void:
	GameState.complete_infrastructure_project(project_id)


func _on_begin_earth_finale_pressed() -> void:
	if GameState.begin_earth_finale():
		GameState.select_species(EarthCampaign.FINAL_SPECIES_ID)


func _on_launch_contribution_pressed(project_id: StringName, amount: int) -> void:
	LaunchProgram.contribute(project_id, amount)


func _on_complete_launch_project_pressed(project_id: StringName) -> void:
	GameState.complete_launch_project(project_id)


func _on_spacecraft_component_pressed(component_id: StringName) -> void:
	GameState.configure_spacecraft(component_id)


func _on_plan_expedition_pressed(destination_id: StringName) -> void:
	GameState.plan_expedition(destination_id, int(Time.get_unix_time_from_system()))


func _on_receive_expedition_pressed() -> void:
	var receipt := GameState.resolve_expedition(int(Time.get_unix_time_from_system()))
	GameState.apply_expedition_receipt(receipt)


func _on_alien_protocol_pressed(destination_id: StringName, action: StringName) -> void:
	GameState.advance_alien_protocol(destination_id, action)


func _on_select_alien_species_pressed(species_id: StringName) -> void:
	GameState.select_species(species_id)


func _on_buy_alien_fleet_pressed(destination_id: StringName) -> void:
	GameState.commission_cargo_fleet(destination_id)


func _on_alien_charter_pressed(destination_id: StringName) -> void:
	GameState.set_expedition_charter(destination_id)


func _on_build_orbital_line_pressed(destination_id: StringName) -> void:
	GameState.build_orbital_line(destination_id)


func _on_building_upgraded(_id: StringName, _tier: int) -> void:
	_refresh_reveal_visibility()
	_rebuild_shop()
	_refresh_splitter_runtime_card()
	if _trees_panel.visible:
		_rebuild_woodshed()


func _on_catalogue_gate_changed() -> void:
	_refresh_reveal_visibility()
	_rebuild_shop()
	_rebuild_orders()
	_rebuild_woodshed()
	_refresh_badges()


func _on_lifetime_cash_earned_changed(_new_total: int) -> void:
	_queue_cash_ui_refresh()


## One row per visible unfinished upgrade, split by role: ordinary equipment
## stays in Items while the Mechanical Splitter machine and its profiles own
## their dedicated tab. Completed one-time/maxed rows move to Purchased, derived
## from the same building tiers rather than a duplicate purchase-history store.
func _rebuild_shop() -> void:
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()
	for child in _splitter_list.get_children():
		_splitter_list.remove_child(child)
		child.queue_free()
	for child in _purchased_list.get_children():
		_purchased_list.remove_child(child)
		child.queue_free()

	var upgrades := Shop.get_visible_upgrades()
	_introduce_revealed_production(upgrades)
	var item_count := 0
	var splitter_count := 0
	for def: UpgradeDef in upgrades:
		if def == null or Shop.is_fully_purchased(def.id):
			continue
		if def.automation_role == UpgradeDef.AutomationRole.NONE:
			_shop_list.add_child(_build_shop_row(def))
			item_count += 1
		else:
			_splitter_list.add_child(_build_shop_row(def))
			splitter_count += 1
	if GameState.get_automated_log_equivalents() > 0:
		for logistics_upgrade: LogisticsUpgradeDef in CompanyLogistics.upgrades():
			if CompanyLogistics.is_owned(logistics_upgrade.id):
				continue
			if CompanyLogistics.is_available(logistics_upgrade.id):
				_splitter_list.add_child(_build_logistics_shop_row(logistics_upgrade))
				splitter_count += 1
				break
	_shop_empty.visible = item_count == 0
	_splitter_empty.visible = splitter_count == 0
	var purchased := Shop.get_purchased_upgrades()
	for def: UpgradeDef in purchased:
		_purchased_list.add_child(_build_purchased_row(def))
	var purchased_logistics := 0
	for logistics_upgrade: LogisticsUpgradeDef in CompanyLogistics.upgrades():
		if CompanyLogistics.is_owned(logistics_upgrade.id):
			_purchased_list.add_child(_build_purchased_logistics_row(logistics_upgrade))
			purchased_logistics += 1
	_purchased_empty.visible = purchased.is_empty() and purchased_logistics == 0
	_shop_tabs.set_tab_hidden(_SPLITTER_TAB, splitter_count == 0)
	if _shop_tabs.is_tab_hidden(_shop_tabs.current_tab):
		_shop_tabs.current_tab = 0
	_refresh_shop_unlock_hint()
	_refresh_splitter_status()
	_refresh_badges()


func _refresh_splitter_status() -> void:
	if not MechanicalSplitter.is_installed():
		_splitter_status.text = "Mechanical Splitter unlocked · Purchase the machine here."
		return
	var assigned := GameState.get_splitter_assigned_species()
	if assigned == &"":
		_splitter_status.text = "Mechanical Splitter installed · No tree assigned. Choose an installed profile in the Tree Catalog."
		return
	var species := SpeciesTable.by_id(assigned)
	_splitter_status.text = "Mechanical Splitter installed · Assigned to %s." % [
		String(assigned) if species == null else species.display_name]


func _build_shop_row(def: UpgradeDef) -> VBoxContainer:
	var level := Shop.get_level(def.id)
	var maxed := def.is_maxed(level)

	var row := VBoxContainer.new()
	row.name = String(def.id)
	row.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = "%s  (rank %d)" % [def.display_name, level] \
		if def.purchase_form == UpgradeDef.PurchaseForm.TIERED else def.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(92, 34)   # room for the coin beside the price
	if maxed:
		buy.text = "Maxed"
		buy.disabled = true
	else:
		var next_cost := Shop.get_next_cost(def.id)
		buy.text = _compact_number(next_cost)
		buy.tooltip_text = "%s coins" % _thousands(next_cost)
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
	_add_equipment_proc_copy(row, def)
	if def is ProductionUpgradeDef:
		var production := def as ProductionUpgradeDef
		var effect_label := Label.new()
		effect_label.text = "Production · %s → %s\nEstimated change · %s" % [
			production.current_effect_text(level),
			production.next_effect_text(level),
			production.estimated_production_change(level)]
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.add_theme_font_size_override("font_size", 12)
		effect_label.modulate = Color(0.72, 0.88, 0.76, 1.0)
		row.add_child(effect_label)
		var tuning := Label.new()
		tuning.text = production.tuning_status
		tuning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tuning.add_theme_font_size_override("font_size", 10)
		tuning.modulate = Color(0.72, 0.72, 0.68, 0.72)
		row.add_child(tuning)
	_add_upgrade_reward(row, def)
	return row


func _add_equipment_proc_copy(row: VBoxContainer, def: UpgradeDef) -> void:
	if def.proc_contributions.is_empty():
		return
	var lines: PackedStringArray = []
	for contribution: UpgradeProcContributionDef in def.proc_contributions:
		if contribution == null:
			continue
		var proc := ProgressionProcs.proc_def(contribution.proc_id)
		var proc_name := String(contribution.proc_id) if proc == null else proc.display_name
		var independent := contribution.chance_per_level
		var combined := ProgressionProcs.effective_chance(contribution.proc_id)
		var depth := ""
		if contribution.proc_id == &"double_strike":
			depth = " · up to %d bonus cut%s" % [contribution.chain_cap,
				"" if contribution.chain_cap == 1 else "s"]
		lines.append("%s · independent %s%%%s · current gear + skill %s%%" % [
			proc_name, _percent_text(independent), depth, _percent_text(combined)])
		if proc != null:
			lines.append("Dry-streak protection · guaranteed by eligible event %d" \
				% proc.bad_luck_bound)
	var copy := Label.new()
	copy.text = "\n".join(lines)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_size_override("font_size", 12)
	copy.modulate = Color(0.72, 0.88, 0.76, 1.0)
	row.add_child(copy)


func _introduce_revealed_production(upgrades: Array[UpgradeDef]) -> void:
	for upgrade: UpgradeDef in upgrades:
		if not upgrade is ProductionUpgradeDef:
			continue
		var feature_id := StringName("shop_%s" % upgrade.id)
		if GameState.has_introduced_feature(feature_id):
			continue
		if GameState.mark_feature_introduced(feature_id):
			_feature_introduction.text = "New production item · %s" % \
				upgrade.display_name
			_feature_introduction.visible = true
			_feature_introduction_timer.start()
		# Introduce at most one item per repaint; later actionable rows are still
		# visible and will receive their compact introduction on the next change.
		break


## Purchased entries intentionally contain no Button. They are a read-only
## record derived from live ownership, while retaining the same honest effect
## and limitation copy as the functional shelf row they came from.
func _build_purchased_row(def: UpgradeDef) -> VBoxContainer:
	var level := Shop.get_level(def.id)
	var row := VBoxContainer.new()
	row.name = String(def.id)
	row.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var status := Label.new()
	status.text = "Maxed · rank %d/%d" % [level, def.max_level] \
		if def.purchase_form == UpgradeDef.PurchaseForm.TIERED \
		else "Owned"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.modulate = Color(0.82, 0.88, 0.78, 1.0)
	top.add_child(status)
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
	_add_equipment_proc_copy(row, def)
	_add_upgrade_reward(row, def)
	return row


func _build_logistics_shop_row(def: LogisticsUpgradeDef) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = String(def.id)
	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = "Logistics · " + def.display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var buy := Button.new()
	buy.text = str(def.cost)
	buy.icon = _COIN
	buy.disabled = not GameState.can_afford_cash(def.cost)
	buy.pressed.connect(_on_buy_logistics_pressed.bind(def.id))
	top.add_child(buy)
	row.add_child(top)
	var detail := Label.new()
	detail.text = def.description + "\nProvisional direct-purchase sequence · no manual craft credit."
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	row.add_child(detail)
	return row


func _build_purchased_logistics_row(def: LogisticsUpgradeDef) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = String(def.id)
	var heading := Label.new()
	heading.text = "Logistics · %s · Owned" % def.display_name
	row.add_child(heading)
	var detail := Label.new()
	detail.text = def.description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	row.add_child(detail)
	return row


func _refresh_shop_unlock_hint() -> void:
	var has_future_yard_reward := false
	for candidate: UpgradeDef in Shop.get_upgrades():
		if candidate != null \
				and candidate.unlock_after_haul_aways > GameState.get_haul_aways_completed():
			has_future_yard_reward = true
			break
	_shop_unlock_hint.visible = has_future_yard_reward
	_shop_unlock_hint.text = "Yard reward · Your first full haul expands the Shop."


func _add_upgrade_reward(row: VBoxContainer, def: UpgradeDef) -> void:
	var rewards: PackedStringArray = []
	var has_profile_reward := false
	for candidate: UpgradeDef in Shop.get_upgrades():
		if candidate == null or candidate.required_upgrade_id != def.id:
			continue
		if not Shop.is_unlocked(candidate.id):
			continue
		if candidate.automation_role == UpgradeDef.AutomationRole.CUTTING_PROFILE:
			has_profile_reward = true
			continue
		var reward := "%s in Shop" % candidate.display_name
		if candidate.required_mastered_species_count > 0:
			reward += " after %d species certifications" % \
				candidate.required_mastered_species_count
		rewards.append(reward)
	if has_profile_reward:
		rewards.append("certified tree profiles in Shop")
	for species: SpeciesDef in SpeciesTable.all():
		if species != null and species.supplier_upgrade_id == def.id \
				and (GameState.owns_species(species.id) \
					or GameState.can_species_be_bought(species.id)):
			rewards.append("%s in the Tree Catalog once its level gate is met" % \
				species.display_name)
	if rewards.is_empty():
		return
	var reward_label := Label.new()
	reward_label.text = "Unlock reward · " + "  ·  ".join(rewards)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 12)
	reward_label.modulate = Color(0.78, 0.88, 0.64, 1.0)
	row.add_child(reward_label)


func _on_buy_pressed(id: StringName) -> void:
	# Shop.buy is atomic: a refused purchase spends nothing and moves no tier, so
	# there is nothing to undo here. The rebuild rides in on building_upgraded.
	Shop.buy(id)


func _on_buy_logistics_pressed(id: StringName) -> void:
	CompanyLogistics.buy(id)


## Driven by the SIGNALS rather than by the row that was clicked, so the button
## and the list agree however the choice moved — including a selection GameState
## refused, which emits nothing and correctly leaves the display alone.
func _on_selected_species_changed(_id: StringName) -> void:
	if _trees_panel.visible:
		_rebuild_woodshed()


func _on_species_purchased(_id: StringName) -> void:
	_refresh_reveal_visibility()
	if _trees_panel.visible:
		_rebuild_woodshed()
	_rebuild_orders()
	_refresh_badges()


func _on_species_mastery_changed(_id: StringName, _progress: int) -> void:
	# The progress bar and next-reward copy advance from the same authoritative
	# signal as the saved counter. M8 Slice 3 also uses certification to reveal
	# splitter purchases, so either open destination repaints from the same event.
	if _trees_panel.visible:
		_rebuild_woodshed()
	if _shop_panel.visible:
		_rebuild_shop()
	_refresh_badges()


func _on_splitter_assignment_changed(_id: StringName) -> void:
	_refresh_splitter_runtime_card()
	if _trees_panel.visible:
		_rebuild_woodshed()
	if _shop_panel.visible:
		_refresh_splitter_status()


## XP moves the level, and the level is what puts a wood on sale — so the shed's
## "needs level N" rows can go live without the player touching anything. Only
## repaints an OPEN panel: this fires once per finished log.
func _on_xp_changed(total: int) -> void:
	# Loads and resets have no orb receipt. A positive gameplay award emits this
	# before its orb batch in the same transaction, so defer the no-orb fallback
	# instead of briefly jumping the bar and then winding it back.
	if total < _displayed_xp_total:
		_xp_delivery_generation += 1
		_pending_orb_xp = 0
		_inflight_orb_xp = 0
		_xp_delivery_queue.clear()
		_xp_delivery_animating = false
		_xp_level_up_hold_level = 0
		_pending_skill_point_rewards.clear()
		_displayed_xp_total = total
		_displayed_skill_points_earned = GameState.get_skill_points_earned()
		_refresh_presented_progress()
		return
	_settle_unbatched_progress.call_deferred()


func _on_skill_points_changed(_available: int) -> void:
	# A level reward emits this before the orb batch. Purchases and respecs have no
	# batch, so the deferred fallback still repaints those immediately.
	_settle_unbatched_progress.call_deferred()


func _on_level_reward_granted(receipt: LevelRewardReceipt) -> void:
	if receipt == null or receipt.reward_type != \
			LevelRewardReceipt.RewardType.SKILL_POINT:
		return
	var presented_level := _xp_level_up_hold_level if _xp_level_up_hold_level > 0 \
		else GameState.get_level_for_xp(_displayed_xp_total)
	if receipt.level > presented_level:
		_pending_skill_point_rewards[receipt.level] = int(
			_pending_skill_point_rewards.get(receipt.level, 0)) + receipt.amount


func _on_skill_level_changed(_id: StringName, _level: int) -> void:
	_rebuild_skills()
	_refresh_badges()


## The World Wood Catalogue remains the authoritative supply-choice panel. M11
## expands it to all 25 Earth species so source, mastery, contract and automation
## status can be compared without creating a second opinion in another screen.
func _rebuild_woodshed() -> void:
	for child in _wood_list.get_children():
		_wood_list.remove_child(child)
		child.queue_free()
	_trees_blurb.text = "WORLD WOOD CATALOGUE · Ownership · manual mastery · supplier · contract · automation."
	if MechanicalSplitter.is_installed():
		_trees_blurb.text += " Assign one installed certified profile to the Mechanical Splitter."

	var chosen := GameState.get_selected_species()
	var next := GameState.get_next_unowned_species()
	for def: SpeciesDef in SpeciesTable.all():
		if GameState.owns_species(def.id) or GameState.can_species_be_bought(def.id):
			_wood_list.add_child(_build_wood_row(def, def.id == chosen))
	if next == null:
		_next_wood.text = String(EarthCampaign.next_anti_stall_goal().get(
			"text", "Every wood on Earth is yours."))
	else:
		if next.id == EarthCampaign.FINAL_SPECIES_ID \
				and not EarthCampaign.terrestrial_requirements_complete():
			_next_wood.text = "Lignum Vitae is reserved for the Earth finale: master the other 24 species and complete all three global projects."
			return
		var levels := next.levels_remaining(GameState.get_level())
		var supplier_missing := next.supplier_upgrade_id != &"" and Shop.get_level(next.supplier_upgrade_id) <= 0
		if supplier_missing:
			_next_wood.text = "Keep progressing in the yard to reveal the next supplier."
		elif levels > 0:
			_next_wood.text = "Keep earning XP to reveal the next supplier."
		else:
			_next_wood.text = "%s is in stock at the gate — %s to buy it." % [
				next.display_name, _thousands(next.unlock_cost)]


func _build_wood_row(def: SpeciesDef, is_chosen: bool) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	row.add_child(heading)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)

	# What the player is actually choosing between: what it pays, and how hard it
	# fights. Janka is the honest one-number answer to "how hard" and it is the
	# number the whole ladder was derived from, so it is the one shown.
	var stat := Label.new()
	stat.text = "%s per piece   ·   %d lbf" % [_thousands(Market.get_price(def.yield_item)), def.janka]
	stat.add_theme_font_size_override("font_size", 13)
	heading.add_child(stat)

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
	heading.add_child(pick)

	if GameState.owns_species(def.id):
		var mastery := Label.new()
		mastery.text = _mastery_row_text(def)
		mastery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mastery.add_theme_font_size_override("font_size", 13)
		mastery.modulate = Color(0.85, 0.88, 0.90, 1.0)
		row.add_child(mastery)

		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(0.0, 8.0)
		progress.max_value = float(maxi(1, _mastery_target(def.id)))
		progress.value = float(GameState.get_species_mastery_progress(def.id))
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var progress_background := StyleBoxFlat.new()
		progress_background.bg_color = Color(0.12, 0.15, 0.16, 0.85)
		progress_background.set_corner_radius_all(3)
		progress.add_theme_stylebox_override("background", progress_background)
		var progress_fill := StyleBoxFlat.new()
		progress_fill.bg_color = XPOrb.COLOR
		progress_fill.set_corner_radius_all(3)
		progress.add_theme_stylebox_override("fill", progress_fill)
		row.add_child(progress)
		_add_splitter_assignment(row, def)
	var region := RegionalNetwork.region_for_species(def.id)
	var catalogue := Label.new()
	var contract := Orders.by_id(StringName("%s_delivery" % def.id))
	var contract_done := contract != null and GameState.has_completed_order(contract.id)
	var automation := MechanicalSplitter.profile_for_species(def.id) != null \
		and MechanicalSplitter.has_installed_profile(def.id)
	catalogue.text = "Supplier: %s · Contract: %s · Automation: %s" % [
		"Unassigned" if region == null else region.display_name,
		"complete" if contract_done else "open",
		"installed" if automation else "manual-only"]
	catalogue.add_theme_font_size_override("font_size", 11)
	catalogue.modulate = Color(0.67, 0.74, 0.76, 1.0)
	row.add_child(catalogue)
	return row


func _add_splitter_assignment(row: VBoxContainer, def: SpeciesDef) -> void:
	var profile := MechanicalSplitter.profile_for_species(def.id)
	if not MechanicalSplitter.is_installed() or profile == null \
			or not GameState.is_species_mastered(def.id):
		return
	var line := HBoxContainer.new()
	line.name = "SplitterAssignment"
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)

	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 12)
	line.add_child(status)

	var assign := Button.new()
	assign.custom_minimum_size = Vector2(142, 32)
	line.add_child(assign)

	var assigned := GameState.get_splitter_assigned_species() == def.id
	if not MechanicalSplitter.has_installed_profile(def.id):
		status.text = "Splitter · Certified · Profile purchase required"
		assign.text = "Buy profile in Shop"
		assign.pressed.connect(_open_splitter_shop)
	elif assigned:
		status.text = "Splitter · Current assignment"
		assign.text = "Assigned"
		assign.disabled = true
	else:
		status.text = "Splitter · Certified profile ready"
		assign.text = "Assign to splitter"
		assign.pressed.connect(_on_assign_splitter_pressed.bind(def.id))


func _mastery_row_text(def: SpeciesDef) -> String:
	var current := GameState.get_species_mastery_progress(def.id)
	var target := _mastery_target(def.id)
	var handling := WoodHandlingProfiles.profile_for_species(def.id)
	var family := "" if handling == null else "%s · " % handling.display_name
	if GameState.is_species_mastered(def.id):
		var machine := MechanicalSplitter.machine_definition()
		var required := 0 if machine == null else machine.required_mastered_species_count
		var certified := mini(GameState.get_mastered_species_count(), required)
		var certification := ""
		if required > 0:
			certification = "  ·  Splitter certifications %d / %d" % [certified, required]
		return "%sMastery %d / %d  ·  Mastered%s  ·  All global rewards active" % [
			family, current, target, certification]
	var next := SpeciesMastery.next_threshold(def.id)
	if next == null:
		return "%sMastery %d / %d" % [family, current, target]
	return "%sMastery %d / %d\nNext reward at %d: %s" % [
		family, current, target, next.required_progress, _mastery_reward_text(next, target)]


func _mastery_target(species_id: StringName) -> int:
	var table := M7CContent.mastery()
	var definition: SpeciesMasteryDef = table.by_species_id(species_id) if table != null else null
	return definition.mastery_target if definition != null else 0


func _mastery_reward_text(threshold: SpeciesMasteryThresholdDef, mastery_target: int) -> String:
	var parts: PackedStringArray = []
	for reward: GameplayModifierDef in threshold.rewards:
		if reward == null:
			continue
		var amount := _percent_text(reward.magnitude)
		match reward.kind:
			GameplayModifierDef.Kind.CASH_GAIN:
				parts.append("+%s%% cash" % amount)
			GameplayModifierDef.Kind.MANUAL_XP:
				parts.append("+%s%% manual XP" % amount)
			GameplayModifierDef.Kind.SPLIT_RELIABILITY:
				parts.append("+%s pts split" % amount)
	if threshold.required_progress >= mastery_target:
		var machine := MechanicalSplitter.machine_definition()
		var required := 0 if machine == null else machine.required_mastered_species_count
		if required > 0:
			parts.append("+1 splitter certification (%d unlock the machine in Shop)" % required)
	return "  ·  ".join(parts)


func _percent_text(magnitude: float) -> String:
	var text := String.num(magnitude * 100.0, 2)
	while text.contains(".") and text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text


func _on_wood_row_pressed(id: StringName) -> void:
	# select_species is atomic and refuses anything unowned, so there is nothing
	# to undo here. The repaint rides in on selected_species_changed.
	GameState.select_species(id)


func _on_assign_splitter_pressed(id: StringName) -> void:
	GameState.assign_splitter_species(id)


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


func _compact_number(n: int) -> String:
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var value := float(absi(n))
	var suffix_index := 0
	while value >= 1000.0 and suffix_index < suffixes.size() - 1:
		value /= 1000.0
		suffix_index += 1
	if suffix_index == 0:
		return str(n)
	var amount := ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	return ("-" if n < 0 else "") + amount + suffixes[suffix_index]


## ------------------------------------------------------------- the skill tree
func _on_skills_pressed() -> void:
	_open_panel(_skill_panel)
	_rebuild_skills()
	_tutorial.notify_hud_action(&"skills_opened")


## --------------------------------------------------------- contract board
func _on_orders_pressed() -> void:
	_open_panel(_orders_panel)
	_rebuild_orders()
	_tutorial.notify_hud_action(&"orders_opened")


func _on_active_job_pressed() -> void:
	if GameState.has_pending_standing_commission_choice() \
			or (GameState.get_active_order_ids().is_empty() \
			and not GameState.get_active_commission_ids().is_empty()):
		_active_tasks_collapsed = not _active_tasks_collapsed
		_refresh_active_job_chip()
		return
	_on_orders_pressed()
	_orders_tabs.current_tab = _OPEN_ORDERS_TAB


func _on_active_job_toggle_pressed() -> void:
	_active_tasks_collapsed = not _active_tasks_collapsed
	_refresh_active_job_chip()


func _on_active_task_row_pressed(tab: int) -> void:
	_on_orders_pressed()
	_orders_tabs.current_tab = tab


func _on_close_orders_pressed() -> void:
	_on_player_closed_panels()


func _on_order_state_changed() -> void:
	_refresh_reveal_visibility()
	_rebuild_orders()
	_rebuild_shop()
	_refresh_active_job_chip()
	_refresh_badges()


func _on_commission_state_changed() -> void:
	_refresh_reveal_visibility()
	_rebuild_orders()
	_refresh_active_job_chip()
	_refresh_badges()


func _rebuild_orders() -> void:
	for child in _orders_list.get_children():
		_orders_list.remove_child(child)
		child.queue_free()
	for child in _orders_completed_list.get_children():
		_orders_completed_list.remove_child(child)
		child.queue_free()
	for child in _commissions_list.get_children():
		_commissions_list.remove_child(child)
		child.queue_free()

	var active_count := GameState.get_active_manual_job_count()
	if active_count == 0:
		_orders_active.text = "No active delivery — ordinary chopping always pays."
	else:
		_orders_active.text = "%d active %s — one matching piece advances each." % [
			active_count, "delivery" if active_count == 1 else "deliveries"]

	# Active first, then every other revealed incomplete contract in authored
	# order. Completed work owns a compact read-only tab instead of crowding the
	# actionable board as the 26-contract ladder opens up.
	var open_count := 0
	var completed_count := 0
	for order: OrderDef in Orders.visible():
		if order == null:
			continue
		if GameState.has_completed_order(order.id):
			_orders_completed_list.add_child(_build_completed_order_row(order))
			completed_count += 1
		elif Orders.is_available(order) or GameState.is_order_active(order.id):
			_orders_list.add_child(_build_order_row(order))
			open_count += 1
	if open_count == 0:
		var empty := Label.new()
		empty.text = "No revealed contracts are open. Keep chopping toward the next level reward."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_orders_list.add_child(empty)
	if completed_count == 0:
		var empty := Label.new()
		empty.text = "Completed deliveries will be recorded here."
		_orders_completed_list.add_child(empty)
	var commissions_unlocked := Orders.commissions_unlocked()
	if commissions_unlocked:
		var commission_summary := Label.new()
		commission_summary.text = "Standing commissions fulfilled: %d · %d campaign choices remain" % [
			GameState.get_completed_commission_count(),
			GameState.get_standing_commission_cycles_remaining()]
		commission_summary.add_theme_font_size_override("font_size", 14)
		commission_summary.modulate = Color(0.78, 0.88, 0.64, 1.0)
		_orders_completed_list.add_child(commission_summary)
	# Standing commissions are selected and tracked from the compact objective
	# chip. The old dense board tab remains scene-compatible but is never part of
	# the required interaction path.
	_orders_tabs.set_tab_hidden(_COMMISSIONS_TAB, true)
	if _orders_tabs.is_tab_hidden(_orders_tabs.current_tab):
		_orders_tabs.current_tab = _OPEN_ORDERS_TAB
	_commissions_empty.visible = false


func _build_order_row(order: OrderDef) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var heading := Label.new()
	heading.text = "%s — %s" % [order.customer_name, order.title]
	heading.add_theme_font_size_override("font_size", 17)
	row.add_child(heading)

	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rewards: PackedStringArray = ["+%s coins" % _thousands(order.cash_bonus)]
	var opens_shop := not Shop.is_entry_revealed()
	if opens_shop:
		rewards.append("Opens the Shop")
	if order.id == Orders.COMMISSION_UNLOCK_ORDER_ID:
		rewards.append("Unlocks occasional standing-commission choices")
	var profile := _matching_contract_profile(order)
	if profile != null:
		rewards.append("Expands production options after certification")
	else:
		for def: UpgradeDef in Shop.get_upgrades():
			if def != null and def.unlock_order_id == order.id:
				if not opens_shop:
					rewards.append("Expands the Shop")
				break
	detail.text = "%s\n%d pieces\nRewards: %s" % [
		order.description, order.required_count, "  ·  ".join(rewards)]
	row.add_child(detail)

	if GameState.is_order_active(order.id):
		var progress := ProgressBar.new()
		progress.max_value = order.required_count
		progress.value = GameState.get_active_order_progress_for(order.id)
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
	elif GameState.is_order_active(order.id):
		button.text = "In progress · %d / %d" % [
			GameState.get_active_order_progress_for(order.id), order.required_count]
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


func _build_completed_order_row(order: OrderDef) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = String(order.id)
	row.add_theme_constant_override("separation", 2)
	var heading := HBoxContainer.new()
	var title := Label.new()
	title.text = order.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	heading.add_child(title)
	var state := Label.new()
	state.text = "Completed"
	state.modulate = Color(0.78, 0.88, 0.64, 1.0)
	heading.add_child(state)
	row.add_child(heading)
	var detail := Label.new()
	detail.text = "%s · %d pieces · +%s coins" % [
		order.customer_name, order.required_count, _thousands(order.cash_bonus)]
	detail.add_theme_font_size_override("font_size", 12)
	detail.modulate = Color(0.78, 0.78, 0.78, 1.0)
	row.add_child(detail)
	var profile := _matching_contract_profile(order)
	if profile != null:
		var reward := Label.new()
		reward.text = "Profile reward · %s · %s" % [
			profile.display_name, _completed_profile_requirement(profile)]
		reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reward.add_theme_font_size_override("font_size", 12)
		reward.modulate = Color(0.76, 0.86, 0.63, 1.0)
		row.add_child(reward)
	if order.id == Orders.COMMISSION_UNLOCK_ORDER_ID:
		var commission_reward := Label.new()
		commission_reward.text = "Yard reward · Standing commissions unlocked"
		commission_reward.add_theme_font_size_override("font_size", 12)
		commission_reward.modulate = Color(0.76, 0.86, 0.63, 1.0)
		row.add_child(commission_reward)
	return row


func _build_commission_row(offer: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = String(offer.get("id", "commission"))
	row.add_theme_constant_override("separation", 3)

	var heading := Label.new()
	heading.text = "%s — %s" % [
		String(offer.get("customer_name", "Standing customer")),
		String(offer.get("title", "Yard commission"))]
	heading.add_theme_font_size_override("font_size", 17)
	row.add_child(heading)

	var required_item := StringName(offer.get("required_item", &""))
	var target := "Any split firewood"
	if required_item != &"":
		var item := InventoryManager.get_item_def(required_item)
		target = String(required_item) if item == null else item.display_name
	var detail := Label.new()
	detail.text = "%s · %s · %s\n%s\n%s · %d pieces\nNormal sale cash still pays · Completion premium: +%s coins" % [
		_commission_role_label(int(offer.get("offer_role", -1))),
		_commission_effort_label(int(offer.get("effort_band", 1))),
		_craft_family_label(int(offer.get("craft_family", 0))),
		String(offer.get("description", "")), target,
		int(offer.get("required_count", 0)),
		_thousands(int(offer.get("cash_bonus", 0)))]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)

	var offer_id := StringName(offer.get("id", &""))
	var active := GameState.is_commission_active(offer_id)
	if active:
		var progress := ProgressBar.new()
		progress.max_value = maxi(1, int(offer.get("required_count", 1)))
		progress.value = GameState.get_active_commission_progress_for(offer_id)
		progress.show_percentage = false
		row.add_child(progress)

	var button := Button.new()
	button.custom_minimum_size.y = 34
	if active:
		button.text = "In progress · %d / %d" % [
			GameState.get_active_commission_progress_for(offer_id),
			int(offer.get("required_count", 0))]
		button.disabled = true
	else:
		button.text = "Accept commission"
		button.pressed.connect(_on_accept_commission_pressed.bind(offer_id))
	row.add_child(button)

	var tuning := Label.new()
	tuning.text = "Experimental pacing · measured M9 review required"
	tuning.add_theme_font_size_override("font_size", 11)
	tuning.modulate = Color(0.72, 0.72, 0.72, 1.0)
	row.add_child(tuning)
	return row


func _build_customer_summary() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "CustomerCards"
	var heading := Label.new()
	heading.text = "Reputation %d · customer families" % GameState.get_reputation()
	heading.add_theme_font_size_override("font_size", 16)
	card.add_child(heading)
	for customer: CustomerDef in Orders.customers():
		if customer == null:
			continue
		var customer_row := HBoxContainer.new()
		customer_row.add_theme_constant_override("separation", 8)
		if not customer.portrait_candidate_path.is_empty():
			var portrait := TextureRect.new()
			portrait.name = "Portrait_%s" % customer.id
			portrait.custom_minimum_size = Vector2(64, 64)
			portrait.texture = load(customer.portrait_candidate_path) as Texture2D
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			portrait.tooltip_text = customer.art_status
			customer_row.add_child(portrait)
		var line := Label.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if customer.is_unlocked(GameState.get_reputation()):
			line.text = "✓ %s — %s" % [customer.display_name, customer.preference_copy]
		else:
			line.text = "Rep %d · %s — %s" % [customer.reputation_required,
				customer.display_name, customer.preference_copy]
			line.modulate = Color(0.62, 0.62, 0.62, 1.0)
		line.add_theme_font_size_override("font_size", 12)
		customer_row.add_child(line)
		card.add_child(customer_row)
	return card


func _craft_family_label(family: int) -> String:
	match family:
		CraftRequirementDef.Family.SPECIES:
			return "Species order"
		CraftRequirementDef.Family.SIZE_BAND:
			return "Size-band order"
		CraftRequirementDef.Family.QUALITY:
			return "Clean-grade order"
		CraftRequirementDef.Family.SIGNATURE:
			return "Signature order"
	return "Quantity order"


func _commission_role_label(role: int) -> String:
	match role:
		Orders.CommissionOfferRole.MIXED:
			return "Flexible yard work"
		Orders.CommissionOfferRole.FRONTIER:
			return "Frontier premium"
		Orders.CommissionOfferRole.ROTATION:
			return "Customer rotation"
	return "Standing commission"


func _commission_effort_label(band: int) -> String:
	match band:
		CommissionTemplateDef.EffortBand.STANDING:
			return "Standing contract"
		CommissionTemplateDef.EffortBand.PROJECT:
			return "Project contract"
	return "Major contract"


func _matching_contract_profile(order: OrderDef) -> UpgradeDef:
	if order == null:
		return null
	for def: UpgradeDef in MechanicalSplitter.profile_definitions():
		if def != null and def.unlock_order_id == order.id:
			return def
	# Norway Spruce's profile keeps its approved pre-Slice-6 gate. Its newly
	# authored species contract still names the route without falsely claiming to
	# be an additional progression prerequisite.
	if order.required_species != &"" \
			and order.id == StringName("%s_delivery" % order.required_species):
		return MechanicalSplitter.profile_for_species(order.required_species)
	return null


func _completed_profile_requirement(profile: UpgradeDef) -> String:
	if Shop.get_level(profile.id) > 0:
		return "purchased"
	if Shop.is_unlocked(profile.id):
		return "available in Shop"
	var requirements := PackedStringArray()
	if profile.required_mastery_species_id != &"" \
			and not GameState.is_species_mastered(profile.required_mastery_species_id):
		var species := SpeciesTable.by_id(profile.required_mastery_species_id)
		requirements.append("%s certification" % (
			String(profile.required_mastery_species_id) if species == null else species.display_name))
	if profile.required_upgrade_id != &"" and Shop.get_level(profile.required_upgrade_id) <= 0:
		requirements.append("Mechanical Splitter installation")
	return "available after remaining requirements" if requirements.is_empty() \
		else "available after %s" % " and ".join(requirements)


func _on_accept_order_pressed(order_id: StringName) -> void:
	GameState.accept_order(order_id)


func _on_accept_commission_pressed(offer_id: StringName) -> void:
	GameState.accept_commission(offer_id)


func _refresh_active_job_chip() -> void:
	if _active_job_chip == null:
		return
	if _modal_backdrop.visible:
		_active_job_chip.visible = false
		_position_top_right_panels(false)
		return
	for child in _active_job_list.get_children():
		_active_job_list.remove_child(child)
		child.queue_free()
	var count := GameState.get_active_manual_job_count()
	var pending_choice := GameState.has_pending_standing_commission_choice()
	if count == 0 and not pending_choice:
		_active_job_chip.visible = false
		_position_top_right_panels(false)
		return

	_active_job_chip.visible = true
	_active_job_scroll.visible = not _active_tasks_collapsed
	_active_job_toggle.text = "▾" if _active_tasks_collapsed else "▴"
	_active_job_toggle.tooltip_text = "%s active deliveries" % (
		"Expand" if _active_tasks_collapsed else "Collapse")
	_active_job_chip.offset_bottom = 70.0 if _active_tasks_collapsed else (
		330.0 if pending_choice else 184.0)
	_active_job_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if pending_choice:
		_active_job_button.text = "Standing commission available · choose 1 of 3"
		if not _active_tasks_collapsed:
			var intro := Label.new()
			intro.text = "One long-term background goal · progress and payout are automatic"
			intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			intro.add_theme_font_size_override("font_size", 11)
			intro.modulate = Color(0.86, 0.88, 0.82, 1.0)
			_active_job_list.add_child(intro)
			for offer: Dictionary in GameState.get_commission_offers():
				_active_job_list.add_child(_standing_commission_choice_button(offer))
		_position_top_right_panels(true)
		return
	if _active_tasks_collapsed:
		_active_job_button.text = _collapsed_active_task_text(count)
	else:
		_active_job_button.text = "Active deliveries · %d" % count
		for order_id: StringName in GameState.get_active_order_ids():
			var order := Orders.by_id(order_id)
			if order != null:
				_active_job_list.add_child(_active_task_button(
					"Contract · %s · %d/%d" % [order.title,
						GameState.get_active_order_progress_for(order_id), order.required_count],
					_OPEN_ORDERS_TAB))
		for offer: Dictionary in GameState.get_active_commissions():
			var progress := ProgressBar.new()
			progress.max_value = maxi(1, int(offer.get("required_count", 1)))
			progress.value = int(offer.get("progress", 0))
			progress.show_percentage = false
			progress.tooltip_text = "%s · %d/%d · pays automatically" % [
				String(offer.get("title", "Standing commission")),
				int(offer.get("progress", 0)), int(offer.get("required_count", 0))]
			_active_job_list.add_child(progress)
	_position_top_right_panels(true)


func _collapsed_active_task_text(count: int) -> String:
	var order_id := GameState.get_active_order_id()
	var order := Orders.by_id(order_id)
	if order != null:
		return "Tasks %d · %s · %d/%d" % [count, order.title,
			GameState.get_active_order_progress_for(order_id), order.required_count]
	var commission := GameState.get_active_commission()
	return "Tasks %d · %s · %d/%d" % [count,
		String(commission.get("title", "Standing commission")),
		GameState.get_active_commission_progress_for(
			StringName(commission.get("id", &""))),
		int(commission.get("required_count", 0))]


func _active_task_button(text: String, tab: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 30
	button.text = text
	button.tooltip_text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 11)
	button.flat = true
	button.pressed.connect(_on_active_task_row_pressed.bind(tab))
	return button


func _standing_commission_choice_button(offer: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 58
	button.add_theme_font_size_override("font_size", 11)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = "%s\n%s · %d pieces · +%s coins" % [
		String(offer.get("title", "Standing commission")),
		_craft_family_label(int(offer.get("craft_family", 0))),
		int(offer.get("required_count", 0)),
		_thousands(int(offer.get("cash_bonus", 0)))]
	button.tooltip_text = "%s\n%s\nNo expiry · automatic payout" % [
		String(offer.get("customer_name", "Standing customer")),
		String(offer.get("description", ""))]
	button.pressed.connect(_on_accept_commission_pressed.bind(
		StringName(offer.get("id", &""))))
	return button


func _position_top_right_panels(has_tasks: bool) -> void:
	var top := 36.0
	if has_tasks:
		top = 78.0 if _active_tasks_collapsed else _active_job_chip.offset_bottom + 8.0
	_splitter_runtime_card.offset_top = top
	_splitter_runtime_card.offset_bottom = top + 154.0


func _on_order_completed(order_id: StringName, cash_bonus: int) -> void:
	var order := Orders.by_id(order_id)
	var title := "Delivery complete" if order == null else order.title
	var detail := "+%s coin premium" % _thousands(cash_bonus)
	if order_id == Orders.COMMISSION_UNLOCK_ORDER_ID:
		detail += "  ·  Yard Commissions unlocked"
	_queue_delivery_receipt(title, detail, cash_bonus, false)


func _on_commission_completed(offer: Dictionary, cash_bonus: int) -> void:
	_queue_delivery_receipt(String(offer.get("title", "Standing commission")),
		"%s  ·  +%s project fund  ·  paid automatically%s" % [
			String(offer.get("customer_name", "Yard customer")),
			_thousands(cash_bonus),
			" · next choice ready" if GameState.has_pending_standing_commission_choice()
			else ""], cash_bonus, true)


func _on_reputation_changed(_new_total: int) -> void:
	_refresh_reveal_visibility()
	_rebuild_orders()
	_rebuild_atlas()
	_refresh_badges()


func _on_manual_piece_settled(receipt: ManualPieceReceipt, craft_bonus: int) -> void:
	if receipt == null:
		return
	_craft_feedback.text = "%s piece · %d%% size" % [
		Craftsmanship.grade_name(receipt.grade),
		int(round(receipt.normalized_size * 100.0))]
	if craft_bonus > 0:
		_craft_feedback.text += " · +%s craft" % _thousands(craft_bonus)
	_craft_feedback.modulate.a = 1.0
	_craft_feedback.visible = true
	if _craft_feedback_tween != null and _craft_feedback_tween.is_valid():
		_craft_feedback_tween.kill()
	_craft_feedback_tween = create_tween()
	_craft_feedback_tween.tween_interval(1.15)
	_craft_feedback_tween.tween_property(_craft_feedback, "modulate:a", 0.0, 0.35)
	_craft_feedback_tween.tween_callback(func() -> void:
		_craft_feedback.visible = false
		_craft_feedback.modulate.a = 1.0)


func _queue_delivery_receipt(title: String, detail: String, cash_bonus: int,
		replaced_offer: bool) -> void:
	_delivery_receipt_pending.append({
		"title": title,
		"detail": detail,
		"cash_bonus": maxi(0, cash_bonus),
		"replaced_offer": replaced_offer,
	})
	if _delivery_receipt_flush_queued:
		return
	_delivery_receipt_flush_queued = true
	_flush_delivery_receipt_batch.call_deferred()


func _flush_delivery_receipt_batch() -> void:
	_delivery_receipt_flush_queued = false
	if _delivery_receipt_pending.is_empty():
		return
	var entries := _delivery_receipt_pending.duplicate(true)
	_delivery_receipt_pending.clear()
	var total_bonus := 0
	var replacements := 0
	for entry: Dictionary in entries:
		total_bonus += int(entry.get("cash_bonus", 0))
		if bool(entry.get("replaced_offer", false)):
			replacements += 1
	var title := String(entries[0].get("title", "Delivery complete"))
	var detail := String(entries[0].get("detail", ""))
	if entries.size() > 1:
		title = "%d deliveries complete" % entries.size()
		var lines := PackedStringArray()
		for entry: Dictionary in entries:
			lines.append("%s · +%s" % [String(entry.get("title", "Delivery")),
				_thousands(int(entry.get("cash_bonus", 0)))])
		lines.append("Total project funding · +%s%s" % [_thousands(total_bonus),
			" · next standing choice ready" if replacements > 0 else ""])
		detail = "\n".join(lines)
	_delivery_receipt_queue.append({
		"title": title,
		"detail": detail,
		"entry_count": entries.size(),
	})
	_play_next_delivery_receipt()


func _show_delivery_receipt(title: String, detail: String) -> void:
	_queue_delivery_receipt(title, detail, 0, false)


func _play_next_delivery_receipt() -> void:
	if _delivery_receipt_showing or _delivery_receipt_queue.is_empty():
		return
	_delivery_receipt_showing = true
	var batch: Dictionary = _delivery_receipt_queue.pop_front()
	var entry_count := maxi(1, int(batch.get("entry_count", 1)))
	_delivery_receipt_title.text = String(batch.get("title", "Delivery complete"))
	_delivery_receipt_detail.text = String(batch.get("detail", ""))
	_delivery_receipt.offset_bottom = 142.0 if entry_count == 1 \
		else minf(220.0, 118.0 + float(entry_count) * 26.0)
	_delivery_receipt.modulate = Color.WHITE
	_delivery_receipt.visible = true
	var hold := _RECEIPT_SINGLE_HOLD if entry_count == 1 else \
		_RECEIPT_AGGREGATE_HOLD + float(entry_count - 2) * _RECEIPT_PER_EXTRA_HOLD
	_delivery_receipt_tween = create_tween()
	_delivery_receipt_tween.tween_interval(hold)
	_delivery_receipt_tween.tween_property(
		_delivery_receipt, "modulate:a", 0.0, _RECEIPT_FADE)
	_delivery_receipt_tween.tween_callback(func() -> void:
		_delivery_receipt.visible = false
		_delivery_receipt.modulate = Color.WHITE
		_delivery_receipt_showing = false
		_play_next_delivery_receipt())


func _on_close_skill_pressed() -> void:
	_on_player_closed_panels()


## Each campaign-relevant branch owns one tab. This keeps the opening readable
## and lets later mechanics arrive as clear additions instead of grey clutter.
func _rebuild_skills() -> void:
	if _skill_boughs == null:
		return   # _ready has not run yet; the initial build is at the end of it
	if _rebuilding_skill_tabs:
		return
	_rebuilding_skill_tabs = true
	for child in _skill_boughs.get_children():
		_skill_boughs.remove_child(child)
		child.queue_free()

	var available := displayed_skill_points_available()
	_points_label.text = "%d point%s   ·   level %d" % [
		available, "" if available == 1 else "s",
		GameState.get_level_for_xp(_displayed_xp_total)]

	var revealed: Array[SkillBranchDef] = []
	for branch: SkillBranchDef in M7CContent.branches().branches:
		if branch != null and SkillTree.is_branch_presented(branch.id):
			revealed.append(branch)
	if revealed.is_empty():
		_rebuilding_skill_tabs = false
		return
	var previous_branch := _presented_skill_branch
	_skill_branch_tabs.clear_tabs()
	for branch: SkillBranchDef in revealed:
		_skill_branch_tabs.add_tab(branch.display_name)
		_skill_branch_tabs.set_tab_metadata(_skill_branch_tabs.tab_count - 1,
			branch.id)
	var selected_index := 0
	for index in range(_skill_branch_tabs.tab_count):
		if StringName(_skill_branch_tabs.get_tab_metadata(index)) == previous_branch:
			selected_index = index
			break
	_skill_branch_tabs.current_tab = selected_index
	_presented_skill_branch = StringName(
		_skill_branch_tabs.get_tab_metadata(selected_index))
	var revealed_graph_height := 0.0
	for branch: SkillBranchDef in revealed:
		if branch.id != _presented_skill_branch:
			continue
		var column := VBoxContainer.new()
		column.name = String(branch.id).to_pascal_case() + "Tree"
		column.custom_minimum_size = Vector2(170.0, 0.0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 3)
		var title := Label.new()
		title.text = branch.display_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", branch.color.darkened(0.28))
		title.add_theme_font_size_override("font_size", 14)
		column.add_child(title)
		var graph := SkillGraphView.new()
		graph.name = "Graph"
		graph.node_selected.connect(_on_buy_skill_pressed)
		graph.configure(branch, &"", available)
		revealed_graph_height = maxf(revealed_graph_height,
			graph.custom_minimum_size.y)
		column.add_child(graph)
		_skill_boughs.add_child(column)
	_resize_skill_panel(revealed_graph_height)
	_refresh_respec_button()
	_rebuilding_skill_tabs = false


func _on_skill_branch_tab_changed(index: int) -> void:
	if _rebuilding_skill_tabs:
		return
	if index < 0 or index >= _skill_branch_tabs.tab_count:
		return
	_presented_skill_branch = StringName(_skill_branch_tabs.get_tab_metadata(index))
	_rebuild_skills()


func _resize_skill_panel(graph_height: float) -> void:
	var height := clampf(graph_height + _SKILL_PANEL_CHROME_HEIGHT,
		_SKILL_PANEL_MIN_HEIGHT, _SKILL_PANEL_MAX_HEIGHT)
	_skill_panel.offset_top = -height * 0.5
	_skill_panel.offset_bottom = height * 0.5


## Legacy deterministic shot seam. Selection has no visual state now because the
## tooltip owns explanation and a real click owns purchase.
func debug_select_skill(id: StringName) -> bool:
	var def := SkillTree.get_node_def(id)
	if def == null or not SkillTree.is_branch_revealed(def.branch_id):
		return false
	return true


func _on_buy_skill_pressed(id: StringName) -> void:
	# SkillTree.buy is atomic — an unaffordable or gated node spends nothing and
	# moves nothing. The repaint rides in on skill_level_changed.
	if displayed_skill_points_available() <= 0:
		return
	SkillTree.buy(id)


func _refresh_respec_button() -> void:
	if _skill_respec_button == null:
		return
	var cost := GameState.get_skill_respec_cost()
	_skill_respec_button.text = "Respec all · 20%% · %s coins" % _thousands(cost)
	_skill_respec_button.disabled = not GameState.can_respec_skills()
	_skill_respec_button.tooltip_text = (
		"Refund every learned skill point for %s coins (20%% of your current cash)."
		% _thousands(cost))


func _on_respec_skills_pressed() -> void:
	GameState.respec_skills()
	_refresh_respec_button()


func _refresh_xp_bar() -> void:
	if _xp_level_label == null:
		return
	var level := _xp_level_up_hold_level if _xp_level_up_hold_level > 0 \
		else GameState.get_level_for_xp(_displayed_xp_total)
	var progress := 1.0 if _xp_level_up_hold_level > 0 \
		else GameState.get_level_progress_for_xp(_displayed_xp_total)
	var xp_to_go := 0 if _xp_level_up_hold_level > 0 \
		else GameState.get_xp_to_next_level_for_xp(_displayed_xp_total)
	_xp_progress.value = progress
	var available := maxi(0, _displayed_skill_points_earned \
		- GameState.get_skill_points_spent())
	var points := "   ·   %d pt%s" % [available, "" if available == 1 else "s"] if available > 0 else ""
	_xp_level_label.text = "Level %d   ·   %s XP to go%s" % [
		level, _thousands(xp_to_go),
		points]


func _on_xp_orb_batch_started(amount: int) -> void:
	if amount <= 0:
		return
	var was_pending := _pending_orb_xp
	_pending_orb_xp += amount
	_inflight_orb_xp += amount
	if was_pending == 0 and not _xp_delivery_animating:
		_displayed_xp_total = maxi(0, GameState.get_xp() - _pending_orb_xp)
	_refresh_xp_bar()


func _on_xp_orb_collected(amount: int, tier := 0) -> void:
	var delivered := clampi(amount, 0, _inflight_orb_xp)
	if delivered <= 0:
		return
	_pulse_xp_arrival(tier)
	_inflight_orb_xp -= delivered
	_xp_delivery_queue.append(delivered)
	if not _xp_delivery_flush_queued:
		_xp_delivery_flush_queued = true
		_process_xp_delivery_queue.call_deferred()


func _process_xp_delivery_queue() -> void:
	_xp_delivery_flush_queued = false
	if _xp_delivery_animating or _xp_delivery_queue.is_empty():
		return
	_xp_delivery_animating = true
	var generation := _xp_delivery_generation
	while not _xp_delivery_queue.is_empty():
		var amount: int = _xp_delivery_queue.pop_front()
		while amount > 0:
			var old_level := GameState.get_level_for_xp(_displayed_xp_total)
			var to_boundary := GameState.get_xp_to_next_level_for_xp(
				_displayed_xp_total)
			if amount < to_boundary:
				_displayed_xp_total += amount
				_pending_orb_xp = maxi(0, _pending_orb_xp - amount)
				amount = 0
				_refresh_xp_bar()
				continue
			_displayed_xp_total += to_boundary
			_pending_orb_xp = maxi(0, _pending_orb_xp - to_boundary)
			amount -= to_boundary
			_xp_level_up_hold_level = old_level
			_refresh_xp_bar()
			await get_tree().create_timer(
				_xp_pacing.level_up_bar_hold_seconds).timeout
			if generation != _xp_delivery_generation or not is_inside_tree():
				return
			_xp_level_up_hold_level = 0
			_present_displayed_level(old_level + 1)
	if generation != _xp_delivery_generation:
		return
	_xp_delivery_animating = false
	if _pending_orb_xp == 0 and _inflight_orb_xp == 0:
		_displayed_xp_total = GameState.get_xp()
		_displayed_skill_points_earned = GameState.get_skill_points_earned()
		_pending_skill_point_rewards.clear()
	if _pending_orb_xp == 0 and _inflight_orb_xp == 0:
		_refresh_presented_progress()
	else:
		_refresh_xp_bar()


func _present_displayed_level(level: int) -> void:
	var earned_point := _pending_skill_point_rewards.has(level) \
		and int(_pending_skill_point_rewards[level]) > 0
	if _pending_skill_point_rewards.has(level):
		_displayed_skill_points_earned += int(_pending_skill_point_rewards[level])
		_pending_skill_point_rewards.erase(level)
	_refresh_presented_progress()
	displayed_level_gained.emit(level)
	if earned_point:
		AudioDirector.play_ui(&"skill_point")


func _settle_unbatched_progress() -> void:
	if _pending_orb_xp > 0 or _inflight_orb_xp > 0 \
			or _xp_delivery_animating or not _xp_delivery_queue.is_empty():
		return
	_displayed_xp_total = GameState.get_xp()
	_displayed_skill_points_earned = GameState.get_skill_points_earned()
	_pending_skill_point_rewards.clear()
	_refresh_presented_progress()


func _refresh_presented_progress() -> void:
	_refresh_xp_bar()
	_refresh_reveal_visibility()
	if _trees_panel.visible:
		_rebuild_woodshed()
	if _skill_panel.visible:
		_rebuild_skills()
	_refresh_badges()
	if _tutorial != null:
		_tutorial.notify_presented_progress_changed()


func displayed_skill_points_earned() -> int:
	return _displayed_skill_points_earned


func displayed_level() -> int:
	return _xp_level_up_hold_level if _xp_level_up_hold_level > 0 \
		else GameState.get_level_for_xp(_displayed_xp_total)


func displayed_skill_points_available() -> int:
	return maxi(0, _displayed_skill_points_earned \
		- GameState.get_skill_points_spent())


## Normalized window coordinate of the live fill edge. XPOrb maps this into its
## own SubViewport before projecting it onto a plane in front of the 3D camera.
func xp_orb_target_normalized() -> Vector2:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.0)
	var rect := _xp_progress.get_global_rect()
	var span := maxf(_xp_progress.max_value - _xp_progress.min_value, 0.0001)
	var progress := clampf((_xp_progress.value - _xp_progress.min_value) / span, 0.0, 1.0)
	# Keep the orb centre just inside the window at empty/full while still landing
	# on the bar's visible leading edge.
	var inset := minf(4.0, rect.size.x * 0.5)
	var target := Vector2(
		lerpf(rect.position.x + inset, rect.end.x - inset, progress),
		rect.position.y + rect.size.y * 0.5)
	return Vector2(target.x / viewport_size.x, target.y / viewport_size.y)


func coin_target_normalized() -> Vector2:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var rect := _cash_label.get_global_rect()
	var target := rect.position + rect.size * 0.5
	return Vector2(target.x / viewport_size.x, target.y / viewport_size.y)


func _on_coin_batch_started(count: int) -> void:
	_pending_coin_count += maxi(0, count)


func _on_coin_collected(amount: int, tier := 0) -> void:
	_pending_coin_count = maxi(0, _pending_coin_count - 1)
	# The authoritative cash already exists by the time a coin is released. Clamp
	# to it so presentation can never mint money, then punch once for this impact.
	var next_amount := mini(GameState.get_cash(), _displayed_cash + maxi(0, amount))
	_set_displayed_cash(next_amount, next_amount > _displayed_cash, tier)


func _on_coins_cancelled(count: int) -> void:
	_pending_coin_count = maxi(0, _pending_coin_count - maxi(0, count))


func _on_coin_batch_finished() -> void:
	# Manual and splitter pools may overlap. Collected/cancelled receipts own the
	# shared count; finishing one pool must not erase the other pool's pending coin.
	if _pending_coin_count == 0:
		_set_displayed_cash(GameState.get_cash(), false)
		if _cash_ui_refresh_queued:
			_flush_cash_ui_refresh.call_deferred()


## ----------------------------------------------------------------- live view
func _on_cash_changed(new_amount: int) -> void:
	# While receipt coins are live, positive awards remain visually pending until
	# each coin reaches this counter. Reductions (purchases/load/reset) still paint
	# immediately so the displayed balance can never exceed authoritative cash.
	if _pending_coin_count == 0 or new_amount <= _displayed_cash:
		_set_displayed_cash(new_amount, new_amount > _displayed_cash)
	_queue_cash_ui_refresh()


func _queue_cash_ui_refresh() -> void:
	if _cash_ui_refresh_queued:
		return
	_cash_ui_refresh_queued = true
	if _pending_coin_count == 0:
		_flush_cash_ui_refresh.call_deferred()


func _flush_cash_ui_refresh() -> void:
	if not _cash_ui_refresh_queued:
		return
	if _pending_coin_count > 0:
		return
	_cash_ui_refresh_queued = false
	_refresh_reveal_visibility()
	_refresh_badges()
	if _shop_panel.visible:
		_rebuild_shop()
	if _trees_panel.visible:
		_rebuild_woodshed()
	if _skill_panel.visible:
		_refresh_respec_button()

func _set_displayed_cash(amount: int, punch: bool, tier := 0) -> void:
	var increase := maxi(0, amount - _displayed_cash)
	_displayed_cash = amount
	_refresh_stats()
	if punch and increase > 0:
		_bounce_cash_counter(increase, tier)


func _bounce_cash_counter(amount: int, tier := 0) -> void:
	if _cash_bounce_tween != null and _cash_bounce_tween.is_valid():
		_cash_bounce_tween.kill()
	_cash_label.pivot_offset = _cash_label.size * 0.5
	# Apply the growth immediately so two coins arriving in one render frame still
	# contribute two distinct impulses instead of the later tween replacing the
	# earlier one. The cap keeps a dense late-game wave inside the HUD.
	# PLACEHOLDER pending the UI feel pass.
	var impulse := clampf(0.035 + log(float(amount) + 1.0) / log(10.0) * 0.018
		+ float(clampi(tier, 0, 3)) * 0.012,
		0.035, 0.075)
	var current_scale := maxf(1.0, _cash_label.scale.x)
	var punched_scale := minf(1.36, current_scale + impulse)
	_cash_label.scale = Vector2.ONE * punched_scale
	_cash_bounce_tween = create_tween()
	_cash_bounce_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_cash_bounce_tween.tween_property(_cash_label, "scale", Vector2.ONE, 0.22)


func _pulse_xp_arrival(tier: int) -> void:
	var safe_tier := clampi(tier, 0, 3)
	var color: Color = GameConfig.current().reward_bursts.xp_tier_colors[safe_tier]
	_xp_progress.self_modulate = Color(color.r, color.g, color.b, 1.0)
	if _xp_pulse_tween != null and _xp_pulse_tween.is_valid():
		_xp_pulse_tween.kill()
	_xp_pulse_tween = create_tween()
	_xp_pulse_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_xp_pulse_tween.tween_property(_xp_progress, "self_modulate", Color.WHITE,
		0.16 + float(safe_tier) * 0.04)


func _refresh_stats() -> void:
	_cash_label.text = _compact_number(_displayed_cash)
	_cash_label.tooltip_text = "%s coins" % _thousands(_displayed_cash)


## Red icon badges are a call to action, not a second economy display. Skills
## shows unspent points; Contracts counts orders the player can accept now; Shop
## counts equipment/splitter purchases the player can make now, while Trees owns
## the next-species purchase callout.
func _refresh_badges() -> void:
	if _orders_badge == null or _skills_badge == null or _shop_badge == null \
			or _trees_badge == null:
		return
	var available_orders := 0
	for order: OrderDef in Orders.visible():
		if Orders.is_available(order) and not GameState.is_order_active(order.id):
			available_orders += 1
	_set_badge(_orders_badge, available_orders)
	_set_badge(_skills_badge, GameState.get_skill_points_available())
	var affordable_upgrades := 0
	for def: UpgradeDef in Shop.get_visible_upgrades():
		if def != null and Shop.can_buy(def.id):
			affordable_upgrades += 1
	_set_badge(_shop_badge, affordable_upgrades)
	var affordable_trees := 0
	var next := GameState.get_next_unowned_species()
	if next != null and GameState.can_species_be_bought(next.id) \
			and GameState.can_afford_cash(next.unlock_cost):
		affordable_trees = 1
	_set_badge(_trees_badge, affordable_trees)


func _set_badge(badge: Label, amount: int) -> void:
	badge.visible = amount > 0
	badge.text = "!"
