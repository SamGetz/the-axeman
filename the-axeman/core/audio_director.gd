extends Node
## Bounded runtime sound owner. It stays silent until Main confirms a successful
## session start, so save restoration and headless fixtures never produce audio.

const _MANIFEST := "res://data/sound_manifest.json"
const _VOICE_COUNT_2D := 16
const _VOICE_COUNT_3D := 16

var _session_active := false
var _cues: Dictionary = {}
var _streams: Dictionary = {}
var _voices_2d: Array[AudioStreamPlayer] = []
var _voices_3d: Array[AudioStreamPlayer3D] = []
var _world_root: Node3D = null
var _last_variant: Dictionary = {}
var _started_2d := PackedInt64Array()
var _started_3d := PackedInt64Array()
var _started_events: Dictionary = {}


func _ready() -> void:
	_load_manifest()
	for index in range(_VOICE_COUNT_2D):
		var voice := AudioStreamPlayer.new()
		voice.name = "SFX2D%d" % index
		add_child(voice)
		_voices_2d.append(voice)
		_started_2d.append(0)
	for index in range(_VOICE_COUNT_3D):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "SFX3D%d" % index
		voice.max_distance = 18.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(voice)
		_voices_3d.append(voice)
		_started_3d.append(0)


func begin_session() -> void:
	_session_active = true


func end_session() -> void:
	_session_active = false
	for voice in _voices_2d:
		voice.stop()
	for voice in _voices_3d:
		voice.stop()


