extends Control
class_name ExpeditionBoardController

signal expedition_dispatch_requested(expedition_data: Dictionary)

const MIN_EXPEDITIONS := 3
const MAX_EXPEDITIONS := 5

@export var expedition_card_scene: PackedScene

@onready var _cards_container: VBoxContainer = %ExpeditionCardsContainer
@onready var _dispatch_button: Button = %DispatchButton
@onready var _selection_label: Label = %SelectionLabel

var _generator := ExpeditionGenerator.new()
var _selected_expedition: Dictionary = {}
var _card_views: Array[ExpeditionCardView] = []


func _ready() -> void:
	randomize()
	_dispatch_button.disabled = true
	_dispatch_button.pressed.connect(_on_dispatch_pressed)
	_generate_board()


func get_selected_expedition() -> Dictionary:
	return _selected_expedition.duplicate(true)


func _generate_board() -> void:
	_clear_cards()

	var desired_count := randi_range(MIN_EXPEDITIONS, MAX_EXPEDITIONS)
	var expeditions := _generator.generate_expeditions(desired_count)

	for expedition in expeditions:
		var card := expedition_card_scene.instantiate() as ExpeditionCardView
		if card == null:
			continue

		_cards_container.add_child(card)
		card.set_expedition_data(expedition)
		card.pressed_with_data.connect(_on_card_selected)
		card.set_selected(false)
		_card_views.append(card)

	_selection_label.text = "Select an expedition to continue."


func _clear_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	_card_views.clear()


func _on_card_selected(expedition_data: Dictionary) -> void:
	_selected_expedition = expedition_data.duplicate(true)
	_dispatch_button.disabled = false
	_selection_label.text = "Selected: %s" % str(_selected_expedition.get("display_name", "Unknown Expedition"))

	for card in _card_views:
		var is_selected: bool = card.expedition_data.get("id", "") == _selected_expedition.get("id", "")
		card.set_selected(is_selected)


func _on_dispatch_pressed() -> void:
	if _selected_expedition.is_empty():
		return

	expedition_dispatch_requested.emit(_selected_expedition.duplicate(true))
	print("Dispatch requested for: %s" % str(_selected_expedition.get("display_name", "Unknown Expedition")))
