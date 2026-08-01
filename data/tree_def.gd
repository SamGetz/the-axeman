class_name TreeDef
extends Resource
## FILE: res://data/tree_def.gd
## Schema per A8. All M5 tunables (integrity, stage counts) live in instances
## of this resource, never in code.

@export var biome: Enums.Biome
@export var hardness_level: int = 1
## 4 quadrants x N cut-depth stages (default N = 3), per A2. Kept as an
## untyped Array per the frozen A8 signature; authored as an Array of
## per-quadrant Arrays of Mesh.
@export var quadrant_stage_meshes: Array = []
@export var integrity_per_cut: int = 1
@export var yields: Array[FragmentDef] = []
