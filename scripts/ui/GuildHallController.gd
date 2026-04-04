extends Control
class_name GuildHallController

# File: GuildHallController.gd
# Guild Hall is the dashboard landing screen for the prototype loop.
#
# Why the operations area now uses a TabContainer:
# - Guild Hall is now the shared status-and-entry surface for both active
#   Expeditions and active Commissions.
# - Keeping both views in one TabContainer lets players switch context quickly
#   without changing screens, while the deeper offer/dispatch workflow still
#   lives on the dedicated board screens.
#
# Why Commission cards mirror Expedition cards:
# - Matching card grammar (image/title/status + whole-card tap) keeps the
#   runtime status UI predictable for beginners and reduces UI learning overhead.
# - The cards are still scene-authored in GuildHall.tscn, while this script only
#   binds runtime state into those authored controls.
#
# Commission settlement popup note:
# - Completed commission cards now open a compact popup summary first.
# - Claim is now explicit via popup button, so "tap card" no longer consumes
#   rewards immediately and players can close the popup without losing claim.

signal open_report_requested
signal navigate_requested(target_screen: String)
signal debug_finish_requested
signal debug_reset_requested
signal commission_claim_requested(runtime_id: int)

const _STATUS_BORDER_EMPTY := Color(0.95, 0.55, 0.20, 1.0)
const _STATUS_BORDER_ONGOING := Color(0.95, 0.84, 0.20, 1.0)
const _STATUS_BORDER_COMPLETED := Color(0.35, 0.85, 0.45, 1.0)
const _SLOT_VISUAL_EMPTY := "empty"
const _SLOT_VISUAL_ONGOING := "ongoing"
const _SLOT_VISUAL_COMPLETED := "completed"
const _EXPEDITION_CARD_COUNT := 3
const _EXPEDITION_UNLOCKED_COUNT := 2
const _COMMISSION_CARD_COUNT := 3
const _COMMISSION_SETTLEMENT_POPUP_SCENE := preload("res://scenes/components/CommissionSettlementPopup.tscn")

@onready var _gold_value_label: Label = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/GoldCounter/Row/GoldValueLabel
@onready var _crew_dropdown_button: Button = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/Row/CrewDropdownButton
@onready var _crew_collapsed_value: RichTextLabel = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/Row/CrewDropdownButton/CrewCollapsedValue
@onready var _crew_dropdown_popup: PopupPanel = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/CrewDropdownPopup
@onready var _assigned_crew_value_label: RichTextLabel = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/CrewDropdownPopup/CrewDropdownMargin/CrewDropdownValues/AssignedCrewValueLabel
@onready var _recovering_crew_value_label: RichTextLabel = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CrewCounter/CrewDropdownPopup/CrewDropdownMargin/CrewDropdownValues/RecoveringCrewValueLabel
@onready var _supplies_value_label: Label = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/SuppliesCounter/Row/SuppliesValueLabel
@onready var _debug_finish_button: Button = $TopSafeArea/TopStack/TopRightToolsRow/DebugFinishButton
@onready var _debug_reset_button: Button = $TopSafeArea/TopStack/TopRightToolsRow/DebugResetButton

@onready var _operations_section_panel: PanelContainer = $OperationsSectionPanel
@onready var _operations_tabs: TabContainer = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs
@onready var _expedition_slots_scroller: ScrollContainer = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller
@onready var _slot_one_card: TouchScrollCardButton = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotOneCard
@onready var _slot_two_card: TouchScrollCardButton = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotTwoCard
@onready var _slot_three_card: TouchScrollCardButton = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotThreeCard
@onready var _slot_one_name_label: Label = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotOneCard/Margin/Content/SlotOneNameLabel
@onready var _slot_one_state_label: Label = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotOneCard/Margin/Content/SlotOneStateLabel
@onready var _slot_two_name_label: Label = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotTwoCard/Margin/Content/SlotTwoNameLabel
@onready var _slot_two_state_label: Label = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotTwoCard/Margin/Content/SlotTwoStateLabel
@onready var _slot_three_name_label: Label = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotThreeCard/Margin/Content/SlotThreeNameLabel
@onready var _slot_three_state_label: Label = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/ExpeditionsTab/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotThreeCard/Margin/Content/SlotThreeStateLabel

