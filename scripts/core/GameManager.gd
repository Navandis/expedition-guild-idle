extends Node

# GameManager owns high-level screen flow and shared runtime state.
# For this milestone it coordinates the two-slot expedition loop:
# dispatch -> wait/finish per slot -> queued reports -> collect one-by-one.
# When multiple reports are queued, GameManager keeps the player on the report
# screen and immediately shows the next pending report after each collect.
# It also keeps upgrades/codex/save behavior wired to the same flow and provides
# debug reset/finish hooks that reuse real expedition completion logic.
#
# Region foundation slice:
# - loads authored region definitions through RegionSystem,
# - tracks selected region runtime state,
# - persists per-region player progress + selected region id,
# - passes selected-region constraints into expedition board generation.

const GUILD_HALL_SCENE := preload("res://scenes/guild_hall/GuildHall.tscn")
const EXPEDITION_BOARD_SCENE := preload("res://scenes/expedition_board/ExpeditionBoard.tscn")
const DISPATCH_SCREEN_SCENE := preload("res://scenes/dispatch/DispatchScreen.tscn")
const EXPEDITION_REPORT_SCENE := preload("res://scenes/report/ExpeditionReport.tscn")
const GUILD_UPGRADES_SCENE := preload("res://scenes/upgrades/GuildUpgrades.tscn")
const CODEX_SCREEN_SCENE := preload("res://scenes/codex/CodexScreen.tscn")
const DEFAULT_RESOURCES := {
	"gold": 1250,
	"relic_fragments": 0,
	"codex_entries": 0
}

var _expedition_manager := ExpeditionManager.new()
var _upgrade_system := UpgradeSystem.new()
var _codex_system := CodexSystem.new()
var _region_system := RegionSystem.new()
var _save_manager := SaveManager.new()
var _resources := DEFAULT_RESOURCES.duplicate(true)
var _expedition_board_offers: Array[Dictionary] = []

var _guild_hall_controller: GuildHallController
var _expedition_board_controller: ExpeditionBoardController
var _dispatch_controller: DispatchController
var _report_controller: ReportController
var _upgrades_controller: UpgradesController
var _codex_controller: CodexController
var _mounted_screen: Control

@onready var _ui_root: Control = $CanvasLayer/UIRoot


func _ready() -> void:
	_load_runtime_state()
	_show_guild_hall()


func get_selected_expedition_for_activation() -> Dictionary:
	# Backward-compatible accessor while the runtime flow migrates to ExpeditionManager.
	return _expedition_manager.get_active_expedition()


func _show_guild_hall() -> void:
	if _guild_hall_controller == null:
		_guild_hall_controller = GUILD_HALL_SCENE.instantiate() as GuildHallController
		_guild_hall_controller.open_expedition_board_requested.connect(_on_open_expedition_board_requested)
		_guild_hall_controller.open_report_requested.connect(_on_open_report_requested)
		_guild_hall_controller.open_upgrades_requested.connect(_on_open_upgrades_requested)
		_guild_hall_controller.open_codex_requested.connect(_on_open_codex_requested)
		_guild_hall_controller.debug_finish_requested.connect(_on_debug_finish_requested)
		_guild_hall_controller.debug_reset_requested.connect(_on_debug_reset_requested)

	_show_screen(_guild_hall_controller)
	_guild_hall_controller.set_expedition_manager(_expedition_manager)
	_guild_hall_controller.set_resources(_resources)


func _show_expedition_board() -> void:
	if _expedition_board_controller == null:
		_expedition_board_controller = EXPEDITION_BOARD_SCENE.instantiate() as ExpeditionBoardController
		_expedition_board_controller.expedition_dispatch_requested.connect(_on_expedition_dispatch_requested)
		_expedition_board_controller.return_to_guild_hall_requested.connect(_on_return_to_guild_hall_requested)
		_expedition_board_controller.region_selected.connect(_on_region_selected)
		_expedition_board_controller.set_initial_board_offers(_expedition_board_offers)

	_expedition_board_controller.set_upgrade_effects(_upgrade_system.get_effects_summary())
	_expedition_board_controller.set_region_data(
		_region_system.get_region_list_for_ui(),
		_region_system.get_generation_rules_for_selected_region()
	)
	_show_screen(_expedition_board_controller)
	_capture_expedition_board_state()


