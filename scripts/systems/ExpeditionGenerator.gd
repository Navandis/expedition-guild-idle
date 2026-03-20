extends RefCounted
class_name ExpeditionGenerator

# ExpeditionGenerator is the content "assembler" for expedition offers.
# It loads JSON content pools, picks random combinations, and returns
# normalized dictionaries that UI/gameplay systems can consume directly.
#
# Region slice note:
# Callers can now pass region generation constraints. The generator keeps the
# same output structure while filtering each content pool by selected region.

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

const MAX_UNIQUE_ATTEMPTS := 60

var _rng := RandomNumberGenerator.new()

var _json_loader := JsonLoader.new()

var _biomes: Array = []
var _site_types: Array = []
var _states: Array = []
var _reward_profiles: Array = []
var _hazards: Array = []


func _init() -> void:
	_rng.randomize()
	_reload_content()


func generate_expeditions(count: int, excluded_signatures: Array[String] = [], generation_context: Dictionary = {}) -> Array[Dictionary]:
	# Clamp to board rules so callers cannot request impossible counts.
	var expedition_count := clampi(count, 3, 5)
	var expeditions: Array[Dictionary] = []
	var reserved_signatures := excluded_signatures.duplicate()

	for _i in expedition_count:
		var expedition := generate_single_expedition(reserved_signatures, generation_context)
		if expedition.is_empty():
			continue

		expeditions.append(expedition)
		reserved_signatures.append(build_signature(expedition))

	# Safe fallback if generation was interrupted by malformed/degraded content
	# and uniqueness filtering cannot satisfy the requested board size.
	if expeditions.size() < expedition_count:
		return _generate_fallback_expeditions(expedition_count, generation_context)

	return expeditions


func generate_single_expedition(excluded_signatures: Array[String] = [], generation_context: Dictionary = {}) -> Dictionary:
	# Keep trying random combinations until we find one not already on the board.
	for attempt in MAX_UNIQUE_ATTEMPTS:
		var expedition := _build_random_expedition(attempt, generation_context)
		if expedition.is_empty():
			continue

		var signature := build_signature(expedition)
		if excluded_signatures.has(signature):
			continue

		return expedition

	return {}


func build_signature(expedition: Dictionary) -> String:
	# Signature uses the display-defining content axes to avoid duplicate offers.
	return "%s|%s|%s" % [
		str(expedition.get("biome", "unknown_biome")),
		str(expedition.get("site_type", "unknown_site")),
		str(expedition.get("state_modifier", "unknown_state"))
	]


func _build_random_expedition(index: int, generation_context: Dictionary) -> Dictionary:
	# Pick one record from each content category to build a full card.
	# Region constraints are optional and only filter pools by allowed IDs.
	var biome := _pick_random(_filter_pool_by_allowed_ids(_biomes, _to_string_array(generation_context.get("allowed_biomes", []))))
	var site_type := _pick_random(_filter_pool_by_allowed_ids(_site_types, _to_string_array(generation_context.get("site_families", []))))
	var state_modifier := _pick_random(_filter_pool_by_allowed_ids(_states, _to_string_array(generation_context.get("site_conditions", []))))
	var reward_profile := _pick_random(_filter_pool_by_allowed_ids(_reward_profiles, _to_string_array(generation_context.get("opportunity_profiles", []))))
	var hazard := _pick_random(_filter_pool_by_allowed_ids(_hazards, _to_string_array(generation_context.get("hazard_tags", []))))
	var difficulty_config := _pick_random(DIFFICULTY_CONFIG)

	if biome.is_empty() or site_type.is_empty() or state_modifier.is_empty() or reward_profile.is_empty() or hazard.is_empty() or difficulty_config.is_empty():
		return {}

	var duration_minutes := _rng.randi_range(
		int(difficulty_config.get("duration_min", 60)),
		int(difficulty_config.get("duration_max", 120))
	)
	var display_name := "%s %s %s" % [
		str(state_modifier.get("name", "Unknown")),
		str(biome.get("name", "Unknown")),
		str(site_type.get("name", "Site"))
	]

	return {
		"id": _build_expedition_id(biome, site_type, state_modifier, index),
		"region_id": str(generation_context.get("region_id", "")),
		"region_name": str(generation_context.get("region_name", "")),
		"biome": str(biome.get("id", "unknown_biome")),
		"site_type": str(site_type.get("id", "unknown_site")),
		"state_modifier": str(state_modifier.get("id", "unknown_state")),
		# Store internal IDs for save/load and gameplay lookups...
		"reward_profile": str(reward_profile.get("id", "balanced")),
		"hazard": str(hazard.get("id", "traps")),
		# ...and include display names for player-facing UI text.
		"reward_profile_name": str(reward_profile.get("name", "Balanced")),
		"hazard_name": str(hazard.get("name", "Traps")),
		"duration_minutes": duration_minutes,
		"difficulty": str(difficulty_config.get("id", "medium")),
		"risk_label": str(difficulty_config.get("risk_label", "Medium")),
		"display_name": display_name,
		"flavor_summary": _build_flavor_summary(state_modifier, biome, site_type, hazard),
		"base_success": float(difficulty_config.get("base_success", 0.75))
	}


func _reload_content() -> void:
	# required_keys ensures each entry has the schema fields we expect.
	_biomes = _json_loader.load_array(BIOMES_PATH, ["id", "name"], FALLBACK_BIOMES)
	_site_types = _json_loader.load_array(SITE_TYPES_PATH, ["id", "name"], FALLBACK_SITE_TYPES)
	_states = _json_loader.load_array(STATES_PATH, ["id", "name"], FALLBACK_STATES)
	_reward_profiles = _json_loader.load_array(REWARD_PROFILES_PATH, ["id", "name"], FALLBACK_REWARD_PROFILES)
	_hazards = _json_loader.load_array(HAZARDS_PATH, ["id", "name"], FALLBACK_HAZARDS)


func _pick_random(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _filter_pool_by_allowed_ids(pool: Array, allowed_ids: Array[String]) -> Array:
	# Constraint behavior:
	# - Empty allowed_ids means "no region filter" (use full pool).
	# - Unknown IDs are ignored; if no matches remain we fall back to full pool so
	#   generation still works during content iteration.
	if allowed_ids.is_empty():
		return pool

	var filtered: Array = []
	for entry in pool:
		if not (entry is Dictionary):
			continue
		if allowed_ids.has(str((entry as Dictionary).get("id", ""))):
			filtered.append(entry)

	return filtered if not filtered.is_empty() else pool


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


func _generate_fallback_expeditions(count: int, generation_context: Dictionary) -> Array[Dictionary]:
	_reload_content()
	var fallback_expeditions: Array[Dictionary] = []
	for i in count:
		fallback_expeditions.append({
			"id": "exp_fallback_%03d" % i,
			"region_id": str(generation_context.get("region_id", "")),
			"region_name": str(generation_context.get("region_name", "")),
			"biome": "plains",
			"site_type": "ruins",
			"state_modifier": "abandoned",
			"reward_profile": "balanced",
			"hazard": "traps",
			"reward_profile_name": "Balanced",
			"hazard_name": "Traps",
			"duration_minutes": 60,
			"difficulty": "easy",
			"risk_label": "Low",
			"display_name": "Abandoned Plains Ruins",
			"flavor_summary": "A calm fallback route used when expedition data is unavailable.",
			"base_success": 0.85
		})
	return fallback_expeditions


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
