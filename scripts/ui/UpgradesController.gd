extends Control
class_name UpgradesController

# File: UpgradesController.gd
# UpgradesController is the day-3 UI for visible guild progression.
# It renders JSON-defined upgrades, lets players buy with gold, and marks owned
# entries so the first progression loop is easy to test in-game.
# Layout note: the upgrades list scroll area is the only expanding content
# region, so long upgrade data scrolls there while the shared bottom nav stays
# fully visible as a fixed footer.

signal back_requested
signal purchase_requested(upgrade_id: String)
signal navigate_requested(target_screen: String)

@onready var _gold_label: Label = $SafeArea/RootColumn/HeaderPanel/HeaderRows/GoldLabel
@onready var _effects_label: Label = $SafeArea/RootColumn/HeaderPanel/HeaderRows/EffectsLabel
@onready var _status_label: Label = $SafeArea/RootColumn/StatusLabel
@onready var _list_container: VBoxContainer = $SafeArea/RootColumn/UpgradesScroll/UpgradesList
@onready var _bottom_nav: BottomNavBar = $SafeArea/RootColumn/BottomNavBar


func _ready() -> void:
	$SafeArea/RootColumn/BackButton.pressed.connect(_on_back_pressed)
	# Shared nav keeps GH/EB/GU/CX switching consistent across screens.
	_bottom_nav.set_current_screen(BottomNavBar.TARGET_GUILD_UPGRADES)
	_bottom_nav.navigate_requested.connect(_on_bottom_nav_requested)


func set_view_model(upgrades: Array[Dictionary], owned_map: Dictionary, current_gold: int, effects: Dictionary) -> void:
	_gold_label.text = "Gold: %d" % current_gold
	_effects_label.text = "Effects - Duration x%.2f | Gold x%.2f | Success +%.0f%%" % [
		float(effects.get("duration_multiplier", 1.0)),
		float(effects.get("gold_multiplier", 1.0)),
		float(effects.get("success_bonus", 0.0)) * 100.0
	]
	_status_label.text = ""

	for child in _list_container.get_children():
		child.queue_free()

	for upgrade in upgrades:
		_add_upgrade_row(upgrade, owned_map, current_gold)


func show_purchase_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_status_label.text = "Purchased successfully."
	else:
		_status_label.text = "Purchase failed: %s" % str(result.get("reason", "Unknown reason"))


func _add_upgrade_row(upgrade: Dictionary, owned_map: Dictionary, current_gold: int) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	var upgrade_id := str(upgrade.get("id", ""))
	var owned := bool(owned_map.get(upgrade_id, false))
	name_label.text = "%s%s" % [str(upgrade.get("name", "Unknown")), " (Owned)" if owned else ""]
	row.add_child(name_label)

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = str(upgrade.get("description", ""))
	row.add_child(description_label)

	var purchase_row := HBoxContainer.new()
	purchase_row.add_theme_constant_override("separation", 8)

	var cost_label := Label.new()
	cost_label.text = "Cost: %d gold" % int(upgrade.get("cost_gold", 0))
	purchase_row.add_child(cost_label)

	var purchase_button := Button.new()
	purchase_button.text = "Purchase"
	purchase_button.disabled = owned or current_gold < int(upgrade.get("cost_gold", 0))
	purchase_button.pressed.connect(func() -> void:
		purchase_requested.emit(upgrade_id)
	)
	purchase_row.add_child(purchase_button)

	row.add_child(purchase_row)

	var divider := HSeparator.new()

	_list_container.add_child(row)
	_list_container.add_child(divider)


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_bottom_nav_requested(target_screen: String) -> void:
	navigate_requested.emit(target_screen)
