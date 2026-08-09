class_name Orders
extends RefCounted
## Stateless order catalogue and piece-routing service. Progress belongs to
## GameState, stock to InventoryManager, and money to GameState; this class only
## decides where a settled piece is credited.

const _TABLE_PATH := "res://data/order_table.tres"
const _COMMISSION_TABLE_PATH := "res://data/commission_table.tres"
const _CUSTOMER_TABLE_PATH := "res://data/customer_table.tres"
const JOBS_UNLOCK_LEVEL := 3
const COMMISSION_UNLOCK_ORDER_ID := &"pine_campsite_load"
const COMMISSION_OFFER_COUNT := 3

enum CommissionOfferRole {
	MIXED,
	FRONTIER,
	ROTATION,
}
static var _orders: OrderTable = null
static var _commissions: CommissionTable = null
static var _customers: CustomerTable = null


static func all() -> Array[OrderDef]:
	var table := _table()
	return [] if table == null else table.orders.duplicate()


static func by_id(id: StringName) -> OrderDef:
	var table := _table()
	return null if table == null else table.by_id(id)


## The authored board enters the progression loop at one explicit level. Order
## rows can still carry later per-job levels, but none can be accepted through a
## hidden board before this shared first-use gate.
static func jobs_unlocked() -> bool:
	return GameState.get_level() >= JOBS_UNLOCK_LEVEL


static func is_revealed(order: OrderDef) -> bool:
	return jobs_unlocked() and order != null \
		and GameState.get_level() >= order.unlock_level


## Only revealed orders. The XP strip advertises the next contract as a level
## reward, so the board itself never contains disabled future work.
static func visible() -> Array[OrderDef]:
	var out: Array[OrderDef] = []
	for order: OrderDef in all():
		if is_revealed(order):
			out.append(order)
	return out


static func next_unrevealed() -> OrderDef:
	for order: OrderDef in all():
		if order != null and not is_revealed(order):
			return order
	return null


static func is_available(order: OrderDef) -> bool:
	if order == null or GameState.has_completed_order(order.id):
		return false
	if not is_revealed(order):
		return false
	return order.required_species == &"" or GameState.owns_species(order.required_species)


## Pay the unlimited buyer first. Only a piece the yard actually bought may
## advance an order; otherwise an unpriced or missing inventory item could earn
## a completion premium without leaving the player's stock.
static func settle_piece(item_id: StringName) -> int:
	return settle_manual_piece(ManualPieceReceipt.new(item_id))


static func settle_manual_piece(receipt: ManualPieceReceipt) -> int:
	if receipt == null or not receipt.is_manual() or receipt.item_id == &"":
		return 0
	var payout := Market.sell(receipt.item_id, 1)
	if payout > 0:
		var grade := clampi(receipt.grade, Craftsmanship.Grade.ROUGH,
			Craftsmanship.Grade.EXCEPTIONAL)
		var craft_bonus := Craftsmanship.cash_bonus(receipt.item_id, grade)
		if craft_bonus > 0:
			craft_bonus = GameState.award_cash(craft_bonus, &"craftsmanship")
		GameState.record_manual_craft_grade(grade)
		GameState.record_signature_log(receipt)
		GameState.record_manual_delivery_receipt(receipt)
		GameState.present_manual_piece_settlement(receipt, craft_bonus)
		return payout + craft_bonus
	return 0


## -------------------------------------------- long-term standing commissions
static func commissions_unlocked() -> bool:
	return GameState.has_completed_order(COMMISSION_UNLOCK_ORDER_ID)


static func commission_templates() -> Array[CommissionTemplateDef]:
	var table := _commission_table()
	return [] if table == null else table.templates.duplicate()


static func customers() -> Array[CustomerDef]:
	var table := _customer_table()
	return [] if table == null else table.customers.duplicate()


static func customer_by_id(id: StringName) -> CustomerDef:
	var table := _customer_table()
	return null if table == null else table.by_id(id)


static func customer_history_limit() -> int:
	var table := _customer_table()
	return 20 if table == null else maxi(1, table.completion_history_limit)


static func standing_commission_limit() -> int:
	var table := _commission_table()
	return 5 if table == null else maxi(1, table.campaign_offer_limit)


