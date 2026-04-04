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
@onready var _outcome_label: Label = $PopupMargin/PopupColumn/OutcomeLabel
@onready var _gold_label: Label = $PopupMargin/PopupColumn/GoldLabel
@onready var _side_reward_label: Label = $PopupMargin/PopupColumn/SideRewardLabel
@onready var _standing_label: Label = $PopupMargin/PopupColumn/StandingLabel
@onready var _recovering_label: Label = $PopupMargin/PopupColumn/RecoveringLabel
@onready var _recovery_time_label: Label = $PopupMargin/PopupColumn/RecoveryTimeLabel
@onready var _summary_label: Label = $PopupMargin/PopupColumn/SummaryLabel
@onready var _close_button: Button = $PopupMargin/PopupColumn/ButtonsRow/CloseButton
@onready var _claim_button: Button = $PopupMargin/PopupColumn/ButtonsRow/ClaimButton

var _runtime_id := 0


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
	_outcome_label.text = "Outcome: %s" % str(payload.get("outcome_label", "Unknown"))
	_gold_label.text = "Gold Payout: %d" % maxi(0, int(payload.get("gold_payout", 0)))
	_side_reward_label.text = "Side Reward: %s" % _format_side_reward(payload.get("side_reward", {}) as Dictionary)
	_standing_label.text = "Standing Change: %s" % _format_signed(int(payload.get("standing_delta", 0)))
	_recovering_label.text = "Crew Sent to Recovering: %d" % maxi(0, int(payload.get("crew_to_recovering", 0)))
	_recovery_time_label.text = "Recovery Time: %s" % TimeFormat.format_seconds_hms(maxi(0, int(payload.get("recovery_seconds", 0))))
	_summary_label.text = str(payload.get("summary", "No additional notes."))

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
