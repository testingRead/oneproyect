extends SceneTree

const NETWORK_SCRIPT := preload("res://client/network_client.gd")
const MENU_SCENE := preload("res://scenes/menu.tscn")
const NET := preload("res://shared/net_constants.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var network := NETWORK_SCRIPT.new()
	network.name = "Network"
	root.add_child(network)
	var menu := MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	_require(
		menu.find_child("MatchRounds", true, false) == null,
		"A room starts exactly one minigame and must not expose match rounds"
	)
	menu.call(
		"_on_room_waiting",
		2,
		2,
		true,
		2,
		true,
		true,
		PackedStringArray(["Ana", "Beto"]),
		PackedByteArray([1, 1]),
		PackedByteArray([2, 3]),
		PackedInt32Array([4, 7]),
		PackedInt32Array([21, 34]),
		PackedInt32Array([8, 5]),
		0
	)
	var waiting_players := menu.find_child("WaitingPlayers", true, false) as Label
	_require(
		waiting_players.text.contains(
			"2/%d JUGADORES · 2 LISTOS" % NET.MAX_PLAYERS_PER_ROOM
		),
		"Waiting room must summarize occupancy and readiness"
	)
	var online_roster := menu.find_child("OnlinePlayerRoster", true, false) as VBoxContainer
	_require(online_roster.get_child_count() == 2, "Online players must use ordered cards")
	var online_text := ""
	for label in online_roster.find_children("*", "Label", true, false):
		online_text += (label as Label).text + "\n"
	_require(
		online_text.contains("ANA") and online_text.contains("8 PTS")
		and online_text.contains("4V · 21XP"),
		"Online cards must organize identity, session points and profile data"
	)
	_require(
		menu.find_child("WaitingRoom", true, false).visible,
		"Waiting room payload must switch to the room screen"
	)
	menu.call("_open_local_room")
	await process_frame
	var roster := menu.find_child("PlayerRoster", true, false) as VBoxContainer
	_require(roster != null and roster.get_child_count() == 1, "Local room must render one roster card")
	_require(
		menu.find_child("PlayerCard0", true, false) != null,
		"Roster card must expose player identity, character, points and ready state"
	)
	var chat := menu.find_child("LanChat", true, false) as Button
	_require(chat != null and chat.disabled, "Chat shell must not claim an unavailable transport")
	print("MENU_SMOKE_OK online_cards=%d" % online_roster.get_child_count())
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("MENU_SMOKE_FAIL: " + message)
	quit(1)
