class_name IslandUiArt
extends Control

const ISLAND_THEME := preload("res://scripts/ui/island_theme.gd")

enum Kind {
	BACKDROP,
	LOGO,
	PLAYER,
	MINIGAME,
}

@export var kind := Kind.LOGO
@export var accent := Color(0.15, 0.65, 1.0)
@export var minigame_id: StringName = &"futbol_rebote"


func configure(next_kind: Kind, next_accent := Color(0.15, 0.65, 1.0), id := &"") -> Control:
	kind = next_kind
	accent = next_accent
	minigame_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _draw() -> void:
	match kind:
		Kind.BACKDROP:
			_draw_backdrop()
		Kind.LOGO:
			_draw_logo()
		Kind.PLAYER:
			_draw_player()
		Kind.MINIGAME:
			_draw_minigame()


func _draw_backdrop() -> void:
	var centre := Vector2(size.x * 0.48, size.y * 0.52)
	var scale_value := minf(size.x / 1280.0, size.y / 720.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.31, 0.45, 0.58, 1.0))
	for index in 8:
		var radius := (520.0 - index * 48.0) * scale_value
		draw_circle(
			centre + Vector2(index * 10.0, index * 5.0),
			radius,
			Color(0.62, 0.76, 0.86, 0.035 + index * 0.012)
		)
	var island := PackedVector2Array([
		centre + Vector2(-330, 55) * scale_value,
		centre + Vector2(-255, -90) * scale_value,
		centre + Vector2(-75, -155) * scale_value,
		centre + Vector2(155, -130) * scale_value,
		centre + Vector2(320, -25) * scale_value,
		centre + Vector2(285, 130) * scale_value,
		centre + Vector2(80, 185) * scale_value,
		centre + Vector2(-190, 165) * scale_value,
	])
	draw_colored_polygon(island, Color(0.57, 0.74, 0.78, 0.12))
	draw_polyline(island, Color(0.82, 0.91, 0.93, 0.16), 7.0 * scale_value, true)
	for x_value in [-180.0, -60.0, 65.0, 185.0]:
		var base := centre + Vector2(x_value, 18.0 + absf(x_value) * 0.12) * scale_value
		draw_rect(Rect2(base - Vector2(27, 20) * scale_value, Vector2(54, 40) * scale_value), Color(0.85, 0.91, 0.92, 0.11))
		draw_circle(base + Vector2(0, -52) * scale_value, 30.0 * scale_value, Color(0.64, 0.82, 0.67, 0.12))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.23, 0.34, 0.08))


func _draw_logo() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_circle(centre, radius, ISLAND_THEME.PAPER)
	draw_arc(centre, radius, 0.0, TAU, 48, ISLAND_THEME.CYAN_BRIGHT, 3.0)
	var sand := PackedVector2Array([
		centre + Vector2(-radius * 0.72, radius * 0.35),
		centre + Vector2(-radius * 0.35, radius * 0.12),
		centre + Vector2(radius * 0.28, radius * 0.14),
		centre + Vector2(radius * 0.72, radius * 0.38),
		centre + Vector2(radius * 0.4, radius * 0.52),
		centre + Vector2(-radius * 0.42, radius * 0.5),
	])
	draw_colored_polygon(sand, ISLAND_THEME.ORANGE)
	draw_line(centre + Vector2(-radius * 0.05, radius * 0.18), centre + Vector2(radius * 0.08, -radius * 0.38), ISLAND_THEME.INK, 5.0, true)
	var crown := centre + Vector2(radius * 0.08, -radius * 0.4)
	for offset in [Vector2(-0.28, -0.08), Vector2(-0.16, -0.28), Vector2(0.12, -0.3), Vector2(0.3, -0.08)]:
		draw_circle(crown + offset * radius, radius * 0.2, ISLAND_THEME.GREEN)


func _draw_player() -> void:
	var centre := size * 0.5
	var unit := minf(size.x, size.y) / 7.0
	draw_style_box(
		_capsule(Color(accent.r, accent.g, accent.b, 0.17), unit * 1.2),
		Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	)
	draw_circle(centre + Vector2(0, -2.15 * unit), unit * 0.82, accent)
	draw_style_box(_capsule(accent, unit * 1.05), Rect2(centre + Vector2(-unit, -1.2 * unit), Vector2(2 * unit, 2.7 * unit)))
	draw_line(centre + Vector2(-0.7 * unit, -0.6 * unit), centre + Vector2(-1.45 * unit, 0.55 * unit), accent, unit * 0.62, true)
	draw_line(centre + Vector2(0.72 * unit, -0.62 * unit), centre + Vector2(1.45 * unit, -1.45 * unit), accent, unit * 0.62, true)
	draw_line(centre + Vector2(-0.45 * unit, 1.0 * unit), centre + Vector2(-0.65 * unit, 2.35 * unit), accent, unit * 0.7, true)
	draw_line(centre + Vector2(0.45 * unit, 1.0 * unit), centre + Vector2(0.65 * unit, 2.35 * unit), accent, unit * 0.7, true)
	var face := centre + Vector2(0.0, -2.15 * unit)
	draw_circle(face + Vector2(-0.25, -0.08) * unit, unit * 0.13, Color.WHITE)
	draw_circle(face + Vector2(0.25, -0.08) * unit, unit * 0.13, Color.WHITE)
	draw_circle(face + Vector2(-0.25, -0.08) * unit, unit * 0.065, ISLAND_THEME.INK)
	draw_circle(face + Vector2(0.25, -0.08) * unit, unit * 0.065, ISLAND_THEME.INK)
	draw_arc(face + Vector2(0.0, 0.14) * unit, unit * 0.28, 0.25, PI - 0.25, 12, ISLAND_THEME.INK, unit * 0.07, true)


