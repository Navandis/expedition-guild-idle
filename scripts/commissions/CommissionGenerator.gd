extends RefCounted
class_name CommissionGenerator

# -----------------------------------------------------------------------------
# CommissionGenerator
# -----------------------------------------------------------------------------
# Purpose:
# - Build commission offers from authored commission data.
# - Respect unlocked/reachable region constraints as a hard requirement.
# - Apply soft composition rules (family/patron/region/risk diversity).
#
# Runtime boundary:
# - This generator creates offer dictionaries only.
# - It does not own save state or mutate authored JSON.
# -----------------------------------------------------------------------------

var _rng := RandomNumberGenerator.new()
var _data: Dictionary = {}


func _init(seed_override: int = 0) -> void:
	if seed_override == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_override


func set_commission_data(commission_data: Dictionary) -> void:
	_data = commission_data.duplicate(true)


func generate_board(unlocked_region_ids: Array[String], existing_offers: Array[Dictionary], requested_count: int = -1) -> Array[Dictionary]:
	# Hard rule: all generated offers must come from currently unlocked/reachable regions.
	if unlocked_region_ids.is_empty():
		return []

	var board_rules := _data.get("board_rules", {}) as Dictionary
	var visible_count := requested_count if requested_count > 0 else int(board_rules.get("visible_offer_count", 3))
	visible_count = maxi(1, visible_count)

	# Standard commissions persist: keep existing entries (unless caller supplies none)
	# and only fill missing slots.
	var output: Array[Dictionary] = []
	for offer in existing_offers:
		if output.size() >= visible_count:
			break
		if _is_offer_region_allowed(offer, unlocked_region_ids):
			output.append((offer as Dictionary).duplicate(true))

	while output.size() < visible_count:
		var offer := _generate_offer_for_slot(unlocked_region_ids, output)
		if offer.is_empty():
			break
		output.append(offer)

	return output


func generate_single_offer(unlocked_region_ids: Array[String], board_so_far: Array[Dictionary]) -> Dictionary:
	if unlocked_region_ids.is_empty():
		return {}
	return _generate_offer_for_slot(unlocked_region_ids, board_so_far)


func _generate_offer_for_slot(unlocked_region_ids: Array[String], board_so_far: Array[Dictionary]) -> Dictionary:
	var candidates := _build_offer_candidates(unlocked_region_ids)
	if candidates.is_empty():
		return {}

	var board_rules := _data.get("board_rules", {}) as Dictionary
	var composition := board_rules.get("composition_rules", {}) as Dictionary
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


