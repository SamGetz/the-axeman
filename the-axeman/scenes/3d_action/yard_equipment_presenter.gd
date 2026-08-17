class_name YardEquipmentPresenter
extends Node3D
## Static yard dressing kept outside the active log boundary.

const _WOOD := Color(0.31, 0.15, 0.055, 1.0)
const _DARK_WOOD := Color(0.12, 0.055, 0.018, 1.0)
const _SURVIVAL_TUNING := preload("res://data/survival_run_tuning_placeholder.tres")


func _ready() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	_build_yard_sign()
	_build_equipment_rack()


func _build_yard_sign() -> void:
	var root := _root("YardSign", Vector3(1.38, 0.0, -1.42))
	_box(root, "Post", Vector3(0.08, 0.72, 0.08), Vector3(0, 0.36, 0), _DARK_WOOD)
	_box(root, "Board", Vector3(0.92, 0.38, 0.07), Vector3(0, 0.70, 0), _WOOD)
	_label(root, "CAMPFIRE SURVIVORS\nYARD ONE", Vector3(0, 0.70, 0.045), 18)


func _build_equipment_rack() -> void:
	var root := _root("EquipmentRack", Vector3(1.73, 0.0, -0.72))
	_box(root, "UprightL", Vector3(0.08, 0.90, 0.08), Vector3(-0.34, 0.45, 0), _DARK_WOOD)
	_box(root, "UprightR", Vector3(0.08, 0.90, 0.08), Vector3(0.34, 0.45, 0), _DARK_WOOD)
	_box(root, "Crossbar", Vector3(0.78, 0.08, 0.08), Vector3(0, 0.76, 0), _WOOD)
	_label(root, "STARTER AXE\nSTARTER BLOCK", Vector3(0, 0.38, 0.045), 10)


func _root(node_name: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = _clear_of_arena(at)
	add_child(root)
	return root


func _clear_of_arena(at: Vector3) -> Vector3:
	var clear_radius := _SURVIVAL_TUNING.boundary_radius \
		+ _SURVIVAL_TUNING.yard_prop_clearance
	var horizontal := Vector2(at.x, at.z)
	if horizontal.length() >= clear_radius:
		return at
	if horizontal.length_squared() < 0.000001:
		horizontal = Vector2.RIGHT
	horizontal = horizontal.normalized() * clear_radius
	return Vector3(horizontal.x, at.y, horizontal.y)


func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.name = node_name
	view.mesh = mesh
	view.position = at
	view.material_override = _material(color)
	parent.add_child(view)
	return view


func _label(parent: Node3D, content: String, at: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = content
	label.position = at
	label.font_size = size
	label.outline_size = 3
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.92, 0.72, 1.0)
	parent.add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	return material
