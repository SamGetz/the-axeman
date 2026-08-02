class_name SpeciesTable
extends Resource
## FILE: res://data/species_table.gd
## ATTACHES TO: nothing. The single instance is res://data/species_table.tres,
## reached through the static helpers below (there is no `Species` autoload, for
## the same reason Market, Shop and SaveSystem are not autoloads: the catalogue
## is immutable data, and a 5th autoload would need an amendment the way GameFeel
## did).
##
## EVERY WOOD IN THE GAME, IN LADDER ORDER — Sam's 25 species (2026-08-02),
## ascending by Janka hardness, which is the order he gave them in. Index 0 is
## the starting wood and index 24 is Lignum Vitae, the hardest commercial timber
## on Earth and the end of the terrestrial ladder that
## handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md builds toward.
##
## THE ORDER IS LOAD-BEARING, not cosmetic. Three things read it as a ladder:
## the wood selector shows it top to bottom, `next_locked()` finds the player's
## next goal by walking it, and m7a_acceptance asserts price and difficulty are
## both monotonic along it — so a new wood cannot be slipped in as the most
## valuable AND the easiest.
##
## Adding a species is a row in species_table.tres, an ItemDef in
## item_registry.tres and a price in price_table.tres. Nothing else, and no code.

## Ascending by Janka. See the ordering note above before reordering anything.
@export var species: Array[SpeciesDef] = []

const _TABLE_PATH := "res://data/species_table.tres"

## Loaded once and cached for the life of the process — a catalogue is static
## data, and this is read on every log spawn and every HUD repaint.
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


## Ladder position of a species id, or -1. The chopping game works in indices
## (its debug_forced_species seam is an index, and M4's suite drives it), so this
## is how an id from a save or from the HUD becomes one.
static func index_of(id: StringName) -> int:
	var list := all()
	for i in range(list.size()):
		if list[i] != null and list[i].id == id:
			return i
	return -1


## The species a finished piece of `item_id` came from, or null. Used to turn the
## yard pile — which is stored per FIREWOOD id — back into the wood that made it.
static func by_yield_item(item_id: StringName) -> SpeciesDef:
	for s: SpeciesDef in all():
		if s != null and s.yield_item == item_id:
			return s
	return null


## ---------------------------------------------------------------- the ladder
## The wood a fresh save starts on: the first species that needs no chopping at
## all. Falls back to index 0 so a table where someone has priced every wood
## behind a threshold still boots with something on the block.
static func starting_species() -> SpeciesDef:
	for s: SpeciesDef in all():
		if s != null and s.unlock_at <= 0:
			return s
	return at(0)


## Every species the player has earned, in ladder order.
static func unlocked(lifetime_wood_chopped: int) -> Array[SpeciesDef]:
	var out: Array[SpeciesDef] = []
	for s: SpeciesDef in all():
		if s != null and s.is_unlocked(lifetime_wood_chopped):
			out.append(s)
	return out


## The next wood the player has NOT earned, or null once the ladder is finished.
## This is the goal the HUD dangles: one wood ahead, never a wall of locked rows.
static func next_locked(lifetime_wood_chopped: int) -> SpeciesDef:
	for s: SpeciesDef in all():
		if s != null and not s.is_unlocked(lifetime_wood_chopped):
			return s
	return null


## ---------------------------------------------------------------- internals
static func _catalogue() -> SpeciesTable:
	if _table == null:
		_table = load(_TABLE_PATH) as SpeciesTable
		if _table == null:
			push_error("SpeciesTable: failed to load '%s' — there is no wood in the world." % _TABLE_PATH)
	return _table
