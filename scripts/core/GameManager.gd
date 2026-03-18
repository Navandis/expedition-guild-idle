extends Node2D

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


func _ready() -> void:
	_show_guild_hall()


func get_selected_expedition_for_activation() -> Dictionary:
	# Duplicate keeps outside callers from mutating manager-owned state.
	return selected_expedition_for_activation.duplicate(true)


func _show_guild_hall() -> void:
	_hide_all_screens()

	if _guild_hall_controller == null:
		_guild_hall_controller = GUILD_HALL_SCENE.instantiate() as GuildHallController
		add_child(_guild_hall_controller)
		_guild_hall_controller.open_expedition_board_requested.connect(_on_open_expedition_board_requested)

	_guild_hall_controller.show()
	_guild_hall_controller.set_active_expedition_status(selected_expedition_for_activation)


func _show_expedition_board() -> void:
	_hide_all_screens()

	if _expedition_board_controller == null:
		_expedition_board_controller = EXPEDITION_BOARD_SCENE.instantiate() as ExpeditionBoardController
		add_child(_expedition_board_controller)
		_expedition_board_controller.expedition_dispatch_requested.connect(_on_expedition_dispatch_requested)
		_expedition_board_controller.return_to_guild_hall_requested.connect(_on_return_to_guild_hall_requested)

	_expedition_board_controller.show()


func _show_dispatch_screen(expedition_data: Dictionary) -> void:
	# We keep the board node alive but hidden so cancel returns to the same board session.
	_hide_all_screens()

	if _dispatch_controller == null:
		_dispatch_controller = DISPATCH_SCREEN_SCENE.instantiate() as DispatchController
		add_child(_dispatch_controller)
		_dispatch_controller.confirmed.connect(_on_dispatch_confirmed)
		_dispatch_controller.canceled.connect(_on_dispatch_canceled)

	_dispatch_controller.show()
	_dispatch_controller.set_expedition_data(expedition_data)


func _hide_all_screens() -> void:
	if _guild_hall_controller != null:
		_guild_hall_controller.hide()
	if _expedition_board_controller != null:
		_expedition_board_controller.hide()
	if _dispatch_controller != null:
		_dispatch_controller.hide()


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
