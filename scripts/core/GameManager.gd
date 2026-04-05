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
#
# Commission runtime foundation slice:
# - stores Crew (max/available/assigned/recovering) as runtime player state,
# - stores Supplies as a single v1 operational resource,
# - stores active/ready-to-claim commission runtime rows separately from board offers,
# - keeps these values in save data instead of authored commission JSON.
#
# Supply Runs foundation slice:
# - keeps Supply Board offers separate from live timed Supply Run runtime rows,
# - stores active/ready-to-claim Supply Runs in a dedicated runtime manager,
# - uses progression-owned Supply Run slot capacity from start-conditions/save.
#
# New-game baseline slice:
# - reads authored start conditions from res://data/progression/new_game_start_conditions.json,
# - applies those values only when no save exists yet,
# - keeps runtime/save state separate from authored baseline content.

const GUILD_HALL_SCENE := preload("res://scenes/guild_hall/GuildHall.tscn")
const EXPEDITION_BOARD_SCENE := preload("res://scenes/expedition_board/ExpeditionBoard.tscn")
const DISPATCH_SCREEN_SCENE := preload("res://scenes/dispatch/DispatchScreen.tscn")
const EXPEDITION_REPORT_SCENE := preload("res://scenes/report/ExpeditionReport.tscn")
const GUILD_UPGRADES_SCENE := preload("res://scenes/upgrades/GuildUpgrades.tscn")
const CODEX_SCREEN_SCENE := preload("res://scenes/codex/CodexScreen.tscn")
const COMMISSION_BOARD_SCENE := preload("res://scenes/commissions/CommissionBoard.tscn")
const SUPPLY_BOARD_SCENE := preload("res://scenes/supply_runs/SupplyBoard.tscn")
const NEW_GAME_START_CONDITIONS_PATH := "res://data/progression/new_game_start_conditions.json"
const DEFAULT_NEW_GAME_START_CONDITIONS := {
	"schema_version": 1,
	"starting_resources": {
		"gold": 1000,
		"supplies": 10
	},
	"starting_crew": {
		"available": 20,
		"assigned": 0,
		"recovering": 0,
		"max": 50
	},
	"starting_slot_capacities": {
		"expedition": {
			"current_expedition_slot_capacity": 2,
			"max_expedition_slot_capacity": 3
		},
		"commission": {
			"current_commission_slot_capacity": 3,
			"max_commission_slot_capacity": 4
		},
		"supply_run": {
			"current_supply_run_slot_capacity": 2,
			"max_supply_run_slot_capacity": 3
		}
	}
}
const DEFAULT_RESOURCES := {
	# New-profile gold now comes from authored start-conditions JSON.
	# This dictionary remains the runtime shape used by save/load paths.
	"gold": 1000,
	"relic_fragments": 0,
	"codex_entries": 0
}

var _expedition_manager := ExpeditionManager.new()
var _upgrade_system := UpgradeSystem.new()
var _codex_system := CodexSystem.new()
var _region_system := RegionSystem.new()
var _commission_resolver := CommissionResolver.new()
var _commission_runtime_manager := CommissionRuntimeManager.new()
var _supply_board_controller := SupplyBoardController.new()
var _supply_run_runtime_manager := SupplyRunRuntimeManager.new()
var _save_manager := SaveManager.new()
var _new_game_start_conditions := DEFAULT_NEW_GAME_START_CONDITIONS.duplicate(true)
var _resources := DEFAULT_RESOURCES.duplicate(true)
var _slot_capacities: Dictionary = DEFAULT_NEW_GAME_START_CONDITIONS.get("starting_slot_capacities", {}).duplicate(true)
var _expedition_board_offers: Array[Dictionary] = []
var _commission_board_snapshot: Dictionary = {}
var _supply_board_snapshot: Dictionary = {}

var _guild_hall_controller: GuildHallController
var _expedition_board_controller: ExpeditionBoardController
var _dispatch_controller: DispatchController
var _report_controller: ReportController
var _upgrades_controller: UpgradesController
var _codex_controller: CodexController
var _commission_board_controller: CommissionBoardScreenController
var _supply_board_screen_controller: SupplyBoardScreenController
var _mounted_screen: Control
var _commission_tick_accumulator := 0.0
const COMMISSION_TICK_SECONDS := 1.0

@onready var _ui_root: Control = $CanvasLayer/UIRoot


func _ready() -> void:
	# Start conditions are authored content for fresh profiles only.
	_new_game_start_conditions = _load_new_game_start_conditions()
	_apply_new_game_start_conditions_baseline()
	_load_runtime_state()
	_show_guild_hall()
	set_process(true)


func _process(delta: float) -> void:
	# Lightweight runtime tick keeps commission timers and offline-like catch-up
	# behavior consistent even while the player stays on Guild Hall.
	_commission_tick_accumulator += delta
	if _commission_tick_accumulator < COMMISSION_TICK_SECONDS:
		return
	_commission_tick_accumulator = 0.0

	var state_changed := _process_commission_runtime_progress()
	var supply_state_changed := _process_supply_run_runtime_progress()
	if supply_state_changed:
		state_changed = true
	var recovered_now := _commission_resolver.process_crew_recovery()
	if recovered_now > 0:
		state_changed = true
	if state_changed:
		_save_runtime_state()
		_refresh_guild_hall_commission_and_resources()
		_refresh_supply_board_context()


