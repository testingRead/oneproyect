class_name GameCrosshair
extends Control

var spread := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64.0, 64.0)


func _process(delta: float) -> void:
	spread = move_toward(spread, 0.0, delta * 36.0)
	queue_redraw()


func kick() -> void:
	spread = 9.0


func _draw() -> void:
	var center := size * 0.5
	var gap := 6.0 + spread
	var length := 8.0
	var color := Color(0.95, 0.98, 1.0, 0.96)
	draw_line(center + Vector2(-gap - length, 0), center + Vector2(-gap, 0), color, 2.2)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), color, 2.2)
	draw_line(center + Vector2(0, -gap - length), center + Vector2(0, -gap), color, 2.2)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), color, 2.2)
	draw_circle(center, 1.8, Color(1.0, 0.45, 0.18, 0.98))
