class_name EquipmentDef
extends Resource
## Immutable loadout/comparison data. Ownership remains in the M7A shop path;
## equipped state will belong to GameState in slice 9.

enum Slot { AXE, WORKSTATION }
enum ArtStatus { AUTHORED, EXISTING_VARIANT, GREYBOX_PLACEHOLDER }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var limitation: String
@export var slot: Slot = Slot.AXE
@export var ownership_upgrade_id: StringName = &""
@export var is_starting_fallback: bool = false
@export_range(0, 8, 1) var progression_stage: int = 0
@export var placeholder_tint: Color = Color.WHITE
@export var comparison_tags: Array[StringName] = []
@export var modifiers: Array[GameplayModifierDef] = []
@export var presentation_scene_path: String = ""
@export var material_variant_path: String = ""
@export var art_status: ArtStatus = ArtStatus.GREYBOX_PLACEHOLDER
@export var tuning_status: String = "PLACEHOLDER — Creative Director tuning required"