func get_selected_expedition_for_activation() -> Dictionary:
	# Backward-compatible accessor while the runtime flow migrates to ExpeditionManager.
	return _expedition_manager.get_active_expedition()


func _show_guild_hall() -> void:
	if _guild_hall_controller == null:
		_guild_hall_controller = GUILD_HALL_SCENE.instantiate() as GuildHallController
		# Guild Hall no longer owns big cross-screen nav buttons.
		# Only report/debug actions are local; GH/EB/GU/CX routing is bottom-nav driven.
		_guild_hall_controller.open_report_requested.connect(_on_open_report_requested)
		_guild_hall_controller.navigate_requested.connect(_on_global_navigation_requested)
		_guild_hall_controller.debug_finish_requested.connect(_on_debug_finish_requested)
		_guild_hall_controller.debug_reset_requested.connect(_on_debug_reset_requested)
		_guild_hall_controller.commission_claim_requested.connect(_on_commission_claim_requested)
		_guild_hall_controller.supply_run_claim_requested.connect(_on_supply_run_claim_requested)

	_show_screen(_guild_hall_controller)
	_guild_hall_controller.set_expedition_manager(_expedition_manager)
	_guild_hall_controller.set_commission_runtime(
		_commission_runtime_manager,
		int(_slot_capacities.get("commission", {}).get("current_commission_slot_capacity", 0))
	)
	_guild_hall_controller.set_supply_run_runtime(
		_supply_run_runtime_manager,
		int(_slot_capacities.get("supply_run", {}).get("current_supply_run_slot_capacity", 0))
	)
	_guild_hall_controller.set_resources(_build_guild_hall_resources())


func _show_expedition_board() -> void:
	if _expedition_board_controller == null:
		_expedition_board_controller = EXPEDITION_BOARD_SCENE.instantiate() as ExpeditionBoardController
		_expedition_board_controller.expedition_dispatch_requested.connect(_on_expedition_dispatch_requested)
		_expedition_board_controller.return_to_guild_hall_requested.connect(_on_return_to_guild_hall_requested)
		_expedition_board_controller.navigate_requested.connect(_on_global_navigation_requested)
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
		_upgrades_controller.navigate_requested.connect(_on_global_navigation_requested)
		_upgrades_controller.purchase_requested.connect(_on_upgrade_purchase_requested)

	_show_screen(_upgrades_controller)
	_refresh_upgrades_view()


func _show_codex_screen() -> void:
	if _codex_controller == null:
		_codex_controller = CODEX_SCREEN_SCENE.instantiate() as CodexController
		_codex_controller.back_requested.connect(_on_codex_back_requested)
		_codex_controller.navigate_requested.connect(_on_global_navigation_requested)

	_show_screen(_codex_controller)
	# Codex screen reads a snapshot so it can render text without touching core state.
	_codex_controller.set_codex_data(
		_codex_system.get_total_discoveries(),
		_codex_system.get_discovered_entries()
	)


func _show_commission_board() -> void:
	if _commission_board_controller == null:
		_commission_board_controller = COMMISSION_BOARD_SCENE.instantiate() as CommissionBoardScreenController
		_commission_board_controller.navigate_requested.connect(_on_global_navigation_requested)
		_commission_board_controller.commission_dispatch_requested.connect(_on_commission_dispatch_requested)
		_commission_board_controller.set_initial_board_snapshot(_commission_board_snapshot)

	# Process ready recovery entries whenever players revisit this screen so crew
	# burden is visible but does not require a full app restart to clear.
	var recovered_now := _commission_resolver.process_crew_recovery()
	# Active rows are timed jobs already in progress and may become ready here.
	var state_changed := _process_commission_runtime_progress()
	if recovered_now > 0:
		state_changed = true
	if state_changed:
		_save_runtime_state()

	_commission_board_controller.set_board_context(
		_get_unlocked_region_ids_for_commissions(),
		_commission_resolver.get_available_crew(),
		_commission_resolver.get_supplies(),
		int(_resources.get("gold", 0)),
		_commission_resolver.get_assigned_crew(),
		_commission_resolver.get_recovering_crew(),
		_commission_resolver.get_max_crew()
	)
	_capture_commission_board_state()
	# Persist generated/restored board offers immediately so an app restart does
	# not reroll CommissionBoard entries the player just saw.
	_save_runtime_state()
	_show_screen(_commission_board_controller)


func _show_supply_board() -> void:
	if _supply_board_screen_controller == null:
		_supply_board_screen_controller = SUPPLY_BOARD_SCENE.instantiate() as SupplyBoardScreenController
		_supply_board_screen_controller.navigate_requested.connect(_on_global_navigation_requested)
		_supply_board_screen_controller.supply_dispatch_requested.connect(_on_supply_dispatch_requested)
	_ensure_supply_board_ready()
	_supply_board_screen_controller.set_supply_board_context(
		_supply_board_controller.get_visible_offers(),
		_commission_resolver.get_available_crew(),
		int(_resources.get("gold", 0)),
		_commission_resolver.get_supplies(),
		_supply_run_runtime_manager.get_active_slot_usage(),
		int(_slot_capacities.get("supply_run", {}).get("current_supply_run_slot_capacity", 0)),
		_commission_resolver.get_assigned_crew(),
		_commission_resolver.get_recovering_crew(),
		_commission_resolver.get_max_crew()
	)
	_show_screen(_supply_board_screen_controller)




