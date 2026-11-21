extends Node2D
## Minigame de coleta seletiva: arraste cada objeto para o destino correto.

const LARGURA := 1920.0
const ALTURA := 1080.0
const ESTEIRA := Rect2(700.0, 170.0, 520.0, 800.0)
const TAM_ITEM := Vector2(108.0, 108.0)
const TAM_LIXEIRA := Vector2(300.0, 270.0)
const META_POR_FASE := [8, 10, 12, 14, 16]
const VELOCIDADES := [145.0, 190.0, 240.0, 300.0, 365.0]
const INTERVALOS := [1.50, 1.28, 1.08, 0.90, 0.75]
const QUANTIDADE_POR_FASE := [12, 15, 18, 21, 24]
const COR_RECICLAVEL := Color("42b96b")
const COR_REJEITO := Color("d75a54")

const SPRITES_OBJETOS := [
	"res://lixos/1000074172.png", "res://lixos/1000074176.png",
	"res://lixos/1000074177.png", "res://lixos/1000075968.png",
	"res://lixos/1000075969.png", "res://lixos/1000075976.png",
	"res://lixos/1000075977.png", "res://lixos/1000075978.png",
	"res://lixos/1000075982.png", "res://lixos/1000075983.png",
	"res://lixos/1000075984.png", "res://lixos/1000075985.png",
	"res://lixos/1000076003.png", "res://lixos/1000076004.png",
	"res://lixos/1000076005.png", "res://lixos/1000076006.png"
]
const SPRITES_LIXEIRAS := [
	"res://lixeiras-sprites/1000073979.png",
	"res://lixeiras-sprites/1000073980.png"
]

enum Estado { MENU, JOGANDO, PAUSADO, FASE_CONCLUIDA, GAME_OVER, VITORIA }

var estado: Estado = Estado.MENU
var fase: int = 0
var pontos: int = 0
var vidas: int = 3
var acertos_fase: int = 0
var gerados_fase: int = 0
var tempo_spawn: float = 0.7
var tempo_animacao: float = 0.0
var itens: Array[Dictionary] = []
var item_arrastado: Dictionary = {}
var texturas_objetos: Array[Texture2D] = []
var textura_reciclavel: Texture2D
var textura_rejeito: Texture2D
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	for caminho in SPRITES_OBJETOS:
		var textura := load(caminho) as Texture2D
		if textura != null:
			texturas_objetos.append(textura)
	if SPRITES_LIXEIRAS.size() >= 2:
		textura_reciclavel = load(SPRITES_LIXEIRAS[0]) as Texture2D
		textura_rejeito = load(SPRITES_LIXEIRAS[1]) as Texture2D
	randomize()
	queue_redraw()


func _process(delta: float) -> void:
	tempo_animacao += delta
	if estado == Estado.JOGANDO:
		_atualizar_jogo(delta)
	queue_redraw()


func _atualizar_jogo(delta: float) -> void:
	var indice: int = clampi(fase - 1, 0, VELOCIDADES.size() - 1)
	tempo_spawn -= delta
	if tempo_spawn <= 0.0 and gerados_fase < QUANTIDADE_POR_FASE[indice]:
		tempo_spawn = INTERVALOS[indice]
		_criar_item()

	for i in range(itens.size() - 1, -1, -1):
		var item: Dictionary = itens[i]
		if item == item_arrastado:
			continue
		item["pos"].y += VELOCIDADES[indice] * delta
		if item["pos"].y > ALTURA - 115.0:
			itens.remove_at(i)
			_perder_vida()
			if estado != Estado.JOGANDO:
				return

	if gerados_fase >= QUANTIDADE_POR_FASE[indice] and itens.is_empty():
		_encerrar_fase()


func _criar_item() -> void:
	if texturas_objetos.is_empty():
		return
	var textura: Texture2D = texturas_objetos[randi() % texturas_objetos.size()]
	var reciclavel := randf() < 0.5
	var x := randf_range(ESTEIRA.position.x + 65.0, ESTEIRA.end.x - 65.0)
	itens.append({
		"pos": Vector2(x, ESTEIRA.position.y + 55.0),
		"texture": textura,
		"recyclable": reciclavel,
		"scale": randf_range(0.85, 1.0),
		"rotation": randf_range(-0.15, 0.15)
	})
	gerados_fase += 1


func _perder_vida() -> void:
	vidas -= 1
	if vidas <= 0:
		estado = Estado.GAME_OVER


func _encerrar_fase() -> void:
	if acertos_fase < META_POR_FASE[fase - 1]:
		estado = Estado.GAME_OVER
	elif fase >= 5:
		estado = Estado.VITORIA
	else:
		estado = Estado.FASE_CONCLUIDA


