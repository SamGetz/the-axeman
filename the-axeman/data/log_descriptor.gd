class_name LogDescriptor
extends RefCounted
## Stable identity for a whole delivered log. Species and mesh variant are
## captured at delivery time so changing the paused Catalog only affects future
## arrivals. The stable id is also the save/journal key.

var id: StringName = &""
var species_id: StringName = &""
var mesh_index := 0
var spawn_serial := 0
var visual_seed := 0
## Survivors-stage snapshot identity. `id` remains the stable root id so the
## existing arena/block journal keeps its current key contract.
var run_id: StringName = &""
var yard_id: StringName = &""
var boss_id: StringName = &""
var boss_tier := 0
var hardness_snapshot := 1.0
var cash_reward_snapshot := 0
var xp_reward_snapshot := 0
var original_mass := 0.0
## Migration-only deferred work from the retired partial off-block cut behavior.
## New run-power hits destroy loose roots immediately and never write this state.
var pending_power_cuts := 0
var pending_power_cut_sources: Array[StringName] = []
var pending_power_scars := 0
## Transient/snapshotted handoff pose populated when a physical loose body is
## claimed. New deliveries leave it at the sentinel and use the normal drop.
var transfer_from := Vector3(INF, INF, INF)
var transfer_rotation := Quaternion.IDENTITY
## Live-only presentation snapshot for an arena claim. These references are
## deliberately excluded from save dictionaries: suspension canonicalizes an
## active handoff before serializing, while legacy waiting roots can still
## rebuild deterministic descendant geometry from old pending cut receipts.
var transfer_visual_meshes: Array[Mesh] = []
var transfer_visual_transforms: Array[Transform3D] = []
var transfer_visual_projection_offsets: Array[Vector3] = []
var transfer_visual_overlays: Array[Material] = []
var _decoded_types_valid := true


static func create(p_id: StringName, p_species_id: StringName, p_mesh_index: int,
		p_spawn_serial: int, p_visual_seed: int) -> LogDescriptor:
	var descriptor := LogDescriptor.new()
	descriptor.id = p_id
	descriptor.species_id = p_species_id
	descriptor.mesh_index = maxi(0, p_mesh_index)
	descriptor.spawn_serial = maxi(0, p_spawn_serial)
	descriptor.visual_seed = p_visual_seed
	return descriptor


## New-stage constructor. Kept separate so every existing five-argument caller
## and test seam retains its exact API while slice 2 begins producing snapshots.
static func create_run(p_id: StringName, p_species_id: StringName, p_mesh_index: int,
		p_spawn_serial: int, p_visual_seed: int, p_run_id: StringName,
		p_yard_id: StringName, p_hardness_snapshot: float,
		p_cash_reward_snapshot: int, p_xp_reward_snapshot: int,
		p_original_mass: float, p_boss_id: StringName = &"",
		p_boss_tier: int = 0) -> LogDescriptor:
	var descriptor := create(p_id, p_species_id, p_mesh_index,
		p_spawn_serial, p_visual_seed)
	descriptor.run_id = p_run_id
	descriptor.yard_id = p_yard_id
	descriptor.hardness_snapshot = maxf(0.0001, p_hardness_snapshot)
	descriptor.cash_reward_snapshot = maxi(0, p_cash_reward_snapshot)
	descriptor.xp_reward_snapshot = maxi(0, p_xp_reward_snapshot)
	descriptor.original_mass = maxf(0.0, p_original_mass)
	descriptor.boss_id = p_boss_id
	descriptor.boss_tier = maxi(0, p_boss_tier)
	return descriptor