@onready var _commission_slots_scroller: ScrollContainer = $OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller
@onready var _commission_slot_cards: Array[TouchScrollCardButton] = [
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotOneCard,
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotTwoCard,
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotThreeCard
]
@onready var _commission_slot_name_labels: Array[Label] = [
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotOneCard/Margin/Content/CommissionSlotOneNameLabel,
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotTwoCard/Margin/Content/CommissionSlotTwoNameLabel,
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotThreeCard/Margin/Content/CommissionSlotThreeNameLabel
]
@onready var _commission_slot_state_labels: Array[Label] = [
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotOneCard/Margin/Content/CommissionSlotOneStateLabel,
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotTwoCard/Margin/Content/CommissionSlotTwoStateLabel,
	$OperationsSectionPanel/OperationsSectionMargin/OperationsTabs/CommissionsTab/CommissionSlotsScroller/CommissionSlotsRow/CommissionSlotThreeCard/Margin/Content/CommissionSlotThreeStateLabel
]

@onready var _bottom_nav_safe: MarginContainer = $BottomNavSafe
@onready var _bottom_nav: BottomNavBar = $BottomNavSafe/BottomNavBar

var _expedition_manager: ExpeditionManager
var _commission_runtime_manager: CommissionRuntimeManager
var _commission_slot_capacity := _COMMISSION_CARD_COUNT
var _crew_dropdown_presenter := CrewDropdownPresenter.new()
var _resources := {
	"gold": 0,
	"available_crew": 0,
	"assigned_crew": 0,
	"recovering_crew": 0,
	"max_crew": 0,
	"supplies": 0
}
var _slot_is_empty: Array[bool] = [true, true, true]
var _slot_visual_states: Array[String] = ["", "", ""]
var _commission_slot_actions: Array[String] = ["", "", ""]
var _commission_slot_runtime_ids: Array[int] = [0, 0, 0]
var _commission_slot_visual_states: Array[String] = ["", "", ""]
var _commission_ready_entries_by_runtime_id: Dictionary = {}
var _cached_slot_styles: Dictionary = {}
var _operations_offset_left := 0.0
var _operations_offset_right := 0.0
var _commission_settlement_popup: CommissionSettlementPopup


func _ready() -> void:
	_hide_scrollbars(_expedition_slots_scroller)
	_hide_scrollbars(_commission_slots_scroller)
	_debug_finish_button.pressed.connect(_on_debug_finish_pressed)
	_debug_reset_button.pressed.connect(_on_debug_reset_pressed)

	# Drag-aware taps prevent accidental activation while swiping carousels.
	_slot_one_card.confirmed_tap.connect(func() -> void:
		_on_slot_card_pressed(0)
	)
	_slot_two_card.confirmed_tap.connect(func() -> void:
		_on_slot_card_pressed(1)
	)
	_slot_three_card.confirmed_tap.connect(func() -> void:
		_on_slot_card_pressed(2)
	)
	for i in range(_commission_slot_cards.size()):
		var card_index := i
		_commission_slot_cards[i].confirmed_tap.connect(func() -> void:
			_on_commission_card_pressed(card_index)
		)
	_build_commission_settlement_popup()

	# Shared bottom nav is the primary cross-screen backbone.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_GUILD_HALL)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)

	# Keep the top-row Crew counter compact: default state shows Available/Max.
	# Tap opens a tiny popup with Assigned and Recovering values only.
	_crew_dropdown_presenter.configure(
		_crew_dropdown_button,
		_crew_collapsed_value,
		_crew_dropdown_popup,
		_assigned_crew_value_label,
		_recovering_crew_value_label
	)

	# Tab captions are explicit status surfaces for active operations.
	_operations_tabs.set_tab_title(0, "Expeditions")
	_operations_tabs.set_tab_title(1, "Commissions")

	_build_cached_slot_styles()
	_operations_offset_left = _operations_section_panel.offset_left
	_operations_offset_right = _operations_section_panel.offset_right

	resized.connect(_on_layout_changed)
	_bottom_nav_safe.resized.connect(_on_layout_changed)
	call_deferred("_update_operations_section_layout")
	set_process(true)
	_refresh_resource_labels()
	_refresh_active_status()
	_refresh_commission_status()


