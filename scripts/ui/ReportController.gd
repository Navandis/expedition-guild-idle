extends Control
class_name ReportController

# ReportController displays the current report at the front of the pending queue
# and emits collect/close requests. In the two-slot milestone, reports are still
# collected one at a time, so this screen shows queue position for clarity.

signal collect_requested
signal close_requested

@onready var _expedition_name_label: Label = $SafeArea/RootColumn/ReportPanel/Rows/ExpeditionNameLabel
@onready var _queue_label: Label = $SafeArea/RootColumn/QueueLabel
@onready var _outcome_label: Label = $SafeArea/RootColumn/ReportPanel/Rows/OutcomeLabel
@onready var _summary_label: Label = $SafeArea/RootColumn/ReportPanel/Rows/SummaryLabel
@onready var _gold_label: Label = $SafeArea/RootColumn/ReportPanel/Rows/Rewards/GoldLabel
@onready var _relic_label: Label = $SafeArea/RootColumn/ReportPanel/Rows/Rewards/RelicFragmentsLabel
@onready var _codex_label: Label = $SafeArea/RootColumn/ReportPanel/Rows/Rewards/CodexEntriesLabel
@onready var _collect_button: Button = $SafeArea/RootColumn/ButtonsRow/CollectButton


func _ready() -> void:
	_collect_button.pressed.connect(_on_collect_pressed)
	$SafeArea/RootColumn/ButtonsRow/CloseButton.pressed.connect(_on_close_pressed)


func set_report_data(report: Dictionary) -> void:
	# All text is set here so scene defaults are only placeholders.
	var pending_index := int(report.get("queue_index", 0)) + 1
	var pending_total: int = maxi(1, int(report.get("queue_total", 1)))
	_queue_label.text = "Report %d of %d" % [pending_index, pending_total]

	_expedition_name_label.text = "Expedition: %s" % str(report.get("expedition_display_name", "Unknown Expedition"))
	_outcome_label.text = "Outcome: %s" % str(report.get("outcome_label", "Unknown"))
	_summary_label.text = "Summary: %s" % str(report.get("summary", "No report summary."))

	var rewards: Dictionary = report.get("rewards", {}) as Dictionary
	_gold_label.text = "Gold: +%d" % int(rewards.get("gold", 0))
	_relic_label.text = "Relic Fragments: +%d" % int(rewards.get("relic_fragments", 0))
	_codex_label.text = "Codex Entries: +%d" % int(rewards.get("codex_entries", 0))

	# Once a report is collected, keep button disabled so it cannot be claimed twice.
	_collect_button.disabled = bool(report.get("collected", false))
	if pending_total > pending_index:
		_collect_button.text = "Collect & View Next"
	else:
		_collect_button.text = "Collect Rewards"


func _on_collect_pressed() -> void:
	if _collect_button.disabled:
		return
	# Disable immediately to guard against accidental double-taps collecting
	# multiple queued reports before the screen re-renders.
	_collect_button.disabled = true
	collect_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
