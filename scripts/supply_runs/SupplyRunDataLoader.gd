extends RefCounted
class_name SupplyRunDataLoader

# -----------------------------------------------------------------------------
# SupplyRunDataLoader
# -----------------------------------------------------------------------------
# Purpose:
# - Load authored Supply Runs data from res://data/supply_runs/.
# - Sanitize fields for safe runtime board generation.
# - Keep authored content separate from runtime/player-owned offer state.
#
# Supply Runs are separate from commissions because this lane models internal
# provisioning operations (supplies generation), not patron-facing contracts.
# -----------------------------------------------------------------------------

const FAMILIES_PATH := "res://data/supply_runs/supply_run_families.json"
const TEMPLATES_PATH := "res://data/supply_runs/supply_run_templates.json"
const BOARD_RULES_PATH := "res://data/supply_runs/supply_board_rules.json"
const GENERATION_CONFIG_PATH := "res://data/supply_runs/supply_generation_config.json"


func load_supply_run_data() -> Dictionary:
	var families_root := _load_json_dictionary(FAMILIES_PATH)
	var templates_root := _load_json_dictionary(TEMPLATES_PATH)
	var board_rules_root := _load_json_dictionary(BOARD_RULES_PATH)
	var generation_root := _load_json_dictionary(GENERATION_CONFIG_PATH)

	var families := _sanitize_families(families_root.get("families", []))
	var templates := _sanitize_templates(templates_root.get("templates", []), families)
	var board_rules := _sanitize_board_rules(board_rules_root)
	var generation_config := _sanitize_generation_config(generation_root)

	return {
		"families": families,
		"templates": templates,
		"board_rules": board_rules,
		"generation_config": generation_config,
		"indexes": {
			"family_by_id": _build_index_by_id(families),
			"template_by_id": _build_index_by_id(templates)
		}
	}


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("SupplyRunDataLoader: missing file at %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SupplyRunDataLoader: failed to open file %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		push_warning("SupplyRunDataLoader: expected dictionary root in %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


func _sanitize_families(raw_value: Variant) -> Array[Dictionary]:
	var families: Array[Dictionary] = []
	if not (raw_value is Array):
		return families

	for row in raw_value:
		if not (row is Dictionary):
			continue
		var family := row as Dictionary
		var family_id := str(family.get("id", "")).strip_edges()
		if family_id.is_empty():
			continue

		families.append({
			"id": family_id,
			"name": str(family.get("name", family_id)),
			"duration_minutes": _to_min_max_dictionary(family.get("duration_minutes", {}), 20, 45),
			"crew_required": _to_min_max_dictionary(family.get("crew_required", {}), 2, 3),
			"gold_cost": _to_min_max_dictionary(family.get("gold_cost", {}), 0, 0),
			"supplies_yield_estimate": _to_min_max_dictionary(family.get("supplies_yield_estimate", {}), 10, 15),
			"risk_text_options": _to_string_array(family.get("risk_text_options", [])),
			"note_text_options": _to_string_array(family.get("note_text_options", []))
		})
	return families


func _sanitize_templates(raw_value: Variant, families: Array[Dictionary]) -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	if not (raw_value is Array):
		return templates

	var family_ids := _build_id_lookup(families)
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
			"title_template": str(template.get("title_template", "Supply Run")),
			"compatible_region_ids": _to_string_array(template.get("compatible_region_ids", []))
		})
	return templates


func _sanitize_board_rules(raw_root: Dictionary) -> Dictionary:
	var composition := raw_root.get("composition_rules", {}) as Dictionary
	return {
		"visible_offer_count": maxi(1, int(raw_root.get("visible_offer_count", 3))),
		"standard_offers_expire": bool(raw_root.get("standard_offers_expire", false)),
		"refill_behavior": str(raw_root.get("refill_behavior", "refill_single_slot_on_accept")),
		"composition_rules": {
			"avoid_family_duplicates_if_possible": bool(composition.get("avoid_family_duplicates_if_possible", true)),
			"avoid_same_region_duplicates_if_possible": bool(composition.get("avoid_same_region_duplicates_if_possible", true)),
			"avoid_exact_title_duplicates_if_possible": bool(composition.get("avoid_exact_title_duplicates_if_possible", true))
		}
	}


func _sanitize_generation_config(raw_root: Dictionary) -> Dictionary:
	return {
		"target_supplies_band": _to_min_max_dictionary(raw_root.get("target_supplies_band", {}), 10, 20),
		"duration_minutes_band": _to_min_max_dictionary(raw_root.get("duration_minutes_band", {}), 20, 75),
		"fallback_note_text": str(raw_root.get("fallback_note_text", "Provisioning run.")),
		"fallback_risk_text": str(raw_root.get("fallback_risk_text", "Minor setbacks possible."))
	}


func _build_index_by_id(rows: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id.is_empty():
			continue
		output[row_id] = row.duplicate(true)
	return output


func _build_id_lookup(rows: Array[Dictionary]) -> Dictionary:
	var output: Dictionary = {}
	for row in rows:
		var row_id := str(row.get("id", "")).strip_edges()
		if row_id.is_empty():
			continue
		output[row_id] = true
	return output


func _to_min_max_dictionary(raw_value: Variant, default_min: int, default_max: int) -> Dictionary:
	var minimum := default_min
	var maximum := default_max
	if raw_value is Dictionary:
		minimum = int((raw_value as Dictionary).get("min", default_min))
		maximum = int((raw_value as Dictionary).get("max", default_max))
	minimum = maxi(0, minimum)
	maximum = maxi(minimum, maximum)
	return {"min": minimum, "max": maximum}


func _to_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text.is_empty() or output.has(text):
				continue
			output.append(text)
	return output
