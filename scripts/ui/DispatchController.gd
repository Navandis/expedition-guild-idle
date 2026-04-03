extends Control
class_name DispatchController

# DispatchController shows a minimal confirmation step before final dispatch.
# It computes messaging from a provided available-slot count so the label works
# for 1, 2, or more slots without hardcoded wording.
# When confirm is successful, GameManager routes back to Expedition Board so
# players can quickly plan or launch the next expedition.

signal confirmed(expedition_data: Dictionary)
signal canceled

@onready var _name_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/NameLabel
@onready var _duration_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/DurationLabel
@onready var _risk_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/RiskLabel
@onready var _block_reason_label: Label = $SafeArea/RootColumn/DispatchPanel/Rows/BlockReasonLabel
@onready var _confirm_button: Button = $SafeArea/RootColumn/ButtonsRow/ConfirmButton

var _expedition_data: Dictionary = {}
var _dispatch_blocked := false
const _AVAILABLE_MESSAGE_COLOR := Color(0.38, 0.74, 0.34, 1.0)
const _UNAVAILABLE_MESSAGE_COLOR := Color(0.86, 0.28, 0.2, 1.0)


func _ready() -> void:
	# Controller owns button wiring so scene stays declarative in .tscn.
	_confirm_button.pressed.connect(_on_confirm_pressed)
	$SafeArea/RootColumn/ButtonsRow/CancelButton.pressed.connect(_on_cancel_pressed)
	_refresh_block_state()


func set_expedition_data(expedition_data: Dictionary) -> void:
	# Store a deep copy so this screen has stable data even if upstream UI changes.
	_expedition_data = expedition_data.duplicate(true)
	_name_label.text = "Name: %s" % str(_expedition_data.get("display_name", "Unknown Expedition"))
	var duration_minutes := int(_expedition_data.get("duration_minutes", 0))
	_duration_label.text = "Duration: %s" % (TimeFormat.format_minutes_hms(duration_minutes) if duration_minutes > 0 else "?")
	_risk_label.text = "Risk: %s" % str(_expedition_data.get("risk_label", "Unknown"))


func set_dispatch_availability(available_slot_count: int, block_message: String = "") -> void:
	# Dispatch is blocked only when no slot is available right now.
	_dispatch_blocked = available_slot_count <= 0
	if _dispatch_blocked:
		var resolved_message := block_message.strip_edges()
		if resolved_message.is_empty():
			resolved_message = "Dispatch blocked: all expedition slots are full."
		_block_reason_label.text = resolved_message
		_block_reason_label.add_theme_color_override("font_color", _UNAVAILABLE_MESSAGE_COLOR)
	else:
		_block_reason_label.text = build_dispatch_availability_message(available_slot_count)
		_block_reason_label.add_theme_color_override("font_color", _AVAILABLE_MESSAGE_COLOR)
	_refresh_block_state()


func build_dispatch_availability_message(count: int) -> String:
	# Singular/plural formatting keeps the UX accurate for any slot count.
	if count == 1:
		return "1 slot is available. Confirm to start this expedition"
	return "%d slots are available. Confirm to start this expedition" % count


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
