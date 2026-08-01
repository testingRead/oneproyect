class_name LocalShooterHost
extends Node

signal score_changed(player_score: int, rival_score: int, target: int)
signal ammo_changed(current: int, maximum: int, reloading: bool)
signal combat_message(text: String)
signal shot_fired(origin: Vector3, hit_position: Vector3, weapon_id: int)
signal hit_confirmed(remaining_health: int)
signal match_completed(player_score: int, rival_score: int)
signal shot_requested(direction: Vector3)
signal reload_requested
signal shot_authorized(peer_id: int, direction: Vector3)
signal weapon_state_authorized(peer_id: int, ammo: int, reloading: bool, remaining_msec: int)
signal hit_authorized(peer_id: int, remaining_health: int)
signal character_health_authorized(peer_id: int, health: int, respawned: bool, position: Vector3)
signal classification_authorized(peer_ids: PackedInt32Array, kills: PackedInt32Array, complete: bool, winner_peer_id: int)

const WEAPONS := preload("res://shared/weapon_profiles.gd")
const CHARACTER_SCENE := preload("res://scenes/local/base_character.tscn")
const TARGET_SCORE := 5
const BOT_COUNT := 3
const TRACER_COUNT := 10

var score := 0
var opponent_score := 0
var _active := false
var _complete := false
var _session_authority := true
var _generation := 0
var _map_root: Node3D
var _map_contract: Node
var _player: LocalBaseCharacter
var _weapon_id := WEAPONS.Id.P9
var _ammo := 0
var _cooldown := 0.0
var _reload_remaining := 0.0
var _bots: Array[LocalBaseCharacter] = []
var _participants: Array[LocalBaseCharacter] = []
var _bot_state: Dictionary = {}
var _respawning: Dictionary = {}
var _kill_scores: Dictionary = {}
var _network_next_shot_msec: Dictionary = {}
var _network_ammo: Dictionary = {}
var _network_reload_ready_msec: Dictionary = {}
var _tracers: Array[MeshInstance3D] = []
var _tracer_lifetimes := PackedFloat32Array()
var _shot_audio: AudioStreamPlayer
var _practice_ai_enabled := true
var _trigger_held := false


func _ready() -> void:
	_shot_audio = AudioStreamPlayer.new()
	_shot_audio.name = "ShooterAudio"
	_shot_audio.stream = _build_shot_stream(WEAPONS.Id.P9)
	var config := ConfigFile.new()
	if config.load("user://profile.cfg") == OK:
		_shot_audio.volume_db = 0.0 if bool(config.get_value("settings", "sound", true)) else -80.0
	add_child(_shot_audio)


func start_match(
	map_root: Node3D,
	player: LocalBaseCharacter,
	round_seed: int,
	spawn_practice_bots := true
) -> bool:
	stop_and_clean()
	if map_root == null or player == null:
		return false
	_generation += 1
	_map_root = map_root
	_map_contract = map_root.get_parent()
	_player = player
	_weapon_id = WEAPONS.from_round_seed(round_seed)
	_shot_audio.stream = _build_shot_stream(_weapon_id)
	_ammo = WEAPONS.magazine_size(_weapon_id)
	_cooldown = 0.0
	_reload_remaining = 0.0
	score = 0
	opponent_score = 0
	_complete = false
	_active = true
	_practice_ai_enabled = true
	for candidate in get_tree().get_nodes_in_group(&"local_base_character"):
		if candidate is LocalBaseCharacter:
			var participant := candidate as LocalBaseCharacter
			var slot := int(participant.get_meta(&"lan_slot", 0))
			participant.set_player_slot_color(slot)
			participant.set_spawn_transform(_get_spawn(slot))
			var spawn_facing := _get_spawn_facing(participant.global_position)
			participant.set_facing_direction(spawn_facing)
			if participant == _player:
				participant.set_view_direction(spawn_facing)
			participant.reset_local_health()
			participant.visual_root.set_shooter_weapon(true, _weapon_id)
			if participant != _player:
				_ensure_health_label(participant)
			_participants.append(participant)
			var peer_id := int(participant.get_meta(&"lan_peer_id", 1))
			_kill_scores[peer_id] = 0
			_network_ammo[peer_id] = WEAPONS.magazine_size(_weapon_id)
	_prepare_tracers()
	if (
		spawn_practice_bots
		and get_tree().get_nodes_in_group(&"local_base_character").size() <= 1
	):
		_spawn_practice_bots()
	score_changed.emit(score, opponent_score, TARGET_SCORE)
	ammo_changed.emit(_ammo, WEAPONS.magazine_size(_weapon_id), false)
	combat_message.emit("Arma lista · %s" % WEAPONS.display_name(_weapon_id))
	return true