static func standing_commission_target_seconds() -> Vector2:
	var table := _commission_table()
	return Vector2(1500.0, 2400.0) if table == null else Vector2(
		table.target_duration_min_seconds, table.target_duration_max_seconds)


## Deterministic, data-driven offer generation. GameState owns and persists the
## returned snapshots, so opening a panel, loading a save or buying a species
## cannot reroll a standing offer. Advancing the stored generation serial is the
## only normal way to ask for a new set.
static func generate_commission_offers(generation: int,
		preserved_slots: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{}, {}, {}]
	if not commissions_unlocked():
		return []
	var owned := GameState.get_owned_species()
	if owned.is_empty():
		return []
	var any_templates: Array[CommissionTemplateDef] = []
	var specific_templates: Array[CommissionTemplateDef] = []
	for template: CommissionTemplateDef in commission_templates():
		if template == null:
			continue
		if GameState.get_reputation() < template.reputation_required:
			continue
		if template.goal_kind == CommissionTemplateDef.GoalKind.ANY_FIREWOOD:
			any_templates.append(template)
		else:
			specific_templates.append(template)
	for raw_slot: Variant in preserved_slots:
		var slot := int(raw_slot)
		if slot < 0 or slot >= COMMISSION_OFFER_COUNT:
			continue
		var preserved := normalise_commission_offer(preserved_slots[raw_slot])
		if not preserved.is_empty() and int(preserved.get("offer_role", -1)) == slot:
			out[slot] = preserved
	for slot in range(COMMISSION_OFFER_COUNT):
		if not out[slot].is_empty():
			continue
		var template: CommissionTemplateDef = null
		var species: SpeciesDef = null
		var role := slot
		if role == CommissionOfferRole.MIXED and not any_templates.is_empty():
			template = any_templates[posmod(generation, any_templates.size())]
		elif not specific_templates.is_empty():
			var template_index := posmod(generation * 2 + slot - 1,
				specific_templates.size())
			template = specific_templates[template_index]
			if role == CommissionOfferRole.FRONTIER:
				species = owned.back()
			else:
				var rotation := owned.duplicate()
				if rotation.size() > 1:
					rotation.pop_back()
				species = rotation[posmod(generation, rotation.size())]
		elif not any_templates.is_empty():
			template = any_templates[posmod(generation + slot, any_templates.size())]
		var offer := _build_commission_offer(template, species, generation, slot, owned)
		if not offer.is_empty():
			out[slot] = offer
	for offer: Dictionary in out:
		if offer.is_empty():
			return []
	return out


static func commission_cash_anchor() -> int:
	var anchor := 0
	var next_species := GameState.get_next_unowned_species()
	if next_species != null and next_species.unlock_cost > 0:
		anchor = next_species.unlock_cost
	var owned := GameState.get_owned_species()
	if anchor <= 0 and not owned.is_empty():
		anchor = maxi(0, owned.back().unlock_cost)
	# Once Earth is empty, a species-priced reward becomes pocket change. Keep the
	# same authored relevance ratio, but anchor it to the next actual campaign
	# project: launch construction first, then the missing alien production line.
	# The source costs remain labelled placeholders in their data resources.
	if GameState.is_earth_depleted():
		for project: LaunchProjectDef in LaunchProgram.projects():
			if not GameState.has_launch_project(project.id):
				anchor = maxi(anchor, project.cash_cost)
				break
		for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
			if GameState.get_alien_destination_state(wood_trait.destination_id) \
					>= GameState.AlienDestinationState.MASTERED \
					and not GameState.has_orbital_line(wood_trait.destination_id):
				anchor = maxi(anchor, wood_trait.fleet_cost + wood_trait.orbital_line_cost)
				break
	return anchor


static func commission_matches(offer: Dictionary, item_id: StringName) -> bool:
	return commission_matches_receipt(offer, ManualPieceReceipt.new(item_id))


