extends Control
class_name PrepTierSelector

# File: PrepTierSelector.gd
# Scene-authored 3-step prep selector used by commission dispatch confirmation.
#
# Why this is a dedicated scene/script:
# - We avoid manual numeric input to keep the flow mobile-friendly.
# - Designers can edit button text/layout in PrepTierSelector.tscn.
# - Gameplay scripts consume a simple tier id + multipliers instead of raw fields.

signal tier_selected(tier_id: String)

const TIERS := {
	"under_prepared": {
		"id": "under_prepared",
		"title": "Under-Prepared",
		"description": "Lower commitment, higher failure risk.",
		"crew_multiplier": 0.8,
		"supplies_multiplier": 0.8,
		"success_weight_modifier": -0.20,
		"risk_shift": "+ High Risk"
	},
	"prepared": {
		"id": "prepared",
		"title": "Prepared",
		"description": "Baseline commitment and balanced outcomes.",
		"crew_multiplier": 1.0,
		"supplies_multiplier": 1.0,
		"success_weight_modifier": 0.0,
		"risk_shift": "Base Risk"
	},
	"over_prepared": {
		"id": "over_prepared",
		"title": "Over-Prepared",
		"description": "Higher commitment, better success odds.",
		"crew_multiplier": 1.3,
		"supplies_multiplier": 1.4,
		"success_weight_modifier": 0.20,
		"risk_shift": "Safer"
	}
}

@onready var _under_button: Button = $SelectorColumn/TierButtons/UnderPreparedButton
@onready var _prepared_button: Button = $SelectorColumn/TierButtons/PreparedButton
@onready var _over_button: Button = $SelectorColumn/TierButtons/OverPreparedButton
@onready var _summary_label: Label = $SelectorColumn/TierSummaryLabel

var _selected_tier_id := "prepared"


func _ready() -> void:
	# Buttons are authored in the scene so only behavior is scripted here.
	_under_button.pressed.connect(func() -> void:
		select_tier("under_prepared")
	)
	_prepared_button.pressed.connect(func() -> void:
		select_tier("prepared")
	)
	_over_button.pressed.connect(func() -> void:
		select_tier("over_prepared")
	)
	select_tier(_selected_tier_id)


func select_tier(tier_id: String) -> void:
	if not TIERS.has(tier_id):
		return
	_selected_tier_id = tier_id
	_sync_button_states()
	_refresh_summary()
	tier_selected.emit(_selected_tier_id)


func get_selected_tier_id() -> String:
	return _selected_tier_id


func get_selected_tier_data() -> Dictionary:
	return (TIERS.get(_selected_tier_id, TIERS["prepared"]) as Dictionary).duplicate(true)


func _sync_button_states() -> void:
	# Toggle_mode buttons give a clear single-choice selector without freeform text.
	_under_button.button_pressed = _selected_tier_id == "under_prepared"
	_prepared_button.button_pressed = _selected_tier_id == "prepared"
	_over_button.button_pressed = _selected_tier_id == "over_prepared"


func _refresh_summary() -> void:
	var tier := get_selected_tier_data()
	_summary_label.text = "%s · %s · Outcome Weight %+.0f%%" % [
		str(tier.get("title", "Prepared")),
		str(tier.get("risk_shift", "Base Risk")),
		float(tier.get("success_weight_modifier", 0.0)) * 100.0
	]
