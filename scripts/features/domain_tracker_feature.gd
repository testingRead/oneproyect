class_name DomainTrackerFeature
extends "res://scripts/features/gameplay_feature.gd"

const ZONE_RADIUS := 6.5

var _player: GrayboxPlayer
var _label: Label
var _active := false
var _local_seconds := 0.0


func _ready() -> void:
	feature_id = &"domain_tracker"


func activate(context: Dictionary) -> void:
	super.activate(context)
	_player = context.get("player") as GrayboxPlayer
	var hud := context.get("hud") as CanvasLayer
	if _label == null and hud != null:
		_label = Label.new()
		_label.name = "DomainStatus"
		_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_label.position = Vector2(-180.0, 116.0)
		_label.size = Vector2(360.0, 58.0)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 21)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		hud.add_child(_label)
	_local_seconds = 0.0
	_active = true
	_label.visible = true
	set_process(true)


func deactivate() -> void:
	_active = false
	set_process(false)
	if _label != null:
		_label.visible = false
	super.deactivate()


func _process(delta: float) -> void:
	if not _active or _player == null or _label == null:
		return
	var flat := Vector2(_player.global_position.x, _player.global_position.z)
	var inside := flat.length_squared() <= ZONE_RADIUS * ZONE_RADIUS
	if inside:
		_local_seconds += delta
	_label.text = (
		"CONTROLANDO NÚCLEO · %.1f s" % _local_seconds
		if inside
		else "ENTRA AL NÚCLEO · %.1f m" % maxf(0.0, flat.length() - ZONE_RADIUS)
	)
	_label.modulate = Color(0.35, 1.0, 0.9) if inside else Color(1.0, 0.68, 0.22)
