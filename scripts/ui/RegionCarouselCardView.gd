extends Button
class_name RegionCarouselCardView

# File: RegionCarouselCardView.gd
# Reusable, scene-authored region selector card for the Expedition Board carousel.
#
# Why this exists:
# - The board previously built each region card's full node tree in code.
# - Moving that structure into a .tscn makes it editable in the Godot editor.
# - The board controller now only instantiates this component and binds data.

@onready var _image: TextureRect = $CardMargin/CardColumn/RegionImage
@onready var _name_label: Label = $CardMargin/CardColumn/RegionNameLabel

var _region_id := ""


func setup(region_row: Dictionary, region_texture: Texture2D) -> void:
	# Populate editor-authored child nodes with runtime data.
	_region_id = str(region_row.get("id", ""))
	var region_name := str(region_row.get("name", _region_id))
	var is_unlocked := bool(region_row.get("is_unlocked", false))

	_image.texture = region_texture
	_name_label.text = region_name if is_unlocked else "%s (Locked)" % region_name
	disabled = not is_unlocked


func get_region_id() -> String:
	return _region_id


func apply_selected_style(is_selected: bool, selected_border: Color, unselected_border: Color) -> void:
	# Keep selected/idle border behavior centralized and easy to tweak.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.11, 0.96)
	style.border_color = selected_border if is_selected else unselected_border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("hover", style)
