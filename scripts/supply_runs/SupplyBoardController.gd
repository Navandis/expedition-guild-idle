extends Node
class_name SupplyBoardController

# -----------------------------------------------------------------------------
# SupplyBoardController
# -----------------------------------------------------------------------------
# Purpose:
# - Own runtime Supply Board state for visible offer cards.
# - Keep board finite (default 3 visible offers from authored board rules).
# - Keep standard offers persistent until accepted or explicit refresh.
#
# Supply Runs remain separate from commissions to preserve a dedicated
# provisioning lane (supplies generation) with its own board logic.
# -----------------------------------------------------------------------------

var _loader := SupplyRunDataLoader.new()
var _generator := SupplyRunGenerator.new()

var _supply_data: Dictionary = {}
var _visible_offers: Array[Dictionary] = []
var _visible_offer_count := 3
var _authored_data_loaded := false


func _init() -> void:
	# This controller is often used as a plain object via .new(), so authored
	# data is loaded in constructor rather than waiting for _ready().
	load_authored_data()


func load_authored_data() -> void:
	_supply_data = _loader.load_supply_run_data()
	_generator.set_supply_run_data(_supply_data)

	var board_rules := _supply_data.get("board_rules", {}) as Dictionary
	_visible_offer_count = maxi(1, int(board_rules.get("visible_offer_count", 3)))
	_authored_data_loaded = true


func _ensure_authored_data_loaded() -> void:
	if _authored_data_loaded:
		return
	load_authored_data()


func generate_board_for_regions(unlocked_regions: Array[Dictionary]) -> Array[Dictionary]:
	_ensure_authored_data_loaded()
	# Hard rule: only currently unlocked/serviceable regions can produce offers.
	# This avoids showing runs the player cannot actually launch.
	_visible_offers = _generator.generate_board(unlocked_regions, _visible_offers, _visible_offer_count)
	return get_visible_offers()


func refresh_board_for_regions(unlocked_regions: Array[Dictionary]) -> Array[Dictionary]:
	_ensure_authored_data_loaded()
	# Explicit full reroll endpoint for later UI actions (manual refresh button).
	_visible_offers = _generator.generate_board(unlocked_regions, [], _visible_offer_count)
	return get_visible_offers()


func accept_offer(offer_id: String, unlocked_regions: Array[Dictionary]) -> Dictionary:
	_ensure_authored_data_loaded()
	var accepted: Dictionary = {}
	var accepted_index := -1
	for i in range(_visible_offers.size()):
		var row := _visible_offers[i] as Dictionary
		if str(row.get("offer_id", "")) == offer_id:
			accepted = row.duplicate(true)
			accepted_index = i
			break

	if accepted.is_empty():
		return {}

	# Preserve slot identity and replace only the accepted slot.
	# This keeps finite board readability stable while still refilling quickly.
	var board_without_accepted: Array[Dictionary] = []
	for i in range(_visible_offers.size()):
		if i == accepted_index:
			continue
		board_without_accepted.append((_visible_offers[i] as Dictionary).duplicate(true))

	var replacement := _generator.generate_single_offer(unlocked_regions, board_without_accepted)
	if replacement.is_empty():
		_visible_offers.remove_at(accepted_index)
	else:
		_visible_offers[accepted_index] = replacement

	return accepted


func get_visible_offers() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for offer in _visible_offers:
		output.append((offer as Dictionary).duplicate(true))
	return output


func clear_board() -> void:
	_visible_offers = []


func build_save_snapshot() -> Dictionary:
	# Runtime-only board payload. Authored data remains on disk in data/supply_runs.
	return {
		"visible_offer_count": _visible_offer_count,
		"visible_offers": get_visible_offers()
	}


func restore_from_save(snapshot: Dictionary, unlocked_regions: Array[Dictionary]) -> void:
	_visible_offer_count = maxi(1, int(snapshot.get("visible_offer_count", _visible_offer_count)))
	_visible_offers = []

	var unlocked_ids: Array[String] = []
	for region in unlocked_regions:
		unlocked_ids.append(str((region as Dictionary).get("id", "")))

	var saved_offers: Variant = snapshot.get("visible_offers", [])
	if saved_offers is Array:
		for offer in saved_offers:
			if not (offer is Dictionary):
				continue
			var row := offer as Dictionary
			if unlocked_ids.has(str(row.get("region_id", ""))):
				_visible_offers.append(row.duplicate(true))

	generate_board_for_regions(unlocked_regions)
