extends Button
class_name ExpeditionCardView

signal pressed_with_data(expedition_data: Dictionary)

@onready var _name_label: Label = %DisplayNameLabel
@onready var _duration_label: Label = %DurationLabel
@onready var _risk_label: Label = %RiskLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _hazard_label: Label = %HazardLabel

var expedition_data: Dictionary = {}


func _ready() -> void:
	pressed.connect(_on_pressed)


func set_expedition_data(data: Dictionary) -> void:
	expedition_data = data.duplicate(true)
	_name_label.text = str(expedition_data.get("display_name", "Unknown Expedition"))
	_duration_label.text = "Duration: %s min" % str(expedition_data.get("duration_minutes", "?"))
	_risk_label.text = "Risk: %s" % str(expedition_data.get("risk_label", "Unknown"))
	_reward_label.text = "Reward: %s" % str(expedition_data.get("reward_profile", "balanced"))
	_hazard_label.text = "Hazard: %s" % str(expedition_data.get("hazard", "unknown"))


func set_selected(is_selected: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0) if is_selected else Color(0.86, 0.86, 0.86)


func _on_pressed() -> void:
	pressed_with_data.emit(expedition_data.duplicate(true))
