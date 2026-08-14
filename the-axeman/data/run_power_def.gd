class_name RunPowerDef
extends Resource
## Immutable identity and fixed authored rank ladder for one temporary power.

enum Rarity { INVALID, COMMON, RARE, EPIC }
enum Pool { INVALID, CORE, BLUEPRINT }

@export_group("Identity and copy")
@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var rarity: Rarity = Rarity.INVALID
@export var pool: Pool = Pool.INVALID
@export_range(1, 99, 1) var rank_cap := 1

@export_group("Authored effects and presentation")
@export var effects: Array[ProgressionEffectDef] = []
@export var icon_path := ""
@export var vfx_path := ""
@export_multiline var tuning_status := \
	"PLACEHOLDER — run-power rank values and cadence require measured tuning approval"


func effect_value(effect_kind: ProgressionEffectDef.Kind, rank: int) -> float:
	for effect: ProgressionEffectDef in effects:
		if effect != null and effect.kind == effect_kind:
			return effect.value_at_rank(clampi(rank, 0, rank_cap))
	return 0.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or display_name.strip_edges().is_empty() \
			or description.strip_edges().is_empty():
		errors.append("run power identity or copy is incomplete")
	if rarity < Rarity.COMMON or rarity > Rarity.EPIC:
		errors.append("run power has an invalid rarity")
	if pool < Pool.CORE or pool > Pool.BLUEPRINT:
		errors.append("run power has an invalid pool")
	if rank_cap <= 0:
		errors.append("run power has an invalid rank cap")
	if effects.is_empty():
		errors.append("run power has no typed effects")
	var kinds: Dictionary = {}
	for effect: ProgressionEffectDef in effects:
		if effect == null:
			errors.append("run power contains a null effect")
			continue
		if kinds.has(effect.kind):
			errors.append("run power contains a duplicate effect kind:%d" % effect.kind)
		kinds[effect.kind] = true
		errors.append_array(effect.validate(rank_cap))
	if icon_path.strip_edges().is_empty() or vfx_path.strip_edges().is_empty():
		errors.append("run power is missing provisional icon or VFX paths")
	if not tuning_status.begins_with("PLACEHOLDER"):
		errors.append("run-power tuning must remain explicitly provisional")
	return errors
