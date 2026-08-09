extends Node
## CLI entrypoint for the pure M15 policy report.

const _REPORT := preload("res://core/tools/m15_grant_free_pacing_report.gd")


func _ready() -> void:
	var before_progression := GameState.to_save_dict()
	var before_inventory := InventoryManager.to_save_dict()
	var errors := _REPORT.validate_catalogues()
	var reports: Array[Dictionary] = _REPORT.run_all()
	var state_unchanged := before_progression == GameState.to_save_dict() \
		and before_inventory == InventoryManager.to_save_dict()
	print("=== M15 GRANT-FREE REINVESTMENT POLICY REPORT ===")
	for report: Dictionary in reports:
		print(
			"SUMMARY policy=%s complete=%s modeled_minutes=%.1f managed_minutes=%.1f target=%s first_automation=%d first_company=%d earth_zero=%d max_drought=%d trees_left=%d purchases=%d m14_logs=%d cash=%d lifetime=%d" % [
				report.get("policy", ""),
				str(report.get("complete", false)),
				float(report.get("modeled_seconds", 0.0)) / 60.0,
				float(report.get("modeled_minutes_with_management", 0.0)),
				str(report.get("inside_two_to_four_hour_target", false)),
				int(report.get("first_automation_seconds", -1)),
				int(report.get("first_company_automation_seconds", -1)),
				int(report.get("earth_zero_seconds", -1)),
				int(report.get("max_decision_drought_seconds", -1)),
				int(report.get("earth_trees_remaining", -1)),
				(report.get("production_purchases", []) as Array).size(),
				int(report.get("m14_receipt_logs", 0)),
				int(report.get("cash_remaining", 0)),
				int(report.get("lifetime_cash", 0)),
			]
		)
		print(JSON.stringify(report))
	var policies_ok := reports.size() == 3
	for report: Dictionary in reports:
		policies_ok = policies_ok \
			and String(report.get("policy", "")) in ["cautious", "expected", "optimized"] \
			and bool(report.get("complete", false)) \
			and bool(report.get("inside_two_to_four_hour_target", false)) \
			and int(report.get("first_automation_seconds", -1)) >= 25 * 60 \
			and int(report.get("first_automation_seconds", -1)) <= 36 * 60 \
			and int(report.get("first_company_automation_seconds", -1)) >= 60 * 60 \
			and int(report.get("first_company_automation_seconds", -1)) <= 75 * 60 \
			and float(report.get("tactile_share_with_management", 0.0)) >= 0.45 \
			and float(report.get("tactile_share_with_management", 0.0)) <= 0.55 \
			and int(report.get("manual_logs", 0)) > 0 \
			and String(report.get("tuning_status", "")).begins_with("PLACEHOLDER")
	var passed := errors.is_empty() and state_unchanged and policies_ok
	print("CATALOGUE_ERRORS=%s" % JSON.stringify(errors))
	print("LIVE_STATE_UNCHANGED=%s" % state_unchanged)
	print("=== M15 GRANT-FREE POLICY REPORT: %s ===" % (
		"PASS — values remain provisional" if passed else "FAIL"))
	get_tree().quit(0 if passed else 1)
