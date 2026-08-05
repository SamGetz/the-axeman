extends Node
## FILE: res://core/tools/m7a_pacing_probe.gd
## ATTACHES TO: m7a_pacing_probe.tscn. Run NON-HEADLESS for Sam's measured
## 30-minute M7A tuning session. It observes the real main scene and prints
## timestamped CSV rows; it does not alter tuning, grant purchases, or wipe saves.
## Use a deliberately fresh save for the sign-off run.

var _started_ms := 0
var _logs := 0
var _swings := 0
var _failed_swings := 0
var _last_minute := -1
var _game: Node = null
const _M7A_CATALOGUE_SIZE := 5


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	_game = $Main.get_node("UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root/Chopping_Minigame")
	_game.log_completed.connect(_on_log_completed)
	_game.strike_resolved.connect(_on_strike_resolved)
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.order_completed.connect(_on_order_completed)
	GameState.haul_aways_changed.connect(_on_haul_away)
	GameState.building_tiers_changed.connect(_on_catalogue_changed)
	print("=== M7A PACING PROBE — use a fresh save; candidate tuning only ===")
	print("event,minutes,logs,swings,failures,cash,detail")
	_emit_row("start", "level=%d" % GameState.get_level())


func _process(_delta: float) -> void:
	var minute := int(floor(_minutes()))
	if minute > _last_minute:
		_last_minute = minute
		_emit_row("minute", "level=%d;order=%s:%d" % [
			GameState.get_level(), GameState.get_active_order_id(),
			GameState.get_active_order_progress()])


func _on_log_completed(species_id: StringName, pieces: int) -> void:
	_logs += 1
	_emit_row("log", "%s;pieces=%d" % [species_id, pieces])


func _on_strike_resolved(did_split: bool) -> void:
	_swings += 1
	if not did_split:
		_failed_swings += 1


func _on_cash_changed(value: int) -> void:
	_emit_row("cash", "balance=%d" % value)


func _on_order_completed(id: StringName, bonus: int) -> void:
	_emit_row("order_complete", "%s;bonus=%d" % [id, bonus])


func _on_haul_away(total: int) -> void:
	_emit_row("haul_away", "total=%d" % total)


func _on_catalogue_changed() -> void:
	var owned: Array[String] = []
	var catalogue := Shop.get_upgrades()
	for index in range(mini(_M7A_CATALOGUE_SIZE, catalogue.size())):
		var def: UpgradeDef = catalogue[index]
		if Shop.get_level(def.id) > 0:
			owned.append(String(def.id))
	_emit_row("purchase", "+".join(owned))
	if owned.size() == _M7A_CATALOGUE_SIZE:
		_emit_row("all_five", "first-level catalogue complete")


func _emit_row(event: String, detail: String) -> void:
	print("%s,%.2f,%d,%d,%d,%d,%s" % [event, _minutes(), _logs, _swings,
		_failed_swings, GameState.get_cash(), detail])


func _minutes() -> float:
	return float(Time.get_ticks_msec() - _started_ms) / 60000.0
