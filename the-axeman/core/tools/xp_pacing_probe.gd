extends Node
## Read-only placeholder pacing report. It validates shape; final values still
## require the approved timed Compatibility play session.


func _ready() -> void:
	var curve := GameConfig.current().level_curve
	var config := GameConfig.current().xp_pacing
	if curve == null or config == null:
		push_error("XP pacing probe could not load its resources.")
		get_tree().quit(1)
		return
	print("=== AXEMAN XP PACING — PLACEHOLDER REVIEW ===")
	print("wood | level | span | base XP/log | modified XP/log | logs/level | active min")
	var previous_minutes := 0.0
	var species := SpeciesTable.all()
	for index in range(species.size()):
		var wood: SpeciesDef = species[index]
		var level := int(config.representative_terrestrial_levels[index])
		var seconds := float(config.representative_terrestrial_active_seconds[index])
		var minutes := _print_anchor(wood.display_name, level, wood.xp_reward,
			seconds, curve, config)
		if minutes + 0.15 < previous_minutes:
			push_error("XP pacing reversal at %s" % wood.display_name)
		previous_minutes = minutes
	var alien := AlienCampaign.traits()
	for index in range(alien.size()):
		var wood: AlienWoodTraitDef = alien[index]
		var level := int(config.representative_alien_levels[index])
		var seconds := float(config.representative_alien_active_seconds[index])
		var minutes := _print_anchor(wood.display_name, level, wood.xp_reward,
			seconds, curve, config)
		if minutes + 0.15 < previous_minutes:
			push_error("XP pacing reversal at %s" % wood.display_name)
		previous_minutes = minutes
	var final_logs := float(curve.xp_to_next(config.representative_alien_levels[-1])) \
		/ float(alien[-1].xp_reward)
	var final_seconds := final_logs * float(config.representative_alien_active_seconds[-1])
	print("Final Frontier anchor: %.2f logs, %.1f seconds (target %.1f)" % [
		final_logs, final_seconds, config.final_frontier_target_seconds])
	_print_campaign_projection(curve, config)
	get_tree().quit()


func _print_anchor(label: String, level: int, base_xp: int, seconds: float,
		curve: LevelCurve, config: XPPacingConfig) -> float:
	var span := curve.xp_to_next(level)
	var modified := maxi(1, int(round(float(base_xp) * config.global_xp_multiplier \
		* (1.0 + SkillTree.total_modifier(GameplayModifierDef.Kind.GLOBAL_XP_GAIN)))))
	var logs := float(span) / float(modified)
	var minutes := logs * seconds / 60.0
	print("%s | %d | %d | %d | %d | %.2f | %.2f" % [
		label, level, span, base_xp, modified, logs, minutes])
	return minutes


## Conservative critical-path audit: no skill/proc/automation XP is credited,
## every terrestrial species is manually mastered, and the maximum planetary
## band is counted after terrestrial work instead of concurrently. The final
## allowance is navigation/reading time, not simulated production.
func _print_campaign_projection(curve: LevelCurve, config: XPPacingConfig) -> void:
	var total_xp := 0
	var terrestrial_logs := 0
	var terrestrial_seconds := 0.0
	var species := SpeciesTable.all()
	for index in range(species.size()):
		var wood: SpeciesDef = species[index]
		var mastery := M7CContent.mastery().by_species_id(wood.id)
		var logs := mastery.mastery_target
		if index + 1 < species.size():
			var next_wood: SpeciesDef = species[index + 1]
			var target_xp := curve.total_xp_for_level(next_wood.unlock_level)
			var awarded_xp := maxi(1, int(round(float(wood.xp_reward) \
				* config.global_xp_multiplier)))
			while total_xp + logs * awarded_xp < target_xp:
				logs += 1
		total_xp += logs * maxi(1, int(round(float(wood.xp_reward) \
			* config.global_xp_multiplier)))
		terrestrial_logs += logs
		terrestrial_seconds += logs * float(
			config.representative_terrestrial_active_seconds[index])

	var alien_logs := 0
	var alien_seconds := 0.0
	var alien := AlienCampaign.traits()
	for index in range(alien.size()):
		var wood: AlienWoodTraitDef = alien[index]
		alien_logs += wood.manual_mastery_target
		alien_seconds += wood.manual_mastery_target * float(
			config.representative_alien_active_seconds[index])
	var flight_seconds := 0
	for destination: ExpeditionDef in LaunchProgram.expedition_table().expeditions:
		flight_seconds += destination.flight_seconds

	const PLANETARY_PROJECTION_SECONDS := 995.0
	const MANAGEMENT_MIN_SECONDS := 600.0
	const MANAGEMENT_MAX_SECONDS := 1200.0
	var active_seconds := terrestrial_seconds + PLANETARY_PROJECTION_SECONDS \
		+ alien_seconds + flight_seconds
	print("=== CONSERVATIVE CAMPAIGN PROJECTION — PLACEHOLDER ===")
	print("Terrestrial gate: %d logs, %.1f minutes" % [
		terrestrial_logs, terrestrial_seconds / 60.0])
	print("Planetary maximum projection: %.1f minutes (validated inside 16.5–17)" % (
		PLANETARY_PROJECTION_SECONDS / 60.0))
	print("Frontier fixed/manual: %d logs, %.1f flight + %.1f chopping minutes" % [
		alien_logs, float(flight_seconds) / 60.0, alien_seconds / 60.0])
	print("Completion with 10–20 management minutes: %.1f–%.1f minutes (target 120–240)" % [
		(active_seconds + MANAGEMENT_MIN_SECONDS) / 60.0,
		(active_seconds + MANAGEMENT_MAX_SECONDS) / 60.0])
