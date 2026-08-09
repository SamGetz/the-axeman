class_name YardEquipmentPresenter
extends Node3D
## FILE: res://scenes/3d_action/yard_equipment_presenter.gd
## ATTACHES TO: YardEquipment (Node3D), a child of Chopping_Minigame in
## res://scenes/3d_action/chopping_minigame.tscn.
##
## Physical view of shop-owned progression. It owns no state: every refresh reads
## Shop/GameState, and it refreshes both after a purchase and after save restore.
## Axe/block reuse existing assets as temporary colour variants. The remaining
## primitive props remain replaceable geometry, now paired with readable vector
## placeholder graphics while final authored models/audio are absent.

const _WOOD := Color(0.32, 0.17, 0.07, 1.0)
const _DARK_WOOD := Color(0.14, 0.07, 0.025, 1.0)
const _METAL := Color(0.28, 0.32, 0.34, 1.0)
const _PAPER := Color(0.82, 0.72, 0.48, 1.0)
const _COFFEE := Color(0.16, 0.30, 0.25, 1.0)
const _REINFORCED_BLOCK_TINT := Color(0.58, 0.72, 0.86, 1.0)
const _SPLITTER_BODY := Color(0.19, 0.25, 0.27, 1.0)
const _SPLITTER_GUARD := Color(0.78, 0.43, 0.12, 1.0)
const _SPLITTER_BLADE := Color(0.65, 0.71, 0.73, 1.0)
const _YARD_CANVAS := Color(0.72, 0.62, 0.42, 1.0)
const _YARD_ACCENT := Color(0.76, 0.28, 0.10, 1.0)

var _splitter_runtime: MechanicalSplitterRuntime
var _yard_stage_root: Node3D
var _yard_vehicle: Node3D
var _yard_vehicle_phase := 0.0
var _splitter_root: Node3D
var _splitter_ram: MeshInstance3D
var _splitter_wheel: MeshInstance3D
var _splitter_log: MeshInstance3D
var _splitter_label: Label3D
var _splitter_state_label: Label3D
var _splitter_log_ends: Array[MeshInstance3D] = []
var _splitter_rest_position := Vector3.ZERO
var _splitter_completion_left := 0.0
var _splitter_skin_species: StringName = &""


func _ready() -> void:
	GameState.building_tiers_changed.connect(refresh)
	GameState.earth_campaign_changed.connect(refresh)
	GameState.launch_program_changed.connect(refresh)
	GameState.alien_campaign_changed.connect(refresh)
	_splitter_runtime = get_parent().get_node_or_null("MechanicalSplitterRuntime") \
		as MechanicalSplitterRuntime
	if _splitter_runtime != null:
		_splitter_runtime.state_changed.connect(_refresh_splitter_runtime.unbind(1))
		_splitter_runtime.progress_changed.connect(_refresh_splitter_runtime.unbind(1))
		_splitter_runtime.cycle_completed.connect(_on_splitter_cycle_completed)
	# Parent builds the runtime stump in its _ready; wait until that has happened
	# before measuring its real imported mesh.
	refresh.call_deferred()


func refresh() -> void:
	_yard_stage_root = null
	_yard_vehicle = null
	_splitter_root = null
	_splitter_ram = null
	_splitter_wheel = null
	_splitter_log = null
	_splitter_label = null
	_splitter_state_label = null
	_splitter_log_ends.clear()
	_splitter_skin_species = &""
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var game := get_parent()
	var axe: AxeViewmodel = game.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor")
	if axe != null:
		var axe_def := M7CContent.equipment().active_for_slot(EquipmentDef.Slot.AXE) \
			if M7CContent.equipment() != null else null
		if axe_def != null and not axe_def.is_starting_fallback:
			axe.set_equipment_upgrade(axe_def.id, axe_def.progression_stage,
				axe_def.placeholder_tint if axe_def.progression_stage > 0 else Color(0.62, 0.82, 1.0, 1.0))
		else:
			axe.set_equipment_upgrade(&"", 0, Color.WHITE)

	var stump_def := M7CContent.equipment().active_for_slot(EquipmentDef.Slot.WORKSTATION) \
		if M7CContent.equipment() != null else null
	_set_block_variant(game, stump_def)
	_build_yard_stage(YardProgression.current_stage())
	if Shop.get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0:
		_build_ledger()
	if Shop.get_level(GameState.UPGRADE_HANDCART) > 0:
		_build_handcart()
	if Shop.get_level(GameState.UPGRADE_COFFEE_THERMOS) > 0:
		_build_thermos()
	if MechanicalSplitter.is_installed():
		_build_mechanical_splitter()
	if GameState.is_earth_master():
		_build_earth_master_memorial()


