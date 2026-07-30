class_name OneProjectRuntimeMode
extends RefCounted

const LOCAL_DEVELOPMENT := &"LOCAL_DEVELOPMENT"
const LOCAL_ARGUMENT := "--local-development"
const LOCAL_SCENE := "res://scenes/local/local_lab.tscn"


static func is_local_development(arguments := OS.get_cmdline_user_args()) -> bool:
	return (
		LOCAL_ARGUMENT in arguments
		or OS.has_feature("local_development")
	)
