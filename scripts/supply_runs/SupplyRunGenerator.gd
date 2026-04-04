extends RefCounted
class_name SupplyRunGenerator

# -----------------------------------------------------------------------------
# SupplyRunGenerator
# -----------------------------------------------------------------------------
# Purpose:
# - Build finite Supply Run board offers from authored supply-run data.
# - Enforce unlocked-region eligibility as a hard generation rule.
# - Apply light composition rules so boards stay readable and curated.
#
# This generator is runtime-agnostic: it only builds offer dictionaries and
# never writes to authored JSON or player save data directly.
# -----------------------------------------------------------------------------

var _rng := RandomNumberGenerator.new()
var _data: Dictionary = {}


func _init(seed_override: int = 0) -> void:
	if seed_override == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_override


func set_supply_run_data(supply_data: Dictionary) -> void:
	_data = supply_data.duplicate(true)


func generate_board(unlocked_regions: Array[Dictionary], existing_offers: Array[Dictionary], requested_count: int = -1) -> Array[Dictionary]:
	# Hard rule: offers may only come from unlocked/serviceable regions.
	if unlocked_regions.is_empty():
		return []

	var board_rules := _data.get("board_rules", {}) as Dictionary
	var visible_count := requested_count if requested_count > 0 else int(board_rules.get("visible_offer_count", 3))
	visible_count = maxi(1, visible_count)

	# Persistent-board behavior: keep existing standard offers and only fill holes.
	var output: Array[Dictionary] = []
	for offer in existing_offers:
		if output.size() >= visible_count:
			break
		if _is_offer_region_allowed(offer, unlocked_regions):
			output.append((offer as Dictionary).duplicate(true))

	while output.size() < visible_count:
		var offer := _generate_offer_for_slot(unlocked_regions, output)
		if offer.is_empty():
			break
		output.append(offer)

	return output


func generate_single_offer(unlocked_regions: Array[Dictionary], board_so_far: Array[Dictionary]) -> Dictionary:
	if unlocked_regions.is_empty():
		return {}
	return _generate_offer_for_slot(unlocked_regions, board_so_far)


func _generate_offer_for_slot(unlocked_regions: Array[Dictionary], board_so_far: Array[Dictionary]) -> Dictionary:
	var candidates := _build_offer_candidates(unlocked_regions)
	if candidates.is_empty():
		return {}

	var composition := (_data.get("board_rules", {}) as Dictionary).get("composition_rules", {}) as Dictionary
	var scored: Array[Dictionary] = []
	for candidate in candidates:
		var score := _score_candidate_for_board(candidate, board_so_far, composition)
		if score <= 0.0:
			continue
		var row := candidate.duplicate(true)
		row["_score"] = score
		scored.append(row)

	var selected := _weighted_pick(scored, "_score")
	if selected.is_empty():
		selected = (candidates[_rng.randi_range(0, candidates.size() - 1)] as Dictionary).duplicate(true)

	selected.erase("_score")
	return _finalize_offer(selected)