func _physics_process(delta: float) -> void:
	if not _active:
		_update_tracers(delta)
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		if _reload_remaining <= 0.0:
			_ammo = WEAPONS.magazine_size(_weapon_id)
			ammo_changed.emit(_ammo, _ammo, false)
			combat_message.emit("RECARGA COMPLETA")
	if _session_authority and _practice_ai_enabled:
		_update_bots(delta)
	if _session_authority:
		_finish_network_reloads()
	# Android touch actions are emitted by their dedicated buttons. Polling the
	# mouse-bound action there would turn joystick/look touches into shots when
	# touch-to-mouse emulation is enabled.
	if is_instance_valid(_player) and _player.controls_enabled and not OS.has_feature("mobile"):
		if Input.is_action_pressed("shoot"):
			request_shot()
		if Input.is_action_just_pressed("reload"):
			request_reload()
	elif is_instance_valid(_player) and _player.controls_enabled and _trigger_held:
		request_shot()
	_update_tracers(delta)


func request_shot(shooter: LocalBaseCharacter = null) -> bool:
	var actor := shooter if is_instance_valid(shooter) else _player
	if (
		not _active
		or not is_instance_valid(actor)
		or actor.get_local_health() <= 0
		or _cooldown > 0.0
		or _reload_remaining > 0.0
	):
		return false
	if actor == _player and _ammo <= 0:
		request_reload()
		return false
	if actor == _player:
		_ammo -= 1
		_cooldown = WEAPONS.cooldown_seconds(_weapon_id)
		ammo_changed.emit(_ammo, WEAPONS.magazine_size(_weapon_id), false)
	actor.visual_root.trigger_shoot()
	if actor == _player:
		_shot_audio.play()
	var origin := actor.get_shoot_origin()
	var direction := actor.get_shoot_direction()
	var result := (
		_resolve_hitscan(actor, origin, direction, _weapon_id)
		if _session_authority
		else {
			"position": origin + direction * WEAPONS.maximum_range(_weapon_id),
			"targets": 0,
		}
	)
	var hit_position: Vector3 = result.position
	_spawn_tracer(origin, hit_position)
	shot_fired.emit(origin, hit_position, _weapon_id)
	if actor == _player and not _session_authority:
		shot_requested.emit(direction)
	elif _session_authority:
		shot_authorized.emit(int(actor.get_meta(&"lan_peer_id", 1)), direction)
	if actor == _player and _ammo <= 0:
		request_reload()
	return true


func request_reload() -> bool:
	if (
		not _active
		or _reload_remaining > 0.0
		or _ammo >= WEAPONS.magazine_size(_weapon_id)
		or not is_instance_valid(_player)
	):
		return false
	_reload_remaining = WEAPONS.reload_seconds(_weapon_id)
	_player.visual_root.trigger_reload(_reload_remaining)
	ammo_changed.emit(_ammo, WEAPONS.magazine_size(_weapon_id), true)
	combat_message.emit("RECARGANDO…")
	if not _session_authority:
		reload_requested.emit()
	return true


func set_session_authority(enabled: bool) -> void:
	_session_authority = enabled


func set_trigger_held(enabled: bool) -> void:
	_trigger_held = enabled


