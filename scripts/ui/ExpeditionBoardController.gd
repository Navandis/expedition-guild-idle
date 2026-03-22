extends Control
class_name ExpeditionBoardController

# File: ExpeditionBoardController.gd
# This controller drives the Expedition Board as a 3-bucket dispatch workspace:
# 1) Top bucket (fixed 50%): region carousel only.
# 2) Middle bucket (dynamic): offered expeditions + dispatch button.
# 3) Bottom bucket: shared bottom nav in BottomNavSafe.
#
# Beginner notes for this pass:
# - The old static "Expedition Board" heading, "Selected Region: ..." text,
#   and "Back to Guild Hall" button were removed because global navigation now
#   lives in the shared bottom nav.
# - Layout bounds are recomputed from ready/resize/theme-safe hooks instead of
#   _process() to avoid per-frame UI churn.
# - Region selection is shown by a green border on the selected region card.
# - Region choice is preserved through RegionSystem/GameManager, then restored
#   here via generation_context + set_region_data.

signal expedition_dispatch_requested(expedition_data: Dictionary)
signal return_to_guild_hall_requested
signal region_selected(region_id: String)
signal navigate_requested(target_screen: String)

const MIN_EXPEDITIONS := 3
const MAX_EXPEDITIONS := 3
const _SELECTED_REGION_BORDER := Color(0.25, 0.85, 0.35, 1.0)
const _UNSELECTED_REGION_BORDER := Color(0.30, 0.30, 0.30, 1.0)

const _REGION_TEXTURES := {
	"greenhollow_reaches": preload("res://assets/Regions/Greenhollow Reaches - v8.png"),
	"emberwake_coast": preload("res://assets/Regions/Emberwake Coast - v7.png"),
	"greyfen_march": preload("res://assets/Regions/Greyfen March - variant 8.png"),
	"sunscar_expanse": preload("res://assets/Regions/Sunscar Expanse - v11.png"),
	"hollowspire_uplands": preload("res://assets/Regions/Hollowspire Uplands - v3.png")
}

@export var expedition_card_scene: PackedScene
@export var region_card_scene: PackedScene

@onready var _top_section: PanelContainer = $TopSection
@onready var _middle_section: PanelContainer = $MiddleSection
@onready var _bottom_nav_safe: MarginContainer = $BottomNavSafe
@onready var _region_hint_label: Label = $TopSection/TopMargin/TopColumn/RegionHintLabel
@onready var _region_carousel_row: HBoxContainer = $TopSection/TopMargin/TopColumn/RegionCarouselScroll/RegionCarouselRow
@onready var _cards_container: VBoxContainer = $MiddleSection/MiddleMargin/MiddleColumn/CardScroll/ExpeditionCardsContainer
@onready var _dispatch_button: Button = $MiddleSection/MiddleMargin/MiddleColumn/DispatchButton
@onready var _selection_label: Label = $MiddleSection/MiddleMargin/MiddleColumn/SelectionLabel
@onready var _bottom_nav: BottomNavBar = $BottomNavSafe/BottomNavBar

var _generator := ExpeditionGenerator.new()
var _selected_expedition: Dictionary = {}
var _card_views: Array[ExpeditionCardView] = []
var _upgrade_effects: Dictionary = {}
var _initial_board_offers: Array[Dictionary] = []
var _generation_context: Dictionary = {}
var _region_rows: Array[Dictionary] = []
var _session_offers_by_region: Dictionary = {}
var _selected_region_id := ""
var _region_card_views: Dictionary = {}


func _ready() -> void:
	randomize()
	_dispatch_button.disabled = true
	_dispatch_button.pressed.connect(_on_dispatch_pressed)
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_EXPEDITION_BOARD)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)
	# Hook bounded layout updates to safe lifecycle points instead of _process().
	resized.connect(_on_layout_changed)
	_top_section.resized.connect(_on_layout_changed)
	_bottom_nav_safe.resized.connect(_on_layout_changed)
	call_deferred("_update_board_layout")
	_refresh_region_carousel()
	_show_board_for_selected_region()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if not is_node_ready():
			call_deferred("_update_board_layout")
			return
		_update_board_layout()


