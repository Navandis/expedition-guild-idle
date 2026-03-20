extends RefCounted
class_name RegionSystem

# RegionSystem keeps authored region definitions separate from player-owned
# region progress. It also tracks which unlocked region is currently selected
# so expedition generation can be constrained without storing state in UI nodes.

const REGIONS_PATH := "res://data/expeditions/regions.json"

# Required keys for each authored region entry. We keep this explicit so bad JSON
# falls back safely instead of crashing runtime flow.
const REQUIRED_REGION_KEYS := [
	"id",
	"display",
	"theme",
	"progression",
	"generation_rules",
	"rewards_and_discoveries",
	"codex",
	"hooks"
]

const FALLBACK_REGION_DEFINITIONS := [
	{
		"id": "greenhollow_reaches",
		"display": {
			"name": "Greenhollow Reaches",
			"short_name": "Greenhollow",
			"region_tier": 1,
			"summary_text": "Fallback starter region.",
			"codex_sketch_asset": ""
		},
		"theme": {
			"region_role": "starter",
			"allowed_biomes": ["plains"],
			"culture_families": [],
			"art_motifs": [],
			"fantasy_level": "grounded"
		},
		"progression": {
			"starts_visible": true,
			"starts_unlocked": true,
			"prerequisite_region_ids": [],
			"prerequisite_clue_tags": [],
			"prerequisite_research_tags": [],
			"prerequisite_logistics_tags": []
		},
		"generation_rules": {
			"route_types": ["scouting"],
			"site_families": ["ruins"],
			"site_conditions": ["abandoned"],
			"opportunity_profiles": ["balanced"],
			"hazard_tags": ["traps"]
		},
		"rewards_and_discoveries": {
			"artifact_families": [],
			"clue_families": []
		},
		"codex": {
			"page_order": 10,
			"starts_as_unknown_page": false
		},
		"hooks": {
			"chain_hook_tags": [],
			"legacy_hook_tags": []
		}
	}
]

# Save payload keys for per-region player progress.
const PLAYER_PROGRESS_KEYS := [
	"is_visible",
	"is_unlocked",
	"expeditions_completed",
	"region_discovery_points",
	"codex_reveal_stage",
	"artifact_families_seen",
	"clue_tags_found",
	"active_chain_ids",
	"completion_flags"
]

var _json_loader := JsonLoader.new()
var _region_definitions: Array[Dictionary] = []
var _player_region_progress := {}
var _selected_region_id := ""


func _init() -> void:
	_load_authored_regions()
	_create_default_player_progress()
	_selected_region_id = _pick_default_selected_region_id()


func restore_player_state(saved_progress: Variant, saved_selected_region_id: Variant) -> void:
	# Save migration/defaulting behavior:
	# - If region progress is missing (older saves), initialize from authored defaults.
	# - If selected region is missing or locked, pick first unlocked region.
	_create_default_player_progress()

	if saved_progress is Dictionary:
		for region in _region_definitions:
			var region_id := str(region.get("id", ""))
			if region_id.is_empty() or not (saved_progress as Dictionary).has(region_id):
				continue
			var incoming_value: Variant = (saved_progress as Dictionary).get(region_id, {})
			if incoming_value is Dictionary:
				var incoming: Dictionary = incoming_value
				_player_region_progress[region_id] = _sanitize_progress_entry(incoming, region)

	_selected_region_id = str(saved_selected_region_id)
	if not is_region_selectable(_selected_region_id):
		_selected_region_id = _pick_default_selected_region_id()


func build_save_progress_snapshot() -> Dictionary:
	return _player_region_progress.duplicate(true)


func get_selected_region_id() -> String:
	return _selected_region_id


func set_selected_region(region_id: String) -> bool:
	if not is_region_selectable(region_id):
		return false
	_selected_region_id = region_id
	return true


func is_region_selectable(region_id: String) -> bool:
	var progress: Variant = _player_region_progress.get(region_id, {})
	if not (progress is Dictionary):
		return false
	return bool((progress as Dictionary).get("is_visible", false)) and bool((progress as Dictionary).get("is_unlocked", false))


func get_selected_region_definition() -> Dictionary:
	return get_region_definition_by_id(_selected_region_id)


