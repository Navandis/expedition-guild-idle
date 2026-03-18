extends RefCounted
class_name UpgradeSystem

# UpgradeSystem is the day-3 progression layer for the prototype.
# It loads upgrade definitions from JSON, tracks owned upgrade IDs, validates
# purchases against current gold, and exposes tiny effect totals that other
# systems can apply to future expeditions.

const UPGRADES_PATH := "res://data/upgrades/guild_upgrades.json"
const REQUIRED_KEYS := [
	"id",
	"name",
	"description",
	"cost_gold",
	"effect_type",
	"effect_value"
]

const FALLBACK_UPGRADES := [
	{
		"id": "survey_tools_1",
		"name": "Survey Tools",
		"description": "Reduces expedition duration by 10%.",
		"cost_gold": 300,
		"effect_type": "duration_multiplier",
		"effect_value": -0.10
	},
	{
		"id": "guild_accounting_1",
		"name": "Guild Accounting",
		"description": "Increases gold rewards by 15%.",
		"cost_gold": 350,
		"effect_type": "gold_multiplier",
		"effect_value": 0.15
	},
	{
		"id": "field_briefing_1",
		"name": "Field Briefing",
		"description": "Adds +5% base success chance.",
		"cost_gold": 250,
		"effect_type": "success_bonus",
		"effect_value": 0.05
	}
]

var _json_loader := JsonLoader.new()
var _upgrades: Array[Dictionary] = []
var _owned_upgrade_ids: Dictionary = {}


func _init() -> void:
	_reload_upgrades()


func get_all_upgrades() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for upgrade in _upgrades:
		rows.append(upgrade.duplicate(true))
	return rows


func is_owned(upgrade_id: String) -> bool:
	return bool(_owned_upgrade_ids.get(upgrade_id, false))


func can_purchase_upgrade(upgrade_id: String, current_gold: int) -> bool:
	var upgrade := _get_upgrade_by_id(upgrade_id)
	if upgrade.is_empty():
		return false
	if is_owned(upgrade_id):
		return false

	# Purchase validation: player must have enough gold and upgrade must not be owned yet.
	return current_gold >= int(upgrade.get("cost_gold", 0))


func try_purchase_upgrade(upgrade_id: String, current_gold: int) -> Dictionary:
	var upgrade := _get_upgrade_by_id(upgrade_id)
	if upgrade.is_empty():
		return {
			"ok": false,
			"reason": "Upgrade not found.",
			"gold_spent": 0,
			"remaining_gold": current_gold
		}
	if is_owned(upgrade_id):
		return {
			"ok": false,
			"reason": "Upgrade already owned.",
			"gold_spent": 0,
			"remaining_gold": current_gold
		}

	var cost := int(upgrade.get("cost_gold", 0))
	if current_gold < cost:
		return {
			"ok": false,
			"reason": "Not enough gold.",
			"gold_spent": 0,
			"remaining_gold": current_gold
		}

	_owned_upgrade_ids[upgrade_id] = true
	return {
		"ok": true,
		"reason": "Purchased.",
		"gold_spent": cost,
		"remaining_gold": current_gold - cost
	}


func get_effects_summary() -> Dictionary:
	# This combines all owned upgrade effects into a single, readable dictionary.
	var summary := {
		"duration_multiplier": 1.0,
		"gold_multiplier": 1.0,
		"success_bonus": 0.0
	}

	for upgrade in _upgrades:
		var upgrade_id := str(upgrade.get("id", ""))
		if not is_owned(upgrade_id):
			continue

		var effect_type := str(upgrade.get("effect_type", ""))
		var effect_value := float(upgrade.get("effect_value", 0.0))

		match effect_type:
			"duration_multiplier":
				summary["duration_multiplier"] = float(summary["duration_multiplier"]) + effect_value
			"gold_multiplier":
				summary["gold_multiplier"] = float(summary["gold_multiplier"]) + effect_value
			"success_bonus":
				summary["success_bonus"] = float(summary["success_bonus"]) + effect_value

	# Clamp multipliers to safe minimums so malformed data cannot invert values.
	summary["duration_multiplier"] = max(0.20, float(summary["duration_multiplier"]))
	summary["gold_multiplier"] = max(0.20, float(summary["gold_multiplier"]))
	summary["success_bonus"] = clampf(float(summary["success_bonus"]), 0.0, 0.95)
	return summary


func _reload_upgrades() -> void:
	# JSON loading: we validate required keys and fall back to built-in rows if needed.
	var loaded_rows := _json_loader.load_array(UPGRADES_PATH, REQUIRED_KEYS, FALLBACK_UPGRADES)
	_upgrades.clear()

	for row in loaded_rows:
		_upgrades.append({
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "Unknown Upgrade")),
			"description": str(row.get("description", "")),
			"cost_gold": int(row.get("cost_gold", 0)),
			"effect_type": str(row.get("effect_type", "")),
			"effect_value": float(row.get("effect_value", 0.0))
		})


func _get_upgrade_by_id(upgrade_id: String) -> Dictionary:
	for upgrade in _upgrades:
		if str(upgrade.get("id", "")) == upgrade_id:
			return upgrade
	return {}