func process_network_shot(actor: LocalBaseCharacter, direction: Vector3) -> bool:
	if (
		not _session_authority
		or not _active
		or not is_instance_valid(actor)
		or actor.get_local_health() <= 0
	):
		return false
	var safe_direction := direction.normalized()
	if not safe_direction.is_finite() or safe_direction.length_squared() < 0.9:
		return false
	var peer_id := int(actor.get_meta(&"lan_peer_id", 0))
	var now := Time.get_ticks_msec()
	if (
		now < int(_network_next_shot_msec.get(peer_id, 0))
		or now < int(_network_reload_ready_msec.get(peer_id, 0))
	):
		return false
	var current_ammo := int(_network_ammo.get(peer_id, WEAPONS.magazine_size(_weapon_id)))
	if current_ammo <= 0:
		_start_network_reload(peer_id, actor)
		return false
	current_ammo -= 1
	_network_ammo[peer_id] = current_ammo
	_network_next_shot_msec[peer_id] = (
		now + roundi(WEAPONS.cooldown_seconds(_weapon_id) * 1000.0)
	)
	actor.set_facing_direction(Vector3(safe_direction.x, 0.0, safe_direction.z))
	actor.visual_root.trigger_shoot()
	var origin := actor.global_position + Vector3.UP * 1.38 + safe_direction * 0.2
	var result := _resolve_hitscan(actor, origin, safe_direction, _weapon_id)
	_spawn_tracer(origin, result.position)
	shot_fired.emit(origin, result.position, _weapon_id)
	shot_authorized.emit(int(actor.get_meta(&"lan_peer_id", 1)), safe_direction)
	weapon_state_authorized.emit(peer_id, current_ammo, false, 0)
	if current_ammo <= 0:
		_start_network_reload(peer_id, actor)
	return true


func process_network_reload(actor: LocalBaseCharacter) -> bool:
	if not _session_authority or not _active or not is_instance_valid(actor):
		return false
	var peer_id := int(actor.get_meta(&"lan_peer_id", 0))
	if actor.get_local_health() <= 0 or peer_id == 0:
		return false
	return _start_network_reload(peer_id, actor)


func apply_authoritative_weapon_state(ammo: int, reloading: bool, remaining_msec: int) -> void:
	_ammo = clampi(ammo, 0, WEAPONS.magazine_size(_weapon_id))
	_reload_remaining = maxf(0.0, float(remaining_msec) / 1000.0) if reloading else 0.0
	if is_instance_valid(_player) and reloading:
		_player.visual_root.trigger_reload(_reload_remaining)
	ammo_changed.emit(_ammo, WEAPONS.magazine_size(_weapon_id), reloading)
	if reloading:
		combat_message.emit("RECARGANDO…")


func play_remote_shot(actor: LocalBaseCharacter, direction: Vector3) -> void:
	if not is_instance_valid(actor):
		return
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() < 0.9:
		return
	actor.set_facing_direction(Vector3(safe_direction.x, 0.0, safe_direction.z))
	actor.visual_root.trigger_shoot()
	_shot_audio.play()
	var origin := actor.global_position + Vector3.UP * 1.38 + safe_direction * 0.2
	_spawn_tracer(origin, origin + safe_direction * WEAPONS.maximum_range(_weapon_id))


func apply_authoritative_classification(
	peer_ids: PackedInt32Array,
	kills: PackedInt32Array,
	complete: bool
) -> void:
	_kill_scores.clear()
	for index in mini(peer_ids.size(), kills.size()):
		_kill_scores[peer_ids[index]] = maxi(0, kills[index])
	_refresh_local_classification()
	_complete = complete
	if complete:
		_active = false
	score_changed.emit(score, opponent_score, TARGET_SCORE)


func apply_authoritative_character_state(
	character: LocalBaseCharacter,
	health: int,
	respawned: bool,
	position_value: Vector3
) -> void:
	if not is_instance_valid(character):
		return
	character.set_authoritative_health(health)
	_update_bot_label(character)
	if health <= 0:
		character.controls_enabled = false
		_set_eliminated(character, true)
		if character == _player:
			combat_message.emit("ELIMINADO · REAPARECES EN 1.6 s")
	elif respawned:
		character.global_position = position_value
		character.velocity = Vector3.ZERO
		_set_eliminated(character, false)
		character.controls_enabled = character == _player


func is_complete() -> bool:
	return _complete


func is_active() -> bool:
	return _active


func get_winner() -> int:
	if score > opponent_score:
		return 1
	if opponent_score > score:
		return -1
	return 0