## AudioStreamPlayer3D resolves listeners through its own viewport. The chopping
## yard is rendered in a SubViewport, so its pooled world voices must live in
## that same viewport rather than underneath this root-viewport autoload.
func register_world_root(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	_world_root = root
	for voice in _voices_3d:
		voice.stop()
		if voice.get_parent() != root:
			voice.reparent(root, false)


func unregister_world_root(root: Node3D) -> void:
	if _world_root != root:
		return
	for voice in _voices_3d:
		if not is_instance_valid(voice):
			continue
		voice.stop()
		if voice.get_parent() != self:
			voice.reparent(self, false)
	_world_root = null


func play_ui(cue_id: StringName, intensity := 1.0) -> bool:
	return _play(cue_id, null, intensity)


func play_world(cue_id: StringName, world_position: Vector3, intensity := 1.0) -> bool:
	return _play(cue_id, world_position, intensity)


func play_reward(kind: StringName, tier: int, phase: StringName) -> bool:
	var safe_tier := clampi(tier, 0, 3)
	var cue_id := StringName("%s_%s_t%d" % [kind, phase, safe_tier])
	# Cash launches are intentionally one shared receipt-glint cue.
	if not _cues.has(String(cue_id)) and kind == &"cash" and phase == &"launch":
		cue_id = &"cash_launch_t0"
	var played := _play(cue_id, null, 1.0 + float(safe_tier) * 0.08)
	if safe_tier == 3 and phase == &"launch":
		played = _play(&"jackpot", null, 1.0) or played
	return played


func _play(cue_id: StringName, world_position: Variant, intensity: float) -> bool:
	if not _session_active:
		return false
	var key := String(cue_id)
	if not _cues.has(key):
		return false
	var cue: Dictionary = _cues[key]
	var streams: Array = _streams.get(key, [])
	if streams.is_empty():
		return false
	var index := randi_range(0, streams.size() - 1)
	if streams.size() > 1 and index == int(_last_variant.get(key, -1)):
		index = (index + 1) % streams.size()
	_last_variant[key] = index
	var stream := streams[index] as AudioStream
	if stream == null:
		return false
	var pitch: Array = cue.get("pitch", [1.0, 1.0])
	var gain := float(cue.get("gain_db", -8.0)) + linear_to_db(maxf(0.05, intensity))
	var can_play_spatial := bool(cue.get("spatial", false)) \
		and world_position is Vector3 and is_instance_valid(_world_root)
	var polyphony := maxi(1, int(cue.get("polyphony", 1)))
	if can_play_spatial:
		var selected := _select_3d_voice(key, polyphony)
		selected.global_position = world_position
		selected.stream = stream
		selected.bus = StringName(cue.get("bus", "SFX/World"))
		selected.volume_db = gain
		selected.pitch_scale = randf_range(float(pitch[0]), float(pitch[1]))
		selected.set_meta("cue_id", key)
		selected.play()
	else:
		var selected := _select_2d_voice(key, polyphony)
		selected.stream = stream
		selected.bus = StringName(cue.get("bus", "SFX/Rewards"))
		selected.volume_db = gain
		selected.pitch_scale = randf_range(float(pitch[0]), float(pitch[1]))
		selected.set_meta("cue_id", key)
		selected.play()
	_started_events[key] = int(_started_events.get(key, 0)) + 1
	return true


func _select_2d_voice(cue_id: String, polyphony: int) -> AudioStreamPlayer:
	var same_cue: Array[int] = []
	for index in range(_voices_2d.size()):
		if _voices_2d[index].playing \
				and String(_voices_2d[index].get_meta("cue_id", "")) == cue_id:
			same_cue.append(index)
	if same_cue.size() >= polyphony:
		return _oldest_2d(same_cue)
	for index in range(_voices_2d.size()):
		if not _voices_2d[index].playing:
			_started_2d[index] = Time.get_ticks_msec()
			return _voices_2d[index]
	return _oldest_2d(range(_voices_2d.size()))


func _select_3d_voice(cue_id: String, polyphony: int) -> AudioStreamPlayer3D:
	var same_cue: Array[int] = []
	for index in range(_voices_3d.size()):
		if _voices_3d[index].playing \
				and String(_voices_3d[index].get_meta("cue_id", "")) == cue_id:
			same_cue.append(index)
	if same_cue.size() >= polyphony:
		return _oldest_3d(same_cue)
	for index in range(_voices_3d.size()):
		if not _voices_3d[index].playing:
			_started_3d[index] = Time.get_ticks_msec()
			return _voices_3d[index]
	return _oldest_3d(range(_voices_3d.size()))


func _oldest_2d(indices: Array) -> AudioStreamPlayer:
	var oldest := int(indices[0])
	for raw_index: Variant in indices:
		var index := int(raw_index)
		if _started_2d[index] < _started_2d[oldest]:
			oldest = index
	_started_2d[oldest] = Time.get_ticks_msec()
	return _voices_2d[oldest]


func _oldest_3d(indices: Array) -> AudioStreamPlayer3D:
	var oldest := int(indices[0])
	for raw_index: Variant in indices:
		var index := int(raw_index)
		if _started_3d[index] < _started_3d[oldest]:
			oldest = index
	_started_3d[oldest] = Time.get_ticks_msec()
	return _voices_3d[oldest]


func _load_manifest() -> void:
	var file := FileAccess.open(_MANIFEST, FileAccess.READ)
	if file == null:
		push_error("AudioDirector: missing sound manifest")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_cues = parsed.get("cues", {})
	for cue_id: String in _cues:
		var cue: Dictionary = _cues[cue_id]
		var loaded: Array[AudioStream] = []
		for path: String in cue.get("variations", []):
			var stream := load(path) as AudioStream
			if stream == null:
				push_error("AudioDirector: failed to preload '%s' for cue '%s'" % [path, cue_id])
				continue
			loaded.append(stream)
		_streams[cue_id] = loaded


func debug_session_active() -> bool:
	return _session_active


func debug_cue_count() -> int:
	return _cues.size()


func debug_preloaded_stream_count() -> int:
	var count := 0
	for streams: Array in _streams.values():
		count += streams.size()
	return count


func debug_started_event_count(cue_id: StringName) -> int:
	return int(_started_events.get(String(cue_id), 0))


func debug_world_root_registered() -> bool:
	return is_instance_valid(_world_root)


func debug_world_voice_viewport() -> Viewport:
	if _voices_3d.is_empty() or not is_instance_valid(_voices_3d[0]):
		return null
	return _voices_3d[0].get_viewport()


func debug_playing_voice_count() -> int:
	var count := 0
	for voice in _voices_2d:
		count += 1 if voice.playing else 0
	for voice in _voices_3d:
		count += 1 if voice.playing else 0
	return count
