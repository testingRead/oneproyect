class_name LookPad
extends Control

signal look_delta(delta: Vector2)

var _finger_id := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1:
			_finger_id = event.index
			accept_event()
		elif not event.pressed and event.index == _finger_id:
			_finger_id = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger_id:
		look_delta.emit(event.relative)
		accept_event()
