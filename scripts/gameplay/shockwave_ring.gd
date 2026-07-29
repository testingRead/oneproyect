class_name ShockwaveRing
extends Node3D

signal warning_started
signal wave_started

enum Phase {
	IDLE,
	WARNING,
	EXPANDING,
}

const MAX_RADIUS := 27.2
const EXPANSION_SPEED := 12.0
const SAFE_HEIGHT := 1.55

@onready var ring: MeshInstance3D = $Ring

var phase := Phase.IDLE
var _phase_time := 0.0
var _radius := 0.0
var _damage := 18
var _blast_force := 8.5
var _targets: Array[Node] = []
var _resolved_targets: Dictionary = {}


func _ready() -> void:
	reset_ring()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.WARNING:
			_phase_time -= delta
			var pulse := 0.34 + sin(_phase_time * 18.0) * 0.06
			ring.scale = Vector3(pulse, 1.0, pulse)
			if _phase_time <= 0.0:
				_begin_expansion()
		Phase.EXPANDING:
			_radius += EXPANSION_SPEED * delta
			ring.scale = Vector3(_radius, 1.0, _radius)
			_resolve_crossed_players()
			if _radius >= MAX_RADIUS:
				reset_ring()


func launch(warning_time := 0.48, damage := 18, blast_force := 8.5) -> bool:
	if phase != Phase.IDLE:
		return false
	_phase_time = warning_time
	_damage = damage
	_blast_force = blast_force
	_radius = 0.0
	_targets.clear()
	_resolved_targets.clear()
	for candidate in get_tree().get_nodes_in_group("players"):
		_targets.append(candidate)
	phase = Phase.WARNING
	ring.visible = true
	ring.scale = Vector3(0.3, 1.0, 0.3)
	warning_started.emit()
	return true


func reset_ring() -> void:
	phase = Phase.IDLE
	_phase_time = 0.0
	_radius = 0.0
	ring.visible = false
	ring.scale = Vector3.ONE
	_targets.clear()
	_resolved_targets.clear()


func is_available() -> bool:
	return phase == Phase.IDLE


func _begin_expansion() -> void:
	phase = Phase.EXPANDING
	_radius = 0.05
	ring.scale = Vector3(_radius, 1.0, _radius)
	wave_started.emit()


func _resolve_crossed_players() -> void:
	for target in _targets:
		if not is_instance_valid(target) or _resolved_targets.has(target):
			continue
		var flat_distance := Vector2(target.global_position.x, target.global_position.z).length()
		if flat_distance > _radius:
			continue
		_resolved_targets[target] = true
		if target.global_position.y <= SAFE_HEIGHT and target.has_method("apply_damage_and_knockback"):
			target.apply_damage_and_knockback(Vector3.ZERO, _blast_force, _damage)
