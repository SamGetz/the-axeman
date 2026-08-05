class_name ProcBurst
extends Node3D
## FILE: res://scenes/3d_action/proc_burst.gd
## ATTACHES TO: nothing authored — instances are built in code by
## ProcBurst.spawn() and parented under the caller.
##
## THE PROC ANNOUNCEMENT (Creative Director call, 2026-08-04, replacing the
## earlier text banner: *"I dont think we need the banner when things proc, we
## can have a small red explosion effect for strength, blue for speed and
## yellow for technique"*, then, asked whether the branch's own UI color or a
## fixed red/blue/yellow palette: *"have the color be the color of the skill
## tree branch, just so theres no confusion"*). The color is READ from the
## proc's branch (SkillTree.branch_for_proc), never hardcoded here — Technique
## stays whatever its authored branch color is (green today, not yellow), and
## a future Follow-Up/Quick Study fire gets the same effect for free.
##
## A quick pop of small additive sparks flying outward from the cut point and
## fading, entirely code-built and script-animated — no Particles node. This
## project avoids GPUParticles3D under the Compatibility renderer the same way
## XPOrb does (see its header); a handful of script-driven quads is simpler
## and already-proven here.
##
## PURELY COSMETIC, carries no state, and frees itself when done — same rule
## XPOrb follows: nothing here can be quit-out-of mid-flight to change what
## already happened.
##
## THE FADE IS IN THE COLOUR, NOT THE ALPHA — the "square exp bubble" lesson
## XPOrb already paid for. An additive surface adds its RGB to whatever is
## behind it, so fading only alpha leaves a hard-edged card; the gradient
## texture below fades colour to black instead, and alpha rides along.
##
## EVERY NUMBER HERE IS A PLACEHOLDER per Directive 3 — spark count, speed,
## size and duration all want a Creative Director feel pass.

static var _shared_mesh: QuadMesh = null
## One cached material per branch colour, built once and reused by every burst
## of that colour — the same reasoning chopping_minigame caches cut materials
## per species rather than building fresh ones per piece.
static var _mat_cache: Dictionary = {}   # Color -> StandardMaterial3D

const _SPARK_COUNT := 8
const _QUAD_SIZE := 0.05
const _DURATION := 0.4      # seconds, PLACEHOLDER
const _SPEED_MIN := 0.6     # m/s, PLACEHOLDER
const _SPEED_MAX := 1.1

var _sparks: Array[MeshInstance3D] = []
var _dirs: Array[Vector3] = []
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _age := 0.0


## Spawns a burst of `color` at `world_pos`, parented under `parent`. Static
## convenience so a caller never has to remember the setup/add_child order —
## same shape as how chopping_minigame builds firewood/scar meshes.
static func spawn(parent: Node, world_pos: Vector3, color: Color) -> ProcBurst:
	_ensure_shared_mesh()
	var burst := ProcBurst.new()
	parent.add_child(burst)
	burst.global_position = world_pos
	burst._build(color)
	return burst


## Called while the chopping scene is constructed behind the startup screen so
## the first real proc does not have to build geometry, gradients and materials.
static func prewarm(colors: Array[Color]) -> void:
	_ensure_shared_mesh()
	for color: Color in colors:
		_material_for(color).get_rid()


static func _ensure_shared_mesh() -> void:
	if _shared_mesh != null:
		return
	_shared_mesh = QuadMesh.new()
	_shared_mesh.size = Vector2(_QUAD_SIZE, _QUAD_SIZE)
	_shared_mesh.get_rid()


func _build(color: Color) -> void:
	var mat := _material_for(color)
	for i in range(_SPARK_COUNT):
		var spark := MeshInstance3D.new()
		spark.mesh = _shared_mesh
		spark.material_override = mat
		add_child(spark)
		_sparks.append(spark)
		# Plain random spread reads as a pop just fine at this count; biased
		# upward a little so it reads as a small explosion, not a puddle.
		var dir := Vector3(
			randf_range(-1.0, 1.0), randf_range(0.2, 1.0), randf_range(-1.0, 1.0)
		).normalized()
		_dirs.append(dir)
		_speeds.append(randf_range(_SPEED_MIN, _SPEED_MAX))


func _process(delta: float) -> void:
	_age += delta
	var k := clampf(_age / _DURATION, 0.0, 1.0)
	for i in range(_sparks.size()):
		_sparks[i].position = _dirs[i] * _speeds[i] * _age
		var s := maxf(0.0, 1.0 - k)
		_sparks[i].scale = Vector3(s, s, s)
	if k >= 1.0:
		queue_free()


static func _material_for(color: Color) -> StandardMaterial3D:
	if _mat_cache.has(color):
		return _mat_cache[color]
	var mat := StandardMaterial3D.new()
	# UNSHADED for the same reason the failure scar and the XP orb are: this is
	# a light-emitting effect in the fiction, and a lit one would go dim in the
	# stump's own shadow, exactly where most of these fire.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = _spark_texture(color)
	_mat_cache[color] = mat
	return mat


static func _spark_texture(color: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 1.0),
		Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.5),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex
