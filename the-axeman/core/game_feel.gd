extends Node
## FILE: res://core/game_feel.gd
## ATTACHES TO: nothing directly. Autoload "GameFeel" (order 4, after
## GameState — Amendment 5). Single owner of A11 hit-pause and the camera
## shake. M4–M6 feed it hits via EventBus.action_hit_registered (already
## wired below); they never call Engine.time_scale themselves.
##
## Nothing here is a final tuning value: pause/shake numbers come from the
## GameFeelConfig embedded in res://data/game_config.tres and are tuned by the
## Creative Director. The 0.05 pause scale and the impact strength are the only
## literals, and they are flagged.

const _HIT_PAUSE_SCALE := 0.05   # A11 verbatim — NOT a tunable.
## Placeholder: how much trauma one registered hit adds (0..1). Whether this
## should scale with tool tier / piece size is an M4 tuning question for Sam.
const _IMPACT_STRENGTH := 1.0

var config: GameFeelConfig               # read-only for everyone else

var _active_pauses := 0                  # A11 overlap guard: last one out restores 1.0
var _trauma := 0.0                       # 0..1, decays every frame
var _camera: Camera3D = null
var _shaking := false                    # true while we are actively writing camera offsets
var _noise := FastNoiseLite.new()
var _noise_t := 0.0


func _ready() -> void:
	config = GameConfig.current().game_feel

	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.5

	# A7 signals only — EventBus (autoload 1) is guaranteed to exist by now.
	EventBus.action_hit_registered.connect(_on_action_hit_registered)
	EventBus.minigame_exited.connect(_on_minigame_exited)


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - config.camera_shake_decay * delta, 0.0)

	if _camera == null or not is_instance_valid(_camera):
		return

	if _trauma > 0.0:
		# Quadratic falloff makes small trauma feel calm and large trauma punchy.
		var shake := _trauma * _trauma * config.camera_shake_amplitude
		_noise_t += delta * 60.0
		_camera.h_offset = _noise.get_noise_2d(_noise_t, 0.0) * shake
		_camera.v_offset = _noise.get_noise_2d(0.0, _noise_t) * shake
		_shaking = true
	elif _shaking:
		# Trauma just reached zero — settle the frustum back exactly once.
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		_shaking = false


## ------------------------------------------------------------- public API

## Register a gameplay impact: adds trauma (shake) and, by default, triggers a
## hit-pause. strength is clamped to 0..1. Safe to call from anywhere; the pause
## is fire-and-forget.
##
## `with_pause = false` gives shake WITHOUT stopping time, for a blow that landed
## but did not resolve anything — the chopping game's failed swings use it, so a
## split still owns the punctuation of a time-stop and a bounced axe reads as a
## lesser event. Added 2026-08-01; an optional argument on a public method, so
## every existing caller and the A7 signal path are untouched.
func register_impact(strength: float, with_pause := true) -> void:
	strength = clampf(strength, 0.0, 1.0)
	_trauma = clampf(_trauma + strength, 0.0, 1.0)
	if with_pause:
		hit_pause()


## A11 hit-pause. Pins Engine.time_scale to 0.05 for `duration` real seconds
## (default = config.hit_pause_duration). Overlapping calls are counted so
## time_scale is only restored to 1.0 when the LAST pause expires — it can
## never get stuck low.
func hit_pause(duration := -1.0) -> void:
	if duration < 0.0:
		duration = config.hit_pause_duration

	Engine.time_scale = _HIT_PAUSE_SCALE
	_active_pauses += 1
	# create_timer(sec, process_always, process_in_physics, ignore_time_scale)
	# ignore_time_scale MUST be true (A11): otherwise the 0.05 scale would
	# stretch this very timer and the pause would never end correctly.
	await get_tree().create_timer(duration, true, false, true).timeout
	_active_pauses -= 1
	if _active_pauses <= 0:
		_active_pauses = 0
		Engine.time_scale = 1.0


## The action scene hands its active camera over on enter; GameFeel writes
## h_offset/v_offset on it (never position/rotation, so it never fights
## gameplay camera motion).
func register_camera(cam: Camera3D) -> void:
	if _camera != null and is_instance_valid(_camera) and _camera != cam:
		push_warning("GameFeel: a camera was already registered; replacing it.")
	_camera = cam
	_shaking = false


func unregister_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
	_camera = null
	_shaking = false


## Test/debug read-only accessor for current trauma (0..1).
func get_trauma() -> float:
	return _trauma


## ------------------------------------------------------------- A7 handlers

func _on_action_hit_registered(_hit_position: Vector3, _tool_tier: int, _direction: Enums.ChopDirection) -> void:
	register_impact(_IMPACT_STRENGTH)


func _on_minigame_exited() -> void:
	# Leave no shake bleeding into the next entry. Do NOT touch time_scale
	# here: any in-flight hit_pause owns it via the counter and its timer
	# ignores time_scale, so it still restores 1.0 on its own.
	_trauma = 0.0
	unregister_camera()
