extends Node
## Production-backed acceptance for every disposable run power at rank one.
##
## The suite deliberately separates the public unlock/offer contract from its
## deterministic effect probes. Blueprint ownership enters through GameState's
## public unlock authority, and one real offer is selected twice to prove that
## rank one takes effect immediately and the same slot advances to rank two.
## The debug rank seam then gives each power a fresh production run
## so failures identify one effect instead of depending on offer RNG.

const _SAVE_PATH := "user://run_power_runtime_acceptance.cfg"
const _AREA_CAPTURE_PATH := "/private/tmp/axeman_area_size_aoe.png"
# Rendered screenshots can stall briefly while shader variants compile on a cold
# compatibility renderer. Keep the watchdog diagnostic, but leave enough room for
# that one-time work so a slow render is not reported as a gameplay failure.
const _WATCHDOG_SECONDS := 90.0
const _EPSILON := 0.0001

const _CORE_IDS: Array[StringName] = [
	&"deep_bite", &"quick_hands", &"scar_wisdom", &"double_chop",
	&"follow_up", &"splinter_volley", &"flying_wedge", &"yard_magnet",
	&"soft_landing", &"ring_reinforcement", &"quick_study",
	&"keen_appraisal", &"area_size", &"sawblade_halo",
]

const _BLUEPRINT_IDS: Array[StringName] = [
	&"grain_reader", &"earthshaker", &"powder_keg", &"kindling_chain",
	&"whirling_axe", &"crosscut_sweep", &"maul_drop", &"splitter_rig",
	&"cant_hook", &"stump_pulse", &"last_ditch_rescue", &"momentum",
	&"timber_burst",
]

## Exact first authored values. Keeping the effect kind beside every value
## catches the easy-to-miss failure where a valid ladder is wired to the wrong
## gameplay consumer.
const _RANK_ONE_EFFECTS := {
	&"deep_bite": {
		ProgressionEffectDef.Kind.SPLIT_RELIABILITY: 0.04,
	},
	&"quick_hands": {
		ProgressionEffectDef.Kind.SWING_RECOVERY: 0.04,
	},
	&"scar_wisdom": {
		ProgressionEffectDef.Kind.SCAR_RELIABILITY: 0.05,
	},
	&"double_chop": {
		ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS: 1.0,
	},
	&"follow_up": {
		ProgressionEffectDef.Kind.FOLLOW_UP_CHANCE: 0.15,
		ProgressionEffectDef.Kind.FOLLOW_UP_DEPTH: 1.0,
	},
	&"splinter_volley": {
		ProgressionEffectDef.Kind.SPLINTER_COUNT: 1.0,
	},
	&"flying_wedge": {
		ProgressionEffectDef.Kind.FLYING_WEDGE_INTERVAL: 12.0,
		ProgressionEffectDef.Kind.FLYING_WEDGE_CUT_COUNT: 1.0,
	},
	&"yard_magnet": {
		ProgressionEffectDef.Kind.YARD_MAGNET_FORCE: 0.1,
		ProgressionEffectDef.Kind.YARD_MAGNET_PULSE_INTERVAL: 5.0,
	},
	&"soft_landing": {
		ProgressionEffectDef.Kind.ARRIVAL_LATERAL_MULTIPLIER: 0.92,
		ProgressionEffectDef.Kind.ARRIVAL_BOUNCE_MULTIPLIER: 0.90,
		ProgressionEffectDef.Kind.ARRIVAL_OUTWARD_MULTIPLIER: 0.92,
	},
	&"ring_reinforcement": {
		ProgressionEffectDef.Kind.BOUNDARY_RADIUS: 0.12,
		ProgressionEffectDef.Kind.BOUNDARY_GRACE: 0.40,
	},
	&"quick_study": {
		ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER: 1.10,
	},
	&"keen_appraisal": {
		ProgressionEffectDef.Kind.SESSION_CASH_MULTIPLIER: 1.10,
	},
	&"area_size": {
		ProgressionEffectDef.Kind.AREA_SIZE_MULTIPLIER: 1.10,
	},
	&"sawblade_halo": {
		ProgressionEffectDef.Kind.SAWBLADE_HALO_INTERVAL: 12.0,
		ProgressionEffectDef.Kind.SAWBLADE_HALO_RADIUS: 1.50,
	},
	&"grain_reader": {
		ProgressionEffectDef.Kind.GRAIN_MARK_CHANCE: 0.10,
		ProgressionEffectDef.Kind.GRAIN_BONUS_XP_MULTIPLIER: 1.50,
	},
	&"earthshaker": {
		ProgressionEffectDef.Kind.EARTHSHAKER_TRIGGER_CUTS: 4.0,
		ProgressionEffectDef.Kind.EARTHSHAKER_RADIUS: 1.50,
		ProgressionEffectDef.Kind.EARTHSHAKER_INWARD_FORCE: 2.0,
	},
	&"powder_keg": {
		ProgressionEffectDef.Kind.POWDER_KEG_RADIUS: 1.50,
		ProgressionEffectDef.Kind.POWDER_KEG_CUT_COUNT: 2.0,
		ProgressionEffectDef.Kind.POWDER_KEG_INWARD_FORCE: 2.0,
	},
	&"kindling_chain": {
		ProgressionEffectDef.Kind.KINDLING_CHAIN_COUNT: 1.0,
		ProgressionEffectDef.Kind.KINDLING_CHAIN_RANGE: 1.50,
	},
	&"whirling_axe": {
		ProgressionEffectDef.Kind.ORBITING_AXE_COUNT: 1.0,
		ProgressionEffectDef.Kind.ORBITING_AXE_CONTACT_COOLDOWN: 2.0,
	},
	&"crosscut_sweep": {
		ProgressionEffectDef.Kind.CROSSCUT_SWEEP_INTERVAL: 14.0,
		ProgressionEffectDef.Kind.CROSSCUT_SWEEP_WIDTH: 2.0,
	},
	&"maul_drop": {
		ProgressionEffectDef.Kind.MAUL_DROP_INTERVAL: 18.0,
		ProgressionEffectDef.Kind.MAUL_DROP_CUT_COUNT: 3.0,
	},
	&"splitter_rig": {
		ProgressionEffectDef.Kind.SPLITTER_RIG_INTERVAL: 18.0,
	},
	&"cant_hook": {
		ProgressionEffectDef.Kind.CANT_HOOK_FORCE: 1.0,
	},
	&"stump_pulse": {
		ProgressionEffectDef.Kind.STUMP_PULSE_INTERVAL: 14.0,
		ProgressionEffectDef.Kind.STUMP_PULSE_FORCE: 2.0,
	},
	&"last_ditch_rescue": {
		ProgressionEffectDef.Kind.RESCUE_CHARGES: 1.0,
	},
	&"momentum": {
		ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS: 3.0,
		ProgressionEffectDef.Kind.MOMENTUM_SPEED_PER_STACK: 0.02,
		ProgressionEffectDef.Kind.MOMENTUM_RELIABILITY_PER_STACK: 0.01,
	},
	&"timber_burst": {
		ProgressionEffectDef.Kind.TIMBER_BURST_RADIUS: 1.20,
	},
}

var _passed := 0
var _failed := 0
var _completed := false
var _main: AxemanMain
var _run: RunDirector
var _game: Node
var _arena: LooseLogArena
var _hud: YardHUD


