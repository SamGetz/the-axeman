class_name BackgroundTreeLineDef
extends Resource
## Artist-facing placeholder layout for non-interactive horizon trees.

@export var positions: Array[Vector3] = []
@export var scales := PackedFloat32Array()
@export var yaws := PackedFloat32Array()
@export var canopy_centres := PackedFloat32Array()
@export var canopy_heights := PackedFloat32Array()
@export var canopy_radii := PackedFloat32Array()
@export var trunk_height := 4.5
@export var trunk_radius := 0.22
@export var trunk_dark := Color(0.30, 0.19, 0.11)
@export var trunk_light := Color(0.42, 0.27, 0.14)
@export var foliage_dark := Color(0.16, 0.29, 0.14)
@export var foliage_light := Color(0.25, 0.38, 0.17)


func tree_count() -> int:
	return mini(positions.size(), mini(scales.size(), yaws.size()))


func canopy_layer_count() -> int:
	return mini(canopy_centres.size(),
		mini(canopy_heights.size(), canopy_radii.size()))
