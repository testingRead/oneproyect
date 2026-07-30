extends SceneTree

const NET := preload("res://shared/net_constants.gd")
const CODEC := preload("res://shared/net_codec.gd")
const WEAPONS := preload("res://shared/weapon_profiles.gd")

var _failed := false
const ROOM_SCRIPT := preload("res://server/room_state.gd")
const ROOM_MANAGER_SCRIPT := preload("res://server/room_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: Node = ROOM_MANAGER_SCRIPT.new()
	manager.name = "RoomManagerTest"
	root.add_child(manager)
	await process_frame
	for room_id in range(1, NET.MAX_ROOMS + 1):
		_require(manager.create_room(room_id) != null, "Five rooms must be creatable")
	_require(manager.create_room() == null, "A sixth room must be rejected")
	_require(manager.rooms.size() == NET.MAX_ROOMS, "Room manager must enforce its hard limit")
	_require(
		NET.MAX_SERVER_CONNECTIONS == NET.MAX_ROOMS * NET.MAX_PLAYERS_PER_ROOM,
		"ENet capacity must cover every room"
	)
	var empty_room: Node = manager.find_room(3)
	_require(manager.remove_room(empty_room), "An empty room must release its slot")
	_require(manager.create_room(3) != null, "A released room ID must be reusable")
	manager.queue_free()

	var shooter_room: Node = ROOM_SCRIPT.new()
	shooter_room.name = "ShooterRoomTest"
	root.add_child(shooter_room)
	await process_frame
	var shooter: RefCounted = shooter_room.session_manager.register_session(
		50, "cccccccccccccccc", "", "Cata", 0, 0, 0, 0
	)
	var target: RefCounted = shooter_room.session_manager.register_session(
		51, "dddddddddddddddd", "", "Dani", 1, 0, 0, 0
	)
	shooter.position = Vector3(0.0, 1.2, 0.0)
	target.position = Vector3(0.0, 1.2, -5.0)
	shooter_room.phase = NET.RoomPhase.ACTIVE
	shooter_room.mode_id = NET.ModeId.SHOOTER
	shooter_room.round_seed = 1
	shooter_room.phase_end_tick = 1000
	_require(
		shooter_room.apply_shot(
			50,
			Vector3(0.0, 1.6, 0.0),
			Vector3(0.0, 0.0, -1.0)
		),
		"Shooter ray must be accepted during its dedicated mode"
	)
	_require(
		target.health == 76
		and shooter_room.resolved_target_player_id == target.player_id,
		"Server must resolve and damage the closest player on the ray"
	)
	var forged_heal := CODEC.create_owned_state_buffer()
	CODEC.write_owned_state(
		forged_heal,
		1,
		target.position,
		Vector3.ZERO,
		0.0,
		100,
		NET.ALL_BODY_PARTS_MASK
	)
	_require(
		shooter_room.apply_owned_state(51, forged_heal) and target.health == 76,
		"Shooter clients must not overwrite authoritative damage with owned state"
	)
	for shot_index in 4:
		shooter_room.server_tick += 5
		shooter_room.apply_shot(
			50,
			Vector3(0.0, 1.6, 0.0),
			Vector3(0.0, 0.0, -1.0)
		)
	_require(
		target.health == 0
		and not target.active
		and shooter_room.phase_end_tick <= shooter_room.server_tick + 1,
		"Individual shooter must eliminate once and end when one player remains"
	)
	shooter_room.queue_free()

	var reload_room: Node = ROOM_SCRIPT.new()
	reload_room.name = "ReloadRoomTest"
	root.add_child(reload_room)
	await process_frame
	var reloader: RefCounted = reload_room.session_manager.register_session(
		55, "abababababababab", "", "Rafa", 0, 0, 0, 0
	)
	reloader.position = Vector3.ZERO
	reload_room.phase = NET.RoomPhase.ACTIVE
	reload_room.mode_id = NET.ModeId.SHOOTER
	reload_room.round_seed = WEAPONS.Id.T12
	reload_room.phase_end_tick = 2000
	for shell in WEAPONS.magazine_size(WEAPONS.Id.T12):
		reload_room.server_tick += WEAPONS.cooldown_ticks(WEAPONS.Id.T12)
		_require(
			reload_room.apply_shot(55, Vector3.ZERO, Vector3.FORWARD),
			"Every shell inside the authoritative magazine must fire"
		)
	reload_room.server_tick += WEAPONS.cooldown_ticks(WEAPONS.Id.T12)
	_require(
		not reload_room.apply_shot(55, Vector3.ZERO, Vector3.FORWARD),
		"Server must reject firing during authoritative reload"
	)
	reload_room.server_tick = reloader.weapon_reload_until_tick
	_require(
		reload_room.apply_shot(55, Vector3.ZERO, Vector3.FORWARD),
		"Server must accept the next magazine after reload"
	)
	reload_room.queue_free()

	var domain_room: Node = ROOM_SCRIPT.new()
	domain_room.name = "DomainRoomTest"
	root.add_child(domain_room)
	await process_frame
	var controller: RefCounted = domain_room.session_manager.register_session(
		60, "eeeeeeeeeeeeeeee", "", "Ema", 0, 0, 0, 0
	)
	var outsider: RefCounted = domain_room.session_manager.register_session(
		61, "ffffffffffffffff", "", "Fede", 1, 0, 0, 0
	)
	controller.position = Vector3(1.0, 1.2, 1.0)
	outsider.position = Vector3(15.0, 1.2, 15.0)
	domain_room.phase = NET.RoomPhase.ACTIVE
	domain_room.mode_id = NET.ModeId.DOMAIN
	domain_room.phase_end_tick = 1000
	for domain_tick in 20:
		domain_room.tick()
	_require(
		controller.objective_ticks == 20 and outsider.objective_ticks == 0,
		"Domain must score authorized positions without additional network messages"
	)
	domain_room.call("_score_round")
	_require(
		controller.round_points > outsider.round_points,
		"Domain standings must prioritize authorized capture time"
	)
	_require(
		WEAPONS.damage(WEAPONS.Id.T12, 5.0)
		> WEAPONS.damage(WEAPONS.Id.T12, 15.0)
		and WEAPONS.maximum_range(WEAPONS.Id.C16)
		> WEAPONS.maximum_range(WEAPONS.Id.P9),
		"Reusable weapon profiles must preserve distinct range and damage roles"
	)
	domain_room.queue_free()

	var room: Node = ROOM_SCRIPT.new()
	room.name = "RoomTest"
	root.add_child(room)
	await process_frame
	_require(room.phase == NET.RoomPhase.WAITING, "New rooms must wait in the lobby")
	var first: RefCounted = room.session_manager.register_session(
		20,
		"aaaaaaaaaaaaaaaa",
		"",
		"Ana",
		2,
		0,
		0,
		room.server_tick
	)
	var second: RefCounted = room.session_manager.register_session(
		21,
		"bbbbbbbbbbbbbbbb",
		"",
		"Beto",
		3,
		0,
		0,
		room.server_tick
	)
	_require(first != null and second != null, "Fixed room must accept two sessions")
	_require(first.player_id != second.player_id, "Logical player IDs must be stable and unique")
	_require(
		room.session_manager.connected_count() == NET.MIN_PLAYERS_TO_START,
		"Room must count the minimum two connected players"
	)
	_require(
		not room.start_rounds(),
		"Lobby room must reject an arbitrary start before everyone is ready"
	)
	first.ready = true
	second.ready = true
	first.excluded_mode_id = NET.ModeId.SHOOTER
	second.excluded_mode_id = NET.ModeId.DOMAIN
	for sample in 16:
		_require(
			room.call("_pick_next_mode", -1) not in [
				NET.ModeId.SHOOTER,
				NET.ModeId.DOMAIN,
			],
			"Distinct player vetoes must both be honored while three modes remain"
		)
	_require(room.set_total_rounds(3), "Host must be able to select a supported match length")
	_require(room.start_rounds(), "Host-ready room must enter countdown with two players")
	_require(room.total_rounds == 3, "Selected match length must survive match startup")
	room.phase_end_tick = room.server_tick + 1
	room.tick()
	_require(room.phase == NET.RoomPhase.ACTIVE, "Countdown must advance to active play")

	var owned_state := CODEC.create_owned_state_buffer()
	CODEC.write_owned_state(
		owned_state,
		1,
		Vector3(3.25, 2.4, -1.5),
		Vector3(5.5, 6.0, -0.5),
		0.5,
		78,
		NET.ALL_BODY_PARTS_MASK
	)
	_require(room.apply_owned_state(20, owned_state), "Valid owned state must be accepted")
	_require(
		first.position.distance_to(Vector3(3.25, 2.4, -1.5)) < 0.001,
		"Server must preserve the owner's physical result"
	)
	_require(first.health == 78, "Server must retain owner-reported health")
	_require(first.last_state_sequence == 1, "Server must confirm the relayed state")
	_require(
		not room.apply_owned_state(20, owned_state),
		"Duplicate state sequence must be rejected"
	)
	var eliminated_state := CODEC.create_owned_state_buffer()
	CODEC.write_owned_state(
		eliminated_state,
		2,
		first.position,
		Vector3.ZERO,
		0.5,
		0,
		0
	)
	_require(room.apply_owned_state(20, eliminated_state), "Elimination state must be accepted")
	var illegal_revive := CODEC.create_owned_state_buffer()
	CODEC.write_owned_state(
		illegal_revive,
		3,
		first.position,
		Vector3.ZERO,
		0.5,
		100,
		NET.ALL_BODY_PARTS_MASK
	)
	_require(room.apply_owned_state(20, illegal_revive), "Later movement state must still relay")
	_require(first.health == 0 and not first.active, "Eliminated player must stay out for the round")
	second.health = 64
	second.active = true
	room.phase_end_tick = room.server_tick + 1
	room.tick()
	_require(room.phase == NET.RoomPhase.RESULT, "Active round must advance to results")
	_require(
		first.round_points == 0 and second.round_points == 5 and second.score == 5,
		"Only surviving players must receive health-ranked round points"
	)

	var snapshot: PackedByteArray = room.build_snapshot()
	_require(CODEC.is_valid_snapshot(snapshot), "Room snapshot must use compact shared codec")
	_require(CODEC.snapshot_player_count(snapshot) == 2, "Snapshot must include connected players")
	_require(snapshot.size() == 72, "Two-player snapshot must omit three unused player slots")
	_require(
		CODEC.snapshot_player_state_sequence(snapshot, 0) == 3,
		"Snapshot must expose the last relayed state sequence"
	)
	var recipient_snapshot: PackedByteArray = room.build_snapshot_for(first.player_id)
	_require(
		recipient_snapshot.size() == 48
		and CODEC.snapshot_player_count(recipient_snapshot) == 1,
		"Recipient snapshot must omit its redundant local transform"
	)
	_require(
		CODEC.snapshot_ack_sequence(recipient_snapshot) == 3,
		"Recipient snapshot must retain a compact owner confirmation"
	)
	_require(
		room._snapshot_buffers.has(first.player_id),
		"Recipient snapshot buffer must be cached while the player remains"
	)
	room.release_player_cache(first.player_id)
	_require(
		not room._snapshot_buffers.has(first.player_id),
		"Leaving players must release their long-lived snapshot buffer"
	)
	for expected_round in [2, 3]:
		room.phase_end_tick = room.server_tick + 1
		room.tick()
		_require(
			room.phase == NET.RoomPhase.COUNTDOWN
			and first.health == 100
			and first.active,
			"Next countdown must restore eliminated players"
		)
		room.phase_end_tick = room.server_tick + 1
		room.tick()
		_require(
			room.phase == NET.RoomPhase.ACTIVE
			and room.round_number == expected_round,
			"Countdown must start the expected configured round"
		)
		first.health = 90
		first.active = true
		second.health = 80
		second.active = true
		room.phase_end_tick = room.server_tick + 1
		room.tick()
	_require(
		room.match_finished
		and room.round_number == room.total_rounds
		and room.phase == NET.RoomPhase.RESULT
		and room.phase_end_tick == 0,
		"Configured final round must freeze on the final classification"
	)
	var final_standings: Array[RefCounted] = room.standings()
	_require(
		final_standings[0] == second
		and second.score == 13
		and first.score == 10,
		"Accumulated points must determine the match winner across rounds"
	)
	_require(
		second.profile_victories == 1
		and second.profile_experience == 13
		and first.profile_experience == 10,
		"Server session profile must reflect multiplayer results only"
	)
	room.tick()
	_require(
		room.phase == NET.RoomPhase.RESULT,
		"Finished match must not revive or start another minigame automatically"
	)
	_require(room.reopen_waiting_room(), "A finished match must reopen its same room")
	_require(
		room.phase == NET.RoomPhase.WAITING
		and room.round_number == 0
		and not first.ready
		and not second.ready
		and second.profile_victories == 1,
		"Reopening must reset match state while retaining room profile progress"
	)

	var first_id: int = first.player_id
	var first_token: String = first.reconnect_token
	room.host_player_id = first.player_id
	room.session_manager.mark_disconnected(20, room.server_tick)
	room.tick()
	_require(
		room.host_player_id == second.player_id,
		"A connected player must inherit host when the creator disconnects"
	)
	var resumed: RefCounted = room.session_manager.register_session(
		44,
		"aaaaaaaaaaaaaaaa",
		first_token,
		"Ana",
		2,
		0,
		0,
		room.server_tick + 20
	)
	_require(resumed == first, "Reconnect must resume the same session object")
	_require(
		resumed.player_id == first_id
		and resumed.peer_id == 44
		and room.session_manager.last_registration_reconnected,
		"Reconnect must preserve identity while replacing peer_id"
	)

	var expired_state := [false]
	room.session_manager.session_expired.connect(func(player_id: int) -> void:
		expired_state[0] = player_id == first_id
	)
	room.session_manager.mark_disconnected(44, room.server_tick)
	room.session_manager.purge_expired(room.server_tick + NET.RECONNECT_TICKS + 1)
	_require(expired_state[0], "Disconnected session must expire after 60 seconds")
	_require(
		room.session_manager.find_by_player_id(first_id) == null,
		"Expired session must free its room slot"
	)
	print(
		"SERVER_ROOM_OK tick=%d players=%d snapshot_bytes=%d reconnect_ticks=%d"
		% [
			room.server_tick,
			room.session_manager.connected_count(),
			snapshot.size(),
			NET.RECONNECT_TICKS,
		]
	)
	quit(1 if _failed else 0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SERVER_ROOM_FAIL: " + message)
