extends Control

@export_file("*.tscn") var cena_principal: String = "res://Cenas/principal.tscn"

@export_group("Áudio da Cutscene")
@export var audio_cutscene: AudioStream
@export_range(-40.0, 6.0) var volume_audio_cutscene_db: float = -8.0

@onready var video: VideoStreamPlayer = $VideoStreamPlayer

var _finalizada: bool = false
var _player_audio: AudioStreamPlayer = null


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

	# Toca o áudio junto com o vídeo, encerrando com ele
	if audio_cutscene != null:
		_player_audio = AudioStreamPlayer.new()
		_player_audio.stream = audio_cutscene
		_player_audio.volume_db = volume_audio_cutscene_db
		add_child(_player_audio)
		_player_audio.play()

	await get_tree().process_frame

	if not video.is_playing():
		push_error("CUTSCENE: o video nao iniciou. Confira o Stream e o arquivo OGV.")


func _on_video_finished() -> void:
	if _finalizada:
		return

	_finalizada = true
	print("CUTSCENE: video finalizado. Indo para a fase principal.")

	if _player_audio != null:
		_player_audio.stop()
		_player_audio.queue_free()
		_player_audio = null

	Jogo.tocar_intro_principal = true

	if not ResourceLoader.exists(cena_principal):
		push_error("CUTSCENE: cena principal nao encontrada: " + cena_principal)
		return

	await Jogo.trocar_cena(cena_principal, false)
