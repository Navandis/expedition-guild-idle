extends RefCounted
class_name CodexSystem

# CodexSystem tracks a tiny discovery collection for the day-3 prototype.
# It records one discovery per unique expedition site_type so players can
# see lightweight progression without adding deeper collection mechanics yet.

var _discovered_site_types: Array[String] = []


func record_discovery_from_report(report: Dictionary) -> bool:
	# Discoveries are recorded when rewards are collected, which is a one-time
	# event in the current loop and avoids duplicate calls from UI re-opening.
	var site_type := str(report.get("site_type", "")).strip_edges()
	if site_type.is_empty():
		return false

	# Duplicate prevention is intentionally simple: skip if this key exists.
	if _discovered_site_types.has(site_type):
		return false

	_discovered_site_types.append(site_type)
	_discovered_site_types.sort()
	return true


func get_total_discoveries() -> int:
	return _discovered_site_types.size()


func get_discovered_entries() -> Array[String]:
	# Return a copy so UI callers cannot mutate system-owned data by accident.
	return _discovered_site_types.duplicate()



func restore_discoveries(saved_entries: Array[String]) -> void:
	# Load flow: normalize values and de-duplicate so malformed save data is safe.
	_discovered_site_types.clear()
	for entry in saved_entries:
		var key := str(entry).strip_edges()
		if key.is_empty() or _discovered_site_types.has(key):
			continue
		_discovered_site_types.append(key)
	_discovered_site_types.sort()
