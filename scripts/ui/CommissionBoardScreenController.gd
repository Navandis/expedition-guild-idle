extends Control
class_name CommissionBoardScreenController

# File: CommissionBoardScreenController.gd
# First playable Commission Board screen controller.
#
# This controller keeps responsibilities split:
# - CommissionBoardController (backend) owns finite board state + generation.
# - This script binds that data into scene-authored UI cards.
#
# The board is intentionally finite/curated (3 visible offers): no infinite list,
# no expiry timers, and no auto-reroll loops. Standard offers persist until a
# future accept/refresh action replaces them.

signal navigate_requested(target_screen: String)
signal commission_dispatch_requested(offer_id: String, prep_tier_id: String, commitment: Dictionary, offer_snapshot: Dictionary)

const _VISIBLE_CARD_COUNT := 3

@onready var _crew_summary_label: Label = $MainMargin/MainColumn/HeaderPanel/HeaderMargin/HeaderColumn/CrewSummaryLabel
@onready var _board_hint_label: Label = $MainMargin/MainColumn/HeaderPanel/HeaderMargin/HeaderColumn/BoardHintLabel
@onready var _cards_column: VBoxContainer = $MainMargin/MainColumn/BoardPanel/BoardMargin/CardsColumn
@onready var _card_slot_1: CommissionCardView = $MainMargin/MainColumn/BoardPanel/BoardMargin/CardsColumn/CommissionCardSlot1
@onready var _card_slot_2: CommissionCardView = $MainMargin/MainColumn/BoardPanel/BoardMargin/CardsColumn/CommissionCardSlot2
@onready var _card_slot_3: CommissionCardView = $MainMargin/MainColumn/BoardPanel/BoardMargin/CardsColumn/CommissionCardSlot3
@onready var _detail_panel_container: MarginContainer = $MainMargin/MainColumn/DetailPanelContainer
@onready var _detail_panel: CommissionDetailPanelController = $MainMargin/MainColumn/DetailPanelContainer/CommissionDetailPanel
@onready var _bottom_nav: BottomNavBar = $BottomNavSafe/BottomNavBar

var _board_controller := CommissionBoardController.new()
var _unlocked_region_ids: Array[String] = []
var _available_crew := 0
var _available_supplies := 0
var _selected_offer: Dictionary = {}


func _ready() -> void:
	# Bottom nav wiring mirrors other major screens.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_COMMISSION_BOARD)
	_bottom_nav.navigate_requested.connect(func(target_screen: String) -> void:
		navigate_requested.emit(target_screen)
	)

	# Scene-authored card nodes are fixed at 3 to emphasize curated board scope.
	_cards_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_wire_card_actions()
	_wire_detail_panel()
	_ensure_board_generated()
	_bind_board_cards()
	_refresh_resource_summary()


func set_board_context(unlocked_region_ids: Array[String], available_crew: int, available_supplies: int) -> void:
	_unlocked_region_ids = unlocked_region_ids.duplicate(true)
	_available_crew = maxi(0, available_crew)
	_available_supplies = maxi(0, available_supplies)
	_ensure_board_generated()
	if is_node_ready():
		_bind_board_cards()
		_refresh_resource_summary()
		if not _selected_offer.is_empty():
			_open_detail_for_offer(_selected_offer)


func handle_dispatch_result(success: bool, offer_id: String, message: String) -> void:
	# Accept means immediate dispatch: only remove from board after resource commit succeeds.
	if not success:
		if _detail_panel.visible:
			_detail_panel.set_status_message(message, true)
		return

	_board_controller.accept_offer(offer_id, _unlocked_region_ids)
	_selected_offer = {}
	_bind_board_cards()
	_refresh_resource_summary()
	_detail_panel.set_status_message(message, false)
	_detail_panel.hide_panel()
	_detail_panel_container.visible = false


func _wire_card_actions() -> void:
	var cards: Array[CommissionCardView] = [_card_slot_1, _card_slot_2, _card_slot_3]
	for card in cards:
		card.inspect_requested.connect(_on_card_inspect_requested)


func _wire_detail_panel() -> void:
	_detail_panel.closed.connect(func() -> void:
		# Cancel/close is a deliberate dismissal, so clear selection state too.
		# Otherwise set_board_context() (called when revisiting board) can reopen
		# the previously inspected offer even though player canceled it.
		_selected_offer = {}
		_detail_panel_container.visible = false
	)
	_detail_panel.dispatch_pressed.connect(func(offer: Dictionary, prep_tier_id: String, commitment: Dictionary) -> void:
		# Dispatch goes straight to commit request: no accepted backlog is created.
		var offer_id := str(offer.get("offer_id", "")).strip_edges()
		if offer_id.is_empty():
			return
		commission_dispatch_requested.emit(offer_id, prep_tier_id, commitment, offer.duplicate(true))
	)


func _ensure_board_generated() -> void:
	# Generate only when board is empty so standard offers stay persistent across
	# navigation until accepted/refreshed later.
	if _unlocked_region_ids.is_empty():
		return
	if not _board_controller.get_visible_offers().is_empty():
		return
	_board_controller.generate_board_for_regions(_unlocked_region_ids)


func _bind_board_cards() -> void:
	var offers := _board_controller.get_visible_offers()
	var cards: Array[CommissionCardView] = [_card_slot_1, _card_slot_2, _card_slot_3]

	# Bind generated data into the pre-authored 3 card slots (finite board view).
	for i in range(_VISIBLE_CARD_COUNT):
		if i < offers.size():
			cards[i].set_offer_data(offers[i])
		else:
			cards[i].set_empty_state(i)

	var shown := mini(offers.size(), _VISIBLE_CARD_COUNT)
	_board_hint_label.text = "Showing %d curated offers. Confirming dispatch commits resources immediately." % shown


func _refresh_resource_summary() -> void:
	_crew_summary_label.text = "Available Crew: %d   Supplies: %d" % [_available_crew, _available_supplies]


func _on_card_inspect_requested(offer_id: String) -> void:
	for offer in _board_controller.get_visible_offers():
		var row := offer as Dictionary
		if str(row.get("offer_id", "")) != offer_id:
			continue
		_open_detail_for_offer(row)
		return


func _open_detail_for_offer(offer: Dictionary) -> void:
	_selected_offer = offer.duplicate(true)
	_detail_panel_container.visible = true
	_detail_panel.show_offer(_selected_offer, _available_crew, _available_supplies)
