extends RefCounted
class_name CommissionDataLoader

# -----------------------------------------------------------------------------
# CommissionDataLoader
# -----------------------------------------------------------------------------
# Purpose:
# - Load authored commission JSON content from res://data/commissions/.
# - Validate/sanitize enough fields for safe runtime generation.
# - Keep authored content fully separate from runtime/player-owned board state.
#
# Important boundary:
# - This loader NEVER writes data back into authored JSON files.
# - Runtime state (visible board offers, accepted offers, etc.) belongs in
#   controllers/save systems, not in authored content files.
# -----------------------------------------------------------------------------

const PATRONS_PATH := "res://data/commissions/commission_patrons.json"
const FAMILIES_PATH := "res://data/commissions/commission_families.json"
const OBJECTIVE_TEMPLATES_PATH := "res://data/commissions/commission_objective_templates.json"
const BOARD_RULES_PATH := "res://data/commissions/commission_board_rules.json"
const GENERATION_CONFIG_PATH := "res://data/commissions/commission_generation_config.json"

const SUPPORTED_FAMILY_IDS: Array[String] = ["retrieval", "escort", "survey", "security"]
const SUPPORTED_TIER_IDS: Array[String] = [
	"tier_1_local_patrons",
	"tier_2_organized_institutions",
	"tier_3_regional_powers",
	"tier_4_grand_patrons"
]