func _iniciar_fase(numero: int) -> void:
	fase = clampi(numero, 1, 5)
	vidas = 3
	acertos_fase = 0
	gerados_fase = 0
	tempo_spawn = 0.75
	itens.clear()
	item_arrastado = {}
	estado = Estado.JOGANDO


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if estado == Estado.JOGANDO:
			estado = Estado.PAUSADO
		elif estado == Estado.PAUSADO:
			estado = Estado.JOGANDO
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := _pos_mouse()
		if event.pressed:
			_ao_clicar(pos)
		else:
			_ao_soltar(pos)
	elif event is InputEventMouseMotion and not item_arrastado.is_empty():
		item_arrastado["pos"] = _pos_mouse()
	elif event is InputEventScreenTouch:
		var pos_toque := _pos_toque(event.position)
		if event.pressed:
			_ao_clicar(pos_toque)
		else:
			_ao_soltar(pos_toque)
	elif event is InputEventScreenDrag and not item_arrastado.is_empty():
		item_arrastado["pos"] = _pos_toque(event.position)


func _pos_mouse() -> Vector2:
	return get_global_mouse_position()


func _pos_toque(pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * pos


func _ao_clicar(pos: Vector2) -> void:
	match estado:
		Estado.MENU, Estado.GAME_OVER, Estado.VITORIA:
			_iniciar_fase(1)
		Estado.FASE_CONCLUIDA:
			_iniciar_fase(fase + 1)
		Estado.PAUSADO:
			estado = Estado.JOGANDO
		Estado.JOGANDO:
			for i in range(itens.size() - 1, -1, -1):
				var item: Dictionary = itens[i]
				var centro: Vector2 = item["pos"]
				if Rect2(centro - TAM_ITEM * 0.5, TAM_ITEM).has_point(pos):
					item_arrastado = item
					break


func _ao_soltar(pos: Vector2) -> void:
	if item_arrastado.is_empty():
		return
	var item := item_arrastado
	item_arrastado = {}
	var destino_reciclavel := Rect2(70.0, 665.0, 380.0, 350.0).has_point(pos)
	var destino_rejeito := Rect2(1470.0, 665.0, 380.0, 350.0).has_point(pos)
	if not destino_reciclavel and not destino_rejeito:
		return

	var correto: bool = bool(item["recyclable"]) == destino_reciclavel
	itens.erase(item)
	if correto:
		acertos_fase += 1
		pontos += 10 + fase * 2
	else:
		_perder_vida()
	if estado == Estado.JOGANDO and gerados_fase >= QUANTIDADE_POR_FASE[fase - 1] and itens.is_empty():
		_encerrar_fase()


func _draw() -> void:
	_desenhar_fundo()
	_desenhar_titulo()
	_desenhar_esteira()
	_desenhar_lixeira(Vector2(260, 825), textura_reciclavel, COR_RECICLAVEL, "RECICLÁVEL", "✓")
	_desenhar_lixeira(Vector2(1660, 825), textura_rejeito, COR_REJEITO, "NÃO RECICLÁVEL", "×")
	for item in itens:
		_desenhar_item(item)
	_desenhar_hud()
	if estado != Estado.JOGANDO:
		_desenhar_painel_estado()


func _desenhar_fundo() -> void:
	draw_rect(Rect2(0, 0, LARGURA, ALTURA), Color("173b38"))
	for i in range(12):
		var x := float(i) * 190.0
		draw_circle(Vector2(x + 35.0, 150.0), 95.0, Color(0.25, 0.55, 0.43, 0.16))
	draw_rect(Rect2(0, 990, LARGURA, 90), Color("102b2a"))


func _desenhar_titulo() -> void:
	_desenhar_texto("MISSÃO RECICLAGEM", Vector2(0, 34), 52, Color("e8f4d0"), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
	_desenhar_texto("Arraste cada objeto para a lixeira correta", Vector2(0, 100), 27, Color("b9d8bd"), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_esteira() -> void:
	draw_rect(ESTEIRA, Color("344943"))
	draw_rect(ESTEIRA, Color("91a78c"), false, 8.0)
	var y := ESTEIRA.position.y + fmod(tempo_animacao * 105.0, 100.0)
	while y < ESTEIRA.end.y:
		draw_rect(Rect2(ESTEIRA.position.x + 18, y, ESTEIRA.size.x - 36, 5), Color(0.75, 0.85, 0.70, 0.35))
		y += 100.0


func _desenhar_lixeira(centro: Vector2, textura: Texture2D, cor: Color, rotulo: String, simbolo: String) -> void:
	var ret := Rect2(centro - TAM_LIXEIRA * 0.5, TAM_LIXEIRA)
	if textura != null:
		draw_texture_rect(textura, ret, false)
	else:
		draw_rect(ret, cor)
		draw_rect(ret, cor.darkened(0.35), false, 8.0)
	draw_rect(Rect2(centro.x - 155, centro.y + 65, 310, 72), Color(0.04, 0.12, 0.10, 0.88))
	_desenhar_texto(simbolo + "  " + rotulo, Vector2(centro.x - 160, centro.y + 80), 24, Color.WHITE, 320, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_item(item: Dictionary) -> void:
	var centro: Vector2 = item["pos"]
	var tamanho: Vector2 = TAM_ITEM * float(item["scale"])
	var ret := Rect2(centro - tamanho * 0.5, tamanho)
	draw_circle(centro + Vector2(0, 52), 43, Color(0, 0, 0, 0.23))
	draw_rect(Rect2(ret.position - Vector2(8, 8), ret.size + Vector2(16, 16)), Color("f0ead4"))
	var textura: Texture2D = item["texture"]
	draw_set_transform(centro, float(item["rotation"]), Vector2.ONE)
	draw_texture_rect(textura, Rect2(-tamanho * 0.5, tamanho), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cor_categoria: Color = COR_RECICLAVEL if item["recyclable"] else COR_REJEITO
	draw_circle(centro + Vector2(43, -43), 18, cor_categoria)
	draw_circle(centro + Vector2(43, -43), 18, Color.WHITE, false, 3.0)


func _desenhar_hud() -> void:
	draw_rect(Rect2(35, 155, 360, 130), Color(0.04, 0.12, 0.10, 0.70))
	_desenhar_texto("FASE %d / 5" % fase, Vector2(55, 165), 32, Color("f4d46b"), 330)
	_desenhar_texto("PONTOS  %d" % pontos, Vector2(55, 208), 26, Color.WHITE, 330)
	_desenhar_texto("ACERTOS  %d / %d" % [acertos_fase, META_POR_FASE[maxi(fase - 1, 0)]], Vector2(55, 247), 22, Color("d5ead0"), 330)
	_desenhar_texto("VIDAS  " + "♥ ".repeat(vidas), Vector2(1500, 170), 34, Color("ff8274"), 360, HORIZONTAL_ALIGNMENT_RIGHT)


func _desenhar_painel_estado() -> void:
	draw_rect(Rect2(0, 0, LARGURA, ALTURA), Color(0, 0, 0, 0.68))
	var titulo := ""
	var subtitulo := ""
	match estado:
		Estado.MENU:
			titulo = "RECICLAGEM EM AÇÃO"
			subtitulo = "Arraste os resíduos para RECICLÁVEL ou NÃO RECICLÁVEL\nClique ou toque para começar"
		Estado.PAUSADO:
			titulo = "JOGO PAUSADO"
			subtitulo = "Clique ou pressione Esc para continuar"
		Estado.FASE_CONCLUIDA:
			titulo = "FASE %d CONCLUÍDA!" % fase
			subtitulo = "Mandou bem! Clique para avançar para a fase %d" % (fase + 1)
		Estado.GAME_OVER:
			titulo = "FIM DE JOGO"
			subtitulo = "Você fez %d pontos. Clique para tentar novamente." % pontos
		Estado.VITORIA:
			titulo = "VOCÊ SALVOU O PLANETA!"
			subtitulo = "Completou os 5 níveis com %d pontos. Clique para jogar de novo." % pontos
	draw_rect(Rect2(340, 330, 1240, 390), Color("183c37"))
	draw_rect(Rect2(340, 330, 1240, 390), Color("9acb85"), false, 5.0)
	_desenhar_texto(titulo, Vector2(390, 405), 54, Color("f4d46b"), 1140, HORIZONTAL_ALIGNMENT_CENTER)
	_desenhar_texto(subtitulo, Vector2(430, 515), 30, Color.WHITE, 1060, HORIZONTAL_ALIGNMENT_CENTER)
	_desenhar_texto("CLIQUE / TOQUE PARA CONTINUAR", Vector2(430, 650), 22, Color("b9d8bd"), 1060, HORIZONTAL_ALIGNMENT_CENTER)


func _desenhar_texto(texto: String, pos: Vector2, tamanho: int, cor: Color, largura: float, alinhamento: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if _font == null:
		return
	draw_string(_font, pos, texto, alinhamento, largura, tamanho, cor)