func has_physical(id: StringName) -> bool:
	return get_node_or_null(String(id)) != null


func visible_yard_stage() -> YardProgression.Stage:
	return YardProgression.current_stage()


func stage_has_landmark(name: StringName) -> bool:
	return _yard_stage_root != null \
		and _yard_stage_root.get_node_or_null(String(name)) != null


func _build_yard_stage(stage: YardProgression.Stage) -> void:
	var definition := YardProgression.definition(stage)
	_yard_stage_root = Node3D.new()
	_yard_stage_root.name = "YardStage"
	_yard_stage_root.set_meta("derived_stage", int(stage))
	_yard_stage_root.set_meta("art_status",
		"native_authored_runtime_geometry_generated_signage_candidate_pending")
	add_child(_yard_stage_root)
	_build_starting_sign(definition)
	if stage >= YardProgression.Stage.SHED:
		_build_supplier_shed()
	if stage >= YardProgression.Stage.WORKING_YARD:
		_build_contract_staging()
	if stage >= YardProgression.Stage.DEPOT:
		_build_depot_canopy_and_vehicle()
	if stage >= YardProgression.Stage.HEADQUARTERS:
		_build_headquarters_office()
	_build_space_program()


func _build_starting_sign(definition: YardStageDef) -> void:
	var root := Node3D.new()
	root.name = "StageSign"
	root.position = Vector3(1.18, 0.36, -1.12)
	root.rotation_degrees.y = -12.0
	_yard_stage_root.add_child(root)
	_box(root, "Post", Vector3(0.07, 0.72, 0.07), Vector3(0, -0.12, 0), _DARK_WOOD)
	_box(root, "Board", Vector3(0.74, 0.30, 0.06), Vector3(0, 0.22, 0),
		definition.accent if definition != null else _WOOD)
	var label := Label3D.new()
	label.name = "StageName"
	label.text = "THE AXEMAN\n%s" % ("YARD" if definition == null else definition.display_name.to_upper())
	label.position = Vector3(0, 0.22, 0.035)
	label.font_size = 18
	label.outline_size = 4
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.92, 0.72, 1.0)
	root.add_child(label)


func _build_supplier_shed() -> void:
	var shed := Node3D.new()
	shed.name = "SupplierShed"
	shed.position = Vector3(1.32, 0.0, -1.68)
	shed.rotation_degrees.y = -8.0
	_yard_stage_root.add_child(shed)
	_box(shed, "Back", Vector3(1.20, 0.82, 0.10), Vector3(0, 0.41, -0.32), _WOOD)
	for x in [-0.53, 0.53]:
		_box(shed, "Post", Vector3(0.10, 0.92, 0.10), Vector3(x, 0.46, 0), _DARK_WOOD)
	var roof := _box(shed, "Roof", Vector3(1.42, 0.10, 0.84),
		Vector3(0, 0.94, -0.03), _YARD_CANVAS)
	roof.rotation_degrees.z = -4.0
	_box(shed, "LedgerShelf", Vector3(0.72, 0.09, 0.30),
		Vector3(0, 0.26, -0.02), _PAPER)


func _build_contract_staging() -> void:
	var staging := Node3D.new()
	staging.name = "ContractStaging"
	staging.position = Vector3(-1.38, 0.0, -1.46)
	_yard_stage_root.add_child(staging)
	_box(staging, "Platform", Vector3(1.42, 0.12, 0.86), Vector3.ZERO, _DARK_WOOD)
	for index in range(3):
		var x := -0.45 + float(index) * 0.45
		_box(staging, "ContractCrate%d" % index, Vector3(0.36, 0.34, 0.42),
			Vector3(x, 0.23, 0), _WOOD)
		_box(staging, "CrateMark%d" % index, Vector3(0.18, 0.06, 0.008),
			Vector3(x, 0.25, 0.215), _YARD_ACCENT)
	var trophies := Node3D.new()
	trophies.name = "TrophyCrossSections"
	trophies.position = Vector3(-0.52, 0.64, -0.08)
	staging.add_child(trophies)
	for index in range(3):
		var trophy := _cylinder(trophies, "CrossSection%d" % index,
			0.12 + index * 0.015, 0.035, Vector3(index * 0.32, 0, 0),
			Color(0.68 - index * 0.07, 0.45 - index * 0.04, 0.22, 1))
		trophy.rotation_degrees.x = 90.0


