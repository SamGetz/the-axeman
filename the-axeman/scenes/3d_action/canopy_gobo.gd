extends MeshInstance3D
## FILE: res://scenes/3d_action/canopy_gobo.gd
## ATTACHES TO: MeshInstance3D "CanopyGobo", child of the
## res://scenes/3d_action/chopping_minigame.tscn root.
##
## Fakes an animated leaf-canopy gobo: an alpha-scissor cutout quad hung
## between the sun and ground so it casts a dappled shadow in Compatibility.
## The node itself is shadow-only and needs the sibling directional light.
##
## Sway is a smoothly-interpolated random walk of the shader's UV offset —
## Sway drifts between random offsets with cubic easing instead of snapping.
##
## EVERY value below is a PLACEHOLDER (Directive 3): tune live with Sam in F6.

const _GOBO_TEX := preload("res://assets/textures/leaves_gobo_tilable.jpg")
const _SHADER := preload("res://assets/shaders/canopy_gobo.gdshader")

@export var canopy_size := Vector2(8.0, 8.0)   # world-space quad footprint (m)
@export var canopy_height := 3.0               # height above origin the quad hangs at
@export var tile_scale := 3.0                  # how many times the texture repeats across the quad
@export var alpha_scissor_threshold := 0.45    # lower = more light gaps, higher = denser canopy
@export var sway_amount := 0.05                # UV-space offset of each waypoint
@export var sway_step_sec := 0.35              # seconds to drift from one waypoint to the next
@export var sway_positions := 6                # distinct random waypoints in the loop before it repeats

var _mat: ShaderMaterial
var _anim_player: AnimationPlayer


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = canopy_size
	quad.orientation = PlaneMesh.FACE_Y
	mesh = quad
	position = Vector3(0.0, canopy_height, 0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	_mat = ShaderMaterial.new()
	_mat.shader = _SHADER
	_mat.set_shader_parameter("gobo_tex", _GOBO_TEX)
	_mat.set_shader_parameter("tile_scale", tile_scale)
	_mat.set_shader_parameter("alpha_scissor_threshold", alpha_scissor_threshold)
	_mat.set_shader_parameter("uv_offset", Vector2.ZERO)
	material_override = _mat

	_build_sway_animation()


func _build_sway_animation() -> void:
	var anim := Animation.new()
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, ".:material_override:shader_parameter/uv_offset")
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)

	var waypoints: Array[Vector2] = []
	for i in range(sway_positions):
		waypoints.append(Vector2(randf_range(-sway_amount, sway_amount), randf_range(-sway_amount, sway_amount)))
	for i in range(waypoints.size()):
		anim.track_insert_key(track, i * sway_step_sec, waypoints[i])
	# repeat the first waypoint at the end so the loop closes without a pop
	anim.track_insert_key(track, waypoints.size() * sway_step_sec, waypoints[0])
	anim.length = waypoints.size() * sway_step_sec
	anim.loop_mode = Animation.LOOP_LINEAR

	var lib := AnimationLibrary.new()
	lib.add_animation(&"sway", anim)
	_anim_player = AnimationPlayer.new()
	add_child(_anim_player)
	_anim_player.add_animation_library("", lib)
	_anim_player.play("sway")
