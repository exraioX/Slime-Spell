extends CharacterBody2D

signal inventario_atualizado(inventario: Dictionary)

@export var velocidade: float = 260.0
@export var aceleracao: float = 1800.0
@export var atrito: float = 1600.0
@export var limite_mochila: int = 10
@export var intervalo_coleta: float = 0.5

@export_group("Áudios da Lixeira")
@export var som_acerto: AudioStream
@export var som_erro: AudioStream

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_interacao: Area2D = $AreaInteracao

var inventario: Dictionary = {}
var ultima_direcao: Vector2 = Vector2.DOWN
var animacao_atual: String = ""
var _espaco_antes: bool = false
var _pode_pegar: bool = true
var _player_som: AudioStreamPlayer

func _ready() -> void:
	# Garante que o CharacterBody2D use visão top-down (não trava no chão como plataforma)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	if area_interacao != null:
		area_interacao.rotation = Vector2.DOWN.angle()
		
	# Cria o reprodutor de som automaticamente por código
	_player_som = AudioStreamPlayer.new()
	add_child(_player_som)

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
	if not _pode_pegar or _total_itens_mochila() >= limite_mochila:
		return

	var alvos: Array[Node2D] = []
	alvos.append_array(area_interacao.get_overlapping_bodies())
	alvos.append_array(area_interacao.get_overlapping_areas())

	var alvo_reciclavel: Node2D = null
	for alvo in alvos:
		if is_instance_valid(alvo) and alvo.is_in_group("reciclavel"):
			alvo_reciclavel = alvo
			break

	if alvo_reciclavel == null:
		return

	_pode_pegar = false
	var alvo: Node2D = alvo_reciclavel

	# 1. Toca a animação de pick (sem esperar terminar)
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("pick"):
		sprite.play("pick")
		animacao_atual = "pick"

	# 2. Coleta o item imediatamente, ignorando a animação de pick
	if is_instance_valid(alvo) and alvo.is_in_group("reciclavel"):
		var tipo: String = str(alvo.get("tipo_material"))
		inventario[tipo] = inventario.get(tipo, 0) + 1
		alvo.queue_free()
		inventario_atualizado.emit(inventario)

	# 3. Aguarda o intervalo antes de liberar uma nova coleta
	await get_tree().create_timer(intervalo_coleta).timeout
	_pode_pegar = true

func _lixeira_mais_proxima() -> Area2D:
	var melhor: Area2D = null
	var melhor_dist: float = INF
	for area in area_interacao.get_overlapping_areas():
		if area.is_in_group("lixeira") and area.has_method("receber_despejo"):
			var d: float = global_position.distance_to(area.global_position)
			if d < melhor_dist:
				melhor_dist = d
				melhor = area
	return melhor

func _tentar_despejar_na_lixeira() -> bool:
	var area: Area2D = _lixeira_mais_proxima()
	if area == null:
		return false
	if not area_interacao.overlaps_area(area):
		return false

	var tipo_lixeira: String = str(area.get("tipo_aceito"))
	var qtd_na_mochila: int = inventario.get(tipo_lixeira, 0)

	if qtd_na_mochila > 0:
		inventario.erase(tipo_lixeira)
		area.receber_despejo(tipo_lixeira, qtd_na_mochila, true)
		inventario_atualizado.emit(inventario)
		return true
	elif not inventario.is_empty():
		var primeiro_errado: String = str(inventario.keys()[0])
		var qtd_errada: int = int(inventario[primeiro_errado])
		inventario.erase(primeiro_errado)
		area.receber_despejo(primeiro_errado, qtd_errada, false)
		inventario_atualizado.emit(inventario)
		return true
	return false

func _tocar_som(audio: AudioStream) -> void:
	if audio != null and _player_som != null:
		_player_som.stream = audio
		_player_som.play()

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
