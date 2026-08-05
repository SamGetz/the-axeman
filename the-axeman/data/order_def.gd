class_name OrderDef
extends Resource
## One patient, one-time lumberyard order. Exact quantities and bonuses are
## tuning data; routing and persistence never depend on literal values.

@export var id: StringName = &""
@export var customer_name := ""
@export var title := ""
@export_multiline var description := ""
## Player level at which this order becomes actionable. The board may tease the
## first unrevealed order, but it cannot be accepted early.
@export_range(1, 99, 1) var unlock_level := 1
## Empty means any registered RAW_WOOD item. A specific item keeps the order
## species-aware without duplicating the SpeciesTable.
@export var required_item: StringName = &""
## Optional ownership gate. This keeps a species order visible but unavailable
## until its wood has actually been bought.
@export var required_species: StringName = &""
@export_range(1, 1000000, 1) var required_count := 1
## Completion premium paid on top of the unlimited buyer's per-piece payment.
@export_range(1, 1000000000, 1) var cash_bonus := 1
## Review state for authored quantity/bonus values. The first three approved
## contracts predate this field and intentionally leave it empty; post-M8 rows
## carry an explicit placeholder label until Sam signs off measured pacing.
@export var tuning_status: String = ""


func matches(item_id: StringName) -> bool:
	if required_item != &"":
		return item_id == required_item
	var item := InventoryManager.get_item_def(item_id)
	return item != null and item.category == Enums.ItemCategory.RAW_WOOD
