extends Node
## FILE: res://scenes/main.gd
## ATTACHES TO: Main (Node), the root of res://scenes/main.tscn.
##
## M2 — main scene shell. Owns the A10 2D/3D mode switch and nothing else:
##   2D mode: Action_Viewport stops rendering, 3D_World_Root stops processing.
##   3D mode (on EventBus.minigame_entered): both restored.
## No gameplay logic lives here. Gameplay UI goes in UI_Overlay (A9), never
## UI_Canvas.
##
## Temp debug keys (see the block at the bottom): M enters/leaves the 3D mode,
## T swaps between the M4 chopping block and the M5 tree felling scene.

@onready var _action_viewport: SubViewport = $"UI_Canvas/SubViewportContainer/Action_Viewport"
@onready var _world_root: Node3D = $"UI_Canvas/SubViewportContainer/Action_Viewport/3D_World_Root"


func _ready() -> void:
	EventBus.minigame_entered.connect(_on_minigame_entered)
	EventBus.minigame_exited.connect(_on_minigame_exited)
	_enter_2d_mode()


func _on_minigame_entered(_biome: Enums.Biome) -> void:
	_enter_3d_mode()


func _on_minigame_exited() -> void:
	_enter_2d_mode()


func _enter_2d_mode() -> void:
	# A10: while in 2D management mode the 3D world neither renders nor thinks.
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_world_root.process_mode = Node.PROCESS_MODE_DISABLED


func _enter_3d_mode() -> void:
	_action_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_root.process_mode = Node.PROCESS_MODE_INHERIT


# ---------------------------------------------------------------------------
# M2 TEMPORARY DEBUG — remove when M7 provides the real minigame entry flow.
# Press M to toggle between 2D and 3D mode so the pixel pipeline can be
# eyeballed from the main scene. Uses the real EventBus signals (A7) so the
# production path is what gets exercised.
#
# M5 TEMPORARY DEBUG — press T to swap which mini-game is loaded under
# 3D_World_Root (M4 chopping block <-> M5 tree felling). Only ever ONE is in the
# tree: each registers its own camera with GameFeel on enter and hands it back on
# exit, so having both alive at once would leave GameFeel holding the wrong one.
# Delete this block together with the M key when M7 lands the real entry flow.
# ---------------------------------------------------------------------------
const _MINIGAMES := [
	"res://scenes/3d_action/chopping_minigame.tscn",
	"res://scenes/3d_action/tree_felling.tscn",
]

var _debug_in_minigame := false
var _debug_minigame := 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_M:
			if _debug_in_minigame:
				EventBus.minigame_exited.emit()
			else:
				EventBus.minigame_entered.emit(Enums.Biome.PINE_FOREST)
			_debug_in_minigame = not _debug_in_minigame
		KEY_T:
			_debug_swap_minigame()


func _debug_swap_minigame() -> void:
	_debug_minigame = (_debug_minigame + 1) % _MINIGAMES.size()
	for child in _world_root.get_children():
		_world_root.remove_child(child)
		child.queue_free()
	# The outgoing scene unregisters its camera in _exit_tree, which queue_free
	# defers to the end of the frame — so wait for it before the new scene claims
	# the camera, or the unregister lands last and GameFeel is left with none.
	await get_tree().process_frame
	var scene: PackedScene = load(_MINIGAMES[_debug_minigame])
	if scene == null:
		push_error("main: could not load '%s'" % _MINIGAMES[_debug_minigame])
		return
	_world_root.add_child(scene.instantiate())
	print("M5 DEBUG: mini-game -> %s" % _MINIGAMES[_debug_minigame].get_file())
