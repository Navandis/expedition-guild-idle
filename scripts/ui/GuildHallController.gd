extends Control
class_name GuildHallController

# GuildHallController is the simple "home" view for this milestone.
# It displays placeholder resources, a button into the board, and a small
# status box that summarizes active expedition progress.

signal open_expedition_board_requested

@onready var _active_name_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/ActiveNameLabel
@onready var _remaining_time_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/RemainingTimeLabel
@onready var _active_status_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/StatusLabel

var _expedition_manager: ExpeditionManager


func _ready() -> void:
	$SafeArea/RootColumn/OpenBoardButton.pressed.connect(_on_open_board_pressed)
	# Polling each frame is acceptable for this prototype-sized status block.
	set_process(true)
	_refresh_active_status()


func _process(_delta: float) -> void:
	_refresh_active_status()


func set_expedition_manager(expedition_manager: ExpeditionManager) -> void:
	_expedition_manager = expedition_manager
	_refresh_active_status()


func _refresh_active_status() -> void:
	# onready refs can be null during scene teardown/reparenting.
	if _active_name_label == null or _remaining_time_label == null or _active_status_label == null:
		return

	if _expedition_manager == null:
		_active_name_label.text = "Expedition: None"
		_remaining_time_label.text = "Remaining: --:--"
		_active_status_label.text = "Status: No active expedition"
		return

	var expedition := _expedition_manager.get_active_expedition()
	if expedition.is_empty():
		_active_name_label.text = "Expedition: None"
		_remaining_time_label.text = "Remaining: --:--"
		_active_status_label.text = "Status: No active expedition"
		return

	# Names come from offer data; fallback text protects against malformed payloads.
	_active_name_label.text = "Expedition: %s" % str(expedition.get("display_name", "Unknown Expedition"))
	_active_status_label.text = "Status: %s" % _expedition_manager.get_status_label()

	if _expedition_manager.has_active_expedition():
		_remaining_time_label.text = "Remaining: %s" % _expedition_manager.get_remaining_time_text()
	else:
		_remaining_time_label.text = "Remaining: 00:00"


func _on_open_board_pressed() -> void:
	open_expedition_board_requested.emit()
