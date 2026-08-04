extends Node
## FILE: res://core/tests/m7c_acceptance.gd
## ATTACHES TO: res://core/tests/m7c_acceptance.tscn. Not shipped.
##
## M7C grows slice by slice. Current groups cover save-v2 skill migration and
## typed content schemas/validators; no proc or mastery gameplay exists yet.

const _FIXTURES := "res://core/tests/fixtures/"
const _BACKUP_PATH := "user://the_axeman_save.m7c_testbackup"

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M7C ACCEPTANCE — migration and typed content ===")
	_stash_real_save()
	_test_all_mappings_and_exact_refunds()
	_test_duplicates_caps_and_corrupt_ranks()
	_test_partial_fixture_and_idempotence()
	_test_load_save_reload_and_source_preservation()
	_test_typed_live_catalogues_validate()
	_test_skill_validator_rejects_bad_graphs()
	_test_content_validators_reject_bad_rows()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M7C RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M7C ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _fixture_progression(name: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(_FIXTURES + name)
	_check(err == OK, "hand-authored fixture %s parses" % name)
	var data: Variant = cfg.get_value("progression", "data", {})
	return data as Dictionary if data is Dictionary else {}


func _test_all_mappings_and_exact_refunds() -> void:
	var migrated := SaveSystem._migrate(
		_fixture_progression("m7c_v1_all_skill_mappings.cfg"), 1)
	var skills: Dictionary = migrated.get("skill_levels", {})
	var legacy: Dictionary = migrated.get("legacy_skill_ranks", {})
	_check(skills.get("strong_arms", 0) == 3, "Strong Arms retains all 3 valid ranks")
	_check(skills.get("quick_hands", 0) == 4, "Quick Hands retains all 4 valid ranks")
	_check(skills.get("ready_stance", 0) == 2 and not skills.has("keen_edge"),
		"Keen Edge renames to Ready Stance without leaving its old id")
	_check(skills.get("quick_study", 0) == 2 and not skills.has("woodsman"),
		"Woodsman renames to Quick Study without leaving its old id")
	_check(not skills.has("splitter"), "Splitter is retired, never converted to Double Strike")
	_check(not skills.has("double_strike"), "migration does not silently award Double Strike")
	_check(not skills.has("master_axeman") and not skills.has("negotiator"),
		"Master Axeman and Negotiator are both absent from version 2")
	_check(legacy == {"strong_arms": 3, "quick_hands": 4, "ready_stance": 2, "quick_study": 2},
		"retained ranks carry their exact prototype-cost basis")

	GameState.apply_save_dict(migrated)
	_check(GameState.get_skill_points_spent() == 17,
		"retained ranks spend exactly 17 prototype points")
	_check(GameState.get_skill_points_available() == 81,
		"the removed 16-point spend is refunded through the derived balance (81 available)")


func _test_duplicates_caps_and_corrupt_ranks() -> void:
	var migrated := SaveSystem._migrate(
		_fixture_progression("m7c_v1_duplicate_caps_corrupt.cfg"), 1)
	var skills: Dictionary = migrated.get("skill_levels", {})
	_check(skills.get("ready_stance", 0) == 5,
		"old/new Ready Stance ids keep the greater rank and clamp to cap 5")
	_check(skills.get("quick_study", 0) == 4,
		"old/new Quick Study ids keep the greater rank, never add to 6")
	_check(not skills.has("strong_arms"), "a non-numeric retained rank is dropped safely")
	_check(not skills.has("splitter") and not skills.has("negotiator"),
		"negative retired/corrupt ranks cannot survive migration")


func _test_partial_fixture_and_idempotence() -> void:
	var original := _fixture_progression("m7c_v1_partial.cfg")
	var migrated := SaveSystem._migrate(original, 1)
	_check(migrated.get("cash", 0) == 73, "unrelated progression survives migration unchanged")
	_check((migrated.get("skill_levels", {}) as Dictionary).get("ready_stance", 0) == 1,
		"a partial skill dictionary migrates its one known rank")
	var twice := SaveSystem._migrate(migrated.duplicate(true), 2)
	_check(twice == migrated, "a version-2 dictionary is byte-shape idempotent")
	var malformed := SaveSystem._migrate({"skill_levels": ["not", "a", "dictionary"]}, 1)
	_check(malformed.get("skill_levels", null) == {}, "a malformed skill field degrades to an empty tree")


func _test_load_save_reload_and_source_preservation() -> void:
	SaveSystem.delete_save()
	var fixture := ConfigFile.new()
	_check(fixture.load(_FIXTURES + "m7c_v1_all_skill_mappings.cfg") == OK,
		"round-trip fixture opens")
	_check(fixture.save(SaveSystem.SAVE_PATH) == OK, "version-1 fixture is installed as the live test save")

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "a version-1 file loads through migration")
	_check(GameState.get_skill_level(&"ready_stance") == 2
		and GameState.get_skill_level(&"quick_study") == 2,
		"renamed ranks are live after the complete state validates")
	var untouched := ConfigFile.new()
	untouched.load(SaveSystem.SAVE_PATH)
	_check(int(untouched.get_value("meta", "version", -1)) == 1,
		"loading leaves the original version-1 file untouched")

	_check(SaveSystem.save_game(), "the next atomic save succeeds")
	var upgraded := ConfigFile.new()
	upgraded.load(SaveSystem.SAVE_PATH)
	_check(int(upgraded.get_value("meta", "version", -1)) == 2,
		"only that successful save replaces it with version 2")
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "the version-2 save reloads")
	_check(GameState.get_skill_level(&"ready_stance") == 2
		and GameState.get_skill_level(&"quick_study") == 2,
		"renamed ranks survive load-save-reload")
	_check(GameState.get_skill_points_spent() == 17,
		"prototype cost basis survives load-save-reload exactly")


