extends Node

const MENU_SCENE := "res://scenes/menu.tscn"
const SERVER_SCENE := "res://server/scenes/dedicated_server.tscn"


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		get_tree().call_deferred("change_scene_to_file", SERVER_SCENE)
		return
	if not get_tree().root.has_node("Network"):
		var client_script: Script = load("res://client/network_client.gd")
		var network: Node = client_script.new()
		network.name = "Network"
		network.ready.connect(_start_menu, CONNECT_ONE_SHOT)
		get_tree().root.add_child.call_deferred(network)
		return
	_start_menu()


func _start_menu() -> void:
	get_tree().call_deferred("change_scene_to_file", MENU_SCENE)
