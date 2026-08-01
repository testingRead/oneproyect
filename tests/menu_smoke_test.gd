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
	var rounds := menu.find_child("MatchRounds", true, false) as OptionButton
	_require(rounds != null, "Waiting room must expose match length")
	_require(
		rounds.item_count == NET.MATCH_ROUND_OPTIONS.size(),
		"Match length must offer only the supported choices"
	)
	for index in rounds.item_count:
		_require(
			rounds.get_item_id(index) == NET.MATCH_ROUND_OPTIONS[index],
			"Match length option IDs must match shared rules"
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
		3
	)
	var waiting_players := menu.find_child("WaitingPlayers", true, false) as Label
	_require(
		waiting_players.text.contains("Ana · LINCE MASCULINO · 4 victorias · 21 XP")
		and waiting_players.text.contains("Beto · LINCE FEMENINA · 7 victorias · 34 XP"),
		"Waiting room must show names, characters, ready state, wins and XP"
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
	print("MENU_SMOKE_OK round_options=%d selected=%d" % [
		rounds.item_count,
		rounds.get_item_id(rounds.selected),
	])
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("MENU_SMOKE_FAIL: " + message)
	quit(1)
