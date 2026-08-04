class_name SkillBranchDef
extends Resource
## One authored bough of the player-skill tree. Layout slots are semantic
## addresses, not pixels, so UI scaling cannot change progression meaning.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color: Color = Color.WHITE
@export var icon_path: String = ""
@export var layout_slots: Array[Vector2i] = []
