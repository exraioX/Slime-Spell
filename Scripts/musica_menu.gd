extends Node

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)

func tocar_musica(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	# Evita reiniciar a música se ela já estiver tocando
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func parar_com_fade(duracao: float = 1.0) -> void:
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -40.0, duracao)
	await tween.finished
	player.stop()
