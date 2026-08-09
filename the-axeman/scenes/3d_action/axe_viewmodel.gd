class_name AxeViewmodel
extends Node3D
## FILE: res://scenes/3d_action/axe_viewmodel.gd
## ATTACHES TO: AxeViewmodelAnchor (Node3D), a CHILD OF THE CHOPPING CAMERA in
## res://scenes/3d_action/chopping_minigame.tscn. Its own children are fixed:
##
##   Camera3D
##   └── AxeViewmodelAnchor      (this script — fixed to the camera, aims the swing)
##       ├── AxeAnimationRoot    (Node3D — the ONLY node the animation moves)
##       │   └── axe_basic       (the imported FBX; scale lives here)
##       └── AnimationPlayer     (plays "swing" from res://data/axe_swing_lib.tres)
##
## REPLACES `axe_rig.gd` (deleted 2026-08-02, recoverable from git). That rig flew
## a world-space axe from the impact point to the wood on a hand-built Bezier with
## two euler poses, all of it hardcoded in script — which is why the swing read as
## clunky and why there was no way to tune it without editing GDScript. This is a
## VIEWMODEL: the axe is bolted to the camera and swings in the camera's own space,
## so it reads as the player's own overhead chop, and the entire motion is an
## AnimationPlayer track Sam can scrub, re-key and re-time in the editor.
##
## THE ANIMATION OWNS THE TIMING, INCLUDING THE GAMEPLAY BEAT. `swing` carries a
## METHOD TRACK whose key calls `_on_swing_contact()` on this node at the frame the
## blade bites; that emits `contact`, and the mini-game resolves the split or the
## scar there. So moving the contact key in the editor moves when the wood breaks —
## the picture and the mechanic cannot drift apart, which is exactly what they did
## when the axe was tweened for `swing_time` (1.0 s in the scene) while the split
## fired off a separate `anticipation_sec` timer (0.1 s): the log came apart while
## the axe was still up in the air.
##
## The method key is called DEFERRED (AnimationMixer's default callback mode). The
## split adds and frees nodes, and doing that from inside the mixer's own process
## is asking for trouble; one frame of slack costs nothing a player can see.
##
## FAILSAFE, and it is load-bearing: the mini-game does NOT trust this signal to
## arrive. `contact` is emitted by a key in an editable data file, so an animation
## re-keyed without one would leave a strike pending forever and soft-lock the
## chop loop. `contact_time()` lets the caller arm its own deadline — see
## chopping_minigame._strike_timeout().

## The frame the blade bites. The mini-game resolves the strike here.
signal contact
## The whole swing, recovery included, is over and the axe is out of frame again.
signal swing_finished

## Name of the swing in the AnimationPlayer's library. The method track inside it
## is what fires `contact`; see res://core/tools/build_axe_swing.gd.
@export var swing_anim := &"swing"
## Post-contact recoil played only when the landed strike does not split the wood.
## It starts from the swing's exact contact pose, then reverses the overhead entry.
@export var bounce_anim := &"bounce"

@export_group("Reach")
## How much further past the grip the head reaches, in metres. Creative Director
## call, 2026-08-02: *"I want the axe to land a little bit ahead of the mouse click
## location - right now it sits just behind and it doesnt look like it actually
## striking the log."* PLACEHOLDER (Directive 3) — tune it live in the Inspector.
##
## IT IS APPLIED AS A SCALE ON THE MODEL, NOT AS A TRANSLATION, and that is forced
## rather than chosen. The grip is the animation's pivot and the handle butt sits
## exactly on it, with only about 5 cm of margin below the bottom of the frame at
## the contact pose — so pushing the rig forward along the view, or up its own
## handle, buys reach by dragging the butt into shot as a floating stub (measured:
## 0.10 m of translation puts it 84% down the screen). Scaling moves the FAR end
## and leaves the pivot exactly where the animation put it, which is why it costs
## nothing the player can see except a slightly larger axe.
##
## Set to 0 to render the axe exactly as authored.
@export var extra_reach := 0.14: set = set_extra_reach

@export_group("Aim")
## The anchor is "fixed to the camera" in the sense that it never leaves it — but
## a swing that lands in the same pixel however far off-centre you clicked reads
## as a cutscene rather than as your own axe. These lean the WHOLE rig toward the
## click before the animation plays, so the authored motion is never touched.
## PLACEHOLDERS (Directive 3) — set both to 0 for a rigidly fixed viewmodel.
@export var aim_yaw_deg := 6.0
@export var aim_pitch_deg := 4.0

@onready var _root: Node3D = $AxeAnimationRoot
@onready var _axe_model: Node3D = $AxeAnimationRoot/axe_basic
@onready var _anim: AnimationPlayer = $AnimationPlayer