func _test_typed_live_catalogues_validate() -> void:
	var branches := M7CContent.branches()
	var procs := M7CContent.procs()
	var mastery := M7CContent.mastery()
	var equipment := M7CContent.equipment()
	_check(branches != null and branches.branches.size() == 3,
		"the live catalogue has exactly the approved three typed branches")
	_check(procs != null and procs.procs.size() == 3
		and procs.by_id(&"double_strike") != null
		and procs.by_id(&"follow_up") != null
		and procs.by_id(&"quick_study") != null,
		"Double Strike, Follow-Up and Quick Study are typed proc families")
	_check(mastery != null and mastery.definitions.size() == SpeciesTable.count(),
		"every live species has one mastery-schema row (%d)" % SpeciesTable.count())
	_check(equipment != null and equipment.equipment.size() == 6,
		"starting/M7A gear plus Maul and Log Cradle have typed equipment rows")
	_check(equipment.starting_for_slot(EquipmentDef.Slot.AXE).id == &"basic_axe"
		and equipment.starting_for_slot(EquipmentDef.Slot.WORKSTATION).id == &"basic_chopping_block",
		"both loadout slots have explicit safe starting fallbacks")
	var errors := M7CContent.validate_all()
	_check(errors.is_empty(), "all shipping M7C resources validate (%s)" % str(errors))
	var quick_study := SkillTree.get_node_def(&"quick_study")
	_check(quick_study != null
		and quick_study.branch_id == &"technique"
		and quick_study.node_type == SkillNodeDef.NodeType.PROC
		and quick_study.proc_id == &"quick_study",
		"skill meaning comes from typed branch/node/proc fields, not display copy")


func _test_skill_validator_rejects_bad_graphs() -> void:
	var branches := M7CContent.branches()
	var procs := M7CContent.procs()

	var duplicate := SkillTreeTable.new()
	var duplicate_node := _test_skill(&"same")
	duplicate.nodes = [duplicate_node, duplicate_node]
	_check(_has_error(M7CContent.validate_skill_tree(duplicate, branches, procs), "duplicate skill id"),
		"tree validation rejects duplicate ids")

	var dangling := SkillTreeTable.new()
	var dangling_node := _test_skill(&"dangling")
	dangling_node.requires = [&"missing"]
	dangling.nodes = [dangling_node]
	_check(_has_error(M7CContent.validate_skill_tree(dangling, branches, procs), "dangling prerequisite"),
		"tree validation rejects dangling prerequisites")

	var cycle := SkillTreeTable.new()
	var cycle_a := _test_skill(&"cycle_a")
	var cycle_b := _test_skill(&"cycle_b")
	cycle_a.requires = [&"cycle_b"]
	cycle_b.requires = [&"cycle_a"]
	cycle.nodes = [cycle_a, cycle_b]
	_check(_has_error(M7CContent.validate_skill_tree(cycle, branches, procs), "prerequisite cycle"),
		"tree validation rejects cycles")

	var illegal := SkillTreeTable.new()
	var illegal_node := _test_skill(&"illegal")
	illegal_node.node_type = 99
	illegal_node.max_level = 0
	illegal_node.cost = 0
	illegal_node.branch_id = &"unknown_branch"
	illegal_node.presentation_position = Vector2i(99, 99)
	illegal.nodes = [illegal_node]
	var illegal_errors := M7CContent.validate_skill_tree(illegal, branches, procs)
	_check(_has_error(illegal_errors, "illegal node type"), "tree validation rejects illegal node types")
	_check(_has_error(illegal_errors, "unknown branch"), "tree validation rejects unknown branches")
	_check(_has_error(illegal_errors, "invalid cap") and _has_error(illegal_errors, "invalid cost"),
		"tree validation rejects invalid caps and costs")

	var layout := SkillTreeTable.new()
	var layout_node := _test_skill(&"off_bough")
	layout_node.presentation_position = Vector2i(99, 99)
	layout.nodes = [layout_node]
	_check(_has_error(M7CContent.validate_skill_tree(layout, branches, procs), "impossible layout"),
		"tree validation rejects impossible bough layout references")