func get_region_definition_by_id(region_id: String) -> Dictionary:
	for region in _region_definitions:
		if str(region.get("id", "")) == region_id:
			return region.duplicate(true)
	return {}


func get_region_list_for_ui() -> Array[Dictionary]:
	# Minimal UI payload: ordered list with availability state and short display text.
	var rows: Array[Dictionary] = []
	for region in _region_definitions:
		var region_id := str(region.get("id", ""))
		var display := region.get("display", {}) as Dictionary
		var progress := _player_region_progress.get(region_id, {}) as Dictionary
		rows.append({
			"id": region_id,
			"name": str(display.get("name", region_id)),
			"short_name": str(display.get("short_name", region_id)),
			"is_visible": bool(progress.get("is_visible", false)),
			"is_unlocked": bool(progress.get("is_unlocked", false)),
			"is_selected": region_id == _selected_region_id
		})
	return rows


func get_generation_rules_for_selected_region() -> Dictionary:
	var selected := get_selected_region_definition()
	if selected.is_empty():
		return {}
	var rules := selected.get("generation_rules", {}) as Dictionary
	var theme := selected.get("theme", {}) as Dictionary
	return {
		"region_id": str(selected.get("id", "")),
		"region_name": str((selected.get("display", {}) as Dictionary).get("name", "Unknown Region")),
		"allowed_biomes": _to_string_array(theme.get("allowed_biomes", [])),
		"site_families": _to_string_array(rules.get("site_families", [])),
		"site_conditions": _to_string_array(rules.get("site_conditions", [])),
		"opportunity_profiles": _to_string_array(rules.get("opportunity_profiles", [])),
		"hazard_tags": _to_string_array(rules.get("hazard_tags", []))
	}


func _load_authored_regions() -> void:
	var loaded := _json_loader.load_array(REGIONS_PATH, REQUIRED_REGION_KEYS, FALLBACK_REGION_DEFINITIONS)
	_region_definitions = []
	for entry in loaded:
		if not (entry is Dictionary):
			continue
		_region_definitions.append((entry as Dictionary).duplicate(true))


func _create_default_player_progress() -> void:
	_player_region_progress = {}
	for region in _region_definitions:
		var region_id := str(region.get("id", ""))
		if region_id.is_empty():
			continue
		_player_region_progress[region_id] = _build_default_progress_for(region)


func _build_default_progress_for(region: Dictionary) -> Dictionary:
	var progression := region.get("progression", {}) as Dictionary
	return {
		"is_visible": bool(progression.get("starts_visible", false)),
		"is_unlocked": bool(progression.get("starts_unlocked", false)),
		"expeditions_completed": 0,
		"region_discovery_points": 0,
		"codex_reveal_stage": 0,
		"artifact_families_seen": [],
		"clue_tags_found": [],
		"active_chain_ids": [],
		"completion_flags": []
	}


func _sanitize_progress_entry(entry: Dictionary, region: Dictionary) -> Dictionary:
	var default_entry := _build_default_progress_for(region)
	var output := default_entry.duplicate(true)
	output["is_visible"] = bool(entry.get("is_visible", default_entry.get("is_visible", false)))
	output["is_unlocked"] = bool(entry.get("is_unlocked", default_entry.get("is_unlocked", false)))
	output["expeditions_completed"] = maxi(0, int(entry.get("expeditions_completed", 0)))
	output["region_discovery_points"] = maxi(0, int(entry.get("region_discovery_points", 0)))
	output["codex_reveal_stage"] = maxi(0, int(entry.get("codex_reveal_stage", 0)))
	output["artifact_families_seen"] = _to_string_array(entry.get("artifact_families_seen", []))
	output["clue_tags_found"] = _to_string_array(entry.get("clue_tags_found", []))
	output["active_chain_ids"] = _to_string_array(entry.get("active_chain_ids", []))
	output["completion_flags"] = _to_string_array(entry.get("completion_flags", []))
	return output


func _pick_default_selected_region_id() -> String:
	for region in _region_definitions:
		var region_id := str(region.get("id", ""))
		if is_region_selectable(region_id):
			return region_id
	return str((_region_definitions[0] as Dictionary).get("id", "")) if not _region_definitions.is_empty() else ""


func _to_string_array(value: Variant) -> Array[String]:
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
