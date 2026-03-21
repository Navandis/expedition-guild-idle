extends Control
class_name GuildHallController

# File: GuildHallController.gd
# GuildHallController is the dashboard-style landing screen for the current
# prototype loop. It now prioritizes:
# - top resource strip (7 equal visual slots),
# - compact expedition slot cards (empty/ongoing/completed),
# - pending report state,
# while cross-screen movement stays in the shared bottom nav.
#
# This script also exposes temporary debug controls:
# - finish active expedition instantly (test-only)
# - reset all prototype progress through GameManager's shared baseline reset flow.

signal open_report_requested
signal navigate_requested(target_screen: String)
signal debug_finish_requested
signal debug_reset_requested

const _STATUS_BORDER_EMPTY := Color(0.95, 0.55, 0.20, 1.0)
const _STATUS_BORDER_ONGOING := Color(0.95, 0.84, 0.20, 1.0)
const _STATUS_BORDER_COMPLETED := Color(0.35, 0.85, 0.45, 1.0)
const _SLOT_VISUAL_EMPTY := "empty"
const _SLOT_VISUAL_ONGOING := "ongoing"
const _SLOT_VISUAL_COMPLETED := "completed"

@onready var _gold_value_label: Label = $SafeArea/RootColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/GoldValueSlot/Center/GoldValueLabel
@onready var _relic_fragments_value_label: Label = $SafeArea/RootColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/RelicValueSlot/Center/RelicFragmentsValueLabel
@onready var _codex_entries_value_label: Label = $SafeArea/RootColumn/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CodexValueSlot/Center/CodexEntriesValueLabel
@onready var _open_report_button: Button = $SafeArea/RootColumn/OpenReportButton
@onready var _pending_reports_label: Label = $SafeArea/RootColumn/PendingReportsLabel
@onready var _debug_finish_button: Button = $SafeArea/RootColumn/DebugFinishButton
@onready var _debug_reset_button: Button = $SafeArea/RootColumn/DebugResetButton
@onready var _slot_one_card: Button = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotOneCard
@onready var _slot_two_card: Button = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotTwoCard
@onready var _slot_one_name_label: Label = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotOneCard/Margin/Content/TopRow/TextColumn/SlotOneNameLabel
@onready var _slot_one_state_label: Label = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotOneCard/Margin/Content/TopRow/TextColumn/SlotOneStateLabel
@onready var _slot_one_reward_label: Label = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotOneCard/Margin/Content/SlotOneRewardLabel
@onready var _slot_two_name_label: Label = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotTwoCard/Margin/Content/TopRow/TextColumn/SlotTwoNameLabel
@onready var _slot_two_state_label: Label = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotTwoCard/Margin/Content/TopRow/TextColumn/SlotTwoStateLabel
@onready var _slot_two_reward_label: Label = $SafeArea/RootColumn/ExpeditionSlotsColumn/SlotTwoCard/Margin/Content/SlotTwoRewardLabel
@onready var _bottom_nav: BottomNavBar = $SafeArea/RootColumn/BottomNavBar

var _expedition_manager: ExpeditionManager
var _resources := {
	"gold": 0,
	"relic_fragments": 0,
	"codex_entries": 0
}
var _slot_is_empty: Array[bool] = [true, true]
var _slot_visual_states: Array[String] = ["", ""]
var _cached_slot_styles: Dictionary = {}


func _ready() -> void:
	_open_report_button.pressed.connect(_on_open_report_pressed)
	_debug_finish_button.pressed.connect(_on_debug_finish_pressed)
	_debug_reset_button.pressed.connect(_on_debug_reset_pressed)
	_slot_one_card.pressed.connect(func() -> void:
		_on_slot_card_pressed(0)
	)
	_slot_two_card.pressed.connect(func() -> void:
		_on_slot_card_pressed(1)
	)
	# Shared bottom nav is now the primary cross-screen backbone.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_GUILD_HALL)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)
	_build_cached_slot_styles()
	# Polling each frame is acceptable for this prototype-sized status block.
	set_process(true)
	_refresh_resource_labels()
	_refresh_active_status()


