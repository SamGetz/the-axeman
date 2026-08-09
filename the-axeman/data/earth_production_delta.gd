class_name EarthProductionDelta
extends RefCounted
## Immutable, unapplied Earth production fact. Inventory settlement still belongs
## to InventoryManager/Market; GameState consumes this receipt exactly once to
## advance depletion and the existing manual/automated campaign totals.

enum SourceKind {
	MANUAL,
	WATCHED_SPLITTER,
	COMPANY_ACTIVE,
	COMPANY_OFFLINE,
}

var receipt_id: StringName
var source_kind: SourceKind
var trees_by_species: Dictionary
var logs_by_item: Dictionary
var elapsed_seconds: int
var offline: bool


func _init(p_receipt_id: StringName, p_source_kind: SourceKind,
		p_trees_by_species: Dictionary, p_logs_by_item: Dictionary = {},
		p_elapsed_seconds := 0, p_offline := false) -> void:
	receipt_id = p_receipt_id
	source_kind = p_source_kind
	trees_by_species = p_trees_by_species.duplicate(true)
	logs_by_item = p_logs_by_item.duplicate(true)
	elapsed_seconds = maxi(0, p_elapsed_seconds)
	offline = p_offline


func total_trees() -> int:
	var total := 0
	for value: Variant in trees_by_species.values():
		var amount := int(value)
		if amount <= 0 or total > GameState.MAX_SAFE_ECONOMY_VALUE - amount:
			return -1
		total += amount
	return total


func total_logs() -> int:
	var total := 0
	for value: Variant in logs_by_item.values():
		var amount := int(value)
		if amount <= 0 or total > GameState.MAX_SAFE_ECONOMY_VALUE - amount:
			return -1
		total += amount
	return total


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if receipt_id == &"":
		errors.append("Earth production receipt has no identity")
	if source_kind < SourceKind.MANUAL or source_kind > SourceKind.COMPANY_OFFLINE:
		errors.append("Earth production receipt has an invalid source")
	if trees_by_species.is_empty() or total_trees() <= 0:
		errors.append("Earth production receipt has no positive tree total")
	for raw_species: Variant in trees_by_species:
		if SpeciesTable.by_id(StringName(raw_species)) == null \
				or int(trees_by_species[raw_species]) <= 0:
			errors.append("Earth production receipt contains an invalid species")
	for raw_item: Variant in logs_by_item:
		if int(logs_by_item[raw_item]) <= 0:
			errors.append("Earth production receipt contains an invalid log output")
	if not logs_by_item.is_empty() and total_logs() <= 0:
		errors.append("Earth production receipt log total overflowed")
	if offline != (source_kind == SourceKind.COMPANY_OFFLINE):
		errors.append("Earth production receipt offline/source state disagrees")
	return errors