func _build_depot_canopy_and_vehicle() -> void:
	var depot := Node3D.new()
	depot.name = "DepotLoadingBay"
	depot.position = Vector3(0, 0, -2.28)
	_yard_stage_root.add_child(depot)
	for x in [-1.55, 1.55]:
		_box(depot, "BayPost", Vector3(0.13, 1.42, 0.13),
			Vector3(x, 0.71, 0), _METAL)
	_box(depot, "LoadingCanopy", Vector3(3.40, 0.14, 1.12),
		Vector3(0, 1.44, 0), Color(0.18, 0.32, 0.38, 1))
	_box(depot, "DepotStripe", Vector3(2.65, 0.11, 0.06),
		Vector3(0, 1.30, 0.56), _YARD_ACCENT)
	_yard_vehicle = Node3D.new()
	_yard_vehicle.name = "YardVehicle"
	_yard_vehicle.position = Vector3(-1.9, 0.30, 0.15)
	depot.add_child(_yard_vehicle)
	_box(_yard_vehicle, "Cab", Vector3(0.46, 0.48, 0.52),
		Vector3(0.48, 0.12, 0), Color(0.22, 0.45, 0.55, 1))
	_box(_yard_vehicle, "Bed", Vector3(1.05, 0.20, 0.52),
		Vector3(-0.28, 0.0, 0), _DARK_WOOD)
	for x in [-0.56, 0.38]:
		_wheel(_yard_vehicle, "VehicleWheel", Vector3(x, -0.18, 0.31))
		_wheel(_yard_vehicle, "VehicleWheel", Vector3(x, -0.18, -0.31))


func _build_headquarters_office() -> void:
	var office := Node3D.new()
	office.name = "HeadquartersOffice"
	office.position = Vector3(2.0, 0.0, -2.25)
	_yard_stage_root.add_child(office)
	_box(office, "Office", Vector3(1.45, 1.30, 1.05),
		Vector3(0, 0.65, 0), Color(0.28, 0.22, 0.34, 1))
	_box(office, "Window", Vector3(0.72, 0.40, 0.025),
		Vector3(-0.12, 0.76, 0.54), Color(0.34, 0.68, 0.78, 1))
	_box(office, "DoctrineBoard", Vector3(0.46, 0.52, 0.04),
		Vector3(0.46, 0.70, 0.56), Color(0.72, 0.55, 0.22, 1))


func _build_earth_master_memorial() -> void:
	var memorial := Node3D.new()
	memorial.name = "EarthMasterMemorial"
	memorial.position = Vector3(-2.0, 0.62, -2.0)
	memorial.set_meta("presentation", "final_cross_section_and_haul_away_complete")
	_yard_stage_root.add_child(memorial)
	_box(memorial, "Mount", Vector3(0.76, 0.92, 0.10), Vector3.ZERO, _DARK_WOOD)
	var section := _cylinder(memorial, "LignumVitaeCrossSection", 0.30, 0.055,
		Vector3(0, 0.05, 0.075), Color(0.43, 0.58, 0.36, 1.0))
	section.rotation_degrees.x = 90.0
	var label := Label3D.new()
	label.name = "EarthMasterPlaque"
	label.text = "EARTH MASTER\n25 WOODS"
	label.position = Vector3(0, -0.38, 0.08)
	label.font_size = 16
	label.outline_size = 4
	label.modulate = Color(1.0, 0.86, 0.48, 1.0)
	memorial.add_child(label)


