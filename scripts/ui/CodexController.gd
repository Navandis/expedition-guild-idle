extends Control
class_name CodexController

# File: CodexController.gd
# CodexController renders the prototype Codex screen for the day-3 milestone.
# It reads discovery data from CodexSystem and turns it into simple progress
# text so players can quickly see what site types they have discovered.
# Layout note: the discoveries block now lives inside a ScrollContainer so
# long text scrolls within content space and cannot push the shared bottom nav
# off-screen on shorter viewports.

signal back_requested
signal navigate_requested(target_screen: String)

@onready var _summary_label: Label = $SafeArea/RootColumn/HeaderPanel/HeaderRows/SummaryLabel
@onready var _hint_label: Label = $SafeArea/RootColumn/HeaderPanel/HeaderRows/HintLabel
@onready var _entries_list_label: Label = $SafeArea/RootColumn/EntriesScroll/EntriesPanel/EntriesRows/EntriesListLabel
@onready var _bottom_nav: BottomNavBar = $SafeArea/RootColumn/BottomNavBar


func _ready() -> void:
	$SafeArea/RootColumn/BackButton.pressed.connect(_on_back_pressed)
	# Bottom nav is shared; center CX is the active destination on this screen.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_CODEX)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)


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


func _on_bottom_nav_requested(target_screen: String) -> void:
	navigate_requested.emit(target_screen)