static func commission_matches_receipt(offer: Dictionary,
		receipt: ManualPieceReceipt) -> bool:
	if receipt == null:
		return false
	var normalised := normalise_commission_offer(offer)
	if normalised.is_empty():
		return false
	if not receipt.is_manual() and not bool(normalised.get("automation_eligible", false)):
		return false
	var required_item := StringName(normalised.get("required_item", &""))
	if required_item != &"" and receipt.item_id != required_item:
		return false
	var item := InventoryManager.get_item_def(receipt.item_id)
	if item == null or item.category != Enums.ItemCategory.RAW_WOOD:
		return false
	var family := int(normalised.get("craft_family", CraftRequirementDef.Family.QUANTITY))
	if receipt.normalized_size < float(normalised.get("min_normalized_size", 0.0)) \
			or receipt.normalized_size > float(normalised.get("max_normalized_size", 1.0)) \
			or receipt.grade < int(normalised.get("minimum_grade", Craftsmanship.Grade.ROUGH)):
		return false
	if bool(normalised.get("require_source_identity", false)) \
			and receipt.source_log_id == &"":
		return false
	return family >= CraftRequirementDef.Family.QUANTITY \
		and family <= CraftRequirementDef.Family.SIGNATURE


## Saved generated content is treated like authored content: every identity,
## species route and positive tuning field is validated before GameState accepts
## it. Returning a canonical copy prevents UI/save dictionaries from becoming a
## second mutation route.
static func normalise_commission_offer(value: Variant,
		require_owned_species := true) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source := value as Dictionary
	var offer_id := StringName(String(source.get("id", "")))
	var template_id := StringName(String(source.get("template_id", "")))
	var template := _commission_template(template_id)
	var goal_kind := int(source.get("goal_kind", -1))
	var required_count := int(source.get("required_count", 0))
	var cash_bonus := int(source.get("cash_bonus", 0))
	var offer_role := int(source.get("offer_role", -1))
	var craft_family := int(source.get("craft_family", CraftRequirementDef.Family.QUANTITY))
	var min_normalized_size := float(source.get("min_normalized_size", 0.0))
	var max_normalized_size := float(source.get("max_normalized_size", 1.0))
	var minimum_grade := int(source.get("minimum_grade", Craftsmanship.Grade.ROUGH))
	var require_source_identity := bool(source.get("require_source_identity", false))
	var automation_eligible := bool(source.get("automation_eligible", false))
	if offer_id == &"" or template == null or required_count <= 0 \
			or required_count > 1000000 or cash_bonus <= 0 \
			or cash_bonus > GameState.MAX_SAFE_ECONOMY_VALUE or goal_kind < 0 \
			or goal_kind > CommissionTemplateDef.GoalKind.SPECIFIC_SPECIES \
			or offer_role < 0 or offer_role > CommissionOfferRole.ROTATION:
		return {}
	if craft_family < CraftRequirementDef.Family.QUANTITY \
			or craft_family > CraftRequirementDef.Family.SIGNATURE \
			or min_normalized_size < 0.0 or max_normalized_size > 1.0 \
			or min_normalized_size > max_normalized_size \
			or minimum_grade < Craftsmanship.Grade.ROUGH \
			or minimum_grade > Craftsmanship.Grade.EXCEPTIONAL:
		return {}
	if goal_kind != int(template.goal_kind):
		return {}
	var reputation_reward := maxi(0,
		int(source.get("reputation_reward", template.reputation_reward)))
	if (offer_role == CommissionOfferRole.MIXED) \
			!= (goal_kind == CommissionTemplateDef.GoalKind.ANY_FIREWOOD):
		return {}
	if not template.tuning_status.begins_with("PLACEHOLDER"):
		return {}
	var required_species := StringName(String(source.get("required_species", "")))
	var required_item := StringName(String(source.get("required_item", "")))
	if goal_kind == CommissionTemplateDef.GoalKind.ANY_FIREWOOD:
		if required_species != &"" or required_item != &"":
			return {}
	else:
		var species := SpeciesTable.by_id(required_species)
		if species == null or species.yield_item != required_item:
			return {}
		if require_owned_species and not GameState.owns_species(required_species):
			return {}
	var customer_name := String(source.get("customer_name", "")).strip_edges()
	var customer_id := StringName(String(source.get("customer_id", template.customer_id)))
	var title := String(source.get("title", "")).strip_edges()
	var description := String(source.get("description", "")).strip_edges()
	if customer_id == &"" or customer_name.is_empty() or title.is_empty() or description.is_empty():
		return {}
	return {
		"id": offer_id,
		"template_id": template_id,
		"customer_name": customer_name,
		"customer_id": customer_id,
		"title": title,
		"description": description,
		"offer_role": offer_role,
		"effort_band": int(template.effort_band),
		"goal_kind": goal_kind,
		"required_species": required_species,
		"required_item": required_item,
		"required_count": required_count,
		"cash_bonus": cash_bonus,
		"reputation_reward": reputation_reward,
		"craft_family": craft_family,
		"min_normalized_size": min_normalized_size,
		"max_normalized_size": max_normalized_size,
		"minimum_grade": minimum_grade,
		"require_source_identity": require_source_identity,
		"automation_eligible": automation_eligible,
		"tuning_status": template.tuning_status,
	}


static func validate_live_commissions() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	var any_count := 0
	var specific_count := 0
	var table := _commission_table()
	if table == null or table.relevance_premium_ratio <= 0.0 \
			or table.campaign_offer_limit < 1 \
			or table.target_duration_min_seconds <= 0.0 \
			or table.target_duration_max_seconds < table.target_duration_min_seconds \
			or not table.tuning_status.begins_with("PLACEHOLDER"):
		errors.append("commission table lacks valid labelled relevance tuning")
	for template: CommissionTemplateDef in commission_templates():
		if template == null:
			errors.append("null commission template")
			continue
		if template.id == &"" or seen.has(template.id):
			errors.append("missing/duplicate commission template id:%s" % template.id)
		seen[template.id] = true
		if template.customer_name.strip_edges().is_empty() \
				or template.title_format.strip_edges().is_empty() \
				or template.description.strip_edges().is_empty():
			errors.append("commission template %s lacks player-facing copy" % template.id)
		if template.required_count <= 0 or template.premium_ratio <= 0.0 \
				or int(template.effort_band) < CommissionTemplateDef.EffortBand.STANDING \
				or int(template.effort_band) > CommissionTemplateDef.EffortBand.PROJECT:
			errors.append("commission template %s has invalid pacing" % template.id)
		if not template.tuning_status.begins_with("PLACEHOLDER"):
			errors.append("commission template %s lacks PLACEHOLDER tuning label" % template.id)
		if template.craft_requirement == null \
				or not template.craft_requirement.validate().is_empty():
			errors.append("commission template %s lacks a valid craft requirement" % template.id)
		if template.automation_eligible_bulk \
			and (template.effort_band != CommissionTemplateDef.EffortBand.PROJECT \
				or template.craft_requirement.family == CraftRequirementDef.Family.QUALITY \
				or template.craft_requirement.family == CraftRequirementDef.Family.SIGNATURE):
			errors.append("commission template %s exposes handcrafted work to automation" % template.id)
		var customer := customer_by_id(template.customer_id)
		if customer == null or not customer.validate().is_empty() \
				or customer.display_name != template.customer_name:
			errors.append("commission template %s has an invalid customer card" % template.id)
		if template.goal_kind == CommissionTemplateDef.GoalKind.ANY_FIREWOOD:
			any_count += 1
		else:
			specific_count += 1
	if any_count == 0 or specific_count < 2:
		errors.append("commission catalogue cannot build one mixed and two specific offers")
	return errors


static func _build_commission_offer(template: CommissionTemplateDef,
		species: SpeciesDef, generation: int, slot: int,
		owned: Array[SpeciesDef]) -> Dictionary:
	if template == null or template.craft_requirement == null:
		return {}
	var required_species := &""
	var required_item := &""
	var species_name := "Mixed Firewood"
	var unit_value := 0
	if template.goal_kind == CommissionTemplateDef.GoalKind.SPECIFIC_SPECIES:
		if species == null:
			return {}
		required_species = species.id
		required_item = species.yield_item
		species_name = species.display_name
		unit_value = Market.get_price(required_item)
	else:
		# A flexible mixed order is valued from the cheapest eligible wood so
		# switching to Aspen after generation can never inflate a snapshotted bonus.
		for candidate: SpeciesDef in owned:
			var price := Market.get_price(candidate.yield_item)
			if price > 0 and (unit_value == 0 or price < unit_value):
				unit_value = price
	if unit_value <= 0:
		return {}
	var role := slot
	var table := _commission_table()
	var relevance_ratio := 0.0 if table == null else table.relevance_premium_ratio
	# Long-term commissions are project funding, not a small load premium. Anchor
	# every choice to the next named species purchase while retaining the authored
	# work-value premium as a floor for late-game and capped catalogues.
	var project_fund := int(round(float(commission_cash_anchor()) * relevance_ratio))
	var work_floor := int(round(float(unit_value * template.required_count)
		* template.premium_ratio))
	var bonus := maxi(1, maxi(project_fund, work_floor))
	var offer := {
		"id": StringName("commission_%d_%d_%s" % [generation, slot, template.id]),
		"template_id": template.id,
		"customer_name": template.customer_name,
		"customer_id": template.customer_id,
		"title": template.title_format.replace("{species}", species_name),
		"description": template.description,
		"offer_role": int(role),
		"effort_band": int(template.effort_band),
		"goal_kind": int(template.goal_kind),
		"required_species": required_species,
		"required_item": required_item,
		"required_count": template.required_count,
		"cash_bonus": bonus,
		"reputation_reward": template.reputation_reward,
		"craft_family": int(template.craft_requirement.family),
		"min_normalized_size": template.craft_requirement.min_normalized_size,
		"max_normalized_size": template.craft_requirement.max_normalized_size,
		"minimum_grade": template.craft_requirement.minimum_grade,
		"require_source_identity": template.craft_requirement.require_source_identity,
		"automation_eligible": template.automation_eligible_bulk,
		"tuning_status": template.tuning_status,
	}
	return normalise_commission_offer(offer)


