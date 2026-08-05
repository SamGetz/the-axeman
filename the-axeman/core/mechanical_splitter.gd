class_name MechanicalSplitter
extends RefCounted
## Read-only Mechanical Splitter service over the shop catalogue and
## GameState-owned building tiers. Slice 4's watched Node runtime consumes these
## admission contracts; this stateless service still owns no timers or writes.


static func machine_definition() -> UpgradeDef:
	for definition: UpgradeDef in Shop.get_upgrades():
		if definition != null \
				and definition.automation_role == UpgradeDef.AutomationRole.MECHANICAL_SPLITTER:
			return definition
	return null


static func profile_definitions() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for definition: UpgradeDef in Shop.get_upgrades():
		if definition != null \
				and definition.automation_role == UpgradeDef.AutomationRole.CUTTING_PROFILE:
			out.append(definition)
	return out


static func upgrade_definitions() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for definition: UpgradeDef in Shop.get_upgrades():
		if definition != null \
				and definition.automation_role == UpgradeDef.AutomationRole.SPLITTER_UPGRADE:
			out.append(definition)
	return out


static func upgrade_definition(kind: UpgradeDef.Effect) -> UpgradeDef:
	for definition: UpgradeDef in upgrade_definitions():
		if definition.effect == kind:
			return definition
	return null


static func profile_for_species(species_id: StringName) -> UpgradeDef:
	for profile: UpgradeDef in profile_definitions():
		if profile.automation_species_id == species_id:
			return profile
	return null


static func is_installed() -> bool:
	var machine := machine_definition()
	return machine != null and Shop.get_level(machine.id) > 0


static func has_installed_profile(species_id: StringName) -> bool:
	var profile := profile_for_species(species_id)
	return is_installed() and profile != null and Shop.get_level(profile.id) > 0


## The future runtime's single admission rule. Current certification and a paid,
## installed profile are both required, so loading stale/crafted ownership can
## never let automation discover or certify a species for the player.
static func can_accept_species(species_id: StringName) -> bool:
	return GameState.is_species_mastered(species_id) \
		and has_installed_profile(species_id)


static func validate_live_catalogue() -> PackedStringArray:
	return validate_catalogue(Shop.get_upgrades())


