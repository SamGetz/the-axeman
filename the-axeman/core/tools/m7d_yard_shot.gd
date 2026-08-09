extends Node
## Non-headless 1280x720 captures for the four derived M7D yard states.

const OUT := "/private/tmp/axeman_m7d_yard_"


func _ready() -> void:
	var machine := MechanicalSplitter.machine_definition()
	var cases := [
		{"name": "1_stump", "tiers": {}},
		{"name": "2_shed", "tiers": {String(GameState.UPGRADE_SUPPLIER_LEDGER): 2}},
		{"name": "3_working", "tiers": {String(GameState.UPGRADE_HANDCART): 2}},
		{"name": "4_depot", "tiers": {String(machine.id): 2}},
	]
	for case: Dictionary in cases:
		GameState.apply_save_dict({"building_tiers": case.tiers})
		var game: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
		add_child(game)
		for _frame in range(8):
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		var path := OUT + String(case.name) + ".png"
		image.save_png(path)
		print("SHOT saved: " + path)
		game.queue_free()
		await get_tree().process_frame
	GameState.reset_to_defaults()
	get_tree().quit()