func get_selected_expedition() -> Dictionary:
	return _selected_expedition.duplicate(true)


func set_upgrade_effects(upgrade_effects: Dictionary) -> void:
	_upgrade_effects = upgrade_effects.duplicate(true)
	for card in _card_views:
		card.set_upgrade_effects(_upgrade_effects)


func set_initial_board_offers(board_offers: Array[Dictionary]) -> void:
	_initial_board_offers = board_offers.duplicate(true)


func set_region_data(region_rows: Array[Dictionary], generation_context: Dictionary) -> void:
	_region_rows = region_rows.duplicate(true)
	_generation_context = generation_context.duplicate(true)
	if not is_node_ready():
		return
	_refresh_region_carousel()
	_show_board_for_selected_region()


func get_board_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for card in _card_views:
		offers.append(card.expedition_data.duplicate(true))
	return offers


func replace_expedition_by_id(expedition_id: String, dispatched_expedition: Dictionary) -> void:
	var removed := _remove_card_by_expedition_id(expedition_id)
	if not removed:
		return

	var signatures_to_exclude := _get_current_board_signatures()
	signatures_to_exclude.append(_generator.build_signature(dispatched_expedition))
	var replacement := _generator.generate_single_expedition(signatures_to_exclude, _generation_context)
	if replacement.is_empty():
		_cache_current_region_offers()
		_clear_selected_expedition()
		return

	_add_card(replacement)
	_cache_current_region_offers()
	_clear_selected_expedition()


func regenerate_board_for_selected_region() -> void:
	var region_id := _get_selected_region_id()
	if _session_offers_by_region.has(region_id):
		_session_offers_by_region.erase(region_id)
	_show_board_for_selected_region(true)


func _on_layout_changed() -> void:
	_update_board_layout()


func _update_board_layout() -> void:
	# 3-bucket layout math:
	# - Top section uses exactly 50% of this screen's height.
	# - Bottom section is whatever BottomNavSafe occupies.
	# - Middle section fills the bounded gap between them.
	# This avoids hard-coding nav heights and avoids _process().
	if size.y <= 0.0:
		return

	var top_height: float = floorf(size.y * 0.5)
	var nav_top_y := _bottom_nav_safe.position.y
	var middle_top_y := top_height
	var middle_bottom_y := maxf(middle_top_y, nav_top_y)

	_top_section.anchor_top = 0.0
	_top_section.anchor_bottom = 0.0
	_top_section.offset_top = 0.0
	_top_section.offset_bottom = top_height

	_middle_section.anchor_top = 0.0
	_middle_section.anchor_bottom = 0.0
	_middle_section.offset_top = middle_top_y
	_middle_section.offset_bottom = middle_bottom_y


func _generate_board(existing_offers: Array[Dictionary] = []) -> void:
	_clear_cards()

	var expeditions: Array[Dictionary] = []
	if _is_valid_board_offers(existing_offers):
		expeditions = existing_offers.duplicate(true)
	else:
		expeditions = _generator.generate_expeditions(3, [], _generation_context)

	for expedition in expeditions:
		_add_card(expedition)

	_clear_selected_expedition()


func _add_card(expedition: Dictionary) -> void:
	var card := expedition_card_scene.instantiate() as ExpeditionCardView
	if card == null:
		return

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
		if str(offer.get("region_id", "")) != region_id:
			return false
	return true