func _claim_all_ready_commissions() -> Dictionary:
	# Claim every ready row and apply its pre-rolled completion payload.
	# This guarantees completion effects are actually granted once a run finishes.
	var claimed_count := 0
	var total_gold_payout := 0
	var ready_rows := _commission_runtime_manager.get_ready_to_claim_entries()
	for row in ready_rows:
		var runtime_id := int((row as Dictionary).get("runtime_id", 0))
		if runtime_id <= 0:
			continue

		var claimed := _commission_runtime_manager.claim_ready_entry(runtime_id)
		if claimed.is_empty():
			continue

		var completion_payload := claimed.get("completion_payload", {}) as Dictionary
		_commission_resolver.apply_completion_claim_rewards(completion_payload)
		var gold_payout := maxi(0, int(completion_payload.get("gold_payout", 0)))
		if gold_payout > 0:
			_resources["gold"] = int(_resources.get("gold", 0)) + gold_payout
			total_gold_payout += gold_payout
		claimed_count += 1

	return {
		"claimed_count": claimed_count,
		"total_gold_payout": total_gold_payout
	}


func _get_unlocked_region_ids_for_commissions() -> Array[String]:
	var ids: Array[String] = []
	for row in _region_system.get_region_list_for_ui():
		if not bool(row.get("is_visible", false)):
			continue
		if not bool(row.get("is_unlocked", false)):
			continue
		ids.append(str(row.get("id", "")))
	return ids

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


func _on_open_report_requested() -> void:
	_show_report_screen()


func _on_global_navigation_requested(target_screen: String) -> void:
	# Shared bottom-nav routes for GH/EB/GU/CX/CB + Supply Board (Logistics).
	# Only the far-right shop placeholder remains intentionally inert.
	match target_screen:
		BottomNavBar.TARGET_GUILD_HALL:
			_show_guild_hall()
		BottomNavBar.TARGET_EXPEDITION_BOARD:
			_show_expedition_board()
		BottomNavBar.TARGET_GUILD_UPGRADES:
			_show_upgrades_screen()
		BottomNavBar.TARGET_CODEX:
			_show_codex_screen()
		BottomNavBar.TARGET_COMMISSION_BOARD:
			_show_commission_board()
		BottomNavBar.TARGET_SUPPLY_BOARD:
			_show_supply_board()


func _on_debug_finish_requested() -> void:
	# Debug-complete reuses ExpeditionManager's real slot completion path.
	_expedition_manager.complete_all_active_expeditions_for_debug()
	# Debug helper now also force-completes in-progress commissions so QA can
	# verify active -> claimable transitions without waiting full durations.
	var forced_rows := _commission_runtime_manager.debug_finish_all_active()
	_apply_completion_crew_transition_for_rows(forced_rows)
	var forced_supply_rows := _supply_run_runtime_manager.debug_finish_all_active()
	_apply_supply_run_completion_rows(forced_supply_rows)
	# Persist immediately so force-completed slots/reports survive app restarts.
	_save_runtime_state()
	_refresh_guild_hall_commission_and_resources()
	if _expedition_manager.has_pending_report():
		_show_report_screen()


func _on_debug_reset_requested() -> void:
	reset_to_debug_baseline()


func reset_to_debug_baseline() -> void:
	# TEMPORARY DEBUG RESET:
	# This is a test-only helper that wipes prototype progression and runtime
	# state in one place to avoid partial resets across multiple scripts.
	# Debug baseline intentionally mirrors the authored new-game start values.
	_apply_new_game_start_conditions_baseline()
	# Commission economy state is runtime data and resets with debug baseline.

	# Clear progression systems back to fresh-start values.
	_upgrade_system.restore_owned_upgrade_ids([])
	_codex_system.restore_discoveries([])
	_region_system.restore_player_state({}, "")
	_expedition_manager.restore_runtime_state([], [])
	_commission_runtime_manager.restore_runtime_snapshot({})
	_supply_run_runtime_manager.restore_runtime_snapshot({})
	_supply_board_controller.clear_board()
	_expedition_board_offers = []
	_commission_board_snapshot = {}
	_supply_board_snapshot = {}
	_discard_expedition_board_controller()
	_discard_commission_board_controller()
	_discard_supply_board_controller()

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


func _discard_commission_board_controller() -> void:
	if _commission_board_controller == null:
		return
	if _mounted_screen == _commission_board_controller:
		_mounted_screen = null
	if _commission_board_controller.get_parent() != null:
		_commission_board_controller.get_parent().remove_child(_commission_board_controller)
	_commission_board_controller.queue_free()
	_commission_board_controller = null


