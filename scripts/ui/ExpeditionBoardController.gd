extends Control
class_name ExpeditionBoardController

# ExpeditionBoardController manages the full board lifecycle:
# 1) Generate expedition offers.
# 2) Render one card per offer.
# 3) Track which card is selected.
# 4) Emit flow signals (dispatch request or return home).
#
# Region slice note:
# The board now exposes a minimal region picker and shows which region is active.
# Generation still happens in this controller, but pools are constrained via
# generation_context provided by GameManager/RegionSystem.

signal expedition_dispatch_requested(expedition_data: Dictionary)
signal return_to_guild_hall_requested
signal region_selected(region_id: String)

const MIN_EXPEDITIONS := 3
const MAX_EXPEDITIONS := 5

@export var expedition_card_scene: PackedScene

@onready var _cards_container: VBoxContainer = $SafeArea/RootColumn/CardScroll/ExpeditionCardsContainer
@onready var _dispatch_button: Button = $SafeArea/RootColumn/DispatchButton
@onready var _selection_label: Label = $SafeArea/RootColumn/SelectionLabel
@onready var _region_summary_label: Label = $SafeArea/RootColumn/RegionSummaryLabel
@onready var _region_selector: OptionButton = $SafeArea/RootColumn/RegionSelector
@onready var _back_button: Button = $SafeArea/RootColumn/BackButton

var _generator := ExpeditionGenerator.new()
var _selected_expedition: Dictionary = {}
var _card_views: Array[ExpeditionCardView] = []
var _upgrade_effects: Dictionary = {}
var _initial_board_offers: Array[Dictionary] = []
var _generation_context: Dictionary = {}
var _region_rows: Array[Dictionary] = []


func _ready() -> void:
	randomize()
	# Players cannot dispatch until they choose a card.
	_dispatch_button.disabled = true
	_dispatch_button.pressed.connect(_on_dispatch_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_region_selector.item_selected.connect(_on_region_selector_changed)
	_refresh_region_selector()
	_generate_board(_initial_board_offers)


func get_selected_expedition() -> Dictionary:
	return _selected_expedition.duplicate(true)


func set_upgrade_effects(upgrade_effects: Dictionary) -> void:
	_upgrade_effects = upgrade_effects.duplicate(true)
	for card in _card_views:
		card.set_upgrade_effects(_upgrade_effects)


func set_initial_board_offers(board_offers: Array[Dictionary]) -> void:
	_initial_board_offers = board_offers.duplicate(true)


func set_region_data(region_rows: Array[Dictionary], generation_context: Dictionary) -> void:
	# Called by GameManager whenever region state changes.
	_region_rows = region_rows.duplicate(true)
	_generation_context = generation_context.duplicate(true)
	if is_node_ready():
		_refresh_region_selector()


func get_board_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for card in _card_views:
		offers.append(card.expedition_data.duplicate(true))
	return offers


func replace_expedition_by_id(expedition_id: String, dispatched_expedition: Dictionary) -> void:
	# Remove the dispatched card, then generate exactly one replacement offer.
	var removed := _remove_card_by_expedition_id(expedition_id)
	if not removed:
		return

	var signatures_to_exclude := _get_current_board_signatures()
	signatures_to_exclude.append(_generator.build_signature(dispatched_expedition))
	var replacement := _generator.generate_single_expedition(signatures_to_exclude, _generation_context)
	if replacement.is_empty():
		_selected_expedition = {}
		_dispatch_button.disabled = true
		_selection_label.text = "Select an expedition to continue."
		return

	_add_card(replacement)
	_selected_expedition = {}
	_dispatch_button.disabled = true
	_selection_label.text = "Select an expedition to continue."


func regenerate_board_for_selected_region() -> void:
	# Region changes invalidate old offers, so rebuild with selected constraints.
	_initial_board_offers = []
	_generate_board([])


func _generate_board(existing_offers: Array[Dictionary] = []) -> void:
	_clear_cards()

	var expeditions: Array[Dictionary] = []
	if _is_valid_board_offers(existing_offers):
		expeditions = existing_offers.duplicate(true)
	else:
		var desired_count := randi_range(MIN_EXPEDITIONS, MAX_EXPEDITIONS)
		expeditions = _generator.generate_expeditions(desired_count, [], _generation_context)

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
	card.set_upgrade_effects(_upgrade_effects)
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


func _is_valid_board_offers(board_offers: Array[Dictionary]) -> bool:
	if board_offers.size() < MIN_EXPEDITIONS or board_offers.size() > MAX_EXPEDITIONS:
		return false

	for offer in board_offers:
		if str(offer.get("id", "")).is_empty():
			return false
		# Save migration safety: if selected region changed, stale board offers from
		# another region should not be reused.
		if str(offer.get("region_id", "")) != str(_generation_context.get("region_id", "")):
			return false
	return true


func _refresh_region_selector() -> void:
	if _region_selector == null:
		return

	var previous_region_id := str(_generation_context.get("region_id", ""))
	_region_selector.clear()
	_region_selector.disabled = _region_rows.is_empty()

	for row in _region_rows:
		var region_id := str(row.get("id", ""))
		var is_visible := bool(row.get("is_visible", false))
		if not is_visible:
			continue
		var is_unlocked := bool(row.get("is_unlocked", false))
		var label := str(row.get("name", region_id))
		if not is_unlocked:
			label = "%s (Locked)" % label
		_region_selector.add_item(label)
		var option_index := _region_selector.item_count - 1
		_region_selector.set_item_metadata(option_index, region_id)
		if not is_unlocked:
			_region_selector.set_item_disabled(option_index, true)

	if _region_selector.item_count <= 0:
		_region_summary_label.text = "No visible regions."
		return

	var selected_index := 0
	for i in range(_region_selector.item_count):
		if str(_region_selector.get_item_metadata(i)) == previous_region_id:
			selected_index = i
			break

	_region_selector.select(selected_index)
	_refresh_region_summary_from_selector()


func _refresh_region_summary_from_selector() -> void:
	if _region_selector.item_count <= 0:
		_region_summary_label.text = "Selected Region: None"
		return
	var selected_text := _region_selector.get_item_text(_region_selector.selected)
	_region_summary_label.text = "Selected Region: %s" % selected_text


func _on_region_selector_changed(index: int) -> void:
	if index < 0 or index >= _region_selector.item_count:
		return
	_refresh_region_summary_from_selector()
	region_selected.emit(str(_region_selector.get_item_metadata(index)))


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
