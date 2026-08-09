class_name M7CContent
extends RefCounted
## Stateless access and validation for M7C's immutable authored data. It owns no
## progression and is deliberately not an autoload. Validators return errors so
## acceptance can prove every rejection without parsing editor log text.

const BRANCH_TABLE_PATH := "res://data/skill_branch_table.tres"
const PROC_TABLE_PATH := "res://data/proc_table.tres"
const MASTERY_TABLE_PATH := "res://data/species_mastery_table.tres"
const EQUIPMENT_TABLE_PATH := "res://data/equipment_table.tres"

static var _branches: SkillBranchTable
static var _procs: ProcTable
static var _mastery: SpeciesMasteryTable
static var _equipment: EquipmentTable


static func branches() -> SkillBranchTable:
	if _branches == null:
		_branches = load(BRANCH_TABLE_PATH) as SkillBranchTable
	return _branches


static func procs() -> ProcTable:
	if _procs == null:
		_procs = load(PROC_TABLE_PATH) as ProcTable
	return _procs


static func mastery() -> SpeciesMasteryTable:
	if _mastery == null:
		_mastery = load(MASTERY_TABLE_PATH) as SpeciesMasteryTable
	return _mastery


static func equipment() -> EquipmentTable:
	if _equipment == null:
		_equipment = load(EQUIPMENT_TABLE_PATH) as EquipmentTable
	return _equipment


static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	if branches() == null:
		errors.append("branch table failed to load")
	if procs() == null:
		errors.append("proc table failed to load")
	if mastery() == null:
		errors.append("mastery table failed to load")
	if equipment() == null:
		errors.append("equipment table failed to load")
	if not errors.is_empty():
		return errors
	errors.append_array(validate_branches(branches()))
	errors.append_array(validate_procs(procs()))
	errors.append_array(validate_skill_tree(_live_skill_table(), branches(), procs()))
	errors.append_array(validate_mastery(mastery()))
	errors.append_array(validate_equipment(equipment()))
	return errors


static func validate_branches(table: SkillBranchTable) -> PackedStringArray:
	var errors := PackedStringArray()
	if table == null:
		errors.append("branch table is null")
		return errors
	var seen: Dictionary = {}
	for branch: SkillBranchDef in table.branches:
		if branch == null:
			errors.append("branch table contains null")
			continue
		if branch.id == &"":
			errors.append("branch has empty id")
		elif seen.has(branch.id):
			errors.append("duplicate branch id:%s" % branch.id)
		seen[branch.id] = true
		if branch.display_name.is_empty():
			errors.append("branch %s has empty display name" % branch.id)
		if branch.layout_slots.is_empty():
			errors.append("branch %s has no layout slots" % branch.id)
		var slots: Dictionary = {}
		for slot: Vector2i in branch.layout_slots:
			if slots.has(slot):
				errors.append("branch %s has duplicate layout slot:%s" % [branch.id, slot])
			slots[slot] = true
	return errors