func get_weapon_id() -> int:
	return _weapon_id


func get_ammo() -> int:
	return _ammo


func get_bots() -> Array[LocalBaseCharacter]:
	return _bots


func set_practice_ai_enabled(enabled: bool) -> void:
	_practice_ai_enabled = enabled
	if not enabled:
		for bot in _bots:
			if is_instance_valid(bot):
				bot.set_movement_override(Vector2.ZERO, false)


func finish_match() -> void:
	if not _active:
		return
	_active = false
	for bot in _bots:
		if is_instance_valid(bot):
			bot.set_movement_override(Vector2.ZERO, false)
	match_completed.emit(score, opponent_score)


func stop_and_clean() -> void:
	_generation += 1
	_active = false
	_complete = false
	if is_instance_valid(_player):
		_set_eliminated(_player, false)
	for participant in _participants:
		if is_instance_valid(participant):
			_set_eliminated(participant, false)
			participant.reset_local_health()
			participant.set_movement_override(Vector2.ZERO, false)
			participant.visual_root.set_shooter_weapon(false)
			var health_label := participant.get_node_or_null("HealthLabel")
			if health_label != null:
				health_label.queue_free()
	_participants.clear()
	_kill_scores.clear()
	_network_next_shot_msec.clear()
	_network_ammo.clear()
	_network_reload_ready_msec.clear()
	for bot in _bots:
		if is_instance_valid(bot):
			bot.set_movement_override(Vector2.ZERO, false)
			bot.queue_free()
	_bots.clear()
	_bot_state.clear()
	_respawning.clear()
	for tracer in _tracers:
		if is_instance_valid(tracer):
			tracer.queue_free()
	_tracers.clear()
	_tracer_lifetimes = PackedFloat32Array()
	_map_root = null
	_map_contract = null
	_player = null
	_reload_remaining = 0.0
	_cooldown = 0.0
	_trigger_held = false


func _resolve_hitscan(
	actor: LocalBaseCharacter,
	origin: Vector3,
	direction: Vector3,
	weapon_id: int
) -> Dictionary:
	var maximum_range := WEAPONS.maximum_range(weapon_id)
	var best_position := origin + direction * maximum_range
	var hit_targets: Dictionary = {}
	var directions: Array[Vector3] = [direction]
	if weapon_id == WEAPONS.Id.T12:
		var right := direction.cross(Vector3.UP).normalized()
		var up := right.cross(direction).normalized()
		directions = [
			direction,
			(direction + right * 0.055).normalized(),
			(direction - right * 0.055).normalized(),
			(direction + up * 0.045).normalized(),
			(direction - up * 0.045).normalized(),
		]
	for ray_direction in directions:
		var query := PhysicsRayQueryParameters3D.create(
			origin,
			origin + ray_direction * maximum_range,
			1,
			[actor.get_rid()]
		)
		query.collide_with_areas = false
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.position
		if origin.distance_squared_to(hit_position) < origin.distance_squared_to(best_position):
			best_position = hit_position
		var target := hit.collider as LocalBaseCharacter
		if target == null or target == actor or target.get_local_health() <= 0:
			continue
		hit_targets[target.get_instance_id()] = target
	for target: LocalBaseCharacter in hit_targets.values():
		var distance := origin.distance_to(target.global_position)
		target.apply_local_damage(WEAPONS.damage(weapon_id, distance))
		_update_bot_label(target)
		if actor == _player:
			hit_confirmed.emit(target.get_local_health())
		hit_authorized.emit(
			int(actor.get_meta(&"lan_peer_id", 1)), target.get_local_health()
		)
		character_health_authorized.emit(
			int(target.get_meta(&"lan_peer_id", 1)),
			target.get_local_health(),
			false,
			target.global_position
		)
		if actor == _player:
			combat_message.emit("IMPACTO · %d VIDA" % target.get_local_health())
		if target.get_local_health() <= 0:
			_register_elimination(actor, target)
	return {"position": best_position, "targets": hit_targets.size()}


