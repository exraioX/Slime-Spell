extends Control

@export_file("*.tscn") var cena_principal: String = "res://Cenas/principal.tscn"

@onready var video: VideoStreamPlayer = $VideoStreamPlayer

var _finalizada: bool = false


func _ready() -> void:
	video.expand = true
	video.loop = false
	video.autoplay = false

	if not video.finished.is_connected(_on_video_finished):
		video.finished.connect(_on_video_finished)

	if video.stream == null:
		push_error("CUTSCENE: nenhum vídeo foi atribuído ao VideoStreamPlayer.")
		return

	print("CUTSCENE: iniciando vídeo: ", video.stream.resource_path)
	call_deferred("_iniciar_video")


func _iniciar_video() -> void:
	if not is_instance_valid(video):
		return

	video.stop()
	video.play()

	# Confirma no Output se o player conseguiu iniciar.
	await get_tree().process_frame
	if not video.is_playing():
		push_warning("CUTSCENE: o VideoStreamPlayer não iniciou. Confira o formato/importação do OGV.")


func _on_video_finished() -> void:
	if _finalizada:
		return

	_finalizada = true
	print("CUTSCENE: vídeo terminou; iniciando transição.")

	if not is_instance_valid(Jogo):
		push_error("CUTSCENE: o Autoload 'Jogo' não está configurado.")
		return

	if not ResourceLoader.exists(cena_principal):
		push_error("CUTSCENE: cena principal não encontrada: " + cena_principal)
		return

	await Jogo.trocar_cena(cena_principal, false)
