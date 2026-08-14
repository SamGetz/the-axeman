class_name LooseLogBody
extends RigidBody3D

var descriptor: LogDescriptor
var boundary_exposure := 0.0
var landed := false
var hazard_speed := 1.0


func set_hazard_speed(value: float) -> void:
	var next := clampf(value, 0.05, 1.0)
	if is_equal_approx(next, hazard_speed):
		return
	var ratio := next / hazard_speed
	linear_velocity *= ratio
	angular_velocity *= ratio
	hazard_speed = next
	gravity_scale = next * next


func to_save_dict() -> Dictionary:
	return {
		"descriptor": descriptor.to_dict() if descriptor != null else {},
		"transform": global_transform,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity,
		"boundary_exposure": boundary_exposure,
		"landed": landed,
	}
