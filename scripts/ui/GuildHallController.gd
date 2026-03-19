extends Control
class_name GuildHallController

# GuildHallController is the home screen for the current gameplay loop.
# It shows runtime resources, active expedition status, and entry points to
# either start a run or review/collect a completed expedition report.
# For day-3, it also exposes navigation into Guild Upgrades and the new
# Codex Discoveries screen so collection progress is easy to check.
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
@onready var _open_upgrades_button: Button = $SafeArea/RootColumn/OpenUpgradesButton
@onready var _open_codex_button: Button = $SafeArea/RootColumn/OpenCodexButton
@onready var _debug_finish_button: Button = $SafeArea/RootColumn/DebugFinishButton
@onready var _debug_reset_button: Button = $SafeArea/RootColumn/DebugResetButton
@onready var _active_name_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/ActiveNameLabel
@onready var _remaining_time_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/RemainingTimeLabel
@onready var _active_status_label: Label = $SafeArea/RootColumn/ActiveExpeditionPanel/ActiveRows/StatusLabel

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
	if _active_name_label == null or _remaining_time_label == null or _active_status_label == null:
		return

	if _expedition_manager == null:
		_active_name_label.text = "Expedition: None"
		_remaining_time_label.text = "Remaining: --:--"
		_active_status_label.text = "Status: No active expedition"
		_open_report_button.visible = false
		_debug_finish_button.visible = false
		return

	var expedition := _expedition_manager.get_active_expedition()
	var has_report := _expedition_manager.has_pending_report()

	if expedition.is_empty():
		_active_name_label.text = "Expedition: None"
		_remaining_time_label.text = "Remaining: --:--"
		_active_status_label.text = "Status: No active expedition"
	else:
		# Names come from offer data; fallback text protects against malformed payloads.
		_active_name_label.text = "Expedition: %s" % str(expedition.get("display_name", "Unknown Expedition"))
		_active_status_label.text = "Status: %s" % _expedition_manager.get_status_label()

		if _expedition_manager.has_active_expedition():
			_remaining_time_label.text = "Remaining: %s" % _expedition_manager.get_remaining_time_text()
		else:
			_remaining_time_label.text = "Remaining: 00:00"

	# Show report button only when a completion report is waiting.
	_open_report_button.visible = has_report

	# TEMPORARY DEBUG BUTTON: this is test-only and can be removed once QA no longer
	# needs instant completion during development.
	_debug_finish_button.visible = _expedition_manager.has_active_expedition()
	# TEMPORARY DEBUG BUTTON: always available in Guild Hall so testers can quickly
	# clear save + runtime state and return to a known clean baseline.
	_debug_reset_button.visible = true


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
