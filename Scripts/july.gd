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
@onready var sombra: AnimatedSprite2D = $Sombra


# =========================
# SOMBRA
# =========================
# A sombra é forte onde existe cenário sólido atrás (paredes, muros, prédios)
# e some completamente na frente do parallax da cidade. Ao pular, ela encolhe
# e desaparece como uma sombra real.
@export var sombra_alpha_max: float = 0.49411765
@export var sombra_y_min: float = 620.0
@export var sombra_y_max: float = 1000.0
@export var sombra_banda: float = 150.0
@export var altura_salto_max: float = 160.0

var _sombra_cenario: SombraCenario = null
var _sombra_pos_base: Vector2 = Vector2.ZERO
var _sombra_escala_base: Vector2 = Vector2.ONE
var _dist_chao_parado: float = -1.0


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

	_sombra_pos_base = sombra.position
	_sombra_escala_base = sombra.scale

	# Monta os intervalos de sombra a partir da arte sólida das paredes.
	_sombra_cenario = SombraCenario.new()
	_sombra_cenario.construir(
		get_tree().get_nodes_in_group("paredes_solidas"),
		sombra_y_min,
		sombra_y_max,
		sombra_banda
	)


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

	sincronizar_sombra()
	atualizar_sombra()


# =========================
# SOMBRA
# =========================

func sincronizar_sombra() -> void:

	sombra.animation = sprite.animation
	sombra.frame = sprite.frame
	sombra.flip_h = sprite.flip_h


# A sombra depende de duas coisas:
#   1) existe cenário sólido atrás do personagem? (paredes)
#   2) o personagem está no chão ou no ar? (sombra real que encolhe ao pular)
func atualizar_sombra() -> void:

	# 1) Fator de parede: 0 na frente da cidade, 1 sobre o cenário.
	var fator_parede: float = 1.0
	if _sombra_cenario != null:
		fator_parede = _sombra_cenario.alpha_em(global_position.x)

	# 2) Contato com o chão.
	var dist_chao: float = _distancia_ate_chao()

	if is_on_floor() and _dist_chao_parado < 0.0:
		_dist_chao_parado = dist_chao

	var referencia: float = dist_chao
	if _dist_chao_parado >= 0.0:
		referencia = _dist_chao_parado

	var altura: float = maxf(dist_chao - referencia, 0.0)
	var ar_t: float = clampf(altura / altura_salto_max, 0.0, 1.0)

	# 3) Aplica posição no chão, encolhimento e alpha.
	sombra.position = Vector2(_sombra_pos_base.x, _sombra_pos_base.y + altura)
	sombra.scale = _sombra_escala_base * lerpf(1.0, 0.45, ar_t)
	sombra.modulate.a = sombra_alpha_max * fator_parede * (1.0 - ar_t)


# Distância (em pixels) do personagem até o chão logo abaixo.
func _distancia_ate_chao() -> float:
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var de: Vector2 = global_position
	var ate: Vector2 = global_position + Vector2(0, 600)

	var consulta := PhysicsRayQueryParameters2D.create(de, ate)
	consulta.exclude = [get_rid()]
	consulta.collision_mask = 16

	var resultado: Dictionary = espaco.intersect_ray(consulta)
	if resultado.is_empty():
		return 600.0

	return de.distance_to(resultado.position)


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
