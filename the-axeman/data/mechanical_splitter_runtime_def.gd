class_name MechanicalSplitterRuntimeDef
extends Resource
## Typed tuning authority for M8's watched Mechanical Splitter cycle. Sam signed
## off this complete band after the measured 4x-economy pass on 2026-08-05.

@export_group("Approved watched-cycle tuning")
## Seconds of active yard time required to finish one queued assigned log.
@export_range(0.1, 600.0, 0.1) var processing_duration_seconds: float = 5.0
## Slice 4 is deliberately one input slot; later queue systems are out of scope.
@export_range(1, 1, 1) var queue_capacity: int = 1
## Sam-approved Logs per Split band (2026-08-05): five represented logs at
## baseline, then +1 per purchased rank, hard-capped at twelve.
@export_range(1, 100, 1) var base_logs_per_split: int = 5
@export_range(1, 100, 1) var maximum_logs_per_split: int = 12
## Firewood units deposited from SpeciesDef.yield_item on one completion.
@export_range(1, 1000, 1) var output_amount: int = 1
## Sam's approved starting automation XP share (2026-08-05). This is the share
## of equivalent manual XP per active second, independent of represented logs
## and cycle speed. Upgrade rows add percentage points; manual XP procs do not.
@export_range(0.0, 1.0, 0.01) var base_xp_rate: float = 0.20
## Approved safety floor for five stacked Speed ranks.
@export_range(0.05, 1.0, 0.05) var minimum_duration_multiplier: float = 0.50
@export var tuning_status: String = "APPROVED — Sam 2026-08-05 measured watched-cycle tuning"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_equal_approx(processing_duration_seconds, 5.0):
		errors.append("processing duration must remain Sam's approved 5 seconds")
	if queue_capacity != 1:
		errors.append("Slice 4 queue capacity must remain exactly one")
	if base_logs_per_split != 5 or maximum_logs_per_split != 12:
		errors.append("Logs per Split must remain Sam's approved 5-to-12 band")
	if output_amount != 1:
		errors.append("output amount must remain one firewood per represented log")
	if not is_equal_approx(base_xp_rate, 0.20):
		errors.append("base automation XP rate must remain Sam's approved 20 percent")
	if not is_equal_approx(minimum_duration_multiplier, 0.50):
		errors.append("minimum duration multiplier must remain Sam's approved 50 percent")
	if not tuning_status.begins_with("APPROVED"):
		errors.append("watched-cycle tuning lacks an APPROVED label")
	return errors
