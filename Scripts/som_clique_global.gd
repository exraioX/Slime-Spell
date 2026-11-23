extends Node

@export var som_clique: AudioStream = preload("res://Sons/clique1.wav")
@export_range(-40.0, 6.0) var volume_db: float = 0.0

var _player: AudioStreamPlayer

func _ready() -> void:
	# Garante que o som continue tocando mesmo se o jogo pausar ou trocar de cena
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_player = AudioStreamPlayer.new()
	_player.stream = som_clique
	_player.volume_db = volume_db
	add_child(_player)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player != null and _player.stream != null:
			_player.play()
