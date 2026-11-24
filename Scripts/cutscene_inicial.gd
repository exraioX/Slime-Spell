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
		push_error("CUTSCENE: nenhum OGV foi atribuido ao VideoStreamPlayer.")
		return

	print("CUTSCENE: cena aberta. Video: ", video.stream.resource_path)
	call_deferred("_iniciar_video")


func _iniciar_video() -> void:
	if not is_instance_valid(video):
		return

	video.stop()
	video.play()
	await get_tree().process_frame

	if not video.is_playing():
		push_error("CUTSCENE: o video nao iniciou. Confira o Stream e o arquivo OGV.")


func _on_video_finished() -> void:
	if _finalizada:
		return

	_finalizada = true
	print("CUTSCENE: video finalizado. Indo para a fase principal.")

	if not ResourceLoader.exists(cena_principal):
		push_error("CUTSCENE: cena principal nao encontrada: " + cena_principal)
		return

	await Jogo.trocar_cena(cena_principal, false)
