class_name XPOrb
extends MeshInstance3D
## FILE: res://scenes/3d_action/xp_orb.gd
## ATTACHES TO: nothing authored — instances are built in code by
## chopping_minigame._burst_xp_orbs() and parented under the mini-game root.
##
## ONE GREEN EXPERIENCE ORB (Creative Director call, 2026-08-02: *"when the log is
## finally split, the log should also drop a bunch of green 'exp orbs' that get
## absorbed in to the player (like in minecraft)"*).
##
## Two phases, because that is what reads as Minecraft: a SCATTER, where the orb
## pops off the block on a little ballistic arc and settles, and a DRAW, where it
## gives up and rushes the player, accelerating the whole way in. The rush is what
## makes it feel collected rather than merely faded out.
##
## IT IS PURELY COSMETIC AND CARRIES NO STATE. The XP is banked the instant the log
## is finished, not when an orb lands — otherwise quitting during the half-second
## of flight would cost the player the log they just chopped, and the save would
## disagree with what they watched happen. The orb is the receipt, not the payment.
##
## Script-animated rather than physics, exactly like the on-block pieces
## (piece_animator.gd): A12 caps active rigid bodies, and spending that budget on
## confetti would push real firewood out of the simulation.
##
## EVERY NUMBER HERE IS A PLACEHOLDER per Directive 3.

## Shared across every orb ever spawned — one sphere and one material for the
## whole effect, rather than a fresh pair per orb for the renderer to track.
static var _shared_mesh: SphereMesh = null
static var _shared_mat: StandardMaterial3D = null

var _target: Node3D = null
var _origin := Vector3.ZERO
var _scatter := Vector3.ZERO
var _age := 0.0
var _delay := 0.0
var _scatter_time := 0.35
var _draw_time := 0.55
var _spin := 0.0


static func _shared() -> Array:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.018
		_shared_mesh.height = 0.036
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4

		_shared_mat = StandardMaterial3D.new()
		# UNSHADED, and that is load-bearing: an orb is a light source in the
		# fiction, and a lit one would go dim in the stump's shadow exactly where
		# most of them are born. Same reasoning as the failure scar.
		_shared_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_mat.albedo_color = Color(0.45, 1.0, 0.35)
		_shared_mat.emission_enabled = true
		_shared_mat.emission = Color(0.35, 1.0, 0.3)
		_shared_mat.emission_energy_multiplier = 2.0
	return [_shared_mesh, _shared_mat]


## `target` is what the orb flies into — the camera, which is where the player is.
func setup(from: Vector3, target: Node3D, delay: float, scatter_radius: float) -> void:
	var shared := _shared()
	mesh = shared[0]
	material_override = shared[1]

	_target = target
	_origin = from
	_delay = delay
	position = from
	# Hidden until its turn: a burst of twelve orbs all leaving on the same frame
	# reads as one object, and the stagger is what makes it read as a handful.
	visible = false

	var angle := randf() * TAU
	var reach := scatter_radius * (0.45 + randf() * 0.55)
	_scatter = from + Vector3(cos(angle) * reach, 0.10 + randf() * 0.14, sin(angle) * reach)
	_scatter_time = 0.28 + randf() * 0.16
	_draw_time = 0.42 + randf() * 0.24
	_spin = randf_range(-6.0, 6.0)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	_age += delta
	if _age < _delay:
		return
	visible = true
	var t := _age - _delay

	if t < _scatter_time:
		# Pop out and up, easing out, with a little gravity sag on the way — a
		# straight lerp reads as a slide rather than a toss.
		var k := t / _scatter_time
		var eased := 1.0 - pow(1.0 - k, 3.0)
		position = _origin.lerp(_scatter, eased)
		position.y -= 0.06 * k * k
	else:
		var k := clampf((t - _scatter_time) / _draw_time, 0.0, 1.0)
		# Accelerating INTO the player (cubic), which is the whole feel of being
		# collected: it hesitates, then snaps home.
		var eased := k * k * k
		var dest := _target.global_position
		position = _scatter.lerp(dest, eased)
		# Shrink as it arrives so it vanishes into the player rather than clipping
		# through the near plane as a full-size ball.
		var s := maxf(0.05, 1.0 - eased * 0.9)
		scale = Vector3(s, s, s)
		if k >= 1.0:
			queue_free()
			return

	rotate_y(_spin * delta)
