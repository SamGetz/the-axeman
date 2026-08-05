class_name Orders
extends RefCounted
## Stateless order catalogue and piece-routing service. Progress belongs to
## GameState, stock to InventoryManager, and money to GameState; this class only
## decides where a settled piece is credited.

const _TABLE_PATH := "res://data/order_table.tres"
const _COMMISSION_TABLE_PATH := "res://data/commission_table.tres"
const COMMISSION_UNLOCK_ORDER_ID := &"pine_campsite_load"
const COMMISSION_OFFER_COUNT := 3
static var _orders: OrderTable = null
static var _commissions: CommissionTable = null


static func all() -> Array[OrderDef]:
	var table := _table()
	return [] if table == null else table.orders.duplicate()


static func by_id(id: StringName) -> OrderDef:
	var table := _table()
	return null if table == null else table.by_id(id)


static func is_revealed(order: OrderDef) -> bool:
	return order != null and GameState.get_level() >= order.unlock_level


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
	var payout := Market.sell(item_id, 1)
	if payout > 0:
		GameState.record_manual_delivery_piece(item_id)
	return payout


## ------------------------------------------------ repeatable commissions (M9)
static func commissions_unlocked() -> bool:
	return GameState.has_completed_order(COMMISSION_UNLOCK_ORDER_ID)


static func commission_templates() -> Array[CommissionTemplateDef]:
	var table := _commission_table()
	return [] if table == null else table.templates.duplicate()


## Deterministic, data-driven offer generation. GameState owns and persists the
## returned snapshots, so opening a panel, loading a save or buying a species
## cannot reroll a standing offer. Advancing the stored generation serial is the
## only normal way to ask for a new set.
static func generate_commission_offers(generation: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not commissions_unlocked():
		return out
	var owned := GameState.get_owned_species()
	if owned.is_empty():
		return out
	var any_templates: Array[CommissionTemplateDef] = []
	var specific_templates: Array[CommissionTemplateDef] = []
	for template: CommissionTemplateDef in commission_templates():
		if template == null:
			continue
		if template.goal_kind == CommissionTemplateDef.GoalKind.ANY_FIREWOOD:
			any_templates.append(template)
		else:
			specific_templates.append(template)
	for slot in range(COMMISSION_OFFER_COUNT):
		var template: CommissionTemplateDef = null
		var species: SpeciesDef = null
		if slot == 0 and not any_templates.is_empty():
			template = any_templates[posmod(generation, any_templates.size())]
		elif not specific_templates.is_empty():
			var template_index := posmod(generation * 2 + slot - 1,
				specific_templates.size())
			template = specific_templates[template_index]
			var species_index := posmod(generation + slot - 1, owned.size())
			species = owned[species_index]
		elif not any_templates.is_empty():
			template = any_templates[posmod(generation + slot, any_templates.size())]
		var offer := _build_commission_offer(template, species, generation, slot,
			owned)
		if not offer.is_empty():
			out.append(offer)
	return out


static func commission_matches(offer: Dictionary, item_id: StringName) -> bool:
	var normalised := normalise_commission_offer(offer)
	if normalised.is_empty():
		return false
	var required_item := StringName(normalised.get("required_item", &""))
	if required_item != &"":
		return item_id == required_item
	var item := InventoryManager.get_item_def(item_id)
	return item != null and item.category == Enums.ItemCategory.RAW_WOOD


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
	if offer_id == &"" or template == null or required_count <= 0 \
			or required_count > 1000000 or cash_bonus <= 0 \
			or cash_bonus > 1000000000 or goal_kind < 0 \
			or goal_kind > CommissionTemplateDef.GoalKind.SPECIFIC_SPECIES:
		return {}
	if goal_kind != int(template.goal_kind):
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
	var title := String(source.get("title", "")).strip_edges()
	var description := String(source.get("description", "")).strip_edges()
	if customer_name.is_empty() or title.is_empty() or description.is_empty():
		return {}
	return {
		"id": offer_id,
		"template_id": template_id,
		"customer_name": customer_name,
		"title": title,
		"description": description,
		"goal_kind": goal_kind,
		"required_species": required_species,
		"required_item": required_item,
		"required_count": required_count,
		"cash_bonus": cash_bonus,
		"tuning_status": template.tuning_status,
	}


static func validate_live_commissions() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	var any_count := 0
	var specific_count := 0
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
		if template.required_count <= 0 or template.premium_ratio <= 0.0:
			errors.append("commission template %s has invalid pacing" % template.id)
		if not template.tuning_status.begins_with("PLACEHOLDER"):
			errors.append("commission template %s lacks PLACEHOLDER tuning label" % template.id)
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
	if template == null:
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
	var bonus := maxi(1, int(round(float(unit_value * template.required_count)
		* template.premium_ratio)))
	var offer := {
		"id": StringName("commission_%d_%d_%s" % [generation, slot, template.id]),
		"template_id": template.id,
		"customer_name": template.customer_name,
		"title": template.title_format.replace("{species}", species_name),
		"description": template.description,
		"goal_kind": int(template.goal_kind),
		"required_species": required_species,
		"required_item": required_item,
		"required_count": template.required_count,
		"cash_bonus": bonus,
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


static func _commission_template(id: StringName) -> CommissionTemplateDef:
	var table := _commission_table()
	return null if table == null else table.by_id(id)
