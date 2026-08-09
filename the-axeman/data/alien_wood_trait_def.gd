class_name AlienWoodTraitDef
extends Resource

enum Behavior { RESONANT_BAND, LOW_GRAVITY_FRAGMENTS, SCAR_PRIMING }

@export var id: StringName = &""
@export var destination_id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var yield_item: StringName = &""
@export var behavior: Behavior = Behavior.RESONANT_BAND
@export_range(0.01, 1.0, 0.01) var split_chance := 0.2
@export_range(1, 1000000, 1) var xp_reward := 1
@export_range(1, 20, 1) var manual_mastery_target := 3
@export_range(1, 16, 1) var fragment_cap := 2
@export_range(1, 12, 1) var scars_to_prime := 2
@export_range(0.01, 1.0, 0.01) var gravity_scale := 1.0
@export_range(1, 10000000000, 1) var fleet_cost := 1
@export_range(1, 10000000000, 1) var orbital_line_cost := 1
@export var premium_order_name := ""
@export var premium_multiplier := 1.0
@export var inside_tint := Color.WHITE
@export var bark_tint := Color.WHITE
@export_file("*.png") var candidate_surface_tex := ""
@export var art_status := "REPLACEABLE CANDIDATE — AI-generated, provenance manifest required"
@export var tuning_status := "PLACEHOLDER — alien behavior and economy tuning review required"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or destination_id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or yield_item == &"" \
			or manual_mastery_target <= 0 or fragment_cap < 2 \
			or scars_to_prime <= 0 or gravity_scale <= 0.0 \
			or premium_order_name.strip_edges().is_empty() or premium_multiplier <= 1.0:
		errors.append("alien wood identity, behavior bounds or premium family is invalid")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("alien tuning must remain provisional")
	return errors


func runtime_species() -> SpeciesDef:
	var species := SpeciesDef.new()
	species.id = id
	species.display_name = display_name
	species.yield_item = yield_item
	species.janka = 5000 + int(behavior) * 500
	species.unlock_level = 99
	species.unlock_cost = 0
	species.split_chance = split_chance
	species.xp_reward = xp_reward
	species.meshes = PackedStringArray([
		"res://assets/models/logs_export/log_01.fbx",
		"res://assets/models/logs_export/log_02.fbx",
	])
	species.inside_tint = inside_tint
	species.bark_tint = bark_tint
	species.inside_tex = candidate_surface_tex
	species.bark_tex = candidate_surface_tex
	return species