## Semantic validation keeps a data-only shop edit from creating a dead profile,
## a profile for an unknown wood, duplicate/missing splitter upgrade identities,
## or an effect that leaks outside the watched machine progression.
static func validate_catalogue(upgrades: Array[UpgradeDef]) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	var indices: Dictionary = {}
	var machine: UpgradeDef = null
	var profiles: Array[UpgradeDef] = []
	var splitter_upgrades: Array[UpgradeDef] = []

	for index in range(upgrades.size()):
		var definition: UpgradeDef = upgrades[index]
		if definition == null:
			continue
		if definition.id == &"":
			errors.append("upgrade has empty id")
		elif ids.has(definition.id):
			errors.append("duplicate upgrade id:%s" % definition.id)
		else:
			ids[definition.id] = definition
			indices[definition.id] = index

		match definition.automation_role:
			UpgradeDef.AutomationRole.MECHANICAL_SPLITTER:
				if machine != null:
					errors.append("multiple Mechanical Splitter purchases")
				else:
					machine = definition
			UpgradeDef.AutomationRole.CUTTING_PROFILE:
				profiles.append(definition)
			UpgradeDef.AutomationRole.SPLITTER_UPGRADE:
				splitter_upgrades.append(definition)

	if machine == null:
		errors.append("Mechanical Splitter purchase is missing")
	if profiles.is_empty():
		errors.append("Mechanical Splitter has no cutting profiles")
	var required_upgrade_effects: Array[UpgradeDef.Effect] = [
		UpgradeDef.Effect.AUTOMATION_SPEED,
		UpgradeDef.Effect.AUTOMATION_AUTO_LOAD,
		UpgradeDef.Effect.AUTOMATION_LOGS_PER_SPLIT,
		UpgradeDef.Effect.AUTOMATION_XP_GAIN,
		UpgradeDef.Effect.AUTOMATION_CASH_GAIN,
	]
	var seen_upgrade_effects: Dictionary = {}

	var seen_species: Dictionary = {}
	for definition: UpgradeDef in upgrades:
		if definition == null:
			continue
		if definition.required_upgrade_id != &"":
			if not ids.has(definition.required_upgrade_id):
				errors.append("upgrade %s requires unknown upgrade:%s" % [
					definition.id, definition.required_upgrade_id])
			elif int(indices.get(definition.required_upgrade_id, -1)) \
					>= int(indices.get(definition.id, upgrades.size())):
				errors.append("upgrade %s requires a non-earlier catalogue row:%s" % [
					definition.id, definition.required_upgrade_id])
		if definition.required_mastery_species_id != &"" \
				and SpeciesTable.by_id(definition.required_mastery_species_id) == null:
			errors.append("upgrade %s requires unknown mastery species:%s" % [
				definition.id, definition.required_mastery_species_id])
		if definition.required_mastered_species_count < 0 \
				or definition.required_mastered_species_count > SpeciesTable.count():
			errors.append("upgrade %s has invalid mastered-species count" % definition.id)

		if definition.automation_role == UpgradeDef.AutomationRole.NONE:
			if definition.automation_species_id != &"":
				errors.append("non-automation upgrade %s names an automation species" % definition.id)
			continue

		if definition.base_cost <= 0:
			errors.append("automation upgrade %s has invalid approved price" % definition.id)
		if not definition.tuning_status.begins_with("APPROVED"):
			errors.append("automation upgrade %s lacks an APPROVED tuning label" % definition.id)

		if definition.automation_role == UpgradeDef.AutomationRole.MECHANICAL_SPLITTER:
			if definition.purchase_form != UpgradeDef.PurchaseForm.ONE_TIME \
					or definition.max_level != 1:
				errors.append("Mechanical Splitter must be a one-time purchase")
			if definition.effect != UpgradeDef.Effect.NONE \
					or not is_zero_approx(definition.effect_step):
				errors.append("Mechanical Splitter purchase grants an upgrade effect")
			if definition.automation_species_id != &"":
				errors.append("Mechanical Splitter machine names a species")
			if definition.required_mastered_species_count <= 0:
				errors.append("Mechanical Splitter lacks a certification-count gate")
			continue

		if definition.automation_role == UpgradeDef.AutomationRole.SPLITTER_UPGRADE:
			if definition.automation_species_id != &"":
				errors.append("splitter upgrade %s names a species" % definition.id)
			if definition.effect not in required_upgrade_effects:
				errors.append("splitter upgrade %s has an unsupported effect" % definition.id)
			elif seen_upgrade_effects.has(definition.effect):
				errors.append("duplicate splitter upgrade effect:%d" % definition.effect)
			else:
				seen_upgrade_effects[definition.effect] = true
			if definition.effect_step <= 0.0:
				errors.append("splitter upgrade %s has a non-positive effect step" % definition.id)
			if definition.required_upgrade_id == &"":
				errors.append("splitter upgrade %s lacks an introduction prerequisite" % definition.id)
			if definition.effect == UpgradeDef.Effect.AUTOMATION_AUTO_LOAD:
				if definition.purchase_form != UpgradeDef.PurchaseForm.ONE_TIME \
						or definition.max_level != 1:
					errors.append("splitter auto loading must be a one-time purchase")
			elif definition.purchase_form != UpgradeDef.PurchaseForm.TIERED \
					or definition.max_level <= 1:
				errors.append("splitter upgrade %s must have multiple bounded ranks" % definition.id)
			continue

		if definition.purchase_form != UpgradeDef.PurchaseForm.ONE_TIME \
				or definition.max_level != 1:
			errors.append("cutting profile %s must be a one-time purchase" % definition.id)
		if definition.effect != UpgradeDef.Effect.NONE \
				or not is_zero_approx(definition.effect_step):
			errors.append("cutting profile %s grants an upgrade effect" % definition.id)
		var species_id := definition.automation_species_id
		if SpeciesTable.by_id(species_id) == null:
			errors.append("cutting profile %s names unknown species:%s" % [
				definition.id, species_id])
		elif seen_species.has(species_id):
			errors.append("duplicate cutting profile species:%s" % species_id)
		else:
			seen_species[species_id] = true
		if definition.required_mastery_species_id != species_id:
			errors.append("cutting profile %s is not gated by its own certification" % definition.id)
		if machine != null and definition.required_upgrade_id != machine.id:
			errors.append("cutting profile %s is not gated by the Mechanical Splitter" % definition.id)

	for effect: UpgradeDef.Effect in required_upgrade_effects:
		if not seen_upgrade_effects.has(effect):
			errors.append("Mechanical Splitter is missing upgrade effect:%d" % effect)

	return errors
