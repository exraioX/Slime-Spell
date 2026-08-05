extends Node

@export var tempo_minimo: float = 8.0
@export var tempo_maximo: float = 15.0
@export var usar_tempo_aleatorio: bool = false

@onready var som_ambiente: AudioStreamPlayer = $SomFabrica
@onready var timer_som: Timer = $SomFabrica/Timer

func _ready() -> void:
	timer_som.timeout.connect(_on_timer_som_timeout)
	if usar_tempo_aleatorio:
		configurar_proximo_tempo()

func _on_timer_som_timeout() -> void:
	som_ambiente.pitch_scale = randf_range(0.9, 1.1)
	som_ambiente.play()
	
	if usar_tempo_aleatorio:
		configurar_proximo_tempo()

func configurar_proximo_tempo() -> void:
	timer_som.wait_time = randf_range(tempo_minimo, tempo_maximo)
	timer_som.start()