func _hide_scrollbars(scroll_container: ScrollContainer) -> void:
	var h_scroll := scroll_container.get_h_scroll_bar()
	if h_scroll != null:
		h_scroll.visible = false
		h_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v_scroll := scroll_container.get_v_scroll_bar()
	if v_scroll != null:
		v_scroll.visible = false
		v_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_refresh_active_status()
	_refresh_commission_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if not is_node_ready():
			call_deferred("_update_operations_section_layout")
			return
		_update_operations_section_layout()


func _on_layout_changed() -> void:
	_update_operations_section_layout()


func _update_operations_section_layout() -> void:
	# Guild Hall keeps tabs as a bounded middle section between top summary and
	# bottom navigation, so operations status cards remain readable on mobile.
	var parent_height := size.y
	if parent_height <= 0.0:
		return

	var midpoint_y := parent_height * 0.5
	var bottom_nav_top_y := _bottom_nav_safe.position.y
	var bounded_height: float = maxf(0.0, bottom_nav_top_y - midpoint_y)

	_operations_section_panel.anchor_left = 0.0
	_operations_section_panel.anchor_right = 1.0
	_operations_section_panel.offset_left = _operations_offset_left
	_operations_section_panel.offset_right = _operations_offset_right
	_operations_section_panel.anchor_top = 0.0
	_operations_section_panel.anchor_bottom = 0.0
	_operations_section_panel.offset_top = midpoint_y
	_operations_section_panel.offset_bottom = midpoint_y + bounded_height


func set_expedition_manager(expedition_manager: ExpeditionManager) -> void:
	_expedition_manager = expedition_manager
	_refresh_active_status()


func set_commission_runtime(runtime_manager: CommissionRuntimeManager, slot_capacity: int) -> void:
	# Guild Hall binds to runtime rows only. Commission Board remains the place
	# where offers are inspected and dispatch prep tiers are selected.
	_commission_runtime_manager = runtime_manager
	_commission_slot_capacity = maxi(0, slot_capacity)
	_refresh_commission_status()


func set_resources(resources: Dictionary) -> void:
	_resources = resources.duplicate(true)
	_refresh_resource_labels()


func _refresh_resource_labels() -> void:
	_gold_value_label.text = str(int(_resources.get("gold", 0)))
	_supplies_value_label.text = str(int(_resources.get("supplies", 0)))

	var available_crew := int(_resources.get("available_crew", 0))
	var max_crew := int(_resources.get("max_crew", 0))
	var assigned_crew := int(_resources.get("assigned_crew", 0))
	var recovering_crew := int(_resources.get("recovering_crew", 0))
	_crew_dropdown_presenter.set_values(available_crew, max_crew, assigned_crew, recovering_crew)


func _refresh_active_status() -> void:
	if _slot_one_card == null or _slot_two_card == null or _slot_three_card == null:
		return

	if _expedition_manager == null:
		_set_empty_slot_card(0)
		_set_empty_slot_card(1)
		_set_locked_slot_card(2)
		_debug_finish_button.visible = false
		return

	var slots := _expedition_manager.get_active_expeditions()
	for i in range(_EXPEDITION_CARD_COUNT):
		if i >= _EXPEDITION_UNLOCKED_COUNT:
			_set_locked_slot_card(i)
			continue
		_refresh_slot_card(i, slots)

	var has_active_expeditions := _expedition_manager.has_active_expedition()
	var has_active_commissions := false
	if _commission_runtime_manager != null:
		has_active_commissions = _commission_runtime_manager.get_active_slot_usage() > 0
	# Debug finish is shared QA tooling for both timed systems.
	_debug_finish_button.visible = has_active_expeditions or has_active_commissions
	_debug_reset_button.visible = true


