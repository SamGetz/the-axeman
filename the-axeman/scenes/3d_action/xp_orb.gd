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
## FOUR PHASES, revised 2026-08-02 (Creative Director call: *"the experience should
## explode out a little and fall on to then bounce a little the ground near the log
## for a moment before flying to camera"*):
##
##   1. BURST   — the orb is thrown off the block on a real ballistic arc.
##   2. BOUNCE  — it lands on the yard floor near the log and bounces, losing
##                height and speed each time until it settles.
##   3. REST    — it sits there for a beat, bobbing, so the player SEES the wood's
##                worth lying on the ground before it is theirs.
##   4. DRAW    — it gives up and ARCS into the player, accelerating the whole way.
##
## It is a translucent bead wearing an additive halo, so it reads as a little light
## lying in the dirt rather than a green bead (Creative Director call, 2026-08-02:
## *"make the orbs glow a tiny amount as well and be a little transparent"*).
##
## The rest beat is the point of the revision: the old two-phase version lerped to a
## floating waypoint and left immediately, which read as one continuous swoosh. A
## burst that lands, settles and is THEN collected reads as loot.
##
## THE ARC IS INTEGRATED, NOT LERPED. Phases 1-2 advance a velocity under gravity
## and reflect it off the floor, because a bounce is exactly the thing a keyframed
## path cannot fake — the second hop has to be a consequence of the first landing,
## or every orb bounces identically. Only the final rush to the player is eased by
## hand, since that one is not physics but a magnet.
##
## WHERE IT LANDS IS AIMED, THOUGH. The horizontal speed is solved from the orb's
## own flight time so the first touchdown falls in a ring OUTSIDE the stump — an
## orb that lands on top of the block, or inside it, is the one thing the effect
## cannot look right doing.
##
## IT IS PURELY COSMETIC AND CARRIES NO STATE. The XP is banked the instant the log
## is finished, not when an orb lands — otherwise quitting during the second of
## flight would cost the player the log they just chopped, and the save would
## disagree with what they watched happen. The orb is the receipt, not the payment.
##
## Script-animated rather than physics, exactly like the on-block pieces
## (piece_animator.gd): A12 caps active rigid bodies, and spending that budget on
## confetti would push real firewood out of the simulation.
##
## EVERY NUMBER HERE IS A PLACEHOLDER per Directive 3.

enum Phase { FLIGHT, REST, DRAW }

## Shared across every orb ever spawned — one sphere, one halo and one material
## each for the whole effect, rather than a fresh set per orb for the renderer to
## track.
static var _shared_mesh: SphereMesh = null
static var _shared_mat: StandardMaterial3D = null
static var _halo_mesh: QuadMesh = null
static var _halo_mat: StandardMaterial3D = null

const _RADIUS := 0.018

# --- tuning (PLACEHOLDERS, Directive 3) ----------------------------------
const _GRAVITY := 9.0           # m/s^2 — the scene is ~0.5 m tall, so this reads brisk
const _POP_SPEED_MIN := 0.85    # upward kick off the block (m/s)
const _POP_SPEED_MAX := 1.55
const _BOUNCE := 0.46           # height kept per bounce
const _GROUND_DRAG := 0.62      # horizontal speed kept per bounce
const _SETTLE_SPEED := 0.35     # a bounce slower than this is not worth drawing (m/s)
const _FLIGHT_TIMEOUT := 2.5    # hard stop, so a stray orb can never hover forever
const _COLLECT_JITTER := 0.07   # how far out of step one orb may leave the ground
## HOW SHORT OF THE CAMERA THE ORB IS SWALLOWED (m), and it is not cosmetic
## trimming: flying to the camera's exact position means arriving at zero distance,
## where angular size explodes and a 2 cm bead fills a quarter of the screen. Caught
## in orb_shot — every orb was correct and two of them were billboards in the lens.
## It absorbs at arm's length instead.
const _ABSORB_DIST := 0.45
## ...and NOT all at the same point. Each orb ends somewhere on a disc this wide
## around the view axis, so the burst FANS OUT across the frame as it arrives, the
## way anything passing a camera does. Converging on one pixel in the middle of the
## screen is what made it look like the log was eating them.
##
## Sized against the frustum, not by eye: at `_ABSORB_DIST` this is about 24 deg off
## the view axis, so the orbs spread wide but stay ON SCREEN to the end. The first
## try was 0.34 and pushed most of the burst out past the frame edge, where being
## collected is indistinguishable from being lost.
const _ABSORB_SPREAD := 0.2
## How much of its size an orb gives up on the way in. It is deliberately LESS than
## the distance it closes, so apparent size still GROWS — see _process. Measured
## with orb_probe: the orb roughly triples on screen across the draw (about 4.7 deg
## of arc to about 13), which is what the eye reads as "it is coming at me".
const _DRAW_SHRINK := 0.25
const _BOB_RATE := 7.0
const _BOB_HEIGHT := 0.006

