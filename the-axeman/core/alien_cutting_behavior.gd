class_name AlienCuttingBehavior
extends RefCounted


static func resolve_strike(wood_trait: AlienWoodTraitDef, state: Dictionary,
		succeeded: bool, aligned_with_cue := false) -> Dictionary:
	var next := state.duplicate(true)
	var assisted := false
	if wood_trait == null:
		return {"state": next, "assisted": false, "reveal_cue": false}
	match wood_trait.behavior:
		AlienWoodTraitDef.Behavior.RESONANT_BAND:
			if bool(next.get("band_active", false)) and aligned_with_cue:
				assisted = true
				next["band_serial"] = int(next.get("band_serial", 0)) + 1
				next["band_active"] = false
			elif not succeeded:
				next["band_active"] = true
		AlienWoodTraitDef.Behavior.SCAR_PRIMING:
			var scars := maxi(0, int(next.get("scars", 0)))
			if bool(next.get("primed", false)):
				assisted = true
				next["primed"] = false
				next["scars"] = 0
			elif not succeeded:
				scars += 1
				next["scars"] = scars
				next["primed"] = scars >= wood_trait.scars_to_prime
	return {"state": next, "assisted": assisted,
		"reveal_cue": bool(next.get("band_active", false)) \
			or bool(next.get("primed", false))}


static func bounded_fragment_count(wood_trait: AlienWoodTraitDef, requested: int) -> int:
	if wood_trait == null:
		return 2
	return clampi(requested, 2, wood_trait.fragment_cap)