func _build_space_program() -> void:
	if GameState.has_launch_project(&"mission_control"):
		var control := Node3D.new()
		control.name = "MissionControl"
		control.position = Vector3(2.95, 0.0, -1.25)
		_yard_stage_root.add_child(control)
		_box(control, "OperationsCabin", Vector3(1.30, 1.08, 0.82),
			Vector3(0, 0.54, 0), Color(0.20, 0.28, 0.38, 1))
		_box(control, "PanoramicWindow", Vector3(0.82, 0.34, 0.025),
			Vector3(0, 0.68, 0.425), Color(0.27, 0.72, 0.86, 1))
		_textured_panel(control, "MissionControlCandidateEmblem", Vector2(0.34, 0.34),
			Vector3(0.43, 0.62, 0.426),
			"res://assets/generated/signage/mission_control_emblem_candidate.png")
		var dish := _cylinder(control, "TrackingDish", 0.24, 0.05,
			Vector3(0.42, 1.22, 0), Color(0.78, 0.82, 0.84, 1))
		dish.rotation_degrees.z = 62.0
	if GameState.has_launch_project(&"gantry"):
		var gantry := Node3D.new()
		gantry.name = "LaunchGantry"
		gantry.position = Vector3(-3.05, 0.0, -2.4)
		_yard_stage_root.add_child(gantry)
		for x in [-0.48, 0.48]:
			_box(gantry, "GantryLeg", Vector3(0.12, 2.35, 0.12),
				Vector3(x, 1.175, 0), _METAL)
		for y in [0.45, 1.10, 1.75, 2.30]:
			_box(gantry, "GantryBrace", Vector3(1.08, 0.09, 0.10),
				Vector3(0, y, 0), _YARD_ACCENT)
	if GameState.has_launch_project(&"deep_space_vessel"):
		var vessel := Node3D.new()
		vessel.name = "DeepSpaceVessel"
		vessel.position = Vector3(-3.05, 0.62, -2.4)
		_yard_stage_root.add_child(vessel)
		var hull := _cylinder(vessel, "TimberVesselHull", 0.26, 1.55,
			Vector3.ZERO, Color(0.70, 0.72, 0.68, 1))
		hull.rotation_degrees.x = 90.0
		_box(vessel, "CargoCradle", Vector3(0.62, 0.32, 0.72),
			Vector3(0, -0.34, 0), _DARK_WOOD)
	var specimen_count := 0
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		if GameState.get_alien_destination_state(wood_trait.destination_id) \
				>= GameState.AlienDestinationState.SPECIMEN_READY:
			specimen_count += 1
	if specimen_count > 0:
		var rig := Node3D.new()
		rig.name = "OrbitalSpecimenRig"
		rig.position = Vector3(0, 0.10, 0)
		_yard_stage_root.add_child(rig)
		for x in [-0.48, 0.48]:
			_box(rig, "RigPost", Vector3(0.055, 0.62, 0.055),
				Vector3(x, 0.31, -0.10), Color(0.46, 0.58, 0.68, 1))
		_box(rig, "ScannerArc", Vector3(1.04, 0.055, 0.055),
			Vector3(0, 0.62, -0.10), Color(0.30, 0.92, 0.84, 1))
		for index in range(specimen_count):
			var light := _cylinder(rig, "SpecimenIndicator%d" % index, 0.035, 0.018,
				Vector3(-0.18 + index * 0.18, 0.66, -0.10),
				AlienCampaign.traits()[index].inside_tint)
			light.rotation_degrees.x = 90.0
	var fleet_total := 0
	for wood_trait: AlienWoodTraitDef in AlienCampaign.traits():
		fleet_total += GameState.get_cargo_fleet_count(wood_trait.destination_id)
	if fleet_total > 0:
		var fleet_pad := Node3D.new()
		fleet_pad.name = "CargoFleetPad"
		fleet_pad.position = Vector3(2.25, 0.18, -3.05)
		_yard_stage_root.add_child(fleet_pad)
		for index in range(mini(fleet_total, 6)):
			_box(fleet_pad, "CargoShuttle%d" % index, Vector3(0.42, 0.16, 0.24),
				Vector3(float(index % 3) * 0.52, float(index / 3) * 0.22, 0),
				Color(0.38, 0.46, 0.58, 1))


