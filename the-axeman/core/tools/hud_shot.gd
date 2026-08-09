extends Node
## FILE: res://core/tools/hud_shot.gd
## ATTACHES TO: root Node of res://core/tools/hud_shot.tscn. DEV TOOL, not shipped.
##
## RUN NON-HEADLESS (F6, or with the scene path and no --headless): it renders the
## real main.tscn — chopping HUD, panels, stockpile and haul-away — to PNGs in user://,
## because every numeric check in this project can be green on a UI that is
## off-screen, unreadably small, or covering the chopping block. This is the
## shot_runner pattern applied to the 2D side.
##
## It drives the REAL scene and the REAL signals: firewood arrives via A7
## resource_gathered exactly as the mini-game deposits it, panels open through
## the HUD's own icon buttons, and the haul-away is the production one.
##
## SAFETY: main.tscn autosaves, so this moves any existing save aside for the run
## and puts it back afterwards. A dev screenshot must not be able to overwrite
## Sam's yard with test firewood.

const OUT := "user://hud_shot"
const _BACKUP := "user://the_axeman_save.shotbackup"


func _ready() -> void:
	_stash_save()

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.start_new_game()
	for i in range(10):
		await get_tree().process_frame

	var hud: Control = main.get_node("UI_Overlay/YardHUD")
	var mg: Node3D = main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")

	# A chopping session part way through a working day: cash earned, wood chopped,
	# the compact action dock visible, the XP strip half full, and a load
	# stacked. The pile pieces go in the way the game adds them, one at a time.
	GameState.add_cash(370)
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(Orders.JOBS_UNLOCK_LEVEL))
	for i in range(26):
		EventBus.resource_gathered.emit(&"birch_firewood", 1)
		GameState.add_to_yard_pile(&"birch_firewood", 1)
	for i in range(14):
		EventBus.resource_gathered.emit(&"oak_firewood", 1)
		GameState.add_to_yard_pile(&"oak_firewood", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_save("_1_chopping")

	# Level 3 discovery state: Jobs is present while Shop is still absent, and the
	# first card explains the completion reward that introduces it.
	hud.get_node("QuickMenu/OrdersButton").pressed.emit()
	await get_tree().process_frame
	_save("_1b_contracts_fresh")
	hud.get_node("OrdersPanel/Column/CloseButton").pressed.emit()

	# Finish the real introductory job before capturing the newly revealed Shop.
	var opening_job := Orders.by_id(&"campfire_warmup")
	if opening_job != null and GameState.accept_order(opening_job.id):
		for _piece in range(opening_job.required_count):
			GameState.record_order_piece(&"birch_firewood")
	# The shop: Sam's coin on the newly revealed button and on the counter.
	hud.get_node("QuickMenu/ShopButton").pressed.emit()
	await get_tree().process_frame
	_save("_2_shop")
	hud.get_node("ShopPanel/Column/CloseShopButton").pressed.emit()

	# The woodshed with an authored mastery rung reached. Progress moves through
	# the same GameState receipt used by completed manual logs, so this shot shows
	# the live next-reward copy and bar rather than a UI-only staged value.
	for _i in range(5):
		GameState.record_species_completion(SpeciesTable.starting_species().id)
	hud.get_node("QuickMenu/TreesButton").pressed.emit()
	await get_tree().process_frame
	_save("_2b_woodshed")
	hud.get_node("TreesPanel/Column/CloseButton").pressed.emit()

	# Fresh three-tree state: every branch is present and all interaction lives on
	# the square nodes; there is no secondary purchase panel.
	hud.get_node("QuickMenu/SkillsButton").pressed.emit()
	hud.debug_select_skill(&"ready_stance")
	await get_tree().process_frame
	_save("_2c_skills_fresh")
	var hover_skill := _find_skill_button(hud, &"ready_stance")
	if hover_skill != null:
		# Native tooltip timers do not fire reliably in an automated Compatibility
		# capture. Mount the button's exact custom tooltip for one QA frame instead.
		var tooltip_card := hover_skill._make_custom_tooltip(
			hover_skill.tooltip_text) as Control
		hud.add_child(tooltip_card)
		tooltip_card.global_position = hover_skill.get_global_rect().get_center() \
			+ Vector2(28.0, -28.0)
		await get_tree().process_frame
		_save("_2c_skills_tooltip")
		tooltip_card.queue_free()
		await get_tree().process_frame
	hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()

	# Part way up: learned foundations, points in hand and a selected Technique
	# proc make branch identity, selection and affordability visible together.
	GameState.add_xp(30000)
	SkillTree.buy(&"quick_hands")
	SkillTree.buy(&"strong_arms")
	hud.get_node("QuickMenu/SkillsButton").pressed.emit()
	hud.debug_select_skill(&"quick_study")
	await get_tree().process_frame
	_save("_2c_skills")
	hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()

	# A real v1 fixture after migration: retained ranks stay learned and retired
	# spend returns through the derived point balance. Restore the working-day
	# state immediately after the shot so later pile/haul images remain honest.
	var before_migration_shot := GameState.to_save_dict()
	var fixture := ConfigFile.new()
	if fixture.load("res://core/tests/fixtures/m7c_v1_all_skill_mappings.cfg") == OK:
		var fixture_data: Variant = fixture.get_value("progression", "data", {})
		if fixture_data is Dictionary:
			GameState.apply_save_dict(SaveSystem._migrate(fixture_data as Dictionary, 1))
			hud.get_node("QuickMenu/SkillsButton").pressed.emit()
			hud.debug_select_skill(&"ready_stance")
			await get_tree().process_frame
			_save("_2c_skills_migration_refund")
			hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()
	GameState.apply_save_dict(before_migration_shot)
	await get_tree().process_frame

	# Earth Master reveals the fourth navigation tab and its hidden model nodes.
	var frontier_state := GameState.to_save_dict()
	frontier_state["earth_finale_state"] = GameState.EarthFinaleState.COMPLETE
	frontier_state["earth_finale_splits"] = 3
	frontier_state["earth_master"] = true
	GameState.apply_save_dict(frontier_state)
	hud.get_node("QuickMenu/SkillsButton").pressed.emit()
	hud.debug_select_skill(&"specimen_handling")
	await get_tree().process_frame
	_save("_2c_skills_frontier")
	hud.get_node("SkillPanel/Column/CloseSkillButton").pressed.emit()

	# The contract board uses temporary native geometry/materials until Sam's yard
	# art arrives. Show both the three authored cards and live progress on one.
	GameState.accept_order(&"aspen_hearth_load")
	for i in range(6):
		EventBus.resource_gathered.emit(&"aspen_firewood", 1)
		Orders.settle_piece(&"aspen_firewood")
	hud.get_node("QuickMenu/OrdersButton").pressed.emit()
	await get_tree().process_frame
	_save("_2d_orders")
	hud.get_node("OrdersPanel/Column/CloseButton").pressed.emit()

	# The load is full and leaves the yard. This is the production haul, caught
	# mid-flight — the point of the shot is that the wood is IN THE AIR and on its
	# way off screen, which no counter can tell us.
	mg._haul_away()
	for i in range(12):
		await get_tree().process_frame
	_save("_4_hauling")
	for i in range(60):
		await get_tree().process_frame
	_save("_5_hauled")

	main.queue_free()
	await get_tree().process_frame
	_restore_save()
	get_tree().quit()


func _find_skill_button(hud: Control, skill_id: StringName) -> Button:
	for candidate: Node in hud.find_children("*", "Button", true, false):
		if candidate.get_meta("skill_id", &"") == skill_id:
			return candidate as Button
	return null


func _save(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + tag + ".png")
	print("SHOT saved: " + tag)


func _stash_save() -> void:
	if not FileAccess.file_exists(SaveSystem.SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP)


func _restore_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.remove(SaveSystem.SAVE_PATH)
	if FileAccess.file_exists(_BACKUP):
		dir.rename(_BACKUP, SaveSystem.SAVE_PATH)
