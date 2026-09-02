extends CharacterBody2D


# =====================================================
# MOVIMENTO
# =====================================================

@export var velocidade: float = 450.0
@export var aceleracao: float = 2500.0
@export var desaceleracao: float = 2800.0


# =====================================================
# PULO
# =====================================================

@export var forca_pulo: float = -850.0

@export var coyote_time_max: float = 0.15

@export var jump_buffer_max: float = 0.12


# =====================================================
# GRAVIDADE
# =====================================================

@export var gravidade: float = 2000.0

@export var gravidade_subida: float = 0.9

@export var gravidade_queda: float = 2.2


# =====================================================
# ANIMAÇÃO DO PULO
# =====================================================

# Frame onde o personagem fica parado durante a subida
@export var frame_pulo: int = 4


# =====================================================
# ANIMAÇÃO DE PEGAR
# =====================================================

# Frame em que o item será coletado
@export var frame_coleta: int = 4


# =====================================================
# SPRITE
# =====================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# =====================================================
# VARIÁVEIS DO PULO
# =====================================================

var coyote_timer: float = 0.0

var jump_buffer_timer: float = 0.0

var esta_pulando: bool = false

var animacao_pulo_travada: bool = false


# =====================================================
# CONTROLE DA ANIMAÇÃO
# =====================================================

var animacao_atual: String = ""


# =====================================================
# SISTEMA DE COLETA
# =====================================================

# Item que está próximo do Spell
var item_interacao_atual: Node = null

# Item que está sendo coletado
var item_do_pick: Node = null

# Indica se o personagem está executando o pick
var fazendo_pick: bool = false

# Impede que o mesmo item seja coletado duas vezes
var item_ja_coletado: bool = false


# =====================================================
# READY
# =====================================================

func _ready() -> void:

	# Conecta o sinal que avisa quando uma animação terminou
	if not sprite.animation_finished.is_connected(_on_animation_finished):

		sprite.animation_finished.connect(_on_animation_finished)


# =====================================================
# FÍSICA
# =====================================================

func _physics_process(delta: float) -> void:


	# =================================================
	# GRAVIDADE
	# =================================================

	if not is_on_floor():

		if velocity.y < 0:

			# -----------------------------------------
			# SUBINDO
			# -----------------------------------------

			velocity.y += (
				gravidade
				* gravidade_subida
				* delta
			)

		else:

			# -----------------------------------------
			# CAINDO
			# -----------------------------------------

			velocity.y += (
				gravidade
				* gravidade_queda
				* delta
			)


	# =================================================
	# COYOTE TIME
	# =================================================

	if is_on_floor():

		coyote_timer = coyote_time_max

	else:

		coyote_timer -= delta


	# =================================================
	# PICK
	# =================================================

	# Se estiver pegando um item,
	# TODO o restante do controle normal é bloqueado.

	if fazendo_pick:

		# Não deixa andar
		velocity.x = 0

		# Verifica se chegou ao frame 4
		processar_pick()

		# Continua aplicando gravidade
		move_and_slide()

		# IMPORTANTE:
		# impede que walk/idle/jump alterem a animação
		return


	# =================================================
	# JUMP BUFFER
	# =================================================

	if Input.is_action_just_pressed("ui_accept"):

		jump_buffer_timer = jump_buffer_max

	else:

		jump_buffer_timer = max(
			jump_buffer_timer - delta,
			0
		)


	# =================================================
	# EXECUTA PULO
	# =================================================

	if jump_buffer_timer > 0 and coyote_timer > 0:

		velocity.y = forca_pulo

		jump_buffer_timer = 0

		coyote_timer = 0

		esta_pulando = true

		animacao_pulo_travada = false

		# Começa a animação do pulo
		tocar_animacao("jump")

		# Começa no frame 0
		sprite.frame = 0


	# =================================================
	# CORTA O PULO AO SOLTAR
	# =================================================

	if Input.is_action_just_released("ui_accept"):

		if velocity.y < 0:

			velocity.y *= 0.45


	# =================================================
	# MOVIMENTO HORIZONTAL
	# =================================================

	var direcao := Input.get_axis(
		"ui_left",
		"ui_right"
	)


	var velocidade_alvo := direcao * velocidade


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


	# =================================================
	# MOVIMENTAÇÃO
	# =================================================

	move_and_slide()


	# =================================================
	# INTERAÇÃO COM ITEM
	# =================================================

	if Input.is_action_just_pressed("interagir"):

		print("APERTEI E!")


		if item_interacao_atual != null:

			# Confirma se o item ainda existe
			if is_instance_valid(item_interacao_atual):

				print(
					"ITEM ENCONTRADO: ",
					item_interacao_atual.name
				)

				iniciar_pick(item_interacao_atual)

			else:

				item_interacao_atual = null

				print("ITEM NÃO EXISTE MAIS")

		else:

			print("NENHUM ITEM PERTO")


	# =================================================
	# ANIMAÇÃO
	# =================================================

	update_animation(direcao)