func _discard_supply_board_controller() -> void:
	if _supply_board_screen_controller == null:
		return
	if _mounted_screen == _supply_board_screen_controller:
		_mounted_screen = null
	if _supply_board_screen_controller.get_parent() != null:
		_supply_board_screen_controller.get_parent().remove_child(_supply_board_screen_controller)
	_supply_board_screen_controller.queue_free()
	_supply_board_screen_controller = null


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


func _on_commission_dispatch_requested(offer_id: String, prep_tier_id: String, commitment: Dictionary, offer_snapshot: Dictionary) -> void:
	# Commission board offers and active commissioned runs are intentionally split:
	# - the board is just the offer surface,
	# - CommissionRuntimeManager owns dispatched rows over time.
	# This keeps timed runtime rows stable even if board offers reroll.
	var crew_cost := maxi(0, int(commitment.get("crew_commitment", 0)))
	var supplies_cost := maxi(0, int(commitment.get("supplies_commitment", 0)))
	var commission_capacity := int(_slot_capacities.get("commission", {}).get("current_commission_slot_capacity", 0))

	if not _commission_runtime_manager.can_start_commission(commission_capacity):
		# Slot-full failure stays separate from resource failure so the player can
		# understand whether to wait for completion vs gather more inputs.
		_commission_board_controller.handle_dispatch_result(
			false,
			offer_id,
			"Dispatch failed: no open Commission slot."
		)
		return

	if crew_cost > _commission_resolver.get_available_crew() or supplies_cost > _commission_resolver.get_supplies():
		# Resource failure messaging is intentionally distinct from slot-full.
		_commission_board_controller.handle_dispatch_result(
			false,
			offer_id,
			"Dispatch failed: insufficient Crew or Supplies."
		)
		return

	# No manual raw number entry in UI: these values are derived from prep tier.
	# Spend supplies first so a rare crew-commit failure can be cleanly refunded.
	var supplies_committed := _commission_resolver.spend_supplies(supplies_cost)
	var crew_committed := _commission_resolver.assign_crew_to_commission(crew_cost)
	if not supplies_committed or not crew_committed:
		if supplies_committed:
			_commission_resolver.add_supplies(supplies_cost)
		_commission_board_controller.handle_dispatch_result(
			false,
			offer_id,
			"Dispatch failed while committing resources."
		)
		return

	# Outcome values are rolled now and stored on the active row.
	# Dispatch no longer grants immediate gold; payout is deferred until a future
	# claim action, so we keep deterministic completion inputs on the runtime row.
	var completion_payload := _commission_resolver.roll_completion_payload(
		offer_snapshot,
		prep_tier_id,
		commitment
	)
	# Active timed entry creation happens here (runtime-state layer), not on board.
	# The board remains an offer surface while runtime rows represent live jobs.
	var active_row := _commission_runtime_manager.start_commission(
		offer_snapshot,
		prep_tier_id,
		commitment,
		completion_payload,
		commission_capacity
	)
	if active_row.is_empty():
		# Safety rollback if slot-state changed between checks.
		_commission_resolver.add_supplies(supplies_cost)
		_commission_resolver.move_assigned_crew_to_available(crew_cost)
		_commission_board_controller.handle_dispatch_result(false, offer_id, "Dispatch failed: no open Commission slot.")
		return

	_save_runtime_state()
	_commission_board_controller.set_board_context(
		_get_unlocked_region_ids_for_commissions(),
		_commission_resolver.get_available_crew(),
		_commission_resolver.get_supplies(),
		int(_resources.get("gold", 0)),
		_commission_resolver.get_assigned_crew(),
		_commission_resolver.get_recovering_crew(),
		_commission_resolver.get_max_crew()
	)
	_commission_board_controller.handle_dispatch_result(
		true,
		offer_id,
		"Dispatched. Active slots: %d/%d." % [
			_commission_runtime_manager.get_active_slot_usage(),
			commission_capacity
		]
	)
	_capture_commission_board_state()
	_save_runtime_state()


func _on_commission_claim_requested(runtime_id: int) -> void:
	# Compact claim flow entry from Guild Hall commission cards:
	# - process time first so any just-finished active rows can enter ready bucket,
	# - claim exactly one selected runtime row,
	# - apply completion payload and refresh Guild Hall resource labels.
	if runtime_id <= 0:
		return

	var newly_ready := _commission_runtime_manager.process_time_progress()
	if not newly_ready.is_empty():
		_apply_completion_crew_transition_for_rows(newly_ready)
	var claimed := _commission_runtime_manager.claim_ready_entry(runtime_id)
	if claimed.is_empty():
		# If the selected row was still active, status refresh is enough.
		_refresh_guild_hall_commission_and_resources()
		if not newly_ready.is_empty():
			_save_runtime_state()
		return

	var completion_payload := claimed.get("completion_payload", {}) as Dictionary
	if not bool(claimed.get("crew_transition_applied", false)):
		# Migration safety: legacy saves may contain ready rows created before
		# completion-time transitions existed, so apply once at claim.
		_commission_resolver.apply_completion_crew_transition(completion_payload)
	_commission_resolver.apply_completion_claim_rewards(completion_payload)
	var gold_payout := maxi(0, int(completion_payload.get("gold_payout", 0)))
	if gold_payout > 0:
		_resources["gold"] = int(_resources.get("gold", 0)) + gold_payout

	_save_runtime_state()
	_refresh_guild_hall_commission_and_resources()