func _register_elimination(actor: LocalBaseCharacter, target: LocalBaseCharacter) -> void:
	if _respawning.has(target.get_instance_id()):
		return
	_set_eliminated(target, true)
	var actor_peer_id := int(actor.get_meta(&"lan_peer_id", 1))
	_kill_scores[actor_peer_id] = int(_kill_scores.get(actor_peer_id, 0)) + 1
	_refresh_local_classification()
	if actor == _player:
		combat_message.emit("ELIMINACIÓN · %d/%d" % [score, TARGET_SCORE])
	elif target == _player:
		combat_message.emit("HAS SIDO ELIMINADO")
	_complete = int(_kill_scores[actor_peer_id]) >= TARGET_SCORE
	score_changed.emit(score, opponent_score, TARGET_SCORE)
	_emit_classification()
	if _complete:
		finish_match()
		return
	_respawn_character(target, _generation)


func _respawn_character(character: LocalBaseCharacter, generation: int) -> void:
	var key := character.get_instance_id()
	_respawning[key] = true
	character.controls_enabled = false
	character.set_movement_override(Vector2.ZERO, false)
	await get_tree().create_timer(1.6).timeout
	if generation != _generation or not _active or not is_instance_valid(character):
		_respawning.erase(key)
		return
	character.reset_local_health()
	character.reset_to_spawn()
	var respawn_facing := _get_spawn_facing(character.global_position)
	character.set_facing_direction(respawn_facing)
	if character == _player:
		character.set_view_direction(respawn_facing)
	_set_eliminated(character, false)
	_update_bot_label(character)
	var peer_id := int(character.get_meta(&"lan_peer_id", 1))
	if character == _player:
		_ammo = WEAPONS.magazine_size(_weapon_id)
		_reload_remaining = 0.0
		ammo_changed.emit(_ammo, _ammo, false)
	_network_reload_ready_msec.erase(peer_id)
	_network_ammo[peer_id] = WEAPONS.magazine_size(_weapon_id)
	if _session_authority and peer_id > 0:
		weapon_state_authorized.emit(
			peer_id, WEAPONS.magazine_size(_weapon_id), false, 0
		)
	character.controls_enabled = character == _player
	if character != _player:
		character.set_movement_override(Vector2.ZERO, true)
	_respawning.erase(key)
	character_health_authorized.emit(
		peer_id,
		character.get_local_health(),
		true,
		character.global_position
	)


func _set_eliminated(character: LocalBaseCharacter, eliminated: bool) -> void:
	character.visual_root.visible = not eliminated
	character.collision.set_deferred("disabled", eliminated)
	var label := character.get_node_or_null("HealthLabel") as Label3D
	if label != null:
		label.visible = not eliminated


func _spawn_practice_bots() -> void:
	for index in BOT_COUNT:
		var bot := CHARACTER_SCENE.instantiate() as LocalBaseCharacter
		bot.name = "ShooterBot%d" % (index + 1)
		bot.controls_enabled = false
		bot.emit_metrics = false
		bot.set_meta(&"display_name", "BOT %d" % (index + 1))
		bot.set_meta(&"lan_slot", index + 1)
		bot.set_meta(&"lan_peer_id", -(index + 1))
		var camera := bot.get_node("CameraPivot/SpringArm/Camera") as Camera3D
		camera.current = false
		_map_root.add_child(bot)
		bot.set_player_slot_color(index + 1)
		var spawn := _get_spawn(index + 1)
		bot.set_spawn_transform(spawn)
		bot.set_facing_direction(_get_spawn_facing(bot.global_position))
		bot.visual_root.set_shooter_weapon(true, _weapon_id)
		_ensure_health_label(bot)
		bot.set_movement_override(Vector2.ZERO, true)
		_bots.append(bot)
		_kill_scores[-(index + 1)] = 0
		_bot_state[bot.get_instance_id()] = {
			"phase": float(index) * 1.7,
			"shoot": 1.15 + float(index) * 0.42,
		}


