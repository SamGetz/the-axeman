class_name FragmentDef
extends Resource
## FILE: res://data/fragment_def.gd
## Schema per A8, AMENDED with Creative Director approval (2026-07-18):
## added `sub_fragments` to model the chop split-chain recursively.
##
## Semantics:
##   - sub_fragments EMPTY  -> LEAF piece. Collectible. `yield_item` /
##     `yield_amount` are read, and only then.
##   - sub_fragments NON-EMPTY -> re-choppable piece. A successful hit swaps
##     this piece for its sub_fragments. `yield_item` / `yield_amount` are
##     ignored on non-leaf pieces.
##
## Hit-count-by-size falls out for free: a species' chain DEPTH is its hit
## count, so bigger logs simply ship deeper authored chains. Multi-way splits
## later are a data change only (append to the array), zero code change.
##
## A3 still holds: size_tier is authored metadata; the ONLY size test anywhere
## is `piece.size_tier > GameFeelConfig.size_threshold`.

@export var mesh: Mesh
@export var size_tier: int = 1
@export var yield_item: StringName        # leaf-only; must exist in item_registry.tres
@export var yield_amount: int = 1         # leaf-only
@export var sub_fragments: Array[FragmentDef] = []


func is_leaf() -> bool:
	return sub_fragments.is_empty()
