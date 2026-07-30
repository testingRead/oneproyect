class_name TouchActionButton
extends Control

signal action_pressed

@export var label := "SALTO"
@export var accent := Color(0.97, 0.63, 0.17, 0.88)

var _finger_id := -1
var _pressed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_label(value: String) -> void:
	if label == value:
		return
	label = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1:
			_finger_id = event.index
			_pressed = true
			action_pressed.emit()
			queue_redraw()
			accept_event()
		elif not event.pressed and event.index == _finger_id:
			_release()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			action_pressed.emit()
		else:
			_release()
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		var color := accent.lightened(0.12) if _pressed else accent
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 40, Color.WHITE, 3.0)
		var font := ThemeDB.fallback_font
		var font_size := 22
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.78), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _release() -> void:
	_finger_id = -1
	_pressed = false
	queue_redraw()