func _build_offer_candidates(unlocked_region_ids: Array[String]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var indexes := _data.get("indexes", {}) as Dictionary
	var templates_value: Variant = _data.get("objective_templates", [])
	var templates: Array = templates_value if templates_value is Array else []

	for template in templates:
		if not (template is Dictionary):
			continue
		var template_row := template as Dictionary
		var regions := _to_string_array(template_row.get("compatible_region_ids", []))
		var allowed_regions := _intersection_string_arrays(regions, unlocked_region_ids)
		if allowed_regions.is_empty():
			continue

		var patron_ids := _to_string_array(template_row.get("compatible_patron_ids", []))
		if patron_ids.is_empty():
			continue

		for patron_id in patron_ids:
			var patron := (indexes.get("patron_by_id", {}) as Dictionary).get(patron_id, {}) as Dictionary
			if patron.is_empty():
				continue

			for region_id in allowed_regions:
				candidates.append({
					"family_id": str(template_row.get("family_id", "")),
					"template": template_row.duplicate(true),
					"patron": patron.duplicate(true),
					"region_id": region_id
				})

	return candidates


func _score_candidate_for_board(candidate: Dictionary, board_so_far: Array[Dictionary], composition: Dictionary) -> float:
	var score := 1.0
	var family_id := str(candidate.get("family_id", ""))
	var patron_id := str((candidate.get("patron", {}) as Dictionary).get("id", ""))
	var region_id := str(candidate.get("region_id", ""))

	# Soft rule: avoid too many identical families if alternatives exist.
	if bool(composition.get("avoid_family_duplicates_if_possible", true)):
		var family_count := _count_key_match(board_so_far, "family_id", family_id)
		score *= (0.45 if family_count > 0 else 1.15)

	# Soft rule: avoid too many identical patrons if alternatives exist.
	if bool(composition.get("avoid_patron_duplicates_if_possible", true)):
		var patron_count := _count_nested_key_match(board_so_far, "patron_id", patron_id)
		score *= (0.40 if patron_count > 0 else 1.10)

	# Soft rule: avoid same-region spam when multiple unlocked regions exist.
	if bool(composition.get("avoid_same_region_all_slots_if_possible", true)):
		var region_count := _count_key_match(board_so_far, "region_id", region_id)
		score *= (0.60 if region_count > 0 else 1.10)

	# Soft risk spread: for this first backend, preselecting likely target slot risk
	# gives simple diversity without overbuilding later risk systems.
	var target_risks := _to_string_array(composition.get("target_risk_spread", []))
	if board_so_far.size() < target_risks.size():
		var target := target_risks[board_so_far.size()]
		if not target.is_empty():
			var likely_risk := _pick_risk_band(candidate)
			if _risk_matches_target(likely_risk, target):
				score *= 1.2
			else:
				score *= 0.8

	return maxf(0.01, score)


func _finalize_offer(candidate: Dictionary) -> Dictionary:
	var template := candidate.get("template", {}) as Dictionary
	var patron := candidate.get("patron", {}) as Dictionary
	var family := _get_family_by_id(str(candidate.get("family_id", "")))
	var tier := _get_tier_by_id(str(patron.get("tier_id", "")))

	var risk_band := _pick_risk_band(candidate)
	var duration_band := _pick_duration_band(family)
	var duration_minutes := _pick_duration_minutes(duration_band)
	var brief_style := _pick_brief_style(template, patron)

	var context := _roll_context_tokens(template)
	context["region_name"] = _format_region_name(str(candidate.get("region_id", "")))
	var brief_text := _render_template_text(str(template.get("template_text", "")), context)

	var offer_id := "comm_%d_%06d" % [Time.get_unix_time_from_system(), _rng.randi_range(0, 999999)]
	return {
		"offer_id": offer_id,
		"family_id": str(candidate.get("family_id", "")),
		"family_name": str(family.get("name", "")),
		"patron_id": str(patron.get("id", "")),
		"patron_name": str(patron.get("name", "")),
		"patron_tier_id": str(tier.get("id", "")),
		"patron_tier_index": int(tier.get("tier_index", 1)),
		"patron_tier_name": str(tier.get("name", "")),
		"region_id": str(candidate.get("region_id", "")),
		"objective_template_id": str(template.get("id", "")),
		"brief_style": brief_style,
		"brief_text": brief_text,
		"risk_band": risk_band,
		"duration_band": duration_band,
		"duration_minutes": duration_minutes,
		"required_tags": _to_string_array(template.get("required_tag_biases", [])),
		"preferred_tags": _merge_unique(
			_to_string_array(template.get("preferred_tag_biases", [])),
			_to_string_array(family.get("typical_requirement_tags", []))
		),
		"crew_required": _roll_min_max(family.get("base_crew_required", {})),
		"supplies_required": _roll_min_max(family.get("base_supplies_required", {})),
		"reward_scaffold": _build_reward_scaffold(family, tier, template, risk_band),
		"risk_scaffold": {
			"risk_band": risk_band,
			"template_modifier": float((template.get("risk_modifiers", {}) as Dictionary).get(risk_band, 1.0))
		},
		"outcome_bands": _to_string_array((_data.get("generation_config", {}) as Dictionary).get("outcome_band_labels", [])),
		"expires_at_unix": 0,
		"metadata": {
			"status": "board_visible",
			"generated_at_unix": Time.get_unix_time_from_system(),
			"context_tokens": context
		}
	}


func _pick_risk_band(candidate: Dictionary) -> String:
	var template := candidate.get("template", {}) as Dictionary
	var family := _get_family_by_id(str(candidate.get("family_id", "")))
	var generation := _data.get("generation_config", {}) as Dictionary

	var weights := _to_float_dictionary(generation.get("risk_weights_default", {}))
	var family_allowed := _to_string_array(family.get("default_risk_bands", []))
	if family_allowed.is_empty():
		family_allowed = ["low", "moderate", "high"]

	# Restrict template-overridden risk choices when provided.
	var template_modifiers := _to_float_dictionary(template.get("risk_modifiers", {}))
	if not template_modifiers.is_empty():
		var mod_filtered: Array[String] = []
		for band in family_allowed:
			if template_modifiers.has(band):
				mod_filtered.append(band)
		if not mod_filtered.is_empty():
			family_allowed = mod_filtered

	var weighted_rows: Array[Dictionary] = []
	for band in family_allowed:
		var weight := maxf(0.01, float(weights.get(band, 1.0)))
		weight *= float(template_modifiers.get(band, 1.0))
		weighted_rows.append({"id": band, "w": weight})

	var picked := _weighted_pick(weighted_rows, "w")
	return str(picked.get("id", "moderate"))


func _pick_duration_band(family: Dictionary) -> String:
	var allowed := _to_string_array(family.get("default_duration_bands", []))
	if allowed.is_empty():
		allowed = ["short", "medium", "long"]

	var weights := _to_float_dictionary((_data.get("generation_config", {}) as Dictionary).get("duration_band_weights_default", {}))
	var weighted_rows: Array[Dictionary] = []
	for band in allowed:
		weighted_rows.append({"id": band, "w": maxf(0.01, float(weights.get(band, 1.0)))})
	var picked := _weighted_pick(weighted_rows, "w")
	return str(picked.get("id", allowed[0]))


func _pick_duration_minutes(duration_band: String) -> int:
	# Duration minute ranges are authored in commission_families.json and loaded
	# into _data["duration_band_minutes"].
	var fallback := {
		"short": {"min": 10, "max": 15},
		"medium": {"min": 25, "max": 35},
		"long": {"min": 50, "max": 70}
	}
	var authored := _data.get("duration_band_minutes", {}) as Dictionary
	var row := authored.get(duration_band, fallback.get(duration_band, {"min": 25, "max": 35})) as Dictionary
	return _rng.randi_range(int(row.get("min", 25)), int(row.get("max", 35)))


func _pick_brief_style(template: Dictionary, patron: Dictionary) -> String:
	var generation := _data.get("generation_config", {}) as Dictionary
	var default_weights := _to_float_dictionary(generation.get("brief_style_weights_default", {}))
	var patron_bias := _to_float_dictionary(patron.get("brief_style_bias", {}))
	var allowed := _to_string_array(template.get("brief_style_allowed", []))
	if allowed.is_empty():
		allowed = ["explicit", "guided", "inferred"]

	var weighted_rows: Array[Dictionary] = []
	for style in allowed:
		var weight := maxf(0.01, float(default_weights.get(style, 1.0)))
		weight *= maxf(0.01, float(patron_bias.get(style, 1.0)))
		weighted_rows.append({"id": style, "w": weight})

	var picked := _weighted_pick(weighted_rows, "w")
	return str(picked.get("id", allowed[0]))


func _build_reward_scaffold(family: Dictionary, tier: Dictionary, template: Dictionary, risk_band: String) -> Dictionary:
	# Scaffold-only output for now; exact economy values can be tuned later.
	# This keeps reward/risk pipeline future-proof without overbuilding.
	var reward_modifiers := template.get("reward_modifiers", {}) as Dictionary
	var tier_index := maxi(1, int(tier.get("tier_index", 1)))
	var risk_mult := 1.0
	match risk_band:
		"low":
			risk_mult = 0.9
		"moderate":
			risk_mult = 1.0
		"high":
			risk_mult = 1.25

	var base_gold := 80.0 + float(tier_index * 40)
	var gold_multiplier := float(reward_modifiers.get("gold_multiplier", 1.0))
	var standing_multiplier := float(reward_modifiers.get("standing_multiplier", 1.0))

	return {
		"reward_focus": _to_string_array(family.get("reward_focus", [])),
		"reward_bias": str(tier.get("reward_bias", "medium")),
		"standing_bias": str(tier.get("standing_bias", "medium")),
		"estimated_gold": int(round(base_gold * gold_multiplier * risk_mult)),
		"estimated_standing": maxf(1.0, float(tier_index) * standing_multiplier),
		"modifiers": reward_modifiers.duplicate(true)
	}


func _roll_context_tokens(template: Dictionary) -> Dictionary:
	var context_tokens := template.get("context_tokens", {}) as Dictionary
	var output: Dictionary = {}
	for key in context_tokens.keys():
		var token_key := str(key)
		var choices := _to_string_array(context_tokens.get(key, []))
		if choices.is_empty():
			continue
		output[token_key] = choices[_rng.randi_range(0, choices.size() - 1)]
	return output


func _render_template_text(template_text: String, context: Dictionary) -> String:
	var output := template_text
	for key in context.keys():
		output = output.replace("[%s]" % str(key), str(context.get(key, "")))
	return output


func _is_offer_region_allowed(offer: Dictionary, unlocked_region_ids: Array[String]) -> bool:
	var region_id := str(offer.get("region_id", "")).strip_edges()
	return not region_id.is_empty() and unlocked_region_ids.has(region_id)


func _risk_matches_target(risk_band: String, target: String) -> bool:
	match target:
		"low_or_moderate":
			return risk_band == "low" or risk_band == "moderate"
		"moderate_or_high":
			return risk_band == "moderate" or risk_band == "high"
		_:
			return risk_band == target


func _get_family_by_id(family_id: String) -> Dictionary:
	var indexes := _data.get("indexes", {}) as Dictionary
	return ((indexes.get("family_by_id", {}) as Dictionary).get(family_id, {}) as Dictionary).duplicate(true)


func _get_tier_by_id(tier_id: String) -> Dictionary:
	var indexes := _data.get("indexes", {}) as Dictionary
	return ((indexes.get("tier_by_id", {}) as Dictionary).get(tier_id, {}) as Dictionary).duplicate(true)


func _count_key_match(rows: Array[Dictionary], key: String, value: String) -> int:
	var count := 0
	for row in rows:
		if str(row.get(key, "")) == value:
			count += 1
	return count


func _count_nested_key_match(rows: Array[Dictionary], key: String, value: String) -> int:
	var count := 0
	for row in rows:
		if str(row.get(key, "")) == value:
			count += 1
	return count


func _weighted_pick(rows: Array[Dictionary], weight_key: String) -> Dictionary:
	if rows.is_empty():
		return {}
	var total := 0.0
	for row in rows:
		total += maxf(0.0, float(row.get(weight_key, 0.0)))
	if total <= 0.0:
		return (rows[_rng.randi_range(0, rows.size() - 1)] as Dictionary).duplicate(true)

	var roll := _rng.randf_range(0.0, total)
	var cursor := 0.0
	for row in rows:
		cursor += maxf(0.0, float(row.get(weight_key, 0.0)))
		if roll <= cursor:
			return (row as Dictionary).duplicate(true)
	return (rows[rows.size() - 1] as Dictionary).duplicate(true)


func _roll_min_max(value: Variant) -> int:
	if not (value is Dictionary):
		return 1
	var min_v := maxi(0, int((value as Dictionary).get("min", 1)))
	var max_v := maxi(min_v, int((value as Dictionary).get("max", min_v)))
	return _rng.randi_range(min_v, max_v)


func _intersection_string_arrays(a: Array[String], b: Array[String]) -> Array[String]:
	var output: Array[String] = []
	for item in a:
		if b.has(item) and not output.has(item):
			output.append(item)
	return output


func _merge_unique(a: Array[String], b: Array[String]) -> Array[String]:
	var output := a.duplicate()
	for item in b:
		if not output.has(item):
			output.append(item)
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


func _to_float_dictionary(value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if not (value is Dictionary):
		return output
	for key in (value as Dictionary).keys():
		var text_key := str(key).strip_edges()
		if text_key.is_empty():
			continue
		output[text_key] = maxf(0.0, float((value as Dictionary).get(key, 0.0)))
	return output


func _format_region_name(region_id: String) -> String:
	if region_id.is_empty():
		return "Unknown Region"
	var parts := region_id.split("_")
	for i in parts.size():
		parts[i] = parts[i].capitalize()
	return " ".join(parts)