func _start_network_reload(peer_id: int, actor: LocalBaseCharacter) -> bool:
	var now := Time.get_ticks_msec()
	if now < int(_network_reload_ready_msec.get(peer_id, 0)):
		return false
	var maximum := WEAPONS.magazine_size(_weapon_id)
	if int(_network_ammo.get(peer_id, maximum)) >= maximum:
		return false
	var remaining_msec := roundi(WEAPONS.reload_seconds(_weapon_id) * 1000.0)
	_network_reload_ready_msec[peer_id] = now + remaining_msec
	actor.visual_root.trigger_reload(float(remaining_msec) / 1000.0)
	weapon_state_authorized.emit(
		peer_id,
		int(_network_ammo.get(peer_id, 0)),
		true,
		remaining_msec
	)
	return true


func _finish_network_reloads() -> void:
	var now := Time.get_ticks_msec()
	var completed := PackedInt32Array()
	for peer_id_value: Variant in _network_reload_ready_msec:
		var peer_id := int(peer_id_value)
		if now >= int(_network_reload_ready_msec[peer_id]):
			completed.append(peer_id)
	for peer_id in completed:
		_network_reload_ready_msec.erase(peer_id)
		_network_ammo[peer_id] = WEAPONS.magazine_size(_weapon_id)
		weapon_state_authorized.emit(
			peer_id, WEAPONS.magazine_size(_weapon_id), false, 0
		)


func _update_bots(delta: float) -> void:
	for bot in _bots:
		if not is_instance_valid(bot) or bot.get_local_health() <= 0:
			continue
		var key := bot.get_instance_id()
		var state: Dictionary = _bot_state[key]
		state.phase = float(state.phase) + delta * 0.48
		state.shoot = float(state.shoot) - delta
		var centre := _get_arena_centre()
		var wanted := centre + Vector3(
			cos(float(state.phase)) * (7.0 + float(key % 4)),
			0.0,
			sin(float(state.phase) * 0.83) * (9.0 + float(key % 3))
		)
		var move_direction := wanted - bot.global_position
		move_direction.y = 0.0
		if move_direction.length_squared() > 0.2:
			move_direction = move_direction.normalized()
			bot.set_movement_override(Vector2(move_direction.x, move_direction.z) * 0.72, true)
		if float(state.shoot) <= 0.0 and is_instance_valid(_player) and _player.get_local_health() > 0:
			state.shoot = 1.35 + float(key % 5) * 0.17
			_try_bot_shot(bot)
		_bot_state[key] = state


func _try_bot_shot(bot: LocalBaseCharacter) -> void:
	var target_position := _player.global_position + Vector3.UP * 0.9
	var origin := bot.global_position + Vector3.UP * 1.15
	var direction := target_position - origin
	var distance := direction.length()
	if distance > 25.0 or distance < 0.2:
		return
	direction /= distance
	bot.set_facing_direction(Vector3(direction.x, 0.0, direction.z))
	var query := PhysicsRayQueryParameters3D.create(origin, target_position, 1, [bot.get_rid()])
	var hit := bot.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != _player:
		return
	bot.visual_root.trigger_shoot()
	_shot_audio.play()
	_spawn_tracer(origin, target_position)
	_player.apply_local_damage(12)
	if _player.get_local_health() <= 0:
		_register_elimination(bot, _player)


func _get_spawn(slot: int) -> Transform3D:
	if is_instance_valid(_map_contract) and _map_contract.has_method("get_spawn_transform"):
		return _map_contract.call("get_spawn_transform", slot)
	return Transform3D(Basis.IDENTITY, Vector3(float(slot * 3), 0.02, -20.0))


func _get_spawn_facing(position_value: Vector3) -> Vector3:
	var centre := _get_arena_centre()
	centre.y = position_value.y
	var facing := centre - position_value
	facing.y = 0.0
	return facing.normalized() if facing.length_squared() > 0.01 else Vector3.FORWARD


func _get_arena_centre() -> Vector3:
	if is_instance_valid(_map_contract):
		var definition: Variant = _map_contract.get("current_definition")
		if definition != null and not definition.event_points.is_empty():
			return definition.event_points[0]
	return Vector3(0.0, 0.0, -20.0)


func _refresh_local_classification() -> void:
	var local_peer_id := int(_player.get_meta(&"lan_peer_id", 1)) if is_instance_valid(_player) else 1
	score = int(_kill_scores.get(local_peer_id, 0))
	opponent_score = 0
	for peer_id: Variant in _kill_scores:
		if int(peer_id) != local_peer_id:
			opponent_score = maxi(opponent_score, int(_kill_scores[peer_id]))