## The imported axe is 0.502 m from its grip/pivot to its head before the scene's
## authored model scale is applied. Keep this beside the one place that uses it:
## it turns a designer-facing distance in metres into a scale multiplier.
const _RAW_AXE_REACH := 0.502
## Temporary art treatment approved 2026-08-04: reuse the current axe mesh and
## textures, multiplying them toward a cool blue variant until an art-directed
## upgraded asset exists.
const _BALANCED_AXE_TINT := Color(0.62, 0.82, 1.0, 1.0)

var _speed := 1.0
## M7C Ready Stance: how much faster than `_speed` the WIND-UP (swing start
## through the contact key) plays. Only the wind-up is affected — the
## follow-through after contact always resumes at the ordinary `_speed`, so a
## shorter wind-up reads as "the blade drops quicker", not as clipped frames.
## See set_windup_scale() and chopping_minigame.current_windup_scale().
var _windup_scale := 1.0
var _authored_model_scale := Vector3.ONE
var _balanced_enabled := false


func _ready() -> void:
	if _axe_model != null:
		_authored_model_scale = _axe_model.scale
		_apply_extra_reach()
	# Out of frame until asked for. The animation's rest pose already parks the axe
	# off-screen, but hiding it means a half-authored or missing animation can never
	# leave an axe floating in the middle of the yard.
	if _root != null:
		_root.visible = false
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)


func set_extra_reach(value: float) -> void:
	extra_reach = maxf(value, 0.0)
	if is_node_ready():
		_apply_extra_reach()


func _apply_extra_reach() -> void:
	if _axe_model == null:
		return
	# Scale from the imported model's origin: that origin is the handle butt/grip,
	# so this moves the head farther through the clicked point without shifting the
	# pivot that Sam's animation keys were authored around. Use the captured scene
	# scale every time so live slider changes cannot compound.
	var authored_reach := _RAW_AXE_REACH * _authored_model_scale.y
	if authored_reach <= 0.0:
		return
	_axe_model.scale = _authored_model_scale * (1.0 + extra_reach / authored_reach)


## Immediate colour-variant consequence for the Balanced Axe purchase. Surface
## overrides are duplicated per instance, so the imported FBX and its shared
## materials remain untouched and can still be replaced by final authored art.
func set_balanced_upgrade(enabled: bool) -> void:
	set_equipment_upgrade(&"balanced_axe" if enabled else &"", 0,
		_BALANCED_AXE_TINT if enabled else Color.WHITE)


## Placeholder visual swap seam. Today every stage reuses the stable axe asset
## and gets a distinct per-instance tint; final models can replace each
## EquipmentDef presentation path without touching ownership or proc behavior.
func set_equipment_upgrade(equipment_id: StringName, stage: int, tint: Color) -> void:
	_balanced_enabled = equipment_id != &""
	if _axe_model == null:
		return
	var parts: Array[MeshInstance3D] = []
	for node in _axe_model.find_children("*", "MeshInstance3D", true, false):
		parts.append(node as MeshInstance3D)
	for part: MeshInstance3D in parts:
		if part.mesh == null:
			continue
		for surface in range(part.mesh.get_surface_count()):
			part.set_surface_override_material(surface, null)
	if equipment_id == &"":
		_axe_model.remove_meta("art_status")
		_axe_model.remove_meta("equipment_id")
		return
	_axe_model.set_meta("art_status", "temporary_colour_variant_existing_axe_stage_%d" % stage)
	_axe_model.set_meta("equipment_id", equipment_id)
	for part: MeshInstance3D in parts:
		if part.mesh == null:
			continue
		for surface in range(part.mesh.get_surface_count()):
			part.set_surface_override_material(surface,
				_tinted_material(part.get_active_material(surface), tint))


func has_balanced_color_variant() -> bool:
	if _axe_model == null:
		return false
	for node in _axe_model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part == null or part.mesh == null:
			continue
		for surface in range(part.mesh.get_surface_count()):
			if part.get_surface_override_material(surface) != null:
				return true
	return false


func _tinted_material(source: Material, tint: Color) -> Material:
	if source is BaseMaterial3D:
		var material := source.duplicate() as BaseMaterial3D
		var colour := material.albedo_color
		material.albedo_color = Color(colour.r * tint.r, colour.g * tint.g,
			colour.b * tint.b, colour.a)
		return material
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = tint
	fallback.roughness = 0.75
	return fallback


## Play the swing. `aim` is the click in normalised screen coordinates — (0,0) is
## the centre of the frame, x right, y UP, roughly +/-1 at the edges.
func swing(aim := Vector2.ZERO) -> void:
	if _anim == null or not _anim.has_animation(swing_anim):
		push_warning("AxeViewmodel: no '%s' animation — the swing will not play." % swing_anim)
		return
	_apply_aim(aim)
	if _root != null:
		_root.visible = true
	# Windup scale applies from the first frame; _on_swing_contact() restores the
	# ordinary rate the instant the blade bites, so the follow-through is always
	# authored speed regardless of how fast the drop was.
	_anim.speed_scale = _speed * _windup_scale
	_anim.play(swing_anim)
	_anim.seek(0.0, true)   # true = update now, so frame one is the rest pose


