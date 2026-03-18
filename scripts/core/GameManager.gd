extends Node

# GameManager owns the high-level "shell" flow for this prototype.
# It swaps between Guild Hall, Expedition Board, and Dispatch confirmation
# while keeping shared runtime state in one place.

const GUILD_HALL_SCENE := preload("res://scenes/guild_hall/GuildHall.tscn")
const EXPEDITION_BOARD_SCENE := preload("res://scenes/expedition_board/ExpeditionBoard.tscn")
const DISPATCH_SCREEN_SCENE := preload("res://scenes/dispatch/DispatchScreen.tscn")

var selected_expedition_for_activation: Dictionary = {}

var _guild_hall_controller: GuildHallController
var _expedition_board_controller: ExpeditionBoardController
var _dispatch_controller: DispatchController
var _mounted_screen: Control

@onready var _ui_root: Control = $CanvasLayer/UIRoot


func _ready() -> void:
	_show_guild_hall()


func get_selected_expedition_for_activation() -> Dictionary:
	# Duplicate keeps outside callers from mutating manager-owned state.
	return selected_expedition_for_activation.duplicate(true)


func _show_guild_hall() -> void:
	if _guild_hall_controller == null:
		_guild_hall_controller = GUILD_HALL_SCENE.instantiate() as GuildHallController
		_guild_hall_controller.open_expedition_board_requested.connect(_on_open_expedition_board_requested)

	_show_screen(_guild_hall_controller)
	_guild_hall_controller.set_active_expedition_status(selected_expedition_for_activation)


func _show_expedition_board() -> void:
	if _expedition_board_controller == null:
		_expedition_board_controller = EXPEDITION_BOARD_SCENE.instantiate() as ExpeditionBoardController
		_expedition_board_controller.expedition_dispatch_requested.connect(_on_expedition_dispatch_requested)
		_expedition_board_controller.return_to_guild_hall_requested.connect(_on_return_to_guild_hall_requested)

	_show_screen(_expedition_board_controller)


func _show_dispatch_screen(expedition_data: Dictionary) -> void:
	if _dispatch_controller == null:
		_dispatch_controller = DISPATCH_SCREEN_SCENE.instantiate() as DispatchController
		_dispatch_controller.confirmed.connect(_on_dispatch_confirmed)
		_dispatch_controller.canceled.connect(_on_dispatch_canceled)

	_show_screen(_dispatch_controller)
	_dispatch_controller.set_expedition_data(expedition_data)


func _show_screen(screen: Control) -> void:
	if screen == null:
		return

	if _mounted_screen != null and is_instance_valid(_mounted_screen) and _mounted_screen.get_parent() == _ui_root:
		_ui_root.remove_child(_mounted_screen)

	if screen.get_parent() != null:
		screen.get_parent().remove_child(screen)

	_ui_root.add_child(screen)
	if screen is Control:
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.offset_left = 0.0
		screen.offset_top = 0.0
		screen.offset_right = 0.0
		screen.offset_bottom = 0.0

	screen.show()
	_mounted_screen = screen


func _on_open_expedition_board_requested() -> void:
	_show_expedition_board()


func _on_return_to_guild_hall_requested() -> void:
	_show_guild_hall()


func _on_expedition_dispatch_requested(expedition_data: Dictionary) -> void:
	_show_dispatch_screen(expedition_data)


func _on_dispatch_confirmed(expedition_data: Dictionary) -> void:
	# This is the shared runtime handoff for the next milestone's active expedition loop.
	selected_expedition_for_activation = expedition_data.duplicate(true)
	print("Dispatch confirmed: %s" % str(selected_expedition_for_activation.get("id", "unknown")))

	if _expedition_board_controller != null:
		_expedition_board_controller.replace_expedition_by_id(
			str(selected_expedition_for_activation.get("id", "")),
			selected_expedition_for_activation
		)

	_show_guild_hall()


func _on_dispatch_canceled() -> void:
	_show_expedition_board()
