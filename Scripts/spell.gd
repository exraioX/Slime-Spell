extends CharacterBody2D

# Movimento
@export var velocidade: float = 450.0
@export var aceleracao: float = 2500.0
@export var desaceleracao: float = 2800.0

# Pulo
@export var forca_pulo: float = -850.0
@export var coyote_time_max: float = 0.15
@export var jump_buffer_max: float = 0.12

# Gravidade
@export var gravidade: float = 2000.0
@export var gravidade_subida: float = 0.9
@export var gravidade_queda: float = 2.2

# Animação
@export var frame_pulo: int = 4
@export var frame_coleta: int = 4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sombra: AnimatedSprite2D = $Sombra

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var esta_pulando: bool = false
var animacao_pulo_travada: bool = false
var animacao_atual: String = ""

# Coleta
var item_interacao_atual: Node = null
var item_do_pick: Node = null
var fazendo_pick: bool = false
var item_ja_coletado: bool = false


func _ready() -> void:
	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:

	# Gravidade
	if not is_on_floor():
		if velocity.y < 0:
			velocity.y += gravidade * gravidade_subida * delta
		else:
			velocity.y += gravidade * gravidade_queda * delta

	# Coyote time
	if is_on_floor():
		coyote_timer = coyote_time_max
	else:
		coyote_timer -= delta

	# Pick em andamento bloqueia o resto
	if fazendo_pick:
		velocity.x = 0
		processar_pick()
		move_and_slide()
		return

	# Jump buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_max
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0)

	# Executa pulo
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = forca_pulo
		jump_buffer_timer = 0
		coyote_timer = 0
		esta_pulando = true
		animacao_pulo_travada = false
		tocar_animacao("jump")
		sprite.frame = 0

	# Movimento horizontal
	var direcao := Input.get_axis("ui_left", "ui_right")
	var velocidade_alvo := direcao * velocidade

	if direcao != 0:
		velocity.x = move_toward(velocity.x, velocidade_alvo, aceleracao * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, desaceleracao * delta)

	move_and_slide()

	# Interação com item
	if Input.is_action_just_pressed("interagir"):
		if item_interacao_atual != null:
			if is_instance_valid(item_interacao_atual):
				iniciar_pick(item_interacao_atual)
			else:
				item_interacao_atual = null

	update_animation(direcao)
	sincronizar_sombra()


func sincronizar_sombra() -> void:
	sombra.animation = sprite.animation
	sombra.frame = sprite.frame
	sombra.flip_h = sprite.flip_h


func tocar_animacao(nome: String) -> void:
	if fazendo_pick:
		return

	if animacao_atual != nome:
		sprite.play(nome)
		animacao_atual = nome


func update_animation(direcao: float) -> void:
	if fazendo_pick:
		return

	# No ar
	if not is_on_floor():
		if velocity.y < 0:
			tocar_animacao("jump")

			if not animacao_pulo_travada:
				if sprite.frame >= frame_pulo:
					sprite.frame = frame_pulo
					sprite.pause()
					animacao_pulo_travada = true
		else:
			if animacao_pulo_travada:
				animacao_pulo_travada = false
				sprite.play("jump")
				sprite.frame = frame_pulo
			else:
				tocar_animacao("jump")

		return

	# Aterrissou
	if esta_pulando:
		esta_pulando = false
		animacao_pulo_travada = false
		sprite.play()

	# Andando / parado
	if direcao != 0:
		tocar_animacao("walk")
		sprite.flip_h = direcao < 0
	else:
		tocar_animacao("idle")


func iniciar_pick(item: Node) -> void:
	if fazendo_pick or item == null or not is_instance_valid(item):
		return

	item_do_pick = item
	fazendo_pick = true
	item_ja_coletado = false
	velocity.x = 0

	animacao_atual = "pick"
	sprite.play("pick")
	sprite.frame = 0


func processar_pick() -> void:
	if item_ja_coletado:
		return

	if sprite.animation == "pick":
		if sprite.frame >= frame_coleta:
			if item_do_pick != null and is_instance_valid(item_do_pick):
				item_do_pick.coletar()

			item_ja_coletado = true


func _on_animation_finished() -> void:
	if sprite.animation != "pick":
		return

	fazendo_pick = false
	item_do_pick = null
	item_ja_coletado = false
	animacao_atual = ""

	var direcao := Input.get_axis("ui_left", "ui_right")
	update_animation(direcao)
