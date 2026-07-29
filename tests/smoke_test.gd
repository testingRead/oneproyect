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
	var meshes := game.find_children("*", "MeshInstance3D", true, false)
	_require(meshes.size() <= 48, "Graybox mesh-node budget exceeded")
	_require(
		ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility",
		"Project must use the Compatibility renderer"
	)
	_require(
		int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 4,
		"Android orientation must remain landscape sensor"
	)

	var disaster: DisasterController = game.get_node("World/DisasterController")
	var meteors := disaster.find_children("Meteor*", "Node3D", false, false)
	_require(meteors.size() == EXPECTED_METEOR_POOL, "Meteor pool must be preallocated")

	var player: GrayboxPlayer = game.get_node("World/Player")
	var start_z := player.global_position.z
	player.set_touch_move(Vector2(0.0, -1.0))
	for frame in 12:
		await physics_frame
	player.set_touch_move(Vector2.ZERO)
	_require(start_z - player.global_position.z > 0.05, "Touch vector must move the player")
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

	var remote: RemoteAvatar = REMOTE_AVATAR_SCENE.instantiate()
	game.get_node("World/RemotePlayers").add_child(remote)
	remote.configure("Prueba", 2, Vector3.ZERO)
	_require(remote.get_node("Name").text == "Prueba", "Remote name must be visible")
	_require(
		remote.get_node("Cap").visible != remote.get_node("Backpack").visible,
		"Remote avatar must expose exactly one cheap visual variant"
	)
	remote.queue_free()

	print("SMOKE_OK lights=%d meshes=%d meteors=%d exposed_health=%d sheltered_health=%d" % [
		lights.size(),
		meshes.size(),
		meteors.size(),
		exposed_health,
		player.get_health(),
	])
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("SMOKE_FAIL: " + message)
	quit(1)