var _target: Node3D = null
var _phase: int = Phase.FLIGHT
var _vel := Vector3.ZERO
var _age := 0.0
var _delay := 0.0
var _phase_age := 0.0
var _floor_y := 0.0
var _rest_y := 0.0
var _collect_at := 0.9              # AGE, not a per-phase timer — see setup()
var _bob_phase := 0.0
var _draw_from := Vector3.ZERO
var _draw_time := 0.55
var _arc_up := 0.18                 # control point height, as a fraction of the trip
var _arc_side := 0.0                # ...and its lean, signed so the burst fans out
var _absorb_off := Vector2.ZERO     # where on the absorb disc THIS orb passes the lens
var _spin := 0.0


static func _shared() -> Array:
	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = _RADIUS
		_shared_mesh.height = _RADIUS * 2.0
		_shared_mesh.radial_segments = 8
		_shared_mesh.rings = 4

		_shared_mat = StandardMaterial3D.new()
		# UNSHADED, and that is load-bearing: an orb is a light source in the
		# fiction, and a lit one would go dim in the stump's shadow exactly where
		# most of them are born. Same reasoning as the failure scar.
		#
		# NOTE unshaded means `emission` is never read — an unshaded surface outputs
		# its albedo and nothing else. The glow is the halo below, which is a real
		# object rather than a post-process, because screen-space glow is not
		# something to rely on under gl_compatibility.
		_shared_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# A LITTLE TRANSPARENT (Creative Director call, 2026-08-02), so the orb reads
		# as light rather than as a painted bead.
		_shared_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_mat.albedo_color = Color(0.55, 1.0, 0.42, 0.78)

		_halo_mesh = QuadMesh.new()
		_halo_mesh.size = Vector2(_RADIUS * 7.0, _RADIUS * 7.0)

		_halo_mat = StandardMaterial3D.new()
		_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# ADDITIVE is what makes it a glow and not a green sticker: it only ever
		# brightens what is behind it, so it bleeds into the dirt around the orb.
		_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Face the player from wherever the camera has orbited to. `keep_scale`
		# matters: billboarding rebuilds the basis, and without it the shrink the
		# draw phase applies would be thrown away and the halo would arrive at the
		# camera full size.
		_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_halo_mat.billboard_keep_scale = true
		_halo_mat.albedo_texture = _halo_texture()
		# TINY, per the brief — the falloff does the work, the strength stays low.
		_halo_mat.albedo_color = Color(0.5, 1.0, 0.4, 0.5)
	return [_shared_mesh, _shared_mat]