func _on_supply_run_claim_requested(runtime_id: int) -> void:
	var result := claim_supply_run(runtime_id)
	_refresh_supply_board_context()
	if _supply_board_screen_controller != null and _mounted_screen == _supply_board_screen_controller:
		_supply_board_screen_controller.handle_dispatch_result(
			bool(result.get("success", false)),
			str(result.get("message", "")),
			_supply_board_controller.get_visible_offers()
		)


func _on_supply_dispatch_requested(offer_id: String) -> void:
	var result := try_dispatch_supply_run(offer_id)
	_refresh_supply_board_context()
	if _supply_board_screen_controller == null:
		return
	_supply_board_screen_controller.handle_dispatch_result(
		bool(result.get("success", false)),
		str(result.get("message", "")),
		_supply_board_controller.get_visible_offers()
	)


func try_dispatch_supply_run(offer_id: String) -> Dictionary:
	# Supply Board stays the offer surface while SupplyRunRuntimeManager owns
	# dispatched/claimable runtime rows. This keeps board rerolls from mutating
	# live timed entries and keeps save behavior explicit.
	var clean_offer_id := offer_id.strip_edges()
	if clean_offer_id.is_empty():
		return {"success": false, "message": "Dispatch failed: invalid offer id."}

	_ensure_supply_board_ready()
	var offer := _find_supply_offer_by_id(clean_offer_id)
	if offer.is_empty():
		return {"success": false, "message": "Dispatch failed: offer no longer available."}

	var supply_run_capacity := int(_slot_capacities.get("supply_run", {}).get("current_supply_run_slot_capacity", 0))
	if not _supply_run_runtime_manager.can_start_supply_run(supply_run_capacity):
		return {"success": false, "message": "Dispatch failed: no open Supply Run slot."}

	var crew_cost := maxi(0, int(offer.get("crew_required", 0)))
	var gold_cost := maxi(0, int(offer.get("gold_cost", 0)))
	if crew_cost > _commission_resolver.get_available_crew():
		return {"success": false, "message": "Dispatch failed: insufficient Crew."}
	if gold_cost > int(_resources.get("gold", 0)):
		return {"success": false, "message": "Dispatch failed: insufficient Gold."}

	# Locked rule for this milestone:
	# Supply Runs never spend Supplies on dispatch.
	var crew_committed := _commission_resolver.assign_crew_to_commission(crew_cost)
	if not crew_committed:
		return {"success": false, "message": "Dispatch failed while committing Crew."}
	_resources["gold"] = maxi(0, int(_resources.get("gold", 0)) - gold_cost)

	var active_row := _supply_run_runtime_manager.start_supply_run(offer, supply_run_capacity)
	if active_row.is_empty():
		# Safety rollback if slot state changed between pre-check and commit.
		_commission_resolver.move_assigned_crew_to_available(crew_cost)
		_resources["gold"] = int(_resources.get("gold", 0)) + gold_cost
		return {"success": false, "message": "Dispatch failed: no open Supply Run slot."}

	# Successful dispatch consumes the offer immediately and refills that slot.
	# This preserves board-offer behavior while active rows live elsewhere.
	_safely_accept_supply_offer(clean_offer_id)
	_capture_supply_board_state()
	_save_runtime_state()
	_refresh_guild_hall_commission_and_resources()
	return {
		"success": true,
		"message": "Supply Run dispatched.",
		"active_entry": active_row,
		"active_slot_usage": _supply_run_runtime_manager.get_active_slot_usage(),
		"slot_capacity": supply_run_capacity
	}


func claim_supply_run(runtime_id: int) -> Dictionary:
	if runtime_id <= 0:
		return {"success": false, "message": "Claim failed: invalid runtime id."}
	var state_changed := false
	var newly_ready := _supply_run_runtime_manager.process_time_progress()
	if not newly_ready.is_empty():
		# Completion processing runs before claim so timers can free active slots
		# and return crew as soon as runs finish, including offline catch-up.
		_apply_supply_run_completion_rows(newly_ready)
		state_changed = true

	var claimed := _supply_run_runtime_manager.claim_ready_entry(runtime_id)
	if claimed.is_empty():
		# Stale-id safety:
		# even if this specific runtime_id is not claimable, processing above may
		# have promoted other rows and returned crew. Persist + refresh now so
		# those changes are not delayed until an unrelated future save tick.
		if state_changed:
			_save_runtime_state()
			_refresh_guild_hall_commission_and_resources()
		return {"success": false, "message": "Claim failed: run is not ready."}

	var payload := claimed.get("completion_payload", {}) as Dictionary
	if not bool(claimed.get("crew_return_applied", false)):
		# Migration safety: if an old ready row exists without completion-side
		# crew return, apply it once now so v1 state remains consistent.
		var legacy_crew_committed := maxi(0, int(claimed.get("crew_committed", 0)))
		if legacy_crew_committed > 0:
			_commission_resolver.move_assigned_crew_to_available(legacy_crew_committed)
		state_changed = true
	var supplies_payout := maxi(0, int(payload.get("supplies_payout", 0)))
	if supplies_payout > 0:
		_commission_resolver.add_supplies(supplies_payout)

	_save_runtime_state()
	_refresh_guild_hall_commission_and_resources()
	return {
		"success": true,
		"message": "Supplies claimed.",
		"supplies_payout": supplies_payout
	}


