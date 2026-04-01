extends Control
class_name BottomNavBar

# File: BottomNavBar.gd
# Shared bottom navigation row used by major in-scope screens.
# Text labels were intentionally removed from the scene buttons and replaced
# with icon TextureRect children so label text no longer forces extra width
# on smaller/mobile screens.
# This script keeps screen-to-screen navigation in one place and clearly marks
# which buttons are active routes versus placeholder slots.
# It also recalculates button/icon size on resize so the full bar stays usable
# on narrow/mobile widths without adding internal scrolling or clipping.

signal navigate_requested(target_screen: String)

const TARGET_GUILD_HALL := "guild_hall"
const TARGET_EXPEDITION_BOARD := "expedition_board"
const TARGET_GUILD_UPGRADES := "guild_upgrades"
const TARGET_CODEX := "codex"
const TARGET_COMMISSION_BOARD := "commission_board"

@export var current_screen: String = ""

@onready var _buttons_row: HBoxContainer = $Panel/Margin/ButtonsRow
@onready var _guild_hall_button: Button = $Panel/Margin/ButtonsRow/GHButton
@onready var _expedition_board_button: Button = $Panel/Margin/ButtonsRow/EBButton
@onready var _guild_upgrades_button: Button = $Panel/Margin/ButtonsRow/GUButton
@onready var _codex_button: Button = $Panel/Margin/ButtonsRow/CXButton
@onready var _commission_board_button: Button = $Panel/Margin/ButtonsRow/CBButton
@onready var _all_buttons: Array[Button] = [
	$Panel/Margin/ButtonsRow/GHButton,
	$Panel/Margin/ButtonsRow/EBButton,
	$Panel/Margin/ButtonsRow/GUButton,
	$Panel/Margin/ButtonsRow/CXButton,
	$Panel/Margin/ButtonsRow/CBButton,
	$Panel/Margin/ButtonsRow/XXButtonRight,
	$Panel/Margin/ButtonsRow/SHButton
]
@onready var _icon_margins: Array[MarginContainer] = [
	$Panel/Margin/ButtonsRow/GHButton/IconMargin,
	$Panel/Margin/ButtonsRow/EBButton/IconMargin,
	$Panel/Margin/ButtonsRow/GUButton/IconMargin,
	$Panel/Margin/ButtonsRow/CXButton/IconMargin,
	$Panel/Margin/ButtonsRow/CBButton/IconMargin,
	$Panel/Margin/ButtonsRow/XXButtonRight/IconMargin,
	$Panel/Margin/ButtonsRow/SHButton/IconMargin
]


func _ready() -> void:
	# Reflow nav button sizes whenever the control width changes.
	resized.connect(_update_responsive_button_sizes)
	# Active routes wired for this milestone: GH, EB, GU, CX, and CB.
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
	_commission_board_button.pressed.connect(func() -> void:
		navigate_requested.emit(TARGET_COMMISSION_BOARD)
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
	_commission_board_button.disabled = current_screen == TARGET_COMMISSION_BOARD


func _update_responsive_button_sizes() -> void:
	if not is_node_ready():
		return

	# Root cause of clipping:
	# hard button minimums (56/72) + fixed center bonus + fixed separation
	# could exceed the row width. On small phones, that pushed first/last buttons
	# outside the panel. We now compute sizes from available width first.
	var button_count := _all_buttons.size()
	var desired_separation := 3
	var narrow_separation := 1
	var separation := narrow_separation if size.x <= 360.0 else desired_separation
	_buttons_row.add_theme_constant_override("separation", separation)

	# Keep a mild Codex emphasis (weight 1.15) while still fitting all 7 buttons.
	var center_weight := 1.15
	var usable_width: float = maxf(
		_buttons_row.size.x - float(separation * (button_count - 1)),
		1.0
	)
	var side_size: float = clampf(floor(usable_width / (6.0 + center_weight)), 28.0, 56.0)
	var center_size: float = clampf(floor(side_size * center_weight), 30.0, 64.0)

	for i in _all_buttons.size():
		var is_center := i == 3
		var button_size := center_size if is_center else side_size
		_all_buttons[i].custom_minimum_size = Vector2(button_size, button_size)

		# Root cause of "missing icons":
		# TextureRects were configured to shrink around their minimum size while
		# ignoring texture size, so they could collapse to nearly 0px. We already
		# anchor them full-rect in the scene, and here we keep icon padding small
		# enough on tiny buttons so the texture always has drawable space.
		var icon_margin := 6 if button_size >= 44.0 else 4 if button_size >= 34.0 else 2
		var icon_margin_container := _icon_margins[i]
		icon_margin_container.add_theme_constant_override("margin_left", icon_margin)
		icon_margin_container.add_theme_constant_override("margin_top", icon_margin)
		icon_margin_container.add_theme_constant_override("margin_right", icon_margin)
		icon_margin_container.add_theme_constant_override("margin_bottom", icon_margin)