## Cross-table validation for the authored one-time ladder. This remains a
## read-only service: it reports malformed data but never repairs progression.
static func validate_live_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	var previous_level := 0
	for index in range(all().size()):
		var order: OrderDef = all()[index]
		if order == null:
			errors.append("null order at index:%d" % index)
			continue
		if order.id == &"":
			errors.append("order has empty id at index:%d" % index)
		elif seen_ids.has(order.id):
			errors.append("duplicate order id:%s" % order.id)
		else:
			seen_ids[order.id] = true
		if order.required_count <= 0 or order.cash_bonus <= 0:
			errors.append("order %s has non-positive count/bonus" % order.id)
		if order.unlock_level < previous_level:
			errors.append("order %s breaks authored reveal ordering" % order.id)
		previous_level = order.unlock_level
		if order.required_item != &"" and not Market.is_sellable(order.required_item):
			errors.append("order %s requires unsellable item:%s" % [order.id, order.required_item])
		if order.required_species == &"":
			continue
		var species := SpeciesTable.by_id(order.required_species)
		if species == null:
			errors.append("order %s requires unknown species:%s" % [order.id, order.required_species])
			continue
		if species.yield_item != order.required_item:
			errors.append("order %s item does not match species yield" % order.id)
		if order.id == StringName("%s_delivery" % species.id):
			if order.unlock_level != species.unlock_level:
				errors.append("order %s reveal level does not match species" % order.id)
			if order.required_count != 20:
				errors.append("order %s breaks the Slice 6 placeholder count" % order.id)
			var expected_bonus := maxi(400,
				int(ceil(float(species.unlock_cost) * 0.10 / 50.0)) * 50)
			if order.cash_bonus != expected_bonus:
				errors.append("order %s breaks the Slice 6 placeholder bonus formula" % order.id)
			if not order.tuning_status.begins_with("PLACEHOLDER"):
				errors.append("order %s lacks a PLACEHOLDER tuning label" % order.id)
	return errors


static func _table() -> OrderTable:
	if _orders == null:
		_orders = load(_TABLE_PATH) as OrderTable
		if _orders == null:
			push_error("Orders: failed to load '%s'; the contract board is empty." % _TABLE_PATH)
	return _orders


static func _commission_table() -> CommissionTable:
	if _commissions == null:
		_commissions = load(_COMMISSION_TABLE_PATH) as CommissionTable
		if _commissions == null:
			push_error("Orders: failed to load '%s'; commissions are unavailable." %
				_COMMISSION_TABLE_PATH)
	return _commissions


static func _customer_table() -> CustomerTable:
	if _customers == null:
		_customers = load(_CUSTOMER_TABLE_PATH) as CustomerTable
		if _customers == null:
			push_error("Orders: failed to load '%s'; customer cards are unavailable." %
				_CUSTOMER_TABLE_PATH)
	return _customers


static func _commission_template(id: StringName) -> CommissionTemplateDef:
	var table := _commission_table()
	return null if table == null else table.by_id(id)