## Branch away from the successful follow-through after the mini-game has resolved
## the contact roll. Returns false if the editable animation has been removed; the
## current swing then simply continues, which is a safe visual fallback.
func bounce() -> bool:
	if _anim == null or not _anim.has_animation(bounce_anim):
		push_warning("AxeViewmodel: no '%s' animation — failed strike has no recoil." % bounce_anim)
		return false
	if _root != null:
		_root.visible = true
	_anim.speed_scale = _speed
	_anim.play(bounce_anim)
	_anim.seek(0.0, true)
	return true


## How much faster than authored the swing plays. The mini-game drives this off
## the swing-speed skill so "5% faster between swings" speeds up the SWING, not
## just a dead wait after it — an upgrade you can see is worth more than one you
## can only measure.
func set_speed(speed: float) -> void:
	_speed = maxf(speed, 0.01)
	# A live change mid-swing (not something any current caller does — set_speed
	# is always called before swing()) resets to the ordinary rate rather than
	# guessing whether the swing is still in its wind-up; _on_swing_contact()
	# would otherwise be the only thing that can safely make that call.
	if _anim != null and _anim.is_playing():
		_anim.speed_scale = _speed


## M7C Ready Stance: how much faster than `set_speed()`'s rate the wind-up
## plays. `_swing_axe()` sets this immediately before every `swing()` call, from
## `chopping_minigame.current_windup_scale()`. 1.0 = authored rate, unaffected.
func set_windup_scale(scale: float) -> void:
	_windup_scale = maxf(scale, 0.01)


func is_swinging() -> bool:
	return _anim != null and _anim.is_playing()


## Authored length of the whole swing, in seconds, at the CURRENT speed AND the
## current wind-up scale. Two segments, because only the wind-up is boosted:
## the pre-contact portion plays at `_speed * _windup_scale`, the post-contact
## follow-through at plain `_speed`. At the default `_windup_scale == 1.0` this
## is numerically identical to the un-split calculation it replaces.
func swing_duration() -> float:
	if _anim == null or not _anim.has_animation(swing_anim):
		return 0.0
	var length := _anim.get_animation(swing_anim).length
	var contact := _authored_contact_time()
	if contact < 0.0:
		# No contact key to split on — fall back to the whole-length reading.
		return length / _speed
	var pre := contact / (_speed * _windup_scale)
	var post := (length - contact) / _speed
	return pre + post


## When the blade bites, in seconds from the start of the swing, at the CURRENT
## speed AND wind-up scale (the whole contact key falls inside the wind-up
## segment by definition). -1.0 if the animation carries no contact key at all
## — which the caller must treat as "this animation cannot resolve a strike",
## not as "time zero".
func contact_time() -> float:
	var t := _authored_contact_time()
	return -1.0 if t < 0.0 else t / (_speed * _windup_scale)


func has_contact_key() -> bool:
	return _authored_contact_time() >= 0.0


## THE METHOD TRACK'S TARGET. Renaming it renames the key in
## res://data/axe_swing_lib.tres, and m4_acceptance checks the two still agree.
##
## Restores the ordinary (non-wind-up-boosted) rate BEFORE emitting `contact`,
## so Sam's authored follow-through always plays at the speed it was keyed at —
## Ready Stance only ever touches how fast the blade FALLS, never how it lands.
func _on_swing_contact() -> void:
	if _anim != null:
		_anim.speed_scale = _speed
	contact.emit()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != swing_anim and anim_name != bounce_anim:
		return
	if _root != null:
		_root.visible = false
	swing_finished.emit()


func _apply_aim(aim: Vector2) -> void:
	# Rotating about the camera's own axes: yaw NEGATIVE swings the rig toward
	# screen right, pitch follows aim.y directly (a low click aims low).
	var a := Vector2(clampf(aim.x, -1.0, 1.0), clampf(aim.y, -1.0, 1.0))
	rotation = Vector3(deg_to_rad(a.y * aim_pitch_deg), deg_to_rad(-a.x * aim_yaw_deg), 0.0)


## Walks the method track for the key that calls `_on_swing_contact`. Read off the
## animation rather than stored, for the same reason the level is derived from XP:
## a value copied out of a data file is a value that can disagree with it, and this
## one is edited by hand in the animation editor.
func _authored_contact_time() -> float:
	if _anim == null or not _anim.has_animation(swing_anim):
		return -1.0
	var anim := _anim.get_animation(swing_anim)
	for track in range(anim.get_track_count()):
		if anim.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in range(anim.track_get_key_count(track)):
			if anim.method_track_get_name(track, key) == &"_on_swing_contact":
				return anim.track_get_key_time(track, key)
	return -1.0
