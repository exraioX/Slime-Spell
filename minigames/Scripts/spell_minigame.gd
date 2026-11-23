extends CharacterBody2D

signal inventario_atualizado(inventario: Dictionary)

@export var velocidade: float = 260.0
@export var aceleracao: float = 1800.0
@export var atrito: float = 1600.0
@export var limite_mochila: int = 10

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_interacao: Area2D = $AreaInteracao

var inventario: Dictionary = {}
var ultima_direcao: Vector2 = Vector2.DOWN
var animacao_atual: String = ""
var _espaco_antes: bool = false

func _ready() -> void:
	# Garante que o CharacterBody2D use visão top-down (não trava no chão como plataforma)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	if area_interacao != null:
		area_interacao.rotation = Vector2.DOWN.angle()

func _physics_process(delta: float) -> void:
	# 1. Leitura de movimento em X e Y (funciona com Setas E com WASD)
	var dir_x: float = Input.get_axis("ui_left", "ui_right")
	var dir_y: float = Input.get_axis("ui_up", "ui_down")

	if Input.is_physical_key_pressed(KEY_A): dir_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir_x += 1.0
	if Input.is_physical_key_pressed(KEY_W): dir_y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir_y += 1.0

	var dir: Vector2 = Vector2(dir_x, dir_y).limit_length(1.0)

	# 2. Aplica velocidade e gira a área de interação para frente do movimento
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * velocidade, aceleracao * delta)
		ultima_direcao = dir.normalized()
		if area_interacao != null:
			area_interacao.rotation = ultima_direcao.angle()
		if dir.x != 0:
			sprite.flip_h = dir.x < 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, atrito * delta)

	move_and_slide()
	_atualizar_animacao(dir != Vector2.ZERO)
	_verificar_espaco()

func _verificar_espaco() -> void:
	var espaco_agora: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if espaco_agora and not _espaco_antes:
		# Primeiro tenta despejar tudo se estiver na frente de uma lixeira
		if not _tentar_despejar_na_lixeira():
			# Caso contrário, tenta pegar um material reciclável da esteira
			_tentar_pegar_material()
	_espaco_antes = espaco_agora

func _tentar_pegar_material() -> void:
	if _total_itens_mochila() >= limite_mochila:
		return

	var alvos: Array[Node2D] = []
	alvos.append_array(area_interacao.get_overlapping_bodies())
	alvos.append_array(area_interacao.get_overlapping_areas())

	for alvo in alvos:
		if alvo.is_in_group("reciclavel"):
			var tipo: String = alvo.get("tipo_material")
			inventario[tipo] = inventario.get(tipo, 0) + 1
			alvo.queue_free()
			
			if sprite.sprite_frames.has_animation("pick"):
				sprite.play("pick")
				animacao_atual = "pick"
				
			inventario_atualizado.emit(inventario)
			return

func _tentar_despejar_na_lixeira() -> bool:
	for area in area_interacao.get_overlapping_areas():
		if area.is_in_group("lixeira") and area.has_method("receber_despejo"):
			var tipo_lixeira: String = area.get("tipo_aceito")
			var qtd_na_mochila: int = inventario.get(tipo_lixeira, 0)
			
			if qtd_na_mochila > 0:
				# Despeja toda a quantidade daquela categoria de uma vez
				inventario.erase(tipo_lixeira)
				area.receber_despejo(tipo_lixeira, qtd_na_mochila, true)
				inventario_atualizado.emit(inventario)
				return true
			elif not inventario.is_empty():
				# Penaliza 1 item errado se apertar Espaço na lixeira errada sem ter o material dela
				var primeiro_errado: String = inventario.keys()[0]
				inventario[primeiro_errado] -= 1
				if inventario[primeiro_errado] <= 0:
					inventario.erase(primeiro_errado)
				area.receber_despejo(primeiro_errado, 1, false)
				inventario_atualizado.emit(inventario)
				return true
	return false

func _total_itens_mochila() -> int:
	var soma: int = 0
	for qtd in inventario.values():
		soma += qtd
	return soma

func _atualizar_animacao(andando: bool) -> void:
	if animacao_atual == "pick" and sprite.is_playing():
		return
	var prox: String = "walk" if andando else "idle"
	if animacao_atual != prox and sprite.sprite_frames.has_animation(prox):
		animacao_atual = prox
		sprite.play(prox)
