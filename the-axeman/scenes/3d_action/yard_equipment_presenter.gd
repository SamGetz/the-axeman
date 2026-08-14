class_name YardEquipmentPresenter
extends Node3D
## A deliberately small, read-only physical record of permanent yard progress
## and the current attempt's disposable splitter. Economy state remains in
## GameState/RunDirector; this presenter only redraws it.

const _WOOD := Color(0.31, 0.15, 0.055, 1.0)
const _DARK_WOOD := Color(0.12, 0.055, 0.018, 1.0)
const _PAPER := Color(0.88, 0.78, 0.54, 1.0)
const _METAL := Color(0.28, 0.34, 0.36, 1.0)
const _ORANGE := Color(0.82, 0.34, 0.075, 1.0)
const _GREEN := Color(0.20, 0.38, 0.25, 1.0)
const _HARVEST := Color(0.69, 0.48, 0.18, 1.0)
const _SURVIVAL_TUNING := preload("res://data/survival_run_tuning_placeholder.tres")

var _run: RunDirector
var _splitter_root: Node3D
var _splitter_ram: MeshInstance3D
var _splitter_installed_shown := false
var _splitter_rank_shown := -1


func _ready() -> void:
	GameState.building_tiers_changed.connect(refresh)
	GameState.earth_clear_record_changed.connect(refresh)
	refresh.call_deferred()


func _process(delta: float) -> void:
	if _splitter_ram == null or _run == null:
		return
	var state := _run.get_splitter_state()
	var cycle := maxf(0.01, _run.tuning.splitter_cycle_seconds)
	var phase := 1.0 - clampf(float(state.get("seconds_left", cycle)) / cycle, 0.0, 1.0)
	_splitter_ram.position.z = -0.28 + sin(phase * TAU) * 0.16
	_splitter_root.rotation.y += delta * 0.08


func bind_run_director(run: RunDirector) -> void:
	if _run != null and _run.splitter_changed.is_connected(_on_splitter_changed):
		_run.splitter_changed.disconnect(_on_splitter_changed)
	_run = run
	if _run != null:
		_run.splitter_changed.connect(_on_splitter_changed)
		var state := _run.get_splitter_state()
		_splitter_installed_shown = bool(state.get("installed", false))
		_splitter_rank_shown = int(state.get("reliability_rank", 0))
	refresh()


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	_splitter_root = null
	_splitter_ram = null
	_build_yard_sign()
	_build_equipment_rack()
	if Shop.get_level(GameState.UPGRADE_SUPPLIER_LEDGER) > 0:
		_build_ledger()
	if Shop.get_level(GameState.UPGRADE_HANDCART) > 0:
		_build_handcart()
	if Shop.get_level(GameState.UPGRADE_COFFEE_THERMOS) > 0:
		_build_thermos()
	_build_harvest_crates(GameState.get_permanent_upgrade_level(
		GameState.UPGRADE_HARVEST_CAPACITY))
	if _run != null and bool(_run.get_splitter_state().get("installed", false)):
		_build_splitter()
	if GameState.has_cleared_earth():
		_build_earth_memorial()
	_apply_active_equipment()


func has_physical(id: StringName) -> bool:
	return get_node_or_null(String(id)) != null


func visible_yard_stage() -> int:
	return mini(4, GameState.get_permanent_upgrades().size() / 3)


func stage_has_landmark(name: StringName) -> bool:
	return get_node_or_null(String(name)) != null


func splitter_output_world_position() -> Vector3:
	if is_instance_valid(_splitter_root):
		return _splitter_root.global_position + Vector3(0.0, 0.46, 0.0)
	return global_position + _clear_of_arena(Vector3(-1.65, 0.46, -1.36))


func _on_splitter_changed(installed: bool, rank: int, _seconds: float) -> void:
	if installed == _splitter_installed_shown and rank == _splitter_rank_shown:
		return
	_splitter_installed_shown = installed
	_splitter_rank_shown = rank
	refresh()


func _build_yard_sign() -> void:
	var root := _root("YardSign", Vector3(1.38, 0.0, -1.42))
	_box(root, "Post", Vector3(0.08, 0.72, 0.08), Vector3(0, 0.36, 0), _DARK_WOOD)
	_box(root, "Board", Vector3(0.92, 0.38, 0.07), Vector3(0, 0.70, 0), _WOOD)
	_label(root, "THE AXEMAN\nEARTH YARD", Vector3(0, 0.70, 0.045), 18)


