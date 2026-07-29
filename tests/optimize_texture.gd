extends SceneTree


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Usage: -- <source.png> <target.webp>")
		quit(2)
		return
	var image := Image.load_from_file(arguments[0])
	if image == null or image.is_empty():
		push_error("Could not load source texture")
		quit(3)
		return
	image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var error := OK
	if arguments[1].get_extension() == "res":
		var texture := PortableCompressedTexture2D.new()
		texture.keep_compressed_buffer = true
		texture.create_from_image(
			image,
			PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY,
			false,
			0.72
		)
		error = ResourceSaver.save(texture, arguments[1])
	else:
		error = image.save_webp(arguments[1], true, 0.72)
	if error != OK:
		push_error("Could not save optimized texture: %s" % error)
		quit(4)
		return
	print("TEXTURE_OPTIMIZED size=256x256 target=%s" % arguments[1])
	quit(0)