func _refresh_slot_card(slot_index: int, slots: Array[Dictionary]) -> void:
	var card := _get_slot_card(slot_index)
	var name_label := _get_slot_name_label(slot_index)
	var state_label := _get_slot_state_label(slot_index)

	if card == null or name_label == null or state_label == null:
		return

	if slot_index < 0 or slot_index >= slots.size():
		_set_empty_slot_card(slot_index)
		return

	var slot_data := slots[slot_index]
	if slot_data.is_empty():
		_set_empty_slot_card(slot_index)
		return

	name_label.text = str(slot_data.get("display_name", "Unknown Expedition"))
	var status := str(slot_data.get("status", ExpeditionManager.STATUS_IDLE))

	if status == ExpeditionManager.STATUS_IN_PROGRESS:
		var remaining_text := _expedition_manager.get_remaining_time_text_for_slot(slot_index)
		state_label.text = "In progress · %s left" % remaining_text
		_slot_is_empty[slot_index] = false
		card.disabled = true
		card.focus_mode = Control.FOCUS_NONE
		_apply_status_border(slot_index, card, _SLOT_VISUAL_ONGOING)
		return

	state_label.text = "Complete · Collect Reward"
	_slot_is_empty[slot_index] = false
	card.disabled = false
	card.focus_mode = Control.FOCUS_ALL
	_apply_status_border(slot_index, card, _SLOT_VISUAL_COMPLETED)


func _set_empty_slot_card(slot_index: int) -> void:
	var card := _get_slot_card(slot_index)
	var name_label := _get_slot_name_label(slot_index)
	var state_label := _get_slot_state_label(slot_index)
	if card == null or name_label == null or state_label == null:
		return

	name_label.text = "Empty Slot"
	state_label.text = "Tap to open Expedition Board"
	_slot_is_empty[slot_index] = true
	card.disabled = false
	card.focus_mode = Control.FOCUS_ALL
	_apply_status_border(slot_index, card, _SLOT_VISUAL_EMPTY)


func _set_locked_slot_card(slot_index: int) -> void:
	var card := _get_slot_card(slot_index)
	var name_label := _get_slot_name_label(slot_index)
	var state_label := _get_slot_state_label(slot_index)
	if card == null or name_label == null or state_label == null:
		return

	name_label.text = "Locked Slot"
	state_label.text = "Reserved for future unlock hints"
	_slot_is_empty[slot_index] = false
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	_apply_status_border(slot_index, card, _SLOT_VISUAL_EMPTY)


func _refresh_commission_status() -> void:
	# Visual binding maps active + ready runtime rows into fixed slot cards.
	# This keeps Guild Hall status-focused while Commission Board handles offers.
	if _commission_slot_cards.is_empty():
		return
	_commission_ready_entries_by_runtime_id.clear()

	var cards_to_fill := mini(_commission_slot_capacity, _COMMISSION_CARD_COUNT)
	var ready_rows: Array[Dictionary] = []
	var active_rows: Array[Dictionary] = []
	if _commission_runtime_manager != null:
		# Guild Hall is a pure renderer for runtime state.
		# Promotion from active -> ready is processed by GameManager so completion
		# side-effects (crew transitions/save) stay centralized and deterministic.
		ready_rows = _commission_runtime_manager.get_ready_to_claim_entries()
		active_rows = _commission_runtime_manager.get_active_entries()

	for i in range(_COMMISSION_CARD_COUNT):
		if i >= cards_to_fill:
			_set_commission_locked_slot(i)
			continue
		if not ready_rows.is_empty():
			var ready_entry: Dictionary = ready_rows.pop_front()
			_set_commission_ready_slot(i, ready_entry)
			continue
		if not active_rows.is_empty():
			var active_entry: Dictionary = active_rows.pop_front()
			_set_commission_active_slot(i, active_entry)
			continue
		_set_commission_empty_slot(i)


func _set_commission_locked_slot(slot_index: int) -> void:
	var card := _get_commission_card(slot_index)
	var name_label := _get_commission_name_label(slot_index)
	var state_label := _get_commission_state_label(slot_index)
	if card == null or name_label == null or state_label == null:
		return
	name_label.text = "Locked Slot"
	state_label.text = "Reserved for future capacity"
	card.disabled = true
	_commission_slot_actions[slot_index] = "locked"
	_commission_slot_runtime_ids[slot_index] = 0
	_apply_commission_status_border(slot_index, card, _SLOT_VISUAL_EMPTY)


