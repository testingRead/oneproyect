class_name LocalReferenceMeteor
extends RigidBody3D

signal impacted(meteor: LocalReferenceMeteor, body: Node)
signal deactivated(meteor: LocalReferenceMeteor)

var active := false
var _remaining_lifetime := 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	set_physics_process(false)
	deactivate()


func launch(position_value: Vector3, velocity_value: Vector3) -> void:
	freeze = true
	global_position = position_value
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	show()
	active = true
	_remaining_lifetime = 4.0
	freeze = false
	sleeping = false
	linear_velocity = velocity_value
	set_physics_process(true)


func deactivate() -> void:
	if not active and not visible:
		return
	active = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	hide()
	set_physics_process(false)
	deactivated.emit(self)


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0 or global_position.y < -2.0:
		deactivate()


func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body is LocalBaseCharacter:
		var direction: Vector3 = (
			(body as LocalBaseCharacter).global_position - global_position
		).normalized()
		(body as LocalBaseCharacter).apply_external_push(direction + Vector3.UP * 0.45, 5.5)
	elif body is RigidBody3D:
		(body as RigidBody3D).apply_central_impulse(Vector3.UP * 3.0)
	impacted.emit(self, body)
	call_deferred("deactivate")