static func validate_skill_tree(table: SkillTreeTable, branch_table: SkillBranchTable,
		proc_table: ProcTable) -> PackedStringArray:
	var errors := PackedStringArray()
	if table == null:
		errors.append("skill tree is null")
		return errors
	var seen: Dictionary = {}
	var occupied_layout: Dictionary = {}
	# M7C Slice 7: tracks which procs are actually reachable through the tree.
	# Its absence is exactly how `follow_up` sat dead in shipped proc_table.tres
	# data since 2026-08-04 — a fully authored, valid ProcDef that no node
	# named, so it could never be bought and could never fire.
	var owned_procs: Dictionary = {}
	for node: SkillNodeDef in table.nodes:
		if node == null:
			errors.append("skill tree contains null")
			continue
		if node.id == &"":
			errors.append("skill has empty id")
		elif seen.has(node.id):
			errors.append("duplicate skill id:%s" % node.id)
		seen[node.id] = true
		if node.max_level <= 0:
			errors.append("skill %s has invalid cap" % node.id)
		if node.cost <= 0:
			errors.append("skill %s has invalid cost" % node.id)
		if node.node_type < SkillNodeDef.NodeType.FOUNDATION or node.node_type > SkillNodeDef.NodeType.CAPSTONE:
			errors.append("skill %s has illegal node type" % node.id)
		var branch := branch_table.by_id(node.branch_id) if branch_table != null else null
		if branch == null:
			errors.append("skill %s has unknown branch:%s" % [node.id, node.branch_id])
		elif not branch.layout_slots.has(node.presentation_position):
			errors.append("skill %s has impossible layout:%s" % [node.id, node.presentation_position])
		else:
			var layout_key := "%s:%s" % [node.branch_id, node.presentation_position]
			if occupied_layout.has(layout_key):
				errors.append("skill %s collides at layout:%s" % [node.id, node.presentation_position])
			occupied_layout[layout_key] = true
		if node.node_type == SkillNodeDef.NodeType.PROC:
			if node.proc_id == &"" or proc_table == null or proc_table.by_id(node.proc_id) == null:
				errors.append("skill %s has unknown proc:%s" % [node.id, node.proc_id])
			else:
				owned_procs[node.proc_id] = true
		elif node.proc_id != &"":
			errors.append("non-proc skill %s names proc:%s" % [node.id, node.proc_id])
		for modifier: GameplayModifierDef in node.modifiers:
			if modifier != null and modifier.kind == GameplayModifierDef.Kind.GRAIN_CUE:
				# grain_read is deliberately NOT owned through a node's proc_id
				# the way every other proc is — the 2026-08-04 grain-mark
				# rework gates it behind an ENABLE-kind GRAIN_CUE modifier on
				# whichever node grants the capability (quick_study today; see
				# chopping_minigame.gd's grain-opportunity section). This is
				# the one documented exception to "a node names its proc".
				owned_procs[&"grain_read"] = true
		errors.append_array(_validate_modifiers(node.modifiers, "skill %s" % node.id))
		errors.append_array(_validate_modifiers(node.effects, "skill effects %s" % node.id))

	for node: SkillNodeDef in table.nodes:
		if node == null:
			continue
		for requirement: StringName in node.requires:
			if not seen.has(requirement):
				errors.append("skill %s has dangling prerequisite:%s" % [node.id, requirement])
			elif requirement == node.id:
				errors.append("skill %s requires itself" % node.id)

	var visit_state: Dictionary = {}
	for node: SkillNodeDef in table.nodes:
		if node != null:
			_visit_skill(table, node.id, visit_state, [], errors)

	# Every authored proc must be reachable through the tree. A proc with no
	# owning node can never be bought and can never fire — dead data that
	# validate_procs() alone cannot catch, since a ProcDef is fully valid on
	# its own terms regardless of whether any skill points at it.
	if proc_table != null:
		for proc: ProcDef in proc_table.procs:
			if proc != null and proc.id != &"" and not owned_procs.has(proc.id) \
					and not _shop_owns_proc(proc.id):
				errors.append("proc %s is not owned by any skill tree node" % proc.id)
	return errors


static func validate_procs(table: ProcTable) -> PackedStringArray:
	var errors := PackedStringArray()
	if table == null:
		errors.append("proc table is null")
		return errors
	var seen: Dictionary = {}
	for proc: ProcDef in table.procs:
		if proc == null:
			errors.append("proc table contains null")
			continue
		if proc.id == &"":
			errors.append("proc has empty id")
		elif seen.has(proc.id):
			errors.append("duplicate proc id:%s" % proc.id)
		seen[proc.id] = true
		if proc.family < ProcDef.Family.DOUBLE_STRIKE or proc.family > ProcDef.Family.EXPRESS_HANDOFF:
			errors.append("proc %s has illegal family" % proc.id)
		if proc.eligibility < ProcDef.Eligibility.MANUAL_SWING or proc.eligibility > ProcDef.Eligibility.MANUAL_PIECE_OFFER:
			errors.append("proc %s has illegal eligibility" % proc.id)
		if proc.base_chance < 0.0 or proc.base_chance > 1.0 or is_nan(proc.base_chance) or is_inf(proc.base_chance):
			errors.append("proc %s has invalid chance" % proc.id)
		if proc.chance_per_rank < 0.0 or proc.chance_per_rank > 1.0 \
				or is_nan(proc.chance_per_rank) or is_inf(proc.chance_per_rank):
			errors.append("proc %s has invalid rank chance" % proc.id)
		if proc.chain_cap <= 0:
			errors.append("proc %s has invalid chain cap" % proc.id)
		if proc.bad_luck_bound <= 0 or proc.bad_luck_policy_key == &"":
			errors.append("proc %s has invalid bad-luck policy" % proc.id)
		if proc.announcement_key == &"":
			errors.append("proc %s has no announcement key" % proc.id)
		if proc.presentation_branch_id == &"" or branches() == null \
				or branches().by_id(proc.presentation_branch_id) == null:
			errors.append("proc %s has no valid presentation branch" % proc.id)
		if proc.tuning_status.is_empty():
			errors.append("proc %s is missing tuning status" % proc.id)
		errors.append_array(_validate_modifiers(proc.modifiers, "proc %s" % proc.id))
		if (proc.family == ProcDef.Family.QUICK_STUDY or proc.family == ProcDef.Family.GRAIN_READ) \
				and not _has_manual_xp_multiplier(proc):
			errors.append("proc %s has no valid manual XP multiplier" % proc.id)
	return errors


