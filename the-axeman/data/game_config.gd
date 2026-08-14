class_name GameConfig
extends Resource
## Single read-only authority for global gameplay and presentation tuning.
##
## Values live as typed subresources inside res://data/game_config.tres. Content
## catalogues, save data, engine settings and scene-local layout remain outside
## this resource because they have different ownership and change lifecycles.

const RESOURCE_PATH := "res://data/survival_game_config.tres"

static var _current: GameConfig

@export_group("Progression")
@export var level_curve: LevelCurve = LevelCurve.new()
@export var xp_pacing: XPPacingConfig = XPPacingConfig.new()

@export_group("Manual play")
@export var grain_cue: GrainCueDef = GrainCueDef.new()

@export_group("Presentation")
@export var game_feel: GameFeelConfig = GameFeelConfig.new()
@export var reward_bursts: RewardBurstConfig = RewardBurstConfig.new()


static func current() -> GameConfig:
	if _current != null:
		return _current
	_current = load(RESOURCE_PATH) as GameConfig
	if _current == null:
		push_error("GameConfig: failed to load '%s'; using schema defaults." % RESOURCE_PATH)
		_current = GameConfig.new()
	return _current


## Test seam for cases that deliberately replace the ResourceLoader cache.
## Normal gameplay never clears this: all consumers must share one instance.
static func clear_cache() -> void:
	_current = null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_append_validation(errors, "level_curve", level_curve)
	_append_validation(errors, "xp_pacing", xp_pacing)
	_append_validation(errors, "grain_cue", grain_cue)
	_append_validation(errors, "game_feel", game_feel)
	_append_validation(errors, "reward_bursts", reward_bursts)
	return errors


func _append_validation(errors: PackedStringArray, label: String,
		resource: Resource) -> void:
	if resource == null:
		errors.append("%s config is missing" % label)
		return
	if not resource.has_method("validate"):
		errors.append("%s config has no validator" % label)
		return
	for error: String in resource.call("validate"):
		errors.append("%s: %s" % [label, error])