## For now the upgrade is the existing authored stump with a cool reinforced
## colour treatment. No replacement geometry is invented; a marker child keeps
## the visible state discoverable to tests and artists in the scene tree.
func _set_block_variant(game: Node, definition: EquipmentDef) -> void:
	var stump: MeshInstance3D = game.get_node_or_null("StumpMesh")
	if stump == null or stump.mesh == null:
		return
	for surface in range(stump.mesh.get_surface_count()):
		stump.set_surface_override_material(surface, null)
	if definition == null or definition.is_starting_fallback:
		stump.remove_meta("art_status")
		stump.remove_meta("equipment_id")
		return
	var tint := definition.placeholder_tint if definition.progression_stage > 0 \
		else _REINFORCED_BLOCK_TINT
	stump.set_meta("art_status", "temporary_colour_variant_existing_chopping_block_stage_%d"
		% definition.progression_stage)
	stump.set_meta("equipment_id", definition.id)
	for surface in range(stump.mesh.get_surface_count()):
		stump.set_surface_override_material(surface,
			_tinted_material(stump.get_active_material(surface), tint))
	var root := Node3D.new()
	root.name = String(definition.ownership_upgrade_id)
	root.set_meta("art_status", "temporary_colour_variant_existing_chopping_block")
	add_child(root)


func has_block_color_variant() -> bool:
	var game := get_parent()
	var stump: MeshInstance3D = game.get_node_or_null("StumpMesh")
	if stump == null or stump.mesh == null:
		return false
	for surface in range(stump.mesh.get_surface_count()):
		if stump.get_surface_override_material(surface) != null:
			return true
	return false


func _build_ledger() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_SUPPLIER_LEDGER)
	root.set_meta("art_status", "placeholder_graphic_integrated_pending_final_3d_asset")
	root.position = Vector3(-0.68, 0.055, 0.28)
	root.rotation_degrees = Vector3(-8, -18, 0)
	add_child(root)
	_box(root, "Cover", Vector3(0.30, 0.025, 0.22), Vector3.ZERO, _DARK_WOOD)
	_box(root, "Pages", Vector3(0.27, 0.014, 0.19), Vector3(0, 0.020, 0), _PAPER)
	_textured_panel(root, "SupplierLedgerGraphic", Vector2(0.24, 0.18),
		Vector3(0, 0.08, 0.13), "res://assets/ui/placeholders/supplier_ledger.svg")


func _build_handcart() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_HANDCART)
	root.set_meta("art_status", "placeholder_graphic_integrated_pending_final_3d_asset")
	root.position = Vector3(0.72, 0.17, 0.38)
	root.rotation_degrees.y = -18.0
	add_child(root)
	_box(root, "Bed", Vector3(0.62, 0.12, 0.34), Vector3.ZERO, _WOOD)
	_box(root, "LeftRail", Vector3(0.62, 0.20, 0.04), Vector3(0, 0.14, -0.17), _DARK_WOOD)
	_box(root, "RightRail", Vector3(0.62, 0.20, 0.04), Vector3(0, 0.14, 0.17), _DARK_WOOD)
	_box(root, "Handle", Vector3(0.48, 0.035, 0.035), Vector3(-0.48, 0.03, 0), _DARK_WOOD)
	_wheel(root, "WheelNear", Vector3(0.02, -0.11, 0.22))
	_wheel(root, "WheelFar", Vector3(0.02, -0.11, -0.22))
	_textured_panel(root, "HandcartGraphic", Vector2(0.28, 0.20),
		Vector3(0.08, 0.18, 0.185), "res://assets/ui/placeholders/handcart.svg")


func _build_thermos() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_COFFEE_THERMOS)
	root.set_meta("art_status", "placeholder_graphic_integrated_pending_final_3d_asset")
	root.position = Vector3(-0.54, 0.17, 0.48)
	add_child(root)
	_cylinder(root, "Body", 0.065, 0.30, Vector3.ZERO, _COFFEE)
	_cylinder(root, "Cap", 0.071, 0.045, Vector3(0, 0.172, 0), _METAL)
	for i in range(3):
		var steam := SphereMesh.new()
		steam.radius = 0.018 - float(i) * 0.003
		steam.height = steam.radius * 2.0
		var puff := MeshInstance3D.new()
		puff.name = "Steam%d" % i
		puff.mesh = steam
		puff.position = Vector3(0.008 * (i % 2), 0.23 + i * 0.055, 0)
		puff.material_override = _material(Color(0.8, 0.85, 0.82, 0.42), true)
		root.add_child(puff)
	_textured_panel(root, "ThermosGraphic", Vector2(0.18, 0.14),
		Vector3(0.13, 0.04, 0.02), "res://assets/ui/placeholders/coffee_thermos.svg")