func _draw_minigame() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.31
	var scene_color := _minigame_scene_color(String(minigame_id))
	draw_style_box(
		_capsule(scene_color, 18.0),
		Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
	)
	var horizon_y := size.y * 0.68
	draw_rect(
		Rect2(Vector2(3.0, horizon_y), Vector2(size.x - 6.0, size.y - horizon_y - 3.0)),
		Color(0.22, 0.69, 0.78, 0.22)
	)
	for cloud_x in [0.2, 0.78]:
		draw_circle(Vector2(size.x * cloud_x, size.y * 0.22), radius * 0.22, Color(1.0, 1.0, 1.0, 0.5))
		draw_circle(Vector2(size.x * cloud_x + radius * 0.2, size.y * 0.22), radius * 0.16, Color(1.0, 1.0, 1.0, 0.5))
	match String(minigame_id):
		"meteors":
			_draw_meteor(centre, radius)
		"shockwave":
			_draw_shockwave(centre, radius)
		"flood":
			_draw_wave(centre, radius)
		"domain":
			_draw_bat_ball(centre, radius)
		"drone_hunt":
			_draw_drone(centre, radius)
		"corona_central":
			_draw_crown(centre, radius)
		"bomba_relevo":
			_draw_bomb(centre, radius)
		"tornado_supervivencia":
			_draw_tornado(centre, radius)
		"shooter_local":
			_draw_shooter(centre, radius)
		"shooter":
			_draw_shooter(centre, radius)
		"bateball_arena":
			_draw_bat_ball(centre, radius)
		"futbol_rebote":
			_draw_ball(centre, radius, Color(0.94, 0.97, 1.0), ISLAND_THEME.CYAN)
		_:
			_draw_ball(centre, radius, Color(0.94, 0.12, 0.12), Color.WHITE)


func _minigame_scene_color(id: String) -> Color:
	match id:
		"futbol_rebote", "bateball_arena", "domain":
			return Color(0.55, 0.84, 0.68, 1.0)
		"corona_central":
			return Color(1.0, 0.87, 0.48, 1.0)
		"bomba_relevo", "meteors":
			return Color(1.0, 0.72, 0.58, 1.0)
		"tornado_supervivencia", "flood", "shockwave":
			return Color(0.57, 0.84, 0.93, 1.0)
		"shooter_local", "shooter", "drone_hunt":
			return Color(0.7, 0.76, 0.84, 1.0)
		_:
			return Color(0.98, 0.7, 0.75, 1.0)


func _draw_meteor(centre: Vector2, radius: float) -> void:
	for index in 3:
		var offset := Vector2(-radius * (1.2 + index * 0.22), -radius * (0.72 - index * 0.34))
		draw_line(centre + offset, centre - Vector2(radius * 0.28, radius * 0.18), Color(1.0, 0.62, 0.18, 0.72), radius * (0.25 - index * 0.035), true)
	draw_circle(centre + Vector2(radius * 0.18, radius * 0.12), radius * 0.72, ISLAND_THEME.ORANGE)
	draw_circle(centre - Vector2(radius * 0.02, radius * 0.1), radius * 0.18, Color(0.68, 0.2, 0.14, 0.55))
	draw_circle(centre + Vector2(radius * 0.38, radius * 0.28), radius * 0.13, Color(0.68, 0.2, 0.14, 0.55))


func _draw_shockwave(centre: Vector2, radius: float) -> void:
	for index in 3:
		draw_arc(centre, radius * (0.38 + index * 0.3), 0.0, TAU, 40, Color(ISLAND_THEME.CYAN.r, ISLAND_THEME.CYAN.g, ISLAND_THEME.CYAN.b, 1.0 - index * 0.22), radius * 0.12, true)
	draw_circle(centre, radius * 0.24, ISLAND_THEME.ORANGE)