func load_commission_data() -> Dictionary:
	# Generation reads from one merged payload for simplicity and testability.
	var patrons_root := _load_json_dictionary(PATRONS_PATH)
	var families_root := _load_json_dictionary(FAMILIES_PATH)
	var templates_root := _load_json_dictionary(OBJECTIVE_TEMPLATES_PATH)
	var board_rules_root := _load_json_dictionary(BOARD_RULES_PATH)
	var generation_config_root := _load_json_dictionary(GENERATION_CONFIG_PATH)

	var patron_tiers := _sanitize_patron_tiers(patrons_root.get("patron_tiers", []))
	var patrons := _sanitize_patrons(patrons_root.get("patrons", []), patron_tiers)
	var families := _sanitize_families(families_root.get("families", []))
	var duration_band_minutes := _sanitize_duration_band_minutes(families_root.get("duration_band_minutes", {}))
	var risk_bands := _to_string_array(families_root.get("risk_bands", []))
	var templates := _sanitize_objective_templates(templates_root.get("templates", []), families, patrons)

	var board_rules := _sanitize_board_rules(board_rules_root)
	var generation_config := _sanitize_generation_config(generation_config_root)

	return {
		"patron_tiers": patron_tiers,
		"patrons": patrons,
		"families": families,
		"duration_band_minutes": duration_band_minutes,
		"risk_bands": risk_bands,
		"objective_templates": templates,
		"board_rules": board_rules,
		"generation_config": generation_config,
		"indexes": {
			"tier_by_id": _build_index_by_id(patron_tiers),
			"patron_by_id": _build_index_by_id(patrons),
			"family_by_id": _build_index_by_id(families),
			"template_by_id": _build_index_by_id(templates),
			"template_ids_by_family": _build_template_ids_by_family(templates),
			"patron_ids_by_tier": _build_patron_ids_by_tier(patrons)
		}
	}


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("CommissionDataLoader: missing file at %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("CommissionDataLoader: failed to open file %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		push_warning("CommissionDataLoader: expected dictionary root in %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


func _sanitize_patron_tiers(raw_value: Variant) -> Array[Dictionary]:
	var tiers: Array[Dictionary] = []
	if not (raw_value is Array):
		return tiers

	for row in raw_value:
		if not (row is Dictionary):
			continue
		var tier := row as Dictionary
		var tier_id := str(tier.get("id", "")).strip_edges()
		if not SUPPORTED_TIER_IDS.has(tier_id):
			continue
		tiers.append({
			"id": tier_id,
			"name": str(tier.get("name", tier_id)),
			"tier_index": int(tier.get("tier_index", 1)),
			"default_unlock_state": str(tier.get("default_unlock_state", "")),
			"family_biases": _to_weight_dictionary(tier.get("family_biases", {})),
			"reward_bias": str(tier.get("reward_bias", "medium")),
			"standing_bias": str(tier.get("standing_bias", "medium"))
		})
	return tiers


func _sanitize_patrons(raw_value: Variant, patron_tiers: Array[Dictionary]) -> Array[Dictionary]:
	var patrons: Array[Dictionary] = []
	var tier_ids := _build_id_lookup(patron_tiers)
	if not (raw_value is Array):
		return patrons

	for row in raw_value:
		if not (row is Dictionary):
			continue
		var patron := row as Dictionary
		var patron_id := str(patron.get("id", "")).strip_edges()
		var tier_id := str(patron.get("tier_id", "")).strip_edges()
		if patron_id.is_empty() or not tier_ids.has(tier_id):
			continue
		patrons.append({
			"id": patron_id,
			"name": str(patron.get("name", patron_id)),
			"tier_id": tier_id,
			"tags": _to_string_array(patron.get("tags", [])),
			"brief_style_bias": _to_weight_dictionary(patron.get("brief_style_bias", {})),
			"family_biases": _to_weight_dictionary(patron.get("family_biases", {})),
			"preferred_region_tags": _to_string_array(patron.get("preferred_region_tags", [])),
			"reward_bias": str(patron.get("reward_bias", "medium")),
			"standing_bias": str(patron.get("standing_bias", "medium"))
		})
	return patrons


func _sanitize_families(raw_value: Variant) -> Array[Dictionary]:
	var families: Array[Dictionary] = []
	if not (raw_value is Array):
		return families

	for row in raw_value:
		if not (row is Dictionary):
			continue
		var family := row as Dictionary
		var family_id := str(family.get("id", "")).strip_edges()
		if not SUPPORTED_FAMILY_IDS.has(family_id):
			continue
		families.append({
			"id": family_id,
			"name": str(family.get("name", family_id)),
			"default_duration_bands": _to_string_array(family.get("default_duration_bands", [])),
			"default_risk_bands": _to_string_array(family.get("default_risk_bands", [])),
			"base_crew_required": _to_min_max_dictionary(family.get("base_crew_required", {}), 1, 3),
			"base_supplies_required": _to_min_max_dictionary(family.get("base_supplies_required", {}), 1, 1),
			"typical_requirement_tags": _to_string_array(family.get("typical_requirement_tags", [])),
			"reward_focus": _to_string_array(family.get("reward_focus", [])),
			"presentation_style": str(family.get("presentation_style", ""))
		})
	return families


func _sanitize_objective_templates(raw_value: Variant, families: Array[Dictionary], patrons: Array[Dictionary]) -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	var family_ids := _build_id_lookup(families)
	var patron_ids := _build_id_lookup(patrons)
	if not (raw_value is Array):
		return templates

	for row in raw_value:
		if not (row is Dictionary):
			continue
		var template := row as Dictionary
		var template_id := str(template.get("id", "")).strip_edges()
		var family_id := str(template.get("family_id", "")).strip_edges()
		if template_id.is_empty() or not family_ids.has(family_id):
			continue
		templates.append({
			"id": template_id,
			"family_id": family_id,
			"template_text": str(template.get("template_text", "")),
			"compatible_patron_ids": _filter_to_known_ids(template.get("compatible_patron_ids", []), patron_ids),
			"compatible_region_ids": _to_string_array(template.get("compatible_region_ids", [])),
			"required_tag_biases": _to_string_array(template.get("required_tag_biases", [])),
			"preferred_tag_biases": _to_string_array(template.get("preferred_tag_biases", [])),
			"risk_modifiers": _to_weight_dictionary(template.get("risk_modifiers", {})),
			"reward_modifiers": _to_weight_dictionary(template.get("reward_modifiers", {})),
			"brief_style_allowed": _to_string_array(template.get("brief_style_allowed", [])),
			"context_tokens": _to_string_array_dictionary(template.get("context_tokens", {}))
		})
	return templates


func _sanitize_board_rules(raw_root: Dictionary) -> Dictionary:
	var composition := raw_root.get("composition_rules", {}) as Dictionary
	return {
		"visible_offer_count": maxi(1, int(raw_root.get("visible_offer_count", 3))),
		"standard_offers_expire": bool(raw_root.get("standard_offers_expire", false)),
		"refill_behavior": str(raw_root.get("refill_behavior", "refill_single_slot_on_accept")),
		"reroll_behavior": str(raw_root.get("reroll_behavior", "refresh_all_visible_slots")),
		"composition_rules": {
			"avoid_family_duplicates_if_possible": bool(composition.get("avoid_family_duplicates_if_possible", true)),
			"avoid_patron_duplicates_if_possible": bool(composition.get("avoid_patron_duplicates_if_possible", true)),
			"avoid_same_region_all_slots_if_possible": bool(composition.get("avoid_same_region_all_slots_if_possible", true)),
			"target_risk_spread": _to_string_array(composition.get("target_risk_spread", [])),
			"target_brief_style_mix": _to_string_array(composition.get("target_brief_style_mix", [])),
			"ensure_one_reasonably_runnable_offer_if_possible": bool(composition.get("ensure_one_reasonably_runnable_offer_if_possible", true)),
			"interesting_slot_bias": (composition.get("interesting_slot_bias", {}) as Dictionary).duplicate(true)
		},
		"fallback_rules": (raw_root.get("fallback_rules", {}) as Dictionary).duplicate(true)
	}


func _sanitize_duration_band_minutes(raw_value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not (raw_value is Dictionary):
		return output
	for key in (raw_value as Dictionary).keys():
		var band := str(key).strip_edges()
		if band.is_empty():
			continue
		output[band] = _to_min_max_dictionary((raw_value as Dictionary).get(key, {}), 10, 15)
	return output


func _sanitize_generation_config(raw_root: Dictionary) -> Dictionary:
	return {
		"starting_board": (raw_root.get("starting_board", {}) as Dictionary).duplicate(true),
		"family_weights_default": _to_weight_dictionary(raw_root.get("family_weights_default", {})),
		"brief_style_weights_default": _to_weight_dictionary(raw_root.get("brief_style_weights_default", {})),
		"risk_weights_default": _to_weight_dictionary(raw_root.get("risk_weights_default", {})),
		"duration_band_weights_default": _to_weight_dictionary(raw_root.get("duration_band_weights_default", {})),
		"outcome_band_labels": _to_string_array(raw_root.get("outcome_band_labels", [])),
		"requirement_tags": (raw_root.get("requirement_tags", {}) as Dictionary).duplicate(true),
		"resource_inputs": (raw_root.get("resource_inputs", {}) as Dictionary).duplicate(true),
		"starter_region_ids": _to_string_array(raw_root.get("starter_region_ids", []))
	}


func _build_index_by_id(rows: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id.is_empty():
			continue
		output[row_id] = row.duplicate(true)
	return output


func _build_template_ids_by_family(rows: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var family_id := str(row.get("family_id", "")).strip_edges()
		if family_id.is_empty():
			continue
		if not output.has(family_id):
			output[family_id] = []
		(output[family_id] as Array).append(str(row.get("id", "")))
	return output


func _build_patron_ids_by_tier(rows: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var tier_id := str(row.get("tier_id", "")).strip_edges()
		if tier_id.is_empty():
			continue
		if not output.has(tier_id):
			output[tier_id] = []
		(output[tier_id] as Array).append(str(row.get("id", "")))
	return output


func _build_id_lookup(rows: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id.is_empty():
			continue
		output[row_id] = true
	return output


func _filter_to_known_ids(value: Variant, known_ids: Dictionary) -> Array[String]:
	var output: Array[String] = []
	if not (value is Array):
		return output
	for entry in value:
		var text := str(entry).strip_edges()
		if text.is_empty() or not known_ids.has(text):
			continue
		output.append(text)
	return output


func _to_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text.is_empty() or output.has(text):
				continue
			output.append(text)
	return output


func _to_weight_dictionary(value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not (value is Dictionary):
		return output
	for key in (value as Dictionary).keys():
		var text_key := str(key).strip_edges()
		if text_key.is_empty():
			continue
		output[text_key] = maxf(0.0, float((value as Dictionary).get(key, 0.0)))
	return output


func _to_string_array_dictionary(value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not (value is Dictionary):
		return output
	for key in (value as Dictionary).keys():
		var text_key := str(key).strip_edges()
		if text_key.is_empty():
			continue
		output[text_key] = _to_string_array((value as Dictionary).get(key, []))
	return output


func _to_min_max_dictionary(value: Variant, fallback_min: int, fallback_max: int) -> Dictionary:
	if not (value is Dictionary):
		return {"min": fallback_min, "max": fallback_max}
	var min_value := maxi(0, int((value as Dictionary).get("min", fallback_min)))
	var max_value := maxi(min_value, int((value as Dictionary).get("max", fallback_max)))
	return {"min": min_value, "max": max_value}