func _emit_classification() -> void:
	var ids := PackedInt32Array(_kill_scores.keys())
	ids.sort()
	var kills := PackedInt32Array()
	var winner_peer_id := 0
	for peer_id in ids:
		var value := int(_kill_scores[peer_id])
		kills.append(value)
		if value >= TARGET_SCORE:
			winner_peer_id = peer_id
	classification_authorized.emit(ids, kills, _complete, winner_peer_id)


func _update_bot_label(character: LocalBaseCharacter) -> void:
	var label := character.get_node_or_null("HealthLabel") as Label3D
	if label == null:
		return
	label.text = "%s · %d" % [
		str(character.get_meta(&"display_name", "RIVAL")),
		character.get_local_health(),
	]
	label.modulate = (
		Color(0.45, 1.0, 0.52)
		if character.get_local_health() > 50
		else Color(1.0, 0.72, 0.18)
		if character.get_local_health() > 0
		else Color(1.0, 0.18, 0.12)
	)


func _ensure_health_label(character: LocalBaseCharacter) -> void:
	if character.get_node_or_null("HealthLabel") == null:
		var health_label := Label3D.new()
		health_label.name = "HealthLabel"
		health_label.position = Vector3(0.0, 2.18, 0.0)
		health_label.font_size = 28
		health_label.pixel_size = 0.0035
		health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Names are readable in direct sight but never reveal a rival through cover.
		health_label.no_depth_test = false
		character.add_child(health_label)
	_update_bot_label(character)


func _prepare_tracers() -> void:
	for index in TRACER_COUNT:
		var tracer := MeshInstance3D.new()
		tracer.name = "LocalTracer%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.028
		mesh.height = 1.0
		mesh.radial_segments = 6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.72, 0.14)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.3, 0.04)
		mesh.material = material
		tracer.mesh = mesh
		tracer.visible = false
		tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_map_root.add_child(tracer)
		_tracers.append(tracer)
		_tracer_lifetimes.append(0.0)


func _spawn_tracer(origin: Vector3, target: Vector3) -> void:
	var direction := target - origin
	var length := direction.length()
	if length < 0.05 or _tracers.is_empty():
		return
	var slot := 0
	for index in _tracer_lifetimes.size():
		if _tracer_lifetimes[index] <= 0.0:
			slot = index
			break
	var tracer := _tracers[slot]
	tracer.global_position = origin + direction * 0.5
	tracer.scale = Vector3(1.0, length, 1.0)
	tracer.look_at(target, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	tracer.visible = true
	_tracer_lifetimes[slot] = 0.09


func _update_tracers(delta: float) -> void:
	for index in _tracer_lifetimes.size():
		if _tracer_lifetimes[index] <= 0.0:
			continue
		_tracer_lifetimes[index] = maxf(0.0, _tracer_lifetimes[index] - delta)
		if _tracer_lifetimes[index] <= 0.0 and is_instance_valid(_tracers[index]):
			_tracers[index].visible = false


func _build_shot_stream(weapon_id: int) -> AudioStreamWAV:
	const MIX_RATE := 11025
	var duration := 0.24 if weapon_id == WEAPONS.Id.T12 else 0.1 if weapon_id == WEAPONS.Id.C16 else 0.12
	var start_frequency := 520.0 if weapon_id == WEAPONS.Id.T12 else 1280.0 if weapon_id == WEAPONS.Id.C16 else 980.0
	var end_frequency := 78.0 if weapon_id == WEAPONS.Id.T12 else 240.0 if weapon_id == WEAPONS.Id.C16 else 180.0
	var frame_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frame_count)
	var noise_state := 91357
	for frame in frame_count:
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var progress := float(frame) / frame_count
		var time := float(frame) / MIX_RATE
		var crack := sin(TAU * lerpf(start_frequency, end_frequency, progress) * time)
		var noise := float(noise_state % 2001 - 1000) / 1000.0
		var sample := (crack * 0.68 + noise * 0.32) * pow(1.0 - progress, 3.0) * 0.7
		data[frame] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
