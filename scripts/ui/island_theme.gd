class_name IslandUiTheme
extends RefCounted

const HEADING_FONT_PATH := "res://assets/fonts/RussoOne-Regular.ttf"

const NAVY := Color(0.012, 0.055, 0.102, 1.0)
const NAVY_PANEL := Color(0.018, 0.09, 0.15, 0.96)
const NAVY_CARD := Color(0.025, 0.115, 0.19, 0.96)
const CYAN := Color(0.12, 0.77, 0.91, 1.0)
const CYAN_BRIGHT := Color(0.22, 0.93, 1.0, 1.0)
const ORANGE := Color(1.0, 0.59, 0.1, 1.0)
const GREEN := Color(0.31, 0.88, 0.29, 1.0)
const WHITE := Color(0.96, 0.985, 1.0, 1.0)
const MUTED := Color(0.65, 0.76, 0.88, 1.0)


static func create() -> Theme:
	var result := Theme.new()
	var heading_font := FontFile.new()
	heading_font.data = FileAccess.get_file_as_bytes(HEADING_FONT_PATH)
	result.default_font = heading_font
	result.default_font_size = 16
	result.set_color(&"font_color", &"Label", WHITE)
	result.set_color(&"font_shadow_color", &"Label", Color(0.0, 0.02, 0.04, 0.9))
	result.set_constant(&"shadow_offset_x", &"Label", 2)
	result.set_constant(&"shadow_offset_y", &"Label", 2)
	_define_button(result, &"IslandButton", CYAN, Color(0.025, 0.14, 0.22, 0.98))
	_define_button(result, &"IslandPrimaryButton", CYAN_BRIGHT, Color(0.02, 0.67, 0.72, 1.0), true)
	_define_button(result, &"IslandGreenButton", GREEN, Color(0.07, 0.42, 0.16, 1.0), true)
	_define_button(result, &"IslandOrangeButton", ORANGE, Color(0.26, 0.12, 0.025, 1.0))
	_define_button(result, &"IslandBackButton", Color(0.23, 0.66, 0.82, 1.0), Color(0.018, 0.09, 0.15, 0.98))
	_define_button(result, &"IslandGhostButton", Color(0.18, 0.42, 0.56, 0.75), Color(0.025, 0.1, 0.16, 0.72))
	result.set_type_variation(&"IslandSelector", &"OptionButton")
	result.set_stylebox(&"normal", &"IslandSelector", style(NAVY_CARD, CYAN, 2, 12, 12))
	result.set_stylebox(&"hover", &"IslandSelector", style(NAVY_CARD.lightened(0.08), CYAN_BRIGHT, 3, 12, 12))
	result.set_stylebox(&"pressed", &"IslandSelector", style(NAVY, ORANGE, 2, 12, 12))
	result.set_stylebox(&"disabled", &"IslandSelector", style(Color(0.03, 0.06, 0.09, 0.88), Color(0.25, 0.33, 0.4, 0.8), 1, 12, 12))
	result.set_color(&"font_color", &"IslandSelector", WHITE)
	result.set_color(&"font_disabled_color", &"IslandSelector", Color(0.48, 0.57, 0.64, 1.0))
	result.set_type_variation(&"IslandInput", &"LineEdit")
	result.set_stylebox(&"normal", &"IslandInput", style(Color(0.015, 0.07, 0.12, 0.98), CYAN, 2, 12, 14))
	result.set_stylebox(&"focus", &"IslandInput", style(Color(0.02, 0.1, 0.17, 1.0), CYAN_BRIGHT, 3, 12, 14))
	result.set_color(&"font_color", &"IslandInput", WHITE)
	result.set_color(&"font_placeholder_color", &"IslandInput", MUTED)
	return result


static func style(
	background: Color,
	border: Color,
	border_width := 2,
	radius := 14,
	padding := 14
) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(border_width)
	result.set_corner_radius_all(radius)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	result.shadow_color = Color(0.0, 0.015, 0.03, 0.48)
	result.shadow_size = 5
	result.shadow_offset = Vector2(0.0, 3.0)
	return result


static func _define_button(
	theme: Theme,
	variation: StringName,
	accent: Color,
	background: Color,
	bright_text := false
) -> void:
	theme.set_type_variation(variation, &"Button")
	theme.set_stylebox(&"normal", variation, style(background, accent, 2, 13, 12))
	theme.set_stylebox(&"hover", variation, style(background.lightened(0.1), Color.WHITE, 3, 13, 12))
	theme.set_stylebox(&"pressed", variation, style(background.darkened(0.12), accent.darkened(0.08), 3, 13, 12))
	theme.set_stylebox(&"disabled", variation, style(Color(0.035, 0.055, 0.075, 0.82), Color(0.22, 0.28, 0.34, 0.72), 1, 13, 12))
	theme.set_color(&"font_color", variation, Color(0.01, 0.07, 0.09, 1.0) if bright_text else WHITE)
	theme.set_color(&"font_hover_color", variation, Color.WHITE if not bright_text else Color(0.0, 0.05, 0.07, 1.0))
	theme.set_color(&"font_pressed_color", variation, Color.WHITE)
	theme.set_color(&"font_disabled_color", variation, Color(0.42, 0.49, 0.56, 1.0))