func _set_commission_empty_slot(slot_index: int) -> void:
	var card := _get_commission_card(slot_index)
	var name_label := _get_commission_name_label(slot_index)
	var state_label := _get_commission_state_label(slot_index)
	if card == null or name_label == null or state_label == null:
		return
	name_label.text = "Empty Slot"
	state_label.text = "Tap to Open Commission Board"
	card.disabled = false
	card.focus_mode = Control.FOCUS_ALL
	_commission_slot_actions[slot_index] = "open_board"
	_commission_slot_runtime_ids[slot_index] = 0
	_apply_commission_status_border(slot_index, card, _SLOT_VISUAL_EMPTY)


func _set_commission_active_slot(slot_index: int, entry: Dictionary) -> void:
	var card := _get_commission_card(slot_index)
	var name_label := _get_commission_name_label(slot_index)
	var state_label := _get_commission_state_label(slot_index)
	if card == null or name_label == null or state_label == null:
		return

	name_label.text = str(entry.get("title", "Commission"))
	var now := int(Time.get_unix_time_from_system())
	var ready_at := int(entry.get("ready_at_unix", now))
	var remaining := maxi(0, ready_at - now)
	state_label.text = "In progress · %s left" % _format_remaining_time(remaining)
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	_commission_slot_actions[slot_index] = "in_progress"
	_commission_slot_runtime_ids[slot_index] = int(entry.get("runtime_id", 0))
	_apply_commission_status_border(slot_index, card, _SLOT_VISUAL_ONGOING)


func _set_commission_ready_slot(slot_index: int, entry: Dictionary) -> void:
	var card := _get_commission_card(slot_index)
	var name_label := _get_commission_name_label(slot_index)
	var state_label := _get_commission_state_label(slot_index)
	if card == null or name_label == null or state_label == null:
		return

	name_label.text = str(entry.get("title", "Commission"))
	state_label.text = "Complete · Collect Reward"
	card.disabled = false
	card.focus_mode = Control.FOCUS_ALL
	_commission_slot_actions[slot_index] = "claim"
	var runtime_id := int(entry.get("runtime_id", 0))
	_commission_slot_runtime_ids[slot_index] = runtime_id
	# Guild Hall settlement popup reads from already-stored completion payload
	# on this ready runtime row, not from a second recalculation path.
	_commission_ready_entries_by_runtime_id[runtime_id] = entry.duplicate(true)
	_apply_commission_status_border(slot_index, card, _SLOT_VISUAL_COMPLETED)


func _format_remaining_time(remaining_seconds: int) -> String:
	if remaining_seconds <= 0:
		return "0m"
	var hours := int(remaining_seconds / 3600)
	var minutes := int((remaining_seconds % 3600) / 60)
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % maxi(1, minutes)


func _build_cached_slot_styles() -> void:
	_cached_slot_styles = {
		_SLOT_VISUAL_EMPTY: _build_base_slot_style(_STATUS_BORDER_EMPTY),
		_SLOT_VISUAL_ONGOING: _build_base_slot_style(_STATUS_BORDER_ONGOING),
		_SLOT_VISUAL_COMPLETED: _build_base_slot_style(_STATUS_BORDER_COMPLETED)
	}


func _build_base_slot_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


func _apply_status_border(slot_index: int, card: Button, visual_state: String) -> void:
	if slot_index < 0 or slot_index >= _slot_visual_states.size():
		return
	if _slot_visual_states[slot_index] == visual_state:
		return

	var base_style := _cached_slot_styles.get(visual_state, null) as StyleBoxFlat
	if base_style == null:
		return

	card.add_theme_stylebox_override("normal", base_style)
	card.add_theme_stylebox_override("hover", base_style.duplicate())
	card.add_theme_stylebox_override("pressed", base_style.duplicate())
	card.add_theme_stylebox_override("disabled", base_style.duplicate())
	_slot_visual_states[slot_index] = visual_state