func _build_equipment_rack() -> void:
	var root := _root("EquipmentRack", Vector3(1.73, 0.0, -0.72))
	_box(root, "UprightL", Vector3(0.08, 0.90, 0.08), Vector3(-0.34, 0.45, 0), _DARK_WOOD)
	_box(root, "UprightR", Vector3(0.08, 0.90, 0.08), Vector3(0.34, 0.45, 0), _DARK_WOOD)
	_box(root, "Crossbar", Vector3(0.78, 0.08, 0.08), Vector3(0, 0.76, 0), _WOOD)
	var active_axe := Shop.active_equipment(UpgradeDef.EquipmentSlot.AXE)
	var active_block := Shop.active_equipment(UpgradeDef.EquipmentSlot.WORKSTATION)
	_label(root, "%s\n%s" % [
		"STARTER AXE" if active_axe == null else active_axe.display_name.to_upper(),
		"STARTER BLOCK" if active_block == null else active_block.display_name.to_upper(),
	], Vector3(0, 0.38, 0.045), 10)


func _build_ledger() -> void:
	var root := _root(String(GameState.UPGRADE_SUPPLIER_LEDGER), Vector3(1.08, 0.0, -0.65))
	_box(root, "Desk", Vector3(0.62, 0.10, 0.42), Vector3(0, 0.46, 0), _WOOD)
	_box(root, "Book", Vector3(0.35, 0.035, 0.25), Vector3(0, 0.54, 0), _PAPER)
	_label(root, "LEDGER", Vector3(0, 0.57, 0.13), 11)


func _build_handcart() -> void:
	var root := _root(String(GameState.UPGRADE_HANDCART), Vector3(-1.48, 0.0, -1.25))
	_box(root, "Bed", Vector3(0.82, 0.18, 0.48), Vector3(0, 0.36, 0), _WOOD)
	for x: float in [-0.34, 0.34]:
		var wheel := _cylinder(root, "Wheel", 0.22, 0.06, Vector3(x, 0.22, 0.28), _DARK_WOOD)
		wheel.rotation_degrees.x = 90.0
	_box(root, "Handle", Vector3(0.08, 0.08, 0.78), Vector3(0, 0.40, -0.54), _DARK_WOOD)


func _build_thermos() -> void:
	var root := _root(String(GameState.UPGRADE_COFFEE_THERMOS), Vector3(0.96, 0.0, -0.88))
	_cylinder(root, "Thermos", 0.07, 0.30, Vector3(0, 0.62, 0), _GREEN)
	_label(root, "COFFEE", Vector3(0, 0.86, 0), 9)


func _build_harvest_crates(rank: int) -> void:
	if rank <= 0:
		return
	var root := _root(String(GameState.UPGRADE_HARVEST_CAPACITY), Vector3(-0.90, 0.0, -1.76))
	for index: int in range(mini(rank, 7)):
		var column := index % 3
		var row := index / 3
		_box(root, "BatchCrate%d" % index, Vector3(0.42, 0.33, 0.38),
			Vector3(float(column) * 0.45, 0.18 + float(row) * 0.34, 0), _HARVEST)
	_label(root, "HARVEST x%d" % rank, Vector3(0.45, 0.86, 0.22), 12)


func _build_splitter() -> void:
	_splitter_root = _root("RunSplitter", Vector3(-1.65, 0.0, -1.36))
	_box(_splitter_root, "Base", Vector3(0.88, 0.16, 0.58), Vector3(0, 0.20, 0), _METAL)
	_box(_splitter_root, "Guard", Vector3(0.12, 0.58, 0.52), Vector3(0, 0.52, 0), _ORANGE)
	_splitter_ram = _box(_splitter_root, "Ram", Vector3(0.42, 0.12, 0.12),
		Vector3(0, 0.50, -0.28), Color(0.72, 0.76, 0.76, 1.0))
	_label(_splitter_root, "RUN SPLITTER", Vector3(0, 0.90, 0), 11)


func _build_earth_memorial() -> void:
	var root := _root("EarthMasterMemorial", Vector3(-2.05, 0.0, -1.90))
	_box(root, "Mount", Vector3(0.76, 0.82, 0.12), Vector3(0, 0.48, 0), _DARK_WOOD)
	var ring := _cylinder(root, "EarthRing", 0.28, 0.05, Vector3(0, 0.50, 0.085),
		Color(0.35, 0.55, 0.24, 1.0))
	ring.rotation_degrees.x = 90.0
	_label(root, "EARTH CLEARED", Vector3(0, 0.12, 0.08), 11)


func _apply_active_equipment() -> void:
	var game := get_parent()
	var axe := game.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor") as AxeViewmodel
	if axe == null:
		return
	var active := Shop.active_equipment(UpgradeDef.EquipmentSlot.AXE)
	if active == null:
		axe.set_equipment_upgrade(&"", 0, Color.WHITE)
	else:
		axe.set_equipment_upgrade(active.id, active.equipment_stage,
			Color(0.60, 0.74, 0.86, 1.0))


func _root(node_name: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = _clear_of_arena(at)
	add_child(root)
	return root


func _clear_of_arena(at: Vector3) -> Vector3:
	var active_tuning: SurvivalRunTuning = _run.tuning if _run != null \
		else _SURVIVAL_TUNING
	var clear_radius := active_tuning.boundary_radius + active_tuning.yard_prop_clearance
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


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
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
