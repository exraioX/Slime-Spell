class_name SnackBasketsGame
extends Node2D
## Orquestrador do minigame. Controla estados, validação da classificação,
## movimentação, pontuação e transições entre telas.
##
## A validação é centralizada AQUI (nunca no item), conforme a especificação.

enum Estado { MENU, JOGANDO, PAUSADO, GAME_OVER }

signal estado_mudou(novo: int)
signal jogo_encerrado(motivo: String, pontuacao: int, recorde: int, novo_recorde: bool)

const MOTIVO_ERRO := "erro_classificacao"
const MOTIVO_NAO_CLASSIFICADO := "objeto_nao_classificado"

@export var config: GameConfig
@export var catalogo: Array[ItemData] = []
## Cena para onde o botão SAIR retorna (o mapa do spell). Vazio = fecha o jogo.
@export_file("*.tscn") var cena_retorno: String = "res://Cenas/principal.tscn"

@onready var conveyor: Conveyor = $Conveyor
@onready var container: Node2D = $Itens
@onready var basket_esq: Basket = $Baskets/BasketLeft
@onready var basket_dir: Basket = $Baskets/BasketRight
@onready var spawner: ItemSpawner = $Spawner
@onready var input_mgr: InputManager = $InputManager
@onready var hud: GameHUD = $HUD
@onready var menu: MainMenu = $MainMenu
@onready var pause: PauseMenu = $PauseMenu
@onready var gameover: GameOver = $GameOver

var score: ScoreManager
var difficulty: DifficultyManager

var estado: int = Estado.MENU
var itens: Array[SortableItem] = []
var _novo_recorde: bool = false


func _ready() -> void:
	if config == null:
		config = GameConfig.new()
	if catalogo.is_empty():
		catalogo = _catalogo_padrao()

	score = ScoreManager.new()
	score.name = "ScoreManager"
	add_child(score)

	difficulty = DifficultyManager.new()
	difficulty.name = "DifficultyManager"
	add_child(difficulty)
	difficulty.configurar(config)

	conveyor.configurar(config)
	basket_esq.configurar(config, ItemData.CATEGORIA_COMIDA, true)
	basket_dir.configurar(config, ItemData.CATEGORIA_LIXO, false)
	spawner.configurar(config, catalogo, container, itens)

	input_mgr.sort_solicitado.connect(_on_sort)
	input_mgr.coletar_solicitado.connect(_on_collect)
	input_mgr.pausar_solicitado.connect(_on_pause)

	hud.ligar(score, config)

	menu.jogar_pressionado.connect(iniciar_jogo)
	menu.sair_pressionado.connect(_sair)
	pause.continuar_pressionado.connect(retomar)
	pause.reiniciar_pressionado.connect(iniciar_jogo)
	pause.menu_pressionado.connect(abrir_menu)
	gameover.tentar_novamente_pressionado.connect(iniciar_jogo)
	gameover.menu_pressionado.connect(abrir_menu)

	randomize()
	abrir_menu()


func _process(delta: float) -> void:
	if estado == Estado.JOGANDO:
		difficulty.atualizar(delta)
		spawner.definir_intervalo(difficulty.intervalo)
		spawner.atualizar(delta)
		conveyor.atualizar(delta, difficulty.velocidade)
		basket_esq.atualizar(delta)
		basket_dir.atualizar(delta)
		_atualizar_itens(delta)


# ============================ ESTADOS ============================

func abrir_menu() -> void:
	estado = Estado.MENU
	spawner.parar()
	_limpar_itens()
	score.resetar()
	difficulty.resetar()
	menu.mostrar(score.recorde)
	pause.esconder()
	gameover.esconder()
	hud.definir_visivel(false)
	estado_mudou.emit(estado)


func iniciar_jogo() -> void:
	_limpar_itens()
	score.resetar()
	difficulty.resetar()
	spawner.iniciar()
	menu.esconder()
	pause.esconder()
	gameover.esconder()
	hud.definir_visivel(true)
	estado = Estado.JOGANDO
	estado_mudou.emit(estado)


func pausar() -> void:
	if estado != Estado.JOGANDO:
		return
	estado = Estado.PAUSADO
	pause.mostrar()
	estado_mudou.emit(estado)


func retomar() -> void:
	if estado != Estado.PAUSADO:
		return
	estado = Estado.JOGANDO
	pause.esconder()
	estado_mudou.emit(estado)


func encerrar(motivo: String) -> void:
	if estado == Estado.GAME_OVER:
		return
	estado = Estado.GAME_OVER
	spawner.parar()
	_novo_recorde = score.finalizar()
	gameover.mostrar(score.pontuacao, score.recorde, motivo, _novo_recorde)
	hud.definir_visivel(false)
	jogo_encerrado.emit(motivo, score.pontuacao, score.recorde, _novo_recorde)
	estado_mudou.emit(estado)


func _sair() -> void:
	if cena_retorno != "":
		get_tree().change_scene_to_file(cena_retorno)
	else:
		get_tree().quit()


# ============================ ATUALIZAÇÃO DOS ITENS ============================