func _apply_commission_status_border(slot_index: int, card: Button, visual_state: String) -> void:
	if slot_index < 0 or slot_index >= _commission_slot_visual_states.size():
		return
	if _commission_slot_visual_states[slot_index] == visual_state:
		return

	var base_style := _cached_slot_styles.get(visual_state, null) as StyleBoxFlat
	if base_style == null:
		return

	card.add_theme_stylebox_override("normal", base_style)
	card.add_theme_stylebox_override("hover", base_style.duplicate())
	card.add_theme_stylebox_override("pressed", base_style.duplicate())
	card.add_theme_stylebox_override("disabled", base_style.duplicate())
	_commission_slot_visual_states[slot_index] = visual_state


func _get_slot_card(slot_index: int) -> Button:
	if slot_index == 0:
		return _slot_one_card
	if slot_index == 1:
		return _slot_two_card
	if slot_index == 2:
		return _slot_three_card
	return null


func _get_slot_name_label(slot_index: int) -> Label:
	if slot_index == 0:
		return _slot_one_name_label
	if slot_index == 1:
		return _slot_two_name_label
	if slot_index == 2:
		return _slot_three_name_label
	return null


func _get_slot_state_label(slot_index: int) -> Label:
	if slot_index == 0:
		return _slot_one_state_label
	if slot_index == 1:
		return _slot_two_state_label
	if slot_index == 2:
		return _slot_three_state_label
	return null


func _get_commission_card(slot_index: int) -> TouchScrollCardButton:
	if slot_index < 0 or slot_index >= _commission_slot_cards.size():
		return null
	return _commission_slot_cards[slot_index]


func _get_commission_name_label(slot_index: int) -> Label:
	if slot_index < 0 or slot_index >= _commission_slot_name_labels.size():
		return null
	return _commission_slot_name_labels[slot_index]


func _get_commission_state_label(slot_index: int) -> Label:
	if slot_index < 0 or slot_index >= _commission_slot_state_labels.size():
		return null
	return _commission_slot_state_labels[slot_index]


func _on_bottom_nav_requested(target_screen: String) -> void:
	navigate_requested.emit(target_screen)


func _on_slot_card_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_is_empty.size():
		return
	if _slot_is_empty[slot_index]:
		navigate_requested.emit(BottomNavBar.TARGET_EXPEDITION_BOARD)
		return
	if _expedition_manager == null:
		return
	var slots := _expedition_manager.get_active_expeditions()
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot_data := slots[slot_index]
	if str(slot_data.get("status", "")) == ExpeditionManager.STATUS_COMPLETED:
		open_report_requested.emit()


func _on_commission_card_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _commission_slot_actions.size():
		return
	var action := _commission_slot_actions[slot_index]
	if action == "open_board":
		navigate_requested.emit(BottomNavBar.TARGET_COMMISSION_BOARD)
		return
	if action == "claim":
		var runtime_id := _commission_slot_runtime_ids[slot_index]
		if runtime_id > 0:
			# Completed cards now open a compact settlement popup first so players
			# can review outcome details before explicitly pressing Claim.
			_open_commission_settlement_popup(runtime_id)


func _on_debug_finish_pressed() -> void:
	debug_finish_requested.emit()


func _on_debug_reset_pressed() -> void:
	debug_reset_requested.emit()


func _build_commission_settlement_popup() -> void:
	if _commission_settlement_popup != null:
		return
	_commission_settlement_popup = _COMMISSION_SETTLEMENT_POPUP_SCENE.instantiate() as CommissionSettlementPopup
	add_child(_commission_settlement_popup)
	_commission_settlement_popup.claim_requested.connect(func(runtime_id: int) -> void:
		commission_claim_requested.emit(runtime_id)
	)


func _open_commission_settlement_popup(runtime_id: int) -> void:
	if _commission_settlement_popup == null:
		return
	var entry := _commission_ready_entries_by_runtime_id.get(runtime_id, {}) as Dictionary
	if entry.is_empty():
		return
	# Closing this popup must not consume the entry; claim happens only when the
	# popup's Claim button emits claim_requested.
	_commission_settlement_popup.open_for_entry(entry)
