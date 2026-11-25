extends Node2D

@export_group("Cliques")
@export var som_clique: AudioStream
@export_range(-40.0, 6.0) var volume_clique_db: float = 0.0

@export_group("Músicas e Ambientes")
@export var musica_menu: AudioStream
@export var som_mundo: AudioStream
# Opção a mais para colocar música no mundo principal (tocada em paralelo ao som_mundo)
@export var musica_mundo_extra: AudioStream
@export_range(-40.0, 6.0) var volume_musica_db: float = -8.0
@export_range(-40.0, 6.0) var volume_musica_menu_db: float = -8.0
@export_range(-40.0, 6.0) var volume_som_mundo_db: float = -8.0
@export_range(-40.0, 6.0) var volume_musica_mundo_extra_db: float = -8.0

var _player_musica: AudioStreamPlayer
var _player_clique: AudioStreamPlayer
var _player_musica_mundo_extra: AudioStreamPlayer
var _faixa_atual: AudioStream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Tocador para música do menu / som do mundo
	_player_musica = AudioStreamPlayer.new()
	_player_musica.volume_db = volume_musica_db
	add_child(_player_musica)
	_player_musica.finished.connect(_repetir_faixa)
	
	# Tocador extra para música adicional do mundo principal
	if musica_mundo_extra != null:
		_player_musica_mundo_extra = AudioStreamPlayer.new()
		_player_musica_mundo_extra.stream = musica_mundo_extra
		_player_musica_mundo_extra.volume_db = volume_musica_mundo_extra_db
		add_child(_player_musica_mundo_extra)
		_player_musica_mundo_extra.finished.connect(_repetir_faixa_extra)
		_player_musica_mundo_extra.play()
	
	# Tocador para o clique do mouse
	_player_clique = AudioStreamPlayer.new()
	_player_clique.stream = som_clique
	_player_clique.volume_db = volume_clique_db
	add_child(_player_clique)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player_clique.stream != null:
			_player_clique.play()

func _process(_delta: float) -> void:
	if _player_musica == null:
		return
	if _faixa_atual == musica_menu:
		_player_musica.volume_db = volume_musica_menu_db
	elif _faixa_atual == som_mundo:
		_player_musica.volume_db = volume_som_mundo_db
	else:
		_player_musica.volume_db = volume_musica_db
	if _player_musica_mundo_extra != null:
		_player_musica_mundo_extra.volume_db = volume_musica_mundo_extra_db

func _repetir_faixa() -> void:
	if _faixa_atual != null:
		_player_musica.play()

func _repetir_faixa_extra() -> void:
	if _player_musica_mundo_extra != null and _player_musica_mundo_extra.stream != null:
		_player_musica_mundo_extra.play()

func tocar(nova_faixa: AudioStream) -> void:
	if nova_faixa == null:
		parar()
		return
	if _faixa_atual == nova_faixa and _player_musica.playing:
		return
		
	_faixa_atual = nova_faixa
	_player_musica.stream = nova_faixa
	if nova_faixa == musica_menu:
		_player_musica.volume_db = volume_musica_menu_db
	elif nova_faixa == som_mundo:
		_player_musica.volume_db = volume_som_mundo_db
	else:
		_player_musica.volume_db = volume_musica_db
	_player_musica.play()

func parar() -> void:
	_faixa_atual = null
	_player_musica.stop()
