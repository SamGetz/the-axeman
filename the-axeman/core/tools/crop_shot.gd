extends SceneTree
## DEV TOOL. Crops and magnifies a region of a saved shot so a seam can be read.
## Run: godot --headless --path . --script res://core/tools/crop_shot.gd

func _initialize() -> void:
	_crop("user://seam_2_join_close.png", Rect2i(470, 280, 320, 180), 4, "user://crop_join.png")
	_crop("user://seam_4_band_only.png", Rect2i(520, 60, 300, 200), 4, "user://crop_band.png")
	quit()


func _crop(src: String, r: Rect2i, zoom: int, dst: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		print("could not load " + src)
		return
	var sub := img.get_region(r)
	sub.resize(r.size.x * zoom, r.size.y * zoom, Image.INTERPOLATE_NEAREST)
	sub.save_png(ProjectSettings.globalize_path(dst))
	print("wrote " + dst)
