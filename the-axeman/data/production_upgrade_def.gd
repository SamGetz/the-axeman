class_name ProductionUpgradeDef
extends UpgradeDef
## A bounded reinvestment rank. Prices/effects are authored resource facts: the
## lifetime-earnings gate reveals them, but never rebases their price.

enum Milestone {
	WATCHED_AUTOMATION,
	TIMBER_DEPOT,
	CONTINENTAL_COMPANY,
	PLANETARY_INDUSTRY,
	EARTH_DEPLETED,
	FIRST_ALIEN_LINE,
	SECOND_ALIEN_LINE,
	THREE_ALIEN_LINES,
}

enum ProductionEffect {
	PARALLEL_LINES,
	LOGS_PER_TREE,
	AUTOMATION_SALE_VALUE,
	INTERVAL_REDUCTION,
	DISPATCH_CAPACITY,
	SPECIES_PER_RECEIPT,
	TREES_PER_CYCLE,
	PARALLEL_MULTIPLIER,
	CONTINUITY_RESERVE,
	ALIEN_CARGO_CAPACITY,
	ORBITAL_OUTPUT,
	ALIEN_SALE_VALUE,
	ALIEN_INTERVAL_REDUCTION,
}

@export_group("Pacing Reveal")
@export var required_lifetime_cash: int = 0
@export var required_milestone: Milestone = Milestone.WATCHED_AUTOMATION

@export_group("Production")
@export var production_effect: ProductionEffect = ProductionEffect.PARALLEL_LINES
@export var production_step: float = 0.0
## Interval reductions compose additively but may never pass this authored floor.
@export_range(0.05, 1.0, 0.01) var interval_floor := 0.2
@export var effect_unit: String = ""


func current_effect_text(level: int) -> String:
	return _format_effect(maxi(0, level))


func next_effect_text(level: int) -> String:
	return _format_effect(maxi(0, level) + 1)


func estimated_production_change(level: int) -> String:
	var current_rank := maxi(0, level)
	match production_effect:
		ProductionEffect.SPECIES_PER_RECEIPT:
			return "+%d routed species capacity" % int(round(production_step))
		ProductionEffect.DISPATCH_CAPACITY, ProductionEffect.PARALLEL_LINES, \
				ProductionEffect.ALIEN_CARGO_CAPACITY:
			var current := 1.0 + production_step * float(current_rank)
			return "~+%d%% capacity" % int(round(production_step / current * 100.0))
		ProductionEffect.LOGS_PER_TREE, ProductionEffect.TREES_PER_CYCLE, \
				ProductionEffect.PARALLEL_MULTIPLIER, ProductionEffect.ORBITAL_OUTPUT:
			var current := 1.0 + production_step * float(current_rank)
			return "~+%d%% output" % int(round(production_step / current * 100.0))
		ProductionEffect.AUTOMATION_SALE_VALUE, ProductionEffect.ALIEN_SALE_VALUE:
			var current := 1.0 + production_step * float(current_rank)
			return "~+%d%% receipt value" % int(round(production_step / current * 100.0))
		ProductionEffect.INTERVAL_REDUCTION, \
				ProductionEffect.ALIEN_INTERVAL_REDUCTION:
			var current := maxf(interval_floor,
				1.0 - production_step * float(current_rank))
			var next := maxf(interval_floor,
				1.0 - production_step * float(current_rank + 1))
			return "~+%d%% cycle throughput" % int(round(
				(current / next - 1.0) * 100.0))
		ProductionEffect.CONTINUITY_RESERVE:
			return "prepaid launch softlock protection"
	return "production effect"


func validate_production() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.is_empty() or base_cost <= 0 or max_level <= 0:
		errors.append("production upgrade identity, price and rank bound must be positive")
	if required_lifetime_cash < 0 or production_step <= 0.0 \
			or not is_finite(production_step):
		errors.append("production upgrade reveal/effect must be finite and non-negative")
	if not tuning_status.begins_with(
			"PLACEHOLDER — four-hour reinvestment validation required"):
		errors.append("production tuning must remain explicitly provisional")
	return errors


func _format_effect(level: int) -> String:
	var value := production_step * float(level)
	match production_effect:
		ProductionEffect.PARALLEL_LINES, ProductionEffect.DISPATCH_CAPACITY, \
				ProductionEffect.SPECIES_PER_RECEIPT, \
				ProductionEffect.ALIEN_CARGO_CAPACITY:
			return "%d %s" % [1 + int(round(value)), effect_unit]
		ProductionEffect.LOGS_PER_TREE, ProductionEffect.TREES_PER_CYCLE, \
				ProductionEffect.PARALLEL_MULTIPLIER, ProductionEffect.ORBITAL_OUTPUT:
			return "×%.2f %s" % [1.0 + value, effect_unit]
		ProductionEffect.AUTOMATION_SALE_VALUE, \
				ProductionEffect.ALIEN_SALE_VALUE:
			return "+%d%% %s" % [int(round(value * 100.0)), effect_unit]
		ProductionEffect.INTERVAL_REDUCTION, \
				ProductionEffect.ALIEN_INTERVAL_REDUCTION:
			return "%.0f%% %s" % [maxf(interval_floor,
				1.0 - value) * 100.0, effect_unit]
		ProductionEffect.CONTINUITY_RESERVE:
			return "funded" if level > 0 else "not funded"
	return str(value)