func _draw_wave(centre: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for index in 25:
		var ratio := float(index) / 24.0
		points.append(centre + Vector2((ratio * 2.0 - 1.0) * radius, sin(ratio * TAU * 1.5) * radius * 0.28))
	draw_polyline(points, Color(0.12, 0.63, 0.88), radius * 0.22, true)
	draw_arc(centre - Vector2(radius * 0.42, radius * 0.28), radius * 0.48, PI, TAU, 20, Color(0.5, 0.86, 0.96), radius * 0.16, true)


func _draw_drone(centre: Vector2, radius: float) -> void:
	draw_style_box(_capsule(Color(0.33, 0.42, 0.52), radius * 0.25), Rect2(centre - Vector2(radius * 0.5, radius * 0.24), Vector2(radius, radius * 0.48)))
	for side in [-1.0, 1.0]:
		var motor := centre + Vector2(side * radius * 0.72, -radius * 0.18)
		draw_line(centre + Vector2(side * radius * 0.32, 0.0), motor, ISLAND_THEME.INK, radius * 0.12, true)
		draw_arc(motor, radius * 0.34, 0.0, TAU, 24, ISLAND_THEME.CYAN, radius * 0.1, true)
	draw_circle(centre + Vector2(0.0, radius * 0.04), radius * 0.13, ISLAND_THEME.ORANGE)


func _draw_ball(centre: Vector2, radius: float, base: Color, stripe: Color) -> void:
	draw_circle(centre + Vector2(0, radius * 0.72), radius * 0.72, Color(0.05, 0.1, 0.14, 0.16))
	draw_circle(centre, radius, base)
	draw_arc(centre, radius * 0.73, -0.45, 2.72, 32, stripe, radius * 0.24, true)
	draw_arc(centre - Vector2(radius * 0.17, radius * 0.2), radius * 0.76, 2.72, 5.84, 32, stripe, radius * 0.24, true)
	draw_circle(centre - Vector2(radius * 0.3, radius * 0.32), radius * 0.2, Color(1.0, 1.0, 1.0, 0.18))


func _draw_crown(centre: Vector2, radius: float) -> void:
	var gold := Color(1.0, 0.72, 0.08)
	var points := PackedVector2Array([
		centre + Vector2(-radius, radius * 0.45), centre + Vector2(-radius, -radius * 0.5),
		centre + Vector2(-radius * 0.38, 0), centre + Vector2(0, -radius),
		centre + Vector2(radius * 0.38, 0), centre + Vector2(radius, -radius * 0.5),
		centre + Vector2(radius, radius * 0.45),
	])
	draw_colored_polygon(points, gold)
	draw_rect(Rect2(centre + Vector2(-radius, radius * 0.4), Vector2(radius * 2, radius * 0.36)), gold.darkened(0.08))


func _draw_bomb(centre: Vector2, radius: float) -> void:
	draw_circle(centre + Vector2(0, radius * 0.15), radius, Color(0.08, 0.11, 0.15))
	draw_circle(centre - Vector2(radius * 0.3, radius * 0.2), radius * 0.2, Color(0.4, 0.48, 0.55, 0.5))
	draw_line(centre + Vector2(radius * 0.35, -radius * 0.75), centre + Vector2(radius * 0.75, -radius * 1.2), Color(0.62, 0.42, 0.2), radius * 0.13, true)
	draw_circle(centre + Vector2(radius * 0.82, -radius * 1.28), radius * 0.2, ISLAND_THEME.ORANGE)


func _draw_tornado(centre: Vector2, radius: float) -> void:
	for index in 5:
		var width := radius * (1.7 - index * 0.28)
		var y_value := centre.y - radius * 0.75 + index * radius * 0.38
		draw_arc(Vector2(centre.x, y_value), width, 0.18, PI - 0.18, 30, Color(0.55, 0.9, 0.96, 0.9), radius * 0.12, true)


func _draw_shooter(centre: Vector2, radius: float) -> void:
	var steel := Color(0.7, 0.82, 0.9)
	draw_rect(Rect2(centre + Vector2(-radius, -radius * 0.32), Vector2(radius * 1.6, radius * 0.55)), steel)
	draw_rect(Rect2(centre + Vector2(radius * 0.25, radius * 0.12), Vector2(radius * 0.42, radius * 0.75)), steel.darkened(0.22))
	draw_rect(Rect2(centre + Vector2(-radius * 0.72, radius * 0.12), Vector2(radius * 0.35, radius * 0.42)), steel.darkened(0.3))
	draw_line(centre + Vector2(radius * 0.75, 0), centre + Vector2(radius * 1.2, 0), ISLAND_THEME.ORANGE, radius * 0.12, true)


func _draw_bat_ball(centre: Vector2, radius: float) -> void:
	draw_line(centre + Vector2(-radius * 0.75, radius), centre + Vector2(radius * 0.65, -radius * 0.9), Color(0.78, 0.48, 0.19), radius * 0.34, true)
	draw_circle(centre + Vector2(radius * 0.72, radius * 0.48), radius * 0.52, Color(0.96, 0.96, 1.0))
	draw_arc(centre + Vector2(radius * 0.72, radius * 0.48), radius * 0.52, 0.0, TAU, 30, ISLAND_THEME.CYAN, radius * 0.1)


func _capsule(color: Color, radius: float) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(int(radius))
	return result
