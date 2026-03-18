extends RefCounted
class_name ExpeditionGenerator

const BIOMES_PATH := "res://data/expeditions/biomes.json"
const SITE_TYPES_PATH := "res://data/expeditions/site_types.json"
const STATES_PATH := "res://data/expeditions/states.json"
const REWARD_PROFILES_PATH := "res://data/expeditions/reward_profiles.json"
const HAZARDS_PATH := "res://data/expeditions/hazards.json"

const FALLBACK_BIOMES := [
	{"id": "plains", "name": "Plains"}
]
const FALLBACK_SITE_TYPES := [
	{"id": "ruins", "name": "Ruins"}
]
const FALLBACK_STATES := [
	{"id": "abandoned", "name": "Abandoned"}
]
const FALLBACK_REWARD_PROFILES := [
	{"id": "balanced", "name": "Balanced"}
]
const FALLBACK_HAZARDS := [
	{"id": "traps", "name": "Traps"}
]

const DIFFICULTY_CONFIG := [
	{"id": "easy", "risk_label": "Low", "duration_min": 30, "duration_max": 60, "base_success": 0.85},
	{"id": "medium", "risk_label": "Medium", "duration_min": 60, "duration_max": 120, "base_success": 0.75},
	{"id": "hard", "risk_label": "High", "duration_min": 120, "duration_max": 240, "base_success": 0.65}
]

var _rng := RandomNumberGenerator.new()

var _biomes: Array = []
var _site_types: Array = []
var _states: Array = []
var _reward_profiles: Array = []
var _hazards: Array = []


func _init() -> void:
	_rng.randomize()
	_reload_content()


func generate_expeditions(count: int) -> Array[Dictionary]:
	var expedition_count := clampi(count, 3, 5)
	var expeditions: Array[Dictionary] = []

	for index in expedition_count:
		var biome := _pick_random(_biomes)
		var site_type := _pick_random(_site_types)
		var state_modifier := _pick_random(_states)
		var reward_profile := _pick_random(_reward_profiles)
		var hazard := _pick_random(_hazards)
		var difficulty_config := _pick_random(DIFFICULTY_CONFIG)

		if biome.is_empty() or site_type.is_empty() or state_modifier.is_empty() or reward_profile.is_empty() or hazard.is_empty() or difficulty_config.is_empty():
			continue

		var duration_minutes := _rng.randi_range(
			int(difficulty_config.get("duration_min", 60)),
			int(difficulty_config.get("duration_max", 120))
		)
		var display_name := "%s %s %s" % [
			str(state_modifier.get("name", "Unknown")),
			str(biome.get("name", "Unknown")),
			str(site_type.get("name", "Site"))
		]

		var expedition: Dictionary = {
			"id": _build_expedition_id(biome, site_type, state_modifier, index),
			"biome": str(biome.get("id", "unknown_biome")),
			"site_type": str(site_type.get("id", "unknown_site")),
			"state_modifier": str(state_modifier.get("id", "unknown_state")),
			"reward_profile": str(reward_profile.get("id", "balanced")),
			"hazard": str(hazard.get("id", "traps")),
			"duration_minutes": duration_minutes,
			"difficulty": str(difficulty_config.get("id", "medium")),
			"risk_label": str(difficulty_config.get("risk_label", "Medium")),
			"display_name": display_name,
			"flavor_summary": _build_flavor_summary(state_modifier, biome, site_type, hazard),
			"base_success": float(difficulty_config.get("base_success", 0.75))
		}

		expeditions.append(expedition)

	# Safe fallback if generation was interrupted by malformed content.
	if expeditions.is_empty():
		return _generate_fallback_expeditions(expedition_count)

	return expeditions


func _reload_content() -> void:
	_biomes = _load_pool(BIOMES_PATH, ["id", "name"], FALLBACK_BIOMES)
	_site_types = _load_pool(SITE_TYPES_PATH, ["id", "name"], FALLBACK_SITE_TYPES)
	_states = _load_pool(STATES_PATH, ["id", "name"], FALLBACK_STATES)
	_reward_profiles = _load_pool(REWARD_PROFILES_PATH, ["id", "name"], FALLBACK_REWARD_PROFILES)
	_hazards = _load_pool(HAZARDS_PATH, ["id", "name"], FALLBACK_HAZARDS)


func _load_pool(path: String, required_keys: Array[String], fallback: Array) -> Array:
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


func _pick_random(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _build_expedition_id(biome: Dictionary, site_type: Dictionary, state_modifier: Dictionary, index: int) -> String:
	return "exp_%s_%s_%s_%03d" % [
		str(biome.get("id", "biome")),
		str(site_type.get("id", "site")),
		str(state_modifier.get("id", "state")),
		index
	]


func _build_flavor_summary(state_modifier: Dictionary, biome: Dictionary, site_type: Dictionary, hazard: Dictionary) -> String:
	return "A %s %s in the %s. Scouts report %s risks in the area." % [
		str(state_modifier.get("name", "weathered")).to_lower(),
		str(site_type.get("name", "site")).to_lower(),
		str(biome.get("name", "frontier")).to_lower(),
		str(hazard.get("name", "unknown")).to_lower()
	]


func _generate_fallback_expeditions(count: int) -> Array[Dictionary]:
	_reload_content()
	var fallback_expeditions: Array[Dictionary] = []
	for i in count:
		fallback_expeditions.append({
			"id": "exp_fallback_%03d" % i,
			"biome": "plains",
			"site_type": "ruins",
			"state_modifier": "abandoned",
			"reward_profile": "balanced",
			"hazard": "traps",
			"duration_minutes": 60,
			"difficulty": "easy",
			"risk_label": "Low",
			"display_name": "Abandoned Plains Ruins",
			"flavor_summary": "A calm fallback route used when expedition data is unavailable.",
			"base_success": 0.85
		})
	return fallback_expeditions
