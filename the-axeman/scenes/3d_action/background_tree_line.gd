extends Node3D
## Non-interactive low-poly scenery for the chopping-block horizon. These trees
## have no collision, gameplay state, felling behavior, or progression meaning.

const TREE_DEF := preload(
	"res://scenes/3d_action/background_tree_line_placeholder.tres")


func _ready() -> void:
	_build_trunks()
	_build_canopies()


func _build_trunks() -> void:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.12
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _trunk_material()

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = TREE_DEF.tree_count()
	for index in range(TREE_DEF.tree_count()):
		var position := TREE_DEF.positions[index]
		var scale_factor := TREE_DEF.scales[index]
		var yaw := TREE_DEF.yaws[index]
		var trunk_height := TREE_DEF.trunk_height * scale_factor
		var trunk_radius := TREE_DEF.trunk_radius * scale_factor
		var basis := Basis(Vector3.UP, yaw).scaled(
			Vector3(trunk_radius, trunk_height, trunk_radius))
		multimesh.set_instance_transform(index, Transform3D(
			basis, position + Vector3.UP * trunk_height * 0.5))
		multimesh.set_instance_color(index,
			TREE_DEF.trunk_dark.lerp(TREE_DEF.trunk_light, float(index % 3) / 2.0))

	var instances := MultiMeshInstance3D.new()
	instances.name = "Trunks"
	instances.multimesh = multimesh
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instances)


func _build_canopies() -> void:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = _canopy_material()

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = TREE_DEF.tree_count() * TREE_DEF.canopy_layer_count()
	var instance_index := 0
	for tree_index in range(TREE_DEF.tree_count()):
		var position := TREE_DEF.positions[tree_index]
		var scale_factor := TREE_DEF.scales[tree_index]
		var yaw := TREE_DEF.yaws[tree_index]
		var foliage := TREE_DEF.foliage_dark.lerp(
			TREE_DEF.foliage_light, float(tree_index % 4) / 3.0)
		for layer_index in range(TREE_DEF.canopy_layer_count()):
			var centre_y := TREE_DEF.canopy_centres[layer_index] * scale_factor
			var height := TREE_DEF.canopy_heights[layer_index] * scale_factor
			var radius := TREE_DEF.canopy_radii[layer_index] * scale_factor
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(radius, height, radius))
			multimesh.set_instance_transform(instance_index, Transform3D(
				basis, position + Vector3.UP * centre_y))
			multimesh.set_instance_color(instance_index, foliage)
			instance_index += 1

	var instances := MultiMeshInstance3D.new()
	instances.name = "Canopies"
	instances.multimesh = multimesh
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instances)


func _trunk_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	return material


func _canopy_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	return material
