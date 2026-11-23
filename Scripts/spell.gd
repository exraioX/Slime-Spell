extends CharacterBody2D

# =========================
# CONFIGURAÇÕES DE MOVIMENTO
# =========================
@export_group("Movimento")
@export var velocidade: float = 260.0
@export var aceleracao: float = 1800.0
@export var atrito: float = 1600.0

# =========================
# NOMES DAS ANIMAÇÕES
# =========================
@export_group("Animações")
@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_pick_idle: String = "pick"
@export var anim_pick_walk: String = "pick"

# =========================
# REFERÊNCIAS DE NÓS
# =========================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ponto_segurar: Marker2D = $PontoSegurar
@onready var area_interacao: Area2D = $AreaInteracao

# =========================
# ESTADO DO PERSONAGEM
# =========================
var item_segurado: Node2D = null
var ultima_direcao: Vector2 = Vector2.DOWN
var animacao_atual: String = ""
var _espaco_pressionado_antes: bool = false

func _ready() -> void:
	_atualizar_direcao_interacao(Vector2.DOWN)

func _physics_process(delta: float) -> void:
	# 1. Movimento em X e Y (Setas ou WASD)
	var direcao: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if direcao != Vector2.ZERO:
		velocity = velocity.move_toward(direcao * velocidade, aceleracao * delta)
		ultima_direcao = direcao.normalized()
		_atualizar_direcao_interacao(ultima_direcao)
		
		if direcao.x != 0:
			sprite.flip_h = direcao.x < 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, atrito * delta)

	move_and_slide()
	_atualizar_animacao(direcao != Vector2.ZERO)
	_verificar_botao_espaco()

# =========================
# INTERAÇÃO (ESPAÇO PARA PEGAR / SOLTAR)
# =========================
func _verificar_botao_espaco() -> void:
	var espaco_atual: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if espaco_atual and not _espaco_pressionado_antes:
		if item_segurado == null:
			_tentar_pegar_item()
		else:
			_tentar_soltar_ou_entregar_item()
	_espaco_pressionado_antes = espaco_atual

func _tentar_pegar_item() -> void:
	var alvos: Array[Node2D] = []
	alvos.append_array(area_interacao.get_overlapping_bodies())
	alvos.append_array(area_interacao.get_overlapping_areas())

	var melhor_item: Node2D = null
	var menor_distancia: float = INF

	for alvo in alvos:
		if alvo.is_in_group("reciclavel") and not alvo.get("esta_sendo_segurado"):
			var dist: float = global_position.distance_to(alvo.global_position)
			if dist < menor_distancia:
				menor_distancia = dist
				melhor_item = alvo

	if melhor_item != null:
		pegar_item(melhor_item)

func pegar_item(item: Node2D) -> void:
	item_segurado = item
	
	if item.has_method("ao_ser_pego"):
		item.ao_ser_pego()

	item.reparent(ponto_segurar)
	item.position = Vector2.ZERO

func _tentar_soltar_ou_entregar_item() -> void:
	var areas_frente: Array[Area2D] = area_interacao.get_overlapping_areas()
	for area in areas_frente:
		if area.is_in_group("lixeira") and area.has_method("receber_item"):
			var aceitou: bool = area.receber_item(item_segurado)
			if aceitou:
				item_segurado = null
			return

	soltar_item_no_chao()

func soltar_item_no_chao() -> void:
	if item_segurado == null:
		return

	var item: Node2D = item_segurado
	item_segurado = null

	var cena_atual: Node = get_parent()
	var pos_soltar: Vector2 = global_position + (ultima_direcao * 32.0)
	
	item.reparent(cena_atual)
	item.global_position = pos_soltar

	if item.has_method("ao_ser_solto"):
		item.ao_ser_solto()

# =========================
# DIREÇÃO E ANIMAÇÕES
# =========================
func _atualizar_direcao_interacao(dir: Vector2) -> void:
	if area_interacao != null:
		area_interacao.rotation = dir.angle()

func _atualizar_animacao(esta_andando: bool) -> void:
	var proxima_anim: String = ""

	if item_segurado != null:
		proxima_anim = anim_pick_walk if esta_andando else anim_pick_idle
	else:
		proxima_anim = anim_walk if esta_andando else anim_idle

	if animacao_atual != proxima_anim and sprite.sprite_frames.has_animation(proxima_anim):
		animacao_atual = proxima_anim
		sprite.play(proxima_anim)
