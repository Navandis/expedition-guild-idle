extends Control
class_name CodexController

# CodexController renders the prototype Codex screen for the day-3 milestone.
# It reads discovery data from CodexSystem and turns it into simple progress
# text so players can quickly see what site types they have discovered.

signal back_requested

@onready var _summary_label: Label = $SafeArea/RootColumn/HeaderPanel/HeaderRows/SummaryLabel
@onready var _hint_label: Label = $SafeArea/RootColumn/HeaderPanel/HeaderRows/HintLabel
@onready var _entries_list_label: Label = $SafeArea/RootColumn/EntriesPanel/EntriesRows/EntriesListLabel


func _ready() -> void:
	$SafeArea/RootColumn/BackButton.pressed.connect(_on_back_pressed)


func set_codex_data(total_discoveries: int, discovered_entries: Array[String]) -> void:
	# This screen is intentionally text-only for now, but still exposes clear
	# progress by showing a total and a readable list of known site types.
	_summary_label.text = "Discoveries unlocked: %d" % total_discoveries
	_hint_label.text = "New discoveries are added the first time you collect rewards from a new site type."

	if discovered_entries.is_empty():
		_entries_list_label.text = "No discoveries yet. Complete and collect an expedition report to start your Codex."
		return

	var lines: Array[String] = []
	for i in discovered_entries.size():
		lines.append("%d. %s" % [i + 1, _to_entry_label(discovered_entries[i])])
	_entries_list_label.text = "\n".join(lines)


func _to_entry_label(site_type: String) -> String:
	# Convert internal IDs like "sunken_ruins" into beginner-friendly labels.
	var label := site_type.replace("_", " ")
	return label.capitalize()


func _on_back_pressed() -> void:
	back_requested.emit()
