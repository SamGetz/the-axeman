extends Node3D
## Plays every Phase-1 cue in manifest order with enough space to judge its tail.


func _ready() -> void:
	var listener := AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	AudioDirector.register_world_root(self)
	AudioDirector.begin_session()
	var file := FileAccess.open("res://data/sound_manifest.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	for cue_id: String in parsed.get("cues", {}):
		var cue: Dictionary = parsed.cues[cue_id]
		print("PHASE 1 AUDIO AUDITION: %s" % cue_id)
		if bool(cue.get("spatial", false)):
			AudioDirector.play_world(StringName(cue_id), Vector3(0.0, 0.0, -1.0))
		else:
			AudioDirector.play_ui(StringName(cue_id))
		await get_tree().create_timer(1.15).timeout
	AudioDirector.end_session()
	AudioDirector.unregister_world_root(self)
	print("=== PHASE 1 AUDIO AUDITION COMPLETE ===")
	get_tree().quit()
