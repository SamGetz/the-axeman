extends Node
## Compatibility-render audit: all eight placeholder axe/stump identity pairs.

const AXES: Array[StringName] = [
	&"tempered_woodsmans_axe", &"forged_splitting_maul", &"steel_cheek_axe",
	&"journeymans_bearded_axe", &"hardwood_pattern_axe", &"continental_mill_axe",
	&"earthmaster_axe", &"starforged_xenowood_axe",
]
const STUMPS: Array[StringName] = [
	&"iron_block_dogs", &"log_cradle", &"raised_split_stand", &"braced_yard_block",
	&"millhouse_chopping_block", &"continental_split_deck",
	&"earthmaster_ironwood_block", &"orbital_specimen_stand",
]


func _ready() -> void:
	var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	game.debug_forced_species = 0
	game.debug_forced_mesh = 0
	game.auto_sell = false
	game.orbs_enabled = false
	add_child(game)
	await get_tree().process_frame
	for stage in range(1, 9):
		var tiers: Dictionary = {}
		for index in range(stage):
			tiers[String(AXES[index])] = GameState.DEFAULT_BUILDING_TIER + 1
			tiers[String(STUMPS[index])] = GameState.DEFAULT_BUILDING_TIER + 1
		GameState.apply_save_dict({"building_tiers": tiers})
		var presenter: YardEquipmentPresenter = game.get_node("YardEquipment")
		presenter.refresh()
		var axe: AxeViewmodel = game.get_node(
			"CameraPivot/Camera3D/AxeViewmodelAnchor")
		axe.swing(Vector2(-0.15, 0.05))
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "user://equipment_stage_%02d.png" % stage
		var error := image.save_png(path)
		print("EQUIPMENT_RENDER stage=%d axe=%s stump=%s path=%s result=%s" % [
			stage, AXES[stage - 1], STUMPS[stage - 1], ProjectSettings.globalize_path(path),
			error_string(error)])
	game.queue_free()
	GameState.reset_to_defaults()
	get_tree().quit()
