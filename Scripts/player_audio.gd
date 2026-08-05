extends Node

@export var intervalo_passo_andar: float = 0.35
@export var intervalo_passo_correr: float = 0.18

@onready var som_passo: AudioStreamPlayer2D = $SomPasso
@onready var timer_passo: Timer = $TimerPasso

var player: CharacterBody2D
var estava_no_ar: bool = false

func _ready() -> void:
	timer_passo.timeout.connect(_on_timer_passo_timeout)
	if get_parent() is CharacterBody2D:
		player = get_parent()

func _process(_delta: float) -> void:
	if not player:
		return

	var direction = Input.get_axis("ui_left", "ui_right")
	var is_running = Input.is_key_pressed(KEY_SHIFT) and player.is_on_floor()
	
	if player.is_on_floor():
		if estava_no_ar:
			estava_no_ar = false
			if direction != 0:
				tocar_som_passo()
				timer_passo.start()
	else:
		estava_no_ar = true

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		if player.is_on_floor() or estava_no_ar:
			timer_passo.stop()
			som_passo.stop()

	gerenciar_loop_passos(direction, is_running)

func gerenciar_loop_passos(direction: float, is_running: bool) -> void:
	if direction != 0 and player.is_on_floor():
		var intervalo_atual = intervalo_passo_correr if is_running else intervalo_passo_andar
		
		if timer_passo.is_stopped() or timer_passo.wait_time != intervalo_atual:
			timer_passo.wait_time = intervalo_atual
			if timer_passo.is_stopped():
				tocar_som_passo()
			timer_passo.start()
	else:
		timer_passo.stop()

func tocar_som_passo() -> void:
	som_passo.pitch_scale = randf_range(0.9, 1.1)
	som_passo.play()

func _on_timer_passo_timeout() -> void:
	tocar_som_passo()
