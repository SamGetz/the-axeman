class_name AlienWoodTable
extends Resource

@export var traits: Array[AlienWoodTraitDef] = []


func by_id(id: StringName) -> AlienWoodTraitDef:
	for wood_trait: AlienWoodTraitDef in traits:
		if wood_trait != null and wood_trait.id == id:
			return wood_trait
	return null


func by_destination(destination_id: StringName) -> AlienWoodTraitDef:
	for wood_trait: AlienWoodTraitDef in traits:
		if wood_trait != null and wood_trait.destination_id == destination_id:
			return wood_trait
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	var destinations: Dictionary = {}
	for wood_trait: AlienWoodTraitDef in traits:
		if wood_trait == null:
			errors.append("alien wood table contains null")
			continue
		errors.append_array(wood_trait.validate())
		if ids.has(wood_trait.id) or destinations.has(wood_trait.destination_id):
			errors.append("duplicate alien wood or destination:%s" % wood_trait.id)
		ids[wood_trait.id] = true
		destinations[wood_trait.destination_id] = true
	return errors
