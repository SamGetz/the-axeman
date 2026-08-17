class_name MetaUpgradeDef
extends Resource
## Immutable catalogue row for one home-only permanent upgrade line.

enum Capability {
	NONE,
	RESERVED_RETIRED_OFF_BLOCK_CUTTING,
	HOLD_TO_CHOP,
	CONTINUOUS_HANDOFF,
	FREQUENCY_CONTROL,
}

@export_group("Identity and copy")
@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export_multiline var limitation := ""
@export var icon_path := ""

@export_group("Rank ladder")
@export_range(1, 99, 1) var max_rank := 1
## Exact price paid for ranks 1..max_rank. There is deliberately no formula.
@export var costs_by_rank := PackedInt64Array()
@export var effects: Array[ProgressionEffectDef] = []

@export_group("Capabilities and prerequisites")
@export var granted_capability: Capability = Capability.NONE
@export var prerequisite_upgrade_id: StringName = &""
@export_range(0, 99, 1) var prerequisite_rank := 0

@export_multiline var tuning_status := \
	"PLACEHOLDER — permanent upgrade costs and values require measured tuning approval"


func cost_for_rank(rank: int) -> int:
	if rank <= 0 or rank > costs_by_rank.size():
		return 0
	return int(costs_by_rank[rank - 1])


func effect_value(effect_kind: ProgressionEffectDef.Kind, rank: int) -> float:
	for effect: ProgressionEffectDef in effects:
		if effect != null and effect.kind == effect_kind:
			return effect.value_at_rank(clampi(rank, 0, max_rank))
	return 0.0


func is_maxed(rank: int) -> bool:
	return rank >= max_rank


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty() or limitation.strip_edges().is_empty():
		errors.append("meta upgrade identity or copy is incomplete")
	if icon_path.strip_edges().is_empty():
		errors.append("meta upgrade has no provisional icon path")
	if max_rank <= 0 or costs_by_rank.size() != max_rank:
		errors.append("meta upgrade cost array does not match its cap")
	for cost: int in costs_by_rank:
		if cost <= 0:
			errors.append("meta upgrade costs must all be positive")
			break
	if effects.is_empty():
		errors.append("meta upgrade has no typed effects")
	var kinds: Dictionary = {}
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			errors.append("meta upgrade contains a null effect")
			continue
		if kinds.has(effect.kind):
			errors.append("meta upgrade contains a duplicate effect kind:%d" % effect.kind)
		kinds[effect.kind] = true
		errors.append_array(effect.validate(max_rank))
	if prerequisite_upgrade_id == &"" and prerequisite_rank != 0:
		errors.append("meta upgrade has a prerequisite rank without an upgrade")
	if prerequisite_upgrade_id != &"" and prerequisite_rank <= 0:
		errors.append("meta upgrade prerequisite must require a positive rank")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("meta upgrade tuning must remain explicitly provisional")
	return errors
