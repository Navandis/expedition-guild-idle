extends Button
class_name TouchScrollCardButton

# File: TouchScrollCardButton.gd
# Shared helper for card-like buttons inside ScrollContainers.
# It keeps cards tappable, but suppresses taps when the pointer moved far enough
# to be treated as a scroll/drag gesture.

signal confirmed_tap

@export var drag_threshold_px := 18.0

var _pointer_down := false
var _is_dragging := false
var _pointer_index := -1
var _press_start_position := Vector2.ZERO


func _ready() -> void:
	# PASS lets this card receive input while still allowing parent ScrollContainer
	# controls to observe drag events and perform scrolling.
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_begin_pointer(event.position, event.index)
		return
	if not _matches_pointer(event.index):
		return
	if not _is_dragging:
		confirmed_tap.emit()
	_reset_pointer_state()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _matches_pointer(event.index):
		return
	_update_drag_state(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_begin_pointer(event.position, 0)
		return
	if not _matches_pointer(0):
		return
	if not _is_dragging:
		confirmed_tap.emit()
	_reset_pointer_state()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _matches_pointer(0):
		return
	_update_drag_state(event.position)


func _begin_pointer(pointer_position: Vector2, pointer_index: int) -> void:
	_pointer_down = true
	_is_dragging = false
	_pointer_index = pointer_index
	_press_start_position = pointer_position


func _update_drag_state(current_position: Vector2) -> void:
	if _is_dragging:
		return
	# Movement threshold cleanly separates "tap" from "scroll".
	if current_position.distance_to(_press_start_position) >= drag_threshold_px:
		_is_dragging = true


func _matches_pointer(pointer_index: int) -> bool:
	return _pointer_down and _pointer_index == pointer_index


func _reset_pointer_state() -> void:
	_pointer_down = false
	_is_dragging = false
	_pointer_index = -1