# =====================================================
# TOCAR ANIMAÇÃO
# =====================================================

func tocar_animacao(nome: String) -> void:

	# Não deixa nenhuma animação normal
	# interromper o pick.

	if fazendo_pick:

		return


	if animacao_atual != nome:

		sprite.play(nome)

		animacao_atual = nome


# =====================================================
# ATUALIZA ANIMAÇÃO
# =====================================================

func update_animation(direcao: float) -> void:


	# =================================================
	# PROTEÇÃO CONTRA INTERRUPÇÃO DO PICK
	# =================================================

	if fazendo_pick:

		return


	# =================================================
	# NO AR
	# =================================================

	if not is_on_floor():

		# ---------------------------------------------
		# SUBINDO
		# ---------------------------------------------

		if velocity.y < 0:

			tocar_animacao("jump")


			if not animacao_pulo_travada:

				if sprite.frame >= frame_pulo:

					sprite.frame = frame_pulo

					sprite.pause()

					animacao_pulo_travada = true


		# ---------------------------------------------
		# CAINDO
		# ---------------------------------------------

		else:

			if animacao_pulo_travada:

				animacao_pulo_travada = false

				sprite.play("jump")

				sprite.frame = frame_pulo

			else:

				tocar_animacao("jump")


		return


	# =================================================
	# ATERRISSOU
	# =================================================

	if esta_pulando:

		esta_pulando = false

		animacao_pulo_travada = false

		sprite.play()


	# =================================================
	# ANDANDO
	# =================================================

	if direcao != 0:

		tocar_animacao("walk")


		if direcao < 0:

			sprite.flip_h = true

		else:

			sprite.flip_h = false


	# =================================================
	# PARADO
	# =================================================

	else:

		tocar_animacao("idle")


# =====================================================
# INICIAR PICK
# =====================================================

func iniciar_pick(item: Node) -> void:

	# Já está pegando alguma coisa
	if fazendo_pick:

		return


	# Item inválido
	if item == null:

		return


	if not is_instance_valid(item):

		return


	print("INICIANDO PICK!")


	# =================================================
	# GUARDA O ITEM
	# =================================================

	item_do_pick = item


	# =================================================
	# ATIVA O ESTADO DE PICK
	# =================================================

	fazendo_pick = true

	item_ja_coletado = false


	# =================================================
	# PARA O MOVIMENTO
	# =================================================

	velocity.x = 0


	# =================================================
	# INICIA A ANIMAÇÃO
	# =================================================

	animacao_atual = "pick"

	sprite.play("pick")

	# Começa no frame 0
	sprite.frame = 0


# =====================================================
# PROCESSAR PICK
# =====================================================

func processar_pick() -> void:

	# Já coletou
	if item_ja_coletado:

		return


	# =================================================
	# FRAME DE COLETA
	# =================================================

	if sprite.animation == "pick":

		if sprite.frame >= frame_coleta:

			print("FRAME 4 - PEGANDO ITEM!")


			# Verifica se o item ainda existe
			if item_do_pick != null:

				if is_instance_valid(item_do_pick):

					# Chama a função coletar()
					item_do_pick.coletar()

				else:

					print("ITEM JÁ FOI REMOVIDO")


			# Impede nova coleta
			item_ja_coletado = true


# =====================================================
# ANIMAÇÃO TERMINOU
# =====================================================

func _on_animation_finished() -> void:

	# Só queremos tratar o fim do pick
	if sprite.animation != "pick":

		return


	print("PICK TERMINOU")


	# =================================================
	# LIBERA O PERSONAGEM
	# =================================================

	fazendo_pick = false

	item_do_pick = null

	item_ja_coletado = false


	# =================================================
	# DECIDE A PRÓXIMA ANIMAÇÃO
	# =================================================

	var direcao := Input.get_axis(
		"ui_left",
		"ui_right"
	)


	# -------------------------------------------------
	# ESTÁ ANDANDO
	# -------------------------------------------------

	if direcao != 0:

		animacao_atual = ""

		tocar_animacao("walk")


		if direcao < 0:

			sprite.flip_h = true

		else:

			sprite.flip_h = false


	# -------------------------------------------------
	# ESTÁ PARADO
	# -------------------------------------------------

	else:

		animacao_atual = ""

		tocar_animacao("idle")
