class_name SurvivalRunTuning
extends Resource
## Provisional tuning for the timed log-survival loop. None of these values are
## final until a measured 25-40 minute mature-profile Earth-clear run and a
## representative boundary/powerup feel session have been approved by Sam.

@export_group("Arena — PLACEHOLDER")
@export_range(1.0, 8.0, 0.05) var boundary_radius := 2.35
@export_range(0.5, 15.0, 0.1) var boundary_grace_seconds := 5.0
@export_range(1.0, 8.0, 0.1) var arrival_height := 3.4
@export_range(0.0, 4.0, 0.05) var arrival_lateral_speed := 0.45
@export_range(0.1, 4.0, 0.05) var spawn_inner_radius := 0.85
@export_range(0.2, 6.0, 0.05) var spawn_outer_radius := 1.85
@export_range(1, 32, 1) var spawn_sample_count := 12

@export_group("Delivery — PLACEHOLDER")
## Ordered slowest to fastest. Delivery Control skills reveal later entries;
## the selected tier is an attempt preference, never an irreversible speed-up.
@export var delivery_intervals := PackedFloat32Array([6.5, 5.2, 4.1, 3.2])

@export_group("Earth batches — PLACEHOLDER")
## Rank zero is always present. Costs buy ranks 1..N and are paid from attempt
## cash while the resulting Harvest Capacity rank persists through death.
@export var earth_batch_sizes := PackedInt64Array([
	1000000, 10000000, 100000000, 500000000, 1000000000,
	3000000000, 7500000000,
])
@export var harvest_capacity_costs := PackedInt64Array([
	250, 2500, 25000, 250000, 2500000, 25000000,
])

@export_group("Powerups — PLACEHOLDER")
@export_range(0.0, 1.0, 0.01) var powerup_drop_chance := 0.16
@export_range(0.0, 1.0, 0.01) var slow_time_weight := 0.45
@export_range(1, 9, 1) var slow_time_charge_cap := 3
@export_range(1, 99, 1) var blaster_ammo_cap := 12
@export_range(1, 20, 1) var blaster_ammo_per_drop := 3
@export_range(0.1, 0.95, 0.05) var slow_hazard_multiplier := 0.45
@export_range(0.5, 20.0, 0.1) var slow_time_duration := 6.0
@export_range(0.1, 30.0, 0.1) var blaster_impulse := 7.0

@export_group("Run splitter — PLACEHOLDER")
@export var splitter_purchase_cost: int = 150
@export var splitter_reliability_costs := PackedInt64Array([250, 650, 1600, 4000])
@export_range(0.5, 30.0, 0.1) var splitter_cycle_seconds := 8.0
@export_range(0.0, 1.0, 0.01) var splitter_base_chance := 0.12
@export_range(0.0, 1.0, 0.01) var splitter_chance_per_rank := 0.14

@export_group("Presentation — PLACEHOLDER")
@export_range(0.05, 2.0, 0.05) var block_hop_seconds := 0.38
@export_range(0.0, 3.0, 0.05) var block_hop_height := 0.75
## Horizontal clearance maintained while a claimed log arcs around the camera.
@export_range(0.2, 2.0, 0.05) var block_hop_camera_clearance := 0.72
## Physical yard landmarks are pushed this far beyond the danger circle so
## their complete silhouettes, rather than only their pivots, remain outside.
@export_range(0.2, 3.0, 0.05) var yard_prop_clearance := 1.35
## The boundary is a translucent ribbon: a narrow peak with a soft fade on both
## its inside and outside edges.
@export_range(0.005, 0.25, 0.005) var boundary_core_half_width := 0.025
@export_range(0.05, 0.8, 0.01) var boundary_gradient_width := 0.18
@export_range(0.05, 1.0, 0.05) var boundary_peak_alpha := 0.55
@export_range(1, 64, 1) var loose_log_soft_cap := 28

@export_multiline var tuning_status := (
	"PLACEHOLDER — survival pacing, boundary, powerup, splitter and presentation "
	+ "values require measured playtest approval from Sam")


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if boundary_radius <= 0.0 or boundary_grace_seconds <= 0.0:
		errors.append("boundary radius and grace must be positive")
	if spawn_inner_radius >= spawn_outer_radius or spawn_outer_radius >= boundary_radius:
		errors.append("spawn radii must be ordered and stay inside the boundary")
	if block_hop_camera_clearance <= 0.0 or yard_prop_clearance <= 0.0:
		errors.append("camera and yard presentation clearances must be positive")
	if boundary_core_half_width <= 0.0 \
			or boundary_gradient_width <= boundary_core_half_width \
			or boundary_gradient_width >= boundary_radius:
		errors.append("boundary gradient must extend beyond its core and fit the arena")
	if delivery_intervals.is_empty():
		errors.append("at least one delivery interval is required")
	for seconds: float in delivery_intervals:
		if seconds <= 0.0:
			errors.append("delivery intervals must be positive")
	if earth_batch_sizes.is_empty() or earth_batch_sizes.size() != harvest_capacity_costs.size() + 1:
		errors.append("Earth batch ranks must have exactly one more entry than their costs")
	var last_batch: int = 0
	for batch: int in earth_batch_sizes:
		if batch <= last_batch:
			errors.append("Earth batch sizes must increase strictly")
		last_batch = batch
	if slow_hazard_multiplier <= 0.0 or slow_hazard_multiplier >= 1.0:
		errors.append("Slow Time hazard multiplier must be between zero and one")
	if splitter_purchase_cost <= 0 or splitter_cycle_seconds <= 0.0:
		errors.append("splitter purchase and cycle values must be positive")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("survival tuning must remain explicitly provisional")
	return errors
