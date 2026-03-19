extends Node

# GameManager owns high-level screen flow and shared runtime state.
# For this milestone it closes the first loop by coordinating:
# dispatch -> wait/finish -> report -> collect -> resource update.
# Day-3 extends this flow with the Guild Upgrades screen and applies purchased
# upgrade effects to newly started expeditions and reward calculations.

const GUILD_HALL_SCENE := preload("res://scenes/guild_hall/GuildHall.tscn")
const EXPEDITION_BOARD_SCENE := preload("res://scenes/expedition_board/ExpeditionBoard.tscn")
const DISPATCH_SCREEN_SCENE := preload("res://scenes/dispatch/DispatchScreen.tscn")
const EXPEDITION_REPORT_SCENE := preload("res://scenes/report/ExpeditionReport.tscn")
const GUILD_UPGRADES_SCENE := preload("res://scenes/upgrades/GuildUpgrades.tscn")

var _expedition_manager := ExpeditionManager.new()
var _upgrade_system := UpgradeSystem.new()
var _resources := {
	"gold": 1250,
	"relic_fragments": 0,
	"codex_entries": 0
}

var _guild_hall_controller: GuildHallController
var _expedition_board_controller: ExpeditionBoardController
var _dispatch_controller: DispatchController
var _report_controller: ReportController
var _upgrades_controller: UpgradesController
var _mounted_screen: Control

@onready var _ui_root: Control = $CanvasLayer/UIRoot


func _ready() -> void:
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
		_guild_hall_controller.debug_finish_requested.connect(_on_debug_finish_requested)

	_show_screen(_guild_hall_controller)
	_guild_hall_controller.set_expedition_manager(_expedition_manager)
	_guild_hall_controller.set_resources(_resources)


func _show_expedition_board() -> void:
	if _expedition_board_controller == null:
		_expedition_board_controller = EXPEDITION_BOARD_SCENE.instantiate() as ExpeditionBoardController
		_expedition_board_controller.expedition_dispatch_requested.connect(_on_expedition_dispatch_requested)
		_expedition_board_controller.return_to_guild_hall_requested.connect(_on_return_to_guild_hall_requested)

	_expedition_board_controller.set_duration_multiplier(float(_upgrade_system.get_effects_summary().get("duration_multiplier", 1.0)))
	_show_screen(_expedition_board_controller)


func _show_dispatch_screen(expedition_data: Dictionary) -> void:
	if _dispatch_controller == null:
		_dispatch_controller = DISPATCH_SCREEN_SCENE.instantiate() as DispatchController
		_dispatch_controller.confirmed.connect(_on_dispatch_confirmed)
		_dispatch_controller.canceled.connect(_on_dispatch_canceled)

	# Always route through the dispatch screen so it can explain why dispatch is blocked.
	_show_screen(_dispatch_controller)
	_dispatch_controller.set_expedition_data(expedition_data)
	_dispatch_controller.set_dispatch_blocked(
		not _expedition_manager.can_start_expedition(),
		_expedition_manager.get_active_expedition()
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


func _on_debug_finish_requested() -> void:
	# This calls the same completion path used by natural timer completion.
	_expedition_manager.complete_active_expedition()
	if _expedition_manager.has_pending_report():
		_show_report_screen()


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
		_show_guild_hall()
		return

	print("Dispatch confirmed: %s" % str(expedition_data.get("id", "unknown")))

	if _expedition_board_controller != null:
		_expedition_board_controller.replace_expedition_by_id(
			str(expedition_data.get("id", "")),
			expedition_data
		)

	_show_guild_hall()


func _on_dispatch_canceled() -> void:
	_show_expedition_board()


func _on_report_collect_requested() -> void:
	# Reward collection is one-time and clears both report + completed expedition.
	var rewards := _expedition_manager.collect_pending_report()
	if rewards.is_empty():
		_show_guild_hall()
		return

	_resources["gold"] = int(_resources.get("gold", 0)) + int(rewards.get("gold", 0))
	_resources["relic_fragments"] = int(_resources.get("relic_fragments", 0)) + int(rewards.get("relic_fragments", 0))
	_resources["codex_entries"] = int(_resources.get("codex_entries", 0)) + int(rewards.get("codex_entries", 0))
	_show_guild_hall()


func _on_upgrades_back_requested() -> void:
	_show_guild_hall()


func _on_upgrade_purchase_requested(upgrade_id: String) -> void:
	var result := _upgrade_system.try_purchase_upgrade(upgrade_id, int(_resources.get("gold", 0)))
	if bool(result.get("ok", false)):
		_resources["gold"] = int(result.get("remaining_gold", int(_resources.get("gold", 0))))
		if _expedition_board_controller != null:
			_expedition_board_controller.set_duration_multiplier(
				float(_upgrade_system.get_effects_summary().get("duration_multiplier", 1.0))
			)

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
