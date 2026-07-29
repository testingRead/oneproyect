class_name GrayboxVirtualJoystick
extends Control

signal value_changed(value: Vector2)

@export var radius := 82.0
@export var deadzone := 0.12

var _finger_id := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _value := Vector2.ZERO
var _touch_origin := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size * 0.5
	_knob = _center
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1 and _is_in_activation_zone(event.position):
			_finger_id = event.index
			_touch_origin = event.position
			_update_global_value(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger_id:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger_id:
		_update_global_value(event.position)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5
		if _finger_id == -1:
			_knob = _center
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_finger_id = -2
				_update_value(event.position)
			elif _finger_id == -2:
				_release()
			accept_event()
	elif event is InputEventMouseMotion and _finger_id == -2:
		_update_value(event.position)
		accept_event()


func _draw() -> void:
	draw_circle(_center, radius, Color(0.08, 0.1, 0.13, 0.55))
	draw_arc(_center, radius, 0.0, TAU, 40, Color(0.7, 0.76, 0.84, 0.65), 3.0)
	draw_circle(_knob, radius * 0.42, Color(0.28, 0.62, 0.95, 0.82))


func _update_value(position: Vector2) -> void:
	var offset := position - _center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob = _center + offset
	_value = offset / radius
	if _value.length() < deadzone:
		_value = Vector2.ZERO
	value_changed.emit(_value)
	queue_redraw()


func _update_global_value(viewport_position: Vector2) -> void:
	var offset := viewport_position - _touch_origin
	_value = offset / radius
	if _value.length() > 1.0:
		_value = _value.normalized()
	if _value.length() < deadzone:
		_value = Vector2.ZERO
	_knob = _center + _value * radius
	value_changed.emit(_value)
	queue_redraw()


func _release() -> void:
	_finger_id = -1
	_value = Vector2.ZERO
	_knob = _center
	value_changed.emit(_value)
	queue_redraw()


func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _is_in_activation_zone(viewport_position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_position.x <= viewport_size.x * 0.5 and viewport_position.y >= viewport_size.y * 0.35
