extends SceneTree

const MENU_SCENE := preload("res://scenes/menu.tscn")
const NETWORK_SCRIPT := preload("res://client/network_client.gd")

var _output_path := "/tmp/oneproyect-menu-room.png"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MENU_CAPTURE_FAIL: a display driver is required")
		quit(1)
		return
	var network := NETWORK_SCRIPT.new()
	network.name = "Network"
	root.add_child(network)
	var menu := MENU_SCENE.instantiate()
	root.add_child(menu)
	for frame in 4:
		await process_frame
	var main_path := _output_path.get_basename() + "-main.png"
	var main_image := root.get_texture().get_image()
	var main_error := main_image.save_png(main_path)
	if main_error != OK:
		push_error("MENU_CAPTURE_FAIL path=%s error=%d" % [main_path, main_error])
		quit(1)
		return
	menu._open_local_room()
	for frame in 6:
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(_output_path)
	if error != OK:
		push_error("MENU_CAPTURE_FAIL path=%s error=%d" % [_output_path, error])
		quit(1)
		return
	menu.call(
		"_on_room_waiting",
		12,
		5,
		true,
		4,
		true,
		false,
		PackedStringArray(["Leo", "Mia", "Paco", "Nina", "Tomi"]),
		PackedByteArray([1, 1, 1, 1, 0]),
		PackedByteArray([0, 0, 0, 0, 0]),
		PackedInt32Array([12, 10, 8, 6, 4]),
		PackedInt32Array([80, 60, 40, 30, 20]),
		PackedInt32Array([12, 10, 8, 6, 4]),
		0
	)
	for frame in 4:
		await process_frame
	var waiting_path := _output_path.get_basename() + "-online.png"
	var waiting_error := root.get_texture().get_image().save_png(waiting_path)
	if waiting_error != OK:
		push_error("MENU_CAPTURE_FAIL path=%s error=%d" % [waiting_path, waiting_error])
		quit(1)
		return
	print("MENU_CAPTURE_OK paths=%s,%s,%s size=%s" % [main_path, _output_path, waiting_path, image.get_size()])
	quit(0)
