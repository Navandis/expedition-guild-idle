extends Button
class_name ExpeditionCardView

# ExpeditionCardView is a thin "presenter" for one expedition offer.
# It receives already-built expedition data and maps fields to labels.

signal pressed_with_data(expedition_data: Dictionary)

var _name_label: Label
var _duration_label: Label
var _risk_label: Label
var _reward_label: Label
var _hazard_label: Label

var expedition_data: Dictionary = {}
var _upgrade_effects: Dictionary = {}


func _ready() -> void:
	_resolve_labels()
	pressed.connect(_on_pressed)


func set_expedition_data(data: Dictionary) -> void:
	# Cards can receive data immediately after being instantiated.
	# Resolve label references here as a safeguard when _ready() has
	# not run yet.
	if not _resolve_labels():
		push_error("ExpeditionCardView.set_expedition_data: Missing one or more label nodes.")
		return

	# Deep copy keeps the card's local state isolated from external changes.
	expedition_data = data.duplicate(true)
	_refresh_labels()


func set_upgrade_effects(upgrade_effects: Dictionary) -> void:
	_upgrade_effects = upgrade_effects.duplicate(true)
	_refresh_labels()


func set_selected(is_selected: bool) -> void:
	# Simple visual affordance for the currently selected card.
	modulate = Color(1.0, 1.0, 1.0) if is_selected else Color(0.86, 0.86, 0.86)


func _on_pressed() -> void:
	var selected_preview := ExpeditionOfferEffects.build_preview(expedition_data, _upgrade_effects)
	pressed_with_data.emit(selected_preview)


func _resolve_labels() -> bool:
	if _name_label == null:
		_name_label = get_node_or_null("CardContent/Rows/DisplayNameLabel")
	if _duration_label == null:
		_duration_label = get_node_or_null("CardContent/Rows/DurationLabel")
	if _risk_label == null:
		_risk_label = get_node_or_null("CardContent/Rows/RiskLabel")
	if _reward_label == null:
		_reward_label = get_node_or_null("CardContent/Rows/RewardLabel")
	if _hazard_label == null:
		_hazard_label = get_node_or_null("CardContent/Rows/HazardLabel")

	return _name_label != null \
		and _duration_label != null \
		and _risk_label != null \
		and _reward_label != null \
		and _hazard_label != null


func _refresh_labels() -> void:
	if not _resolve_labels():
		return

	var preview := ExpeditionOfferEffects.build_preview(expedition_data, _upgrade_effects)

	_name_label.text = str(preview.get("display_name", "Unknown Expedition"))
	var duration_minutes := int(preview.get("duration_minutes", 0))
	if duration_minutes <= 0:
		_duration_label.text = "Duration: ? min"
	else:
		_duration_label.text = "Duration: %d min" % duration_minutes

	_risk_label.text = "Risk: %s" % str(preview.get("risk_label", "Unknown"))
	# Player-facing text should use display names, not internal IDs.
	_reward_label.text = "Reward: %s" % str(preview.get("reward_profile_name", "Balanced"))
	_hazard_label.text = "Hazard: %s" % str(preview.get("hazard_name", "Unknown"))