## A soft round falloff, built in code rather than authored — it is 64 px of green
## fog and does not want to be an art dependency.
##
## THE FALLOFF IS IN THE COLOUR, NOT THE ALPHA, AND THAT IS THE WHOLE BUG THIS FIXES.
## An additive surface adds its RGB to what is behind it; fading only the alpha out
## to the rim left the corners still carrying full green, so every halo rendered as
## a hard flat SQUARE — which is the "square exp bubble". Black adds nothing, so the
## colour is what has to fade. The alpha is carried along for the ride.
##
## Diagnosed with core/tools/orb_probe.tscn, which parks halos at known distances:
## the texture dumped correct (centre alpha 0.53, corner 0.0) while the quads on
## screen were flat cards, which is what pinned it on the blend rather than the art.
static func _halo_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([
		Color(0.62, 1.0, 0.52, 1.0),
		Color(0.16, 0.34, 0.13, 0.35),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## `target` is what the orb flies into — the camera, which is where the player is.
## `ground_y` is the yard floor the burst falls onto, and `clear_radius` is the
## stump's own radius: the orb is aimed to touch down OUTSIDE it, "near the log"
## rather than on top of the block it just came off.
##
## `collect_at` is measured from the burst and is THE SAME FOR EVERY ORB IN IT
## (bar a few hundredths of jitter), which is what makes the whole handful leave the
## ground together — Creative Director call, 2026-08-02: *"so all the collecting
## happens at once"*. A per-orb rest timer, which is what this had first, stacked on
## top of each orb's own landing time and dribbled them home one at a time.
func setup(from: Vector3, target: Node3D, delay: float, scatter_radius: float,
		ground_y := 0.0, clear_radius := 0.0, collect_at := 0.9) -> void:
	var shared := _shared()
	mesh = shared[0]
	material_override = shared[1]

	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = _halo_mesh
	halo.material_override = _halo_mat
	add_child(halo)

	_target = target
	_delay = delay
	position = from
	# Hidden until its turn: a burst of twelve orbs all leaving on the same frame
	# reads as one object, and the stagger is what makes it read as a handful.
	visible = false

	_floor_y = ground_y + _RADIUS
	_rest_y = _floor_y
	_collect_at = collect_at + randf_range(0.0, _COLLECT_JITTER)
	_bob_phase = randf() * TAU
	_draw_time = 0.42 + randf() * 0.24
	_arc_up = randf_range(0.14, 0.30)
	_arc_side = randf_range(-0.22, 0.22)
	var off_angle := randf() * TAU
	# sqrt keeps the draw even across the disc rather than crowding the middle,
	# which is where the "all into one point" look came from.
	var off_reach := sqrt(randf()) * _ABSORB_SPREAD
	_absorb_off = Vector2(cos(off_angle), sin(off_angle)) * off_reach
	_spin = randf_range(-6.0, 6.0)

	var up := randf_range(_POP_SPEED_MIN, _POP_SPEED_MAX)
	# Solve the orb's OWN time to the floor, then pick the horizontal speed that
	# puts its first touchdown in the ring we want. Aiming the landing this way
	# survives any change to gravity or to the pop — the ring stays the ring.
	var drop := maxf(from.y - _floor_y, 0.01)
	var fall := (up + sqrt(up * up + 2.0 * _GRAVITY * drop)) / _GRAVITY
	# The jitter multiplies whichever floor wins, so the ring keeps its spread even
	# when the stump is wide enough to dictate the minimum throw.
	var reach := maxf(clear_radius * 1.15, scatter_radius) * randf_range(1.0, 1.5)
	var angle := randf() * TAU
	_vel = Vector3(cos(angle) * reach / fall, up, sin(angle) * reach / fall)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	_age += delta
	if _age < _delay:
		return
	visible = true
	_phase_age += delta

	match _phase:
		Phase.FLIGHT:
			_step_flight(delta)
			# Still bouncing when the burst is called home: it leaves from wherever
			# it is. Keeping the wave together beats letting one late orb straggle.
			if _age - _delay >= _collect_at:
				_begin_draw()
		Phase.REST:
			# A little bob on the spot. An orb sitting perfectly still on the floor
			# reads as dropped litter; one that breathes reads as waiting to be had.
			position.y = _rest_y + sin(_phase_age * _BOB_RATE + _bob_phase) * _BOB_HEIGHT
			if _age - _delay >= _collect_at:
				_begin_draw()
		Phase.DRAW:
			var k := clampf(_phase_age / _draw_time, 0.0, 1.0)
			# Accelerating INTO the player, which is the feel of being collected: it
			# hesitates, then comes. QUADRATIC, not cubic — orb_probe showed a cubic
			# ease left the orb almost stationary for the first 20 frames of the draw
			# and then crossed the last half of the trip in three, so the approach was
			# over before the eye could read it as an approach at all.
			var eased := k * k
			position = _draw_curve(_absorb_point(), eased)
			# IT SHRINKS BY LESS THAN IT CLOSES, so apparent size (scale / distance)
			# GROWS the whole way in. This is the entire read of "coming at the
			# player": the first cut shrank to a twentieth while converging on the
			# middle of the frame, and an object that gets smaller as it reaches the
			# centre of the screen is an object going AWAY — Sam saw it as the orbs
			# being absorbed into the log. The shrink that is left only keeps the
			# last few frames from becoming a wall of green.
			var s := maxf(0.05, 1.0 - eased * _DRAW_SHRINK)
			scale = Vector3(s, s, s)
			if k >= 1.0:
				queue_free()
				return

	rotate_y(_spin * delta)


## Where the orb actually ends: `_ABSORB_DIST` short of the player, ON THE CAMERA'S
## VIEW AXIS — which is the middle of the screen, and therefore reads as flying INTO
## the player.
##
## It used to back off along the line the orb was travelling, and since every orb
## starts on the ground that line came up from below: the burst converged under the
## lens and looked like it was being collected by the player's FEET (Creative
## Director, 2026-08-02). Where the orb came from should not decide where the player
## is standing.
func _absorb_point() -> Vector3:
	var cam := _target.global_transform
	return cam.origin - cam.basis.z * _ABSORB_DIST \
		+ cam.basis.x * _absorb_off.x + cam.basis.y * _absorb_off.y


## THE RUSH HOME IS A CURVE, NOT A LINE (Creative Director call, 2026-08-02: *"I
## also want the exp to arc towards the player, not just a direct line"*).
##
## A quadratic Bezier through a control point hung above and to one side of the
## midpoint: the orb swings up out of the dirt, leans around, and comes down into
## the player. The sideways lean is per-orb and signed, so a burst fans out into
## separate curves instead of a dozen orbs tracing the same one.
##
## Both offsets scale with the distance left to travel, so the arc keeps its shape
## whether the camera is orbited in close or pulled back.
func _draw_curve(dest: Vector3, t: float) -> Vector3:
	var to := dest - _draw_from
	var flat := Vector3(to.x, 0.0, to.z)
	var side := Vector3.RIGHT if flat.length_squared() < 0.000001 else Vector3.UP.cross(flat).normalized()
	var dist := to.length()
	var ctrl := _draw_from.lerp(dest, 0.5) + Vector3.UP * dist * _arc_up + side * dist * _arc_side
	# Quadratic Bezier, written out: two lerps and a lerp between them.
	var a := _draw_from.lerp(ctrl, t)
	var b := ctrl.lerp(dest, t)
	return a.lerp(b, t)


## Ballistic flight plus the bounces, integrated. Settling is a CONSEQUENCE of the
## bounces getting small rather than a timer, so a hard throw genuinely takes longer
## to come to rest than a soft one.
func _step_flight(delta: float) -> void:
	_vel.y -= _GRAVITY * delta
	position += _vel * delta

	if position.y <= _floor_y and _vel.y < 0.0:
		position.y = _floor_y
		if -_vel.y < _SETTLE_SPEED:
			_rest_y = _floor_y
			_enter(Phase.REST)
			return
		_vel.y = -_vel.y * _BOUNCE
		_vel.x *= _GROUND_DRAG
		_vel.z *= _GROUND_DRAG

	# Backstop: nothing in the maths should keep an orb airborne this long, but a
	# stuck orb would hang in the yard forever, and forever is a long time to look at.
	if _phase_age > _FLIGHT_TIMEOUT:
		position.y = _floor_y
		_rest_y = _floor_y
		_enter(Phase.REST)


func _begin_draw() -> void:
	_enter(Phase.DRAW)
	_draw_from = position


func _enter(phase: int) -> void:
	_phase = phase
	_phase_age = 0.0