func _load_runtime_state() -> void:
	# Load flow: authored start conditions are already applied as baseline;
	# saved runtime state overrides them when a save exists.
	var save_data := _save_manager.load_game_state()
	if save_data.is_empty():
		# No save present => keep authored new-game baseline values.
		return

	# Missing keys are safe: each system uses default fallback values.
	_resources = _sanitize_resources(save_data.get("resources", {}))
	_commission_resolver.restore_runtime_snapshot(save_data.get("commission_resources", {}))
	_commission_runtime_manager.restore_runtime_snapshot(save_data.get("commission_runtime", {}))
	_supply_run_runtime_manager.restore_runtime_snapshot(save_data.get("supply_run_runtime", {}))
	_slot_capacities = _sanitize_slot_capacities(save_data.get("slot_capacities", {}))
	# Process delayed crew recovery on load so offline time can be honored later.
	var recovered_now := _commission_resolver.process_crew_recovery()
	var runtime_changed := _process_commission_runtime_progress()
	var supply_runtime_changed := _process_supply_run_runtime_progress()
	if supply_runtime_changed:
		runtime_changed = true
	if recovered_now > 0:
		runtime_changed = true
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
	_commission_board_snapshot = _sanitize_board_snapshot(save_data.get("commission_board_snapshot", {}))
	_supply_board_snapshot = _sanitize_board_snapshot(save_data.get("supply_board_snapshot", {}))
	_restore_supply_board_state()
	if runtime_changed:
		# Save post-load migration/catch-up so offline-finished commissions and
		# crew transitions persist immediately.
		_save_runtime_state()


func _save_runtime_state() -> void:
	# Save flow: capture a snapshot from owner systems and write plain JSON.
	_save_manager.save_game_state({
		"resources": _resources,
		"commission_resources": _commission_resolver.build_runtime_snapshot(),
		"commission_runtime": _commission_runtime_manager.build_runtime_snapshot(),
		"supply_run_runtime": _supply_run_runtime_manager.build_runtime_snapshot(),
		"slot_capacities": _slot_capacities,
		"owned_upgrades": _upgrade_system.get_owned_upgrade_ids(),
		"codex_discoveries": _codex_system.get_discovered_entries(),
		"region_progress": _region_system.build_save_progress_snapshot(),
		"selected_region_id": _region_system.get_selected_region_id(),
		"active_expeditions": _expedition_manager.get_active_expeditions(),
		"pending_reports": _expedition_manager.get_pending_reports(),
		"expedition_board_offers": _expedition_board_offers,
		"commission_board_snapshot": _commission_board_snapshot,
		"supply_board_snapshot": _supply_board_snapshot
	})


func _sanitize_resources(value: Variant) -> Dictionary:
	var source := value as Dictionary if value is Dictionary else {}
	return {
		# Clamp to 0 so malformed saves cannot create confusing negative totals.
		"gold": maxi(0, int(source.get("gold", int(_resources.get("gold", 0))))),
		"relic_fragments": maxi(0, int(source.get("relic_fragments", int(_resources.get("relic_fragments", 0))))),
		"codex_entries": maxi(0, int(source.get("codex_entries", int(_resources.get("codex_entries", 0)))))
	}


