extends CharacterBody2D


# =========================
# MOVIMENTO
# =========================

@export var velocidade: float = 450.0
@export var aceleracao: float = 2500.0
@export var desaceleracao: float = 2800.0


# =========================
# PULO
# =========================

@export var forca_pulo: float = -850.0

# Tempo que permite pular após sair da borda
@export var coyote_time_max: float = 0.15

# Guarda o comando de pulo antes de tocar no chão
@export var jump_buffer_max: float = 0.12



# =========================
# GRAVIDADE
# =========================

@export var gravidade: float = 2000.0

# subida mais suave
@export var gravidade_subida: float = 0.9

# queda mais rápida
@export var gravidade_queda: float = 2.2



# =========================
# SPRITE
# =========================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D



# =========================
# VARIÁVEIS
# =========================

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var animacao_atual: String = ""





func _physics_process(delta: float) -> void:


	# =========================
	# GRAVIDADE
	# =========================

	if not is_on_floor():

		if velocity.y < 0:

			# subindo
			velocity.y += gravidade * gravidade_subida * delta


		else:

			# caindo
			velocity.y += gravidade * gravidade_queda * delta




	# =========================
	# COYOTE TIME
	# =========================

	if is_on_floor():

		coyote_timer = coyote_time_max

	else:

		coyote_timer -= delta





	# =========================
	# JUMP BUFFER
	# =========================

	if Input.is_action_just_pressed("ui_accept"):

		jump_buffer_timer = jump_buffer_max


	else:

		jump_buffer_timer = max(
			jump_buffer_timer - delta,
			0
		)





	# =========================
	# EXECUTA PULO
	# =========================

	if jump_buffer_timer > 0 and coyote_timer > 0:


		velocity.y = forca_pulo

		jump_buffer_timer = 0

		coyote_timer = 0





	# =========================
	# CONTROLE DO PULO
	# =========================
	
	# soltou o botão = corta o pulo

	if Input.is_action_just_released("ui_accept"):

		if velocity.y < 0:

			velocity.y *= 0.45





	# =========================
	# MOVIMENTO HORIZONTAL
	# =========================

	var direcao := Input.get_axis(
		"ui_left",
		"ui_right"
	)



	var velocidade_alvo = direcao * velocidade



	if direcao != 0:


		velocity.x = move_toward(
			velocity.x,
			velocidade_alvo,
			aceleracao * delta
		)


	else:


		velocity.x = move_toward(
			velocity.x,
			0,
			desaceleracao * delta
		)





	move_and_slide()



	update_animation(direcao)






# =========================
# SISTEMA DE ANIMAÇÃO
# =========================


func tocar_animacao(nome: String):


	if animacao_atual != nome:


		sprite.play(nome)

		animacao_atual = nome





func update_animation(direcao: float):


	# No ar

	if not is_on_floor():


		if velocity.y < 0:

			tocar_animacao("jump")


		else:

			tocar_animacao("fall")


		return





	# andando

	if direcao != 0:


		tocar_animacao("walk")


		if direcao < 0:

			sprite.flip_h = true

		else:

			sprite.flip_h = false





	# parado

	else:


		tocar_animacao("idle")
