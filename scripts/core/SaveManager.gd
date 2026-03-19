extends RefCounted
class_name SaveManager

# SaveManager provides plain-JSON persistence for the day-3 prototype milestone.
# It stores core runtime progress (resources, upgrades, codex, expedition state)
# so restart testing is practical while systems are still intentionally simple.

const SAVE_PATH := "user://prototype_save.json"
const SAVE_SCHEMA_VERSION := 1


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
		"owned_upgrades": _coerce_string_array(state.get("owned_upgrades", [])),
		"codex_discoveries": _coerce_string_array(state.get("codex_discoveries", [])),
		"active_expedition": _coerce_dictionary(state.get("active_expedition", {})),
		"pending_report": _coerce_dictionary(state.get("pending_report", {}))
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: failed to open save file for write.")
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _coerce_resources(value: Variant) -> Dictionary:
	var source := _coerce_dictionary(value)
	return {
		"gold": int(source.get("gold", 0)),
		"relic_fragments": int(source.get("relic_fragments", 0)),
		"codex_entries": int(source.get("codex_entries", 0))
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