func _show_dispatch_screen(expedition_data: Dictionary) -> void:
	if _dispatch_controller == null:
		_dispatch_controller = DISPATCH_SCREEN_SCENE.instantiate() as DispatchController
		_dispatch_controller.confirmed.connect(_on_dispatch_confirmed)
		_dispatch_controller.canceled.connect(_on_dispatch_canceled)

	# Always route through the dispatch screen so it can explain why dispatch is blocked.
	_show_screen(_dispatch_controller)
	_dispatch_controller.set_expedition_data(expedition_data)
	_dispatch_controller.set_dispatch_availability(
		_expedition_manager.get_available_slot_count(),
		_expedition_manager.get_dispatch_block_message()
	)


func _show_report_screen() -> void:
	if _report_controller == null:
		_report_controller = EXPEDITION_REPORT_SCENE.instantiate() as ReportController
		_report_controller.collect_requested.connect(_on_report_collect_requested)
		_report_controller.close_requested.connect(_on_report_close_requested)

	var report := _expedition_manager.get_pending_report()
	if report.is_empty():
		_show_guild_hall()
		return

	# Mount first so ReportController onready label references are initialized.
	_show_screen(_report_controller)
	_report_controller.set_report_data(report)


func _show_upgrades_screen() -> void:
	if _upgrades_controller == null:
		_upgrades_controller = GUILD_UPGRADES_SCENE.instantiate() as UpgradesController
		_upgrades_controller.back_requested.connect(_on_upgrades_back_requested)
		_upgrades_controller.purchase_requested.connect(_on_upgrade_purchase_requested)

	_show_screen(_upgrades_controller)
	_refresh_upgrades_view()


func _show_codex_screen() -> void:
	if _codex_controller == null:
		_codex_controller = CODEX_SCREEN_SCENE.instantiate() as CodexController
		_codex_controller.back_requested.connect(_on_codex_back_requested)

	_show_screen(_codex_controller)
	# Codex screen reads a snapshot so it can render text without touching core state.
	_codex_controller.set_codex_data(
		_codex_system.get_total_discoveries(),
		_codex_system.get_discovered_entries()
	)


func _show_screen(screen: Control) -> void:
	if screen == null:
		return

	if _mounted_screen != null and is_instance_valid(_mounted_screen) and _mounted_screen.get_parent() == _ui_root:
		_ui_root.remove_child(_mounted_screen)

	if screen.get_parent() != null:
		screen.get_parent().remove_child(screen)

	_ui_root.add_child(screen)
	if screen is Control:
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.offset_left = 0.0
		screen.offset_top = 0.0
		screen.offset_right = 0.0
		screen.offset_bottom = 0.0

	screen.show()
	_mounted_screen = screen


func _on_open_expedition_board_requested() -> void:
	_show_expedition_board()


func _on_open_report_requested() -> void:
	_show_report_screen()


func _on_open_upgrades_requested() -> void:
	_show_upgrades_screen()


func _on_open_codex_requested() -> void:
	_show_codex_screen()


func _on_debug_finish_requested() -> void:
	# Debug-complete reuses ExpeditionManager's real slot completion path.
	_expedition_manager.complete_all_active_expeditions_for_debug()
	# Persist immediately so force-completed slots/reports survive app restarts.
	_save_runtime_state()
	if _expedition_manager.has_pending_report():
		_show_report_screen()


func _on_debug_reset_requested() -> void:
	reset_to_debug_baseline()


