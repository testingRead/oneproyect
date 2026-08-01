extends SceneTree

const LAB_SCENE := preload("res://scenes/local/local_lab.tscn")
const SHOOTER_MAP: MinigameMapDefinition = preload("res://data/maps/shooter_local.tres")
const CONTENT_REGISTRY := preload("res://scripts/content/content_registry.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectSettings.set_setting(
		"oneproyect/session_minigame_path",
		"res://data/minigames/shooter_local.tres"
	)
	ProjectSettings.set_setting("oneproyect/session_auto_start", false)
	var shooter_discovered := false
	for definition in CONTENT_REGISTRY.load_minigames():
		if definition.minigame_id == &"shooter_local":
			shooter_discovered = true
			break
	_require(shooter_discovered, "The modular catalog must discover shooter without menu edits")
	_require(SHOOTER_MAP.supports_minigame(&"shooter_local"), "Shooter map must declare its mode")
	_require(SHOOTER_MAP.spawn_points.size() == 8, "Shooter must provide eight unique spawns")
	for slot in SHOOTER_MAP.spawn_points.size():
		var spawn := SHOOTER_MAP.get_spawn_for_slot(slot)
		var facing := SHOOTER_MAP.get_team_facing_for_slot(slot)
		_require(
			facing.dot((Vector3(0.0, spawn.y, -20.0) - spawn).normalized()) > 0.95,
			"Every free-for-all spawn must face the arena centre"
		)
	var lab := LAB_SCENE.instantiate() as LocalDevelopmentLab
	root.add_child(lab)
	await process_frame
	lab.round_controller.duration_multiplier = 0.04
	var baseline_nodes := get_node_count()
	_require(lab.start_reference_round(9000), "Shooter round must start")
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.ACTIVE, 180), "Shooter must reach active")
	_require(
		lab.player.is_first_person()
		and lab.crosshair.visible
		and lab.shoot_button.visible
		and lab.reload_button.visible
		and not lab.foot_button.visible
		and not lab.hand_button.visible,
		"Shooter must expose only its first-person combat controls"
	)
	# A touch that starts over DISPARAR belongs to both systems: the button
	# keeps automatic fire active and the global right-half router keeps aiming.
	var touch_index := 31
	var shoot_centre: Vector2 = lab.shoot_button.get_global_rect().get_center()
	var camera_yaw_before := lab.player.camera_pivot.rotation.y
	var ammo_before_touch: int = lab.shooter_host.get_ammo()
	var shoot_press := InputEventScreenTouch.new()
	shoot_press.index = touch_index
	shoot_press.pressed = true
	shoot_press.position = shoot_centre
	lab.look_pad._input(shoot_press)
	lab.shoot_button._gui_input(shoot_press)
	var shoot_drag := InputEventScreenDrag.new()
	shoot_drag.index = touch_index
	shoot_drag.position = shoot_centre + Vector2(96.0, -18.0)
	shoot_drag.relative = Vector2(96.0, -18.0)
	lab.look_pad._input(shoot_drag)
	await physics_frame
	_require(
		lab.look_pad.is_tracking_finger(touch_index)
		and lab.shooter_host.is_trigger_held()
		and lab.shooter_host.get_ammo() < ammo_before_touch
		and absf(lab.player.camera_pivot.rotation.y - camera_yaw_before) > 0.1,
		"Holding fire must rotate the camera with the same right-side finger"
	)
	var shoot_release := InputEventScreenTouch.new()
	shoot_release.index = touch_index
	shoot_release.pressed = false
	shoot_release.position = shoot_drag.position
	lab.look_pad._input(shoot_release)
	lab.shoot_button._gui_input(shoot_release)
	_require(
		not lab.look_pad.is_tracking_finger(touch_index)
		and not lab.shooter_host.is_trigger_held(),
		"Releasing the shared fire/look touch must release both owners"
	)
	# Keep the following combat fixture independent of this input contract.
	lab.shooter_host.set("_cooldown", 0.0)
	var mounted := lab.map_host.get_node_or_null("MountedMap")
	_require(
		mounted != null
		and mounted.has_node("ArenaFloor")
		and mounted.get_children().size() >= 15,
		"Shooter arena must mount boundaries, lanes and cover"
	)
	var bots: Array = lab.shooter_host.get_bots()
	_require(bots.size() == 3, "Solo shooter must create three lightweight practice rivals")
	lab.player.apply_local_damage(1)
	await process_frame
	_require(lab.damage_flash.visible, "Confirmed local damage must produce immediate HUD feedback")
	lab.shooter_host.set_practice_ai_enabled(false)
	var target := bots[0] as LocalBaseCharacter
	lab.player.global_position = Vector3(0.0, 0.02, -14.0)
	lab.player.set_view_direction(Vector3(0.0, 0.0, -1.0))
	lab.player.set_facing_direction(Vector3(0.0, 0.0, -1.0))
	target.global_position = Vector3(0.0, 0.02, -18.0)
	target.set_authoritative_health(34)
	lab.shooter_host.set("_ammo", 1)
	for frame in 4:
		await physics_frame
	_require(lab.shooter_host.request_shot(), "Ready weapon must fire")
	_require(lab.player.visual_root.is_shooting(), "Local body must play recoil animation")
	_require(
		lab.player.visual_root.has_node("Model/RightArmPivot/ItemSocket/ShooterWeapon/MuzzleFlash")
		and (
			lab.player.visual_root.get_node(
				"Model/RightArmPivot/ItemSocket/ShooterWeapon/MuzzleFlash"
			) as MeshInstance3D
		).visible,
		"Every shot must expose the pooled weapon muzzle flash"
	)
	_require(target.get_local_health() == 0, "P9 ray must damage the visible target")
	_require(lab.shooter_host.score == 1, "Elimination must increment local classification")
	_require(lab.player.visual_root.is_reloading(), "Empty magazine must start reload animation")
	_require(lab.banner_detail.text.begins_with("RECARGANDO"), "HUD must announce automatic reload")
	for frame in 105:
		await physics_frame
	_require(
		target.get_local_health() == 100,
		"Eliminated practice rival must respawn with full health"
	)
	# Exercise the same authoritative path used when a LAN guest requests a
	# shot. The confirmation belongs to the shooter, while health belongs to the
	# victim and weapon state belongs to the shooter's own magazine.
	var network_actor := bots[1] as LocalBaseCharacter
	var network_events := {
		"shot_peer": 0,
		"hit_peer": 0,
		"health_peer": 0,
		"weapon_peer": 0,
		"weapon_ammo": -1,
	}
	lab.shooter_host.shot_authorized.connect(func(peer_id: int, _direction: Vector3) -> void:
		network_events.shot_peer = peer_id
	)
	lab.shooter_host.hit_authorized.connect(func(peer_id: int, _health: int) -> void:
		network_events.hit_peer = peer_id
	)
	lab.shooter_host.character_health_authorized.connect(
		func(peer_id: int, _health: int, _respawned: bool, _position: Vector3) -> void:
			network_events.health_peer = peer_id
	)
	lab.shooter_host.weapon_state_authorized.connect(
		func(peer_id: int, ammo: int, _reloading: bool, _remaining: int) -> void:
			network_events.weapon_peer = peer_id
			network_events.weapon_ammo = ammo
	)
	# LAN avatars are presentation proxies: their transforms are interpolated by
	# LocalDevelopmentLab and their own motor never calls move_and_slide().
	network_actor.set_physics_process(false)
	target.set_physics_process(false)
	lab.player.global_position = Vector3(9.0, 0.02, -14.0)
	network_actor.global_position = Vector3(0.0, 0.02, -14.0)
	target.global_position = Vector3(0.0, 0.02, -18.0)
	target.set_authoritative_health(34)
	network_actor.force_update_transform()
	target.force_update_transform()
	await process_frame
	var network_origin := network_actor.global_position + Vector3.UP * 1.38 + Vector3.FORWARD * 0.2
	var network_query := PhysicsRayQueryParameters3D.create(
		network_origin,
		network_origin + Vector3.FORWARD * 27.0,
		1,
		[network_actor.get_rid()]
	)
	var network_probe := network_actor.get_world_3d().direct_space_state.intersect_ray(network_query)
	_require(
		not network_probe.is_empty() and network_probe.collider == target,
		"LAN authority fixture must expose its intended victim first: hit=%s actor=%s target=%s"
		% [network_probe, network_actor.global_position, target.global_position]
	)
	_require(
		lab.shooter_host.process_network_shot(network_actor, Vector3.FORWARD),
		"LAN guest shot must pass authoritative cadence and ammo validation"
	)
	_require(
		int(network_events.shot_peer) == -2
		and int(network_events.hit_peer) == -2
		and int(network_events.health_peer) == -1
		and int(network_events.weapon_peer) == -2
		and int(network_events.weapon_ammo) == 7,
		"LAN shot events must address shooter, victim and magazine independently: %s"
		% [network_events]
	)
	_require(await _wait_for_phase(lab, LocalRoundController.Phase.IDLE, 240), "Shooter must finish and clean")
	_require(
		not lab.player.is_first_person()
		and lab.player.get_local_health() == 100
		and lab.map_host.get_mounted_node_count() == 0
		and get_node_count() == baseline_nodes,
		"Shooter cleanup must restore the exact local baseline"
	)
	print("SHOOTER_ROUND_OK score=%d baseline_nodes=%d" % [lab.shooter_host.score, baseline_nodes])
	quit(1 if _failed else 0)


func _wait_for_phase(lab: LocalDevelopmentLab, wanted: int, limit: int) -> bool:
	for frame in limit:
		if lab.round_controller.phase == wanted:
			return true
		await physics_frame
	return false


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("SHOOTER_ROUND_FAIL: %s" % message)
