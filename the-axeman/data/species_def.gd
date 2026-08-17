class_name SpeciesDef
extends Resource
## One immutable survival-log species row. Gameplay chooses an identity before a
## mesh so art variety never changes species probability.

@export_group("Identity and rewards")
@export var id: StringName
@export var display_name: String
## Registered RAW_WOOD item used by finished-piece inventory validation.
@export var yield_item: StringName
@export_range(0.0, 1.0, 0.01) var split_chance: float = 0.55
@export var xp_reward: int = 10

@export_group("Art")
@export var meshes: PackedStringArray = PackedStringArray()
## Runtime fresh-cut face. Empty paths fall back to the shared oak material.
@export var inside_tex: String = ""
@export var inside_normal: String = ""
@export var inside_tint: Color = Color.WHITE
## Defensive fallback for imported exteriors without an authored texture.
@export var bark_tint: Color = Color.WHITE
## Shared geometry receives species-specific exterior textures at runtime.
@export var bark_tex: String = ""
@export var top_tex: String = ""
@export var exterior_textures_placeholder: bool = false
@export_range(0.25, 24.0, 0.05) var bark_projection_scale: float = 1.8
