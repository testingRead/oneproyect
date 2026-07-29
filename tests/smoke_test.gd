extends SceneTree

const EXPECTED_METEOR_POOL := 8
const NETWORK_SCRIPT := preload("res://scripts/network/network_manager.gd")
const REMOTE_AVATAR_SCENE := preload("res://scenes/components/remote_avatar.tscn")


func _init() -> void:
	call_deferred("_run")


func _ensure_network() -> void:
	if not root.has_node("Network"):
		var network := NETWORK_SCRIPT.new()
		network.name = "Network"
		root.add_child(network)


func _run() -> void:
	_ensure_network()
	var packed: PackedScene = load("res://scenes/main.tscn")
	_require(packed != null, "Main scene must load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var lights := game.find_children("*", "Light3D", true, false)
	_require(lights.size() <= 1, "Low-end budget allows at most one light")
	for light: Light3D in lights:
		_require(not light.shadow_enabled, "Low-end light must not cast shadows")
	var meshes := game.get_node("World").find_children("*", "MeshInstance3D", true, false)
	_require(meshes.size() <= 64, "Low-end world mesh-node budget exceeded")
	_require(
		ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility",
		"Project must use the Compatibility renderer"
	)
	_require(
		int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 4,
		"Android orientation must remain landscape sensor"
	)

	var disaster: DisasterController = game.get_node("World/DisasterController")
	_require(
		disaster.get_registered_mode_ids() == [&"meteors", &"shockwave", &"flood"],
		"Round controller must discover independent minigame modules in scene order"
	)
	var meteors := disaster.get_node("MeteorMode").find_children("Meteor*", "", false, false)
	_require(meteors.size() == EXPECTED_METEOR_POOL, "Meteor pool must be preallocated")
	var shockwaves := disaster.get_node("ShockwaveMode").find_children(
		"ShockwaveRing",
		"",
		false,
		false
	)
	_require(shockwaves.size() == 1, "Exactly one reusable shockwave must be preallocated")
	var floods := disaster.get_node("FloodMode").find_children("FloodHazard", "", false, false)
	_require(floods.size() == 1, "Exactly one reusable flood surface must be preallocated")

	var player: GrayboxPlayer = game.get_node("World/Player")
	_require(player.get_node("Visual/Head") != null, "Player must have a recognizable low-poly head")
	_require(player.get_node("Visual/LeftArm") != null, "Player must have low-poly limbs")
	_require(
		player.get_node("Hitboxes").find_children("*", "Area3D", false, false).size() == 8,
		"Player must expose eight stable hit zones"
	)
	var quality_options := game.get_node("HUD/PausePanel/Center/Quality") as OptionButton
	var fps_options := game.get_node("HUD/PausePanel/Center/FPSLimit") as OptionButton
	var character_options := game.get_node("HUD/PausePanel/PreviewPanel/Character") as OptionButton
	var settings_rect: Rect2 = game.get_node("HUD/PausePanel/Center").get_global_rect()
	var preview_rect: Rect2 = game.get_node("HUD/PausePanel/PreviewPanel").get_global_rect()
	_require(
		not settings_rect.intersects(preview_rect),
		"Settings and 3D character preview must remain separate at 1280x720"
	)
	_require(
		settings_rect.position.x >= 0.0
		and settings_rect.end.x <= 1280.0
		and preview_rect.position.x >= 0.0
		and preview_rect.end.x <= 1280.0,
		"Complete settings menu must fit the landscape viewport"
	)
	_require(quality_options.item_count == 3, "Quality menu must show Low, Medium and High")
	_require(fps_options.item_count == 3, "FPS menu must show every available cap")
	_require(character_options.item_count == 5, "Character menu must show every model")
	_require(
		game.get_node("HUD/PausePanel/PreviewPanel/ViewportContainer/Viewport/Avatar") != null,
		"Character menu must include a reusable 3D preview"
	)
	var joystick: GrayboxVirtualJoystick = game.get_node("HUD/Joystick")
	_require(
		joystick._is_in_activation_zone(Vector2(80.0, 80.0)),
		"Whole left screen half must activate movement"
	)
	_require(
		not joystick._is_in_activation_zone(Vector2(1000.0, 80.0)),
		"Right screen half must remain reserved for camera"
	)
	var start_z := player.global_position.z
	player.set_touch_move(Vector2(0.0, -1.0))
	for frame in 12:
		await physics_frame
	player.set_touch_move(Vector2.ZERO)
	_require(start_z - player.global_position.z > 0.05, "Touch vector must move the player")
	_require(
		absf(player.get_node("Visual/LeftArm").rotation.x) > 0.01,
		"Moving player must drive the procedural walk animation"
	)
	player.velocity = Vector3.ZERO
	player.set_controls_enabled(false)
	var locked_position := player.global_position
	player.set_touch_move(Vector2(1.0, 0.0))
	for frame in 8:
		await physics_frame
	_require(
		player.global_position.distance_to(locked_position) < 0.02,
		"Online menu must lock local movement without pausing the shared round"
	)
	player.set_controls_enabled(true)

	player.set_first_person(true)
	_require(not player.get_node("Visual").visible, "First person must hide the local body")
	_require(
		player.get_node("CameraRig/SpringArm").spring_length < 0.1,
		"First-person camera must move to the player"
	)
	player.set_first_person(false)
	_require(player.get_node("Visual").visible, "Third person must restore the local body")
	player.set_look_sensitivity_scale(1.4)
	_require(
		is_equal_approx(player.get_look_sensitivity_scale(), 1.4),
		"Look sensitivity setting must reach the player"
	)
	player.set_character_variant(1)
	_require(
		not player.get_node("Visual/Cap").visible and player.get_node("Visual/Backpack").visible,
		"Character variants must change their cheap accessory"
	)
	player.set_texture_detail(true)
	var suit_material := player.get_node("Visual/Body").material_override as StandardMaterial3D
	_require(suit_material.albedo_texture != null, "Medium quality must enable shared suit atlas")
	player.set_texture_detail(false)
	player.set_character_variant(0)
	game._on_quality_selected(1)
	suit_material = player.get_node("Visual/Body").material_override as StandardMaterial3D
	_require(suit_material.albedo_texture != null, "Quality profile must apply shared texture")
	game._on_quality_selected(2)
	_require(game.get_node("World/Sun").shadow_enabled, "High quality must enable the optional shadow")
	game._on_quality_selected(0)
	_require(not game.get_node("World/Sun").shadow_enabled, "Low quality must disable shadows")

	var push_request_state := [false]
	player.push_requested.connect(func() -> void:
		push_request_state[0] = true
	)
	player.request_push()
	_require(push_request_state[0], "Push button must request a short frontal push")
	await physics_frame
	_require(
		player.get_node("Visual/LeftArm").rotation.x > 0.1,
		"Push action must drive the shared procedural pose"
	)
	player.velocity = Vector3.ZERO
	player.apply_external_push(Vector3.FORWARD, 5.2)
	_require(player.velocity.z < -4.0 and player.velocity.y > 0.0, "Received push must add knockback")
	player.velocity = Vector3.ZERO

	player.heal_full()
	player.apply_damage_and_knockback(
		player.get_node("Hitboxes/Torso").global_position,
		2.0,
		7
	)
	await process_frame
	var damage_flash: ColorRect = game.get_node("HUD/DamageFlash")
	_require(damage_flash.visible and damage_flash.color.a > 0.0, "Damage must trigger reusable HUD flash")
	_require(
		player.get_limb_mask() == GrayboxPlayer.ALL_LIMBS_MASK,
		"Torso impact must reduce health without detaching an unrelated limb"
	)
	player.heal_full()

	player.global_position = Vector3(0.0, 1.25, 0.0)
	player.velocity = Vector3.ZERO
	var meteor: MeteorSlot = meteors[0]
	meteor.launch(Vector3(0.0, 0.06, 0.0), Vector2.ZERO, 0.01, 22, 10.5)
	for frame in 110:
		await physics_frame
	_require(player.get_health() < GrayboxPlayer.MAX_HEALTH, "Meteor impact must damage the player")
	var exposed_health := player.get_health()

	player.heal_full()
	player.global_position = Vector3(-8.3, 1.2, -7.8)
	player.velocity = Vector3.ZERO
	meteor.launch(Vector3(-8.3, 0.06, -7.8), Vector2.ZERO, 0.01, 22, 10.5)
	for frame in 110:
		await physics_frame
	_require(player.get_health() == GrayboxPlayer.MAX_HEALTH, "Shelter roof must block meteor blast")

	var shockwave: ShockwaveRing = shockwaves[0]
	player.heal_full()
	player.global_position = Vector3(4.0, 1.25, 0.0)
	player.velocity = Vector3.ZERO
	shockwave.launch(0.05, 18, 8.5)
	for frame in 125:
		await physics_frame
	var wave_exposed_health := player.get_health()
	_require(wave_exposed_health < GrayboxPlayer.MAX_HEALTH, "Grounded player must be hit by shockwave")

	player.heal_full()
	player.global_position = Vector3(2.0, 2.1, 0.0)
	player.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	shockwave.launch(0.05, 18, 8.5)
	for frame in 125:
		await physics_frame
	_require(
		player.get_health() == GrayboxPlayer.MAX_HEALTH,
		"Elevated center platform must protect from shockwave"
	)

	var flood: Variant = floods[0]
	player.heal_full()
	player.global_position = Vector3(7.0, 1.2, 0.0)
	player.velocity = Vector3.ZERO
	flood.sync_active(0.0, 36.0)
	for frame in 4:
		await physics_frame
	_require(player.get_health() < GrayboxPlayer.MAX_HEALTH, "Rising flood must damage low players")
	flood.stop()
	player.heal_full()

	player.apply_limb_damage(
		GrayboxPlayer.Limb.LEFT_HAND,
		20,
		player.global_position + Vector3(-1.0, 0.0, 0.0)
	)
	await physics_frame
	_require(
		not player.get_node("Visual/LeftHand").visible,
		"Localized hand damage must detach only the impacted piece"
	)
	_require(
		(player.get_limb_mask() & (1 << GrayboxPlayer.Limb.LEFT_HAND)) == 0,
		"Detached limbs must be represented by a compact reusable bit mask"
	)
	var detached_meshes := game.get_node("World/DetachedParts").find_children(
		"*",
		"MeshInstance3D",
		true,
		false
	)
	var visible_detached_part := false
	for part: MeshInstance3D in detached_meshes:
		visible_detached_part = visible_detached_part or part.visible
	_require(visible_detached_part, "Detached piece must use the preallocated physics pool")
	player.reset_to_spawn()
	_require(
		player.get_limb_mask() == GrayboxPlayer.ALL_LIMBS_MASK,
		"Respawning must restore every hit zone and visual part"
	)

	var remote: RemoteAvatar = REMOTE_AVATAR_SCENE.instantiate()
	game.get_node("World/RemotePlayers").add_child(remote)
	remote.configure("Prueba", 2, Vector3.ZERO)
	_require(remote.get_node("Name").text == "Prueba", "Remote name must be visible")
	_require(
		remote.get_node("Cap").visible != remote.get_node("Backpack").visible,
		"Remote avatar must expose exactly one cheap visual variant"
	)
	remote.set_limb_mask(GrayboxPlayer.ALL_LIMBS_MASK & ~(1 << GrayboxPlayer.Limb.RIGHT_LEG))
	_require(
		not remote.get_node("RightLeg").visible,
		"Remote avatar must apply synchronized limb state"
	)
	remote.queue_free()

	var custom_map_root := Node3D.new()
	var custom_spawn := Marker3D.new()
	custom_spawn.position = Vector3(3.0, 1.2, -2.0)
	custom_spawn.add_to_group(&"player_spawn", true)
	custom_map_root.add_child(custom_spawn)
	custom_spawn.owner = custom_map_root
	var custom_map_scene := PackedScene.new()
	_require(custom_map_scene.pack(custom_map_root) == OK, "Custom minigame map must pack")
	custom_map_root.free()
	var map_host: Node3D = game.get_node("World/ModeMapHost")
	map_host.activate_mode(&"test_mode", custom_map_scene)
	await physics_frame
	_require(
		not game.get_node("World/Arena").visible and map_host.get_cached_map_count() == 1,
		"Dedicated minigame map must replace the default arena and remain cached"
	)
	_require(
		player.global_position.distance_to(Vector3(3.0, 1.2, -2.0)) < 0.1,
		"Dedicated map spawn marker must relocate the reusable player"
	)
	map_host.activate_mode(&"test_mode", custom_map_scene)
	_require(map_host.get_cached_map_count() == 1, "Reusing a mode must not recreate its map")
	map_host.activate_mode(&"default", null)
	await physics_frame
	_require(game.get_node("World/Arena").visible, "Default arena must restore after a custom mode")

	disaster.round_started.emit(99)
	disaster.round_survived.emit(99)
	await process_frame
	var score: Label = game.get_node("HUD/RoundPanel/Score")
	_require(score.text.contains("RONDAS 1"), "Completed round must update persistent score HUD")
	for frame in 40:
		await physics_frame

	print("SMOKE_OK lights=%d meshes=%d meteors=%d flood=1 meteor_health=%d shelter_health=%d wave_health=%d elevated_health=%d" % [
		lights.size(),
		meshes.size(),
		meteors.size(),
		exposed_health,
		GrayboxPlayer.MAX_HEALTH,
		wave_exposed_health,
		player.get_health(),
	])
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("SMOKE_FAIL: " + message)
	quit(1)