func _build_offer_candidates(unlocked_regions: Array[Dictionary]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var indexes := _data.get("indexes", {}) as Dictionary
	var family_by_id := indexes.get("family_by_id", {}) as Dictionary
	var templates_value: Variant = _data.get("templates", [])
	var templates: Array = templates_value if templates_value is Array else []

	for template in templates:
		if not (template is Dictionary):
			continue
		var template_row := template as Dictionary
		var family := family_by_id.get(str(template_row.get("family_id", "")), {}) as Dictionary
		if family.is_empty():
			continue

		for region in unlocked_regions:
			if not (region is Dictionary):
				continue
			var region_id := str((region as Dictionary).get("id", "")).strip_edges()
			if region_id.is_empty():
				continue
			if not _template_supports_region(template_row, region_id):
				continue

			candidates.append({
				"template": template_row.duplicate(true),
				"family": family.duplicate(true),
				"region_id": region_id,
				"region_name": str((region as Dictionary).get("name", region_id))
			})

	return candidates


func _score_candidate_for_board(candidate: Dictionary, board_so_far: Array[Dictionary], composition: Dictionary) -> float:
	var score := 1.0
	var family_id := str((candidate.get("family", {}) as Dictionary).get("id", ""))
	var region_id := str(candidate.get("region_id", ""))
	var title := _render_title(candidate)

	if bool(composition.get("avoid_family_duplicates_if_possible", true)):
		var family_count := _count_key_match(board_so_far, "run_family_id", family_id)
		score *= (0.55 if family_count > 0 else 1.15)

	if bool(composition.get("avoid_same_region_duplicates_if_possible", true)):
		var region_count := _count_key_match(board_so_far, "region_id", region_id)
		score *= (0.65 if region_count > 0 else 1.10)

	if bool(composition.get("avoid_exact_title_duplicates_if_possible", true)):
		var title_count := _count_key_match(board_so_far, "title", title)
		score *= (0.50 if title_count > 0 else 1.05)

	return maxf(0.01, score)


func _finalize_offer(candidate: Dictionary) -> Dictionary:
	var family := candidate.get("family", {}) as Dictionary
	var generation := _data.get("generation_config", {}) as Dictionary
	var supplies_band := _to_min_max_dictionary(family.get("supplies_yield_estimate", {}), 10, 20)
	var target_band := _to_min_max_dictionary(generation.get("target_supplies_band", {}), 10, 20)
	var duration_band := _to_min_max_dictionary(family.get("duration_minutes", {}), 20, 45)
	var global_duration_band := _to_min_max_dictionary(generation.get("duration_minutes_band", {}), 20, 75)

	# Keep v1 payouts inside the provisional working range (10-20 supplies).
	supplies_band["min"] = clampi(int(supplies_band.get("min", 10)), int(target_band.get("min", 10)), int(target_band.get("max", 20)))
	supplies_band["max"] = clampi(int(supplies_band.get("max", 20)), int(supplies_band.get("min", 10)), int(target_band.get("max", 20)))
	# Match supplies behavior: clamp family durations to the authored global
	# generation band so config edits always constrain runtime offer rolls.
	duration_band["min"] = clampi(int(duration_band.get("min", 20)), int(global_duration_band.get("min", 20)), int(global_duration_band.get("max", 75)))
	duration_band["max"] = clampi(int(duration_band.get("max", 75)), int(duration_band.get("min", 20)), int(global_duration_band.get("max", 75)))

	var crew_band := _to_min_max_dictionary(family.get("crew_required", {}), 2, 3)
	var gold_band := _to_min_max_dictionary(family.get("gold_cost", {}), 0, 0)

	var duration_minutes := _roll_min_max(duration_band)
	var crew_required := _roll_min_max(crew_band)
	var gold_cost := _roll_min_max(gold_band)
	var supplies_yield := _roll_min_max(supplies_band)

	var offer_id := "srun_%d_%06d" % [Time.get_unix_time_from_system(), _rng.randi_range(0, 999999)]
	return {
		"offer_id": offer_id,
		"region_id": str(candidate.get("region_id", "")),
		"region_name": str(candidate.get("region_name", "Unknown Region")),
		"title": _render_title(candidate),
		"run_family_id": str(family.get("id", "")),
		"run_family_name": str(family.get("name", "Supply Run")),
		"duration_minutes": duration_minutes,
		"crew_required": crew_required,
		"gold_cost": gold_cost,
		"supplies_yield_estimate": supplies_yield,
		"note_text": _pick_text_option(
			_to_string_array(family.get("note_text_options", [])),
			str(generation.get("fallback_note_text", "Provisioning run."))
		),
		"risk_text": _pick_text_option(
			_to_string_array(family.get("risk_text_options", [])),
			str(generation.get("fallback_risk_text", "Minor setbacks possible."))
		),
		"metadata": {
			"status": "board_visible",
			"generated_at_unix": Time.get_unix_time_from_system(),
			"template_id": str((candidate.get("template", {}) as Dictionary).get("id", ""))
		}
	}


func _template_supports_region(template: Dictionary, region_id: String) -> bool:
	var compatible := _to_string_array(template.get("compatible_region_ids", []))
	if compatible.is_empty():
		return true
	return compatible.has(region_id)


func _render_title(candidate: Dictionary) -> String:
	var template := candidate.get("template", {}) as Dictionary
	var title_template := str(template.get("title_template", "Supply Run"))
	var region_name := str(candidate.get("region_name", "Unknown Region"))
	return title_template.replace("{region_name}", region_name)


func _is_offer_region_allowed(offer: Dictionary, unlocked_regions: Array[Dictionary]) -> bool:
	var offer_region := str(offer.get("region_id", "")).strip_edges()
	if offer_region.is_empty():
		return false
	for region in unlocked_regions:
		if str((region as Dictionary).get("id", "")).strip_edges() == offer_region:
			return true
	return false


func _count_key_match(rows: Array[Dictionary], key: String, expected: Variant) -> int:
	var count := 0
	for row in rows:
		if not (row is Dictionary):
			continue
		if (row as Dictionary).get(key, null) == expected:
			count += 1
	return count


func _weighted_pick(rows: Array[Dictionary], weight_key: String) -> Dictionary:
	if rows.is_empty():
		return {}

	var total := 0.0
	for row in rows:
		total += maxf(0.0, float((row as Dictionary).get(weight_key, 0.0)))

	if total <= 0.0:
		return (rows[_rng.randi_range(0, rows.size() - 1)] as Dictionary).duplicate(true)

	var roll := _rng.randf_range(0.0, total)
	var acc := 0.0
	for row in rows:
		acc += maxf(0.0, float((row as Dictionary).get(weight_key, 0.0)))
		if roll <= acc:
			return (row as Dictionary).duplicate(true)

	return (rows[rows.size() - 1] as Dictionary).duplicate(true)


func _roll_min_max(min_max: Dictionary) -> int:
	var minimum := int(min_max.get("min", 0))
	var maximum := int(min_max.get("max", minimum))
	if maximum < minimum:
		maximum = minimum
	if maximum == minimum:
		return minimum
	return _rng.randi_range(minimum, maximum)


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


func _pick_text_option(options: Array[String], fallback: String) -> String:
	if options.is_empty():
		return fallback
	return options[_rng.randi_range(0, options.size() - 1)]
