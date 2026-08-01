class_name FadeOut
extends RefCounted
## FILE: res://scenes/3d_action/fade_out.gd
## ATTACHES TO: nothing — a static helper.
##
## Dissolves a piece of scenery away and frees it, so a mini-game can clear the
## board without anything popping out of existence. M5 uses it on the felled
## tree, its logs and its chips, right before the next tree bounces in.
##
## It fades by installing a DUPLICATE of each surface's material as a surface
## OVERRIDE and animating that copy's alpha. Two reasons not to take the shorter
## routes: writing alpha on the material itself would fade every other object
## sharing it (all the wood shares two materials), and GeometryInstance3D's own
## `transparency` property is a no-op on materials whose transparency mode is
## DISABLED — which is the default on every material in this project.
##
## Materials that are not BaseMaterial3D cannot be faded this way; those meshes
## are simply freed with the rest at the end.

## Fade `node` and everything under it to nothing over `seconds`, then free it.
## Returns immediately; the node stays in the tree until the fade finishes.
static func run(node: Node3D, seconds: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if seconds <= 0.0:
		node.queue_free()
		return
	var mats := _prepare(node)
	var tween := node.create_tween().set_parallel(true)
	for m: BaseMaterial3D in mats:
		tween.tween_property(m, "albedo_color:a", 0.0, seconds)
	# Even with nothing fadeable, the tween still has to run the timer out so the
	# caller's sequencing (fade, then respawn) holds.
	tween.tween_interval(seconds)
	tween.chain().tween_callback(node.queue_free)


## Give every mesh under `node` its own transparent copy of each material it
## wears, and hand the copies back so they can be animated.
static func _prepare(node: Node) -> Array[BaseMaterial3D]:
	var out: Array[BaseMaterial3D] = []
	for mi: MeshInstance3D in _meshes(node):
		if mi.mesh == null:
			continue
		for si in range(mi.mesh.get_surface_count()):
			var src: Material = mi.get_active_material(si)
			if not (src is BaseMaterial3D):
				continue
			var dup: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.set_surface_override_material(si, dup)
			out.append(dup)
	return out


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out
