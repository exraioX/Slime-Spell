extends Node

@export_group("Áudios do Menu")
@export var musica_fundo: AudioStream
@export_range(-40.0, 6.0) var volume_musica_db: float = -8.0

@export var som_clique: AudioStream
@export_range(-40.0, 6.0) var volume_clique_db: float = 0.0

var _player_musica: AudioStreamPlayer
var _player_clique: AudioStreamPlayer

func _ready() -> void:
	# Música de fundo em loop
	if musica_fundo != null:
		_player_musica = AudioStreamPlayer.new()
		_player_musica.stream = musica_fundo
		_player_musica.volume_db = volume_musica_db
		add_child(_player_musica)
		_player_musica.finished.connect(_player_musica.play)
		_player_musica.play()

	# Som de clique conectado automaticamente a todos os botões do Menu
	if som_clique != null:
		_player_clique = AudioStreamPlayer.new()
		_player_clique.stream = som_clique
		_player_clique.volume_db = volume_clique_db
		add_child(_player_clique)
		_conectar_botoes(get_parent())

func _conectar_botoes(no: Node) -> void:
	for filho in no.get_children():
		if filho is BaseButton:
			if not filho.pressed.is_connected(_tocar_clique):
				filho.pressed.connect(_tocar_clique)
		_conectar_botoes(filho)

func _tocar_clique() -> void:
	if _player_clique != null:
		_player_clique.play()
