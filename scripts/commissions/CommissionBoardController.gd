extends Node
class_name CommissionBoardController

# -----------------------------------------------------------------------------
# CommissionBoardController
# -----------------------------------------------------------------------------
# Purpose:
# - Own runtime board state for visible commission offers.
# - Keep board size finite (default 3 from authored board rules/config).
# - Persist standard offers until accepted or manual refresh.
#
# Runtime-only state here is intentionally separate from authored JSON content.
# This is save/load-friendly because the controller can export/import snapshots.
# -----------------------------------------------------------------------------

var _loader := CommissionDataLoader.new()
var _generator := CommissionGenerator.new()

var _commission_data: Dictionary = {}
var _visible_offers: Array[Dictionary] = []
var _visible_offer_count := 3
var _authored_data_loaded := false


func _init() -> void:
	# This controller is frequently used as a plain object via .new() (not as a
	# scene-tree node), so authored data must load during construction.
	load_authored_data()


func load_authored_data() -> void:
	_commission_data = _loader.load_commission_data()
	_generator.set_commission_data(_commission_data)

	var board_rules := _commission_data.get("board_rules", {}) as Dictionary
	var generated_count := int((_commission_data.get("generation_config", {}) as Dictionary).get("starting_board", {}).get("visible_offer_count", 3))
	_visible_offer_count = maxi(1, int(board_rules.get("visible_offer_count", generated_count)))
	_authored_data_loaded = true


func _ensure_authored_data_loaded() -> void:
	if _authored_data_loaded:
		return
	load_authored_data()


func generate_board_for_regions(unlocked_region_ids: Array[String]) -> Array[Dictionary]:
	_ensure_authored_data_loaded()
	# Standard offers persist by default, so generation only fills missing slots.
	_visible_offers = _generator.generate_board(unlocked_region_ids, _visible_offers, _visible_offer_count)
	return get_visible_offers()


func refresh_board_for_regions(unlocked_region_ids: Array[String]) -> Array[Dictionary]:
	_ensure_authored_data_loaded()
	# Full reroll endpoint for future "refresh board" actions.
	_visible_offers = _generator.generate_board(unlocked_region_ids, [], _visible_offer_count)
	return get_visible_offers()


func accept_offer(offer_id: String, unlocked_region_ids: Array[String]) -> Dictionary:
	_ensure_authored_data_loaded()
	# Accept flow removes the selected slot and refills one slot using current
	# unlocked regions. This keeps board continuity without expirations.
	var accepted: Dictionary = {}
	var remaining: Array[Dictionary] = []
	for offer in _visible_offers:
		var row := offer as Dictionary
		if accepted.is_empty() and str(row.get("offer_id", "")) == offer_id:
			accepted = row.duplicate(true)
			continue
		remaining.append(row.duplicate(true))
	_visible_offers = remaining

	if accepted.is_empty():
		return {}

	if _visible_offers.size() < _visible_offer_count:
		var single := _generator.generate_single_offer(unlocked_region_ids, _visible_offers)
		if not single.is_empty():
			_visible_offers.append(single)

	return accepted


func get_visible_offers() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for offer in _visible_offers:
		output.append((offer as Dictionary).duplicate(true))
	return output


func clear_board() -> void:
	_visible_offers = []


func build_save_snapshot() -> Dictionary:
	# Save only runtime board state. Authored content stays on disk in data/*.json.
	return {
		"visible_offer_count": _visible_offer_count,
		"visible_offers": get_visible_offers()
	}


func restore_from_save(snapshot: Dictionary, unlocked_region_ids: Array[String]) -> void:
	_visible_offer_count = maxi(1, int(snapshot.get("visible_offer_count", _visible_offer_count)))
	_visible_offers = []
	var saved_offers: Variant = snapshot.get("visible_offers", [])
	if saved_offers is Array:
		for offer in saved_offers:
			if not (offer is Dictionary):
				continue
			var row := offer as Dictionary
			# Hard region rule still applies on restore: discard stale offers for
			# regions that are no longer currently reachable.
			if unlocked_region_ids.has(str(row.get("region_id", ""))):
				_visible_offers.append(row.duplicate(true))

	generate_board_for_regions(unlocked_region_ids)
