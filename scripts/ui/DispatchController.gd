extends Control
class_name DispatchController

# DispatchController shows a minimal confirmation step before final dispatch.
# In the two-slot milestone, it also shows clear messaging when dispatch is
# blocked because both expedition slots are already occupied.

signal confirmed(expedition_data: Dictionary)
signal canceled

@onready var _name_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/NameLabel
@onready var _duration_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/DurationLabel
@onready var _risk_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/RiskLabel
@onready var _block_reason_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/BlockReasonLabel
@onready var _confirm_button: Button = $SafeArea/RootColumn/ButtonsRow/ConfirmButton

var _expedition_data: Dictionary = {}
var _dispatch_blocked := false


func _ready() -> void:
	# Controller owns button wiring so scene stays declarative in .tscn.
	_confirm_button.pressed.connect(_on_confirm_pressed)
	$SafeArea/RootColumn/ButtonsRow/CancelButton.pressed.connect(_on_cancel_pressed)
	_refresh_block_state()


func set_expedition_data(expedition_data: Dictionary) -> void:
	# Store a deep copy so this screen has stable data even if upstream UI changes.
	_expedition_data = expedition_data.duplicate(true)
	_name_label.text = "Name: %s" % str(_expedition_data.get("display_name", "Unknown Expedition"))
	_duration_label.text = "Duration: %s min" % str(_expedition_data.get("duration_minutes", "?"))
	_risk_label.text = "Risk: %s" % str(_expedition_data.get("risk_label", "Unknown"))


func set_dispatch_blocked(is_blocked: bool, block_message: String = "") -> void:
	_dispatch_blocked = is_blocked
	if _dispatch_blocked:
		var resolved_message := block_message.strip_edges()
		if resolved_message.is_empty():
			resolved_message = "Dispatch blocked: both expedition slots are occupied. Collect a pending report to free a slot."
		_block_reason_label.text = resolved_message
	else:
		_block_reason_label.text = "Both slots are available. Confirm to start this expedition."
	_refresh_block_state()


func _refresh_block_state() -> void:
	if _confirm_button == null:
		return
	_confirm_button.disabled = _dispatch_blocked


func _on_confirm_pressed() -> void:
	# Guard clauses keep this signal safe from race conditions and bad payloads.
	if _dispatch_blocked:
		return
	if _expedition_data.is_empty():
		return
	confirmed.emit(_expedition_data.duplicate(true))


func _on_cancel_pressed() -> void:
	canceled.emit()
