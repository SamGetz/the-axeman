class_name GrainCueDef
extends Resource
## Data-only presentation and validity tuning for Technique's grain-reading
## opportunity — a PERMANENT glowing gold mark, occasionally offered on a
## piece, that cuts exactly along its line with no forced camera turn.
## Every number is a labelled placeholder per Directive 3.

@export_group("Availability")
@export var minimum_skill_rank: int = 1
@export var candidate_tolerance: float = 0.01

@export_group("Top-surface mark")
@export var mark_length_fraction: float = 0.82
@export var mark_core_width: float = 0.010
@export var mark_glow_width: float = 0.024
@export var mark_dark_width: float = 0.032
@export var surface_lift: float = 0.006
@export var layer_lift: float = 0.0005
@export var mark_color: Color = Color(1.0, 0.78, 0.25, 1.0)

@export_group("Glow pulse")
@export var glow_pulse_period_sec: float = 1.6
@export var glow_pulse_min: float = 0.35
@export var glow_pulse_max: float = 0.95

@export_group("Authorship")
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
