extends Node2D

@export_group("Cenas e Transição")
@export var cena_material: PackedScene = preload("res://minigames/minigame-seleta/Cenas/material_reciclavel.tscn")
@export_file("*.tscn") var cena_mundo_principal: String = "res://Cenas/principal.tscn"

@export_group("Regras das Fases")
@export var total_fases: int = 3
@export var pedidos_por_fase: int = 3

@onready var spell: CharacterBody2D = $spell
@onready var ponto_spawn: Marker2D = $PontoSpawnEsteira
@onready var timer_spawn: Timer = $Esteira/TimerSpawn
@onready var label_pedidos: Label = $HUD/LabelPedidos
@onready var label_tempo: Label = $HUD/LabelTempo
@onready var box_inventario: HBoxContainer = $HUD/InventarioVisual

const PASTA_BASE: String = "res://lixos/lixos-minigame/"
const NOMES_BONITOS: Dictionary = {
	"plastico": "Plástico",
	"papel": "Papel",
	"metal": "Metal",
	"vidro": "Vidro"
}

var _banco_texturas: Dictionary = {
	"plastico": [],
	"papel": [],
	"metal": [],
	"vidro": []
}

var fase_atual: int = 1
var pedidos_concluidos_na_fase: int = 0
var pedidos_restantes: Dictionary = {}
var pontuacao_total: int = 0

var tempo_restante: float = 120.0
var velocidade_esteira_atual: float = 180.0
var pausado_entre_fases: bool = false
var jogo_finalizado: bool = false

func _ready() -> void:
	_carregar_texturas_das_pastas()
	_conectar_todas_lixeiras()
	
	if spell != null and spell.has_signal("inventario_atualizado"):
		spell.inventario_atualizado.connect(_atualizar_hud_inventario)

	timer_spawn.timeout.connect(_gerar_material)
	_iniciar_fase(1)

func _conectar_todas_lixeiras() -> void:
	# Busca tanto pelo grupo quanto percorrendo os filhos de "Lixeiras" para nunca falhar
	var candidatas: Array[Node] = []
	candidatas.append_array(get_tree().get_nodes_in_group("lixeira"))
	if has_node("Lixeiras"):
		candidatas.append_array($Lixeiras.get_children())

	for no in candidatas:
		if no.has_signal("material_despejado"):
			if not no.material_despejado.is_connected(_ao_despejar_na_lixeira):
				no.material_despejado.connect(_ao_despejar_na_lixeira)

func _iniciar_fase(numero_fase: int) -> void:
	fase_atual = numero_fase
	pedidos_concluidos_na_fase = 0
	pausado_entre_fases = false

	# Dificuldade progressiva a cada fase
	match fase_atual:
		1:
			tempo_restante = 120.0
			velocidade_esteira_atual = 180.0
			timer_spawn.wait_time = 1.8
		2:
			tempo_restante = 110.0
			velocidade_esteira_atual = 240.0
			timer_spawn.wait_time = 1.4
		_:
			tempo_restante = 100.0
			velocidade_esteira_atual = 310.0
			timer_spawn.wait_time = 1.1

	_sortear_novo_pedido()
	_atualizar_hud_pedidos()
	timer_spawn.start()
	_gerar_material()

func _process(delta: float) -> void:
	if jogo_finalizado or pausado_entre_fases:
		return

	tempo_restante -= delta
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		_encerrar_por_tempo()

	var minutos: int = int(tempo_restante) / 60
	var segundos: int = int(tempo_restante) % 60
	if label_tempo != null:
		label_tempo.text = "Fase %d/%d | Tempo: %02d:%02d | Pts: %d" % [
			fase_atual, total_fases, minutos, segundos, pontuacao_total
		]

func _sortear_novo_pedido() -> void:
	pedidos_restantes.clear()
	var categorias: Array = ["plastico", "papel", "metal", "vidro"]
	categorias.shuffle()
	
	# Quantidade aumenta progressivamente conforme a fase
	var min_qtd: int = 1 + fase_atual
	var max_qtd: int = 3 + fase_atual
	
	for i in range(2):
		var cat: String = categorias[i]
		pedidos_restantes[cat] = randi_range(min_qtd, max_qtd)

func _carregar_texturas_das_pastas() -> void:
	for categoria in _banco_texturas.keys():
		var caminho_pasta: String = PASTA_BASE + categoria
		var dir := DirAccess.open(caminho_pasta)
		if dir != null:
			dir.list_dir_begin()
			var arquivo: String = dir.get_next()
			while arquivo != "":
				if not dir.current_is_dir() and not arquivo.ends_with(".import"):
					var tex = load(caminho_pasta + "/" + arquivo)
					if tex is Texture2D:
						_banco_texturas[categoria].append(tex)
				arquivo = dir.get_next()

func _gerar_material() -> void:
	if jogo_finalizado or pausado_entre_fases or cena_material == null:
		return

	var pendentes: Array = []
	for cat in pedidos_restantes.keys():
		if pedidos_restantes[cat] > 0:
			pendentes.append(cat)

	var tipo_sorteado: String = ""
	if not pendentes.is_empty() and randf() < 0.75:
		tipo_sorteado = pendentes.pick_random()
	else:
		tipo_sorteado = _banco_texturas.keys().pick_random()

	var lista_tex: Array = _banco_texturas[tipo_sorteado]
	var textura_sorteada: Texture2D = lista_tex.pick_random() if not lista_tex.is_empty() else null

	var novo_item = cena_material.instantiate()
	add_child(novo_item)
	novo_item.global_position = ponto_spawn.global_position
	novo_item.configurar(tipo_sorteado, textura_sorteada, velocidade_esteira_atual)

