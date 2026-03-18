extends Control
class_name GuildHallController

# GuildHallController is the simple "home" view for this milestone.
# It displays placeholder resources, a button into the board, and a small
# status box that will later summarize active expedition progress.

signal open_expedition_board_requested

@onready var _active_status_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/StatusLabel

func _ready() -> void:
	$SafeArea/RootColumn/OpenBoardButton.pressed.connect(_on_open_board_pressed)


func set_active_expedition_status(expedition_data: Dictionary) -> void:
	if expedition_data.is_empty():
		_active_status_label.text = "No active expedition yet."
		return

	# Keep this text short and readable for small mobile layouts.
	_active_status_label.text = "Last dispatch queued: %s (%s min, %s risk)" % [
		str(expedition_data.get("display_name", "Unknown Expedition")),
		str(expedition_data.get("duration_minutes", "?")),
		str(expedition_data.get("risk_label", "Unknown"))
	]


func _on_open_board_pressed() -> void:
	open_expedition_board_requested.emit()