func _atualizar_itens(delta: float) -> void:
	var barreira_y: float = config.barreira_rect().position.y
	var pronto: SortableItem = _item_pronto()

	for it in itens:
		var si: SortableItem = it
		if si.estado != SortableItem.EstadoItem.CAINDO:
			continue
		si.velocidade = difficulty.velocidade
		si.descer(delta)

	# Remove itens que alcançaram a barreira sem classificação (derrota)
	for i in range(itens.size() - 1, -1, -1):
		var si2: SortableItem = itens[i]
		if si2.estado != SortableItem.EstadoItem.CAINDO:
			continue
		if si2.position.y >= barreira_y:
			conveyor.pulsar_barreira()
			encerrar(MOTIVO_NAO_CLASSIFICADO)
			return

	# Atualiza o destaque de "pronto"
	for it in itens:
		var si3: SortableItem = it
		si3.pronto = (si3 == pronto and si3.estado == SortableItem.EstadoItem.CAINDO)


## Primeiro objeto disponível na janela de decisão (o mais urgente).
func _item_pronto() -> SortableItem:
	var jan: Rect2 = config.janela_rect()
	var melhor: SortableItem = null
	var melhor_y: float = -INF
	for it in itens:
		var si: SortableItem = it
		if si.estado != SortableItem.EstadoItem.CAINDO:
			continue
		var y: float = si.position.y
		if y >= jan.position.y and y <= jan.position.y + jan.size.y:
			if y > melhor_y:
				melhor_y = y
				melhor = si
	return melhor


# ============================ ENTRADA ============================

func _on_sort(direcao: int) -> void:
	if estado != Estado.JOGANDO:
		return
	var it: SortableItem = _item_pronto()
	if it == null:
		return   # entrada sem objeto: ignorada

	var basket: Basket = basket_esq if direcao < 0 else basket_dir
	var acertou: bool = it.categoria == basket.categoria

	if acertou:
		var ganho: int = score.registrar_acerto(config.pontos_por_acerto, config.bonus_combo_por_nivel, config.combo_maximo)
		basket.brilhar()
		_criar_popup(it.position, "+%d" % ganho, Color("ffd700"))
		_remover_item(it)
		it.voar_para(Vector2(basket.position.x, basket.position.y + 30.0))
	else:
		it.ja_classificado = true
		_remover_item(it)
		it.voar_para(Vector2(basket.position.x, basket.position.y + 30.0))
		encerrar(MOTIVO_ERRO)


func _on_collect() -> void:
	if estado != Estado.JOGANDO:
		return
	var it: SortableItem = _item_pronto()
	if it == null or not it.especial:
		return   # nada especial disponível: entrada ignorada

	score.registrar_bonus(config.pontos_bonus_especial)
	_criar_popup(it.position, "+%d" % config.pontos_bonus_especial, Color("ffd700"))
	_remover_item(it)
	it.voar_para(Vector2(it.position.x, config.esteira_rect.position.y - 60.0))


func _on_pause() -> void:
	if estado == Estado.JOGANDO:
		pausar()
	elif estado == Estado.PAUSADO:
		retomar()


# ============================ UTILITÁRIOS ============================

func _remover_item(it: SortableItem) -> void:
	itens.erase(it)
	it.pronto = false


func _criar_popup(pos: Vector2, texto: String, cor: Color) -> void:
	var p := ScorePopup.new()
	p.texto = texto
	p.cor = cor
	p.position = pos
	container.add_child(p)


func _limpar_itens() -> void:
	itens.clear()
	for c in container.get_children():
		c.queue_free()


func _catalogo_padrao() -> Array[ItemData]:
	var arr: Array[ItemData] = []
	arr.append(_novo_item(&"maca", "Maçã", ItemData.CATEGORIA_COMIDA, Color("d94a3a"), 0, 10))
	arr.append(_novo_item(&"pao", "Pão", ItemData.CATEGORIA_COMIDA, Color("e6b463"), 1, 10))
	arr.append(_novo_item(&"queijo", "Queijo", ItemData.CATEGORIA_COMIDA, Color("f2d24b"), 0, 10))
	arr.append(_novo_item(&"lata", "Lata", ItemData.CATEGORIA_LIXO, Color("9aa4ad"), 0, 10))
	arr.append(_novo_item(&"garrafa", "Garrafa", ItemData.CATEGORIA_LIXO, Color("5fb3e6"), 1, 10))
	arr.append(_novo_item(&"papel", "Papel", ItemData.CATEGORIA_LIXO, Color("b9b3a3"), 0, 10))
	arr.append(_item_especial(&"doce", "Doce", Color("e46a9a")))
	return arr


func _novo_item(id: StringName, nome: String, cat: int, cor: Color, forma: int, pontos: int) -> ItemData:
	var d := ItemData.new()
	d.id = id
	d.nome = nome
	d.categoria = cat
	d.cor_placeholder = cor
	d.forma = forma
	d.pontuacao = pontos
	return d


func _item_especial(id: StringName, nome: String, cor: Color) -> ItemData:
	var d := ItemData.new()
	d.id = id
	d.nome = nome
	d.categoria = ItemData.CATEGORIA_COMIDA
	d.cor_placeholder = cor
	d.forma = 1
	d.especial = true
	d.pontuacao = 0
	return d