func _ao_despejar_na_lixeira(acertou: bool, tipo_lixeira: String, quantidade: int) -> void:
	if jogo_finalizado or pausado_entre_fases:
		return

	if acertou:
		pontuacao_total += quantidade * 50
		if pedidos_restantes.has(tipo_lixeira) and pedidos_restantes[tipo_lixeira] > 0:
			pedidos_restantes[tipo_lixeira] = max(0, pedidos_restantes[tipo_lixeira] - quantidade)
		_atualizar_hud_pedidos()
		_verificar_pedido_completo()
	else:
		pontuacao_total = max(0, pontuacao_total - 25)
		tempo_restante = maxf(0.0, tempo_restante - 5.0)

func _verificar_pedido_completo() -> void:
	for cat in pedidos_restantes.keys():
		if pedidos_restantes[cat] > 0:
			return

	# Completou o pedido atual!
	pedidos_concluidos_na_fase += 1
	pontuacao_total += 150 * fase_atual

	_aplicar_melhoria()

	if pedidos_concluidos_na_fase < pedidos_por_fase:
		_sortear_novo_pedido()
		_atualizar_hud_pedidos()
	else:
		_concluir_fase_atual()

func _aplicar_melhoria() -> void:
	# +velocidade e +vel. de coleta a cada pedido
	velocidade_esteira_atual += 30.0
	timer_spawn.wait_time = max(0.6, timer_spawn.wait_time - 0.1)
	if spell != null:
		spell.velocidade += 20.0
		spell.intervalo_coleta = max(0.15, spell.intervalo_coleta - 0.05)
	_mostrar_melhoria("+velocidade\n+vel. de coleta")

func _mostrar_melhoria(texto: String) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 28)
	label.modulate = Color(0.2, 1.0, 0.2, 1.0)
	label.position = Vector2(get_viewport_rect().size.x / 2.0 - 80.0, get_viewport_rect().size.y / 2.0 - 40.0)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)

func _concluir_fase_atual() -> void:
	pausado_entre_fases = true
	timer_spawn.stop()
	
	# Limpa os materiais que sobraram na esteira
	for item in get_tree().get_nodes_in_group("reciclavel"):
		item.queue_free()

	# Bônus pelo tempo restante
	var bonus_tempo: int = int(tempo_restante) * 5
	pontuacao_total += bonus_tempo

	if fase_atual < total_fases:
		if label_pedidos != null:
			label_pedidos.text = "FASE %d CONCLUÍDA!\nBônus de tempo: +%d\nPontuação: %d pts\nPreparando Fase %d..." % [
				fase_atual, bonus_tempo, pontuacao_total, fase_atual + 1
			]
		await get_tree().create_timer(3.5).timeout
		_iniciar_fase(fase_atual + 1)
	else:
		jogo_finalizado = true
		if label_pedidos != null:
			label_pedidos.text = "PARABÉNS! VOCÊ PASSOU!\nPontuação Final: %d pts\nVoltando ao mapa..." % pontuacao_total
		await get_tree().create_timer(4.0).timeout
		_voltar_mundo_principal()

func _encerrar_por_tempo() -> void:
	jogo_finalizado = true
	timer_spawn.stop()
	if label_pedidos != null:
		label_pedidos.text = "TEMPO ESGOTADO!\nPontuação: %d pts\nTentando novamente..." % pontuacao_total
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func _voltar_mundo_principal() -> void:
	if cena_mundo_principal != "" and ResourceLoader.exists(cena_mundo_principal):
		await Jogo.trocar_cena(cena_mundo_principal, false)

func _atualizar_hud_inventario(inventario_atual: Dictionary) -> void:
	if box_inventario == null:
		return

	for filho in box_inventario.get_children():
		filho.queue_free()

	for tipo in inventario_atual.keys():
		var qtd: int = inventario_atual[tipo]
		if qtd <= 0:
			continue

		var slot := HBoxContainer.new()
		var icone := TextureRect.new()
		var lista_tex: Array = _banco_texturas.get(tipo, [])
		if not lista_tex.is_empty():
			icone.texture = lista_tex[0]
		icone.custom_minimum_size = Vector2(48, 48)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var texto_qtd := Label.new()
		texto_qtd.text = "%s x%d" % [NOMES_BONITOS.get(tipo, tipo), qtd]
		texto_qtd.add_theme_font_size_override("font_size", 22)

		slot.add_child(icone)
		slot.add_child(texto_qtd)
		box_inventario.add_child(slot)

func _atualizar_hud_pedidos() -> void:
	if label_pedidos == null:
		return
	var linhas: Array[String] = ["Pedido (%d/%d):" % [pedidos_concluidos_na_fase + 1, pedidos_por_fase]]
	for cat in pedidos_restantes.keys():
		var nome_exibicao: String = NOMES_BONITOS.get(cat, cat)
		var falta: int = pedidos_restantes[cat]
		linhas.append("- %s: faltam %d" % [nome_exibicao, falta] if falta > 0 else "- %s: OK!" % nome_exibicao)
	label_pedidos.text = "\n".join(linhas)