func _process(_delta: float) -> void:
	_refresh_active_status()


func set_expedition_manager(expedition_manager: ExpeditionManager) -> void:
	_expedition_manager = expedition_manager
	_refresh_active_status()


func set_resources(resources: Dictionary) -> void:
	_resources = resources.duplicate(true)
	_refresh_resource_labels()


func _refresh_resource_labels() -> void:
	# Resource row layout note:
	# - slot 1 is PP placeholder
	# - slots 2/3 are G + gold value
	# - slots 4/5 are R + relic fragment value
	# - slots 6/7 are C + codex entry value
	_gold_value_label.text = str(int(_resources.get("gold", 0)))
	_relic_fragments_value_label.text = str(int(_resources.get("relic_fragments", 0)))
	_codex_entries_value_label.text = str(int(_resources.get("codex_entries", 0)))


func _refresh_active_status() -> void:
	# onready refs can be null during scene teardown/reparenting.
	if _slot_one_card == null or _slot_two_card == null:
		return

	if _expedition_manager == null:
		_set_empty_slot_card(0)
		_set_empty_slot_card(1)
		_pending_reports_label.text = "Pending Reports: 0 (none ready)"
		_open_report_button.visible = false
		_debug_finish_button.visible = false
		return

	var slots := _expedition_manager.get_active_expeditions()
	_refresh_slot_card(0, slots)
	_refresh_slot_card(1, slots)

	var pending_count := _expedition_manager.get_pending_report_count()
	if pending_count > 0:
		_pending_reports_label.text = "Pending Reports: %d ready to collect" % pending_count
	else:
		_pending_reports_label.text = "Pending Reports: 0 (none ready)"

	# Show report button only when a completion report is waiting.
	_open_report_button.visible = pending_count > 0
	if pending_count > 0:
		_open_report_button.text = "View Pending Reports (%d)" % pending_count
	else:
		_open_report_button.text = "View Pending Reports"

	# TEMPORARY DEBUG BUTTON: this is test-only and can be removed once QA no longer
	# needs instant completion during development.
	_debug_finish_button.visible = _expedition_manager.has_active_expedition()
	# TEMPORARY DEBUG BUTTON: always available in Guild Hall so testers can quickly
	# clear save + runtime state and return to a known clean baseline.
	_debug_reset_button.visible = true


func _refresh_slot_card(slot_index: int, slots: Array[Dictionary]) -> void:
	var card := _get_slot_card(slot_index)
	var name_label := _get_slot_name_label(slot_index)
	var state_label := _get_slot_state_label(slot_index)
	var reward_label := _get_slot_reward_label(slot_index)

	if card == null or name_label == null or state_label == null or reward_label == null:
		return

	if slot_index < 0 or slot_index >= slots.size():
		_set_empty_slot_card(slot_index)
		return

	var slot_data := slots[slot_index]
	if slot_data.is_empty():
		_set_empty_slot_card(slot_index)
		return

	var expedition_name := str(slot_data.get("display_name", "Unknown Expedition"))
	var status := str(slot_data.get("status", ExpeditionManager.STATUS_IDLE))
	name_label.text = "Slot %d: %s" % [slot_index + 1, expedition_name]

	if status == ExpeditionManager.STATUS_IN_PROGRESS:
		var remaining_text := _expedition_manager.get_remaining_time_text_for_slot(slot_index)
		# Ongoing slot card behavior: compact summary + timer.
		state_label.text = "In progress · %s left" % remaining_text
		reward_label.visible = false
		reward_label.text = ""
		_slot_is_empty[slot_index] = false
		card.disabled = true
		card.focus_mode = Control.FOCUS_NONE
		_apply_status_border(slot_index, card, _SLOT_VISUAL_ONGOING)
		return

	# Completed slot card behavior: compact summary + queued report hint.
	state_label.text = "Completed · report ready"
	reward_label.visible = true
	reward_label.text = "Reward: collect from Pending Reports"
	_slot_is_empty[slot_index] = false
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	_apply_status_border(slot_index, card, _SLOT_VISUAL_COMPLETED)


