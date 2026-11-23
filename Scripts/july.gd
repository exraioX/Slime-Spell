extends CharacterBody2D

signal chegou_ao_destino

# =========================
# CONFIGURAÇÕES
# =========================
@export var velocidade: float = 80.0
@export var velocidade_encontro: float = 180.0
@export var tempo_idle: float = 2.0
@export var tempo_andando: float = 5.0
@export var direcao: float = 1.0
@export var altura_pulo_susto: float = 35.0
@export var duracao_exclamacao: float = 1.0

# =========================
# NÓS E SPRITES
# =========================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sombra: AnimatedSprite2D = $Sombra
@onready var balao_susto: Node2D = $BalaoSusto

# =========================
# SOMBRA
# =========================
@export var sombra_alpha_max: float = 0.49411765
@export var sombra_y_min: float = 620.0
@export var sombra_y_max: float = 1000.0
@export var sombra_banda: float = 150.0
@export var altura_salto_max: float = 160.0

# =========================
# CUTSCENE E CAMINHADA GUIADA
# =========================
@export var em_cutscene: bool = false

var _caminhando_ate_alvo: bool = false
var _alvo_x: float = 0.0
var _velocidade_alvo: float = 180.0

var _sombra_cenario: SombraCenario = null
var _sombra_pos_base: Vector2 = Vector2.ZERO
var _sombra_escala_base: Vector2 = Vector2.ONE
var _dist_chao_parado: float = -1.0
var _sprite_y_base: float = 0.0

# =========================
# CONTROLE
# =========================
var cronometro: float = 0.0
var estado: int = 0
var animacao_atual: String = ""

func _ready() -> void:
	cronometro = 0.0
	estado = 0
	velocity.x = 0
	sprite.flip_h = direcao < 0
	tocar_animacao("idle")

	if balao_susto != null:
		balao_susto.visible = false

	_sprite_y_base = sprite.position.y
	_sombra_pos_base = sombra.position
	_sombra_escala_base = sombra.scale

	_sombra_cenario = SombraCenario.new()
	_sombra_cenario.construir(
		get_tree().get_nodes_in_group("paredes_solidas"),
		sombra_y_min,
		sombra_y_max,
		sombra_banda
	)

func _physics_process(delta: float) -> void:
	# 1. MODO CUTSCENE DO ANIMATION PLAYER (posição travada pela régua)
	if em_cutscene and not _caminhando_ate_alvo:
		velocity = Vector2.ZERO
		sincronizar_sombra()
		atualizar_sombra()
		return

	# 2. GRAVIDADE (usada na rotina normal E na caminhada guiada)
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	else:
		if velocity.y > 0:
			velocity.y = 0

	# 3. CAMINHADA GUIADA COM COLISÃO DE CHÃO (para encontros de gatilho)
	if _caminhando_ate_alvo:
		var diferenca_x: float = _alvo_x - global_position.x
		if absf(diferenca_x) <= 6.0:
			global_position.x = _alvo_x
			velocity.x = 0.0
			_caminhando_ate_alvo = false
			tocar_animacao("idle")
			move_and_slide()
			sincronizar_sombra()
			atualizar_sombra()
			chegou_ao_destino.emit()
			return

		var dir_passo: float = signf(diferenca_x)
		direcao = dir_passo
		sprite.flip_h = dir_passo < 0
		velocity.x = dir_passo * _velocidade_alvo
		tocar_animacao("walk")

		move_and_slide()
		sincronizar_sombra()
		atualizar_sombra()
		return

	# 4. ROTINA AUTOMÁTICA (FORA DA CUTSCENE)
	if estado == 0:
		velocity.x = 0
		cronometro += delta
		tocar_animacao("idle")
		if cronometro >= tempo_idle:
			estado = 1
			cronometro = 0.0
			tocar_animacao("walk")

	elif estado == 1:
		velocity.x = direcao * velocidade
		cronometro += delta
		tocar_animacao("walk")
		if cronometro >= tempo_andando:
			estado = 2
			cronometro = 0.0
			velocity.x = 0
			tocar_animacao("idle")

	elif estado == 2:
		velocity.x = 0
		tocar_animacao("idle")

	move_and_slide()
	sincronizar_sombra()
	atualizar_sombra()

# =========================
# FUNÇÕES DE MOVIMENTO E CUTSCENE
# =========================
func caminhar_ate_x(destino_x: float, vel_custom: float = -1.0) -> void:
	em_cutscene = true
	_alvo_x = destino_x
	_velocidade_alvo = velocidade_encontro if vel_custom <= 0.0 else vel_custom
	_caminhando_ate_alvo = true

func cancelar_caminhada() -> void:
	_caminhando_ate_alvo = false
	velocity.x = 0.0

func iniciar_cutscene() -> void:
	_caminhando_ate_alvo = false
	em_cutscene = true
	velocity = Vector2.ZERO
	olhar_para_direita()

func finalizar_cutscene() -> void:
	_caminhando_ate_alvo = false
	em_cutscene = false
	estado = 2
	velocity = Vector2.ZERO
	tocar_animacao("idle")

func dar_pulo_susto() -> void:
	tocar_animacao("idle")
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", _sprite_y_base - altura_pulo_susto, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", _sprite_y_base, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func mostrar_exclamacao(tempo: float = -1.0) -> void:
	if balao_susto == null:
		return
	var duracao: float = duracao_exclamacao if tempo < 0.0 else tempo
	balao_susto.visible = true
	await get_tree().create_timer(duracao).timeout
	balao_susto.visible = false

func esconder_exclamacao() -> void:
	if balao_susto != null:
		balao_susto.visible = false

func olhar_para_direita() -> void:
	direcao = 1.0
	sprite.flip_h = false

func olhar_para_esquerda() -> void:
	direcao = -1.0
	sprite.flip_h = true

# =========================
# SOMBRA E ANIMAÇÃO
# =========================
func sincronizar_sombra() -> void:
	sombra.animation = sprite.animation
	sombra.frame = sprite.frame
	sombra.flip_h = sprite.flip_h

func atualizar_sombra() -> void:
	var fator_parede: float = 1.0
	if _sombra_cenario != null:
		fator_parede = _sombra_cenario.alpha_em(global_position.x)

	var dist_chao: float = _distancia_ate_chao()
	if is_on_floor() and _dist_chao_parado < 0.0:
		_dist_chao_parado = dist_chao

	var referencia: float = dist_chao
	if _dist_chao_parado >= 0.0:
		referencia = _dist_chao_parado

	var altura_pulo_visual: float = maxf(_sprite_y_base - sprite.position.y, 0.0)
	var altura: float = maxf(dist_chao - referencia, 0.0) + altura_pulo_visual
	var ar_t: float = clampf(altura / altura_salto_max, 0.0, 1.0)

	sombra.position = Vector2(_sombra_pos_base.x, _sombra_pos_base.y + altura)
	sombra.scale = _sombra_escala_base * lerpf(1.0, 0.45, ar_t)
	sombra.modulate.a = sombra_alpha_max * fator_parede * (1.0 - ar_t)

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

func tocar_animacao(nome: String) -> void:
	if animacao_atual == nome:
		return
	sprite.stop()
	sprite.animation = nome
	sprite.play()
	animacao_atual = nome