static func from_dict(data: Dictionary) -> LogDescriptor:
	var descriptor := LogDescriptor.new()
	var string_keys := ["id", "species_id", "run_id", "yard_id", "boss_id"]
	for key: String in string_keys:
		var value: Variant = data.get(key, "")
		if not (value is String or value is StringName):
			descriptor._decoded_types_valid = false
			value = ""
		descriptor.set(key, StringName(value))
	for key: String in ["mesh_index", "spawn_serial", "visual_seed", "boss_tier",
			"cash_reward_snapshot", "xp_reward_snapshot", "pending_power_cuts",
			"pending_power_scars"]:
		var value: Variant = data.get(key, 0)
		if not (value is int):
			descriptor._decoded_types_valid = false
			value = -1
		descriptor.set(key, int(value))
	for key: String in ["hardness_snapshot", "original_mass"]:
		var default_value := 1.0 if key == "hardness_snapshot" else 0.0
		var value: Variant = data.get(key, default_value)
		if not (value is int or value is float):
			descriptor._decoded_types_valid = false
			value = NAN
		descriptor.set(key, float(value))
	var raw_cut_sources: Variant = data.get("pending_power_cut_sources", [])
	if raw_cut_sources is Array:
		for raw_source: Variant in raw_cut_sources:
			if raw_source is String or raw_source is StringName:
				var source := StringName(raw_source)
				if source != &"":
					descriptor.pending_power_cut_sources.append(source)
					continue
			descriptor._decoded_types_valid = false
	else:
		descriptor._decoded_types_valid = false
	return descriptor


static func from_save_dict(data: Dictionary) -> LogDescriptor:
	var descriptor := from_dict(data)
	var transfer_value: Variant = data.get("transfer_from", Vector3(INF, INF, INF))
	if transfer_value is Vector3:
		descriptor.transfer_from = transfer_value
	else:
		descriptor._decoded_types_valid = false
	var rotation_value: Variant = data.get("transfer_rotation", Quaternion.IDENTITY)
	if rotation_value is Quaternion:
		descriptor.transfer_rotation = rotation_value
	else:
		descriptor._decoded_types_valid = false
	return descriptor


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"species_id": String(species_id),
		"mesh_index": mesh_index,
		"spawn_serial": spawn_serial,
		"visual_seed": visual_seed,
		"run_id": String(run_id),
		"yard_id": String(yard_id),
		"boss_id": String(boss_id),
		"boss_tier": boss_tier,
		"hardness_snapshot": hardness_snapshot,
		"cash_reward_snapshot": cash_reward_snapshot,
		"xp_reward_snapshot": xp_reward_snapshot,
		"original_mass": original_mass,
		"pending_power_cuts": pending_power_cuts,
		"pending_power_cut_sources": _serialized_pending_power_cut_sources(),
		"pending_power_scars": pending_power_scars,
		"transfer_from": transfer_from,
		"transfer_rotation": transfer_rotation,
	}


func _serialized_pending_power_cut_sources() -> Array[String]:
	var out: Array[String] = []
	for source: StringName in pending_power_cut_sources:
		out.append(String(source))
	return out


func is_valid() -> bool:
	return _decoded_types_valid and id != &"" \
		and SpeciesTable.by_id(species_id) != null \
		and mesh_index >= 0 and spawn_serial >= 0 \
		and pending_power_cuts >= 0 and pending_power_scars >= 0 \
		and pending_power_cut_sources.size() <= pending_power_cuts


## Strict validator for descriptors produced by the v19 run loop. The existing
## is_valid() deliberately remains backward-compatible during the gated pivot.
func is_valid_run_snapshot() -> bool:
	var yards := SurvivorsContent.yards()
	return is_valid() and run_id != &"" and yard_id != &"" \
		and yards != null and yards.by_id(yard_id) != null \
		and hardness_snapshot > 0.0 and is_finite(hardness_snapshot) \
		and cash_reward_snapshot > 0 and xp_reward_snapshot > 0 \
		and original_mass > 0.0 and is_finite(original_mass) \
		and ((boss_id == &"" and boss_tier == 0) \
			or (boss_id != &"" and boss_tier > 0))


func has_transfer_pose() -> bool:
	return is_finite(transfer_from.x) and is_finite(transfer_from.y) \
		and is_finite(transfer_from.z) and is_finite(transfer_rotation.x) \
		and is_finite(transfer_rotation.y) and is_finite(transfer_rotation.z) \
		and is_finite(transfer_rotation.w)


func has_transfer_visuals() -> bool:
	return not transfer_visual_meshes.is_empty() \
		and transfer_visual_meshes.size() == transfer_visual_transforms.size()
