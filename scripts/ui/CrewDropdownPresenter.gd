extends RefCounted
class_name CrewDropdownPresenter

# File: CrewDropdownPresenter.gd
# Shared helper for the compact Crew counter dropdown used in top resource rows.
# This keeps Guild Hall and Commission Board behavior identical:
# - collapsed button shows Available / Max,
# - popup shows Assigned + Recovering,
# - colors match the same semantic meaning across both screens.

var _dropdown_button: Button
var _collapsed_value: RichTextLabel
var _dropdown_popup: PopupPanel
var _assigned_value: RichTextLabel
var _recovering_value: RichTextLabel


func configure(
	dropdown_button: Button,
	collapsed_value: RichTextLabel,
	dropdown_popup: PopupPanel,
	assigned_value: RichTextLabel,
	recovering_value: RichTextLabel
) -> void:
	_dropdown_button = dropdown_button
	_collapsed_value = collapsed_value
	_dropdown_popup = dropdown_popup
	_assigned_value = assigned_value
	_recovering_value = recovering_value

	# Shared wiring means both screens react to taps exactly the same way.
	_dropdown_button.pressed.connect(_on_dropdown_button_pressed)
	_dropdown_popup.popup_hide.connect(_on_dropdown_popup_hidden)


func set_values(available_crew: int, max_crew: int, assigned_crew: int, recovering_crew: int) -> void:
	# Collapsed label intentionally uses "available now vs cap" as the fast-read value.
	_collapsed_value.text = "[color=#6EEB74]%d[/color] / %d" % [available_crew, max_crew]
	# Expanded popup keeps details focused on non-available pools.
	_assigned_value.text = "[color=#F5D547]%d[/color]" % assigned_crew
	_recovering_value.text = "[color=#F2A14A]%d[/color]" % recovering_crew


func _on_dropdown_button_pressed() -> void:
	if _dropdown_popup.visible:
		_dropdown_popup.hide()
		return

	# Keep authored width, but shrink height to the popup content so no blank row appears.
	var authored_width := _dropdown_popup.size.x
	_dropdown_popup.reset_size()
	_dropdown_popup.size = Vector2i(max(authored_width, _dropdown_popup.size.x), _dropdown_popup.size.y)

	# PopupPanel gives a compact dropdown that closes when focus/tap moves away.
	var button_rect := _dropdown_button.get_global_rect()
	_dropdown_popup.position = Vector2i(
		int(button_rect.position.x),
		int(button_rect.position.y + button_rect.size.y + 2.0)
	)
	_dropdown_popup.popup()
	_dropdown_button.text = "▲"


func _on_dropdown_popup_hidden() -> void:
	_dropdown_button.text = "▼"
