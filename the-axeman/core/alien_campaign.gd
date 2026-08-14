class_name AlienCampaign
extends RefCounted
## Retired compatibility facade. Alien catalogue/resources remain on disk so old
## saves and historical tools can be identified, but no live route may reveal,
## mutate, sell, or automate them in the survival-era game.


static func table() -> AlienWoodTable:
	return null


static func traits() -> Array[AlienWoodTraitDef]:
	return []


static func trait_by_id(_id: StringName) -> AlienWoodTraitDef:
	return null


static func trait_for_destination(_destination_id: StringName) -> AlienWoodTraitDef:
	return null


static func validate_catalogue() -> PackedStringArray:
	return PackedStringArray()


static func quarantine(_destination_id: StringName) -> bool:
	return false


static func identify(_destination_id: StringName) -> bool:
	return false


static func retrieve_specimen(_destination_id: StringName) -> bool:
	return false


static func unlock_repeat_cargo(_destination_id: StringName) -> bool:
	return false


static func premium_order_family(_destination_id: StringName) -> Dictionary:
	return {}


static func alien_cutting_profile_unlocked(_species_id: StringName) -> bool:
	return false


static func apply_automation_receipt(_receipt: AlienAutomationReceipt) -> bool:
	return false
