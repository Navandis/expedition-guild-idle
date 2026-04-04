extends PopupPanel
class_name CommissionSettlementPopup

# File: CommissionSettlementPopup.gd
# Compact settlement modal for one completed commission claim.
#
# Why this popup exists:
# - Guild Hall completed commission cards now open a short settlement summary
#   before claiming, so rewards are no longer granted with zero feedback.
# - This is intentionally *not* the expedition report flow; it stays small and
#   focused on commission-specific payout/recovery details.
# - The popup binds directly from the stored runtime completion payload so we do
#   not create a second parallel result-calculation path.

signal claim_requested(runtime_id: int)

@onready var _title_label: Label = $PopupMargin/PopupColumn/TitleLabel
@onready var _outcome_label: RichTextLabel = $PopupMargin/PopupColumn/OutcomeLabel
@onready var _gold_label: RichTextLabel = $PopupMargin/PopupColumn/GoldLabel
@onready var _side_reward_label: Label = $PopupMargin/PopupColumn/SideRewardLabel
@onready var _standing_label: Label = $PopupMargin/PopupColumn/StandingLabel
@onready var _recovering_label: Label = $PopupMargin/PopupColumn/RecoveringLabel
@onready var _recovery_time_label: RichTextLabel = $PopupMargin/PopupColumn/RecoveryTimeLabel
@onready var _close_button: Button = $PopupMargin/PopupColumn/ButtonsRow/CloseButton
@onready var _claim_button: Button = $PopupMargin/PopupColumn/ButtonsRow/ClaimButton

var _runtime_id := 0

const _OUTCOME_COLOR_BY_BAND := {
	"poor": Color(1.0, 0.6, 0.2, 1.0), # Orange
	"strained": Color(0.95, 0.85, 0.2, 1.0), # Yellow
	"solid": Color(1.0, 1.0, 1.0, 1.0), # Default white
	"excellent": Color(0.35, 0.85, 0.45, 1.0) # Green
}


func _ready() -> void:
	# Closing this popup must not consume the claimable entry.
	# Only the explicit Claim button emits claim_requested.
	hide()
	_close_button.pressed.connect(_on_close_pressed)
	_claim_button.pressed.connect(_on_claim_pressed)


func open_for_entry(entry: Dictionary) -> void:
	_runtime_id = maxi(0, int(entry.get("runtime_id", 0)))
	var payload := entry.get("completion_payload", {}) as Dictionary

	_title_label.text = str(entry.get("title", "Commission"))
	# Only the outcome value is colorized so row labels keep consistent styling.
	var outcome_band := str(payload.get("outcome_band", "solid")).to_lower()
	var outcome_label := str(payload.get("outcome_label", "Unknown"))
	var outcome_color := _get_outcome_color(outcome_band)
	_outcome_label.text = "Outcome: [color=%s]%s[/color]" % [_to_html_color(outcome_color), outcome_label]

	var gold_payout := maxi(0, int(payload.get("gold_payout", 0)))
	var recovery_seconds := maxi(0, int(payload.get("recovery_seconds", 0)))
	# Delta values come from completion payload runtime data so popup text matches
	# the exact modifiers already used by commission resolution.
	var gold_delta_percent := _resolve_delta_percent(payload, "gold_delta_percent", "gold_multiplier", outcome_band, true)
	var recovery_delta_percent := _resolve_delta_percent(payload, "recovery_delta_percent", "recovery_multiplier", outcome_band, false)
	var delta_color_tag := "[color=%s]" % _to_html_color(outcome_color)
	var delta_close_tag := "[/color]"
	var show_delta := outcome_band != "solid"
	# Delta color matches the outcome color to reinforce "these effects came from
	# this outcome band" without redesigning the full popup visuals.
	if show_delta:
		_gold_label.text = "Gold Payout: %d (%s%s%s)" % [
			gold_payout,
			delta_color_tag,
			_format_signed_percent(gold_delta_percent),
			delta_close_tag
		]
	else:
		_gold_label.text = "Gold Payout: %d" % gold_payout
	_side_reward_label.text = "Side Reward: %s" % _format_side_reward(payload.get("side_reward", {}) as Dictionary)
	_standing_label.text = "Standing Change: %s" % _format_signed(int(payload.get("standing_delta", 0)))
	_recovering_label.text = "Crew Sent to Recovering: %d" % maxi(0, int(payload.get("crew_to_recovering", 0)))
	if show_delta:
		_recovery_time_label.text = "Recovery Time: %s (%s%s%s)" % [
			TimeFormat.format_seconds_hms(recovery_seconds),
			delta_color_tag,
			_format_signed_percent(recovery_delta_percent),
			delta_close_tag
		]
	else:
		_recovery_time_label.text = "Recovery Time: %s" % TimeFormat.format_seconds_hms(recovery_seconds)
	# Summary row removed because outcome + payout/recovery deltas already explain
	# the settlement result in a more direct and compact way.

	popup_centered()


func _on_close_pressed() -> void:
	hide()


func _on_claim_pressed() -> void:
	if _runtime_id > 0:
		claim_requested.emit(_runtime_id)
	hide()


func _format_side_reward(side_reward: Dictionary) -> String:
	if side_reward.is_empty():
		return "None"
	var reward_type := str(side_reward.get("type", "")).strip_edges()
	var amount := int(side_reward.get("amount", 0))
	if reward_type.is_empty():
		return "None"
	if amount > 0:
		return "%s +%d" % [reward_type.capitalize(), amount]
	return reward_type.capitalize()


func _format_signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _format_signed_percent(value: int) -> String:
	if value > 0:
		return "+%d%%" % value
	return "%d%%" % value


func _resolve_delta_percent(payload: Dictionary, delta_key: String, multiplier_key: String, outcome_band: String, is_gold: bool) -> int:
	if payload.has(delta_key):
		return int(payload.get(delta_key, 0))
	if payload.has(multiplier_key):
		var multiplier := float(payload.get(multiplier_key, 1.0))
		return int(round((multiplier - 1.0) * 100.0))
	# Save-compat fallback for older payload rows created before explicit deltas.
	if is_gold:
		match outcome_band:
			"excellent":
				return 30
			"strained":
				return -30
			"poor":
				return -60
			_:
				return 0
	match outcome_band:
		"excellent":
			return -25
		"strained":
			return 20
		"poor":
			return 45
		_:
			return 0


func _get_outcome_color(outcome_band: String) -> Color:
	return _OUTCOME_COLOR_BY_BAND.get(outcome_band, Color.WHITE)


func _to_html_color(color: Color) -> String:
	return color.to_html(false)