## Native-node placeholder geometry with a vector equipment plate. It remains
## intentionally replaceable by a final authored machine model.
func _build_mechanical_splitter() -> void:
	var machine := MechanicalSplitter.machine_definition()
	if machine == null:
		return
	_splitter_root = Node3D.new()
	_splitter_root.name = String(machine.id)
	_splitter_root.set_meta("art_status",
		"placeholder_graphic_integrated_pending_final_3d_asset")
	_splitter_root.position = Vector3(-1.22, 0.34, -0.72)
	_splitter_rest_position = _splitter_root.position
	_splitter_root.rotation_degrees.y = 12.0
	add_child(_splitter_root)

	_box(_splitter_root, "Skid", Vector3(1.10, 0.12, 0.48),
		Vector3(0, -0.28, 0), _DARK_WOOD)
	_box(_splitter_root, "Body", Vector3(0.62, 0.48, 0.42),
		Vector3(-0.18, 0.02, 0), _SPLITTER_BODY)
	_box(_splitter_root, "Guard", Vector3(0.20, 0.42, 0.46),
		Vector3(-0.48, 0.04, 0), _SPLITTER_GUARD)
	_box(_splitter_root, "Bed", Vector3(0.72, 0.10, 0.28),
		Vector3(0.42, -0.02, 0), _METAL)
	_splitter_ram = _box(_splitter_root, "Ram", Vector3(0.18, 0.24, 0.24),
		Vector3(0.08, 0.12, 0), _SPLITTER_GUARD)
	_box(_splitter_root, "Blade", Vector3(0.055, 0.42, 0.34),
		Vector3(0.66, 0.15, 0), _SPLITTER_BLADE)
	_splitter_wheel = _cylinder(_splitter_root, "Flywheel", 0.22, 0.08,
		Vector3(-0.20, 0.08, 0.25), _SPLITTER_GUARD)
	_splitter_wheel.rotation_degrees.x = 90.0
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.11
	log_mesh.bottom_radius = 0.12
	log_mesh.height = 0.42
	log_mesh.radial_segments = 14
	_splitter_log = MeshInstance3D.new()
	_splitter_log.name = "RepresentativeAssignedLog"
	_splitter_log.mesh = log_mesh
	_splitter_log.position = Vector3(0.39, 0.14, 0)
	_splitter_log.rotation_degrees.z = 90.0
	_splitter_log.material_override = _material(Color(0.31, 0.13, 0.045, 1.0))
	_splitter_log.set_meta("art_status",
		"single_preauthored_log_proxy_no_runtime_slicing")
	_splitter_log.visible = false
	_splitter_root.add_child(_splitter_log)
	var end_mesh := CylinderMesh.new()
	end_mesh.top_radius = 0.11
	end_mesh.bottom_radius = 0.11
	end_mesh.height = 0.006
	end_mesh.radial_segments = 14
	for index in range(2):
		var end := MeshInstance3D.new()
		end.name = "InsideEnd%d" % index
		end.mesh = end_mesh
		end.position.y = -0.213 if index == 0 else 0.213
		end.material_override = _material(Color(0.72, 0.52, 0.28, 1.0))
		_splitter_log.add_child(end)
		_splitter_log_ends.append(end)

	_splitter_label = Label3D.new()
	_splitter_label.name = "MissingArtAndStateLabel"
	_splitter_label.position = Vector3(0, 0.73, 0)
	_splitter_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_splitter_label.fixed_size = true
	_splitter_label.no_depth_test = true
	_splitter_label.font_size = 8
	_splitter_label.outline_size = 3
	_splitter_label.modulate = Color(0.76, 0.72, 0.64, 0.82)
	_splitter_root.add_child(_splitter_label)
	_splitter_state_label = Label3D.new()
	_splitter_state_label.name = "OperationalStateLabel"
	_splitter_state_label.position = Vector3(0, 0.61, 0)
	_splitter_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_splitter_state_label.fixed_size = true
	_splitter_state_label.no_depth_test = true
	_splitter_state_label.font_size = 14
	_splitter_state_label.outline_size = 4
	_splitter_state_label.modulate = Color(1.0, 0.92, 0.68, 1.0)
	_splitter_root.add_child(_splitter_state_label)
	_textured_panel(_splitter_root, "MechanicalSplitterGraphic", Vector2(0.52, 0.30),
		Vector3(-0.12, 0.25, 0.245),
		"res://assets/ui/placeholders/mechanical_splitter.svg")
	_refresh_splitter_runtime()