func _refresh_region_carousel() -> void:
	for child in _region_carousel_row.get_children():
		child.queue_free()
	_region_card_views.clear()

	# Preserve last selected region if still valid; otherwise pick first unlocked.
	if _selected_region_id.is_empty():
		_selected_region_id = str(_generation_context.get("region_id", ""))

	var selectable_region_ids: Array[String] = []
	for row in _region_rows:
		if not bool(row.get("is_visible", false)):
			continue
		var region_id := str(row.get("id", ""))
		var is_unlocked := bool(row.get("is_unlocked", false))
		if is_unlocked:
			selectable_region_ids.append(region_id)
		_add_region_card(row)

	if selectable_region_ids.is_empty():
		_region_hint_label.text = "No visible regions."
		_selected_region_id = ""
		return

	if not selectable_region_ids.has(_selected_region_id):
		# First-time fallback: first opened region.
		_selected_region_id = selectable_region_ids[0]

	_region_hint_label.text = "Choose a region"
	_update_region_card_highlights()


func _add_region_card(row: Dictionary) -> void:
	var region_id := str(row.get("id", ""))
	if region_id.is_empty() or region_card_scene == null:
		return

	# Region card visuals are now scene-authored for editor usability.
	# The controller only instantiates the reusable card and binds data.
	var card := region_card_scene.instantiate() as RegionCarouselCardView
	if card == null:
		return

	card.setup(row, _resolve_region_texture(region_id))
	card.pressed.connect(func() -> void:
		_on_region_card_pressed(region_id)
	)

	_region_carousel_row.add_child(card)
	_region_card_views[region_id] = card


func _resolve_region_texture(region_id: String) -> Texture2D:
	if _REGION_TEXTURES.has(region_id):
		return _REGION_TEXTURES[region_id]
	return null


func _on_region_card_pressed(region_id: String) -> void:
	if region_id.is_empty() or region_id == _selected_region_id:
		return
	_selected_region_id = region_id
	_clear_selected_expedition()
	_update_region_card_highlights()
	# Emit to RegionSystem so last-selected region persists to save state.
	region_selected.emit(region_id)


func _update_region_card_highlights() -> void:
	# Selection is indicated by a green border on the chosen region card.
	# Locked/unlocked presentation is applied by RegionCarouselCardView.setup().
	for region_id in _region_card_views.keys():
		var card := _region_card_views[region_id] as RegionCarouselCardView
		if card == null:
			continue
		var is_selected := str(region_id) == _selected_region_id
		card.apply_selected_style(is_selected, _SELECTED_REGION_BORDER, _UNSELECTED_REGION_BORDER)


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
	if not _is_selected_expedition_dispatchable():
		_clear_selected_expedition()
		return

	expedition_dispatch_requested.emit(_selected_expedition.duplicate(true))
	print("Dispatch requested for: %s" % str(_selected_expedition.get("display_name", "Unknown Expedition")))


func _on_bottom_nav_requested(target_screen: String) -> void:
	navigate_requested.emit(target_screen)


func _show_board_for_selected_region(force_regenerate: bool = false) -> void:
	var region_id := _get_selected_region_id()
	if region_id.is_empty():
		_generate_board([])
		return

	var offers_for_region: Array[Dictionary] = []
	if _session_offers_by_region.has(region_id):
		offers_for_region = _duplicate_offer_array(_session_offers_by_region.get(region_id, []))
	elif _is_valid_board_offers_for_region(_initial_board_offers, region_id):
		offers_for_region = _initial_board_offers.duplicate(true)

	if force_regenerate or not _is_valid_board_offers_for_region(offers_for_region, region_id):
		offers_for_region = _generator.generate_expeditions(3, [], _generation_context)

	_session_offers_by_region[region_id] = _duplicate_offer_array(offers_for_region)
	_generate_board(offers_for_region)


func _clear_selected_expedition() -> void:
	_selected_expedition = {}
	_dispatch_button.disabled = true
	_selection_label.text = "Select an expedition to continue."
	for card in _card_views:
		card.set_selected(false)


func _get_selected_region_id() -> String:
	if not _selected_region_id.is_empty():
		return _selected_region_id
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