func reset_to_debug_baseline() -> void:
	# TEMPORARY DEBUG RESET:
	# This is a test-only helper that wipes prototype progression and runtime
	# state in one place to avoid partial resets across multiple scripts.
	_resources = DEFAULT_RESOURCES.duplicate(true)

	# Clear progression systems back to fresh-start values.
	_upgrade_system.restore_owned_upgrade_ids([])
	_codex_system.restore_discoveries([])
	_region_system.restore_player_state({}, "")
	_expedition_manager.restore_runtime_state([], [])
	_expedition_board_offers = []
	_discard_expedition_board_controller()

	# Clear persisted progress so app restarts also stay at baseline.
	var save_cleared := _save_manager.clear_saved_game_state()
	if not save_cleared:
		# Fallback: overwrite with current baseline snapshot if file deletion fails.
		_save_runtime_state()

	# Minimal refresh behavior: always return to Guild Hall with clean values.
	_show_guild_hall()


func _discard_expedition_board_controller() -> void:
	if _expedition_board_controller == null:
		return
	if _mounted_screen == _expedition_board_controller:
		_mounted_screen = null
	if _expedition_board_controller.get_parent() != null:
		_expedition_board_controller.get_parent().remove_child(_expedition_board_controller)
	_expedition_board_controller.queue_free()
	_expedition_board_controller = null


func _on_return_to_guild_hall_requested() -> void:
	_show_guild_hall()


func _on_expedition_dispatch_requested(expedition_data: Dictionary) -> void:
	# Even when dispatch is blocked, we still show this screen so users get
	# contextual messaging and can explicitly back out.
	_show_dispatch_screen(expedition_data)


func _on_dispatch_confirmed(expedition_data: Dictionary) -> void:
	# Upgrade effects are applied right before launch so only future expeditions
	# benefit from new purchases.
	var effects := _upgrade_system.get_effects_summary()
	var started := _expedition_manager.start_expedition(expedition_data, effects)
	if not started:
		# Safe failure path: keep player in dispatch flow with fresh slot messaging.
		_show_dispatch_screen(expedition_data)
		return

	print("Dispatch confirmed: %s" % str(expedition_data.get("id", "unknown")))

	if _expedition_board_controller != null:
		_expedition_board_controller.replace_expedition_by_id(
			str(expedition_data.get("id", "")),
			expedition_data
		)
		_capture_expedition_board_state()

	_save_runtime_state()
	# After a successful dispatch, return to the board so players can
	# immediately start another run or inspect upcoming expeditions.
	_show_expedition_board()


func _on_dispatch_canceled() -> void:
	_show_expedition_board()


func _on_report_collect_requested() -> void:
	var report_snapshot := _expedition_manager.get_pending_report()

	# Reward collection is one-time and clears both report + completed expedition.
	var rewards := _expedition_manager.collect_pending_report()
	if rewards.is_empty():
		_show_guild_hall()
		return

	_resources["gold"] = int(_resources.get("gold", 0)) + int(rewards.get("gold", 0))
	_resources["relic_fragments"] = int(_resources.get("relic_fragments", 0)) + int(rewards.get("relic_fragments", 0))
	_resources["codex_entries"] = int(_resources.get("codex_entries", 0)) + int(rewards.get("codex_entries", 0))

	# Record Codex discovery after a successful collect so the event is stable.
	_codex_system.record_discovery_from_report(report_snapshot)
	_save_runtime_state()

	# Queue-driven report flow: stay in the report screen until queue is empty.
	# This reuses the same report rendering path so queue labels/state stay in sync.
	if _expedition_manager.has_pending_report():
		_show_report_screen()
		return

	# Only return to Guild Hall after the last pending report is collected.
	_show_guild_hall()


func _on_upgrades_back_requested() -> void:
	_show_guild_hall()


func _on_upgrade_purchase_requested(upgrade_id: String) -> void:
	var result := _upgrade_system.try_purchase_upgrade(upgrade_id, int(_resources.get("gold", 0)))
	if bool(result.get("ok", false)):
		_resources["gold"] = int(result.get("remaining_gold", int(_resources.get("gold", 0))))
		if _expedition_board_controller != null:
			_expedition_board_controller.set_upgrade_effects(_upgrade_system.get_effects_summary())
		_save_runtime_state()

	_refresh_upgrades_view()
	if _upgrades_controller != null:
		_upgrades_controller.show_purchase_result(result)


