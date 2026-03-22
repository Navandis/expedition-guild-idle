extends Control
class_name GuildHallController

# File: GuildHallController.gd
# Guild Hall is the dashboard landing screen for the prototype loop.
# This controller keeps the screen lightweight by handling only:
# - resource value text updates (icons are wired in the scene),
# - two active expedition cards with compact status text,
# - completed-card clicks as the report entry point,
# - shared bottom-nav routing and test-only debug actions.
# Note for beginners:
# - the old "Pending Reports..." label was intentionally removed from the UI;
#   completed slot cards are now the report-entry cue.
# - the "PP" badge was moved into its own top-left panel in GuildHall.tscn so
#   the resource row only shows real resource counters.
# - GuildHall.tscn now uses section-level layout anchors instead of one giant
#   global SafeArea wrapper. Top widgets, expedition cards, and bottom nav are
#   now separate containers so they can be positioned independently.
# - TopSafeArea is explicitly given a bottom offset in the scene so the top
#   stack has guaranteed height (top-level Controls do not auto-size to children).
# - ExpeditionSectionFill was removed from the scene because it only consumed
#   vertical space and prevented expedition cards from using the intended area.
# - Bottom nav now lives in its own bottom-anchored safe margin container so
#   it stays visible while the expedition section remains bounded above it.
# - expedition card labels now use word-wrap + smaller font sizes in the scene
#   for compact, stable text even when expedition names are long.

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

@onready var _gold_value_label: Label = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/GoldCounter/Row/GoldValueLabel
@onready var _relic_fragments_value_label: Label = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/RelicCounter/Row/RelicFragmentsValueLabel
@onready var _codex_entries_value_label: Label = $TopSafeArea/TopStack/TopPanelsRow/ResourceRowPanel/ResourceRowMargin/ResourceSlots/CodexCounter/Row/CodexEntriesValueLabel
@onready var _debug_finish_button: Button = $TopSafeArea/TopStack/TopRightToolsRow/DebugFinishButton
@onready var _debug_reset_button: Button = $TopSafeArea/TopStack/TopRightToolsRow/DebugResetButton
@onready var _slot_one_card: Button = $ExpeditionSectionPanel/ExpeditionSectionMargin/ExpeditionSectionColumn/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotOneCard
@onready var _slot_two_card: Button = $ExpeditionSectionPanel/ExpeditionSectionMargin/ExpeditionSectionColumn/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotTwoCard
@onready var _slot_one_name_label: Label = $ExpeditionSectionPanel/ExpeditionSectionMargin/ExpeditionSectionColumn/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotOneCard/Margin/Content/SlotOneNameLabel
@onready var _slot_one_state_label: Label = $ExpeditionSectionPanel/ExpeditionSectionMargin/ExpeditionSectionColumn/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotOneCard/Margin/Content/SlotOneStateLabel
@onready var _slot_two_name_label: Label = $ExpeditionSectionPanel/ExpeditionSectionMargin/ExpeditionSectionColumn/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotTwoCard/Margin/Content/SlotTwoNameLabel
@onready var _slot_two_state_label: Label = $ExpeditionSectionPanel/ExpeditionSectionMargin/ExpeditionSectionColumn/ExpeditionSlotsScroller/ExpeditionSlotsRow/SlotTwoCard/Margin/Content/SlotTwoStateLabel
@onready var _expedition_section_panel: PanelContainer = $ExpeditionSectionPanel
@onready var _bottom_nav_safe: MarginContainer = $BottomNavSafe
@onready var _bottom_nav: BottomNavBar = $BottomNavSafe/BottomNavBar

var _expedition_manager: ExpeditionManager
var _resources := {
	"gold": 0,
	"relic_fragments": 0,
	"codex_entries": 0
}
var _slot_is_empty: Array[bool] = [true, true]
var _slot_visual_states: Array[String] = ["", ""]
var _cached_slot_styles: Dictionary = {}
var _expedition_offset_left := 0.0
var _expedition_offset_right := 0.0


