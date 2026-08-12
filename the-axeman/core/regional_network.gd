class_name RegionalNetwork
extends RefCounted
## Read-only regional catalogue and actionable supply diagnosis. GameState owns
## every discovery/standing/depot/route write.

enum DelayReason { UNASSIGNED, STANDING, DEPOT, ROUTE, DISPATCH, YARD_QUEUE, READY }

const _TABLE_PATH := "res://data/regional_network_table.tres"
static var _table: RegionalNetworkTable


static func regions() -> Array[RegionDef]:
	var table := _catalogue()
	return [] if table == null else table.regions.duplicate()


static func routes() -> Array[RouteDef]:
	var table := _catalogue()
	return [] if table == null else table.routes.duplicate()


static func initial_regions() -> Array[RegionDef]:
	var all := regions()
	return all.slice(0, mini(3, all.size()))


static func projects() -> Array[InfrastructureProjectDef]:
	var table := _catalogue()
	return [] if table == null else table.projects.duplicate()


static func project_by_id(id: StringName) -> InfrastructureProjectDef:
	for project: InfrastructureProjectDef in projects():
		if project != null and project.id == id:
			return project
	return null


static func region_by_id(id: StringName) -> RegionDef:
	var table := _catalogue()
	return null if table == null else table.region_by_id(id)


static func region_for_species(species_id: StringName) -> RegionDef:
	for region: RegionDef in regions():
		if region != null and region.species_ids.has(species_id):
			return region
	return null


static func region_for_customer(customer_id: StringName) -> RegionDef:
	for region: RegionDef in regions():
		if region != null and region.customer_ids.has(customer_id):
			return region
	return null


static func route_for_region(region_id: StringName) -> RouteDef:
	var table := _catalogue()
	return null if table == null else table.route_for_region(region_id)


static func supply_status(species_id: StringName) -> Dictionary:
	var region := region_for_species(species_id)
	if region == null:
		return _status(DelayReason.UNASSIGNED, "No supplier has been found yet.", "View World Catalogue")
	if not GameState.is_region_discovered(region.id):
		return _status(DelayReason.STANDING,
			"Build reputation %d to discover %s." % [region.reputation_required,
			region.display_name], "Open customer board")
	if GameState.get_regional_standing(region.id) < region.depot_standing_required:
		return _status(DelayReason.STANDING,
			"%s standing %d / %d." % [region.display_name,
			GameState.get_regional_standing(region.id), region.depot_standing_required],
			"Complete regional customer work")
	if not GameState.has_regional_depot(region.id):
		return _status(DelayReason.DEPOT,
			"%s depot is not built." % region.display_name, "Build depot")
	if not GameState.has_regional_route(region.id):
		return _status(DelayReason.ROUTE,
			"%s has no active freight route." % region.display_name, "Establish route")
	if not CompanyLogistics.is_owned(&"log_feeder"):
		return _status(DelayReason.DISPATCH,
			"The yard has no supplier input equipment.", "Install Log Feeder")
	var cfg := CompanySimulation.config()
	if cfg != null and GameState.get_supplier_input_queues().size() >= cfg.dispatch_capacity \
			and not GameState.get_supplier_input_queues().has(species_id):
		return _status(DelayReason.DISPATCH,
			"All delivery lanes are serving other suppliers.", "Change supplier priorities")
	if cfg != null and int(GameState.get_supplier_input_queues().get(species_id, 0)) \
			>= CompanyLogistics.supplier_queue_capacity():
		return _status(DelayReason.YARD_QUEUE,
			"The supplier racks are full.", "Wait for space or change priorities")
	return _status(DelayReason.READY,
		"%s is connected and ready to send logs." % region.display_name, "Send logs to the yard")


static func validate_catalogue() -> PackedStringArray:
	var errors := PackedStringArray()
	var species_seen: Dictionary = {}
	var region_ids: Dictionary = {}
	for region: RegionDef in regions():
		if region == null or not region.validate().is_empty():
			errors.append("invalid regional definition")
			continue
		region_ids[region.id] = true
		for species_id: StringName in region.species_ids:
			if SpeciesTable.by_id(species_id) == null or species_seen.has(species_id):
				errors.append("unknown/duplicate regional species:%s" % species_id)
			species_seen[species_id] = region.id
	for route: RouteDef in routes():
		if route == null or not route.validate().is_empty() \
				or not region_ids.has(route.region_id):
			errors.append("invalid/orphaned regional route")
	for project: InfrastructureProjectDef in _catalogue().projects:
		if project == null or not project.validate().is_empty() \
				or (project.region_id != &"" and not region_ids.has(project.region_id)):
			errors.append("invalid/orphaned infrastructure project")
	return errors


static func _status(reason: DelayReason, detail: String, action: String) -> Dictionary:
	return {"reason": int(reason), "detail": detail, "action": action}


static func _catalogue() -> RegionalNetworkTable:
	if _table == null:
		_table = load(_TABLE_PATH) as RegionalNetworkTable
	return _table
