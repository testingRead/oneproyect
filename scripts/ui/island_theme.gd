class_name IslandUiTheme
extends RefCounted

const HEADING_FONT_PATH := "res://assets/fonts/RussoOne-Regular.ttf"

const NAVY := Color(0.12, 0.22, 0.34, 1.0)
const NAVY_PANEL := Color(0.94, 0.95, 0.96, 1.0)
const NAVY_CARD := Color(0.985, 0.985, 0.98, 1.0)
const PAPER := Color(0.985, 0.982, 0.965, 1.0)
const INK := Color(0.12, 0.21, 0.32, 1.0)
# Compatibility name used by the first theme. In the clear-card system this
# means the primary readable ink; PAPER is the actual white surface.
const WHITE := INK
const CYAN := Color(0.08, 0.68, 0.73, 1.0)
const CYAN_BRIGHT := Color(0.13, 0.76, 0.79, 1.0)
const ORANGE := Color(0.95, 0.39, 0.29, 1.0)
const GREEN := Color(0.31, 0.72, 0.30, 1.0)
const MUTED := Color(0.38, 0.46, 0.56, 1.0)
const LINE := Color(0.78, 0.81, 0.85, 1.0)


static func create() -> Theme:
	var result := Theme.new()
	var heading_font := FontFile.new()
	heading_font.data = FileAccess.get_file_as_bytes(HEADING_FONT_PATH)
	result.default_font = heading_font
	result.default_font_size = 16
	result.set_color(&"font_color", &"Label", WHITE)
	result.set_color(&"font_shadow_color", &"Label", Color.TRANSPARENT)
	result.set_constant(&"shadow_offset_x", &"Label", 0)
	result.set_constant(&"shadow_offset_y", &"Label", 0)
	_define_button(result, &"IslandButton", Color(0.65, 0.72, 0.79), PAPER)
	_define_button(result, &"IslandPrimaryButton", CYAN_BRIGHT, Color(0.08, 0.68, 0.72), true)
	_define_button(result, &"IslandGreenButton", GREEN, Color(0.31, 0.72, 0.30), true)
	_define_button(result, &"IslandOrangeButton", ORANGE, Color(0.95, 0.39, 0.29), true)
	_define_button(result, &"IslandBackButton", Color(0.54, 0.65, 0.75), Color(0.29, 0.43, 0.56))
	_define_button(result, &"IslandGhostButton", LINE, Color(0.92, 0.94, 0.95))
	result.set_type_variation(&"IslandSelector", &"OptionButton")
	result.set_stylebox(&"normal", &"IslandSelector", style(PAPER, LINE, 2, 12, 12))
	result.set_stylebox(&"hover", &"IslandSelector", style(Color.WHITE, CYAN_BRIGHT, 3, 12, 12))
	result.set_stylebox(&"pressed", &"IslandSelector", style(Color(0.95, 0.98, 0.98), ORANGE, 2, 12, 12))
	result.set_stylebox(&"disabled", &"IslandSelector", style(Color(0.9, 0.91, 0.92), Color(0.72, 0.75, 0.78), 1, 12, 12))
	result.set_color(&"font_color", &"IslandSelector", INK)
	result.set_color(&"font_disabled_color", &"IslandSelector", Color(0.5, 0.54, 0.58, 1.0))
	result.set_type_variation(&"IslandInput", &"LineEdit")
	result.set_stylebox(&"normal", &"IslandInput", style(PAPER, LINE, 2, 12, 14))
	result.set_stylebox(&"focus", &"IslandInput", style(Color.WHITE, CYAN_BRIGHT, 3, 12, 14))
	result.set_color(&"font_color", &"IslandInput", INK)
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
	result.shadow_color = Color(0.06, 0.12, 0.18, 0.26)
	result.shadow_size = 4
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
	theme.set_stylebox(&"disabled", variation, style(Color(0.84, 0.86, 0.88, 0.94), Color(0.68, 0.71, 0.74, 0.8), 1, 13, 12))
	theme.set_color(&"font_color", variation, Color.WHITE if bright_text else INK)
	theme.set_color(&"font_hover_color", variation, Color.WHITE if bright_text else INK)
	theme.set_color(&"font_pressed_color", variation, Color.WHITE if bright_text else INK)
	theme.set_color(&"font_disabled_color", variation, Color(0.48, 0.52, 0.56, 1.0))
