extends Control
class_name GuildHallController

# GuildHallController is the home screen for the current gameplay loop.
# In the two-slot milestone it shows both expedition slots (empty/active/
# completed), the pending report count, and entry points to dispatch/reports.
# It also exposes Upgrades/Codex navigation and temporary debug controls.
# This script also exposes temporary debug controls:
# - finish active expedition instantly (test-only)
# - reset all prototype progress through GameManager's shared baseline reset flow.

signal open_expedition_board_requested
signal open_report_requested
signal open_upgrades_requested
signal open_codex_requested
signal debug_finish_requested
signal debug_reset_requested

@onready var _gold_label: Label = $SafeArea/RootColumn/ResourcesPanel/ResourceRows/GoldLabel
@onready var _relic_fragments_label: Label = $SafeArea/RootColumn/ResourcesPanel/ResourceRows/RelicFragmentsLabel
@onready var _codex_entries_label: Label = $SafeArea/RootColumn/ResourcesPanel/ResourceRows/CodexEntriesLabel
@onready var _open_report_button: Button = $SafeArea/RootColumn/OpenReportButton
@onready var _pending_reports_label: Label = $SafeArea/RootColumn/PendingReportsLabel
@onready var _open_upgrades_button: Button = $SafeArea/RootColumn/OpenUpgradesButton
@onready var _open_codex_button: Button = $SafeArea/RootColumn/OpenCodexButton
@onready var _debug_finish_button: Button = $SafeArea/RootColumn/DebugFinishButton
@onready var _debug_reset_button: Button = $SafeArea/RootColumn/DebugResetButton
@onready var _slot_one_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/SlotOneLabel
@onready var _slot_two_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/SlotTwoLabel

var _expedition_manager: ExpeditionManager
var _resources := {
	"gold": 0,
	"relic_fragments": 0,
	"codex_entries": 0
}


func _ready() -> void:
	$SafeArea/RootColumn/OpenBoardButton.pressed.connect(_on_open_board_pressed)
	_open_upgrades_button.pressed.connect(_on_open_upgrades_pressed)
	_open_codex_button.pressed.connect(_on_open_codex_pressed)
	_open_report_button.pressed.connect(_on_open_report_pressed)
	_debug_finish_button.pressed.connect(_on_debug_finish_pressed)
	_debug_reset_button.pressed.connect(_on_debug_reset_pressed)
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
	_gold_label.text = "Gold: %d" % int(_resources.get("gold", 0))
	_relic_fragments_label.text = "Relic Fragments: %d" % int(_resources.get("relic_fragments", 0))
	_codex_entries_label.text = "Codex Entries: %d" % int(_resources.get("codex_entries", 0))


func _refresh_active_status() -> void:
	# onready refs can be null during scene teardown/reparenting.
	if _slot_one_label == null or _slot_two_label == null:
		return

	if _expedition_manager == null:
		_slot_one_label.text = "Slot 1: Empty"
		_slot_two_label.text = "Slot 2: Empty"
		_pending_reports_label.text = "Pending Reports: 0"
		_open_report_button.visible = false
		_debug_finish_button.visible = false
		return

	var slots := _expedition_manager.get_active_expeditions()
	_slot_one_label.text = _build_slot_text(0, slots)
	_slot_two_label.text = _build_slot_text(1, slots)

	var pending_count := _expedition_manager.get_pending_report_count()
	_pending_reports_label.text = "Pending Reports: %d" % pending_count

	# Show report button only when a completion report is waiting.
	_open_report_button.visible = pending_count > 0
	if pending_count > 0:
		_open_report_button.text = "Open Expedition Report (%d)" % pending_count
	else:
		_open_report_button.text = "Open Expedition Report"

	# TEMPORARY DEBUG BUTTON: this is test-only and can be removed once QA no longer
	# needs instant completion during development.
	_debug_finish_button.visible = _expedition_manager.has_active_expedition()
	# TEMPORARY DEBUG BUTTON: always available in Guild Hall so testers can quickly
	# clear save + runtime state and return to a known clean baseline.
	_debug_reset_button.visible = true


func _build_slot_text(slot_index: int, slots: Array[Dictionary]) -> String:
	if slot_index < 0 or slot_index >= slots.size():
		return "Slot %d: Empty" % (slot_index + 1)

	var slot_data := slots[slot_index]
	if slot_data.is_empty():
		return "Slot %d: Empty" % (slot_index + 1)

	var expedition_name := str(slot_data.get("display_name", "Unknown Expedition"))
	var status := str(slot_data.get("status", ExpeditionManager.STATUS_IDLE))
	if status == ExpeditionManager.STATUS_IN_PROGRESS:
		var remaining_text := _expedition_manager.get_remaining_time_text_for_slot(slot_index)
		return "Slot %d: Active - %s (%s left)" % [slot_index + 1, expedition_name, remaining_text]
	return "Slot %d: Completed - %s (Report queued)" % [slot_index + 1, expedition_name]


func _on_open_board_pressed() -> void:
	open_expedition_board_requested.emit()


func _on_open_report_pressed() -> void:
	open_report_requested.emit()


func _on_open_upgrades_pressed() -> void:
	open_upgrades_requested.emit()


func _on_open_codex_pressed() -> void:
	open_codex_requested.emit()


func _on_debug_finish_pressed() -> void:
	debug_finish_requested.emit()


func _on_debug_reset_pressed() -> void:
	debug_reset_requested.emit()
