extends RefCounted
class_name JsonLoader

# -----------------------------------------------------------------------------
# JsonLoader
# -----------------------------------------------------------------------------
# Purpose:
# - Central helper for safely loading JSON arrays from disk.
# - Protects callers from malformed files by always returning valid data.
#
# Design choice:
# - This loader is "fail-safe": whenever validation fails at any step, it
#   returns a deep-duplicated fallback array instead of throwing.
# - This keeps game boot/runtime robust even if user data or content files are
#   missing, corrupted, or partially incorrect.
# -----------------------------------------------------------------------------

func load_array(path: String, required_keys: Array[String], fallback: Array) -> Array:
	# Flow step 1: ensure the file exists before trying to open it.
	if not FileAccess.file_exists(path):
		# duplicate(true) creates a deep copy so caller mutations do not affect
		# the original fallback template.
		return fallback.duplicate(true)

	# Flow step 2: open file in read mode.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		# If open fails (permissions/path issues), recover with fallback.
		return fallback.duplicate(true)

	# Flow step 3: parse raw file text as JSON.
	var raw_text := file.get_as_text()
	var parsed = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_ARRAY:
		# Contract of this helper: caller expects an Array at top-level.
		return fallback.duplicate(true)

	# Flow step 4: validate each entry and keep only dictionaries that contain
	# all required keys.
	var valid_entries: Array = []
	for entry in parsed:
		# Skip non-object entries (numbers/strings/etc).
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		# Keep only dictionaries with the required schema fields.
		if _has_required_keys(entry, required_keys):
			valid_entries.append(entry)

	# Flow step 5: if nothing usable remains, fail-safe to fallback.
	if valid_entries.is_empty():
		return fallback.duplicate(true)

	# Success path: return validated, filtered content from file.
	return valid_entries


func _has_required_keys(entry: Dictionary, required_keys: Array[String]) -> bool:
	# Small schema guard:
	# returns true only if every key in `required_keys` exists in `entry`.
	for key in required_keys:
		if not entry.has(key):
			return false
	return true