func _ready() -> void:
	_debug_finish_button.pressed.connect(_on_debug_finish_pressed)
	_debug_reset_button.pressed.connect(_on_debug_reset_pressed)
	_slot_one_card.pressed.connect(func() -> void:
		_on_slot_card_pressed(0)
	)
	_slot_two_card.pressed.connect(func() -> void:
		_on_slot_card_pressed(1)
	)
	# Shared bottom nav is the primary cross-screen backbone.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_GUILD_HALL)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)
	_build_cached_slot_styles()
	# Preserve scene-authored horizontal padding so this script only owns vertical
	# bounds for the middle section.
	_expedition_offset_left = _expedition_section_panel.offset_left
	_expedition_offset_right = _expedition_section_panel.offset_right
	# Layout is updated at resize/layout events instead of in _process(). This keeps
	# the middle section stable and avoids per-frame layout churn.
	resized.connect(_on_layout_changed)
	_bottom_nav_safe.resized.connect(_on_layout_changed)
	# Defer the first pass so all Control nodes have their final initial size.
	call_deferred("_update_expedition_section_layout")
	# Polling each frame is acceptable for this prototype-sized status block.
	set_process(true)
	_refresh_resource_labels()
	_refresh_active_status()


func _process(_delta: float) -> void:
	_refresh_active_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		# Theme/safe-area adjustments can move BottomNavSafe without a gameplay event.
		# This notification can fire before @onready nodes are initialized while the
		# control is still entering the tree, so defer until the node is ready.
		if not is_node_ready():
			call_deferred("_update_expedition_section_layout")
			return
		# Recompute the bounded expedition area at this safe layout point.
		_update_expedition_section_layout()


func _on_layout_changed() -> void:
	_update_expedition_section_layout()


func _update_expedition_section_layout() -> void:
	# Coordinate-space note:
	# - GuildHall (self), ExpeditionSectionPanel, and BottomNavSafe share the same
	#   parent/local space, so we use local positions/sizes directly.
	# - This avoids fragile global/local mixing and keeps math robust if hierarchy
	#   internals change but these nodes remain siblings.
	var parent_height := size.y
	if parent_height <= 0.0:
		return

	var midpoint_y := parent_height * 0.5
	var bottom_nav_top_y := _bottom_nav_safe.position.y
	var bounded_height: float = maxf(0.0, bottom_nav_top_y - midpoint_y)

	# Keep horizontal behavior from the scene, but drive vertical bounds explicitly:
	# top = viewport midpoint, bottom = top edge of BottomNavSafe.
	_expedition_section_panel.anchor_left = 0.0
	_expedition_section_panel.anchor_right = 1.0
	_expedition_section_panel.offset_left = _expedition_offset_left
	_expedition_section_panel.offset_right = _expedition_offset_right
	_expedition_section_panel.anchor_top = 0.0
	_expedition_section_panel.anchor_bottom = 0.0
	_expedition_section_panel.offset_top = midpoint_y
	_expedition_section_panel.offset_bottom = midpoint_y + bounded_height


func set_expedition_manager(expedition_manager: ExpeditionManager) -> void:
	_expedition_manager = expedition_manager
	_refresh_active_status()


func set_resources(resources: Dictionary) -> void:
	_resources = resources.duplicate(true)
	_refresh_resource_labels()


func _refresh_resource_labels() -> void:
	# Icon textures are assigned in GuildHall.tscn.
	# Keep this method focused on number updates only.
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
		_debug_finish_button.visible = false
		return

	var slots := _expedition_manager.get_active_expeditions()
	_refresh_slot_card(0, slots)
	_refresh_slot_card(1, slots)

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

	if card == null or name_label == null or state_label == null:
		return

	if slot_index < 0 or slot_index >= slots.size():
		_set_empty_slot_card(slot_index)
		return

	var slot_data := slots[slot_index]
	if slot_data.is_empty():
		_set_empty_slot_card(slot_index)
		return

	# Remove static "Slot X" prefix so each card reads as a compact expedition tile.
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

	# Completed cards are now the report interaction entry, replacing the removed
	# "View Pending Reports" button from the old layout.
	state_label.text = "Completed · tap to collect report"
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
	# for enabled and disabled card states.
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


func _on_bottom_nav_requested(target_screen: String) -> void:
	# GH/EB/GU/CX are active routes; XX/XX/SH stay inert in the nav component.
	navigate_requested.emit(target_screen)


func _on_slot_card_pressed(slot_index: int) -> void:
	# Empty card -> Expedition Board.
	# Completed card -> Report flow entry (lightweight replacement for removed button).
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


func _on_debug_finish_pressed() -> void:
	debug_finish_requested.emit()


func _on_debug_reset_pressed() -> void:
	debug_reset_requested.emit()
