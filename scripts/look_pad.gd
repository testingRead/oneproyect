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
var _input_enabled := true
var _last_viewport_position := Vector2.ZERO

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


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_finger_id = -1
		_aim_value = Vector2.ZERO
		queue_redraw()


func is_aim_mode() -> bool:
	return _aim_mode


func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventScreenTouch:
		if (
			event.pressed
			and _finger_id == -1
			and _is_in_activation_zone(event.position)
		):
			_finger_id = event.index
			_last_viewport_position = event.position
			if _aim_mode:
				_aim_origin = _viewport_to_local(event.position)
				_aim_current = _aim_origin
				_aim_value = Vector2.ZERO
				aim_changed.emit(_aim_value, true)
				queue_redraw()
		elif not event.pressed and event.index == _finger_id:
			if _aim_mode:
				var released_value := _aim_value
				aim_changed.emit(released_value, false)
				if released_value.length() >= AIM_DEADZONE:
					aim_released.emit(released_value.normalized())
				_aim_value = Vector2.ZERO
				queue_redraw()
			_finger_id = -1
	elif event is InputEventScreenDrag and event.index == _finger_id:
		if _aim_mode:
			_aim_current = _viewport_to_local(event.position)
			_aim_value = ((_aim_current - _aim_origin) / AIM_RADIUS).limit_length(1.0)
			aim_changed.emit(_aim_value, true)
			queue_redraw()
		else:
			# ScreenDrag.relative is normally populated, but a few Android input
			# stacks report zero on the first drag. The position delta keeps the
			# camera continuous on those devices and when the touch began over a
			# superimposed action button.
			var delta: Vector2 = event.relative
			if delta.length_squared() <= 0.0001:
				delta = event.position - _last_viewport_position
			if delta.is_finite() and delta.length_squared() > 0.0001:
				look_delta.emit(delta)
		_last_viewport_position = event.position


func _gui_input(event: InputEvent) -> void:
	# Touchscreen input is observed in _input(), before GUI hit testing. This is
	# deliberate: Shoot/Reload/Jump can consume their own button press while the
	# very same finger continues rotating the camera. Desktop mouse look remains
	# owned by LocalBaseCharacter's captured-mouse handler.
	if event is InputEventMouseButton:
		accept_event()


func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _is_in_activation_zone(viewport_position: Vector2) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_position.x >= viewport_size.x * 0.5


func is_tracking_finger(finger_id: int) -> bool:
	return _finger_id == finger_id


func _draw() -> void:
	if not _aim_mode or _finger_id == -1:
		return
	draw_circle(_aim_origin, AIM_RADIUS, Color(0.02, 0.06, 0.09, 0.32))
	draw_arc(_aim_origin, AIM_RADIUS, 0.0, TAU, 48, Color(0.55, 0.92, 1.0, 0.72), 3.0)
	var knob := _aim_origin + _aim_value * AIM_RADIUS
	draw_circle(knob, 29.0, Color(0.12, 0.72, 0.92, 0.82))
	draw_arc(knob, 29.0, 0.0, TAU, 32, Color.WHITE, 2.5)
