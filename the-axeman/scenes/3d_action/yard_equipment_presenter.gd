class_name YardEquipmentPresenter
extends Node3D
## FILE: res://scenes/3d_action/yard_equipment_presenter.gd
## ATTACHES TO: YardEquipment (Node3D), a child of Chopping_Minigame in
## res://scenes/3d_action/chopping_minigame.tscn.
##
## Physical view of shop-owned progression. It owns no state: every refresh reads
## Shop/GameState, and it refreshes both after a purchase and after save restore.
## The primitive props are approved greyboxes while final authored art/audio are
## absent. Compatibility-safe native MeshInstance3D nodes only.

const _WOOD := Color(0.32, 0.17, 0.07, 1.0)
const _DARK_WOOD := Color(0.14, 0.07, 0.025, 1.0)
const _METAL := Color(0.28, 0.32, 0.34, 1.0)
const _PAPER := Color(0.82, 0.72, 0.48, 1.0)
const _COFFEE := Color(0.16, 0.30, 0.25, 1.0)


func _ready() -> void:
	GameState.building_tiers_changed.connect(refresh)
	# Parent builds the runtime stump in its _ready; wait until that has happened
	# before measuring its real imported mesh.
	refresh.call_deferred()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var game := get_parent()
	var axe: AxeViewmodel = game.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor")
	if axe != null:
		axe.set_balanced_upgrade(Shop.get_level(GameState.UPGRADE_BALANCED_AXE) > 0)

	if Shop.get_level(GameState.UPGRADE_REINFORCED_BLOCK) > 0:
		_build_reinforced_block(game)
	if Shop.get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0:
		_build_ledger()
	if Shop.get_level(GameState.UPGRADE_HANDCART) > 0:
		_build_handcart()
	if Shop.get_level(GameState.UPGRADE_COFFEE_THERMOS) > 0:
		_build_thermos()


func has_physical(id: StringName) -> bool:
	return get_node_or_null(String(id)) != null


func _build_reinforced_block(game: Node) -> void:
	var stump: MeshInstance3D = game.get_node_or_null("StumpMesh")
	if stump == null or stump.mesh == null:
		return
	var aabb := stump.mesh.get_aabb()
	var top_y := stump.position.y + aabb.position.y + aabb.size.y
	var base_radius := maxf(aabb.size.x, aabb.size.z) * 0.5
	var bonus := Shop.total_effect(UpgradeDef.Effect.WORK_RADIUS)
	var radius := base_radius * (1.0 + bonus)
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_REINFORCED_BLOCK)
	add_child(root)
	_cylinder(root, "WorkSurface", radius, 0.035, Vector3(0, top_y - 0.0175, 0), _WOOD)
	_cylinder(root, "UpperBand", base_radius * 1.02, 0.035, Vector3(0, top_y - 0.10, 0), _METAL)
	_cylinder(root, "LowerBand", base_radius * 1.02, 0.035, Vector3(0, top_y - 0.30, 0), _METAL)


func _build_ledger() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_SUPPLIER_LEDGER)
	root.position = Vector3(-0.68, 0.055, 0.28)
	root.rotation_degrees = Vector3(-8, -18, 0)
	add_child(root)
	_box(root, "Cover", Vector3(0.30, 0.025, 0.22), Vector3.ZERO, _DARK_WOOD)
	_box(root, "Pages", Vector3(0.27, 0.014, 0.19), Vector3(0, 0.020, 0), _PAPER)


func _build_handcart() -> void:
	var root := Node3D.new()
	root.name = String(GameState.UPGRADE_HANDCART)
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


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(colour)
	parent.add_child(node)


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float,
		pos: Vector3, colour: Color) -> void:
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
