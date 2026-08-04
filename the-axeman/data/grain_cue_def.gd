class_name GrainCueDef
extends Resource
## Data-only presentation and validity tuning for Technique's grain-reading
## opportunity. Every number is a labelled placeholder per Directive 3.

@export_group("Availability")
@export var minimum_skill_rank: int = 1
@export var duration_sec: float = 0.8
@export var candidate_tolerance: float = 0.01

@export_group("Top-surface mark")
@export var mark_length_fraction: float = 0.82
@export var mark_core_width: float = 0.010
@export var mark_light_width: float = 0.018
@export var mark_dark_width: float = 0.028
@export var surface_lift: float = 0.006
@export var layer_lift: float = 0.0005

@export_group("Screen-space bracket")
@export var bracket_size: Vector2 = Vector2(116.0, 66.0)
@export var bracket_arm: float = 18.0
@export var bracket_core_width: float = 3.0
@export var bracket_outline_width: float = 7.0
@export var label_offset_y: float = 42.0
@export var cue_text: String = "Read the grain — cut here"

@export_group("Authorship")
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
