extends SceneTree

const EXPECTED_METEOR_POOL := 8
const NETWORK_SCRIPT := preload("res://scripts/network/network_manager.gd")
const REMOTE_AVATAR_SCENE := preload("res://scenes/components/remote_avatar.tscn")
const GAMEPLAY_FEATURE_SCRIPT := preload("res://scripts/features/gameplay_feature.gd")
const CHARACTER_CATALOG := preload("res://scripts/characters/character_catalog.gd")
const WEAPONS := preload("res://shared/weapon_profiles.gd")


func _init() -> void:
	call_deferred("_run")


func _ensure_network() -> void:
	if not root.has_node("Network"):
		var network := NETWORK_SCRIPT.new()
		network.name = "Network"
		root.add_child(network)


func _run() -> void:
	_ensure_network()
	var menu_packed: PackedScene = load("res://scenes/menu.tscn")
	_require(menu_packed != null, "Main menu scene must load")
	var menu := menu_packed.instantiate()
	root.add_child(menu)
	await process_frame
	_require(
		menu.get_node("MenuPanel/Screens/Main/PlayLocal") is Button,
		"Menu must expose a dedicated offline play action"
	)
	_require(
		menu.get_node("MenuPanel/Screens/Main/Multiplayer") is Button,
		"Menu must expose the multiplayer lobby action"
	)
	_require(
		menu.find_child("CreateRoom", true, false) is Button
		and menu.find_child("StartRoom", true, false) is Button,
		"Lobby must expose room creation and host-controlled start"
	)
	_require(
		menu.find_child("RoomCharacter", true, false) is OptionButton
		and menu.find_child("ReadyRoom", true, false) is Button,
		"Waiting room must expose character selection and ready confirmation"
	)
	_require(
		menu.find_child("ModeExclusion", true, false) is OptionButton
		and menu.find_child("ModeExclusion", true, false).item_count == 7,
		"Waiting room must expose one optional minigame veto"
	)
	menu.queue_free()
	await process_frame

	var packed: PackedScene = load("res://scenes/main.tscn")
	_require(packed != null, "Main scene must load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	# Profile settings persist between runs. Force the baseline before checking
	# the low-end rendering budget so this test is deterministic.
	game.set("_quality_level", 0)
	game.call("_apply_quality")
	var player: GrayboxPlayer = game.get_node("World/Player")

	var lights := game.find_children("*", "Light3D", true, false)
	_require(lights.size() <= 1, "Low-end budget allows at most one light")
	for light: Light3D in lights:
		_require(not light.shadow_enabled, "Low-end light must not cast shadows")
	var meshes := game.get_node("World").find_children("*", "MeshInstance3D", true, false)
	var visible_meshes := 0
	for mesh: MeshInstance3D in meshes:
		visible_meshes += int(mesh.is_visible_in_tree())
	_require(visible_meshes <= 86, "Low-end visible mesh budget exceeded")
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
		disaster.call("_round_state_from_network", NetConstants.RoomPhase.ACTIVE)
		== DisasterController.RoundState.ACTIVE,
		"Shared ACTIVE phase must never be rendered as RESULT"
	)
	_require(
		disaster.get_registered_mode_ids()
		== [&"meteors", &"shockwave", &"flood", &"shooter", &"domain", &"drone_hunt"],
		"Round controller must discover independent minigame modules in scene order"
	)
	var map_host: Node3D = game.get_node("World/ModeMapHost")
	_require(
		map_host.get_registered_map_ids()
		== [
			&"plaza_caos",
			&"campo_tiro",
			&"nucleo_tactico",
			&"deposito_drones",
			&"muelles_altos",
		],
		"Map host must discover data-driven common maps"
	)
	var initial_plan := disaster.get_upcoming_plan()
	_require(
		initial_plan.has_all([
			"mode_id",
			"map_id",
			"round_seed",
			"feature_ids",
			"player_profile_id",
			"spawn_policy_id",
			"spectator_policy_id",
		]),
		"Round selection must produce a complete reusable experience plan"
	)
	_require(
		_mode_map_compatible(initial_plan.mode_id, initial_plan.map_id),
		"Common mode must select only a tag-compatible map"
	)
	var feature_host: Node = game.get_node("ExperienceFeatureHost")
	var test_feature: Node = GAMEPLAY_FEATURE_SCRIPT.new()
	test_feature.feature_id = &"test_feature"
	feature_host.register_feature(test_feature)
	var feature_plan := initial_plan.duplicate(true)
	feature_plan.feature_ids = PackedStringArray(["test_feature"])
	feature_host.apply_experience(feature_plan)
	_require(
		feature_host.get_active_feature_ids() == [&"test_feature"]
		and test_feature.feature_context.player == game.get_node("World/Player"),
		"Experience features must receive reusable player/world/HUD dependencies"
	)
	feature_host.apply_experience(initial_plan)
	_require(
		test_feature.feature_context.is_empty(),
		"Features omitted by the next plan must deactivate without rebuilding the game"
	)
	var shooter_plan := initial_plan.duplicate(true)
	shooter_plan.mode_id = &"shooter"
	shooter_plan.map_id = &"campo_tiro"
	shooter_plan.feature_ids = PackedStringArray(["shooter_controls"])
	feature_host.apply_experience(shooter_plan)
	_require(
		game.get_node("HUD/Shoot").visible
		and game.get_node("HUD/Reload").visible
		and game.get_node("HUD/Crosshair").visible
		and player.is_first_person(),
		"Shooter feature must provide controls, crosshair, and camera profile"
	)
	var shooter_feature := game.get_node("ExperienceFeatureHost/ShooterControls")
	var initial_ammo := int(shooter_feature.get("_ammo"))
	shooter_feature.call("_request_shot")
	_require(
		int(shooter_feature.get("_ammo")) == initial_ammo - 1
		and game.get_node("HUD/WeaponStatus").text.contains("/"),
		"Shooter feature must animate a modeled weapon and track its magazine"
	)
	shooter_feature.set("_ammo", 0)
	shooter_feature.call("_begin_reload")
	_require(
		float(shooter_feature.get("_reload_remaining")) > 0.0,
		"Empty magazine must start the reusable reload animation"
	)
	feature_host.clear_experience()
	_require(
		not game.get_node("HUD/Shoot").visible
		and not game.get_node("HUD/Reload").visible,
		"Shooter controls must disappear when another minigame starts"
	)
	var domain_plan := initial_plan.duplicate(true)
	domain_plan.mode_id = &"domain"
	domain_plan.map_id = &"nucleo_tactico"
	domain_plan.feature_ids = PackedStringArray(["domain_tracker", "bat_controls"])
	feature_host.apply_experience(domain_plan)
	_require(
		game.get_node("HUD/DomainStatus").visible,
		"Domain feature must expose local capture feedback without network traffic"
	)
	_require(
		player.get_node("Visual/PushBat").visible,
		"Domain must expose its reusable high-force bat"
	)
	feature_host.clear_experience()
	disaster.set_physics_process(false)
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
	_require(
		disaster.get_node("DomainMode/CaptureZone") is MeshInstance3D,
		"Domain must reuse one lightweight capture-zone mesh"
	)
	_require(
		disaster.get_node("DroneHuntMode").get_child_count() == 4,
		"Drone hunt must preallocate four client-owned NPCs"
	)

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
	_require(character_options.item_count == 6, "Character menu must show every model")
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
	player.global_position = Vector3(0.0, 1.2, 8.0)
	player.velocity = Vector3.ZERO
	await physics_frame
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
	var organic_avatar := player.get_node("Visual/OrganicAvatar") as ModularAvatar
	_require(
		organic_avatar.get_archetype_index() == 1
		and organic_avatar.get_model_mesh_count() == 4,
		"Female selection must use its fitted four-mesh organic model"
	)
	player.set_character_variant(2)
	_require(
		organic_avatar.get_archetype_index() == 2,
		"Semi-human selection must use its rigged ears-and-tail model"
	)
	player.set_texture_detail(true)
	var suit_material := player.get_node("Visual/Body").material_override as StandardMaterial3D
	_require(suit_material.albedo_texture != null, "Medium quality must enable shared suit atlas")
	player.set_texture_detail(false)
	player.set_character_variant(CHARACTER_CATALOG.PIONEER_INDEX)
	_require(
		player.get_node("Visual/Body").scale.x
		< player.get_node("Visual/Pelvis").scale.x,
		"Pionera must use an independent feminine silhouette"
	)
	player.set_character_variant(0)
	game._on_quality_selected(1)
	suit_material = player.get_node("Visual/Body").material_override as StandardMaterial3D
	_require(suit_material.albedo_texture != null, "Quality profile must apply shared texture")
	_require(game.get_node("World/Sun").shadow_enabled, "Medium quality must inherit former High shadows")
	_require(
		organic_avatar.visible
		and organic_avatar.get_model_mesh_count() == 4,
		"Medium quality must retain the batched organic avatar"
	)
	game._on_quality_selected(2)
	_require(game.get_node("World/Sun").shadow_enabled, "High quality must enable the optional shadow")
	_require(
		organic_avatar.get_model_mesh_count() == 4
		and game.get_node("World/Environment").environment.fog_enabled,
		"High quality must retain organic characters and atmospheric fog"
	)
	game._on_quality_selected(0)
	_require(not game.get_node("World/Sun").shadow_enabled, "Low quality must disable shadows")
	_require(
		not player.get_node("Visual/Chest").visible,
		"Low quality must omit secondary character geometry"
	)

	var push_request_state := [false]
	player.push_requested.connect(func() -> void:
		push_request_state[0] = true
	)
	player.request_push()
	_require(push_request_state[0], "Push button must request a short frontal push")
	await physics_frame
	_require(
		player.get_node("Visual/LeftArm").rotation.x < -0.1
		and player.get_node("Visual/LeftHand").position.z > 0.05,
		"Push action must extend both arms toward the facing direction"
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

	player.set_character_variant(2)
	player.apply_limb_damage(
		GrayboxPlayer.Limb.HEAD,
		GrayboxPlayer.ACCESSORY_MAX_HEALTH,
		player.global_position + Vector3(0.0, 2.0, 0.0)
	)
	await physics_frame
	_require(
		(player.get_limb_mask() & (1 << GrayboxPlayer.Limb.HEAD)) != 0
		and (player.get_limb_mask() & (1 << GrayboxPlayer.Accessory.LEFT_EAR)) == 0
		and (player.get_limb_mask() & (1 << GrayboxPlayer.Accessory.RIGHT_EAR)) == 0,
		"Head accessories must detach before the underlying body part"
	)
	_require(
		(player.get_limb_mask() & (1 << GrayboxPlayer.Accessory.LEFT_EAR)) == 0,
		"Accessory detachment must use the same compact synchronized body mask"
	)
	player.heal_full()
	player.set_character_variant(0)
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
	_require(
		remote.get_node("Name").text == "Prueba · 100 VIDA",
		"Remote name and life must be visible"
	)
	_require(
		remote.get_node("PlayerCollision") is StaticBody3D,
		"Remote avatars must provide lightweight player collision"
	)
	remote.set_detail_quality(2)
	remote.play_shoot_animation(WEAPONS.Id.C16)
	await process_frame
	_require(
		remote.get_node("HeldWeapon").visible
		and remote.get_node("Chest").mesh is CapsuleMesh,
		"Remote shooter must deduce its weapon pose from reliable shot events"
	)
	remote.set_health(0)
	_require(
		remote.get_node("Name").text == "Prueba · ELIMINADO",
		"Remote elimination must be visible without synchronizing visual state"
	)
	_require(
		(remote.get_node("OrganicAvatar") as ModularAvatar).get_archetype_index() == 2,
		"Remote and preview avatars must reuse the semi-human silhouette"
	)
	remote.set_limb_mask(
		GrayboxPlayer.ALL_LIMBS_MASK
		& ~(1 << GrayboxPlayer.Limb.RIGHT_LEG)
		& ~(1 << GrayboxPlayer.Accessory.TAIL)
	)
	_require(
		(
			(remote.get_node("OrganicAvatar") as ModularAvatar).get_limb_mask()
			& (1 << GrayboxPlayer.Limb.RIGHT_LEG)
		) == 0
		and (
			(remote.get_node("OrganicAvatar") as ModularAvatar).get_limb_mask()
			& (1 << GrayboxPlayer.Accessory.TAIL)
		) == 0,
		"Remote avatar must apply synchronized limb and accessory state"
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
	map_host.register_runtime_map(
		&"test_map",
		custom_map_scene,
		PackedStringArray(["custom", "test"])
	)
	map_host.activate_selection(&"test_mode", &"test_map")
	await physics_frame
	_require(
		not game.get_node("World/Arena").visible and map_host.get_cached_map_count() == 1,
		"Dedicated minigame map must replace the default arena and remain cached"
	)
	_require(
		player.global_position.distance_to(Vector3(3.0, 1.2, -2.0)) < 0.1,
		"Dedicated map spawn marker must relocate the reusable player"
	)
	map_host.activate_selection(&"test_mode", &"test_map")
	_require(map_host.get_cached_map_count() == 1, "Reusing a mode must not recreate its map")
	map_host.activate_selection(&"default", &"plaza_caos")
	await physics_frame
	_require(game.get_node("World/Arena").visible, "Default arena must restore after a custom mode")
	map_host.activate_selection(&"shooter", &"campo_tiro")
	await physics_frame
	var shooter_map := game.get_node("World/ModeMapHost/ModeMap_campo_tiro")
	_require(
		not game.get_node("World/Arena").visible
		and shooter_map.find_children("PhysicsProp*", "RigidBody3D", true, false).size() == 10
		and player.global_position.distance_to(Vector3(0.0, 1.2, 29.0)) < 0.1,
		"Shooter map must replace the plaza with separated spawns and physical props"
	)
	map_host.activate_selection(&"domain", &"nucleo_tactico")
	await physics_frame
	var domain_map := game.get_node("World/ModeMapHost/ModeMap_nucleo_tactico")
	_require(
		domain_map.find_children("PhysicsProp*", "RigidBody3D", true, false).size() == 8
		and domain_map.find_children("PlayerSpawn*", "Marker3D", true, false).size() == 5,
		"Domain map must reuse physical props and five separated spawn points"
	)
	map_host.activate_selection(&"default", &"plaza_caos")
	await physics_frame

	disaster.round_started.emit(99)
	disaster.round_survived.emit(99)
	await process_frame
	var score: Label = game.get_node("HUD/RoundPanel/Score")
	_require(score.text.contains("RONDAS 1"), "Completed round must update persistent score HUD")
	disaster.round_started.emit(100)
	player.apply_hazard_damage(GrayboxPlayer.MAX_HEALTH)
	await process_frame
	_require(
		player.is_defeated()
		and player.get_health() == 0
		and player.get_limb_mask() == 0
		and player.global_position.y > 10.0,
		"Defeated player must remain eliminated in the overhead spectator state"
	)
	disaster.round_survived.emit(100)
	await process_frame
	_require(
		not player.is_defeated()
		and player.get_health() == GrayboxPlayer.MAX_HEALTH
		and player.get_limb_mask() == GrayboxPlayer.ALL_LIMBS_MASK,
		"Round completion must restore the reusable player for the next minigame"
	)
	var previous_mode_id := StringName(initial_plan.mode_id)
	disaster._activate_plan(initial_plan)
	for selection in 8:
		var random_plan: Dictionary = disaster._select_next_plan()
		_require(
			random_plan.mode_id != previous_mode_id,
			"Random selector must not repeat the same mode consecutively"
		)
		_require(
			_mode_map_compatible(random_plan.mode_id, random_plan.map_id),
			"Random selector must preserve mode/map compatibility"
		)
		disaster._activate_plan(random_plan)
		previous_mode_id = StringName(random_plan.mode_id)
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


func _mode_map_compatible(mode_id: StringName, map_id: StringName) -> bool:
	if mode_id == &"shooter":
		return map_id == &"campo_tiro"
	if mode_id == &"domain":
		return map_id == &"nucleo_tactico"
	if mode_id == &"drone_hunt":
		return map_id == &"deposito_drones"
	return map_id in [&"plaza_caos", &"muelles_altos"]
