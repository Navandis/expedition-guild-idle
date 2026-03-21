extends Control
class_name BottomNavBar

# File: BottomNavBar.gd
# Shared bottom navigation row used by major in-scope screens.
# This keeps screen-to-screen navigation in one place and clearly marks
# which buttons are active routes versus placeholder slots.
# It also recalculates button size on resize so the full bar stays usable
# on narrow/mobile widths without adding internal scrolling.

signal navigate_requested(target_screen: String)

const TARGET_GUILD_HALL := "guild_hall"
const TARGET_EXPEDITION_BOARD := "expedition_board"
const TARGET_GUILD_UPGRADES := "guild_upgrades"
const TARGET_CODEX := "codex"

@export var current_screen: String = ""

@onready var _buttons_row: HBoxContainer = $Panel/Margin/ButtonsRow
@onready var _guild_hall_button: Button = $Panel/Margin/ButtonsRow/GHButton
@onready var _expedition_board_button: Button = $Panel/Margin/ButtonsRow/EBButton
@onready var _guild_upgrades_button: Button = $Panel/Margin/ButtonsRow/GUButton
@onready var _codex_button: Button = $Panel/Margin/ButtonsRow/CXButton


func _ready() -> void:
	# Reflow nav button sizes whenever the control width changes.
	resized.connect(_update_responsive_button_sizes)
	# Active routes wired for this milestone: GH, EB, GU, and center CX.
	_guild_hall_button.pressed.connect(func() -> void:
		navigate_requested.emit(TARGET_GUILD_HALL)
	)
	_expedition_board_button.pressed.connect(func() -> void:
		navigate_requested.emit(TARGET_EXPEDITION_BOARD)
	)
	_guild_upgrades_button.pressed.connect(func() -> void:
		navigate_requested.emit(TARGET_GUILD_UPGRADES)
	)
	_codex_button.pressed.connect(func() -> void:
		navigate_requested.emit(TARGET_CODEX)
	)
	_refresh_active_state()
	_update_responsive_button_sizes()


func set_current_screen(screen_id: String) -> void:
	# Each host screen sets this so its own destination button is disabled.
	current_screen = screen_id
	_refresh_active_state()


func _refresh_active_state() -> void:
	if not is_node_ready():
		return
	_guild_hall_button.disabled = current_screen == TARGET_GUILD_HALL
	_expedition_board_button.disabled = current_screen == TARGET_EXPEDITION_BOARD
	_guild_upgrades_button.disabled = current_screen == TARGET_GUILD_UPGRADES
	_codex_button.disabled = current_screen == TARGET_CODEX


func _update_responsive_button_sizes() -> void:
	if not is_node_ready():
		return

	var all_buttons: Array[Button] = [
		$Panel/Margin/ButtonsRow/GHButton,
		$Panel/Margin/ButtonsRow/EBButton,
		$Panel/Margin/ButtonsRow/GUButton,
		$Panel/Margin/ButtonsRow/CXButton,
		$Panel/Margin/ButtonsRow/XXButtonLeft,
		$Panel/Margin/ButtonsRow/XXButtonRight,
		$Panel/Margin/ButtonsRow/SHButton
	]

	# Keep side buttons square while scaling all seven buttons to fit width.
	# The center Codex button stays larger/highlighted via a small bonus size.
	var separation := _buttons_row.get_theme_constant("separation")
	var center_bonus := 12.0
	var usable_width := max(_buttons_row.size.x - float(separation * (all_buttons.size() - 1)), 1.0)
	var side_size := clamp(floor((usable_width - center_bonus) / 7.0), 40.0, 56.0)
	var center_size := clamp(side_size + center_bonus, 48.0, 72.0)

	for i in all_buttons.size():
		var is_center := i == 3
		var button_size := center_size if is_center else side_size
		all_buttons[i].custom_minimum_size = Vector2(button_size, button_size)