func _load_new_game_start_conditions() -> Dictionary:
	# This file is authored balancing data for *new game setup only*.
	# Runtime and save progress stay in save JSON, not here.
	if not FileAccess.file_exists(NEW_GAME_START_CONDITIONS_PATH):
		push_warning("GameManager: new-game start conditions file missing; using fallback defaults.")
		return DEFAULT_NEW_GAME_START_CONDITIONS.duplicate(true)

	var file := FileAccess.open(NEW_GAME_START_CONDITIONS_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameManager: failed to open start conditions file; using fallback defaults.")
		return DEFAULT_NEW_GAME_START_CONDITIONS.duplicate(true)

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_warning("GameManager: start conditions JSON must be a dictionary; using fallback defaults.")
		return DEFAULT_NEW_GAME_START_CONDITIONS.duplicate(true)

	return _sanitize_new_game_start_conditions(parsed as Dictionary)


func _sanitize_new_game_start_conditions(value: Dictionary) -> Dictionary:
	var resources := value.get("starting_resources", {}) as Dictionary
	var crew := value.get("starting_crew", {}) as Dictionary
	var slot_capacities := _sanitize_slot_capacities(value.get("starting_slot_capacities", {}))
	return {
		"schema_version": int(value.get("schema_version", 1)),
		"starting_resources": {
			"gold": maxi(0, int(resources.get("gold", 1000))),
			"supplies": maxi(0, int(resources.get("supplies", 10)))
		},
		"starting_crew": {
			"available": maxi(0, int(crew.get("available", 20))),
			"assigned": maxi(0, int(crew.get("assigned", 0))),
			"recovering": maxi(0, int(crew.get("recovering", 0))),
			"max": maxi(0, int(crew.get("max", 50)))
		},
		"starting_slot_capacities": slot_capacities
	}


func _apply_new_game_start_conditions_baseline() -> void:
	var resources := _new_game_start_conditions.get("starting_resources", {}) as Dictionary
	var crew := _new_game_start_conditions.get("starting_crew", {}) as Dictionary
	_resources = {
		"gold": maxi(0, int(resources.get("gold", 1000))),
		"relic_fragments": 0,
		"codex_entries": 0
	}
	_commission_resolver.restore_runtime_snapshot({
		"max_crew": maxi(0, int(crew.get("max", 50))),
		"available_crew": maxi(0, int(crew.get("available", 20))),
		"assigned_crew": maxi(0, int(crew.get("assigned", 0))),
		"recovering_crew": maxi(0, int(crew.get("recovering", 0))),
		# Keep authored new-game availability as-is instead of auto-filling
		# to max_crew; this preserves intended early-game pacing.
		"preserve_sparse_crew_state": true,
		"supplies": maxi(0, int(resources.get("supplies", 10))),
		"standing": 0,
		"crew_recovery_entries": []
	})
	# Slot-capacity ownership is runtime/save state; the authored file only seeds
	# fresh profiles and is never written back at runtime.
	_slot_capacities = _sanitize_slot_capacities(_new_game_start_conditions.get("starting_slot_capacities", {}))


func _sanitize_slot_capacities(value: Variant) -> Dictionary:
	# Migration-safe sanitize path for both authored start data and save data.
	var source := value as Dictionary if value is Dictionary else {}
	var expedition := source.get("expedition", {}) as Dictionary
	var commission := source.get("commission", {}) as Dictionary
	var supply_run := source.get("supply_run", {}) as Dictionary
	var expedition_current := maxi(0, int(expedition.get("current_expedition_slot_capacity", int(_slot_capacities.get("expedition", {}).get("current_expedition_slot_capacity", 2)))))
	var expedition_max := maxi(expedition_current, int(expedition.get("max_expedition_slot_capacity", int(_slot_capacities.get("expedition", {}).get("max_expedition_slot_capacity", 3)))))
	var commission_current := maxi(0, int(commission.get("current_commission_slot_capacity", int(_slot_capacities.get("commission", {}).get("current_commission_slot_capacity", 3)))))
	var commission_max := maxi(commission_current, int(commission.get("max_commission_slot_capacity", int(_slot_capacities.get("commission", {}).get("max_commission_slot_capacity", 4)))))
	var supply_run_current := maxi(0, int(supply_run.get("current_supply_run_slot_capacity", int(_slot_capacities.get("supply_run", {}).get("current_supply_run_slot_capacity", 2)))))
	var supply_run_max := maxi(supply_run_current, int(supply_run.get("max_supply_run_slot_capacity", int(_slot_capacities.get("supply_run", {}).get("max_supply_run_slot_capacity", 3)))))

	return {
		"expedition": {
			"current_expedition_slot_capacity": expedition_current,
			"max_expedition_slot_capacity": expedition_max
		},
		"commission": {
			"current_commission_slot_capacity": commission_current,
			"max_commission_slot_capacity": commission_max
		},
		"supply_run": {
			"current_supply_run_slot_capacity": supply_run_current,
			"max_supply_run_slot_capacity": supply_run_max
		}
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


func _sanitize_board_snapshot(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _capture_expedition_board_state() -> void:
	if _expedition_board_controller == null:
		return
	_expedition_board_offers = _expedition_board_controller.get_board_offers()


func _capture_commission_board_state() -> void:
	if _commission_board_controller == null:
		return
	_commission_board_snapshot = _commission_board_controller.build_board_snapshot()


func _capture_supply_board_state() -> void:
	_supply_board_snapshot = _supply_board_controller.build_save_snapshot()


func _restore_supply_board_state() -> void:
	if _supply_board_snapshot.is_empty():
		return
	_supply_board_controller.restore_from_save(_supply_board_snapshot, _get_unlocked_regions_for_supply_runs())
	_capture_supply_board_state()


func _ensure_supply_board_ready() -> void:
	if _supply_board_controller.get_visible_offers().is_empty():
		_supply_board_controller.generate_board_for_regions(_get_unlocked_regions_for_supply_runs())
		_capture_supply_board_state()


func _find_supply_offer_by_id(offer_id: String) -> Dictionary:
	for offer in _supply_board_controller.get_visible_offers():
		var row := offer as Dictionary
		if str(row.get("offer_id", "")) == offer_id:
			return row.duplicate(true)
	return {}


func _safely_accept_supply_offer(offer_id: String) -> void:
	_supply_board_controller.accept_offer(offer_id, _get_unlocked_regions_for_supply_runs())


func _process_commission_runtime_progress(now_unix: int = -1) -> bool:
	# Runtime-loop v1 completion processing:
	# - move finished commissions from active -> ready-to-claim,
	# - free active slots before claim so board capacity updates immediately,
	# - move committed crew from Assigned -> Recovering on completion.
	#
	# Offline-safe behavior: this helper is called on load and regular runtime
	# ticks, so any elapsed wall-clock time can promote overdue entries.
	var promoted_rows := _commission_runtime_manager.process_time_progress(now_unix)
	if promoted_rows.is_empty():
		return false
	_apply_completion_crew_transition_for_rows(promoted_rows)
	return true


func _process_supply_run_runtime_progress(now_unix: int = -1) -> bool:
	# Supply Run completion side effect is intentionally light in v1:
	# when a run finishes, committed crew returns directly to Available.
	# Offline-safe note: this helper is called both during live ticks and load
	# catch-up, so overdue runs are promoted without requiring manual waits.
	var promoted_rows := _supply_run_runtime_manager.process_time_progress(now_unix)
	if promoted_rows.is_empty():
		return false
	_apply_supply_run_completion_rows(promoted_rows)
	return true


func _apply_supply_run_completion_rows(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var transitioned_runtime_ids: Array[int] = []
	for row in rows:
		var crew_committed := maxi(0, int((row as Dictionary).get("crew_committed", 0)))
		if crew_committed > 0:
			# v1 simplification: Supply Runs skip the deeper recovery model and send
			# committed crew directly back to Available on completion.
			_commission_resolver.move_assigned_crew_to_available(crew_committed)
		transitioned_runtime_ids.append(int((row as Dictionary).get("runtime_id", 0)))
	_supply_run_runtime_manager.mark_ready_entries_crew_return_applied(transitioned_runtime_ids)


func _apply_completion_crew_transition_for_rows(rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var transitioned_runtime_ids: Array[int] = []
	for row in rows:
		var payload := row.get("completion_payload", {}) as Dictionary
		_commission_resolver.apply_completion_crew_transition(payload)
		transitioned_runtime_ids.append(int(row.get("runtime_id", 0)))
	_commission_runtime_manager.mark_ready_entries_crew_transition_applied(transitioned_runtime_ids)


func _refresh_guild_hall_commission_and_resources() -> void:
	# Guild Hall cards are a projection of runtime commission buckets:
	# empty / active / complete states are rebuilt from manager data each refresh.
	if _guild_hall_controller == null:
		return
	_guild_hall_controller.set_resources(_build_guild_hall_resources())
	_guild_hall_controller.set_commission_runtime(
		_commission_runtime_manager,
		int(_slot_capacities.get("commission", {}).get("current_commission_slot_capacity", 0))
	)
	_guild_hall_controller.set_supply_run_runtime(
		_supply_run_runtime_manager,
		int(_slot_capacities.get("supply_run", {}).get("current_supply_run_slot_capacity", 0))
	)


func _refresh_supply_board_context() -> void:
	if _supply_board_screen_controller == null:
		return
	_supply_board_screen_controller.set_supply_board_context(
		_supply_board_controller.get_visible_offers(),
		_commission_resolver.get_available_crew(),
		int(_resources.get("gold", 0)),
		_commission_resolver.get_supplies(),
		_supply_run_runtime_manager.get_active_slot_usage(),
		int(_slot_capacities.get("supply_run", {}).get("current_supply_run_slot_capacity", 0)),
		_commission_resolver.get_assigned_crew(),
		_commission_resolver.get_recovering_crew(),
		_commission_resolver.get_max_crew()
	)


func _get_unlocked_regions_for_supply_runs() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for region in _region_system.get_region_list_for_ui():
		if not bool((region as Dictionary).get("is_visible", false)):
			continue
		if not bool((region as Dictionary).get("is_unlocked", false)):
			continue
		rows.append({
			"id": str((region as Dictionary).get("id", "")),
			"name": str((region as Dictionary).get("name", "Unknown Region"))
		})
	return rows


func _on_region_selected(region_id: String) -> void:
	# Region selection state is owned by RegionSystem and persisted in saves.
	if not _region_system.set_selected_region(region_id):
		return
	if _expedition_board_controller != null:
		# Re-send region context so the board can swap to that region's cached
		# session offers (or generate once if this is first visit for that region).
		_expedition_board_controller.set_region_data(
			_region_system.get_region_list_for_ui(),
			_region_system.get_generation_rules_for_selected_region()
		)
		_capture_expedition_board_state()
	_save_runtime_state()


func _on_codex_back_requested() -> void:
	_show_guild_hall()


func _build_guild_hall_resources() -> Dictionary:
	# Guild Hall top row mixes shared progression (gold) with commission runtime
	# state (crew/supplies), so this helper builds one UI-friendly snapshot.
	var view := _resources.duplicate(true)
	view["available_crew"] = _commission_resolver.get_available_crew()
	view["assigned_crew"] = _commission_resolver.get_assigned_crew()
	view["recovering_crew"] = _commission_resolver.get_recovering_crew()
	view["max_crew"] = _commission_resolver.get_max_crew()
	view["supplies"] = _commission_resolver.get_supplies()
	return view


func _notification(what: int) -> void:
	# Save when the app exits so prototype testing survives restarts.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save_runtime_state()
