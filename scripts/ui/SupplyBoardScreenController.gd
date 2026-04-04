extends Control
class_name SupplyBoardScreenController

# File: SupplyBoardScreenController.gd
# Dedicated Supply Board offer surface for Supply Runs Foundation v1.
#
# Why this screen exists:
# - Guild Hall is status + entry only for active Supply Runs.
# - Offer inspection and dispatch stay here so the runtime/status surface does
#   not absorb full board-detail complexity.
#
# Why this uses simple scene-authored cards:
# - v1 only needs three visible offers and explicit taps.
# - Reusing the existing board/card grammar keeps behavior readable.

signal navigate_requested(target_screen: String)
signal supply_dispatch_requested(offer_id: String)

const _VISIBLE_CARD_COUNT := 3

@onready var _gold_value_label: Label = $MainColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/GoldCounter/Row/GoldValueLabel
@onready var _crew_value_label: Label = $MainColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/Row/CrewValueLabel
@onready var _supplies_value_label: Label = $MainColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/SuppliesCounter/Row/SuppliesValueLabel
@onready var _card_buttons: Array[Button] = [
	$MainColumn/OffersPanel/OffersMargin/OffersColumn/CardsGrid/SR1Button,
	$MainColumn/OffersPanel/OffersMargin/OffersColumn/CardsGrid/SR2Button,
	$MainColumn/OffersPanel/OffersMargin/OffersColumn/CardsGrid/SR3Button
]
@onready var _selected_title_label: Label = $MainColumn/OffersPanel/OffersMargin/OffersColumn/DetailPanel/DetailMargin/DetailColumn/SelectedTitleLabel
@onready var _selected_info_label: Label = $MainColumn/OffersPanel/OffersMargin/OffersColumn/DetailPanel/DetailMargin/DetailColumn/SelectedInfoLabel
@onready var _dispatch_button: Button = $MainColumn/OffersPanel/OffersMargin/OffersColumn/DetailPanel/DetailMargin/DetailColumn/DispatchButton
@onready var _status_label: Label = $MainColumn/OffersPanel/OffersMargin/OffersColumn/DetailPanel/DetailMargin/DetailColumn/StatusLabel
@onready var _bottom_nav: BottomNavBar = $BottomNavSafe/BottomNavBar

var _offers: Array[Dictionary] = []
var _selected_offer: Dictionary = {}
var _available_crew := 0
var _current_gold := 0
var _available_supplies := 0
var _slot_usage := 0
var _slot_capacity := 0
var _ui_ready := false


func _ready() -> void:
	# Keep global navigation behavior consistent with the other board screens.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_SUPPLY_BOARD)
	_bottom_nav.navigate_requested.connect(func(target_screen: String) -> void:
		navigate_requested.emit(target_screen)
	)

	for i in range(_card_buttons.size()):
		var index := i
		_card_buttons[i].pressed.connect(func() -> void:
			_open_offer_at_index(index)
		)
	_dispatch_button.pressed.connect(_on_dispatch_pressed)
	_ui_ready = true
	_bind_offer_cards()
	_refresh_dispatch_panel()
	_apply_header_resources()


func set_supply_board_context(
	offers: Array[Dictionary],
	available_crew: int,
	current_gold: int,
	available_supplies: int,
	slot_usage: int,
	slot_capacity: int
) -> void:
	# UI binding is a projection of runtime/board state from GameManager.
	_offers = offers.duplicate(true)
	_available_crew = maxi(0, available_crew)
	_current_gold = maxi(0, current_gold)
	_slot_usage = maxi(0, slot_usage)
	_slot_capacity = maxi(0, slot_capacity)
	_available_supplies = maxi(0, available_supplies)
	_apply_header_resources()
	if not _ui_ready:
		return
	_bind_offer_cards()
	_refresh_dispatch_panel()


func _apply_header_resources() -> void:
	# GameManager can bind context before this scene has finished _ready.
	# Guarding here avoids nil-label assignment errors during first open.
	if not _ui_ready:
		return
	_gold_value_label.text = str(_current_gold)
	_crew_value_label.text = str(_available_crew)
	_supplies_value_label.text = str(_available_supplies)


func handle_dispatch_result(success: bool, message: String, offers: Array[Dictionary]) -> void:
	_offers = offers.duplicate(true)
	if success:
		_selected_offer = {}
	_bind_offer_cards()
	_refresh_dispatch_panel()
	_status_label.text = message
	_status_label.modulate = Color(0.4, 0.9, 0.4, 1.0) if success else Color(1.0, 0.55, 0.4, 1.0)


func _bind_offer_cards() -> void:
	for i in range(_VISIBLE_CARD_COUNT):
		var button := _card_buttons[i]
		if i >= _offers.size():
			button.disabled = true
			button.text = "Empty"
			continue
		var offer := _offers[i]
		button.disabled = false
		button.text = "%s\n%s" % [str(offer.get("title", "Supply Run")), str(offer.get("region_name", "Unknown Region"))]


func _open_offer_at_index(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	_selected_offer = (_offers[index] as Dictionary).duplicate(true)
	_refresh_dispatch_panel()


func _refresh_dispatch_panel() -> void:
	if _selected_offer.is_empty():
		_selected_title_label.text = "Select a Supply Run"
		_selected_info_label.text = "Tap a card to inspect dispatch details."
		_dispatch_button.disabled = true
		if _status_label.text.is_empty():
			_status_label.text = ""
		return

	var crew_required := maxi(0, int(_selected_offer.get("crew_required", 0)))
	var gold_cost := maxi(0, int(_selected_offer.get("gold_cost", 0)))
	var duration_minutes := maxi(0, int(_selected_offer.get("duration_minutes", 0)))
	var supplies_estimate := maxi(0, int(_selected_offer.get("supplies_yield_estimate", 0)))
	var blocked_reason := _build_block_reason(crew_required, gold_cost)

	_selected_title_label.text = str(_selected_offer.get("title", "Supply Run"))
	_selected_info_label.text = "Method: %s\nDuration: %dm\nCrew: %d  Gold: %d\nEst. Supplies: %d\nSlots: %d/%d" % [
		str(_selected_offer.get("run_family_name", "Unknown")),
		duration_minutes,
		crew_required,
		gold_cost,
		supplies_estimate,
		_slot_usage,
		_slot_capacity
	]
	_dispatch_button.disabled = not blocked_reason.is_empty()
	if blocked_reason.is_empty():
		_status_label.text = "Dispatch available."
		_status_label.modulate = Color(0.85, 0.9, 1.0, 1.0)
	else:
		_status_label.text = blocked_reason
		_status_label.modulate = Color(1.0, 0.55, 0.4, 1.0)


func _build_block_reason(crew_required: int, gold_cost: int) -> String:
	if _slot_usage >= _slot_capacity:
		return "Dispatch blocked: no open Supply Run slot."
	if crew_required > _available_crew:
		return "Dispatch blocked: insufficient Crew."
	if gold_cost > _current_gold:
		return "Dispatch blocked: insufficient Gold."
	return ""


func _on_dispatch_pressed() -> void:
	if _selected_offer.is_empty():
		return
	var offer_id := str(_selected_offer.get("offer_id", "")).strip_edges()
	if offer_id.is_empty():
		return
	supply_dispatch_requested.emit(offer_id)