func _process(delta: float) -> void:
	if _yard_vehicle != null:
		_yard_vehicle_phase = fposmod(_yard_vehicle_phase + delta * 0.11, 1.0)
		# Slow scheduled arrival/departure loop; authored bounds avoid vehicle
		# allocation or node growth while the yard remains open.
		var travel := sin(_yard_vehicle_phase * TAU) * 1.28
		_yard_vehicle.position.x = travel
		_yard_vehicle.rotation_degrees.y = 0.0 if cos(_yard_vehicle_phase * TAU) >= 0.0 else 180.0
	if _splitter_runtime == null or _splitter_root == null:
		return
	if _splitter_runtime.current_state() == MechanicalSplitterRuntime.State.PROCESSING:
		if _splitter_wheel != null:
			_splitter_wheel.rotate_y(delta * 7.0)
		if _splitter_ram != null:
			_splitter_ram.position.x = lerpf(0.08, 0.50,
				_splitter_runtime.progress())
		if _splitter_log != null:
			_splitter_log.visible = true
			_splitter_log.position.x = lerpf(0.36, 0.48,
				_splitter_runtime.progress())
	elif _splitter_ram != null:
		_splitter_ram.position.x = 0.08
		if _splitter_log != null:
			_splitter_log.visible = false
	if _splitter_completion_left > 0.0:
		_splitter_completion_left = maxf(0.0, _splitter_completion_left - delta)
		var phase := 1.0 - _splitter_completion_left / 0.28
		var pulse := sin(phase * PI)
		_splitter_root.position = _splitter_rest_position + Vector3.UP * pulse * 0.025
		_splitter_root.scale = Vector3(1.0 + pulse * 0.025,
			1.0 - pulse * 0.012, 1.0 + pulse * 0.025)
	else:
		_splitter_root.position = _splitter_rest_position
		_splitter_root.scale = Vector3.ONE


func _refresh_splitter_runtime() -> void:
	if _splitter_runtime == null or _splitter_label == null:
		return
	_splitter_label.text = "MECHANICAL SPLITTER · PLACEHOLDER"
	if _splitter_state_label != null:
		_splitter_state_label.text = MechanicalSplitterRuntime.state_title(
			_splitter_runtime.current_state())
	var assigned := GameState.get_splitter_assigned_species()
	if _splitter_log != null and assigned != _splitter_skin_species:
		_splitter_skin_species = assigned
		var species := SpeciesTable.by_id(assigned)
		if species != null:
			var material := _material(species.bark_tint)
			if species.bark_tex != "":
				var texture := load(species.bark_tex) as Texture2D
				if texture != null:
					material.albedo_texture = texture
			_splitter_log.material_override = material
			var inside_material := _material(species.inside_tint)
			if species.inside_tex != "":
				var inside_texture := load(species.inside_tex) as Texture2D
				if inside_texture != null:
					inside_material.albedo_texture = inside_texture
			for end: MeshInstance3D in _splitter_log_ends:
				end.material_override = inside_material


func _on_splitter_cycle_completed(_species_id: StringName, _item_id: StringName,
		_amount: int, _receipt_id: StringName) -> void:
	_splitter_completion_left = 0.28


func splitter_output_world_position() -> Vector3:
	if _splitter_root != null and is_instance_valid(_splitter_root):
		return _splitter_root.to_global(Vector3(0.72, 0.22, 0.0))
	return to_global(Vector3(-0.50, 0.56, -0.72))


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3,
		colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(colour)
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float,
		pos: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(colour)
	parent.add_child(node)
	return node


func _wheel(parent: Node3D, node_name: String, pos: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.15
	mesh.height = 0.045
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees.z = 90.0
	node.material_override = _material(_DARK_WOOD)
	parent.add_child(node)


func _textured_panel(parent: Node3D, node_name: String, size: Vector2,
		pos: Vector3, texture_path: String) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path) as Texture2D
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.set_meta("art_status", "replaceable_ai_generated_candidate")
	parent.add_child(node)
	return node


func _material(colour: Color, transparent := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.82
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _tinted_material(source: Material, tint: Color) -> Material:
	if source is BaseMaterial3D:
		var material := source.duplicate() as BaseMaterial3D
		var colour := material.albedo_color
		material.albedo_color = Color(colour.r * tint.r, colour.g * tint.g,
			colour.b * tint.b, colour.a)
		return material
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = tint
	fallback.roughness = 0.8
	return fallback