func _refresh_upgrades_view() -> void:
	if _upgrades_controller == null:
		return

	var owned_map := {}
	for upgrade in _upgrade_system.get_all_upgrades():
		var upgrade_id := str(upgrade.get("id", ""))
		owned_map[upgrade_id] = _upgrade_system.is_owned(upgrade_id)

	_upgrades_controller.set_view_model(
		_upgrade_system.get_all_upgrades(),
		owned_map,
		int(_resources.get("gold", 0)),
		_upgrade_system.get_effects_summary()
	)


func _on_report_close_requested() -> void:
	_show_guild_hall()


func _load_runtime_state() -> void:
	# Load flow: start from defaults, then apply any valid JSON save values.
	var save_data := _save_manager.load_game_state()
	if save_data.is_empty():
		# Older/new save default behavior is handled by RegionSystem init defaults.
		return

	# Missing keys are safe: each system uses default fallback values.
	_resources = _sanitize_resources(save_data.get("resources", {}))
	_upgrade_system.restore_owned_upgrade_ids(_to_string_array(save_data.get("owned_upgrades", [])))
	_codex_system.restore_discoveries(_to_string_array(save_data.get("codex_discoveries", [])))
	_region_system.restore_player_state(
		save_data.get("region_progress", {}),
		save_data.get("selected_region_id", "")
	)
	_expedition_manager.restore_runtime_state(
		save_data.get("active_expeditions", save_data.get("active_expedition", [])),
		save_data.get("pending_reports", save_data.get("pending_report", []))
	)
	_expedition_board_offers = _sanitize_board_offers(save_data.get("expedition_board_offers", []))


func _save_runtime_state() -> void:
	# Save flow: capture a snapshot from owner systems and write plain JSON.
	_save_manager.save_game_state({
		"resources": _resources,
		"owned_upgrades": _upgrade_system.get_owned_upgrade_ids(),
		"codex_discoveries": _codex_system.get_discovered_entries(),
		"region_progress": _region_system.build_save_progress_snapshot(),
		"selected_region_id": _region_system.get_selected_region_id(),
		"active_expeditions": _expedition_manager.get_active_expeditions(),
		"pending_reports": _expedition_manager.get_pending_reports(),
		"expedition_board_offers": _expedition_board_offers
	})


func _sanitize_resources(value: Variant) -> Dictionary:
	var source := value as Dictionary if value is Dictionary else {}
	return {
		# Clamp to 0 so malformed saves cannot create confusing negative totals.
		"gold": maxi(0, int(source.get("gold", int(_resources.get("gold", 0))))),
		"relic_fragments": maxi(0, int(source.get("relic_fragments", int(_resources.get("relic_fragments", 0))))),
		"codex_entries": maxi(0, int(source.get("codex_entries", int(_resources.get("codex_entries", 0)))))
	}


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _sanitize_board_offers(value: Variant) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if not (value is Array):
		return offers

	for item in value:
		if not (item is Dictionary):
			continue
		offers.append((item as Dictionary).duplicate(true))
	return offers


func _capture_expedition_board_state() -> void:
	if _expedition_board_controller == null:
		return
	_expedition_board_offers = _expedition_board_controller.get_board_offers()


func _on_region_selected(region_id: String) -> void:
	# Region selection state is owned by RegionSystem and persisted in saves.
	if not _region_system.set_selected_region(region_id):
		return
	_expedition_board_offers = []
	if _expedition_board_controller != null:
		_expedition_board_controller.set_region_data(
			_region_system.get_region_list_for_ui(),
			_region_system.get_generation_rules_for_selected_region()
		)
		_expedition_board_controller.regenerate_board_for_selected_region()
		_capture_expedition_board_state()
	_save_runtime_state()


func _on_codex_back_requested() -> void:
	_show_guild_hall()


func _notification(what: int) -> void:
	# Save when the app exits so prototype testing survives restarts.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save_runtime_state()
