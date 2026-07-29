extends Node

const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args():
		var network: Variant = get_node("/root/Network")
		var error: int = network.start_server()
		if error != OK:
			push_error("Server startup failed: %s" % error)
			get_tree().quit(1)
		return
		return
	get_tree().call_deferred("change_scene_to_file", GAME_SCENE)
