extends SceneTree

const EXPECTED_METEOR_POOL := 8


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_require(packed != null, "Main scene must load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var lights := game.find_children("*", "Light3D", true, false)
	_require(lights.size() <= 1, "Low-end budget allows at most one light")

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

	player.global_position = Vector3(0.0, 1.25, 0.0)
	player.velocity = Vector3.ZERO
	var meteor: MeteorSlot = meteors[0]
	meteor.launch(Vector3(0.0, 0.06, 0.0), Vector2.ZERO, 0.01, 22, 10.5)
	for frame in 110:
		await physics_frame
	_require(player.get_health() < GrayboxPlayer.MAX_HEALTH, "Meteor impact must damage the player")

	print("SMOKE_OK lights=%d meteors=%d health=%d" % [
		lights.size(),
		meteors.size(),
		player.get_health(),
	])
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("SMOKE_FAIL: " + message)
	quit(1)
