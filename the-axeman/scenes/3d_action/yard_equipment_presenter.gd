class_name YardEquipmentPresenter
extends Node3D
## FILE: res://scenes/3d_action/yard_equipment_presenter.gd
## ATTACHES TO: YardEquipment (Node3D), a child of Chopping_Minigame in
## res://scenes/3d_action/chopping_minigame.tscn.
##
## Physical view of shop-owned progression. It owns no state: every refresh reads
## Shop/GameState, and it refreshes both after a purchase and after save restore.
## Axe/block reuse existing assets as temporary colour variants. The remaining
## primitive props are deliberately visible greyboxes while final authored
## art/audio are absent. Compatibility-safe native MeshInstance3D nodes only.

const _WOOD := Color(0.32, 0.17, 0.07, 1.0)
const _DARK_WOOD := Color(0.14, 0.07, 0.025, 1.0)
const _METAL := Color(0.28, 0.32, 0.34, 1.0)
const _PAPER := Color(0.82, 0.72, 0.48, 1.0)
const _COFFEE := Color(0.16, 0.30, 0.25, 1.0)
const _REINFORCED_BLOCK_TINT := Color(0.58, 0.72, 0.86, 1.0)
const _SPLITTER_BODY := Color(0.19, 0.25, 0.27, 1.0)
const _SPLITTER_GUARD := Color(0.78, 0.43, 0.12, 1.0)
const _SPLITTER_BLADE := Color(0.65, 0.71, 0.73, 1.0)

var _splitter_runtime: MechanicalSplitterRuntime
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
		axe.set_balanced_upgrade(Shop.get_level(GameState.UPGRADE_BALANCED_AXE) > 0)

	_set_reinforced_block_variant(game,
		Shop.get_level(GameState.UPGRADE_REINFORCED_BLOCK) > 0)
	if Shop.get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0:
		_build_ledger()
	if Shop.get_level(GameState.UPGRADE_HANDCART) > 0:
		_build_handcart()
	if Shop.get_level(GameState.UPGRADE_COFFEE_THERMOS) > 0:
		_build_thermos()
	if MechanicalSplitter.is_installed():
		_build_mechanical_splitter()


func has_physical(id: StringName) -> bool:
	return get_node_or_null(String(id)) != null


## For now the upgrade is the existing authored stump with a cool reinforced
## colour treatment. No replacement geometry is invented; a marker child keeps
## the visible state discoverable to tests and artists in the scene tree.
func _set_reinforced_block_variant(game: Node, enabled: bool) -> void:
	var stump: MeshInstance3D = game.get_node_or_null("StumpMesh")
	if stump == null or stump.mesh == null:
		return
	for surface in range(stump.mesh.get_surface_count()):
		stump.set_surface_override_material(surface, null)
	if not enabled:
		stump.remove_meta("art_status")
		return
	stump.set_meta("art_status", "temporary_colour_variant_existing_chopping_block")
	for surface in range(stump.mesh.get_surface_count()):
		stump.set_surface_override_material(surface,
			_tinted_material(stump.get_active_material(surface), _REINFORCED_BLOCK_TINT))
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_REINFORCED_BLOCK)
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
	root.set_meta("art_status", "greybox_missing_authored_ledger_asset")
	root.position = Vector3(-0.68, 0.055, 0.28)
	root.rotation_degrees = Vector3(-8, -18, 0)
	add_child(root)
	_box(root, "Cover", Vector3(0.30, 0.025, 0.22), Vector3.ZERO, _DARK_WOOD)
	_box(root, "Pages", Vector3(0.27, 0.014, 0.19), Vector3(0, 0.020, 0), _PAPER)


func _build_handcart() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_HANDCART)
	root.set_meta("art_status", "greybox_missing_authored_handcart_asset")
	root.position = Vector3(0.72, 0.17, 0.38)
	root.rotation_degrees.y = -18.0
	add_child(root)
	_box(root, "Bed", Vector3(0.62, 0.12, 0.34), Vector3.ZERO, _WOOD)
	_box(root, "LeftRail", Vector3(0.62, 0.20, 0.04), Vector3(0, 0.14, -0.17), _DARK_WOOD)
	_box(root, "RightRail", Vector3(0.62, 0.20, 0.04), Vector3(0, 0.14, 0.17), _DARK_WOOD)
	_box(root, "Handle", Vector3(0.48, 0.035, 0.035), Vector3(-0.48, 0.03, 0), _DARK_WOOD)
	_wheel(root, "WheelNear", Vector3(0.02, -0.11, 0.22))
	_wheel(root, "WheelFar", Vector3(0.02, -0.11, -0.22))


func _build_thermos() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_COFFEE_THERMOS)
	root.set_meta("art_status", "greybox_missing_authored_thermos_asset")
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


## Native-node greybox only. Every piece is an engine primitive and both the
## scene-tree metadata and in-world placard call out the missing authored asset.
func _build_mechanical_splitter() -> void:
	var machine := MechanicalSplitter.machine_definition()
	if machine == null:
		return
	_splitter_root = Node3D.new()
	_splitter_root.name = String(machine.id)
	_splitter_root.set_meta("art_status",
		"greybox_missing_authored_mechanical_splitter_asset")
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
	_refresh_splitter_runtime()


func _process(delta: float) -> void:
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
	_splitter_label.text = "AUTHORED ART MISSING · MECH SPLITTER"
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
