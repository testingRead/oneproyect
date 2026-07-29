class_name ServerRoomManager
extends Node

const NET := preload("res://shared/net_constants.gd")

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
signal standings_changed(room: Node)

const ROOM_SCRIPT := preload("res://server/room_state.gd")

var rooms: Array[Node] = []


func _ready() -> void:
	pass


func create_room(room_id := 0) -> Node:
	if rooms.size() >= NET.MAX_ROOMS:
		return null
	if room_id <= 0:
		room_id = _next_available_room_id()
	if room_id <= 0 or find_room(room_id) != null:
		return null
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
	room.standings_changed.connect(func() -> void:
		standings_changed.emit(room)
	)
	return room


func fixed_room() -> Node:
	var room := find_room(1)
	return room if room != null else create_room(1)


func remove_room(room: Node) -> bool:
	if room == null or room not in rooms:
		return false
	if room.session_manager != null and not room.session_manager.sessions.is_empty():
		return false
	rooms.erase(room)
	room.queue_free()
	return true


func find_room(room_id: int) -> Node:
	for room in rooms:
		if room.room_id == room_id:
			return room
	return null


func find_room_for_stable_id(stable_id: String) -> Node:
	for room in rooms:
		if room.session_manager.find_by_stable_id(stable_id) != null:
			return room
	return null


func tick_all() -> void:
	for room in rooms:
		room.tick()


func find_room_for_peer(peer_id: int) -> Node:
	for room in rooms:
		if room.session_manager.find_by_peer_id(peer_id) != null:
			return room
	return null


func _next_available_room_id() -> int:
	for room_id in range(1, NET.MAX_ROOMS + 1):
		if find_room(room_id) == null:
			return room_id
	return 0
