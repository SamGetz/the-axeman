class_name CommissionTable
extends Resource
## Long-horizon standing commission identities. Quantities, ratios and selection
## remain explicitly provisional until Sam's measured campaign review.

@export var templates: Array[CommissionTemplateDef] = []
## Every standing commission targets this share of the next species cash goal.
## The offer itself snapshots the resulting cash amount, so later purchases and
## phase changes cannot move a promise already shown to the player.
@export_range(0.001, 1.0, 0.001) var relevance_premium_ratio := 0.05
## Five choices across a four-hour campaign keeps commissions strategic without
## turning them into a recurring board-maintenance loop.
@export_range(1, 12, 1) var campaign_offer_limit := 5
## Probe/acceptance targets only. Live progress remains piece/quality based.
@export_range(60.0, 7200.0, 1.0) var target_duration_min_seconds := 1500.0
@export_range(60.0, 7200.0, 1.0) var target_duration_max_seconds := 2400.0
@export var tuning_status := "PLACEHOLDER — M9 measured tuning required"


func by_id(id: StringName) -> CommissionTemplateDef:
	for template: CommissionTemplateDef in templates:
		if template != null and template.id == id:
			return template
	return null
