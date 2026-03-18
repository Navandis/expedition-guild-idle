extends Node2D

const EXPEDITION_BOARD_SCENE := preload("res://scenes/expedition_board/ExpeditionBoard.tscn")

var pending_dispatch_expedition: Dictionary = {}


func _ready() -> void:
	_show_expedition_board()


func get_pending_dispatch_expedition() -> Dictionary:
	return pending_dispatch_expedition.duplicate(true)


func _show_expedition_board() -> void:
	var board := EXPEDITION_BOARD_SCENE.instantiate()
	add_child(board)
	if board is ExpeditionBoardController:
		board.expedition_dispatch_requested.connect(_on_expedition_dispatch_requested)


func _on_expedition_dispatch_requested(expedition_data: Dictionary) -> void:
	pending_dispatch_expedition = expedition_data.duplicate(true)
	print("Queued for dispatch flow: %s" % str(pending_dispatch_expedition.get("id", "unknown")))