static func _shop_owns_proc(proc_id: StringName) -> bool:
	for upgrade: UpgradeDef in Shop.get_upgrades():
		if upgrade == null:
			continue
		for contribution: UpgradeProcContributionDef in upgrade.proc_contributions:
			if contribution != null and contribution.proc_id == proc_id:
				return true
	return false


static func _has_manual_xp_multiplier(proc: ProcDef) -> bool:
	for modifier: GameplayModifierDef in proc.modifiers:
		if modifier != null \
				and modifier.kind == GameplayModifierDef.Kind.MANUAL_XP \
				and modifier.operation == GameplayModifierDef.Operation.MULTIPLY \
				and modifier.magnitude > 1.0:
			return true
	return false


static func validate_mastery(table: SpeciesMasteryTable) -> PackedStringArray:
	var errors := PackedStringArray()
	if table == null:
		errors.append("mastery table is null")
		return errors
	var previous_threshold := 0
	for threshold: SpeciesMasteryThresholdDef in table.thresholds:
		if threshold == null:
			errors.append("mastery table contains null threshold")
			continue
		if threshold.required_progress <= previous_threshold:
			errors.append("mastery table has invalid threshold:%d" % threshold.required_progress)
		previous_threshold = threshold.required_progress
		if threshold.tuning_status.is_empty():
			errors.append("mastery threshold %d is missing tuning status" % threshold.required_progress)
		var reward_kinds: Dictionary = {}
		for modifier: GameplayModifierDef in threshold.rewards:
			if modifier == null:
				continue
			if reward_kinds.has(modifier.kind):
				errors.append("mastery threshold %d has duplicate reward kind:%d" % [
					threshold.required_progress, modifier.kind])
			reward_kinds[modifier.kind] = true
			if modifier.kind not in [GameplayModifierDef.Kind.CASH_GAIN,
					GameplayModifierDef.Kind.MANUAL_XP,
					GameplayModifierDef.Kind.SPLIT_RELIABILITY]:
				errors.append("mastery threshold %d has unsupported reward kind:%d" % [
					threshold.required_progress, modifier.kind])
			if modifier.operation != GameplayModifierDef.Operation.ADD or modifier.magnitude <= 0.0:
				errors.append("mastery threshold %d has invalid additive reward:%s" % [
					threshold.required_progress, modifier.id])
		errors.append_array(_validate_modifiers(threshold.rewards,
			"mastery threshold %d" % threshold.required_progress))
		for required_kind: int in [GameplayModifierDef.Kind.CASH_GAIN,
				GameplayModifierDef.Kind.MANUAL_XP,
				GameplayModifierDef.Kind.SPLIT_RELIABILITY]:
			if not reward_kinds.has(required_kind):
				errors.append("mastery threshold %d is missing reward kind:%d" % [
					threshold.required_progress, required_kind])
	if table.thresholds.is_empty():
		errors.append("mastery table has no reward thresholds")
	var seen: Dictionary = {}
	for definition: SpeciesMasteryDef in table.definitions:
		if definition == null:
			errors.append("mastery table contains null")
			continue
		if seen.has(definition.species_id):
			errors.append("duplicate mastery species:%s" % definition.species_id)
		seen[definition.species_id] = true
		if SpeciesTable.by_id(definition.species_id) == null:
			errors.append("mastery references unknown species:%s" % definition.species_id)
		if definition.mastery_target <= 0 or definition.manual_completion_award <= 0:
			errors.append("mastery %s has invalid target/award" % definition.species_id)
		var scaled_thresholds := table.thresholds_for_species(definition.species_id)
		if scaled_thresholds.size() != table.thresholds.size() \
				or scaled_thresholds.is_empty() \
				or scaled_thresholds.back().required_progress != definition.mastery_target:
			errors.append("mastery %s lacks a scaled final threshold" % definition.species_id)
		for requirement: CertificationRequirementDef in definition.certification_requirements:
			if requirement == null:
				errors.append("mastery %s has null certification requirement" % definition.species_id)
				continue
			if requirement.kind < CertificationRequirementDef.Kind.MANUAL_LOGS or requirement.kind > CertificationRequirementDef.Kind.GRAIN_READS:
				errors.append("mastery %s has illegal certification requirement" % definition.species_id)
			if requirement.required_count <= 0:
				errors.append("mastery %s has invalid certification count" % definition.species_id)
			elif requirement.kind == CertificationRequirementDef.Kind.MANUAL_LOGS \
					and not requirement.use_mastery_target \
					and requirement.required_count != definition.mastery_target:
				errors.append("mastery %s manual certification count does not match target" \
					% definition.species_id)
		if definition.tuning_status.is_empty():
			errors.append("mastery %s is missing tuning status" % definition.species_id)
	for species: SpeciesDef in SpeciesTable.all():
		if species != null and not seen.has(species.id):
			errors.append("mastery missing live species:%s" % species.id)
	return errors


