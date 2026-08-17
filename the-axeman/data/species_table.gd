class_name SpeciesTable
extends Resource
## Immutable catalogue of the 25 terrestrial woods used by survival runs.
## Rows stay in ascending Janka order: spawn progression and review tooling use
## this array as a ladder, with index zero as the fresh-run fallback.
@export var species: Array[SpeciesDef] = []

const _TABLE_PATH := "res://data/species_table.tres"

## Loaded once and cached for the life of the process.
static var _table: SpeciesTable = null


## ------------------------------------------------------------------ catalogue
static func all() -> Array[SpeciesDef]:
	var t := _catalogue()
	return [] if t == null else t.species


static func count() -> int:
	return all().size()


## The species at `index` in ladder order, or null if the index is off the end.
static func at(index: int) -> SpeciesDef:
	var list := all()
	if index < 0 or index >= list.size():
		return null
	return list[index]


static func by_id(id: StringName) -> SpeciesDef:
	for s: SpeciesDef in all():
		if s != null and s.id == id:
			return s
	return null


## Ladder position of a species id, or -1.
static func index_of(id: StringName) -> int:
	var list := all()
	for i in range(list.size()):
		if list[i] != null and list[i].id == id:
			return i
	return -1


## The species a finished piece of `item_id` came from, or null.
static func by_yield_item(item_id: StringName) -> SpeciesDef:
	for s: SpeciesDef in all():
		if s != null and s.yield_item == item_id:
			return s
	return null


## The first catalogue row is the fresh-run fallback.
static func starting_species() -> SpeciesDef:
	return at(0)


## ---------------------------------------------------------------- internals
static func _catalogue() -> SpeciesTable:
	if _table == null:
		_table = load(_TABLE_PATH) as SpeciesTable
		if _table == null:
			push_error("SpeciesTable: failed to load '%s' — there is no wood in the world." % _TABLE_PATH)
	return _table
