class_name RegionalNetworkTable
extends Resource

@export var regions: Array[RegionDef] = []
@export var routes: Array[RouteDef] = []
@export var projects: Array[InfrastructureProjectDef] = []


func region_by_id(id: StringName) -> RegionDef:
	for region: RegionDef in regions:
		if region != null and region.id == id:
			return region
	return null


func route_for_region(id: StringName) -> RouteDef:
	for route: RouteDef in routes:
		if route != null and route.region_id == id:
			return route
	return null
