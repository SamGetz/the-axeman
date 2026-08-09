class_name StartupMenu
extends Control
## FILE: res://scenes/2d_management/startup_menu.gd
## ATTACHES TO: StartupMenu, instanced above the dormant yard by main.tscn.
##
## This is presentation only. Main owns the boot transaction because it already
## owns save/load and autosave wiring. The menu emits intent and never mutates
## GameState, InventoryManager, or the save file itself.

signal new_game_requested
signal load_game_requested

var _has_save := false

@onready var _new_game_button: Button = %NewGameButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _status_label: Label = %StatusLabel
@onready var _footer: Label = %Footer
@onready var _new_game_confirmation: ConfirmationDialog = %NewGameConfirmation


func _ready() -> void:
	_footer.text = "Progress saves automatically. · Alpha %s · %s" % [
		ProjectSettings.get_setting("application/config/version", "unversioned"),
		ProjectSettings.get_setting("application/config/build_date", "undated"),
	]
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(load_game_requested.emit)
	_new_game_confirmation.confirmed.connect(new_game_requested.emit)


func configure(has_save: bool) -> void:
	_has_save = has_save
	_load_game_button.disabled = not has_save
	_load_game_button.tooltip_text = "Continue from the last autosave." if has_save \
		else "No saved yard was found."
	_status_label.text = "A saved yard is ready." if has_save \
		else "No save found — begin a new yard."
	_new_game_button.grab_focus()


func show_error(message: String) -> void:
	_status_label.text = message


func dismiss() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func _on_new_game_pressed() -> void:
	if _has_save:
		_new_game_confirmation.popup_centered()
		return
	new_game_requested.emit()
