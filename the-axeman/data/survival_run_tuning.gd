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
## USER-DIRECTED 2026-08-14 — logs fall at twice the prior speed. Since free-fall
## time scales with the inverse square root of gravity, physics uses this squared.
@export_range(0.25, 4.0, 0.05) var arrival_fall_speed_multiplier := 2.0
@export_range(0.1, 4.0, 0.05) var spawn_inner_radius := 0.85
@export_range(0.2, 6.0, 0.05) var spawn_outer_radius := 1.85
@export_range(1, 32, 1) var spawn_sample_count := 12

@export_group("Delivery — PLACEHOLDER")
## Ordered slowest to fastest. Delivery Control skills reveal later entries;
## the selected tier is an attempt preference, never an irreversible speed-up.
@export var delivery_intervals := PackedFloat32Array([
	2.166667, 1.7333335, 1.3666665, 1.0666665])

@export_group("Run rewards — PLACEHOLDER")
## USER-DIRECTED PROVISIONAL 2026-08-17 — boost every source of disposable run
## XP by roughly thirty percent before any presentation receipt is created.
@export_range(1.0, 3.0, 0.05) var global_xp_gain_multiplier := 1.30

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
## USER-DIRECTED 2026-08-16 — Yard Magnet pulls only during this active slice of
## its rank-authored pulse interval.
@export_range(0.05, 2.0, 0.05) var yard_magnet_pulse_duration_seconds := 0.5

@export_group("Run splitter — PLACEHOLDER")
@export var splitter_purchase_cost: int = 150
@export var splitter_reliability_costs := PackedInt64Array([250, 650, 1600, 4000])
@export_range(0.5, 30.0, 0.1) var splitter_cycle_seconds := 8.0
@export_range(0.0, 1.0, 0.01) var splitter_base_chance := 0.12
@export_range(0.0, 1.0, 0.01) var splitter_chance_per_rank := 0.14

@export_group("Presentation — PLACEHOLDER")
@export_range(0.05, 2.0, 0.05) var block_hop_seconds := 0.38
## Portion of the handoff spent lifting vertically at the claimed ground pose;
## the remainder is the vertical drop above the chopping block.
@export_range(0.1, 0.9, 0.05) var block_handoff_lift_fraction := 0.45
## USER-DIRECTED PROVISIONAL 2026-08-14 — lengthen only the visible upward leg;
## the downward leg retains its previously authored duration.
@export_range(1.0, 3.0, 0.05) var block_handoff_lift_time_multiplier := 1.75
## Both the source lift and block-side reposition must clear the top of frame by
## at least this many pixels before the hidden horizontal teleport can occur.
@export_range(0.0, 256.0, 4.0) var block_handoff_offscreen_margin_pixels := 64.0
## USER-DIRECTED PROVISIONAL 2026-08-14 — retain one readable hidden beat between
## the source lift and block-side drop; final timing awaits a measured playtest.
@export_range(0.0, 0.25, 0.01) var block_handoff_hidden_hold_seconds := 0.04
## USER-DIRECTED 2026-08-16 — a scheduled boss is five ordinary-height roots
## stacked on the block, with only the top root cuttable at any time.
@export_range(5, 5, 1) var boss_stack_log_count := 5
## PLACEHOLDER — visual air between the five stacked root meshes.
@export_range(0.0, 0.2, 0.005) var boss_stack_gap := 0.025
## The live boss camera keeps ordinary gameplay distance/FOV. A full 1.0 lift
## locks the exposed ordinary-sized root's real centre to the camera centre.
@export_range(0.0, 4.0, 0.05) var boss_stack_camera_pullback := 1.15
@export_range(0.0, 1.0, 0.05) var boss_stack_camera_lift_fraction := 1.0
@export_range(60.0, 110.0, 1.0) var boss_stack_camera_fov := 88.0
## PLACEHOLDER — easing time between the exposed root heights and back to stump.
@export_range(0.05, 2.0, 0.05) var boss_stack_camera_transition_seconds := 0.4
## USER-DIRECTED PROVISIONAL 2026-08-14 — grounded Yard Magnet logs dock just
## outside the solid stump and ease out before contact instead of ramming it.
@export_range(0.0, 0.5, 0.01) var yard_magnet_dock_margin := 0.06
@export_range(0.05, 1.5, 0.05) var yard_magnet_brake_distance := 0.35
## USER-DIRECTED PROVISIONAL 2026-08-17 — an invisible collision capsule keeps
## the full vertical chopping corridor clear when final-minute waves pile up.
## These dimensions are deliberately surfaced for measured camera/physics tuning.
@export_range(0.25, 2.0, 0.05) var chopping_visibility_dome_radius := 0.75
@export_range(1.0, 10.0, 0.1) var chopping_visibility_dome_height := 5.0
@export_range(0.0, 1.0, 0.05) var chopping_visibility_dome_friction := 0.35
## USER-DIRECTED PROVISIONAL 2026-08-17 — only geometry crossing the camera-to-
## block corridor becomes invisible. The active workpiece is never a candidate.
@export_range(0.5, 1.0, 0.05) var chopping_visibility_tunnel_transparency := 1.0
## PLACEHOLDER — how quickly an old occluder returns after leaving the tunnel.
## Entering the tunnel is immediate so the workpiece is never covered.
@export_range(1.0, 30.0, 0.5) var chopping_visibility_tunnel_restore_speed := 10.0
@export_range(0.0, 64.0, 1.0) var chopping_visibility_screen_margin := 8.0
## PLACEHOLDER — a fifth-cut loose root should collapse locally, never launch
## like block firewood. No upward velocity is applied to these fragments.
@export_range(0.0, 2.0, 0.05) var off_block_fragment_out_speed := 0.35
@export_range(0.0, 6.0, 0.1) var off_block_fragment_tumble_speed := 1.2
## Physical yard landmarks are pushed this far beyond the danger circle so
## their complete silhouettes, rather than only their pivots, remain outside.
@export_range(0.2, 3.0, 0.05) var yard_prop_clearance := 1.35
## The boundary is a translucent ribbon: a narrow peak with a soft fade on both
## its inside and outside edges.
@export_range(0.005, 0.25, 0.005) var boundary_core_half_width := 0.025
@export_range(0.05, 0.8, 0.01) var boundary_gradient_width := 0.18
@export_range(0.05, 1.0, 0.05) var boundary_peak_alpha := 0.55
## PLACEHOLDER safety guard: 512 covers just over two full five-second boundary
## windows at the directed final rate of 10 roots every 0.2 seconds.
@export_range(10, 4096, 1) var loose_log_soft_cap := 512
## USER-DIRECTED 2026-08-17 — once completed billets retire their colliders,
## they begin sinking on the very next gameplay frame with no hold delay.
@export_range(0.0, 15.0, 0.05) var finished_piece_hold_seconds := 0.0
## PLACEHOLDER — downward speed throughout the immediate sink.
@export_range(0.05, 2.0, 0.05) var finished_piece_sink_speed := 0.35

