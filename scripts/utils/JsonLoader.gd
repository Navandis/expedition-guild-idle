extends RefCounted
class_name JsonLoader


func load_array(path: String, required_keys: Array[String], fallback: Array) -> Array:
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback.duplicate(true)

	var raw_text := file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_ARRAY:
		return fallback.duplicate(true)

	var valid_entries: Array = []
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if _has_required_keys(entry, required_keys):
			valid_entries.append(entry)

	if valid_entries.is_empty():
		return fallback.duplicate(true)

	return valid_entries


func _has_required_keys(entry: Dictionary, required_keys: Array[String]) -> bool:
	for key in required_keys:
		if not entry.has(key):
			return false
	return true
