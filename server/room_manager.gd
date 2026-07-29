class_name ServerRoomManager
extends Node

signal phase_changed(room: Node)
signal meteor_spawned(
	room: Node,
	target: Vector3,
	drift: Vector2,
	damage: int,
	force: float
)
signal shockwave_started(room: Node)
signal session_expired(room: Node, player_id: int)

const ROOM_SCRIPT := preload("res://server/room_state.gd")

var rooms: Array[Node] = []


func _ready() -> void:
	create_room(1)


func create_room(room_id: int) -> Node:
	var room: Node = ROOM_SCRIPT.new()
	room.name = "Room%d" % room_id
	room.room_id = room_id
	add_child(room)
	rooms.append(room)
	room.phase_changed.connect(func() -> void: phase_changed.emit(room))
	room.meteor_spawned.connect(func(
		target: Vector3,
		drift: Vector2,
		damage: int,
		force: float
	) -> void:
		meteor_spawned.emit(room, target, drift, damage, force)
	)
	room.shockwave_started.connect(func() -> void: shockwave_started.emit(room))
	room.session_expired.connect(func(player_id: int) -> void:
		session_expired.emit(room, player_id)
	)
	return room


func fixed_room() -> Node:
	return rooms[0] if not rooms.is_empty() else null


func tick_all() -> void:
	for room in rooms:
		room.tick()


func find_room_for_peer(peer_id: int) -> Node:
	for room in rooms:
		if room.session_manager.find_by_peer_id(peer_id) != null:
			return room
	return null
