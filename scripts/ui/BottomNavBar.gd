extends Control
class_name BottomNavBar

# File: BottomNavBar.gd
# Shared bottom navigation row used by major in-scope screens.
# This keeps screen-to-screen navigation in one place and clearly marks
# which buttons are active routes versus placeholder slots.

signal navigate_requested(target_screen: String)

const TARGET_GUILD_HALL := "guild_hall"
const TARGET_EXPEDITION_BOARD := "expedition_board"
const TARGET_GUILD_UPGRADES := "guild_upgrades"
const TARGET_CODEX := "codex"

@export var current_screen: String = ""

@onready var _guild_hall_button: Button = $Panel/Margin/ButtonsRow/GHButton
@onready var _expedition_board_button: Button = $Panel/Margin/ButtonsRow/EBButton
@onready var _guild_upgrades_button: Button = $Panel/Margin/ButtonsRow/GUButton
@onready var _codex_button: Button = $Panel/Margin/ButtonsRow/CXButton


func _ready() -> void:
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
