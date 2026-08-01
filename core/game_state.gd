extends Node
## FILE: res://core/game_state.gd
## ATTACHES TO: nothing directly. Register as Autoload "GameState"
## (order 3, after EventBus).
##
## Owns ALL progression state: unlocked biomes, equipped tool tiers, building
## tiers (A5). Writes occur ONLY here, in response to EventBus signals.
## Other modules (M5 gear gating, M7 upgrade UI) use direct read-only getters.

## Fresh-save defaults (M1 acceptance: AXE tier == 1 on a fresh save).
const DEFAULT_TOOL_TIER := 1
const DEFAULT_BUILDING_TIER := 1

## -------------------------------------------------------------------- state
## Keys are Enums.Biome ints; value is always true (presence = unlocked).
var _unlocked_biomes: Dictionary = { Enums.Biome.PINE_FOREST: true }
## Keys are Enums.ToolType ints -> int tier.
var _tool_tiers: Dictionary = {
	Enums.ToolType.AXE: DEFAULT_TOOL_TIER,
	Enums.ToolType.PICKAXE: DEFAULT_TOOL_TIER,
}
## Keys are building StringName ids -> int tier. Unknown ids read as tier 1.
var _building_tiers: Dictionary = {}

## ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	EventBus.gear_upgraded.connect(_on_gear_upgraded)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.environment_unlocked.connect(_on_environment_unlocked)

## -------------------------------------------------------- read-only queries
func get_tool_tier(tool_type: Enums.ToolType) -> int:
	return _tool_tiers.get(tool_type, DEFAULT_TOOL_TIER)


func get_building_tier(building_id: StringName) -> int:
	return _building_tiers.get(building_id, DEFAULT_BUILDING_TIER)


func is_biome_unlocked(biome: Enums.Biome) -> bool:
	return _unlocked_biomes.get(biome, false)


func get_unlocked_biomes() -> Array:
	## Array of Enums.Biome values. Defensive copy.
	return _unlocked_biomes.keys()

## ------------------------------------------- writes (EventBus-driven ONLY)
func _on_gear_upgraded(tool_type: Enums.ToolType, new_tier: int) -> void:
	## Tiers only ever move up. A non-increasing "upgrade" is almost certainly
	## an emitter bug, so it is warned about and ignored rather than applied.
	var current := get_tool_tier(tool_type)
	if new_tier <= current:
		push_warning("GameState: gear_upgraded for tool %d with non-increasing tier %d (current %d) — ignored." % [tool_type, new_tier, current])
		return
	_tool_tiers[tool_type] = new_tier


func _on_building_upgraded(building_id: StringName, new_tier: int) -> void:
	var current := get_building_tier(building_id)
	if new_tier <= current:
		push_warning("GameState: building_upgraded for '%s' with non-increasing tier %d (current %d) — ignored." % [building_id, new_tier, current])
		return
	_building_tiers[building_id] = new_tier


func _on_environment_unlocked(biome_id: Enums.Biome) -> void:
	if _unlocked_biomes.get(biome_id, false):
		push_warning("GameState: environment_unlocked for already-unlocked biome %d — ignored." % biome_id)
		return
	_unlocked_biomes[biome_id] = true