func _set_empty_slot_card(slot_index: int) -> void:
	var card := _get_slot_card(slot_index)
	var name_label := _get_slot_name_label(slot_index)
	var state_label := _get_slot_state_label(slot_index)
	var reward_label := _get_slot_reward_label(slot_index)
	if card == null or name_label == null or state_label == null or reward_label == null:
		return

	name_label.text = "Slot %d: Empty" % (slot_index + 1)
	# Empty slot behavior: pressing this card routes to Expedition Board.
	state_label.text = "Tap to open Expedition Board"
	reward_label.visible = false
	reward_label.text = ""
	_slot_is_empty[slot_index] = true
	card.disabled = false
	card.focus_mode = Control.FOCUS_ALL
	_apply_status_border(slot_index, card, _SLOT_VISUAL_EMPTY)


func _build_cached_slot_styles() -> void:
	# Build style resources once, then reuse them. This avoids allocating new
	# StyleBoxFlat instances every frame while _process refreshes slot status.
	_cached_slot_styles = {
		_SLOT_VISUAL_EMPTY: _build_base_slot_style(_STATUS_BORDER_EMPTY),
		_SLOT_VISUAL_ONGOING: _build_base_slot_style(_STATUS_BORDER_ONGOING),
		_SLOT_VISUAL_COMPLETED: _build_base_slot_style(_STATUS_BORDER_COMPLETED)
	}


func _build_base_slot_style(border_color: Color) -> StyleBoxFlat:
	# Temporary prototype border logic:
	# - orange: empty, yellow: ongoing, green: completed.
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
	# Reapply only when visual state changed for this slot (empty/ongoing/completed).
	# Timer text may update every frame, but border styles now stay stable.
	if slot_index < 0 or slot_index >= _slot_visual_states.size():
		return
	if _slot_visual_states[slot_index] == visual_state:
		return

	var base_style := _cached_slot_styles.get(visual_state, null) as StyleBoxFlat
	if base_style == null:
		return

	# We still override all button states so border color remains consistent
	# even when the card is disabled for ongoing/completed slots.
	card.add_theme_stylebox_override("normal", base_style)
	card.add_theme_stylebox_override("hover", base_style.duplicate())
	card.add_theme_stylebox_override("pressed", base_style.duplicate())
	card.add_theme_stylebox_override("disabled", base_style.duplicate())
	_slot_visual_states[slot_index] = visual_state


func _get_slot_card(slot_index: int) -> Button:
	if slot_index == 0:
		return _slot_one_card
	if slot_index == 1:
		return _slot_two_card
	return null


func _get_slot_name_label(slot_index: int) -> Label:
	if slot_index == 0:
		return _slot_one_name_label
	if slot_index == 1:
		return _slot_two_name_label
	return null


func _get_slot_state_label(slot_index: int) -> Label:
	if slot_index == 0:
		return _slot_one_state_label
	if slot_index == 1:
		return _slot_two_state_label
	return null


func _get_slot_reward_label(slot_index: int) -> Label:
	if slot_index == 0:
		return _slot_one_reward_label
	if slot_index == 1:
		return _slot_two_reward_label
	return null


func _on_open_report_pressed() -> void:
	open_report_requested.emit()


func _on_bottom_nav_requested(target_screen: String) -> void:
	# GH/EB/GU/CX are active routes; XX/XX/SH stay inert in the nav component.
	navigate_requested.emit(target_screen)


func _on_slot_card_pressed(slot_index: int) -> void:
	# Only empty slots are clickable. They are direct shortcuts to Expedition Board.
	if slot_index < 0 or slot_index >= _slot_is_empty.size():
		return
	if not _slot_is_empty[slot_index]:
		return
	navigate_requested.emit(BottomNavBar.TARGET_EXPEDITION_BOARD)


func _on_debug_finish_pressed() -> void:
	debug_finish_requested.emit()


func _on_debug_reset_pressed() -> void:
	debug_reset_requested.emit()
