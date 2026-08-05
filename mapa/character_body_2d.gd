extends CharacterBody2D

@export var speed: float = 300.0
@export var run_speed: float = 1000.0
@export var jump_velocity: float = -650.0
@export var coyote_duration: float = 0.12

@export var gravidade_subida_multiplicador: float = 1.4
@export var gravidade_queda_multiplicador: float = 3.2

@export var intervalo_passo_andar: float = 0.35
@export var intervalo_passo_correr: float = 0.18

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var som_passo: AudioStreamPlayer2D = $SomPasso
@onready var timer_passo: Timer = $TimerPasso

var coyote_timer: float = 0.0
var velocidade_no_ar: float = 0.0
var estava_no_ar: bool = false

func _ready() -> void:
	timer_passo.timeout.connect(_on_timer_passo_timeout)

func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0
		coyote_timer = coyote_duration
		
		if estava_no_ar:
			estava_no_ar = false
			if Input.get_axis("ui_left", "ui_right") != 0:
				_tocar_som_passo()
				timer_passo.start()
	else:
		var gravidade_padrao = ProjectSettings.get_setting("physics/2d/default_gravity")
		if velocity.y > 0:
			velocity.y += (gravidade_padrao * gravidade_queda_multiplicador) * delta
		else:
			velocity.y += (gravidade_padrao * gravidade_subida_multiplicador) * delta
		coyote_timer -= delta
		estava_no_ar = true

	var current_speed = speed
	var is_running = false
	
	if is_on_floor():
		if Input.is_key_pressed(KEY_SHIFT):
			current_speed = run_speed
			is_running = true
		velocidade_no_ar = current_speed
	else:
		current_speed = velocidade_no_ar
		if current_speed == run_speed:
			is_running = true

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		if coyote_timer > 0.0:
			velocity.y = jump_velocity
			coyote_timer = 0.0
			timer_passo.stop()
			som_passo.stop()

	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()
	update_animation(direction, is_running)
	gerenciar_som_passo(direction, is_running)

func update_animation(direction: float, is_running: bool) -> void:
	if direction != 0:
		sprite.play("walk")
		if is_running:
			sprite.speed_scale = 1.8
		else:
			sprite.speed_scale = 1.0
		
		if direction < 0:
			sprite.flip_h = true
		elif direction > 0:
			sprite.flip_h = false
	else:
		sprite.speed_scale = 1.0
		sprite.play("idle")

func gerenciar_som_passo(direction: float, is_running: bool) -> void:
	if direction != 0 and is_on_floor():
		var intervalo_atual = intervalo_passo_correr if is_running else intervalo_passo_andar
		
		if timer_passo.is_stopped() or timer_passo.wait_time != intervalo_atual:
			timer_passo.wait_time = intervalo_atual
			
			if timer_passo.is_stopped():
				_tocar_som_passo()
				
			timer_passo.start()
	else:
		timer_passo.stop()

func _tocar_som_passo() -> void:
	som_passo.pitch_scale = randf_range(0.9, 1.1)
	som_passo.play()

func _on_timer_passo_timeout() -> void:
	_tocar_som_passo()