@export_multiline var tuning_status := (
	"PLACEHOLDER — survival pacing, boundary, powerup, splitter and presentation "
	+ "values require measured playtest approval from Sam")


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if boundary_radius <= 0.0 or boundary_grace_seconds <= 0.0:
		errors.append("boundary radius and grace must be positive")
	if spawn_inner_radius >= spawn_outer_radius or spawn_outer_radius >= boundary_radius:
		errors.append("spawn radii must be ordered and stay inside the boundary")
	if arrival_fall_speed_multiplier <= 0.0:
		errors.append("arrival fall speed multiplier must be positive")
	if not is_equal_approx(global_xp_gain_multiplier, 1.30):
		errors.append("global run XP gain must retain the directed 30% increase")
	if not is_equal_approx(yard_magnet_pulse_duration_seconds, 0.5):
		errors.append("Yard Magnet pulse duration must be the directed 0.5 seconds")
	if block_handoff_lift_fraction <= 0.0 \
			or block_handoff_lift_fraction >= 1.0 \
			or block_handoff_lift_time_multiplier < 1.0 \
			or block_handoff_offscreen_margin_pixels < 0.0 \
			or block_handoff_hidden_hold_seconds < 0.0:
		errors.append("block handoff lift timing or off-screen margin is invalid")
	if boss_stack_log_count != 5 or boss_stack_gap < 0.0 \
			or boss_stack_camera_pullback < 0.0 \
			or boss_stack_camera_lift_fraction < 0.0 \
			or boss_stack_camera_fov <= 0.0 \
			or boss_stack_camera_transition_seconds <= 0.0:
		errors.append("boss-stack count or camera presentation tuning is invalid")
	if off_block_fragment_out_speed < 0.0 \
			or off_block_fragment_tumble_speed < 0.0:
		errors.append("off-block fragment fall-apart tuning cannot be negative")
	if yard_magnet_dock_margin < 0.0 or yard_magnet_brake_distance <= 0.0:
		errors.append("Yard Magnet dock and braking tuning is invalid")
	if chopping_visibility_dome_radius <= 0.0 \
			or chopping_visibility_dome_height <= chopping_visibility_dome_radius * 2.0 \
			or chopping_visibility_dome_friction < 0.0 \
			or chopping_visibility_tunnel_transparency < 0.5 \
			or chopping_visibility_tunnel_restore_speed <= 0.0 \
			or chopping_visibility_screen_margin < 0.0:
		errors.append("chopping visibility dome or tunnel tuning is invalid")
	if yard_prop_clearance <= 0.0:
		errors.append("yard presentation clearance must be positive")
	if not is_zero_approx(finished_piece_hold_seconds):
		errors.append("finished pieces must begin sinking immediately")
	if finished_piece_sink_speed <= 0.0:
		errors.append("finished-piece sink speed must be positive")
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
