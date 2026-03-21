extends Control
class_name ExpeditionBoardController

# File: ExpeditionBoardController.gd
# File role:
# Handles Expedition Board UI behavior for offer generation, selection, and
# region switching. The board now keeps per-region offers stable for one
# screen visit by caching generated offers in-memory.
#
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
signal navigate_requested(target_screen: String)

const MIN_EXPEDITIONS := 3
const MAX_EXPEDITIONS := 5

@export var expedition_card_scene: PackedScene

@onready var _cards_container: VBoxContainer = $SafeArea/RootColumn/CardScroll/ExpeditionCardsContainer
@onready var _dispatch_button: Button = $SafeArea/RootColumn/DispatchButton
@onready var _selection_label: Label = $SafeArea/RootColumn/SelectionLabel
@onready var _region_summary_label: Label = $SafeArea/RootColumn/RegionSummaryLabel
@onready var _region_selector: OptionButton = $SafeArea/RootColumn/RegionSelector
@onready var _back_button: Button = $SafeArea/RootColumn/BackButton
@onready var _bottom_nav: BottomNavBar = $SafeArea/RootColumn/BottomNavBar

var _generator := ExpeditionGenerator.new()
var _selected_expedition: Dictionary = {}
var _card_views: Array[ExpeditionCardView] = []
var _upgrade_effects: Dictionary = {}
var _initial_board_offers: Array[Dictionary] = []
var _generation_context: Dictionary = {}
var _region_rows: Array[Dictionary] = []
var _session_offers_by_region: Dictionary = {}


func _ready() -> void:
	randomize()
	# Players cannot dispatch until they choose a card.
	_dispatch_button.disabled = true
	_dispatch_button.pressed.connect(_on_dispatch_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	# Bottom nav is shared across major screens in this slice.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_EXPEDITION_BOARD)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)
	_region_selector.item_selected.connect(_on_region_selector_changed)
	_refresh_region_selector()
	_show_board_for_selected_region()


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
		_show_board_for_selected_region()


func get_board_offers() -> Array[Dictionary]:
	# Save currently visible offers so GameManager can persist the active region.
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
		# Even without a replacement, persist the post-dispatch board shape so
		# region switching does not restore a stale pre-dispatch cache snapshot.
		_cache_current_region_offers()
		_selected_expedition = {}
		_dispatch_button.disabled = true
		_selection_label.text = "Select an expedition to continue."
		return

	_add_card(replacement)
	_cache_current_region_offers()
	_selected_expedition = {}
	_dispatch_button.disabled = true
	_selection_label.text = "Select an expedition to continue."


func regenerate_board_for_selected_region() -> void:
	# Keep this method for compatibility with existing callers.
	# It intentionally clears only the currently selected region cache entry.
	var region_id := _get_selected_region_id()
	if _session_offers_by_region.has(region_id):
		_session_offers_by_region.erase(region_id)
	_show_board_for_selected_region(true)


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
	_dispatch_button.disabled = true
	_selected_expedition = {}


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
	return _is_valid_board_offers_for_region(board_offers, _get_selected_region_id())


func _is_valid_board_offers_for_region(board_offers: Array[Dictionary], region_id: String) -> bool:
	if board_offers.size() < MIN_EXPEDITIONS or board_offers.size() > MAX_EXPEDITIONS:
		return false

	for offer in board_offers:
		if str(offer.get("id", "")).is_empty():
			return false
		# Safety guard: only use offers that belong to the target region.
		if str(offer.get("region_id", "")) != region_id:
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
		var row_is_visible := bool(row.get("is_visible", false))
		if not row_is_visible:
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
	# Selection is region-scoped. Clear old selection so dispatch cannot carry
	# a stale expedition from another region.
	_clear_selected_expedition()
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
	# Defensive check: only dispatch if selected expedition still belongs to
	# the active region and still exists on the visible board.
	if not _is_selected_expedition_dispatchable():
		_clear_selected_expedition()
		return

	expedition_dispatch_requested.emit(_selected_expedition.duplicate(true))
	print("Dispatch requested for: %s" % str(_selected_expedition.get("display_name", "Unknown Expedition")))


func _on_back_pressed() -> void:
	return_to_guild_hall_requested.emit()


func _on_bottom_nav_requested(target_screen: String) -> void:
	navigate_requested.emit(target_screen)


func _show_board_for_selected_region(force_regenerate: bool = false) -> void:
	var region_id := _get_selected_region_id()
	if region_id.is_empty():
		_generate_board([])
		return

	var offers_for_region: Array[Dictionary] = []
	var has_cached := _session_offers_by_region.has(region_id)
	if has_cached:
		offers_for_region = _duplicate_offer_array(_session_offers_by_region.get(region_id, []))
	elif _is_valid_board_offers_for_region(_initial_board_offers, region_id):
		# On first board load, reuse saved offers for this region if they exist.
		offers_for_region = _initial_board_offers.duplicate(true)

	if force_regenerate or not _is_valid_board_offers_for_region(offers_for_region, region_id):
		# Generate once per region during this board visit, then keep cached.
		var desired_count := randi_range(MIN_EXPEDITIONS, MAX_EXPEDITIONS)
		offers_for_region = _generator.generate_expeditions(desired_count, [], _generation_context)

	_session_offers_by_region[region_id] = _duplicate_offer_array(offers_for_region)
	_generate_board(offers_for_region)


func _clear_selected_expedition() -> void:
	_selected_expedition = {}
	_dispatch_button.disabled = true
	_selection_label.text = "Select an expedition to continue."
	for card in _card_views:
		card.set_selected(false)


func _get_selected_region_id() -> String:
	return str(_generation_context.get("region_id", ""))


func _cache_current_region_offers() -> void:
	var region_id := _get_selected_region_id()
	if region_id.is_empty():
		return
	_session_offers_by_region[region_id] = get_board_offers()


func _duplicate_offer_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for item in value:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _is_selected_expedition_dispatchable() -> bool:
	var selected_id := str(_selected_expedition.get("id", ""))
	var selected_region := str(_selected_expedition.get("region_id", ""))
	var active_region := _get_selected_region_id()
	if selected_id.is_empty() or selected_region != active_region:
		return false
	for card in _card_views:
		if str(card.expedition_data.get("id", "")) == selected_id:
			return true
	return false
