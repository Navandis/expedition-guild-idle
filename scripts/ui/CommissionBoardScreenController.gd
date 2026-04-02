extends Control
class_name CommissionBoardScreenController

# File: CommissionBoardScreenController.gd
# Temporary playtest-focused Commission Board layout/controller.
#
# Why this pass exists:
# - Remove redundant explanatory labels and make top-half UI easier to scan.
# - Replace the old crew summary text line with the same ResourceRowPanel pattern
#   used on Guild Hall so testers read resources the same way on both screens.
# - Use 2x3 placeholder commission card buttons (CM1-3 + Locked1-3) so taps are
#   explicit and fast during playtesting.

signal navigate_requested(target_screen: String)
signal commission_dispatch_requested(offer_id: String, prep_tier_id: String, commitment: Dictionary, offer_snapshot: Dictionary)

const _UNLOCKED_CARD_COUNT := 3

@onready var _top_half_area: Control = $TopHalfArea
@onready var _resource_row_panel: PanelContainer = $TopHalfArea/TopHalfColumn/ResourceRowPanel
@onready var _gold_value_label: Label = $TopHalfArea/TopHalfColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/GoldCounter/Row/GoldValueLabel
@onready var _crew_value_label: Label = $TopHalfArea/TopHalfColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/Row/CrewValueLabel
@onready var _supplies_value_label: Label = $TopHalfArea/TopHalfColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/SuppliesCounter/Row/SuppliesValueLabel
@onready var _cards_grid: GridContainer = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid
@onready var _cm1_button: Button = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid/CM1Button
@onready var _cm2_button: Button = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid/CM2Button
@onready var _cm3_button: Button = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid/CM3Button
@onready var _locked_1_button: Button = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid/Locked1Button
@onready var _locked_2_button: Button = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid/Locked2Button
@onready var _locked_3_button: Button = $TopHalfArea/TopHalfColumn/CommissionCardsSection/CardsGrid/Locked3Button
@onready var _detail_panel_container: MarginContainer = $DetailPanelContainer
@onready var _detail_panel: CommissionDetailPanelController = $DetailPanelContainer/CommissionDetailPanel
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

	# The old BoardHintLabel/CrewSummaryLabel path was removed in scene authoring.
	# Resource values now render inside the GuildHall-style ResourceRowPanel.
	_wire_card_actions()
	_wire_detail_panel()
	_lock_placeholder_buttons()
	_ensure_board_generated()
	_bind_board_cards()
	_refresh_resource_summary()
	_apply_top_half_bounds()
	get_viewport().size_changed.connect(_apply_top_half_bounds)


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
	# Unlocked row is interactive and replaces the old per-card "Inspect & Dispatch"
	# button flow: tapping CM1/CM2/CM3 now opens CommissionDetailPanel directly.
	_cm1_button.pressed.connect(func() -> void: _open_offer_by_index(0))
	_cm2_button.pressed.connect(func() -> void: _open_offer_by_index(1))
	_cm3_button.pressed.connect(func() -> void: _open_offer_by_index(2))


func _wire_detail_panel() -> void:
	_detail_panel.closed.connect(func() -> void:
		# Cancel/close is a deliberate dismissal, so clear selection state too.
		_selected_offer = {}
		_detail_panel_container.visible = false
	)
	_detail_panel.dispatch_pressed.connect(func(offer: Dictionary, prep_tier_id: String, commitment: Dictionary) -> void:
		var offer_id := str(offer.get("offer_id", "")).strip_edges()
		if offer_id.is_empty():
			return
		commission_dispatch_requested.emit(offer_id, prep_tier_id, commitment, offer.duplicate(true))
	)


func _lock_placeholder_buttons() -> void:
	# Bottom row is intentionally non-interactive placeholder content for now.
	_locked_1_button.disabled = true
	_locked_2_button.disabled = true
	_locked_3_button.disabled = true


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
	var unlocked_buttons: Array[Button] = [_cm1_button, _cm2_button, _cm3_button]

	# 2x3 grid is scene-authored (3 columns) and always shown.
	# Top row is unlocked placeholders with fixed labels CM1/CM2/CM3.
	for i in range(_UNLOCKED_CARD_COUNT):
		unlocked_buttons[i].text = "CM%d" % (i + 1)
		unlocked_buttons[i].disabled = i >= offers.size()


func _refresh_resource_summary() -> void:
	# Keep this row consistent with Guild Hall style while using board-specific values.
	_gold_value_label.text = "0"
	_crew_value_label.text = str(_available_crew)
	_supplies_value_label.text = str(_available_supplies)


func _open_offer_by_index(offer_index: int) -> void:
	var offers := _board_controller.get_visible_offers()
	if offer_index < 0 or offer_index >= offers.size():
		return
	_open_detail_for_offer(offers[offer_index])


func _open_detail_for_offer(offer: Dictionary) -> void:
	_selected_offer = offer.duplicate(true)
	_detail_panel_container.visible = true
	_detail_panel.show_offer(_selected_offer, _available_crew, _available_supplies)


func _apply_top_half_bounds() -> void:
	# Dynamic bounds rule for testing:
	# - X margins are fixed to 3px at viewport edges.
	# - Y has no fixed margin; TopHalfArea ends exactly at screen midpoint.
	# - ResourceRowPanel keeps authored/default height.
	# - Card grid section expands to fill remaining space down to midpoint.
	_top_half_area.offset_left = 3.0
	_top_half_area.offset_right = -3.0
	_top_half_area.offset_top = 0.0
	_top_half_area.offset_bottom = 0.0

	# Keep all six buttons uniform inside the authored 2x3 grid on resize.
	for card_button in _cards_grid.get_children():
		if card_button is Button:
			(card_button as Button).custom_minimum_size = Vector2.ZERO
