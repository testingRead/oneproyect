class_name MeteorSlot
extends Node3D

signal became_available
signal warning_started
signal impacted

enum Phase {
	IDLE,
	WARNING,
	FALLING,
	IMPACT,
}

@onready var marker: MeshInstance3D = $WarningMarker
@onready var body: RigidBody3D = $Meteor
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var blast_area: Area3D = $BlastArea

var phase := Phase.IDLE
var _phase_time := 0.0
var _launch_velocity := Vector3.ZERO
var _damage := 24
var _blast_force := 10.0


func _ready() -> void:
	body.body_entered.connect(_on_body_entered)
	reset_slot()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.WARNING:
			_phase_time -= delta
			var pulse := 0.88 + sin(_phase_time * 14.0) * 0.12
			marker.scale = Vector3(pulse, 1.0, pulse)
			if _phase_time <= 0.0:
				_begin_fall()
		Phase.FALLING:
			if body.global_position.y < -4.0:
				_begin_impact()
		Phase.IMPACT:
			_phase_time -= delta
			var progress: float = 1.0 - clampf(_phase_time / 0.34, 0.0, 1.0)
			var size := lerpf(0.2, 1.25, progress)
			shockwave.scale = Vector3(size, 1.0, size)
			if _phase_time <= 0.0:
				reset_slot()


func launch(target: Vector3, horizontal_velocity: Vector2, warning_time: float, damage: int, blast_force: float) -> void:
	global_position = target
	_launch_velocity = Vector3(horizontal_velocity.x, -3.0, horizontal_velocity.y)
	_damage = damage
	_blast_force = blast_force
	_phase_time = warning_time
	phase = Phase.WARNING
	marker.visible = true
	marker.scale = Vector3.ONE
	shockwave.visible = false
	body.visible = false
	body.freeze = true
	body.position = Vector3(0.0, 12.0, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	warning_started.emit()


func is_available() -> bool:
	return phase == Phase.IDLE


func reset_slot() -> void:
	phase = Phase.IDLE
	_phase_time = 0.0
	marker.visible = false
	shockwave.visible = false
	body.visible = false
	body.freeze = true
	body.collision_layer = 0
	body.position = Vector3(0.0, 12.0, 0.0)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	became_available.emit()


func _begin_fall() -> void:
	phase = Phase.FALLING
	marker.visible = false
	body.visible = true
	body.freeze = false
	body.collision_layer = 2
	body.linear_velocity = _launch_velocity
	body.angular_velocity = Vector3(3.2, 1.8, 2.7)


func _on_body_entered(_other: Node) -> void:
	if phase == Phase.FALLING:
		_begin_impact()


func _begin_impact() -> void:
	if phase != Phase.FALLING:
		return
	phase = Phase.IMPACT
	_phase_time = 0.34
	body.freeze = true
	body.visible = false
	body.collision_layer = 0
	shockwave.visible = true
	shockwave.scale = Vector3(0.2, 1.0, 0.2)
	for nearby_body in blast_area.get_overlapping_bodies():
		if nearby_body.has_method("apply_damage_and_knockback"):
			nearby_body.apply_damage_and_knockback(global_position, _blast_force, _damage)
	impacted.emit()