func _test_content_validators_reject_bad_rows() -> void:
	var branch_table := SkillBranchTable.new()
	var bad_branch := SkillBranchDef.new()
	bad_branch.id = &"duplicate_branch"
	bad_branch.layout_slots = [Vector2i.ZERO, Vector2i.ZERO]
	branch_table.branches = [bad_branch, bad_branch]
	var branch_errors := M7CContent.validate_branches(branch_table)
	_check(_has_error(branch_errors, "duplicate branch id")
		and _has_error(branch_errors, "empty display name")
		and _has_error(branch_errors, "duplicate layout slot"),
		"branch validation rejects duplicate ids, missing copy and duplicate slots")

	var proc_table := ProcTable.new()
	var bad_proc := ProcDef.new()
	bad_proc.id = &"bad_proc"
	bad_proc.display_name = "Bad Proc"
	bad_proc.announcement_key = &""
	bad_proc.base_chance = 2.0
	bad_proc.chain_cap = 0
	bad_proc.bad_luck_bound = 0
	proc_table.procs = [bad_proc, bad_proc]
	var proc_errors := M7CContent.validate_procs(proc_table)
	_check(_has_error(proc_errors, "duplicate proc id")
		and _has_error(proc_errors, "invalid chance")
		and _has_error(proc_errors, "invalid chain cap")
		and _has_error(proc_errors, "invalid bad-luck policy")
		and _has_error(proc_errors, "no announcement key"),
		"proc validation rejects duplicate and unsafe resolver data")

	var mastery_table := SpeciesMasteryTable.new()
	var bad_mastery := SpeciesMasteryDef.new()
	bad_mastery.species_id = &"invented_wood"
	bad_mastery.mastery_target = 2
	bad_mastery.manual_completion_award = 0
	bad_mastery.reveal_thresholds = PackedInt32Array([2, 1, 9])
	var bad_requirement := CertificationRequirementDef.new()
	bad_requirement.kind = 99
	bad_requirement.required_count = 0
	var bad_requirements: Array[CertificationRequirementDef] = [bad_requirement]
	bad_mastery.certification_requirements = bad_requirements
	mastery_table.definitions = [bad_mastery, bad_mastery]
	var mastery_errors := M7CContent.validate_mastery(mastery_table)
	_check(_has_error(mastery_errors, "duplicate mastery species")
		and _has_error(mastery_errors, "unknown species")
		and _has_error(mastery_errors, "invalid target/award")
		and _has_error(mastery_errors, "invalid reveal threshold")
		and _has_error(mastery_errors, "illegal certification requirement"),
		"mastery validation rejects duplicate, unknown, unordered and illegal requirements")

	var equipment_table := EquipmentTable.new()
	var bad_equipment := EquipmentDef.new()
	bad_equipment.id = &"bad_equipment"
	bad_equipment.slot = 99
	bad_equipment.ownership_upgrade_id = &"invented_purchase"
	var bad_modifier := GameplayModifierDef.new()
	bad_modifier.kind = 99
	bad_modifier.operation = 99
	bad_modifier.magnitude = NAN
	bad_modifier.tuning_status = ""
	var bad_modifiers: Array[GameplayModifierDef] = [bad_modifier]
	bad_equipment.modifiers = bad_modifiers
	equipment_table.equipment = [bad_equipment, bad_equipment]
	var equipment_errors := M7CContent.validate_equipment(equipment_table)
	_check(_has_error(equipment_errors, "duplicate equipment id")
		and _has_error(equipment_errors, "illegal slot")
		and _has_error(equipment_errors, "unknown ownership upgrade")
		and _has_error(equipment_errors, "no comparison tags")
		and _has_error(equipment_errors, "starting fallbacks")
		and _has_error(equipment_errors, "modifier with illegal kind")
		and _has_error(equipment_errors, "modifier with illegal operation")
		and _has_error(equipment_errors, "non-finite magnitude"),
		"equipment/modifier validation rejects duplicate, unknown, uncomparable and unsafe rows")


func _test_skill(id: StringName) -> SkillNodeDef:
	var node := SkillNodeDef.new()
	node.id = id
	node.display_name = String(id)
	node.description = "test"
	node.branch_id = &"strength"
	node.node_type = SkillNodeDef.NodeType.FOUNDATION
	node.presentation_position = Vector2i.ZERO
	node.max_level = 1
	node.cost = 1
	return node


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false


func _stash_real_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(_BACKUP_PATH):
		dir.remove(_BACKUP_PATH)
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP_PATH)


func _restore_real_save() -> void:
	SaveSystem.delete_save()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(_BACKUP_PATH):
		dir.rename(_BACKUP_PATH, SaveSystem.SAVE_PATH)
