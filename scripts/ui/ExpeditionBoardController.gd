extends Control
class_name ExpeditionBoardController

# ExpeditionBoardController manages the full board lifecycle:
# 1) Generate expedition offers.
# 2) Render one card per offer.
# 3) Track which card is selected.
# 4) Emit flow signals (dispatch request or return home).

signal expedition_dispatch_requested(expedition_data: Dictionary)
signal return_to_guild_hall_requested

const MIN_EXPEDITIONS := 3
const MAX_EXPEDITIONS := 5

@export var expedition_card_scene: PackedScene

@onready var _cards_container: VBoxContainer = $SafeArea/RootColumn/CardScroll/ExpeditionCardsContainer
@onready var _dispatch_button: Button = $SafeArea/RootColumn/DispatchButton
@onready var _selection_label: Label = $SafeArea/RootColumn/SelectionLabel
@onready var _back_button: Button = $SafeArea/RootColumn/BackButton

var _generator := ExpeditionGenerator.new()
var _selected_expedition: Dictionary = {}
var _card_views: Array[ExpeditionCardView] = []
var _duration_multiplier: float = 1.0


func _ready() -> void:
	randomize()
	# Players cannot dispatch until they choose a card.
	_dispatch_button.disabled = true
	_dispatch_button.pressed.connect(_on_dispatch_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_generate_board()


func get_selected_expedition() -> Dictionary:
	return _selected_expedition.duplicate(true)


func set_duration_multiplier(duration_multiplier: float) -> void:
	_duration_multiplier = maxf(0.20, duration_multiplier)
	for card in _card_views:
		card.set_duration_multiplier(_duration_multiplier)


func replace_expedition_by_id(expedition_id: String, dispatched_expedition: Dictionary) -> void:
	# Remove the dispatched card, then generate exactly one replacement offer.
	var removed := _remove_card_by_expedition_id(expedition_id)
	if not removed:
		return

	var signatures_to_exclude := _get_current_board_signatures()
	signatures_to_exclude.append(_generator.build_signature(dispatched_expedition))
	var replacement := _generator.generate_single_expedition(signatures_to_exclude)
	if replacement.is_empty():
		_selected_expedition = {}
		_dispatch_button.disabled = true
		_selection_label.text = "Select an expedition to continue."
		return

	_add_card(replacement)
	_selected_expedition = {}
	_dispatch_button.disabled = true
	_selection_label.text = "Select an expedition to continue."


func _generate_board() -> void:
	_clear_cards()

	var desired_count := randi_range(MIN_EXPEDITIONS, MAX_EXPEDITIONS)
	var expeditions := _generator.generate_expeditions(desired_count)

	for expedition in expeditions:
		_add_card(expedition)

	_selection_label.text = "Select an expedition to continue."


func _add_card(expedition: Dictionary) -> void:
	var card := expedition_card_scene.instantiate() as ExpeditionCardView
	if card == null:
		return

	# Each card gets the full expedition dictionary so it can both
	# display fields and emit them back when clicked.
	_cards_container.add_child(card)
	card.set_expedition_data(expedition)
	card.set_duration_multiplier(_duration_multiplier)
	card.pressed_with_data.connect(_on_card_selected)
	card.set_selected(false)
	_card_views.append(card)


func _clear_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	_card_views.clear()


func _get_current_board_signatures() -> Array[String]:
	var signatures: Array[String] = []
	for card in _card_views:
		signatures.append(_generator.build_signature(card.expedition_data))
	return signatures


func _remove_card_by_expedition_id(expedition_id: String) -> bool:
	for card in _card_views:
		if str(card.expedition_data.get("id", "")) != expedition_id:
			continue

		_card_views.erase(card)
		card.queue_free()
		return true

	return false


func _on_card_selected(expedition_data: Dictionary) -> void:
	# Duplicate to avoid accidental shared-mutation between UI and model data.
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


func _on_back_pressed() -> void:
	return_to_guild_hall_requested.emit()