func _ready() -> void:
	print("=== RUN POWER RUNTIME ACCEPTANCE ===")
	get_tree().create_timer(_WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	_completed = await _run_scenario()
	_check(_completed, "the all-power production scenario reached its completion sentinel")
	print("RUN POWER RUNTIME: %d passed, %d failed" % [_passed, _failed])
	await _cleanup()
	get_tree().quit(0 if _failed == 0 else 1)


func _run_scenario() -> bool:
	if not _prepare_isolated_profile():
		return false
	_test_catalogue_rank_one_contract()
	await _boot_production_main()
	if _run == null or _game == null or _arena == null or _hud == null:
		return false
	_test_uniform_power_identity_selection()
	await _test_legitimate_rank_up()
	await _test_quality_offer_headroom()
	await _test_rank_one_effect_composition()
	# Runtime and presentation probes live below the composition contract. They
	# intentionally use fresh attempts so one proc cannot satisfy another check.
	await _test_direct_cut_powers()
	await _test_physics_and_boundary_powers()
	await _test_reward_and_grain_powers()
	await _test_grain_suspend_restore()
	await _test_periodic_and_completion_powers()
	await _test_area_size_and_new_aoe_powers()
	await _test_boosted_single_target_receipts()
	await _test_off_block_destruction_and_migration()
	await _test_capped_automatic_completion()
	await _test_momentum_rescue_and_persistence()
	return true


func _prepare_isolated_profile() -> bool:
	var isolated := SaveSystem.set_save_path_for_tests(_SAVE_PATH)
	_remove_save_files()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var clean_core := GameState.get_unlocked_run_powers()
	var core_ok := clean_core.size() == _CORE_IDS.size()
	for id: StringName in _CORE_IDS:
		core_ok = core_ok and GameState.is_run_power_unlocked(id)
	_check(isolated and core_ok,
		"the isolated clean profile owns exactly the fourteen Core powers")
	if not isolated or not core_ok:
		return false
	var blueprints_ok := true
	for id: StringName in _BLUEPRINT_IDS:
		blueprints_ok = GameState.unlock_run_power(id) and blueprints_ok
	_check(blueprints_ok and GameState.get_unlocked_run_powers().size() == 27,
		"all Blueprint powers enter the test profile through public unlock authority")
	_check(SaveSystem.clear_attempt_and_save(),
		"the fully unlocked isolated profile is durable before production boot")
	return true


func _test_catalogue_rank_one_contract() -> void:
	var table := SurvivorsContent.run_powers()
	var all_ok := table != null and table.powers.size() == 27 \
		and _RANK_ONE_EFFECTS.size() == 27 \
		and table.powers.size() <= RunPowerTable.MAX_POWER_COUNT
	var icon_paths: Dictionary = {}
	if table != null:
		for raw_id: Variant in _RANK_ONE_EFFECTS:
			var id := StringName(raw_id)
			var definition := table.by_id(id)
			all_ok = all_ok and definition != null
			if definition == null:
				continue
			var expected: Dictionary = _RANK_ONE_EFFECTS[raw_id]
			all_ok = all_ok and definition.effects.size() == expected.size() \
				and definition.icon_path.begins_with("res://assets/ui/powers/") \
				and not icon_paths.has(definition.icon_path) \
				and load(definition.icon_path) is Texture2D \
				and load(definition.vfx_path) is Shader
			icon_paths[definition.icon_path] = true
			for raw_kind: Variant in expected:
				var kind := int(raw_kind) as ProgressionEffectDef.Kind
				all_ok = all_ok and is_equal_approx(
					definition.effect_value(kind, 1), float(expected[raw_kind]))
	_check(all_ok and icon_paths.size() == 27,
		"all 27 powers expose exact rank-one values and distinct loadable vector icons below the 32-power cap")


func _boot_production_main() -> void:
	_main = load("res://scenes/main.tscn").instantiate() as AxemanMain
	add_child(_main)
	for _frame: int in range(6):
		await get_tree().process_frame
	_main.get_node("StartupOverlay").hide()
	_main.call("_enter_world")
	_hud = _main.get_node("UI_Overlay/YardHUD") as YardHUD
	_hud.show()
	_run = _main.get_node("RunDirector") as RunDirector
	_game = _main.get_node(
		"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	_arena = _game.get_node("LooseLogArena") as LooseLogArena
	_game.set("orbs_enabled", false)
	_check(_run != null and _game != null and _arena != null and _hud != null,
		"the probes use production Main, RunDirector, HUD, chopping, and loose-log arena")


func _test_uniform_power_identity_selection() -> void:
	var table := SurvivorsContent.run_powers()
	var ids: Array[StringName] = []
	if table != null:
		for definition: RunPowerDef in table.powers:
			if definition != null:
				ids.append(definition.id)
	ids.sort()
	var counts: Dictionary = {}
	var rng := _run.get("_rng") as RandomNumberGenerator
	if rng != null:
		rng.seed = 64271
	for _sample_index: int in range(ids.size() * 1000):
		var sample: Array = _run.call("_uniform_power_sample", ids, 1)
		if sample.size() != 1:
			continue
		var id := StringName(sample[0])
		counts[id] = int(counts.get(id, 0)) + 1
	var minimum := 1000000
	var maximum := 0
	for id: StringName in ids:
		minimum = mini(minimum, int(counts.get(id, 0)))
		maximum = maxi(maximum, int(counts.get(id, 0)))
	_check(ids.size() == 27 and counts.size() == ids.size() \
		and minimum >= 850 and maximum <= 1150,
		"every eligible power identity uses the same uniform offer sampler; only upgrade quality is weighted [min=%d max=%d]" % [minimum, maximum])


func _test_legitimate_rank_up() -> void:
	var target := &"deep_bite"
	var found := false
	for seed: int in range(61001, 61301):
		_run.start_attempt(seed)
		await _wait_frames(2)
		var baseline_chance := float(_game.call("debug_split_chance"))
		_run.debug_force_next_offer_quality(RunOfferTuning.Quality.COMMON)
		_open_next_offer()
		await _wait_frames(2)
		if target not in _offer_ids(_run.get_current_offer()):
			_run.abandon_attempt()
			await _wait_frames(1)
			continue
		if not _run.choose_run_offer(target):
			continue
		await _wait_frames(2)
		var rank_one_chance := float(_game.call("debug_split_chance"))
		var rank_one_visible := _power_slot_has_text("Deep Bite", "R1")
		_run.debug_force_next_offer_quality(RunOfferTuning.Quality.COMMON)
		_open_next_offer()
		await _wait_frames(2)
		if target not in _offer_ids(_run.get_current_offer()):
			_run.abandon_attempt()
			await _wait_frames(1)
			continue
		if not _run.choose_run_offer(target):
			continue
		await _wait_frames(2)
		found = _run.get_power_slots() == [target] \
			and _run.get_run_power_rank(target) == 2 \
			and is_equal_approx(_run.get_effect(
				ProgressionEffectDef.Kind.SPLIT_RELIABILITY), 0.08) \
			and rank_one_chance > baseline_chance + 0.039 \
			and rank_one_visible and _power_slot_has_text("Deep Bite", "R2")
		break
	_check(found,
		"a public offer applies Deep Bite rank one immediately, then advances the same slot to rank two")
	await _test_offer_quality_contract()


func _test_offer_quality_contract() -> void:
	var tuning := SurvivorsContent.run_offer_tuning()
	var qualities: Array[RunOfferTuning.Quality] = [
		RunOfferTuning.Quality.COMMON,
		RunOfferTuning.Quality.RARE,
		RunOfferTuning.Quality.EPIC,
		RunOfferTuning.Quality.LEGENDARY,
	]
	var weights: Array[float] = []
	var multipliers: Array[float] = []
	if tuning != null:
		for quality: RunOfferTuning.Quality in qualities:
			weights.append(tuning.quality_weight_for(quality))
			multipliers.append(tuning.quality_multiplier_for(quality))
	_check(tuning != null and tuning.tuning_status.begins_with("PLACEHOLDER") \
		and weights.size() == 4 and multipliers.size() == 4 \
		and weights[3] > 0.0 and weights[3] < weights[2] \
		and weights[2] < weights[1] and weights[1] < weights[0] \
		and _float_arrays_equal(multipliers, [1.0, 2.0, 3.0, 4.0]),
		"placeholder offer tuning makes positive Legendary quality the rarest tier and uses distinct whole-step 1x/2x/3x/4x value")

	# Exercise the same unforced weighted roll used by production cards. Five
	# thousand deterministic draws make the very rare Legendary tier observable
	# without turning the acceptance contract into a probabilistic test.
	_run.start_attempt(61501)
	var natural_counts: Dictionary = {}
	for _draw: int in range(5000):
		var quality := int(_run.call("_roll_offer_quality"))
		natural_counts[quality] = int(natural_counts.get(quality, 0)) + 1
	var natural_ok := true
	for quality: RunOfferTuning.Quality in qualities:
		natural_ok = natural_ok and int(natural_counts.get(quality, 0)) > 0
	natural_ok = natural_ok \
		and int(natural_counts.get(RunOfferTuning.Quality.COMMON, 0)) \
			> int(natural_counts.get(RunOfferTuning.Quality.RARE, 0)) \
		and int(natural_counts.get(RunOfferTuning.Quality.RARE, 0)) \
			> int(natural_counts.get(RunOfferTuning.Quality.EPIC, 0)) \
		and int(natural_counts.get(RunOfferTuning.Quality.EPIC, 0)) \
			> int(natural_counts.get(RunOfferTuning.Quality.LEGENDARY, 0))
	_check(natural_ok,
		"the unforced production quality roll naturally emits Common, Rare, Epic, and Legendary cards")

	var results: Dictionary = {}
	var every_selection_ok := true
	for index: int in range(qualities.size()):
		var quality := qualities[index]
		var result: Dictionary = await _forced_quality_rank_two(
			quality, 61600 + index)
		results[int(quality)] = result
		every_selection_ok = every_selection_ok and bool(result.get("ok", false))
	_check(every_selection_ok,
		"every quality is generated and visibly presented by a real offer, then public selection advances exactly R1 to R2")

	var common_effect := float((results.get(
		RunOfferTuning.Quality.COMMON, {}) as Dictionary).get("effect", 0.0))
	var rare_effect := float((results.get(
		RunOfferTuning.Quality.RARE, {}) as Dictionary).get("effect", 0.0))
	var epic_effect := float((results.get(
		RunOfferTuning.Quality.EPIC, {}) as Dictionary).get("effect", 0.0))
	var legendary_effect := float((results.get(
		RunOfferTuning.Quality.LEGENDARY, {}) as Dictionary).get("effect", 0.0))
	_check(common_effect < rare_effect and rare_effect < epic_effect \
		and epic_effect < legendary_effect,
		"the same Deep Bite R2 pick is stronger at Rare, Epic, and Legendary quality than Common")

	var legendary_result: Dictionary = results.get(
		RunOfferTuning.Quality.LEGENDARY, {})
	var legendary_picks: Array[float] = _float_array(
		legendary_result.get("pick_multipliers", []))
	var snapshot := _run.suspend_attempt()
	var restored := _run.restore_attempt(snapshot)
	var restored_all: Dictionary = _run.get_run_power_pick_multipliers()
	var restored_picks := _float_array(restored_all.get("deep_bite", []))
	_check(restored and _float_arrays_equal(legendary_picks, restored_picks),
		"quality pick multipliers survive suspension and restore without changing rank or value")

	var double_values: Array[float] = []
	var rescue_values: Array[float] = []
	for index: int in range(qualities.size()):
		double_values.append(await _forced_quality_rank_one_effect(
			&"double_chop", ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS,
			qualities[index], 61620 + index * 200))
		rescue_values.append(await _forced_quality_rank_one_effect(
			&"last_ditch_rescue", ProgressionEffectDef.Kind.RESCUE_CHARGES,
			qualities[index], 62420 + index * 200))
	_check(_float_arrays_equal(double_values, [1.0, 2.0, 3.0, 4.0]) \
		and _float_arrays_equal(rescue_values, [1.0, 2.0, 3.0, 4.0]),
		"discrete Double Chop cuts and Last-Ditch charges remain strictly distinct at Common, Rare, Epic, and Legendary R1 [double=%s rescue=%s]" % [
			double_values, rescue_values])


func _forced_quality_rank_two(quality: RunOfferTuning.Quality,
		seed: int) -> Dictionary:
	const TARGET := &"deep_bite"
	const FILLERS: Array[StringName] = [
		&"quick_hands", &"double_chop", &"yard_magnet",
		&"quick_study", &"keen_appraisal",
	]
	_run.start_attempt(seed)
	await _wait_frames(1)
	if not _run.debug_set_run_power_rank(TARGET, 1):
		return {}
	for filler: StringName in FILLERS:
		var definition := SurvivorsContent.run_powers().by_id(filler)
		if definition == null \
				or not _run.debug_set_run_power_rank(filler, definition.rank_cap):
			return {}
	if not _run.debug_force_next_offer_quality(quality):
		return {}
	var award := _run.get_xp_to_next_level_for_xp(0)
	_run.award_xp(award)
	if not _run.present_level_choice(2):
		return {}
	await _wait_frames(1)
	var offer := _run.get_current_offer()
	var card := _offer_card(offer, TARGET)
	var tuning := SurvivorsContent.run_offer_tuning()
	var definition := SurvivorsContent.run_powers().by_id(TARGET)
	if card.is_empty() or tuning == null or definition == null:
		return {}
	var quality_multiplier := tuning.quality_multiplier_for(quality)
	var common_multiplier := tuning.quality_multiplier_for(
		RunOfferTuning.Quality.COMMON)
	var expected_picks: Array[float] = [common_multiplier, quality_multiplier]
	var card_ok := int(card.get("quality", RunOfferTuning.Quality.INVALID)) \
			== int(quality) \
		and String(card.get("quality_name", "")) \
			== String(RunOfferTuning.Quality.keys()[int(quality)]).capitalize() \
		and is_equal_approx(float(card.get("quality_multiplier", 0.0)),
			quality_multiplier) \
		and int(card.get("current_rank", -1)) == 1 \
		and int(card.get("next_rank", -1)) == 2 \
		and _float_arrays_equal(_float_array(card.get("pick_multipliers", [])),
			[common_multiplier]) \
		and _offer_only_changes_effects(offer) \
		and _offer_card_is_presented(offer, TARGET, card)
	var chosen := _run.choose_run_offer(TARGET)
	await _wait_frames(1)
	var all_picks: Dictionary = _run.get_run_power_pick_multipliers()
	var actual_picks := _float_array(all_picks.get(String(TARGET), []))
	var actual_effect := _run.get_effect(
		ProgressionEffectDef.Kind.SPLIT_RELIABILITY)
	var expected_effect := definition.effect_value_for_pick_multipliers(
		ProgressionEffectDef.Kind.SPLIT_RELIABILITY, expected_picks)
	return {
		"ok": card_ok and chosen and _run.get_run_power_rank(TARGET) == 2 \
			and _float_arrays_equal(actual_picks, expected_picks) \
			and is_equal_approx(actual_effect, expected_effect) \
			and _power_slot_has_text("Deep Bite", "R2"),
		"effect": actual_effect,
		"pick_multipliers": actual_picks,
	}


func _forced_quality_rank_one_effect(power_id: StringName,
		kind: ProgressionEffectDef.Kind, quality: RunOfferTuning.Quality,
		seed_start: int) -> float:
	_run.start_attempt(seed_start)
	await _wait_frames(1)
	# Isolate the requested card through the same disposable ban dictionary used
	# by production offers. This preserves real generation/UI/selection and exact
	# quality validation without making an Epic target depend on eventually
	# appearing in an arbitrary finite seed search.
	var banned: Dictionary = {}
	for unlocked_id: StringName in GameState.get_unlocked_run_powers():
		if unlocked_id != power_id:
			banned[unlocked_id] = true
	_run.set("_banned_power_ids", banned)
	var offer := await _open_forced_quality_offer(quality)
	var card := _offer_card(offer, power_id)
	if card.is_empty() \
			or int(card.get("quality", RunOfferTuning.Quality.INVALID)) != int(quality) \
			or not _offer_only_changes_effects(offer) \
			or not _run.choose_run_offer(power_id):
		return -1.0
	return _run.get_effect(kind)


func _test_quality_offer_headroom() -> void:
	const FILLERS: Array[StringName] = [
		&"quick_hands", &"double_chop", &"yard_magnet",
		&"scar_wisdom", &"keen_appraisal",
	]
	# A Rare second Last-Ditch pick reaches the Common ladder's three-charge
	# endpoint at R2. Quality value must persist: the nominal R3 card still has to
	# add a real charge instead of becoming a clamped no-op.
	_run.start_attempt(61801)
	await _wait_frames(1)
	var rescue_setup := _run.debug_set_run_power_rank(&"last_ditch_rescue", 1)
	for filler: StringName in FILLERS:
		var definition := SurvivorsContent.run_powers().by_id(filler)
		rescue_setup = definition != null and _run.debug_set_run_power_rank(
			filler, definition.rank_cap) and rescue_setup
	var rescue_pick := await _take_forced_quality_pick(
		&"last_ditch_rescue", RunOfferTuning.Quality.RARE)
	var rescue_effect := _run.get_effect(
		ProgressionEffectDef.Kind.RESCUE_CHARGES)
	var rescue_headroom := bool(_run.call(
		"_run_power_has_effect_headroom", &"last_ditch_rescue"))
	var rescue_next_offer := await _open_forced_quality_offer(
		RunOfferTuning.Quality.COMMON)
	var rescue_next_effectful := _offer_only_changes_effects(rescue_next_offer)
	var rescue_next_selected := _run.choose_run_offer(&"last_ditch_rescue")
	_check(rescue_setup and rescue_pick and is_equal_approx(rescue_effect, 3.0) \
		and rescue_headroom \
		and &"last_ditch_rescue" in _offer_ids(rescue_next_offer) \
		and rescue_next_effectful and rescue_next_selected \
		and _run.get_run_power_rank(&"last_ditch_rescue") == 3 \
		and is_equal_approx(_run.get_effect(
			ProgressionEffectDef.Kind.RESCUE_CHARGES), 4.0),
		"quality value persists past the Common endpoint and every nominal rank still changes gameplay")

	# Flying Wedge's one-log payload is intentionally fixed; this quality history
	# proves its separate interval ladder still gives every offered rank a real
	# gameplay improvement without multiplying one wedge into multiple removals.
	_run.start_attempt(61802)
	await _wait_frames(1)
	var wedge_setup := _run.debug_set_run_power_rank(&"flying_wedge", 1)
	for filler: StringName in FILLERS:
		var definition := SurvivorsContent.run_powers().by_id(filler)
		wedge_setup = definition != null and _run.debug_set_run_power_rank(
			filler, definition.rank_cap) and wedge_setup
	for quality: RunOfferTuning.Quality in [
			RunOfferTuning.Quality.RARE,
			RunOfferTuning.Quality.RARE,
			RunOfferTuning.Quality.COMMON,
			RunOfferTuning.Quality.RARE,
		]:
		wedge_setup = await _take_forced_quality_pick(
			&"flying_wedge", quality) and wedge_setup
	var wedge_next_offer := await _open_forced_quality_offer(
		RunOfferTuning.Quality.RARE)
	_check(wedge_setup and _run.get_run_power_rank(&"flying_wedge") == 5 \
		and &"flying_wedge" in _offer_ids(wedge_next_offer) \
		and _offer_only_changes_effects(wedge_next_offer) \
		and _run.choose_run_offer(&"flying_wedge") \
		and _run.get_run_power_rank(&"flying_wedge") == 6 \
		and is_equal_approx(_run.get_effect(
			ProgressionEffectDef.Kind.FLYING_WEDGE_CUT_COUNT), 1.0),
		"every visible offer's exact rolled quality changes at least one gameplay effect")

	# Five Legendary Quick Hands picks reach the production recovery ceiling at
	# nominal R5. R6-R8 still exist in authored data, but once every exact quality
	# is clamped to the same 0.8 consumer value they must leave the eligible pool
	# instead of printing a gameplay-no-op card.
	var quick_first := await _forced_quality_rank_one_effect(
		&"quick_hands", ProgressionEffectDef.Kind.SWING_RECOVERY,
		RunOfferTuning.Quality.LEGENDARY, 61901)
	var quick_setup := is_equal_approx(quick_first, 0.16)
	for filler: StringName in [
		&"deep_bite", &"double_chop", &"yard_magnet", &"scar_wisdom",
		&"keen_appraisal",
	]:
		var definition := SurvivorsContent.run_powers().by_id(filler)
		quick_setup = definition != null and _run.debug_set_run_power_rank(
			filler, definition.rank_cap) and quick_setup
	for _pick: int in range(4):
		quick_setup = await _take_forced_quality_pick(
			&"quick_hands", RunOfferTuning.Quality.LEGENDARY) and quick_setup
	var quick_definition := SurvivorsContent.run_powers().by_id(&"quick_hands")
	var quick_picks := _float_array(_run.get_run_power_pick_multipliers().get(
		"quick_hands", []))
	var quick_effect := _run.get_effect(
		ProgressionEffectDef.Kind.SWING_RECOVERY)
	var quick_headroom := bool(_run.call(
		"_run_power_has_effect_headroom", &"quick_hands"))
	var quick_quality_changes := false
	for raw_quality: int in range(RunOfferTuning.Quality.COMMON,
			RunOfferTuning.Quality.LEGENDARY + 1):
		quick_quality_changes = bool(_run.call(
			"_quality_would_change_power", &"quick_hands",
			raw_quality as RunOfferTuning.Quality)) \
			or quick_quality_changes
	var quick_next_offer := await _open_forced_quality_offer(
		RunOfferTuning.Quality.LEGENDARY)
	_check(quick_setup and quick_definition != null \
		and _run.get_run_power_rank(&"quick_hands") == 5 \
		and _run.get_run_power_rank(&"quick_hands") < quick_definition.rank_cap \
		and _float_arrays_equal(quick_picks, [4.0, 4.0, 4.0, 4.0, 4.0]) \
		and is_equal_approx(quick_effect, 0.8) \
		and not quick_headroom and not quick_quality_changes \
		and &"quick_hands" not in _offer_ids(quick_next_offer) \
		and _offer_ids(quick_next_offer) == [RunDirector.PAYDAY_POWER_ID],
		"Quick Hands leaves the offer pool before its high-quality recovery ceiling can create a nominal no-op rank")


func _take_forced_quality_pick(power_id: StringName,
		quality: RunOfferTuning.Quality) -> bool:
	var offer := await _open_forced_quality_offer(quality)
	var card := _offer_card(offer, power_id)
	if card.is_empty() or not _offer_only_changes_effects(offer):
		return false
	var before_rank := _run.get_run_power_rank(power_id)
	return _run.choose_run_offer(power_id) \
		and _run.get_run_power_rank(power_id) == before_rank + 1


func _open_forced_quality_offer(quality: RunOfferTuning.Quality) -> Dictionary:
	if not _run.debug_force_next_offer_quality(quality):
		return {}
	var award := _run.get_xp_to_next_level_for_xp(_run.get_xp())
	_run.award_xp(award)
	var level := _run.get_level()
	if not _run.present_level_choice(level):
		return {}
	await _wait_frames(1)
	return _run.get_current_offer()


func _test_rank_one_effect_composition() -> void:
	var all_ok := _run.has_method("debug_set_run_power_rank")
	for raw_id: Variant in _RANK_ONE_EFFECTS:
		var id := StringName(raw_id)
		await _fresh_power(id, 1, 62000 + _passed + _failed)
		var power_ok := _run.get_power_slots() == [id] \
			and _run.get_run_power_rank(id) == 1 \
			and _first_power_slot_is_presented(id, 1)
		var expected: Dictionary = _RANK_ONE_EFFECTS[raw_id]
		for raw_kind: Variant in expected:
			power_ok = power_ok and is_equal_approx(_run.get_effect(
				int(raw_kind) as ProgressionEffectDef.Kind), float(expected[raw_kind]))
		all_ok = all_ok and power_ok
	_check(all_ok,
		"every named power composes its exact rank-one values into a fresh live run")


## Filled out against the production debug seams supplied by RunDirector and
## ChoppingMinigame. Each section asserts a physical/economic result in addition
## to the shared trigger counters.
func _test_direct_cut_powers() -> void:
	# Quick Hands changes the real swing recovery consumer, not merely the
	# composed effect dictionary.
	_run.start_attempt(63001)
	await _wait_frames(2)
	var base_cooldown := float(_game.call("current_swing_cooldown"))
	_run.call("debug_set_run_power_rank", &"quick_hands", 1)
	var quick_cooldown := float(_game.call("current_swing_cooldown"))
	_check(quick_cooldown < base_cooldown \
		and is_equal_approx(quick_cooldown, maxf(float(_game.get(
			"min_swing_cooldown")), base_cooldown * 0.96)),
		"Quick Hands rank one shortens the production swing cooldown by 4%")

	# Scar Wisdom must add its own rank-one reliability on top of the ordinary
	# visible scar pity left by a failed bite.
	await _fresh_power(&"scar_wisdom", 1, 63002)
	var before_scar_chance := float(_game.call("debug_split_chance"))
	_game.set("debug_split_roll", 0)
	var scar_split := bool(_game.call("debug_swing_world", _centre_cut_plane()))
	var after_scar_chance := float(_game.call("debug_split_chance"))
	_check(not scar_split and int(_game.call("debug_scar_count")) == 1 \
		and int(_game.call("debug_total_scar_projection_count")) == 1 \
		and after_scar_chance > before_scar_chance + 0.049,
		"Scar Wisdom rank one turns a failed bite into a visible scar with extra reliability")

	# Double Chop resolves the root swing and its guaranteed continuation through
	# the same real MeshSlicer path.
	await _fresh_power(&"double_chop", 1, 63003)
	_game.set("debug_split_roll", 1)
	var double_before := int(_game.call("piece_count"))
	var double_split := bool(_game.call("debug_swing_world", _centre_cut_plane()))
	var double_after := int(_game.call("piece_count"))
	_check(double_split and int(_game.call(
		"debug_last_run_power_cuts", &"double_chop")) == 1 \
		and double_after >= double_before + 2 \
		and _trigger_count(&"double_chop") == 1 \
		and _has_power_burst(&"double_chop"),
		"Double Chop rank one adds one guaranteed real descendant cut")

	# A high-quality first pick can grant more cuts than the current block can
	# geometrically accept. Every unused unit now destroys one ordered loose log.
	var spill_selected := false
	for seed: int in range(68151, 68251):
		_run.start_attempt(seed)
		await _wait_frames(1)
		var spill_offer := await _open_forced_quality_offer(
			RunOfferTuning.Quality.LEGENDARY)
		var spill_card := _offer_card(spill_offer, &"double_chop")
		if spill_card.is_empty():
			continue
		spill_selected = int(spill_card.get("current_rank", -1)) == 0 \
			and int(spill_card.get("next_rank", -1)) == 1 \
			and int(spill_card.get("quality", RunOfferTuning.Quality.INVALID)) \
				== RunOfferTuning.Quality.LEGENDARY \
			and _offer_only_changes_effects(spill_offer) \
			and _run.choose_run_offer(&"double_chop")
		if spill_selected:
			break
	await _wait_frames(1)
	var spill_safe := _spawn_loose_body()
	var spill_endangered := _spawn_loose_body()
	if spill_safe != null:
		spill_safe.boundary_exposure = 0.25
	if spill_endangered != null:
		spill_endangered.boundary_exposure = 3.0
	var spill_safe_id := _body_id(spill_safe)
	var spill_endangered_id := _body_id(spill_endangered)
	var block_pieces: Variant = _game.get("_on_block")
	var block_meshes: Array[Mesh] = []
	if block_pieces is Array:
		for raw_piece: Variant in block_pieces:
			var piece := raw_piece as Area3D
			block_meshes.append(piece.get_meta("mesh_ref") as Mesh)
			# Keep the metadata key valid while supplying geometry that cannot split;
			# `null` removes Godot metadata and makes the production target picker log
			# an unrelated missing-meta error.
			piece.set_meta("mesh_ref", ArrayMesh.new())
	var immediate_spill_cuts := int(_game.call("_attempt_run_double_chop"))
	if block_pieces is Array:
		for index: int in range((block_pieces as Array).size()):
			((block_pieces as Array)[index] as Area3D).set_meta(
				"mesh_ref", block_meshes[index])
	var spill_count := maxi(0, int(round(_run.get_effect(
		ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS))))
	_check(spill_selected and _run.get_run_power_rank(&"double_chop") == 1 \
		and spill_count > 1 and immediate_spill_cuts == 0 \
		and _arena_body_state(spill_endangered_id).is_empty() \
		and _arena_body_state(spill_safe_id).is_empty() \
		and _trigger_count(&"double_chop") == 1 \
		and _has_power_burst(&"double_chop"),
		"Legendary Double Chop rank one turns unused block cuts into immediate ordered loose-log destruction")

	# Follow-Up uses its production repeat-swing branch; the forced roll removes
	# chance from the test while retaining the rank-one depth of one.
	await _fresh_power(&"follow_up", 1, 63004)
	_game.set("debug_split_roll", 1)
	_game.set("debug_force_proc", 1)
	var follow_before := int(_game.call("piece_count"))
	var follow_split := bool(_game.call("debug_swing_world", _centre_cut_plane()))
	var follow_after := int(_game.call("piece_count"))
	_check(follow_split and follow_after >= follow_before + 2 \
		and _trigger_count(&"follow_up") == 1 \
		and _has_power_burst(&"follow_up"),
		"Follow-Up rank one fires one repeat swing and produces another real cut")

	# Splinters leave the block and immediately destroy physical loose roots.
	await _fresh_power(&"splinter_volley", 1, 63005)
	_game.call("_clear_finished_firewood")
	var splinter_body := _spawn_loose_body()
	_game.set("debug_split_roll", 1)
	# Splinter Volley has no chance roll: even the shared forced-miss seam cannot
	# suppress a successful primary strike.
	_game.set("debug_force_proc", 0)
	var splinter_id := _body_id(splinter_body)
	var splinter_descriptor := splinter_body.descriptor \
		if splinter_body != null else null
	var splinter_cash_before := _run.get_cash()
	var splinter_xp_before := _run.get_xp()
	var root_split := bool(_game.call("debug_swing_world", _centre_cut_plane()))
	var splinter_state := _arena_body_state(splinter_id)
	var splinter_parts := int(_game.debug_finished_piece_state().get("count", 0))
	_check(root_split and splinter_state.is_empty() \
		and splinter_descriptor != null \
		and splinter_parts >= 2 and splinter_parts <= 6 \
		and _run.get_cash() == splinter_cash_before \
			+ splinter_descriptor.cash_reward_snapshot \
		and _run.get_xp() == splinter_xp_before \
			+ splinter_descriptor.xp_reward_snapshot \
		and _trigger_count(&"splinter_volley") == 1,
		"every successful strike makes Rank 1 Splinter Volley immediately destroy, reward, and randomly fragment its nearest loose log [split=%s state=%s descriptor=%s parts=%d cash=%d→%d/%d xp=%d→%d/%d triggers=%d]" % [
			root_split, splinter_state, splinter_descriptor != null,
			splinter_parts, splinter_cash_before, _run.get_cash(),
			splinter_descriptor.cash_reward_snapshot \
				if splinter_descriptor != null else -1,
			splinter_xp_before, _run.get_xp(),
			splinter_descriptor.xp_reward_snapshot \
				if splinter_descriptor != null else -1,
			_trigger_count(&"splinter_volley")])


func _test_physics_and_boundary_powers() -> void:
	# Soft Landing snapshots all three rank-one arrival multipliers onto a future
	# body. Reusing the same run seed gives the baseline and powered delivery the
	# same authored spawn roll.
	_run.start_attempt(64001)
	await _wait_frames(1)
	var baseline_body := _spawn_loose_body()
	var baseline_spawned := baseline_body != null
	var baseline_velocity: Vector3 = baseline_body.linear_velocity \
		if baseline_body != null else Vector3.ZERO
	var baseline_position: Vector3 = baseline_body.global_position \
		if baseline_body != null else Vector3.ZERO
	await _fresh_power(&"soft_landing", 1, 64001)
	var soft_body := _spawn_loose_body()
	var soft_velocity: Vector3 = soft_body.linear_velocity \
		if soft_body != null else Vector3.ZERO
	var soft_position: Vector3 = soft_body.global_position \
		if soft_body != null else Vector3.ZERO
	var baseline_outward := _outward_speed(baseline_position, baseline_velocity)
	var soft_outward := _outward_speed(soft_position, soft_velocity)
	var soft_state := _arena_body_state(_body_id(soft_body))
	_check(soft_body != null and baseline_spawned \
		and _horizontal_speed(soft_velocity) <= _horizontal_speed(baseline_velocity) * 0.921 \
		and (baseline_outward <= _EPSILON \
			or soft_outward <= baseline_outward * 0.847) \
		and is_equal_approx(float(soft_state.get(
			"arrival_bounce_multiplier", 0.0)), 0.90),
		"Soft Landing rank one reduces future lateral, outward, and bounce motion")

	await _fresh_power(&"yard_magnet", 1, 64002)
	var initial_magnet_state := _runtime_state()
	var initial_pulse_left := float(initial_magnet_state.get(
		"yard_magnet_pulse_seconds_left", 0.0))
	_advance_power_time(initial_pulse_left + 0.001)
	var between_pulses := _runtime_state()
	var next_pulse_left := float(between_pulses.get(
		"yard_magnet_cycle_seconds_left", 0.0))
	_advance_power_time(maxf(0.0, next_pulse_left - 0.01))
	var just_before_pulse := _runtime_state()
	_advance_power_time(0.011)
	var next_pulse := _runtime_state()
	var magnet_definition := SurvivorsContent.run_powers().by_id(&"yard_magnet")
	_check(initial_pulse_left > 0.0 and initial_pulse_left <= 0.5 \
		and is_equal_approx(float(initial_magnet_state.get(
			"yard_magnet_interval", 0.0)), 5.0) \
		and not bool(between_pulses.get("yard_magnet_active", true)) \
		and not bool(just_before_pulse.get("yard_magnet_active", true)) \
		and bool(next_pulse.get("yard_magnet_active", false)) \
		and float(next_pulse.get("yard_magnet_pulse_seconds_left", 0.0)) > 0.48 \
		and magnet_definition != null \
		and is_equal_approx(magnet_definition.effect_value(
			ProgressionEffectDef.Kind.YARD_MAGNET_PULSE_INTERVAL, 8), 1.5),
		"Yard Magnet pulses for 0.5 seconds every 5 seconds at Rank 1 and its provisional interval works down to 1.5 seconds")
	var original_game_position: Vector3 = _game.global_position
	_game.global_position += Vector3(4.0, 0.0, -3.0)
	var magnet_target: Vector3 = _arena.call(
		"yard_magnet_target_world_position")
	var magnet_body := _spawn_loose_body()
	if magnet_body != null:
		magnet_body.global_position = magnet_target + Vector3(2.0, 2.0, 0.0)
		magnet_body.linear_velocity = Vector3.ZERO
	_advance_power_time(1.0)
	_arena.call("_advance_yard_magnet_drag", 0.1, 1.0)
	var airborne_velocity := magnet_body.linear_velocity \
		if magnet_body != null else Vector3.INF
	var floor := _game.get_node_or_null("Floor") as StaticBody3D
	if magnet_body != null and floor != null:
		magnet_body.body_entered.emit(floor)
		magnet_body.linear_velocity = Vector3(2.0, 0.8, 3.0)
		magnet_body.angular_velocity = Vector3(1.0, 2.0, 3.0)
	_advance_power_time(1.0)
	_arena.call("_advance_yard_magnet_drag", 0.1, 1.0)
	var grounded_velocity := magnet_body.linear_velocity \
		if magnet_body != null else Vector3.INF
	var grounded_angular := magnet_body.angular_velocity \
		if magnet_body != null else Vector3.INF
	var grounded_bounce := magnet_body.physics_material_override.bounce \
		if magnet_body != null \
			and magnet_body.physics_material_override != null else INF
	var grounded_friction := magnet_body.physics_material_override.friction \
		if magnet_body != null \
			and magnet_body.physics_material_override != null else INF
	var grounded_locks := magnet_body != null \
		and magnet_body.axis_lock_angular_x \
		and magnet_body.axis_lock_angular_y \
		and magnet_body.axis_lock_angular_z
	var grounded_drag_speed := magnet_body.magnet_drag_speed \
		if magnet_body != null else -1.0
	var magnet_dock: Vector3 = _arena.call(
		"yard_magnet_dock_world_position", magnet_body) \
		if magnet_body != null else Vector3.ZERO
	var to_block := magnet_dock - magnet_body.global_position \
		if magnet_body != null else Vector3.ZERO
	to_block.y = 0.0
	var planar_grounded := Vector3(grounded_velocity.x, 0.0,
		grounded_velocity.z)
	if magnet_body != null:
		# Simulate a contact solver consuming the commanded planar velocity and
		# injecting spin. The controller-owned ramp must restore full smooth pull
		# on the very next update instead of accelerating again from zero.
		magnet_body.linear_velocity = Vector3.ZERO
		magnet_body.angular_velocity = Vector3(3.0, 8.0, -4.0)
	_advance_power_time(0.1)
	_arena.call("_advance_yard_magnet_drag", 0.1, 0.1)
	var recovered_velocity := magnet_body.linear_velocity \
		if magnet_body != null else Vector3.INF
	var recovered_angular := magnet_body.angular_velocity \
		if magnet_body != null else Vector3.INF
	if magnet_body != null:
		magnet_body.global_position = magnet_dock + Vector3(0.05, 2.0, 0.0)
		magnet_body.linear_velocity = Vector3(5.0, 0.0, 2.0)
	_advance_power_time(1.0)
	_arena.call("_advance_yard_magnet_drag", 0.1, 1.0)
	var near_target_velocity := magnet_body.linear_velocity \
		if magnet_body != null else Vector3.INF
	if magnet_body != null and floor != null:
		magnet_body.body_exited.emit(floor)
	_advance_power_time(1.0)
	var after_exit_velocity := magnet_body.linear_velocity \
		if magnet_body != null else Vector3.INF
	var released_material := magnet_body.physics_material_override \
		if magnet_body != null else null
	var released_controller := magnet_body != null \
		and not magnet_body.magnet_engaged \
		and is_zero_approx(magnet_body.magnet_drag_speed) \
		and not magnet_body.axis_lock_angular_x \
		and not magnet_body.axis_lock_angular_y \
		and not magnet_body.axis_lock_angular_z \
		and released_material != null \
		and is_equal_approx(released_material.friction, 0.8) \
		and is_equal_approx(released_material.bounce, 0.05)
	_game.global_position = original_game_position
	# Real physics trajectory: place the whole root upright just above the floor,
	# let the production physics-cadence servo move it for consecutive ticks, and
	# measure the rendered body's actual pose rather than only its commanded speed.
	var physical_glide_ok := false
	var physical_progress := 0.0
	var physical_vertical_range := INF
	var physical_max_spin := INF
	var physical_lost_ground_frames := 999
	var dock_clearance_ok := false
	if magnet_body != null and floor != null:
		var physical_target: Vector3 = _arena.call(
			"yard_magnet_target_world_position")
		var visual := magnet_body.get_node_or_null("Mesh") as MeshInstance3D
		var half_height := 0.45
		if visual != null and visual.mesh != null:
			half_height = maxf(0.05, -visual.mesh.get_aabb().position.y)
		magnet_body.quaternion = Quaternion.IDENTITY
		magnet_body.global_position = physical_target \
			+ Vector3(1.5, half_height + 0.005, 0.0)
		magnet_body.linear_velocity = Vector3.ZERO
		magnet_body.angular_velocity = Vector3.ZERO
		magnet_body.body_entered.emit(floor)
		_run.set("_yard_magnet_cycle_seconds_left", float(
			initial_magnet_state.get("yard_magnet_interval", 5.0)))
		_run.set("_yard_magnet_pulse_seconds_left",
			_run.tuning.yard_magnet_pulse_duration_seconds)
		_run.call("_sync_yard_magnet_force", 0.1, 1.0 / 60.0)
		var physical_dock: Vector3 = _arena.call(
			"yard_magnet_dock_world_position", magnet_body)
		magnet_body.global_position.x = physical_dock.x + 0.4
		var start_distance := Vector2(magnet_body.global_position.x \
			- physical_dock.x, magnet_body.global_position.z \
			- physical_dock.z).length()
		var min_y := magnet_body.global_position.y
		var max_y := min_y
		var max_spin := 0.0
		var lost_ground_frames := 0
		var prior_distance := start_distance
		var monotonic := true
		for _physics_frame: int in range(28):
			await get_tree().physics_frame
			var current_distance := Vector2(magnet_body.global_position.x \
				- physical_dock.x, magnet_body.global_position.z \
				- physical_dock.z).length()
			monotonic = monotonic and current_distance <= prior_distance + 0.002
			prior_distance = current_distance
			min_y = minf(min_y, magnet_body.global_position.y)
			max_y = maxf(max_y, magnet_body.global_position.y)
			max_spin = maxf(max_spin, magnet_body.angular_velocity.length())
			if not magnet_body.grounded:
				lost_ground_frames += 1
		physical_progress = start_distance - prior_distance
		physical_vertical_range = max_y - min_y
		physical_max_spin = max_spin
		physical_lost_ground_frames = lost_ground_frames
		var centre_distance := Vector2(magnet_body.global_position.x \
			- physical_target.x, magnet_body.global_position.z \
			- physical_target.z).length()
		dock_clearance_ok = centre_distance \
			>= magnet_body.magnet_dock_radius - 0.002
		physical_glide_ok = monotonic and physical_progress > 0.015 \
			and physical_vertical_range < 0.035 \
			and physical_max_spin < 0.001 \
			and physical_lost_ground_frames <= 1 and dock_clearance_ok
	_check(magnet_body != null and floor != null \
		and airborne_velocity.is_zero_approx() \
		and magnet_target.distance_to(Vector3.ZERO) > 1.0 \
		and planar_grounded.length() > 0.099 \
		and planar_grounded.length() < 0.101 \
		and planar_grounded.normalized().dot(to_block.normalized()) > 0.999 \
		and absf(grounded_velocity.y) <= _EPSILON \
		and absf(grounded_angular.x) <= _EPSILON \
		and absf(grounded_angular.y) <= _EPSILON \
		and absf(grounded_angular.z) <= _EPSILON \
		and grounded_locks \
		and is_equal_approx(grounded_drag_speed, 0.1) \
		and is_zero_approx(grounded_bounce) \
		and is_zero_approx(grounded_friction) \
		and _horizontal_speed(recovered_velocity) > 0.099 \
		and _horizontal_speed(recovered_velocity) < 0.101 \
		and recovered_angular.is_zero_approx() \
		and absf(near_target_velocity.x) <= 0.0501 \
		and absf(near_target_velocity.z) <= _EPSILON \
		and is_equal_approx(after_exit_velocity.x, near_target_velocity.x) \
		and is_equal_approx(after_exit_velocity.z, near_target_velocity.z) \
		and released_controller \
		and physical_glide_ok \
		and bool(magnet_body.get("landed")) \
		and bool(magnet_body.get("grounded")),
		"During its active pulse, Yard Magnet ignores airborne logs, follows a real monotonic frictionless and rotation-locked floor glide, recovers uniformly after contacts, eases to a reachable stump-rim dock, and releases cleanly after lift-off [progress=%.3f y_range=%.3f spin=%.4f lost_ground=%d clearance=%s]" % [
			physical_progress, physical_vertical_range, physical_max_spin,
			physical_lost_ground_frames, dock_clearance_ok])

	# Use that same real magnet-controlled rigid body for the production claim and
	# handoff. A synthetic descriptor can prove the curve while missing a lifecycle
	# regression caused by transferring a body with live magnet locks/materials.
	var handoff_source := magnet_body.global_position \
		if magnet_body != null else Vector3.INF
	var handoff_id := magnet_body.descriptor.id \
		if magnet_body != null and magnet_body.descriptor != null else &""
	var handoff_ready := [0]
	_game.connect(&"run_log_ready",
		func() -> void: handoff_ready[0] += 1, CONNECT_ONE_SHOT)
	# Enter through the production block-ready signal rather than manually
	# stitching arena claim and chopping stage together.
	_game.emit_signal(&"block_ready_for_log")
	var handoff_descriptor := _game.get("_current_descriptor") as LogDescriptor
	var claimed_source_hidden := magnet_body != null \
		and is_instance_valid(magnet_body) and not magnet_body.visible
	var handoff_roots: Array = _game.get("_on_block")
	var handoff_root := handoff_roots[0] as Node3D \
		if not handoff_roots.is_empty() else null
	var handoff_visual := _game.get("_run_handoff_visual") as Node3D
	var handoff_began_at_source := handoff_visual != null \
		and handoff_visual.global_position.is_equal_approx(handoff_source) \
		and handoff_root != null and not handoff_root.visible
	var handoff_timing: Vector2 = _game.call(
		"_vertical_handoff_timing", _run.tuning.block_hop_seconds)
	var handoff_lift_seconds := handoff_timing.x * handoff_timing.y
	var lift_probe_delay := maxf(0.01, handoff_lift_seconds * 0.5)
	await get_tree().create_timer(lift_probe_delay,
		true, false, true).timeout
	var handoff_mid := handoff_visual.global_position \
		if is_instance_valid(handoff_visual) else Vector3.INF
	# Main's 0.5-second quiet autosave lands just before this authored 0.548-second
	# handoff finishes. Serialization must not kill the tween, move it, emit ready,
	# or preserve the already-claimed id in arena authority.
	var autosave_quiet_seconds := float(_main.call("autosave_quiet_seconds"))
	await get_tree().create_timer(maxf(0.01,
		autosave_quiet_seconds - lift_probe_delay), true, false, true).timeout
	var handoff_before_autosave := handoff_visual.global_position \
		if is_instance_valid(handoff_visual) else Vector3.INF
	var boundary_before_autosave := bool(_run.get("_boundary_timers_paused"))
	var autosave_snapshot := _run.to_save_dict()
	var autosave_chopping: Variant = autosave_snapshot.get("chopping", {})
	var handoff_survived_autosave := is_instance_valid(handoff_visual) \
		and bool(_game.get("_run_handoff_active")) \
		and handoff_visual.global_position.is_equal_approx(handoff_before_autosave) \
		and int(handoff_ready[0]) == 0 \
		and StringName(autosave_snapshot.get("active_log_id", "")) == handoff_id \
		and bool(autosave_snapshot.get("boundary_timers_paused", false)) \
			== boundary_before_autosave \
		and bool(_run.get("_boundary_timers_paused")) \
			== boundary_before_autosave \
		and autosave_chopping is Dictionary \
		and bool((autosave_chopping as Dictionary).get(
			"handoff_active", false)) \
		and _arena_body_state(handoff_id).is_empty() \
		and not _arena_save_has_log_id(
			autosave_snapshot.get("arena", {}), handoff_id)
	var handoff_total_seconds := handoff_timing.x \
		+ _run.tuning.block_handoff_hidden_hold_seconds
	await get_tree().create_timer(maxf(0.01,
		handoff_total_seconds - autosave_quiet_seconds + 0.05),
		true, false, true).timeout
	for _handoff_frame: int in range(10):
		if int(handoff_ready[0]) > 0:
			break
		await get_tree().process_frame
	var handoff_end := handoff_root.global_position \
		if is_instance_valid(handoff_root) else Vector3.INF
	var handoff_target: Vector3 = _game.call(
		"yard_magnet_target_world_position")
	_check(handoff_descriptor != null and handoff_descriptor.has_transfer_pose() \
		and handoff_descriptor.has_transfer_visuals() and claimed_source_hidden \
		and handoff_descriptor.id == handoff_id \
		and StringName(_run.get("_active_log_id")) == handoff_id \
		and handoff_began_at_source and handoff_survived_autosave \
		and handoff_mid.y > handoff_source.y \
		and Vector2(handoff_mid.x, handoff_mid.z).is_equal_approx(
			Vector2(handoff_source.x, handoff_source.z)) \
		and Vector2(handoff_end.x, handoff_end.z).is_equal_approx(
			Vector2(handoff_target.x, handoff_target.z)) \
		and int(handoff_ready[0]) == 1,
		"a genuinely magnetised loose body keeps its source pose, survives the production autosave without a snap, repositions off-screen, and completes one block delivery")

	# Ring Reinforcement changes both the hazard authority and the rendered mesh.
	_run.start_attempt(64003)
	await _wait_frames(1)
	var base_ring_width := _boundary_mesh_width()
	var base_radius := float(_run.tuning.boundary_radius)
	var base_grace := float(_run.tuning.boundary_grace_seconds)
	_run.call("debug_set_run_power_rank", &"ring_reinforcement", 1)
	await _wait_frames(1)
	var ring_state := _runtime_state()
	var ring_arena: Dictionary = ring_state.get("arena", {})
	var ring_body := _spawn_loose_body()
	if ring_body != null:
		ring_body.freeze = true
		ring_body.global_position = Vector3(base_radius + 0.06, 0.4, 0.0)
		ring_body.boundary_exposure = 0.0
	_arena.advance_hazards(0.2)
	var inside_exposure := ring_body.boundary_exposure if ring_body != null else -1.0
	if ring_body != null:
		ring_body.global_position = Vector3(base_radius + 0.20, 0.4, 0.0)
	_arena.advance_hazards(base_grace + 0.20)
	_check(is_equal_approx(float(ring_arena.get("boundary_radius", 0.0)),
			base_radius + 0.12) \
		and is_equal_approx(float(ring_arena.get("boundary_grace", 0.0)),
			base_grace + 0.40) \
		and _boundary_mesh_width() > base_ring_width + 0.20 \
		and is_zero_approx(inside_exposure) and _run.is_gameplay_active(),
		"Ring Reinforcement rank one enlarges the visible ring and grants live radius/grace")

	# Cant Hook is event-driven rather than periodic: one successful manual cut
	# tugs the most endangered body inward.
	await _fresh_power(&"cant_hook", 1, 64004)
	var hook_body := _spawn_loose_body()
	if hook_body != null:
		hook_body.global_position = Vector3(2.0, 0.4, 0.0)
		hook_body.boundary_exposure = 2.0
		hook_body.linear_velocity = Vector3.ZERO
	_run.call("on_manual_strike_resolved", true, Vector3.ZERO, 1)
	_check(hook_body != null and hook_body.linear_velocity.x < -0.99 \
		and _trigger_count(&"cant_hook") == 1,
		"Cant Hook rank one visibly tugs the worst exposed loose root inward")


func _test_reward_and_grain_powers() -> void:
	await _fresh_power(&"quick_study", 1, 65001)
	var quick_award := _run.award_xp(10)
	_check(quick_award == 14 and _run.get_xp() == 14,
		"Quick Study rank one composes with the global XP boost exactly once")

	await _fresh_power(&"keen_appraisal", 1, 65002)
	var cash_descriptor := _run.call("_make_descriptor") as LogDescriptor
	var yard := SurvivorsContent.yards().by_id(cash_descriptor.yard_id) \
		if cash_descriptor != null else null
	var cash_reward := yard.reward_for_species(cash_descriptor.species_id) \
		if yard != null and cash_descriptor != null else null
	var base_cash := cash_reward.cash_reward if cash_reward != null else 0
	_check(cash_descriptor != null and base_cash > 0 \
		and cash_descriptor.cash_reward_snapshot == int(round(float(base_cash) * 1.10)),
		"Keen Appraisal rank one snapshots 10% more session cash onto future roots")

	await _fresh_power(&"grain_reader", 1, 65003)
	_game.set("debug_force_grain", 1)
	_game.call("debug_hold_grain_cue")
	var grain_cue := bool(_game.call("debug_has_grain_cue"))
	var grain_valid := bool(_game.call("debug_grain_plane_valid"))
	var grain_marks := int(_game.call("debug_grain_top_mark_count"))
	var grain_source := StringName(_game.call("debug_grain_offer_source"))
	var grain_visible := grain_cue and grain_valid and grain_marks == 3
	var grain_descriptor := _game.get("_current_descriptor") as LogDescriptor
	var grain_base_xp := _descriptor_base_xp(grain_descriptor)
	var grain_before_xp := _run.get_xp()
	var grain_split := bool(_game.call("debug_slice_world", _centre_cut_plane()))
	var grain_bonus := int(_game.call("debug_last_grain_bonus"))
	var expected_grain_bonus := int(round(float(int(round(
		float(grain_base_xp) * 1.50))) * _run.tuning.global_xp_gain_multiplier))
	_check(grain_visible and grain_source == &"grain_reader" \
		and grain_split and grain_bonus == expected_grain_bonus \
		and _run.get_xp() == grain_before_xp + grain_bonus,
		"Grain Reader rank one draws a visible valid mark whose cut guarantees a split and bonus XP")

func _test_grain_suspend_restore() -> void:
	await _fresh_power(&"grain_reader", 1, 65501)
	_game.set("debug_force_grain", 1)
	_game.call("debug_hold_grain_cue")
	var live_count := int(_game.call("debug_grain_offer_count"))
	var live_visible := bool(_game.call("debug_has_grain_cue")) \
		and bool(_game.call("debug_grain_plane_valid")) \
		and int(_game.call("debug_grain_top_mark_count")) == 3 \
		and StringName(_game.call("debug_grain_offer_source")) == &"grain_reader" \
		and live_count >= 1
	var live_rng_before := int(_run.to_save_dict().get("rng_state", -1))
	var live_snapshot := _run.suspend_attempt()
	var live_chopping := live_snapshot.get("chopping", {}) as Dictionary
	var saved_cue := live_chopping.get("grain_cue", {}) as Dictionary
	var live_saved := bool(live_chopping.get("grain_offered", false)) \
		and int(live_chopping.get("grain_offer_count", 0)) == live_count \
		and not saved_cue.is_empty() \
		and StringName(saved_cue.get("target_piece_id", "")) != &"" \
		and saved_cue.get("local_plane", null) is Plane \
		and saved_cue.get("local_anchor", null) is Vector3 \
		and StringName(saved_cue.get("source", "")) == &"grain_reader" \
		and int(live_snapshot.get("rng_state", -2)) == live_rng_before
	var live_restored := _run.restore_attempt(live_snapshot)
	var live_rng_after := int(_run.to_save_dict().get("rng_state", -3))
	var restored_visible := bool(_game.call("debug_has_grain_cue")) \
		and bool(_game.call("debug_grain_plane_valid")) \
		and int(_game.call("debug_grain_top_mark_count")) == 3 \
		and StringName(_game.call("debug_grain_offer_source")) == &"grain_reader" \
		and int(_game.call("debug_grain_offer_count")) == live_count
	var restored_descriptor := _game.get("_current_descriptor") as LogDescriptor
	var restored_base_xp := _descriptor_base_xp(restored_descriptor)
	_run.resume_attempt()
	var restored_xp_before := _run.get_xp()
	var restored_cut := bool(_game.call(
		"debug_slice_world", _centre_cut_plane()))
	var restored_bonus := int(_game.call("debug_last_grain_bonus"))
	var expected_restored_bonus := int(round(float(int(round(
		float(restored_base_xp) * 1.50))) \
		* _run.tuning.global_xp_gain_multiplier))
	_check(live_visible and live_saved and live_restored and restored_visible \
		and live_rng_after == live_rng_before and restored_cut \
		and restored_bonus == expected_restored_bonus \
		and _run.get_xp() == restored_xp_before + restored_bonus,
		"a live R1 Grain Reader mark preserves its exact visible source, geometry, count, RNG, and payout through suspend/restore")

	# Externally staging the next root is the lifecycle edge that releases the
	# once-per-log latch. A forced next-root offer must start at count one rather
	# than inheriting either the restored root's latch or offer count.
	var next_body := _spawn_loose_body()
	var next_descriptor := _arena.claim_for_block(_body_id(next_body)) \
		if next_body != null else null
	_game.set("debug_force_grain", 1)
	if next_descriptor != null:
		_game.call("stage_run_log", next_descriptor, false)
	var next_root_mark := next_descriptor != null \
		and bool(_game.call("debug_has_grain_cue")) \
		and bool(_game.call("debug_grain_plane_valid")) \
		and int(_game.call("debug_grain_top_mark_count")) == 3 \
		and int(_game.call("debug_grain_offer_count")) == 1 \
		and StringName(_game.call("debug_grain_offer_source")) == &"grain_reader"
	_check(next_root_mark,
		"the next externally staged root resets Grain Reader's latch and can receive one fresh R1 mark")

	# A saved miss has no cue and an open latch. Restore must reproduce that exact
	# state without immediately rolling the same piece again and advancing the
	# authoritative RunDirector RNG.
	await _fresh_power(&"grain_reader", 1, 65502)
	_game.set("debug_force_grain", 0)
	_game.call("_clear_grain_cue", &"acceptance_no_mark")
	_game.set("_grain_offered_this_log", false)
	_game.set("_grain_offer_count_this_log", 0)
	_game.call("_refresh_grain_availability")
	var no_mark_before := not bool(_game.call("debug_has_grain_cue")) \
		and StringName(_game.call("debug_grain_offer_source")) == &"" \
		and int(_game.call("debug_grain_offer_count")) == 0
	_game.set("debug_force_grain", -1)
	var no_mark_rng_before := int(_run.to_save_dict().get("rng_state", -1))
	var no_mark_snapshot := _run.suspend_attempt()
	var no_mark_chopping := no_mark_snapshot.get("chopping", {}) as Dictionary
	var no_mark_saved := not bool(no_mark_chopping.get("grain_offered", true)) \
		and int(no_mark_chopping.get("grain_offer_count", -1)) == 0 \
		and (no_mark_chopping.get("grain_cue", {}) as Dictionary).is_empty() \
		and int(no_mark_snapshot.get("rng_state", -2)) == no_mark_rng_before
	var no_mark_restored := _run.restore_attempt(no_mark_snapshot)
	var no_mark_rng_after := int(_run.to_save_dict().get("rng_state", -3))
	_check(no_mark_before and no_mark_saved and no_mark_restored \
		and no_mark_rng_after == no_mark_rng_before \
		and not bool(_game.call("debug_has_grain_cue")) \
		and StringName(_game.call("debug_grain_offer_source")) == &"" \
		and int(_game.call("debug_grain_offer_count")) == 0,
		"a no-mark Grain Reader save restores without rerolling the same piece or advancing run RNG")


func _test_periodic_and_completion_powers() -> void:
	await _fresh_power(&"flying_wedge", 1, 66001)
	var wedge_pieces := int(_game.call("piece_count"))
	var wedge_safe := _spawn_loose_body()
	var wedge_endangered := _spawn_loose_body()
	if wedge_safe != null:
		wedge_safe.boundary_exposure = 0.25
		wedge_safe.global_position = Vector3(-1.0, 0.4, -0.4)
	if wedge_endangered != null:
		wedge_endangered.boundary_exposure = 3.0
		wedge_endangered.global_position = Vector3(1.5, 0.4, 0.5)
	var wedge_endangered_id := _body_id(wedge_endangered)
	var wedge_safe_id := _body_id(wedge_safe)
	var wedge_descriptor := wedge_endangered.descriptor \
		if wedge_endangered != null else null
	var wedge_origin := wedge_endangered.global_position \
		if wedge_endangered != null else Vector3.INF
	var wedge_cash_before := _run.get_cash()
	var wedge_xp_before := _run.get_xp()
	var wedge_bursts_before := _power_burst_count(&"flying_wedge")
	# `_fresh_power` deliberately waits for HUD composition, so production frame
	# processing has already consumed a small, variable part of the 12-second
	# cadence. Advance relative to the authoritative remaining timer instead of
	# assuming this probe starts at exactly 12.000 seconds.
	var wedge_left := float((_runtime_state().get(
		"periodic_seconds_left", {}) as Dictionary).get("flying_wedge", -1.0))
	_advance_power_time(maxf(0.0, wedge_left - 0.01))
	var wedge_early := int(_arena_body_state(wedge_endangered_id).get(
		"pending_power_cuts", 0))
	_advance_power_time(0.02)
	var wedge_endangered_removed := _arena_body_state(
		wedge_endangered_id).is_empty()
	var wedge_safe_state := _arena_body_state(wedge_safe_id)
	var wedge_burst := _latest_power_burst(&"flying_wedge")
	var wedge_action := wedge_burst.get_node_or_null("ActionSilhouette") \
		as Node3D if wedge_burst != null else null
	var wedge_visual := wedge_action != null \
		and wedge_action.get_node_or_null("FlyingWedge") is MeshInstance3D \
		and wedge_action.get_node_or_null("WedgeTail") is MeshInstance3D \
		and _action_visual_contract(wedge_burst,
			[&"FlyingWedge", &"WedgeTail"], true) \
		and wedge_descriptor != null \
		and wedge_burst.global_position.distance_to(
			wedge_origin) < 0.2
	_check(wedge_left > 0.01 and wedge_early == 0 \
		and wedge_endangered_removed \
		and wedge_descriptor != null \
		and wedge_descriptor.pending_power_cuts >= 1 \
		and wedge_descriptor.pending_power_cuts <= 5 \
		and not wedge_safe_state.is_empty() \
		and int(_game.call("piece_count")) == wedge_pieces \
		and _run.get_cash() == wedge_cash_before \
			+ wedge_descriptor.cash_reward_snapshot \
		and _run.get_xp() == wedge_xp_before \
			+ wedge_descriptor.xp_reward_snapshot \
		and _trigger_count(&"flying_wedge") == 1 and wedge_visual \
		and _power_burst_count(&"flying_wedge") == wedge_bursts_before + 1,
		"Flying Wedge rank one waits 12 seconds, immediately destroys and randomly fragments the most endangered loose root, pays once, and presents one anchored wedge silhouette [left=%.3f early=%d removed=%s fragments=%d safe=%s triggers=%d bursts=%d→%d visual=%s]" % [
			wedge_left, wedge_early, wedge_endangered_removed,
			(wedge_descriptor.pending_power_cuts + 1) \
				if wedge_descriptor != null else -1,
			not wedge_safe_state.is_empty(),
			_trigger_count(&"flying_wedge"), wedge_bursts_before,
			_power_burst_count(&"flying_wedge"), wedge_visual])

	var shaker_double_value := await _forced_quality_rank_one_effect(
		&"double_chop", ProgressionEffectDef.Kind.GUARANTEED_EXTRA_CUTS,
		RunOfferTuning.Quality.LEGENDARY, 66002)
	var shaker_setup := _run.debug_set_run_power_rank(&"earthshaker", 1)
	await _wait_frames(1)
	# Keep every valid descendant on the block for this geometry proof. The live
	# firewood threshold is intentionally restored immediately after the one
	# synchronous strike; only the available target count changes, while every
	# cut still travels through the production slicer and sequence accounting.
	var shaker_min_vol := float(_game.get("min_vol"))
	var shaker_aspect_limit := float(_game.get("aspect_limit"))
	_game.set("min_vol", 0.0)
	_game.set("aspect_limit", 1000.0)
	var shaker_prepared := bool(_game.call(
		"debug_slice_world", Plane(Vector3.BACK, 0.0)))
	var shaker_body := _spawn_loose_body()
	var shaker_id := _body_id(shaker_body)
	var shaker_descriptor := shaker_body.descriptor if shaker_body != null else null
	if shaker_body != null:
		shaker_body.global_position = Vector3(0.8, 0.4, 0.0)
		# Begin with a deliberately unsafe outward/tangential/upward launch. The
		# Earthshaker draw must replace all three components, not add to them.
		shaker_body.linear_velocity = Vector3(-7.0, 3.0, 4.0)
	_game.set("debug_split_roll", 1)
	var shaker_split := bool(_game.call(
		"debug_swing_world", _centre_cut_plane()))
	_game.set("min_vol", shaker_min_vol)
	_game.set("aspect_limit", shaker_aspect_limit)
	var shaker_state := _arena_body_state(shaker_id)
	var shaker_cuts := int(_game.call(
		"debug_last_run_power_cuts", &"double_chop"))
	var shaker_triggered := _trigger_count(&"earthshaker")
	_check(shaker_setup and is_equal_approx(shaker_double_value, 4.0) \
		and shaker_prepared and shaker_split and shaker_cuts >= 3 \
		and shaker_state.is_empty() \
		and shaker_descriptor != null \
		and shaker_descriptor.pending_power_cuts >= 1 \
		and shaker_descriptor.pending_power_cuts <= 5 \
		and shaker_descriptor.pending_power_scars == 0 \
		and shaker_descriptor.pending_power_cut_sources.size() \
			== shaker_descriptor.pending_power_cuts \
		and shaker_descriptor.pending_power_cut_sources.all(
			func(source: StringName) -> bool: return source == &"earthshaker") \
		and shaker_triggered == 1,
		"Earthshaker R1 counts a real R1 Legendary Double Chop sequence, then immediately destroys and randomly fragments the affected loose root [prepared=%s split=%s sequence=%d removed=%s fragments=%d scars=%d triggers=%d]" % [
			shaker_prepared, shaker_split, shaker_cuts,
			shaker_state.is_empty(),
			(shaker_descriptor.pending_power_cuts + 1) \
				if shaker_descriptor != null else -1,
			shaker_descriptor.pending_power_scars \
				if shaker_descriptor != null else -1,
			shaker_triggered])

	await _fresh_power(&"powder_keg", 1, 66003)
	var keg_a := _spawn_loose_body()
	var keg_b := _spawn_loose_body()
	if keg_a != null:
		keg_a.global_position = Vector3(0.6, 0.4, 0.0)
		keg_a.linear_velocity = Vector3.ZERO
	if keg_b != null:
		keg_b.global_position = Vector3(-0.8, 0.4, 0.0)
		keg_b.linear_velocity = Vector3.ZERO
	var keg_a_id := _body_id(keg_a)
	var keg_b_id := _body_id(keg_b)
	var active_descriptor := _game.get("_current_descriptor") as LogDescriptor
	var keg_receipt := _run.on_manual_root_completed(active_descriptor, Vector3.ZERO)
	var keg_logs := _cut_receipt_total((keg_receipt.get(
		"powder_keg", {}) as Dictionary).get("cuts", []))
	_check(not keg_receipt.is_empty() and keg_logs == 2 \
		and _arena_body_state(keg_a_id).is_empty() \
		and _arena_body_state(keg_b_id).is_empty() \
		and _trigger_count(&"powder_keg") == 1,
		"Powder Keg rank one immediately destroys two nearby loose logs")

	await _fresh_power(&"kindling_chain", 1, 66004)
	var chain_body := _spawn_loose_body()
	if chain_body != null:
		chain_body.global_position = Vector3(0.8, 0.4, 0.0)
	var chain_body_id := _body_id(chain_body)
	var chain_descriptor := _game.get("_current_descriptor") as LogDescriptor
	var chain_receipt := _run.on_manual_root_completed(chain_descriptor, Vector3.ZERO)
	_check(not chain_receipt.is_empty() \
		and _arena_body_state(chain_body_id).is_empty() \
		and _trigger_count(&"kindling_chain") == 1,
		"Kindling Chain rank one immediately destroys one nearby loose log")

	await _fresh_power(&"whirling_axe", 1, 66005)
	var orbit_root := _game.get_node_or_null("RunPowerOrbitingAxes") as Node3D
	var visible_axe := orbit_root.get_child(0) as Node3D \
		if orbit_root != null and orbit_root.get_child_count() == 1 else null
	var orbit_body := _spawn_loose_body()
	var opposite_body := _spawn_loose_body()
	var orbit_id := _body_id(orbit_body)
	var opposite_id := _body_id(opposite_body)
	var orbit_descriptor := orbit_body.descriptor if orbit_body != null else null
	if visible_axe != null and orbit_body != null and opposite_body != null:
		var radial := visible_axe.global_position - orbit_root.global_position
		orbit_body.freeze = true
		opposite_body.freeze = true
		orbit_body.global_position = visible_axe.global_position
		opposite_body.global_position = orbit_root.global_position - radial
	var orbit_visible := int(_game.call("debug_orbiting_axe_count")) == 1 \
		and visible_axe != null
	_advance_power_time(2.01)
	var orbit_state := _arena_body_state(orbit_id)
	var opposite_state := _arena_body_state(opposite_id)
	_check(orbit_visible and orbit_state.is_empty() \
		and orbit_descriptor != null \
		and orbit_descriptor.pending_power_cuts >= 1 \
		and orbit_descriptor.pending_power_cuts <= 5 \
		and orbit_descriptor.pending_power_cut_sources.size() \
			== orbit_descriptor.pending_power_cuts \
		and orbit_descriptor.pending_power_cut_sources.all(
			func(source: StringName) -> bool: return source == &"whirling_axe") \
		and int(opposite_state.get("pending_power_cuts", 0)) == 0 \
		and _trigger_count(&"whirling_axe") >= 1,
		"Whirling Axe rank one completes only the root under the rendered axe, never the opposite side of its annulus")

	await _fresh_power(&"crosscut_sweep", 1, 66006)
	var sweep_first_body := _spawn_loose_body()
	var sweep_second_body := _spawn_loose_body()
	var sweep_first_id := _body_id(sweep_first_body)
	var sweep_second_id := _body_id(sweep_second_body)
	var sweep_first_descriptor := sweep_first_body.descriptor \
		if sweep_first_body != null else null
	var sweep_second_descriptor := sweep_second_body.descriptor \
		if sweep_second_body != null else null
	var sweep_active_descriptor := _game.get("_current_descriptor") as LogDescriptor
	if sweep_first_body != null:
		sweep_first_body.global_position = Vector3(0.0, 0.4, 2.0)
	if sweep_second_body != null:
		sweep_second_body.global_position = Vector3(2.0, 0.4, 0.0)
	var sweep_expected_travel := float(_runtime_state().get(
		"effective_boundary_radius", 0.0)) * 2.0
	var sweep_bursts_before := _power_burst_count(&"crosscut_sweep")
	_advance_power_time(14.01)
	var sweep_first_state := _arena_body_state(sweep_first_id)
	var sweep_second_early := _arena_body_state(sweep_second_id)
	var sweep_block_cuts := int(_game.call(
		"debug_last_run_power_cuts", &"crosscut_sweep"))
	var sweep_saved_runtime: Variant = _run.to_save_dict().get(
		"run_power_runtime", {})
	var sweep_automatic_ids: Variant = (sweep_saved_runtime as Dictionary).get(
		"automatic_completion_ids", {}) \
		if sweep_saved_runtime is Dictionary else {}
	var sweep_block_completed := sweep_active_descriptor != null \
		and sweep_automatic_ids is Dictionary \
		and (sweep_automatic_ids as Dictionary).has(
			String(sweep_active_descriptor.id))
	var sweep_first_burst := _latest_power_burst(&"crosscut_sweep")
	var sweep_first_action := sweep_first_burst.get_node_or_null(
		"ActionSilhouette") as Node3D if sweep_first_burst != null else null
	var sweep_first_blade := sweep_first_action.get_node_or_null(
		"CrosscutBlade") as MeshInstance3D if sweep_first_action != null else null
	var sweep_first_visual := sweep_first_blade != null \
		and sweep_first_blade.mesh is BoxMesh \
		and is_equal_approx((sweep_first_blade.mesh as BoxMesh).size.x, 2.0) \
		and is_equal_approx(float(sweep_first_burst.get("_action_span")), 2.0) \
		and is_equal_approx(float(sweep_first_burst.get(
			"_action_travel_span")), sweep_expected_travel) \
		and is_zero_approx(sweep_first_action.rotation.y) \
		and is_zero_approx(sweep_first_action.position.x) \
		and is_equal_approx(sweep_first_action.position.z,
			-sweep_expected_travel * 0.5) \
		and int(sweep_first_burst.get("_action_variant")) == 0 \
		and _action_visual_contract(sweep_first_burst,
			[&"CrosscutBlade"], false)
	_advance_power_time(14.01)
	var sweep_second_state := _arena_body_state(sweep_second_id)
	var sweep_first_after := _arena_body_state(sweep_first_id)
	var sweep_second_burst := _latest_power_burst(&"crosscut_sweep")
	var sweep_second_action := sweep_second_burst.get_node_or_null(
		"ActionSilhouette") as Node3D if sweep_second_burst != null else null
	var sweep_second_visual := sweep_second_action != null \
		and sweep_second_action.get_node_or_null(
			"CrosscutBlade") is MeshInstance3D \
		and is_equal_approx(sweep_second_action.rotation.y, PI * 0.5) \
		and is_equal_approx(float(sweep_second_burst.get(
			"_action_travel_span")), sweep_expected_travel) \
		and is_equal_approx(sweep_second_action.position.x,
			-sweep_expected_travel * 0.5) \
		and is_zero_approx(sweep_second_action.position.z) \
		and int(sweep_second_burst.get("_action_variant")) == 1 \
		and _action_visual_contract(sweep_second_burst,
			[&"CrosscutBlade"], false)
	_check(sweep_first_state.is_empty() \
		and int(sweep_second_early.get("pending_power_cuts", 0)) == 0 \
		and sweep_first_after.is_empty() \
		and sweep_second_state.is_empty() \
		and sweep_first_descriptor != null \
		and sweep_first_descriptor.pending_power_cuts >= 1 \
		and sweep_first_descriptor.pending_power_cuts <= 5 \
		and sweep_second_descriptor != null \
		and sweep_second_descriptor.pending_power_cuts >= 1 \
		and sweep_second_descriptor.pending_power_cuts <= 5 \
		and sweep_block_cuts > 1 and sweep_block_completed \
		and _trigger_count(&"crosscut_sweep") == 2 \
		and sweep_first_visual and sweep_second_visual \
		and _power_burst_count(&"crosscut_sweep") == sweep_bursts_before + 2,
		"Crosscut Sweep completes the active block root and every loose root intersecting its alternating real axis, while presenting one authored-width blade per event")

	await _fresh_power(&"maul_drop", 1, 66007)
	var maul_pieces := int(_game.call("piece_count"))
	var maul_hard_normal := _spawn_loose_body()
	var maul_boss := _spawn_loose_body()
	if maul_hard_normal != null and maul_hard_normal.descriptor != null:
		maul_hard_normal.descriptor.hardness_snapshot = 999.0
		maul_hard_normal.global_position = Vector3(-1.3, 0.4, 0.7)
	if maul_boss != null and maul_boss.descriptor != null:
		maul_boss.descriptor.hardness_snapshot = 0.5
		maul_boss.descriptor.boss_id = &"acceptance_boss"
		maul_boss.descriptor.boss_tier = 1
		maul_boss.global_position = Vector3(1.6, 0.4, -0.6)
	var maul_boss_id := _body_id(maul_boss)
	var maul_normal_id := _body_id(maul_hard_normal)
	var maul_boss_position := maul_boss.global_position \
		if maul_boss != null else Vector3.INF
	var maul_bursts_before := _power_burst_count(&"maul_drop")
	_advance_power_time(18.01)
	var maul_boss_removed := _arena_body_state(maul_boss_id).is_empty()
	var maul_normal_removed := _arena_body_state(maul_normal_id).is_empty()
	var maul_burst := _latest_power_burst(&"maul_drop")
	var maul_action := maul_burst.get_node_or_null("ActionSilhouette") \
		as Node3D if maul_burst != null else null
	var maul_visual := maul_action != null \
		and maul_action.get_node_or_null("MaulHead") is MeshInstance3D \
		and maul_action.get_node_or_null("MaulHandle") is MeshInstance3D \
		and _action_visual_contract(maul_burst,
			[&"MaulHead", &"MaulHandle"], true) \
		and maul_burst.global_position.distance_to(maul_boss_position) < 0.2
	_check(maul_boss_removed and maul_normal_removed \
		and int(_game.call("piece_count")) == maul_pieces \
		and _trigger_count(&"maul_drop") == 1 and maul_visual \
		and _power_burst_count(&"maul_drop") == maul_bursts_before + 1,
		"Maul Drop rank one immediately destroys up to three hardest loose logs, boss first, and presents one anchored maul silhouette")

	await _fresh_power(&"stump_pulse", 1, 66008)
	var pulse_body := _spawn_loose_body()
	if pulse_body != null:
		pulse_body.global_position = Vector3(1.0, 0.4, 0.0)
		pulse_body.linear_velocity = Vector3.ZERO
	_advance_power_time(14.01)
	_check(pulse_body != null and pulse_body.linear_velocity.x < -1.99 \
		and _trigger_count(&"stump_pulse") == 1,
		"Stump Pulse rank one waits 14 seconds and visibly shoves loose roots inward")

	await _fresh_power(&"splitter_rig", 1, 66009)
	var rig_setup := _run.debug_set_run_power_rank(&"powder_keg", 1) \
		and _run.debug_set_run_power_rank(&"kindling_chain", 1)
	var rig_body := _spawn_loose_body()
	var rig_remaining := _spawn_loose_body()
	if rig_body != null:
		rig_body.global_position = Vector3(1.2, 0.4, 0.0)
		rig_body.boundary_exposure = 3.0
	if rig_remaining != null:
		rig_remaining.global_position = Vector3(0.4, 0.4, 0.0)
		rig_remaining.boundary_exposure = 0.1
	var rig_descriptor := rig_body.descriptor if rig_body != null else null
	var rig_remaining_descriptor := rig_remaining.descriptor \
		if rig_remaining != null else null
	var rig_remaining_id := _body_id(rig_remaining)
	var rig_origin := rig_body.global_position if rig_body != null else Vector3.INF
	var rig_cash_before := _run.get_cash()
	var rig_xp_before := _run.get_xp()
	var rig_count_before := _arena.loose_log_count()
	var rig_bursts_before := _power_burst_count(&"splitter_rig")
	var rig_keg_bursts_before := _power_burst_count(&"powder_keg")
	var rig_chain_bursts_before := _power_burst_count(&"kindling_chain")
	var rig_left := float((_runtime_state().get(
		"periodic_seconds_left", {}) as Dictionary).get("splitter_rig", -1.0))
	_advance_power_time(rig_left + 0.01)
	var rig_remaining_state := _arena_body_state(rig_remaining_id)
	var rig_burst := _latest_power_burst(&"splitter_rig")
	var rig_cash_after := _run.get_cash()
	var rig_xp_after := _run.get_xp()
	var duplicate_rig_receipt := _run.call("_complete_automatic_descriptor",
		rig_descriptor, &"splitter_rig") as Dictionary \
		if rig_descriptor != null else {}
	_check(rig_setup and rig_descriptor != null and rig_left > 0.0 \
		and _arena.loose_log_count() == rig_count_before - 2 \
		and rig_descriptor.has_transfer_pose() \
		and rig_descriptor.transfer_from.is_equal_approx(rig_origin) \
		and rig_remaining_descriptor != null \
		and rig_cash_after == rig_cash_before \
			+ rig_descriptor.cash_reward_snapshot \
			+ rig_remaining_descriptor.cash_reward_snapshot \
		and rig_xp_after == rig_xp_before + rig_descriptor.xp_reward_snapshot \
			+ rig_remaining_descriptor.xp_reward_snapshot \
		and duplicate_rig_receipt.is_empty() \
		and _run.get_cash() == rig_cash_after and _run.get_xp() == rig_xp_after \
		and rig_remaining_state.is_empty() \
		and _trigger_count(&"splitter_rig") == 1 \
		and _trigger_count(&"powder_keg") == 1 \
		and _trigger_count(&"kindling_chain") == 0 \
		and _power_burst_count(&"splitter_rig") == rig_bursts_before + 1 \
		and _power_burst_count(&"powder_keg") == rig_keg_bursts_before + 1 \
		and _power_burst_count(&"kindling_chain") \
			== rig_chain_bursts_before \
		and rig_burst != null \
		and rig_burst.global_position.distance_to(rig_origin) < 0.3,
		"Splitter Rig preserves its target pose and payout; its source-neutral Powder Keg immediately destroys and pays the remaining loose log")


func _test_area_size_and_new_aoe_powers() -> void:
	await _fresh_power(&"area_size", 1, 67001)
	var halo_added := _run.debug_set_run_power_rank(&"sawblade_halo", 1)
	var halo_inside := _spawn_loose_body()
	var halo_outside := _spawn_loose_body()
	var halo_inside_id := _body_id(halo_inside)
	var halo_outside_id := _body_id(halo_outside)
	var halo_inside_descriptor := halo_inside.descriptor \
		if halo_inside != null else null
	if halo_inside != null:
		halo_inside.global_position = Vector3(1.58, 0.4, 0.0)
	if halo_outside != null:
		halo_outside.global_position = Vector3(1.72, 0.4, 0.0)
	_set_runtime_bursts_visible(_main, false)
	_advance_power_time(12.01)
	var halo_inside_state := _arena_body_state(halo_inside_id)
	var halo_outside_state := _arena_body_state(halo_outside_id)
	var halo_burst := _latest_power_burst(&"sawblade_halo")
	var halo_ring := halo_burst.get_node_or_null("ActionSilhouette/AreaRing") \
		if halo_burst != null else null
	_check(halo_added and is_equal_approx(_run.get_area_size_multiplier(), 1.1) \
		and is_equal_approx(_run.scale_power_area(1.5), 1.65) \
		and halo_inside_state.is_empty() \
		and halo_inside_descriptor != null \
		and halo_inside_descriptor.pending_power_cuts >= 1 \
		and halo_inside_descriptor.pending_power_cuts <= 5 \
		and halo_inside_descriptor.pending_power_cut_sources.count(
			&"sawblade_halo") == halo_inside_descriptor.pending_power_cuts \
		and int(halo_outside_state.get("pending_power_cuts", 0)) == 0 \
		and _trigger_count(&"sawblade_halo") == 1 \
		and halo_ring is MeshInstance3D \
		and is_equal_approx(float(halo_burst.get("_action_span")), 1.65),
		"Area Size R1 expands Sawblade Halo gameplay and its visible ring from 1.5m to 1.65m; Halo immediately destroys only roots inside it")
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.12, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image != null and image.get_width() == 1280 \
			and image.get_height() == 720 \
			and image.save_png(_AREA_CAPTURE_PATH) == OK,
			"the rendered Area Size + Sawblade Halo checkpoint writes at 1280x720")

	var earth_added := _run.debug_set_run_power_rank(&"earthshaker", 1)
	var earth_target := _spawn_loose_body()
	var earth_id := _body_id(earth_target)
	var earth_descriptor := earth_target.descriptor \
		if earth_target != null else null
	if earth_target != null:
		earth_target.global_position = Vector3(-1.58, 0.4, 0.0)
		earth_target.linear_velocity = Vector3.ZERO
	_run.on_manual_strike_resolved(true, Vector3.ZERO, 4)
	var earth_state := _arena_body_state(earth_id)
	var earth_burst := _latest_power_burst(&"earthshaker")
	_check(earth_added \
		and earth_state.is_empty() \
		and earth_descriptor != null \
		and earth_descriptor.pending_power_cuts >= 1 \
		and earth_descriptor.pending_power_cuts <= 5 \
		and earth_descriptor.pending_power_scars == 0 \
		and earth_burst != null \
		and earth_burst.get_node_or_null("ActionSilhouette/AreaRing") \
			is MeshInstance3D \
		and is_equal_approx(float(earth_burst.get("_action_span")), 1.65),
		"the general Area Size stat expands Earthshaker's completion AoE and its matching visual")

	await _fresh_power(&"timber_burst", 1, 67002)
	var timber_inside := _spawn_loose_body()
	var timber_chain := _spawn_loose_body()
	var timber_outside := _spawn_loose_body()
	var timber_inside_id := _body_id(timber_inside)
	var timber_chain_id := _body_id(timber_chain)
	var timber_outside_id := _body_id(timber_outside)
	var timber_inside_descriptor := timber_inside.descriptor \
		if timber_inside != null else null
	var timber_chain_descriptor := timber_chain.descriptor \
		if timber_chain != null else null
	if timber_inside != null:
		timber_inside.global_position = Vector3(1.1, 0.4, 0.0)
	if timber_chain != null:
		# Outside the initial burst, but inside the completed first target's burst.
		timber_chain.global_position = Vector3(2.0, 0.4, 0.0)
	if timber_outside != null:
		timber_outside.global_position = Vector3(-1.3, 0.4, 0.0)
	var completed := _game.get("_current_descriptor") as LogDescriptor
	var timber_receipt := _run.on_manual_root_completed(completed, Vector3.ZERO)
	var timber_inside_state := _arena_body_state(timber_inside_id)
	var timber_chain_state := _arena_body_state(timber_chain_id)
	var timber_outside_state := _arena_body_state(timber_outside_id)
	var timber_burst := _latest_power_burst(&"timber_burst")
	_check(timber_receipt.has("timber_burst") \
		and timber_inside_state.is_empty() \
		and timber_inside_descriptor != null \
		and timber_inside_descriptor.pending_power_cuts >= 1 \
		and timber_inside_descriptor.pending_power_cuts <= 5 \
		and timber_chain_state.is_empty() \
		and timber_chain_descriptor != null \
		and timber_chain_descriptor.pending_power_cuts >= 1 \
		and timber_chain_descriptor.pending_power_cuts <= 5 \
		and int(timber_outside_state.get("pending_power_cuts", 0)) == 0 \
		and _trigger_count(&"timber_burst") == 2 \
		and timber_burst != null \
		and timber_burst.get_node_or_null("ActionSilhouette/AreaRing") \
			is MeshInstance3D \
		and is_equal_approx(float(timber_burst.get("_action_span")), 1.2),
		"Timber Burst R1 immediately destroys every loose root inside its AoE, drains follow-on completion chains without recursion, excludes disconnected roots, and shows the authored area")


func _test_boosted_single_target_receipts() -> void:
	# Quality scales destructive count values as whole logs, never as partial cuts
	# accumulated on one descriptor.
	var splinter_effect := await _forced_quality_rank_one_effect(
		&"splinter_volley", ProgressionEffectDef.Kind.SPLINTER_COUNT,
		RunOfferTuning.Quality.LEGENDARY, 67501)
	var splinter_ids: Array[StringName] = []
	for index: int in range(5):
		var body := _spawn_loose_body()
		if body != null:
			body.global_position = Vector3(0.5 + float(index) * 0.25, 0.4, 0.0)
			splinter_ids.append(_body_id(body))
	var splinter_bursts_before := _power_burst_count(&"splinter_volley")
	var splinter_receipts: Array[Dictionary] = _run.trigger_splinter_volley(
		Vector3.ZERO)
	var splinter_total := _cut_receipt_total(splinter_receipts)
	var splinter_projectile := _game.find_child(
		"SplinterProjectile", true, false) as MeshInstance3D
	var splinter_projectile_count := int(splinter_projectile.get_meta(
		"splinter_count", 0)) if splinter_projectile != null else 0
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.24, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var splinter_capture := get_viewport().get_texture().get_image()
		_check(splinter_capture != null \
			and splinter_capture.save_png(
				"/private/tmp/axeman_splinter_volley.png") == OK,
			"the visible Splinter Volley projectile renders between the block strike and nearest loose root")
	var splinter_burst: RunPowerBurst = null
	for frame: int in range(90):
		splinter_burst = _power_burst_presenting_amount(
			&"splinter_volley", 4)
		if splinter_burst != null:
			break
		await get_tree().process_frame
	var splinter_removed := 0
	for id: StringName in splinter_ids:
		if _arena_body_state(id).is_empty():
			splinter_removed += 1
	_check(is_equal_approx(splinter_effect, 4.0) \
		and splinter_receipts.size() == 4 and splinter_total == 4 \
		and splinter_removed == 4 \
		and _trigger_count(&"splinter_volley") == 1 \
		and splinter_projectile_count == 4 \
		and splinter_burst != null and _burst_presents_amount(splinter_burst, 4),
		"Legendary R1 Splinter Volley visibly travels and immediately destroys its four nearest loose logs [effect=%.1f receipts=%d total=%d removed=%d projectile=%d triggers=%d bursts=%d→%d label=%s]" % [
			splinter_effect, splinter_receipts.size(), splinter_total,
			splinter_removed, splinter_projectile_count,
			_trigger_count(&"splinter_volley"), splinter_bursts_before,
			_power_burst_count(&"splinter_volley"),
			"missing" if splinter_burst == null else String((
				splinter_burst.get_node_or_null("PowerName") as Label3D).text)])

	var keg_effect := await _forced_quality_rank_one_effect(
		&"powder_keg", ProgressionEffectDef.Kind.POWDER_KEG_CUT_COUNT,
		RunOfferTuning.Quality.LEGENDARY, 67701)
	var keg_ids: Array[StringName] = []
	for index: int in range(3):
		var body := _spawn_loose_body()
		if body != null:
			body.global_position = Vector3(0.5 + float(index) * 0.2, 0.4, 0.0)
			keg_ids.append(_body_id(body))
	var keg_bursts_before := _power_burst_count(&"powder_keg")
	var boosted_keg_descriptor := _game.get("_current_descriptor") as LogDescriptor
	var boosted_keg_receipt := _run.on_manual_root_completed(
		boosted_keg_descriptor, Vector3.ZERO)
	var keg_payload := boosted_keg_receipt.get("powder_keg", {}) as Dictionary
	var keg_receipts: Array = keg_payload.get("cuts", [])
	var keg_total := _cut_receipt_total(keg_receipts)
	var keg_burst := _latest_power_burst(&"powder_keg")
	_check(is_equal_approx(keg_effect, 8.0) \
		and keg_receipts.size() == 3 and keg_total == 3 \
		and keg_ids.all(func(id: StringName) -> bool:
			return _arena_body_state(id).is_empty()) \
		and _trigger_count(&"powder_keg") == 1 \
		and _power_burst_count(&"powder_keg") == keg_bursts_before + 1 \
		and _burst_presents_amount(keg_burst, 3),
		"Legendary R1 Powder Keg destroys every available in-range log up to its eight-log value")

	var chain_effect := await _forced_quality_rank_one_effect(
		&"kindling_chain", ProgressionEffectDef.Kind.KINDLING_CHAIN_COUNT,
		RunOfferTuning.Quality.LEGENDARY, 67901)
	var chain_ids: Array[StringName] = []
	for index: int in range(4):
		var body := _spawn_loose_body()
		if body != null:
			body.global_position = Vector3(0.5 + float(index) * 0.2, 0.4, 0.0)
			chain_ids.append(_body_id(body))
	var chain_bursts_before := _power_burst_count(&"kindling_chain")
	var boosted_chain_descriptor := _game.get(
		"_current_descriptor") as LogDescriptor
	var boosted_chain_receipt := _run.on_manual_root_completed(
		boosted_chain_descriptor, Vector3.ZERO)
	var chain_receipts: Array = boosted_chain_receipt.get(
		"kindling_chain", [])
	var chain_total := _cut_receipt_total(chain_receipts)
	var chain_burst := _latest_power_burst(&"kindling_chain")
	_check(is_equal_approx(chain_effect, 4.0) \
		and chain_receipts.size() == 4 and chain_total == 4 \
		and chain_ids.all(func(id: StringName) -> bool:
			return _arena_body_state(id).is_empty()) \
		and _trigger_count(&"kindling_chain") == 1 \
		and _power_burst_count(&"kindling_chain") \
			== chain_bursts_before + 1 \
		and _burst_presents_amount(chain_burst, 4),
		"Legendary R1 Kindling Chain immediately destroys four distinct logs and presents ×4")


func _test_off_block_destruction_and_migration() -> void:
	await _fresh_power(&"splinter_volley", 1, 66801)
	# Migration only: an old descriptor can still reconstruct its saved partial
	# geometry, but no production power below creates another such descriptor.
	var legacy_body := _spawn_loose_body()
	var legacy_id := _body_id(legacy_body)
	if legacy_body != null and legacy_body.descriptor != null:
		legacy_body.descriptor.pending_power_cuts = 1
		legacy_body.descriptor.pending_power_cut_sources = [&"precut"]
	var legacy_save := _arena.to_save_dict()
	_arena.restore_from_save(legacy_save)
	var legacy_state := _arena_body_state(legacy_id)
	_check(int(legacy_state.get("pending_power_cuts", 0)) == 1 \
		and int(legacy_state.get("piece_count", 0)) == 2,
		"a retired partial-cut descriptor still reconstructs once for save migration")

	await _fresh_power(&"splinter_volley", 1, 66801)
	_game.call("_clear_finished_firewood")
	_game.set("orbs_enabled", true)
	var body := _spawn_loose_body()
	if body != null:
		body.quaternion = Quaternion(
			Vector3(0.37, 0.22, 0.90).normalized(), 0.91)
		body.global_position = Vector3(1.1, 0.45, 0.15)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	var id := _body_id(body)
	var descriptor := body.descriptor if body != null else null
	var impact_position := body.global_position if body != null else Vector3.ZERO
	var cash_before := _run.get_cash()
	var xp_before := _run.get_xp()
	var receipts: Array[Dictionary] = _run.trigger_splinter_volley(
		impact_position)
	var fragment_count := int(receipts[0].get("fragments", 0)) \
		if not receipts.is_empty() else 0
	var axes: Array = body.get_meta("power_cut_axes", []) \
		if body != null and is_instance_valid(body) else []
	var axes_are_vertical := axes.size() == maxi(0, fragment_count - 1)
	for raw_axis: Variant in axes:
		if not (raw_axis is Vector3):
			axes_are_vertical = false
			break
		var axis := raw_axis as Vector3
		axes_are_vertical = axes_are_vertical and is_zero_approx(axis.y) \
			and (axis.is_equal_approx(Vector3.RIGHT) \
				or axis.is_equal_approx(Vector3.FORWARD))
	var falling := _game.debug_finished_piece_state() as Dictionary
	var arena_save := _arena.to_save_dict()
	if DisplayServer.get_name() != "headless":
		_hud.hide()
		_set_runtime_bursts_visible(_game, false)
		await get_tree().create_timer(0.12, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image != null and image.save_png(
			"/private/tmp/axeman_off_block_immediate_destruction.png") == OK,
			"the immediate off-block destruction checkpoint renders its fragment burst")
		_set_runtime_bursts_visible(_game, true)
		_hud.show()
	_game.call("_update_finished_piece_sink",
		float(_game.get("firewood_settle_timeout")) + 0.01)
	var settled := _game.debug_finished_piece_state() as Dictionary
	_game.call("_update_finished_piece_sink", 0.05)
	var sinking := _game.debug_finished_piece_state() as Dictionary
	_game.call("_update_finished_piece_sink", 10.0)
	var terminated := _game.debug_finished_piece_state() as Dictionary
	var duplicate := _run.complete_off_block_log(
		descriptor, fragment_count, &"splinter_volley", impact_position) \
		if descriptor != null else {}
	_check(descriptor != null and receipts.size() == 1 \
		and _cut_receipt_total(receipts) == 1 \
		and fragment_count >= 2 and fragment_count <= 6 \
		and _arena_body_state(id).is_empty() \
		and not _arena_save_has_log_id(arena_save, id) \
		and axes_are_vertical \
		and descriptor.pending_power_cuts == fragment_count - 1 \
		and descriptor.pending_power_cut_sources.size() \
			== fragment_count - 1 \
		and descriptor.pending_power_cut_sources.all(
			func(source: StringName) -> bool:
				return source == &"splinter_volley") \
		and _run.get_cash() == cash_before + descriptor.cash_reward_snapshot \
		and _run.get_xp() == xp_before + descriptor.xp_reward_snapshot \
		and int(falling.get("count", 0)) == fragment_count \
		and int(falling.get("geometry_count", 0)) == fragment_count \
		and int(falling.get("settling_count", 0)) == fragment_count \
		and int(falling.get("enabled_collision_count", 0)) == fragment_count \
		and int(settled.get("settling_count", -1)) == 0 \
		and int(settled.get("enabled_collision_count", -1)) == 0 \
		and float(sinking.get("max_sink_distance", 0.0)) > 0.0 \
		and int(terminated.get("count", -1)) == 0 \
		and duplicate.is_empty(),
		"one off-block power hit immediately removes one hazard, makes a random 2–6-part real breakup on log-local vertical planes, pays cash/XP once, then settles and sinks every fragment [receipts=%s fragments=%d axes=%d falling=%s settled=%s sinking=%s terminated=%s]" % [
			receipts, fragment_count, axes.size(), falling, settled, sinking,
			terminated])
	_game.set("orbs_enabled", false)


func _test_capped_automatic_completion() -> void:
	await _fresh_power(&"splitter_rig", 1, 66901)
	var descriptor := _game.get("_current_descriptor") as LogDescriptor
	var pieces := int(_game.call("piece_count"))
	_run.set("_cash", GameState.MAX_SAFE_ECONOMY_VALUE)
	_run.set("_xp", GameState.MAX_SAFE_ECONOMY_VALUE)
	var first := _run.complete_automatic_active_log(
		descriptor, pieces, &"splitter_rig")
	var second := _run.complete_automatic_active_log(
		descriptor, pieces, &"splitter_rig")
	var save := _run.to_save_dict()
	var raw_shares: Variant = save.get("pending_piece_cash", [])
	var shares_are_zero := raw_shares is Array \
		and (raw_shares as Array).size() == pieces
	if raw_shares is Array:
		for raw_share: Variant in raw_shares:
			shares_are_zero = shares_are_zero and int(raw_share) == 0
	_check(descriptor != null and pieces > 0 and not first.is_empty() \
		and int(first.get("cash_total", -1)) == 0 \
		and int(first.get("xp_total", -1)) == 0 \
		and bool(first.get("automatic", false)) \
		and second.is_empty() and shares_are_zero \
		and StringName(save.get("active_log_id", "missing")) == &"" \
		and bool(save.get("boundary_timers_paused", false)),
		"a valid automatic completion at cash and XP caps is consumed exactly once despite a zero-value payout")


func _test_momentum_rescue_and_persistence() -> void:
	await _fresh_power(&"momentum", 1, 67001)
	var momentum_base_cooldown := float(_game.call("current_swing_cooldown"))
	var momentum_base_chance := float(_game.call("debug_split_chance"))
	for _cut: int in range(3):
		_run.on_manual_strike_resolved(true, Vector3.ZERO, 1)
	var momentum_state := _runtime_state()
	var momentum_fast := float(_game.call("current_swing_cooldown"))
	var momentum_reliable := float(_game.call("debug_split_chance"))
	var stacked_ok := int(momentum_state.get("momentum_stacks", 0)) == 3 \
		and is_equal_approx(float(momentum_state.get("momentum_speed_bonus", 0.0)), 0.06) \
		and is_equal_approx(float(momentum_state.get(
			"momentum_reliability_bonus", 0.0)), 0.03) \
		and momentum_fast < momentum_base_cooldown \
		and momentum_reliable > momentum_base_chance + 0.029
	_run.on_manual_strike_resolved(false, Vector3.ZERO, 0)
	_check(stacked_ok and int(_runtime_state().get("momentum_stacks", -1)) == 0 \
		and is_equal_approx(float(_game.call("current_swing_cooldown")),
			momentum_base_cooldown),
		"Momentum rank one builds three real speed/reliability stacks and failure resets them")

	await _fresh_power(&"last_ditch_rescue", 1, 67002)
	var rescue_body := _spawn_loose_body()
	var rescue_radius := float(_runtime_state().get("effective_boundary_radius", 0.0))
	var rescue_grace := float(_runtime_state().get("effective_boundary_grace", 0.0))
	if rescue_body != null:
		rescue_body.freeze = true
		rescue_body.global_position = Vector3(rescue_radius + 0.5, 0.4, 0.0)
		rescue_body.boundary_exposure = rescue_grace - 0.05
	_arena.advance_hazards(0.10)
	_check(rescue_body != null and is_instance_valid(rescue_body) \
		and Vector2(rescue_body.global_position.x,
			rescue_body.global_position.z).length() < rescue_radius \
		and is_zero_approx(rescue_body.boundary_exposure) \
		and int(_runtime_state().get("rescue_charges_remaining", -1)) == 0 \
		and _trigger_count(&"last_ditch_rescue") == 1 \
		and _run.is_gameplay_active(),
		"Last-Ditch Rescue rank one spends one charge to return and reset an expiring root")

	# Cooldowns, stacks, rescue charges, and surviving loose roots are disposable
	# run state. Destroyed roots must not leave partial-cut journals in a save.
	_run.start_attempt(67003)
	await _wait_frames(1)
	for id: StringName in [&"flying_wedge", &"momentum",
			&"last_ditch_rescue", &"splinter_volley", &"yard_magnet"]:
		_run.call("debug_set_run_power_rank", id, 1)
	var destroyed_body := _spawn_loose_body()
	var saved_body := _spawn_loose_body()
	if destroyed_body != null:
		destroyed_body.global_position = Vector3(0.5, 0.4, 0.0)
	if saved_body != null:
		saved_body.global_position = Vector3(1.5, 0.4, 0.0)
	var destroyed_body_id := _body_id(destroyed_body)
	var saved_body_id := _body_id(saved_body)
	_run.trigger_splinter_volley(Vector3.ZERO)
	_advance_power_time(3.0)
	_run.on_manual_strike_resolved(true, Vector3.ZERO, 1)
	var before_pause := _runtime_state()
	_run.pause_attempt()
	_run.call("_process", 2.0)
	var while_paused := _runtime_state()
	var timer_before := float((before_pause.get(
		"periodic_seconds_left", {}) as Dictionary).get("flying_wedge", -1.0))
	var timer_paused := float((while_paused.get(
		"periodic_seconds_left", {}) as Dictionary).get("flying_wedge", -2.0))
	var magnet_cycle_paused := float(while_paused.get(
		"yard_magnet_cycle_seconds_left", -2.0))
	_run.resume_attempt()
	var snapshot := _run.suspend_attempt()
	var saved_state := _runtime_state()
	var saved_body_state := _arena_body_state(saved_body_id)
	var restored := _run.restore_attempt(snapshot)
	var restored_state := _runtime_state()
	var restored_body_state := _arena_body_state(saved_body_id)
	var state_restored := restored \
		and timer_before >= 0.0 and is_equal_approx(timer_before, timer_paused) \
		and is_equal_approx(float(saved_state.get(
			"yard_magnet_cycle_seconds_left", -1.0)), magnet_cycle_paused) \
		and is_equal_approx(float(restored_state.get(
			"yard_magnet_cycle_seconds_left", -2.0)), magnet_cycle_paused) \
		and is_equal_approx(float(saved_state.get(
			"yard_magnet_pulse_seconds_left", -1.0)), float(restored_state.get(
				"yard_magnet_pulse_seconds_left", -2.0))) \
		and int(saved_state.get("momentum_stacks", -1)) == 1 \
		and int(restored_state.get("momentum_stacks", -2)) == 1 \
		and int(saved_state.get("rescue_charges_remaining", -1)) == 1 \
		and int(restored_state.get("rescue_charges_remaining", -2)) == 1 \
		and not saved_body_state.is_empty() \
		and int(saved_body_state.get("pending_power_cuts", -1)) == 0 \
		and not restored_body_state.is_empty() \
		and int(restored_body_state.get("pending_power_cuts", -1)) == 0 \
		and _arena_body_state(destroyed_body_id).is_empty()
	_run.start_attempt(67004)
	var reset_state := _runtime_state()
	_check(state_restored and int(reset_state.get("momentum_stacks", -1)) == 0 \
		and int(reset_state.get("rescue_charges_remaining", -1)) == 0 \
		and is_zero_approx(float(reset_state.get(
			"yard_magnet_cycle_seconds_left", -1.0))) \
		and is_zero_approx(float(reset_state.get(
			"yard_magnet_pulse_seconds_left", -1.0))) \
		and (reset_state.get("periodic_seconds_left", {}) as Dictionary).is_empty(),
		"run-power timers, magnet pulse phase, stacks, charges, and surviving roots pause/save/restore while destroyed roots leave no partial journal")


func _fresh_power(id: StringName, rank: int, seed: int) -> void:
	_run.start_attempt(seed)
	await _wait_frames(2)
	if not _run.has_method("debug_set_run_power_rank"):
		_check(false, "RunDirector exposes deterministic rank setup for " + String(id))
		return
	var accepted := bool(_run.call("debug_set_run_power_rank", id, rank))
	await _wait_frames(1)
	if not accepted or _run.get_run_power_rank(id) != rank:
		_check(false, "%s reaches rank %d in a fresh run" % [id, rank])


func _open_next_offer() -> void:
	var award := _run.get_xp_to_next_level_for_xp(_run.get_xp())
	_run.award_xp(award)


func _offer_ids(offer: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var raw_cards: Variant = offer.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary:
				out.append(StringName((raw_card as Dictionary).get("id", "")))
	return out


func _offer_card(offer: Dictionary, id: StringName) -> Dictionary:
	var raw_cards: Variant = offer.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary \
					and StringName((raw_card as Dictionary).get("id", "")) == id:
				return (raw_card as Dictionary).duplicate(true)
	return {}


func _offer_only_changes_effects(offer: Dictionary) -> bool:
	var raw_cards: Variant = offer.get("cards", [])
	if not (raw_cards is Array) or (raw_cards as Array).is_empty():
		return false
	for raw_card: Variant in raw_cards:
		if not (raw_card is Dictionary):
			return false
		var card := raw_card as Dictionary
		var power_id := StringName(card.get("id", ""))
		if power_id == RunDirector.PAYDAY_POWER_ID:
			continue
		var definition := SurvivorsContent.run_powers().by_id(power_id)
		if definition == null:
			return false
		var current_picks := _float_array(card.get("pick_multipliers", []))
		var next_picks := current_picks.duplicate()
		next_picks.append(float(card.get("quality_multiplier", 0.0)))
		var changes := false
		for effect: ProgressionEffectDef in definition.effects:
			if effect == null:
				continue
			changes = changes or not is_equal_approx(
				definition.effect_value_for_pick_multipliers(
					effect.kind, current_picks),
				definition.effect_value_for_pick_multipliers(
					effect.kind, next_picks))
		if not changes:
			return false
	return true


func _offer_card_is_presented(offer: Dictionary, id: StringName,
		card: Dictionary) -> bool:
	var backdrop := _hud.get_node_or_null("RunPowerOffer") as Control
	var cards_node := backdrop.find_child("Cards", true, false) as Container \
		if backdrop != null else null
	var raw_cards: Variant = offer.get("cards", [])
	if backdrop == null or cards_node == null or not backdrop.visible \
			or not (raw_cards is Array):
		return false
	var card_index := -1
	for index: int in range((raw_cards as Array).size()):
		var raw_card: Variant = (raw_cards as Array)[index]
		if raw_card is Dictionary \
				and StringName((raw_card as Dictionary).get("id", "")) == id:
			card_index = index
			break
	if card_index < 0 or card_index >= cards_node.get_child_count():
		return false
	var panel := cards_node.get_child(card_index) as Control
	if panel == null:
		return false
	var badge := panel.find_child("QualityBadge", true, false) as Control
	var quality_label := panel.find_child("QualityLabel", true, false) as Label
	var effect_label := panel.find_child("EffectSummary", true, false) as Label
	var expected_quality := String(card.get("quality_name", "")).to_upper() \
		+ " QUALITY"
	return panel.visible and badge != null \
		and not card.has("rarity") \
		and panel.find_child("IdentityRarity", true, false) == null \
		and panel.get_theme_stylebox("panel") is StyleBoxFlat \
		and badge.get_theme_stylebox("panel") is StyleBoxFlat \
		and quality_label != null \
		and quality_label.text.contains(expected_quality) \
		and quality_label.text.contains("×") \
		and effect_label != null and effect_label.visible \
		and effect_label.text == String(card.get("effect_summary", "")) \
		and not effect_label.text.is_empty()


func _float_array(raw: Variant) -> Array[float]:
	var out: Array[float] = []
	if raw is Array:
		for value: Variant in raw:
			out.append(float(value))
	return out


func _float_arrays_equal(left: Array[float], right: Array[float]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if not is_equal_approx(left[index], right[index]):
			return false
	return true


func _power_slot_has_text(name_text: String, rank_text: String) -> bool:
	var slots := _hud.get_node("RunPowerSlots")
	for slot: Node in slots.get_children():
		var combined := ""
		for node: Node in slot.find_children("*", "Label", true, false):
			var label := node as Label
			if label != null:
				combined += "\n" + label.text
		if combined.contains(name_text) and combined.contains(rank_text):
			return true
	return false


func _first_power_slot_is_presented(id: StringName, rank: int) -> bool:
	var slot := _hud.get_node("RunPowerSlots").get_child(0)
	var name_label := slot.find_child("Name", true, false) as Label
	var rank_label := slot.find_child("Rank", true, false) as Label
	var status_label := slot.find_child("Status", true, false) as Label
	var icon := slot.find_child("Icon", true, false) as TextureRect
	var definition := SurvivorsContent.run_powers().by_id(id)
	return definition != null and name_label != null \
		and name_label.text == definition.display_name and not name_label.visible \
		and rank_label != null and rank_label.visible \
		and rank_label.text == "R%d" % rank \
		and status_label != null and not status_label.visible \
		and icon != null and icon.visible and icon.texture != null


func _centre_cut_plane() -> Plane:
	return Plane(Vector3.RIGHT, 0.0)


func _spawn_loose_body() -> LooseLogBody:
	if _run == null or _arena == null:
		return null
	_run.call("_spawn_timed_log")
	var bodies: Array = _arena.call("_live_bodies")
	return null if bodies.is_empty() else bodies[-1] as LooseLogBody


func _set_runtime_bursts_visible(root: Node, visible: bool) -> void:
	for child: Node in root.get_children():
		if child is RunPowerBurst or child is LevelUpBurst:
			(child as Node3D).visible = visible
		else:
			_set_runtime_bursts_visible(child, visible)


func _descriptor_base_xp(descriptor: LogDescriptor) -> int:
	if descriptor == null:
		return 0
	var yards := SurvivorsContent.yards()
	var yard := yards.by_id(descriptor.yard_id) if yards != null else null
	var reward := yard.reward_for_species(descriptor.species_id) \
		if yard != null else null
	return 0 if reward == null else reward.xp_reward


func _body_id(body: LooseLogBody) -> StringName:
	return &"" if body == null or body.descriptor == null else body.descriptor.id


func _arena_body_state(id: StringName) -> Dictionary:
	var arena_state: Variant = _runtime_state().get("arena", {})
	if not (arena_state is Dictionary):
		return {}
	var bodies: Variant = (arena_state as Dictionary).get("bodies", {})
	if not (bodies is Dictionary):
		return {}
	var raw: Variant = (bodies as Dictionary).get(String(id),
		(bodies as Dictionary).get(id, {}))
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func _arena_save_has_log_id(raw_arena: Variant, id: StringName) -> bool:
	if not (raw_arena is Dictionary):
		return false
	var raw_logs: Variant = (raw_arena as Dictionary).get("logs", [])
	if not (raw_logs is Array):
		return false
	for raw_log: Variant in raw_logs:
		if not (raw_log is Dictionary):
			continue
		var raw_descriptor: Variant = (raw_log as Dictionary).get(
			"descriptor", {})
		if raw_descriptor is Dictionary and StringName(
				(raw_descriptor as Dictionary).get("id", "")) == id:
			return true
	return false


func _boundary_mesh_width() -> float:
	if _arena == null:
		return 0.0
	var ring := _arena.get_node_or_null("RedBoundary") as MeshInstance3D
	return 0.0 if ring == null or ring.mesh == null else ring.mesh.get_aabb().size.x


func _horizontal_speed(velocity: Vector3) -> float:
	return Vector2(velocity.x, velocity.z).length()


func _outward_speed(position: Vector3, velocity: Vector3) -> float:
	var radial := Vector3(position.x, 0.0, position.z).normalized()
	return maxf(0.0, velocity.dot(radial))


func _has_power_burst(id: StringName) -> bool:
	return _power_burst_count(id) > 0


func _cut_receipt_total(receipts: Array) -> int:
	var total := 0
	for raw_receipt: Variant in receipts:
		if raw_receipt is Dictionary:
			var receipt := raw_receipt as Dictionary
			total += maxi(0, int(receipt.get("logs",
				receipt.get("cuts", 0))))
	return total


func _burst_presents_amount(burst: RunPowerBurst, amount: int) -> bool:
	if burst == null or amount <= 1:
		return false
	var label := burst.get_node_or_null("PowerName") as Label3D
	return label != null and label.text.contains("×%d" % amount)


## Structural and projection contract for the code-native periodic tool marks.
## A huge candidate proves the fit path is checking real mesh bounds instead of
## only the action anchor; the original presentation scale is always restored.
func _action_visual_contract(burst: RunPowerBurst,
		mesh_names: Array[StringName], uniform_fit: bool) -> bool:
	if burst == null or mesh_names.is_empty():
		return false
	var action_root := burst.get_node_or_null("ActionSilhouette") as Node3D
	var label := burst.get_node_or_null("PowerName") as Label3D
	var style := load(
		"res://data/painterly_vfx_style_placeholder.tres") as Resource
	var raw_registered: Variant = burst.get("_action_meshes")
	if action_root == null or label == null or style == null \
			or not (raw_registered is Array):
		return false
	var registered := raw_registered as Array
	if registered.size() != mesh_names.size() \
			or not label.no_depth_test or label.render_priority != 127:
		return false
	var expected_opacity := float(style.get("soft_opacity"))
	for mesh_name: StringName in mesh_names:
		var mesh_instance := action_root.get_node_or_null(
			String(mesh_name)) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null \
				or not registered.has(mesh_instance):
			return false
		var bounds := mesh_instance.mesh.get_aabb()
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 \
				or bounds.size.z <= 0.0:
			return false
		var primitive := mesh_instance.mesh as PrimitiveMesh
		var material := primitive.material as ShaderMaterial \
			if primitive != null else null
		if material == null \
				or not bool(material.get_shader_parameter("solid_geometry")) \
				or bool(material.get_shader_parameter("billboard_enabled")) \
				or int(material.get_shader_parameter("shape_mode")) != 1 \
				or not is_equal_approx(float(material.get_shader_parameter(
					"opacity")), expected_opacity):
			return false
	var viewport := burst.get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if viewport == null or camera == null:
		return false
	var visible_rect := viewport.get_visible_rect()
	var original_burst_position := burst.global_position
	var original_scale := action_root.scale
	var original_anchor_visible := not camera.is_position_behind(
		action_root.global_position) and visible_rect.has_point(
			camera.unproject_position(action_root.global_position))
	var original_fitted := float(burst.call(
		"_camera_fitted_action_scale", 1.0, uniform_fit))
	var original_guard_valid := original_fitted >= 0.0 \
		and original_fitted <= 1.0 \
		and (original_anchor_visible or is_zero_approx(original_fitted)) \
		and (original_fitted <= 0.0 or bool(burst.call(
			"_action_meshes_fit", camera, visible_rect,
			original_fitted, uniform_fit)))
	# These gameplay probes deliberately cover off-screen loose-root targets too.
	# Centre the same authored geometry briefly so the positive camera-fit branch
	# and all transformed mesh AABBs are verified without changing production.
	var camera_centre := camera.global_position \
		- camera.global_transform.basis.z.normalized() * 4.0
	burst.global_position += camera_centre - action_root.global_position
	var centred_fitted := float(burst.call(
		"_camera_fitted_action_scale", 1.0, uniform_fit))
	var fitted_bounds_visible := centred_fitted > 0.0 \
		and centred_fitted <= 1.0 \
		and bool(burst.call("_action_meshes_fit", camera, visible_rect,
			centred_fitted, uniform_fit))
	var oversized_bounds_rejected := not bool(burst.call(
		"_action_meshes_fit", camera, visible_rect, 100.0, uniform_fit))
	burst.global_position = original_burst_position
	action_root.scale = original_scale
	return original_guard_valid and fitted_bounds_visible \
		and oversized_bounds_rejected


func _power_burst_count(id: StringName) -> int:
	return _power_bursts(id).size()


func _latest_power_burst(id: StringName) -> RunPowerBurst:
	var bursts := _power_bursts(id)
	return null if bursts.is_empty() else bursts[-1]


func _power_burst_presenting_amount(id: StringName,
		amount: int) -> RunPowerBurst:
	for burst: RunPowerBurst in _power_bursts(id):
		if _burst_presents_amount(burst, amount):
			return burst
	return null


func _power_bursts(id: StringName) -> Array[RunPowerBurst]:
	var out: Array[RunPowerBurst] = []
	if _game == null:
		return out
	# Godot assigns an internal `@...` name when two same-power bursts coexist.
	# Identity is the typed node plus its authored power id, never that incidental
	# scene-tree name.
	for node: Node in _game.find_children("*", "", true, false):
		var burst := node as RunPowerBurst
		if burst != null and burst.power_id == id:
			out.append(burst)
	return out


func _runtime_state() -> Dictionary:
	if _run == null or not _run.has_method("get_run_power_runtime_state"):
		return {}
	return _run.call("get_run_power_runtime_state") as Dictionary


func _trigger_count(id: StringName) -> int:
	var counts: Variant = _runtime_state().get("trigger_counts", {})
	if not (counts is Dictionary):
		return 0
	return int((counts as Dictionary).get(String(id),
		(counts as Dictionary).get(id, 0)))


func _advance_power_time(seconds: float) -> void:
	if _run != null and _run.has_method("debug_advance_run_power_time"):
		_run.call("debug_advance_run_power_time", seconds)


func _wait_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _remove_save_files() -> void:
	var base := ProjectSettings.globalize_path(_SAVE_PATH)
	for suffix: String in ["", ".tmp", ".replacing"]:
		DirAccess.remove_absolute(base + suffix)


func _cleanup() -> void:
	if is_instance_valid(_main):
		# RunPowerBurst owns runtime-created ShaderMaterials and GPUParticles3D.
		# Detach renderer resources first, then free the production root
		# synchronously before the dummy renderer is finalized by headless shutdown.
		_release_production_renderer_resources(_main)
		_main.free()
	_main = null
	_run = null
	_game = null
	_arena = null
	_hud = null
	# The production burst classes intentionally keep prewarmed materials in
	# process-wide caches. A standalone acceptance process must release those
	# shared references explicitly before renderer shutdown.
	_release_primitive_mesh_materials(RunPowerBurst._mesh_cache.values())
	_release_material_values(RunPowerBurst._material_cache.values())
	_release_material_values(LevelUpBurst._material_cache.values())
	_release_material_values(CoinRewardPool._materials)
	_release_material_values(XPOrb._tier_materials)
	_release_material_values(XPOrb._halo_materials)
	RunPowerBurst._material_cache.clear()
	RunPowerBurst._mesh_cache.clear()
	LevelUpBurst._material_cache.clear()
	CoinRewardPool._meshes.clear()
	CoinRewardPool._materials.clear()
	XPOrb._tier_meshes.clear()
	XPOrb._tier_materials.clear()
	XPOrb._halo_mesh = null
	XPOrb._halo_materials.clear()
	SurvivorsContent.clear_cache()
	_remove_save_files()
	SaveSystem.reset_save_path_after_tests()
	# Renderer resource retirement is deferred. Give both the scene tree and the
	# rendering server several frames after dropping the last owned references.
	await _wait_frames(4)


func _release_production_renderer_resources(root: Node) -> void:
	for raw_particles: Node in root.find_children(
			"*", "GPUParticles3D", true, false):
		var particles := raw_particles as GPUParticles3D
		_release_material(particles.process_material as Material)
		particles.process_material = null
		for pass_index: int in range(particles.draw_passes):
			var draw_mesh := particles.get_draw_pass_mesh(pass_index)
			_release_mesh(draw_mesh)
			particles.set_draw_pass_mesh(pass_index, null)
	for raw_mesh: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		_release_material(mesh_instance.material_override)
		_release_material(mesh_instance.material_overlay)
		_release_mesh(mesh_instance.mesh)
		mesh_instance.material_override = null
		mesh_instance.material_overlay = null
		mesh_instance.mesh = null
	for raw_multi_mesh: Node in root.find_children(
			"*", "MultiMeshInstance3D", true, false):
		var multi_mesh := raw_multi_mesh as MultiMeshInstance3D
		_release_material(multi_mesh.material_override)
		_release_material(multi_mesh.material_overlay)
		multi_mesh.material_override = null
		multi_mesh.material_overlay = null
		multi_mesh.multimesh = null
	for raw_canvas: Node in root.find_children("*", "CanvasItem", true, false):
		var canvas := raw_canvas as CanvasItem
		_release_material(canvas.material)
		canvas.material = null
	for raw_environment: Node in root.find_children(
			"*", "WorldEnvironment", true, false):
		(raw_environment as WorldEnvironment).environment = null


func _release_mesh(mesh: Mesh) -> void:
	if mesh == null:
		return
	if mesh is PrimitiveMesh:
		var primitive := mesh as PrimitiveMesh
		_release_material(primitive.material)
		primitive.material = null
		return
	for surface_index: int in range(mesh.get_surface_count()):
		_release_material(mesh.surface_get_material(surface_index))
		mesh.surface_set_material(surface_index, null)


func _release_material_values(values: Array) -> void:
	for raw_value: Variant in values:
		_release_material(raw_value as Material)


func _release_primitive_mesh_materials(values: Array) -> void:
	for raw_value: Variant in values:
		var mesh := raw_value as PrimitiveMesh
		if mesh != null:
			mesh.material = null


func _release_material(material: Material) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).shader = null


func _on_watchdog() -> void:
	if _completed:
		return
	push_error("FAIL: all-power runtime scenario timed out")
	await _cleanup()
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
