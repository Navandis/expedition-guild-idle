extends Control
class_name DispatchController

# DispatchController shows a minimal confirmation step before final dispatch.
# This keeps accidental taps from immediately consuming an expedition offer.

signal confirmed(expedition_data: Dictionary)
signal canceled

@onready var _name_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/NameLabel
@onready var _duration_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/DurationLabel
@onready var _risk_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/RiskLabel

var _expedition_data: Dictionary = {}


func _ready() -> void:
	$SafeArea/RootColumn/ButtonsRow/ConfirmButton.pressed.connect(_on_confirm_pressed)
	$SafeArea/RootColumn/ButtonsRow/CancelButton.pressed.connect(_on_cancel_pressed)


func set_expedition_data(expedition_data: Dictionary) -> void:
	# Store a deep copy so this screen has stable data even if upstream UI changes.
	_expedition_data = expedition_data.duplicate(true)
	_name_label.text = "Name: %s" % str(_expedition_data.get("display_name", "Unknown Expedition"))
	_duration_label.text = "Duration: %s min" % str(_expedition_data.get("duration_minutes", "?"))
	_risk_label.text = "Risk: %s" % str(_expedition_data.get("risk_label", "Unknown"))


func _on_confirm_pressed() -> void:
	if _expedition_data.is_empty():
		return
	confirmed.emit(_expedition_data.duplicate(true))


func _on_cancel_pressed() -> void:
	canceled.emit()
