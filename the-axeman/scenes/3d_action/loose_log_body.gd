class_name LooseLogBody
extends RigidBody3D

var descriptor: LogDescriptor
var boundary_exposure := 0.0
var landed := false
## Live floor contact, intentionally not persisted: restored bodies must prove a
## fresh physics contact before ground-only forces can affect them.
var grounded := false
## Delivery gravity is snapshotted from survival tuning at spawn.
var arrival_gravity_scale := 1.0
## Yard Magnet owns this ramp while grounded. Keeping it outside the physics
## velocity prevents floor contacts from resetting a smooth pull to zero.
var magnet_drag_speed := 0.0
var magnet_engaged := false
var magnet_restore_linear_damp := 0.38
var magnet_dock_direction := Vector2.ZERO
var magnet_dock_radius := 0.0
## Delivery-snapshotted Soft Landing value. Existing loose roots keep the bounce
## they arrived with when the power is ranked later in the same attempt.
var arrival_bounce_multiplier := 1.0
## Hot-path presentation state. LooseLogArena owns the contents; keeping the
## current descendants here avoids allocating and filtering get_children() arrays
## for every target, warning, collision rebuild, and visibility pass.
var piece_visuals: Array[MeshInstance3D] = []
var collision_shapes: Array[CollisionShape3D] = []
var warning_active := false
var warning_decisecond := -1
var batched_visual := false
var batch_key := 0


func to_save_dict() -> Dictionary:
	return {
		"descriptor": descriptor.to_dict() if descriptor != null else {},
		"transform": global_transform,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity,
		"boundary_exposure": boundary_exposure,
		"landed": landed,
		"arrival_bounce_multiplier": arrival_bounce_multiplier,
	}