static func validate_equipment(table: EquipmentTable) -> PackedStringArray:
	var errors := PackedStringArray()
	if table == null:
		errors.append("equipment table is null")
		return errors
	var seen: Dictionary = {}
	var fallbacks := {EquipmentDef.Slot.AXE: 0, EquipmentDef.Slot.WORKSTATION: 0}
	for definition: EquipmentDef in table.equipment:
		if definition == null:
			errors.append("equipment table contains null")
			continue
		if definition.id == &"":
			errors.append("equipment has empty id")
		elif seen.has(definition.id):
			errors.append("duplicate equipment id:%s" % definition.id)
		seen[definition.id] = true
		if definition.slot < EquipmentDef.Slot.AXE or definition.slot > EquipmentDef.Slot.WORKSTATION:
			errors.append("equipment %s has illegal slot" % definition.id)
		elif definition.is_starting_fallback:
			fallbacks[definition.slot] = int(fallbacks[definition.slot]) + 1
		if definition.ownership_upgrade_id != &"" and Shop.get_upgrade(definition.ownership_upgrade_id) == null:
			errors.append("equipment %s has unknown ownership upgrade:%s" % [definition.id, definition.ownership_upgrade_id])
		if definition.comparison_tags.is_empty() and definition.progression_stage <= 0:
			errors.append("equipment %s has no comparison tags" % definition.id)
		if definition.tuning_status.is_empty():
			errors.append("equipment %s is missing tuning status" % definition.id)
		errors.append_array(_validate_modifiers(definition.modifiers, "equipment %s" % definition.id))
	for slot: int in fallbacks:
		if int(fallbacks[slot]) != 1:
			errors.append("equipment slot %d has %d starting fallbacks" % [slot, fallbacks[slot]])
	return errors


static func _validate_modifiers(modifiers: Array[GameplayModifierDef], owner: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for modifier: GameplayModifierDef in modifiers:
		if modifier == null:
			errors.append("%s has null modifier" % owner)
			continue
		if modifier.id == &"":
			errors.append("%s has modifier with empty id" % owner)
		elif seen.has(modifier.id):
			errors.append("%s has duplicate modifier:%s" % [owner, modifier.id])
		seen[modifier.id] = true
		if modifier.kind < GameplayModifierDef.Kind.SPLIT_RELIABILITY \
				or modifier.kind > GameplayModifierDef.Kind.FRONTIER_LOGISTICS:
			errors.append("%s has modifier with illegal kind" % owner)
		if modifier.operation < GameplayModifierDef.Operation.ADD or modifier.operation > GameplayModifierDef.Operation.ENABLE:
			errors.append("%s has modifier with illegal operation" % owner)
		if is_nan(modifier.magnitude) or is_inf(modifier.magnitude):
			errors.append("%s has modifier with non-finite magnitude" % owner)
		if modifier.tuning_status.is_empty():
			errors.append("%s has modifier missing tuning status" % owner)
	return errors


static func _visit_skill(table: SkillTreeTable, id: StringName, state: Dictionary,
		path: Array[StringName], errors: PackedStringArray) -> void:
	var mark := int(state.get(id, 0))
	if mark == 2:
		return
	if mark == 1:
		errors.append("skill prerequisite cycle:%s" % id)
		return
	state[id] = 1
	var node := table.get_node_def(id)
	if node != null:
		var next := path.duplicate()
		next.append(id)
		for requirement: StringName in node.requires:
			if table.get_node_def(requirement) != null:
				_visit_skill(table, requirement, state, next, errors)
	state[id] = 2


static func _live_skill_table() -> SkillTreeTable:
	return load("res://data/skill_tree.tres") as SkillTreeTable
