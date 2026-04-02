extends RefCounted
class_name SaveManager

# SaveManager handles plain-JSON persistence for this prototype.
# For the region-foundation milestone it now stores:
# - authored-state references (selected_region_id),
# - player-owned per-region progress (region_progress),
# - commission runtime resources (Crew pools + Supplies),
# - runtime slot-capacity ownership state (current/max for expedition/commission),
# while keeping previous keys for expedition loop persistence.

const SAVE_PATH := "user://prototype_save.json"
const SAVE_SCHEMA_VERSION := 4


func load_game_state() -> Dictionary:
	# Load flow: if the file is missing or malformed, return an empty dictionary.
	# Callers treat empty data as "start from defaults" for safe prototype behavior.
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: failed to open save file for read.")
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		push_warning("SaveManager: save JSON parse failed; ignoring save file.")
		return {}

	var data: Variant = json.data
	if not (data is Dictionary):
		push_warning("SaveManager: save root is not a dictionary; ignoring save file.")
		return {}

	return (data as Dictionary).duplicate(true)


func save_game_state(state: Dictionary) -> bool:
	# Write flow: sanitize input into one readable dictionary and overwrite file.
	# This keeps the format straightforward and avoids hidden binary serialization.
	var payload := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"resources": _coerce_resources(state.get("resources", {})),
		"commission_resources": _coerce_commission_resources(state.get("commission_resources", {})),
		"slot_capacities": _coerce_slot_capacities(state.get("slot_capacities", {})),
		"owned_upgrades": _coerce_string_array(state.get("owned_upgrades", [])),
		"codex_discoveries": _coerce_string_array(state.get("codex_discoveries", [])),
		"region_progress": _coerce_dictionary_of_dictionaries(state.get("region_progress", {})),
		"selected_region_id": str(state.get("selected_region_id", "")),
		"active_expeditions": _coerce_dictionary_array(state.get("active_expeditions", [])),
		"pending_reports": _coerce_dictionary_array(state.get("pending_reports", [])),
		"expedition_board_offers": _coerce_dictionary_array(state.get("expedition_board_offers", []))
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: failed to open save file for write.")
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func clear_saved_game_state() -> bool:
	# Debug reset path: deleting the file avoids stale keys and forces defaults
	# on the next load. Missing files are treated as already-cleared.
	if not FileAccess.file_exists(SAVE_PATH):
		return true

	var save_dir := DirAccess.open("user://")
	if save_dir == null:
		push_warning("SaveManager: failed to open user:// during debug reset.")
		return false

	var result := save_dir.remove("prototype_save.json")
	if result != OK:
		push_warning("SaveManager: failed to remove save file during debug reset.")
		return false

	return true


func _coerce_resources(value: Variant) -> Dictionary:
	var source := _coerce_dictionary(value)
	return {
		"gold": int(source.get("gold", 0)),
		"relic_fragments": int(source.get("relic_fragments", 0)),
		"codex_entries": int(source.get("codex_entries", 0))
	}


func _coerce_commission_resources(value: Variant) -> Dictionary:
	# Commission resources are runtime/player state, not authored commission JSON.
	var source := _coerce_dictionary(value)
	var max_crew := maxi(0, int(source.get("max_crew", 10)))
	var assigned_crew := maxi(0, int(source.get("assigned_crew", 0)))
	var recovering_crew := maxi(0, int(source.get("recovering_crew", 0)))
	var available_crew := maxi(0, int(source.get("available_crew", max_crew - assigned_crew - recovering_crew)))
	var entries := _coerce_dictionary_array(source.get("crew_recovery_entries", []))

	return {
		"max_crew": max_crew,
		"available_crew": available_crew,
		"assigned_crew": assigned_crew,
		"recovering_crew": recovering_crew,
		# Supplies v1 intentionally stays one single resource bucket.
		"supplies": maxi(0, int(source.get("supplies", 50))),
		# Standing scaffold is runtime progress, kept outside authored JSON.
		"standing": int(source.get("standing", 0)),
		# Keep entries serializable now so later offline/passive recovery can read them.
		"crew_recovery_entries": entries
	}


func _coerce_slot_capacities(value: Variant) -> Dictionary:
	# Slot capacities are runtime/player progression state and are persisted in
	# saves. Authored JSON only supplies brand-new profile baselines.
	var source := _coerce_dictionary(value)
	var expedition := _coerce_dictionary(source.get("expedition", {}))
	var commission := _coerce_dictionary(source.get("commission", {}))
	var expedition_current := maxi(0, int(expedition.get("current_expedition_slot_capacity", 2)))
	var expedition_max := maxi(expedition_current, int(expedition.get("max_expedition_slot_capacity", 3)))
	var commission_current := maxi(0, int(commission.get("current_commission_slot_capacity", 3)))
	var commission_max := maxi(commission_current, int(commission.get("max_commission_slot_capacity", 4)))

	return {
		"expedition": {
			"current_expedition_slot_capacity": expedition_current,
			"max_expedition_slot_capacity": expedition_max
		},
		"commission": {
			"current_commission_slot_capacity": commission_current,
			"max_commission_slot_capacity": commission_max
		}
	}


func _coerce_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text.is_empty():
				continue
			if output.has(text):
				continue
			output.append(text)
	return output


func _coerce_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _coerce_dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not (value is Array):
		return output

	for item in value:
		if not (item is Dictionary):
			continue
		output.append((item as Dictionary).duplicate(true))
	return output


func _coerce_dictionary_of_dictionaries(value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not (value is Dictionary):
		return output
	for key in (value as Dictionary).keys():
		var region_id := str(key).strip_edges()
		if region_id.is_empty():
			continue
		var row: Variant = (value as Dictionary).get(key, {})
		if not (row is Dictionary):
			continue
		output[region_id] = (row as Dictionary).duplicate(true)
	return output
