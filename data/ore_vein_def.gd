class_name OreVeinDef
extends Resource
## FILE: res://data/ore_vein_def.gd
## Schema per A8. Pre-fractured layers only (A2) — no runtime booleans.

@export var biome: Enums.Biome
@export var hardness_level: int = 1
## Pre-authored fracture layers, activated radially around hit points (M6).
## Untyped Array per the frozen A8 signature.
@export var fracture_layers: Array = []
## Gem drops are weighted-random entries within these yields (M6).
@export var yields: Array[FragmentDef] = []
