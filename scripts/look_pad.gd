class_name LookPad
extends Control

signal look_delta(delta: Vector2)
signal aim_changed(value: Vector2, active: bool)
signal aim_released(value: Vector2)

var _finger_id := -1
var _aim_mode := false
var _aim_origin := Vector2.ZERO
var _aim_current := Vector2.ZERO
var _aim_value := Vector2.ZERO

const AIM_RADIUS := 82.0
const AIM_DEADZONE := 0.16


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_aim_mode(enabled: bool) -> void:
	_aim_mode = enabled
	_finger_id = -1
	_aim_value = Vector2.ZERO
	queue_redraw()


func is_aim_mode() -> bool:
	return _aim_mode


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1:
			_finger_id = event.index
			if _aim_mode:
				_aim_origin = event.position - global_position
				_aim_current = _aim_origin
				_aim_value = Vector2.ZERO
				aim_changed.emit(_aim_value, true)
				queue_redraw()
			accept_event()
		elif not event.pressed and event.index == _finger_id:
			if _aim_mode:
				var released_value := _aim_value
				aim_changed.emit(released_value, false)
				if released_value.length() >= AIM_DEADZONE:
					aim_released.emit(released_value.normalized())
				_aim_value = Vector2.ZERO
				queue_redraw()
			_finger_id = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger_id:
		if _aim_mode:
			_aim_current = event.position - global_position
			_aim_value = ((_aim_current - _aim_origin) / AIM_RADIUS).limit_length(1.0)
			aim_changed.emit(_aim_value, true)
			queue_redraw()
		else:
			look_delta.emit(event.relative)
		accept_event()


func _draw() -> void:
	if not _aim_mode or _finger_id == -1:
		return
	draw_circle(_aim_origin, AIM_RADIUS, Color(0.02, 0.06, 0.09, 0.32))
	draw_arc(_aim_origin, AIM_RADIUS, 0.0, TAU, 48, Color(0.55, 0.92, 1.0, 0.72), 3.0)
	var knob := _aim_origin + _aim_value * AIM_RADIUS
	draw_circle(knob, 29.0, Color(0.12, 0.72, 0.92, 0.82))
	draw_arc(knob, 29.0, 0.0, TAU, 32, Color.WHITE, 2.5)
