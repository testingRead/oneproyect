class_name OneProjectLoadingScreen
extends CanvasLayer

@onready var status_label: Label = $Overlay/Content/Status
@onready var progress_bar: ProgressBar = $Overlay/Content/Progress
@onready var detail_label: Label = $Overlay/Content/Detail

var _target_path := ""
var _changing := false
var _elapsed := 0.0


func begin(target_path: String, status := "PREPARANDO PARTIDA") -> void:
	if _changing or target_path.is_empty():
		return
	_target_path = target_path
	status_label.text = status
	progress_bar.value = 0.0
	visible = true
	var error := ResourceLoader.load_threaded_request(_target_path, "", true)
	if error != OK:
		detail_label.text = "No se pudo preparar el escenario"
		return
	set_process(true)


func _process(delta: float) -> void:
	if _changing or _target_path.is_empty():
		return
	_elapsed += delta
	var progress := []
	var state := ResourceLoader.load_threaded_get_status(_target_path, progress)
	var amount := float(progress[0]) if not progress.is_empty() else 0.0
	progress_bar.value = amount * 100.0
	detail_label.text = "CARGANDO%s" % ".".repeat(int(_elapsed * 2.5) % 4)
	if state == ResourceLoader.THREAD_LOAD_FAILED:
		set_process(false)
		detail_label.text = "Error al cargar. Inténtalo nuevamente."
	elif state == ResourceLoader.THREAD_LOAD_LOADED:
		_changing = true
		progress_bar.value = 100.0
		detail_label.text = "LISTO"
		var packed := ResourceLoader.load_threaded_get(_target_path) as PackedScene
		if packed == null:
			detail_label.text = "Escenario inválido"
			return
		get_tree().change_scene_to_packed(packed)
		await get_tree().process_frame
		queue_free()
