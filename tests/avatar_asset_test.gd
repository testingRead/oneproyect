extends SceneTree

const AVATARS := [
	"res://assets/models/avatars/human_male.glb",
	"res://assets/models/avatars/human_female.glb",
	"res://assets/models/avatars/lynx_male.glb",
	"res://assets/models/avatars/lynx_female.glb",
]
const REQUIRED_ANIMATIONS := ["Idle", "Walk", "Crouch", "Push", "Shoot"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path: String in AVATARS:
		var packed := load(path) as PackedScene
		_require(packed != null, "Avatar must import as PackedScene: " + path)
		var avatar := packed.instantiate()
		root.add_child(avatar)
		var skeletons := avatar.find_children("*", "Skeleton3D", true, false)
		var players := avatar.find_children("*", "AnimationPlayer", true, false)
		var meshes := avatar.find_children("*", "MeshInstance3D", true, false)
		_require(skeletons.size() == 1, "Avatar must expose one skeleton: " + path)
		_require(players.size() == 1, "Avatar must expose one AnimationPlayer: " + path)
		_require(meshes.size() == 4, "Avatar must keep body, clothing, face and hair batched: " + path)
		var animation_player := players[0] as AnimationPlayer
		var available := PackedStringArray()
		for animation_name: StringName in animation_player.get_animation_list():
			var qualified_name := str(animation_name)
			available.append(
				qualified_name.substr(qualified_name.rfind("/") + 1)
				if qualified_name.contains("/")
				else qualified_name
			)
		for required: String in REQUIRED_ANIMATIONS:
			_require(
				required in available,
				"Missing %s animation in %s (got %s)" % [required, path, available]
			)
		print(
			"AVATAR_ASSET_OK file=%s bones=%d meshes=%d animations=%s"
			% [
				path.get_file(),
				(skeletons[0] as Skeleton3D).get_bone_count(),
				meshes.size(),
				available,
			]
		)
		avatar.queue_free()
		await process_frame
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("AVATAR_ASSET_FAIL: " + message)
	quit(1)
