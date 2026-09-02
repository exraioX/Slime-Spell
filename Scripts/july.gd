extends CharacterBody2D


# =========================
# CONFIGURAÇÕES
# =========================

@export var velocidade: float = 80.0

# Tempo parado no início
@export var tempo_idle: float = 2.0

# Tempo andando
@export var tempo_andando: float = 5.0

# 1 = direita
# -1 = esquerda
@export var direcao: float = 1.0


# =========================
# SPRITE
# =========================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# =========================
# CONTROLE
# =========================

var cronometro: float = 0.0

# 0 = idle inicial
# 1 = andando
# 2 = idle permanente
var estado: int = 0

var animacao_atual: String = ""


# =========================
# INÍCIO
# =========================

func _ready() -> void:

	cronometro = 0.0
	estado = 0

	velocity.x = 0

	sprite.flip_h = direcao < 0

	tocar_animacao("idle")


# =========================
# FÍSICA
# =========================

func _physics_process(delta: float) -> void:


	# =========================
	# GRAVIDADE
	# =========================

	if not is_on_floor():

		velocity.y += (
			ProjectSettings.get_setting(
				"physics/2d/default_gravity"
			) * delta
		)

	else:

		velocity.y = 0


	# =========================
	# IDLE INICIAL
	# =========================

	if estado == 0:

		velocity.x = 0

		cronometro += delta

		tocar_animacao("idle")


		if cronometro >= tempo_idle:

			estado = 1
			cronometro = 0.0

			tocar_animacao("walk")


	# =========================
	# ANDANDO
	# =========================

	elif estado == 1:

		velocity.x = direcao * velocidade

		cronometro += delta

		tocar_animacao("walk")


		if cronometro >= tempo_andando:

			estado = 2
			cronometro = 0.0

			velocity.x = 0

			tocar_animacao("idle")


	# =========================
	# PARADO PARA SEMPRE
	# =========================

	elif estado == 2:

		velocity.x = 0

		tocar_animacao("idle")


	# =========================
	# MOVIMENTO
	# =========================

	move_and_slide()


# =========================
# TOCAR ANIMAÇÃO
# =========================

func tocar_animacao(nome: String) -> void:

	# Se já está nessa animação,
	# não faz nada.
	if animacao_atual == nome:
		return

	# Para qualquer animação anterior
	sprite.stop()

	# Troca para a nova animação
	sprite.animation = nome

	# Começa a animação
	sprite.play()

	animacao_atual = nome
