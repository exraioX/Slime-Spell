extends Node2D

# =============================================================================
# CLASSIFICADOR RAPIDO  (esteira rolante)
# -----------------------------------------------------------------------------
# Jogo 2D feito APENAS com formas geometricas e cores solidas.
# Inspirado no minijogo "Separa-Compras" (My Talking Angela 2).
#
# COMO TROCAR AS FORMAS PELOS SEUS SPRITES:
#   Cada elemento tem uma funcao de desenho propria:
#       drawFundo, drawEsteira, drawLimite, drawPlacas, drawCestos,
#       drawItemAzul, drawItemAmarelo, drawHUD, drawVidas, drawEstrelas ...
#   Dentro de cada funcao existe o comentario ">>> TROQUE AQUI" indicando
#   exatamente o ponto onde a forma vira a sua imagem.
#
#   Alem disso, cada elemento tem um SLOT DE TEXTURA exportado (ex.: tex_esteira).
#   Se voce arrastar uma textura para o slot no Inspector, o desenho da forma e
#   substituido automaticamente pela sua imagem (veja _usar_textura()).
# =============================================================================


# =============================================================================
# CONFIGURACAO
# =============================================================================

@export_group("Slots de Sprite (opcional - arraste sua imagem aqui)")
# >>> TROQUE AQUI (slots): arraste seus PNGs para estes campos.
#     Sem textura, o jogo desenha a forma geometrica. Com textura, usa a imagem.
@export var tex_fundo: Texture2D
@export var tex_esteira: Texture2D
@export var tex_placa_azul: Texture2D
@export var tex_placa_amarela: Texture2D
@export var tex_cesto_azul: Texture2D
@export var tex_cesto_amarelo: Texture2D
@export var tex_item_azul: Texture2D
@export var tex_item_amarelo: Texture2D
@export var tex_estrela: Texture2D
@export var tex_hud: Texture2D
@export var tex_botao_pausa: Texture2D

@export_group("Regras")
@export var vidas_iniciais: int = 3            # coracoes no canto superior esquerdo
@export var game_over_imediato: bool = false   # true = erra 1 vez e acaba
@export var pontos_por_acerto: int = 10

@export_group("Vidas (visual)")
@export var coracoes_visiveis: bool = true


# =============================================================================
# CONSTANTES DE DESENHO
# =============================================================================

# Resolucao de projeto (retrato). Tudo e desenhado nesse espaco.
const TAM_DESENHO := Vector2(720, 1280)

# Cores solidas
const COR_LETTERBOX := Color("1b1b20")
const COR_FUNDO_A := Color("ded0ad")     # bege claro (piso quadriculado)
const COR_FUNDO_B := Color("c9b689")     # bege medio
const COR_ESTEIRA := Color("3c3c44")     # cinza escuro
const COR_ESTEIRA_LINHA := Color("8d8d97")  # cinza claro (linhas que descem)
const COR_ESTEIRA_BORDA := Color("26262c")
const COR_LIMITE := Color("d13b3b")      # barra vermelha (sensor de queda)
const COR_PLACA_AZUL := Color("2f6fd0")
const COR_PLACA_AMARELA := Color("e8b21e")
const COR_HASTE := Color("7a5230")       # marrom da haste
const COR_CESTO_AZUL := Color("2f6fd0")
const COR_CESTO_AMARELO := Color("e8b21e")
const COR_CESTO_FENDA := Color("2a2a2f")
const COR_HUD_ROXO := Color("6a3fb0")
const COR_HUD_BORDA := Color("d9b44a")   # dourado
const COR_TEXTO := Color("ffffff")
const COR_TEXTO_ESCURO := Color("2a2233")
const COR_BOTAO_ROSA := Color("e46a9a")
const COR_BOTAO_VERDE := Color("3fae5a")
const COR_VIDA := Color("e33b3b")
const COR_MODAL := Color(0, 0, 0, 0.62)
const COR_PAINEL := Color("2f2a3a")
const COR_PAINEL_BORDA := Color("d9b44a")
const COR_ESTRELA_VAZIA := Color("585862")
const COR_ESTRELA_CHEIA := Color("ffd21f")

# Cores dos itens por categoria
const CORES_AZUL: Array[Color] = [Color("5fb3e6"), Color("6fbf5a")]      # azul claro / verde
const CORES_AMARELO: Array[Color] = [Color("f08a2c"), Color("d94a3a")]   # laranja / vermelho

const CATEGORIA_AZUL := 0     # reciclavel / estragado  -> cesto azul (esquerda)
const CATEGORIA_AMARELO := 1  # alimento bom            -> cesto amarelo (direita)


# =============================================================================
# FASES (velocidade, spawn e metas de 1/2/3 estrelas)
# =============================================================================
# velocidade da esteira e intervalo de spawn aumentam a cada fase; dentro da
# propria fase a dificuldade cresce conforme a pontuacao (ver atualizar_jogo()).
const FASES: Array = [
	{"vel": 95.0,  "spawn": 1.15, "metas": [100, 200, 300],  "quota": 16},
	{"vel": 125.0, "spawn": 0.98, "metas": [200, 350, 500],  "quota": 20},
	{"vel": 155.0, "spawn": 0.84, "metas": [300, 500, 700],  "quota": 24},
	{"vel": 190.0, "spawn": 0.72, "metas": [400, 650, 900],  "quota": 28},
	{"vel": 225.0, "spawn": 0.60, "metas": [500, 800, 1100], "quota": 32},
]
const TOTAL_FASES := 5


# =============================================================================
# LAYOUT (coordenadas do projeto)
# =============================================================================

const CONV := Rect2(216, 150, 288, 950)          # esteira: 40% larg / 75% alt
const LIMITE_RECT := Rect2(CONV.position.x, CONV.position.y + CONV.size.y - 18, CONV.size.x, 18)
const LIMITE_Y := LIMITE_RECT.position.y

const CESTO_ESQ := Vector2(118, 1185)            # centro do cesto azul
const CESTO_DIR := Vector2(602, 1185)            # centro do cesto amarelo
const CESTO_LARG := 168.0
const CESTO_ALT := 96.0

const PLACA_ESQ := Vector2(108, 250)             # centro da placa azul
const PLACA_DIR := Vector2(612, 250)             # centro da placa amarela
const PLACA_TAM := 116.0

const HUD_CENTRO := Vector2(360, 82)
const HUD_RX := 176.0
const HUD_RY := 56.0

const BOTAO_PAUSA := Vector2(664, 54)
const BOTAO_PAUSA_R := 30.0

const ITEM_TAM := 54.0


# =============================================================================
# ESTADO
# =============================================================================

enum Estado { JOGANDO, FASE_CONCLUIDA, GAME_OVER, VITORIA }

var estado: int = Estado.JOGANDO
var pausado: bool = false

var fase_atual: int = 1
var pontuacao: int = 0
var vidas: int = 3
var itens_gerados: int = 0
var pontuacao_total: int = 0

var velocidade_atual: float = 0.0
var intervalo_atual: float = 1.0
var tempo_spawn: float = 0.0
var tempo_fase: float = 0.0
var offset_linhas: float = 0.0

var itens: Array = []
var item_arrastado: Item = null
var arraste_offset: Vector2 = Vector2.ZERO

var glow_esq: float = 0.0
var glow_dir: float = 0.0
var flash_erro: float = 0.0

# modal de fim de fase
var tempo_modal: float = 0.0
var estrelas_ganhas: int = 0
var pontos_exibidos: float = 0.0
var modal_fase: int = 1

var fonte: Font = null

@onready var camera: Camera2D = $Camera2D


# =============================================================================
# ITEM
# =============================================================================

class Item:
	const NA_ESTEIRA := 0
	const ARRASTANDO := 1
	const VOANDO := 2

	var categoria: int = 0
	var forma: int = 0            # 0 = quadrado, 1 = circulo
	var cor: Color = Color.WHITE
	var pos: Vector2 = Vector2.ZERO
	var tam: float = 54.0
	var estado: int = NA_ESTEIRA
	var x_origem: float = 0.0
	var alvo: Vector2 = Vector2.ZERO
	var rot: float = 0.0


# =============================================================================
# CICLO DE VIDA
# =============================================================================

func _ready() -> void:
	randomize()
	fonte = ThemeDB.fallback_font
	camera.make_current()
	ajustar_camera()
	get_viewport().size_changed.connect(ajustar_camera)
	iniciar_fase(1)


func ajustar_camera() -> void:
	if camera == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var esc: float = minf(vp.x / TAM_DESENHO.x, vp.y / TAM_DESENHO.y)
	camera.zoom = Vector2(esc, esc)
	camera.position = TAM_DESENHO * 0.5


func _process(delta: float) -> void:
	if estado == Estado.JOGANDO and not pausado:
		atualizar_jogo(delta)
	elif estado == Estado.FASE_CONCLUIDA:
		atualizar_modal(delta)

	queue_redraw()


# =============================================================================
# CONTROLE DE FASES
# =============================================================================

func iniciar_fase(fase: int) -> void:
	fase_atual = fase
	estado = Estado.JOGANDO
	pausado = false

	pontuacao = 0
	itens_gerados = 0
	itens.clear()
	item_arrastado = null
	tempo_fase = 0.0
	tempo_spawn = 0.6
	glow_esq = 0.0
	glow_dir = 0.0
	flash_erro = 0.0

	if game_over_imediato:
		vidas = 1
	else:
		vidas = vidas_iniciais


func dados_fase() -> Dictionary:
	return FASES[clampf(fase_atual - 1, 0, FASES.size() - 1)]


func meta_nivel(nivel: int) -> int:
	var metas: Array = dados_fase()["metas"]
	return int(metas[clampf(nivel - 1, 0, 2)])


func concluir_fase() -> void:
	estado = Estado.FASE_CONCLUIDA
	modal_fase = fase_atual
	tempo_modal = 0.0
	pontos_exibidos = 0.0

	if pontuacao >= meta_nivel(3):
		estrelas_ganhas = 3
	elif pontuacao >= meta_nivel(2):
		estrelas_ganhas = 2
	elif pontuacao >= meta_nivel(1):
		estrelas_ganhas = 1
	else:
		estrelas_ganhas = 0

	pontuacao_total += pontuacao


func terminar_jogo() -> void:
	estado = Estado.GAME_OVER
	tempo_modal = 0.0


# =============================================================================
# ATUALIZACAO
# =============================================================================

func atualizar_jogo(delta: float) -> void:
	tempo_fase += delta

	# Dificuldade dentro da propria fase: cresce ateh a meta maxima (Nivel 3).
	var progresso: float = clampf(float(pontuacao) / float(maxi(meta_nivel(3), 1)), 0.0, 1.0)
	var base: Dictionary = dados_fase()
	velocidade_atual = float(base["vel"]) * (1.0 + progresso * 0.25)
	intervalo_atual = float(base["spawn"]) * (1.0 - progresso * 0.35)

	offset_linhas = fmod(offset_linhas + velocidade_atual * delta, 48.0)

	# Spawner
	tempo_spawn -= delta
	if tempo_spawn <= 0.0:
		tempo_spawn = intervalo_atual
		gerar_item()

	# Itens
	var i: int = itens.size() - 1
	while i >= 0:
		var it: Item = itens[i]
		if it.estado == Item.NA_ESTEIRA:
			it.pos.y += velocidade_atual * delta
			if it.pos.y - it.tam * 0.5 > LIMITE_Y:
				erro_item_perdido()
				itens.remove_at(i)
		elif it.estado == Item.VOANDO:
			it.pos = it.pos.lerp(it.alvo, clampf(18.0 * delta, 0.0, 1.0))
			it.rot += 9.0 * delta
			if it.pos.distance_to(it.alvo) < 14.0:
				itens.remove_at(i)
		i -= 1

	glow_esq = maxf(glow_esq - delta, 0.0)
	glow_dir = maxf(glow_dir - delta, 0.0)
	flash_erro = maxf(flash_erro - delta, 0.0)

	# Fim da fase
	if pontuacao >= meta_nivel(3) or itens_gerados >= int(base["quota"]):
		concluir_fase()


func atualizar_modal(delta: float) -> void:
	tempo_modal += delta
	var alvo: float = float(pontuacao)
	pontos_exibidos = move_toward(pontos_exibidos, alvo, maxf(1.0, alvo * 4.0 * delta))


func gerar_item() -> void:
	var base: Dictionary = dados_fase()
	if itens_gerados >= int(base["quota"]):
		return

	var it := Item.new()
	it.categoria = randi() % 2
	it.forma = randi() % 2
	var paleta: Array = CORES_AZUL if it.categoria == CATEGORIA_AZUL else CORES_AMARELO
	it.cor = paleta[randi() % paleta.size()]
	it.tam = ITEM_TAM
	var margem: float = it.tam * 0.5 + 12.0
	it.pos = Vector2(
		randf_range(CONV.position.x + margem, CONV.position.x + CONV.size.x - margem),
		CONV.position.y + 12.0
	)
	itens.append(it)
	itens_gerados += 1


# =============================================================================
# REGRAS DE ACERTO / ERRO
# =============================================================================

func classificar(it: Item, lado: int) -> void:
	# lado: -1 = esquerda (cesto azul) | +1 = direita (cesto amarelo)
	var correto: bool = (it.categoria == CATEGORIA_AZUL and lado < 0) \
		or (it.categoria == CATEGORIA_AMARELO and lado > 0)

	var destino: Vector2 = CESTO_ESQ if lado < 0 else CESTO_DIR
	it.estado = Item.VOANDO
	it.alvo = destino
	it.x_origem = it.pos.x

	if correto:
		pontuacao += pontos_por_acerto
		if lado < 0:
			glow_esq = 0.35
		else:
			glow_dir = 0.35
	else:
		erro_item_errado()
		flash_erro = 0.4
		if lado < 0:
			glow_esq = 0.25
		else:
			glow_dir = 0.25


func erro_item_perdido() -> void:
	flash_erro = 0.5
	perder_vida()


func erro_item_errado() -> void:
	perder_vida()


func perder_vida() -> void:
	vidas -= 1
	if vidas <= 0:
		terminar_jogo()


# =============================================================================
# INPUT (drag & drop / swipe)
# =============================================================================
# Baseado em EVENTOS (nao em polling), para nao disparar cliques acidentais.
# O Godot emula mouse a partir do toque por padrao, entao o mesmo codigo
# atende mouse (PC) e toque (celular).

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = get_global_mouse_position()
		if event.pressed:
			ao_pressionar_geral(pos)
		else:
			ao_soltar_geral(pos)
	elif event is InputEventMouseMotion:
		if item_arrastado != null:
			item_arrastado.pos = get_global_mouse_position() + arraste_offset
	elif event is InputEventScreenTouch:
		var pos_t: Vector2 = _para_mundo(event.position)
		if event.pressed:
			ao_pressionar_geral(pos_t)
		else:
			ao_soltar_geral(pos_t)
	elif event is InputEventScreenDrag:
		if item_arrastado != null:
			item_arrastado.pos = _para_mundo(event.position) + arraste_offset


func _para_mundo(pos_viewport: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * pos_viewport


func ao_pressionar_geral(pos: Vector2) -> void:
	match estado:
		Estado.JOGANDO:
			if pausado:
				if not _rect_pausa().has_point(pos):
					pausado = false
			else:
				ao_pressionar(pos)
		Estado.FASE_CONCLUIDA:
			ao_clicar_modal(pos)
		Estado.GAME_OVER, Estado.VITORIA:
			if _rect_botao_modal().has_point(pos):
				iniciar_fase(1)


func ao_soltar_geral(pos: Vector2) -> void:
	if estado == Estado.JOGANDO and not pausado:
		ao_soltar(pos)


func ao_pressionar(pos: Vector2) -> void:
	if _rect_pausa().has_point(pos):
		pausado = true
		return

	var melhor: Item = null
	var melhor_y: float = -1.0
	for it in itens:
		var it2: Item = it
		if it2.estado != Item.NA_ESTEIRA:
			continue
		if _rect_item(it2).has_point(pos) and it2.pos.y > melhor_y:
			melhor = it2
			melhor_y = it2.pos.y

	if melhor != null:
		melhor.estado = Item.ARRASTANDO
		melhor.x_origem = melhor.pos.x
		item_arrastado = melhor
		arraste_offset = melhor.pos - pos


func ao_soltar(pos: Vector2) -> void:
	if item_arrastado == null:
		return

	var it: Item = item_arrastado
	item_arrastado = null

	var lado: int = 0
	if _rect_cesto(CESTO_ESQ).has_point(pos):
		lado = -1
	elif _rect_cesto(CESTO_DIR).has_point(pos):
		lado = 1
	else:
		var dx: float = pos.x - it.x_origem
		if dx < -44.0:
			lado = -1
		elif dx > 44.0:
			lado = 1

	if lado == 0:
		it.estado = Item.NA_ESTEIRA
	else:
		classificar(it, lado)


func ao_clicar_modal(pos: Vector2) -> void:
	if not _rect_botao_modal().has_point(pos):
		return
	if estrelas_ganhas <= 0:
		iniciar_fase(modal_fase)          # tentar de novo
	elif modal_fase < TOTAL_FASES:
		iniciar_fase(modal_fase + 1)      # proxima fase
	else:
		estado = Estado.VITORIA           # terminou a fase 5
		tempo_modal = 0.0


# =============================================================================
# AREAS (retangulos de clique)
# =============================================================================

func _rect_pausa() -> Rect2:
	return Rect2(BOTAO_PAUSA - Vector2(BOTAO_PAUSA_R, BOTAO_PAUSA_R),
		Vector2(BOTAO_PAUSA_R * 2.0, BOTAO_PAUSA_R * 2.0))


func _rect_item(it: Item) -> Rect2:
	return Rect2(it.pos - Vector2(it.tam, it.tam) * 0.5, Vector2(it.tam, it.tam))


func _rect_cesto(centro: Vector2) -> Rect2:
	return Rect2(centro - Vector2(CESTO_LARG, CESTO_ALT) * 0.5, Vector2(CESTO_LARG, CESTO_ALT))


func _rect_painel_modal() -> Rect2:
	return Rect2(90, 322, 540, 636)


func _rect_botao_modal() -> Rect2:
	return Rect2(210, 792, 300, 94)


# =============================================================================
# DESENHO PRINCIPAL
# =============================================================================

func _draw() -> void:
	drawFundo()
	drawEsteira()
	drawPlacas()
	drawCestos()
	drawItens()
	drawLimite()
	drawHUD()
	drawVidas()
	drawBotaoPausa()

	if pausado:
		drawPausa()
	elif estado == Estado.FASE_CONCLUIDA:
		drawModalFase()
	elif estado == Estado.GAME_OVER:
		drawGameOver()
	elif estado == Estado.VITORIA:
		drawVitoria()


# -----------------------------------------------------------------------------
# FUNDO (piso quadriculado bege)
# -----------------------------------------------------------------------------
func drawFundo() -> void:
	# >>> TROQUE AQUI (fundo): substitua o piso quadriculado por sua imagem.
	#     Com tex_fundo definido, o piso vira a textura (esticada na tela).
	draw_rect(Rect2(-4000, -4000, 9000, 9000), COR_LETTERBOX)  # barras laterais
	if tex_fundo != null:
		draw_texture_rect(tex_fundo, Rect2(Vector2.ZERO, TAM_DESENHO), false)
		return

	var celula: float = 64.0
	var cols: int = int(ceil(TAM_DESENHO.x / celula))
	var linhas: int = int(ceil(TAM_DESENHO.y / celula))
	for cy in range(linhas):
		for cx in range(cols):
			var cor: Color = COR_FUNDO_A if (cx + cy) % 2 == 0 else COR_FUNDO_B
			draw_rect(Rect2(cx * celula, cy * celula, celula, celula), cor)


# -----------------------------------------------------------------------------
# ESTEIRA ROLANTE
# -----------------------------------------------------------------------------
func drawEsteira() -> void:
	# >>> TROQUE AQUI (esteira): desenhe sua textura da esteira no lugar.
	if tex_esteira != null:
		draw_texture_rect(tex_esteira, CONV, false)
	else:
		draw_rect(CONV, COR_ESTEIRA)
		# linhas horizontais que descem (simulam o movimento)
		var y: float = CONV.position.y + offset_linhas
		while y < CONV.position.y + CONV.size.y:
			draw_rect(Rect2(CONV.position.x, y, CONV.size.x, 3.0), COR_ESTEIRA_LINHA)
			y += 48.0
	# borda inferior/superior
	draw_rect(Rect2(CONV.position.x, CONV.position.y, CONV.size.x, 6.0), COR_ESTEIRA_BORDA)
	draw_rect(Rect2(CONV.position.x, CONV.position.y, 6.0, CONV.size.y), COR_ESTEIRA_BORDA)
	draw_rect(Rect2(CONV.position.x + CONV.size.x - 6.0, CONV.position.y, 6.0, CONV.size.y), COR_ESTEIRA_BORDA)


# -----------------------------------------------------------------------------
# ZONA LIMITE (barra vermelha / sensor de queda)
# -----------------------------------------------------------------------------
func drawLimite() -> void:
	var cor: Color = COR_LIMITE
	if flash_erro > 0.0:
		cor = cor.lerp(Color.WHITE, flash_erro)
	draw_rect(LIMITE_RECT, cor)
	# listras
	var x: float = LIMITE_RECT.position.x
	while x < LIMITE_RECT.position.x + LIMITE_RECT.size.x:
		draw_rect(Rect2(x, LIMITE_RECT.position.y, 8.0, LIMITE_RECT.size.y), cor.darkened(0.25))
		x += 24.0


# -----------------------------------------------------------------------------
# PLACAS INDICADORAS (topo lateral, com haste marrom)
# -----------------------------------------------------------------------------
func drawPlacas() -> void:
	# haste esquerda
	draw_rect(Rect2(PLACA_ESQ.x - 8, PLACA_ESQ.y + PLACA_TAM * 0.5, 16, 150), COR_HASTE)
	# haste direita
	draw_rect(Rect2(PLACA_DIR.x - 8, PLACA_DIR.y + PLACA_TAM * 0.5, 16, 150), COR_HASTE)

	# placa azul (esquerda) -> reciclagem (triangulo branco)
	var ret_esq := Rect2(PLACA_ESQ - Vector2(PLACA_TAM, PLACA_TAM) * 0.5,
		Vector2(PLACA_TAM, PLACA_TAM))
	# >>> TROQUE AQUI (placa azul)
	if tex_placa_azul != null:
		draw_texture_rect(tex_placa_azul, ret_esq, false)
	else:
		draw_rect(ret_esq, COR_PLACA_AZUL)
		draw_rect(ret_esq, COR_PLACA_AZUL.darkened(0.3), false, 5.0)
		# simbolo: triangulo branco (reciclagem simplificada)
		var c: Vector2 = PLACA_ESQ
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -26), c + Vector2(24, 18), c + Vector2(-24, 18)
		]), Color.WHITE)

	# placa amarela (direita) -> carrinho de compras
	var ret_dir := Rect2(PLACA_DIR - Vector2(PLACA_TAM, PLACA_TAM) * 0.5,
		Vector2(PLACA_TAM, PLACA_TAM))
	# >>> TROQUE AQUI (placa amarela)
	if tex_placa_amarela != null:
		draw_texture_rect(tex_placa_amarela, ret_dir, false)
	else:
		draw_rect(ret_dir, COR_PLACA_AMARELA)
		draw_rect(ret_dir, COR_PLACA_AMARELA.darkened(0.3), false, 5.0)
		_desenhar_carrinho(PLACA_DIR, Color.WHITE)


func _desenhar_carrinho(c: Vector2, cor: Color) -> void:
	# carrinho de compras simples em formas
	draw_rect(Rect2(c.x - 22, c.y - 14, 40, 26), cor, false, 5.0)
	draw_line(c + Vector2(-26, -22), c + Vector2(-14, -22), cor, 5.0)
	draw_line(c + Vector2(-14, -22), c + Vector2(-8, -14), cor, 5.0)
	draw_circle(c + Vector2(-12, 18), 5.0, cor)
	draw_circle(c + Vector2(12, 18), 5.0, cor)


# -----------------------------------------------------------------------------
# CESTOS COLETORES
# -----------------------------------------------------------------------------
func drawCestos() -> void:
	draw_cesto(CESTO_ESQ, COR_CESTO_AZUL, tex_cesto_azul, glow_esq, false)
	draw_cesto(CESTO_DIR, COR_CESTO_AMARELO, tex_cesto_amarelo, glow_dir, true)


func draw_cesto(centro: Vector2, cor: Color, tex: Texture2D, glow: float, com_fendas: bool) -> void:
	var largura_top: float = CESTO_LARG * (1.0 + glow * 0.12)
	var altura: float = CESTO_ALT * (1.0 + glow * 0.12)
	var ret := Rect2(centro.x - largura_top * 0.5, centro.y - altura * 0.5, largura_top, altura)

	# brilho ao acertar
	if glow > 0.0:
		var brilho := Rect2(ret.position - Vector2(10, 10), ret.size + Vector2(20, 20))
		draw_rect(brilho, Color(1, 1, 1, glow * 0.55), false, 8.0)

	# >>> TROQUE AQUI (cesto): substitua o trapezio pela sua imagem do cesto.
	if tex != null:
		draw_texture_rect(tex, ret, false)
		return

	# trapezio (topo mais largo que a base)
	var pts := PackedVector2Array([
		Vector2(centro.x - largura_top * 0.5, centro.y - altura * 0.5),
		Vector2(centro.x + largura_top * 0.5, centro.y - altura * 0.5),
		Vector2(centro.x + CESTO_LARG * 0.36, centro.y + altura * 0.5),
		Vector2(centro.x - CESTO_LARG * 0.36, centro.y + altura * 0.5),
	])
	draw_colored_polygon(pts, cor)
	draw_rect(ret, cor.darkened(0.35), false, 5.0)

	# tres fendas verticais escuras (cesto amarelo / comida)
	if com_fendas:
		for k in range(-1, 2):
			var fx: float = centro.x + k * 34.0
			draw_rect(Rect2(fx - 5, centro.y - altura * 0.30, 10, altura * 0.60), COR_CESTO_FENDA)


# -----------------------------------------------------------------------------
# ITENS (placeholders coloridos)
# -----------------------------------------------------------------------------
func drawItens() -> void:
	for it in itens:
		var it2: Item = it
		if it2.categoria == CATEGORIA_AZUL:
			drawItemAzul(it2)
		else:
			drawItemAmarelo(it2)


func drawItemAzul(it: Item) -> void:
	_draw_item(it)


func drawItemAmarelo(it: Item) -> void:
	_draw_item(it)


func _draw_item(it: Item) -> void:
	# sombra simples
	draw_circle(it.pos + Vector2(0, it.tam * 0.42), it.tam * 0.34, Color(0, 0, 0, 0.18))
	# >>> TROQUE AQUI (itens): troque a forma pela sua imagem (por categoria).
	var tex: Texture2D = tex_item_azul if it.categoria == CATEGORIA_AZUL else tex_item_amarelo
	if tex != null:
		draw_set_transform(it.pos, it.rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-it.tam * 0.5, -it.tam * 0.5, it.tam, it.tam), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	if it.estado == Item.ARRASTANDO:
		draw_circle(it.pos, it.tam * 0.62, Color(1, 1, 1, 0.18))

	if it.forma == 0:
		var r := Rect2(it.pos - Vector2(it.tam, it.tam) * 0.5, Vector2(it.tam, it.tam))
		draw_rect(r, it.cor)
		draw_rect(r, it.cor.darkened(0.35), false, 4.0)
	else:
		draw_circle(it.pos, it.tam * 0.5, it.cor)
		draw_arc(it.pos, it.tam * 0.5, 0, TAU, 24, it.cor.darkened(0.35), 4.0)


# -----------------------------------------------------------------------------
# HUD (painel oval roxo + pontuacao + fase/meta)
# -----------------------------------------------------------------------------
func drawHUD() -> void:
	# oval dourado (borda) + oval roxo
	var pts_borda := _pontos_elipse(HUD_CENTRO, HUD_RX + 6, HUD_RY + 6, 48)
	draw_colored_polygon(pts_borda, COR_HUD_BORDA)

	# >>> TROQUE AQUI (HUD): desenhe seu painel no lugar do oval roxo.
	if tex_hud != null:
		var ret := Rect2(HUD_CENTRO - Vector2(HUD_RX, HUD_RY), Vector2(HUD_RX * 2, HUD_RY * 2))
		draw_texture_rect(tex_hud, ret, false)
	else:
		var pts := _pontos_elipse(HUD_CENTRO, HUD_RX, HUD_RY, 48)
		draw_colored_polygon(pts, COR_HUD_ROXO)

	_texto_centrado("PONTUAÇÃO", HUD_CENTRO.x, HUD_CENTRO.y - 8, 26, COR_TEXTO)
	_texto_centrado(str(pontuacao), HUD_CENTRO.x, HUD_CENTRO.y + 38, 46, COR_HUD_BORDA)

	# indicador de fase e meta (barra discreta abaixo da pontuacao)
	var nivel_atual: int = 3 if pontuacao >= meta_nivel(3) else (2 if pontuacao >= meta_nivel(2) else (1 if pontuacao >= meta_nivel(1) else 0))
	_texto_centrado("FASE %d / %d   •   META %d pts   •   Nível %d" % [
		fase_atual, TOTAL_FASES, meta_nivel(3), nivel_atual
	], 360, 160, 20, Color(1, 1, 1, 0.92))


func drawVidas() -> void:
	if not coracoes_visiveis:
		return
	for i in range(maxi(vidas, 0)):
		_desenhar_coracao(Vector2(44 + i * 44, 46), 15.0, COR_VIDA)


func _desenhar_coracao(c: Vector2, r: float, cor: Color) -> void:
	draw_circle(c + Vector2(-r * 0.5, -r * 0.35), r * 0.62, cor)
	draw_circle(c + Vector2(r * 0.5, -r * 0.35), r * 0.62, cor)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 1.02, -r * 0.1),
		c + Vector2(r * 1.02, -r * 0.1),
		c + Vector2(0, r * 1.05),
	]), cor)


func drawBotaoPausa() -> void:
	# >>> TROQUE AQUI (botao pausa)
	if tex_botao_pausa != null:
		draw_texture_rect(tex_botao_pausa,
			Rect2(BOTAO_PAUSA - Vector2(BOTAO_PAUSA_R, BOTAO_PAUSA_R),
				Vector2(BOTAO_PAUSA_R * 2, BOTAO_PAUSA_R * 2)), false)
		return
	draw_circle(BOTAO_PAUSA, BOTAO_PAUSA_R, COR_BOTAO_ROSA)
	draw_circle(BOTAO_PAUSA, BOTAO_PAUSA_R, COR_BOTAO_ROSA.darkened(0.3), false, 4.0)
	var b: float = 13.0
	draw_line(BOTAO_PAUSA + Vector2(-b, -b), BOTAO_PAUSA + Vector2(b, b), Color.WHITE, 6.0)
	draw_line(BOTAO_PAUSA + Vector2(-b, b), BOTAO_PAUSA + Vector2(b, -b), Color.WHITE, 6.0)


# =============================================================================
# TELAS (pausa / fim de fase / game over / vitoria)
# =============================================================================

func drawPausa() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAM_DESENHO), COR_MODAL)
	_texto_centrado("PAUSADO", 360, 600, 64, COR_TEXTO)
	_texto_centrado("Toque para continuar", 360, 668, 26, Color(1, 1, 1, 0.8))


func drawModalFase() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAM_DESENHO), COR_MODAL)
	var p := _rect_painel_modal()
	draw_rect(p, COR_PAINEL)
	draw_rect(p, COR_PAINEL_BORDA, false, 6.0)

	var titulo: String = "FASE %d CONCLUÍDA" % modal_fase
	if estrelas_ganhas <= 0:
		titulo = "FASE %d FALHOU" % modal_fase
	_texto_centrado(titulo, 360, p.position.y + 74, 40, COR_HUD_BORDA)

	drawEstrelas()

	_texto_centrado("PONTUAÇÃO", 360, 636, 24, Color(1, 1, 1, 0.8))
	_texto_centrado(str(int(pontos_exibidos)), 360, 700, 62, COR_TEXTO)

	var rotulo: String = "PRÓXIMA FASE"
	var cor_botao: Color = COR_BOTAO_VERDE
	if estrelas_ganhas <= 0:
		rotulo = "TENTAR DE NOVO"
		cor_botao = COR_BOTAO_ROSA
	elif modal_fase >= TOTAL_FASES:
		rotulo = "FINALIZAR"
		cor_botao = COR_HUD_BORDA

	var b := _rect_botao_modal()
	draw_rect(b, cor_botao)
	draw_rect(b, cor_botao.darkened(0.35), false, 4.0)
	_texto_centrado(rotulo, b.position.x + b.size.x * 0.5, b.position.y + b.size.y * 0.64, 34, COR_TEXTO_ESCURO if cor_botao != COR_BOTAO_ROSA else COR_TEXTO)


# -----------------------------------------------------------------------------
# ESTRELAS (animacao de preenchimento)
# -----------------------------------------------------------------------------
func drawEstrelas() -> void:
	var centros: Array[Vector2] = [Vector2(232, 470), Vector2(360, 470), Vector2(488, 470)]
	var raio: float = 62.0

	for i in range(3):
		var ganha: bool = i < estrelas_ganhas
		# atraso sequencial de 0.4s entre as estrelas
		var t: float = clampf((tempo_modal - float(i) * 0.4) / 0.38, 0.0, 1.0)

		var escala: float = 1.0
		var rot: float = 0.0
		if ganha:
			# "pop" elastico + pequeno giro
			var e: float = _ease_out_elastic(t)
			escala = lerpf(0.55, 1.0, e) + (1.0 - e) * 0.0
			rot = (1.0 - t) * (-0.9)

		var cor: Color = COR_ESTRELA_VAZIA
		if ganha:
			cor = COR_ESTRELA_CHEIA if t > 0.0 else COR_ESTRELA_VAZIA
			if t <= 0.0:
				cor = COR_ESTRELA_VAZIA

		_draw_estrela(centros[i], raio * escala, rot, cor, ganha and t > 0.0)


func _draw_estrela(centro: Vector2, raio: float, rot: float, cor: Color, cheia: bool) -> void:
	var pts: PackedVector2Array = _pontos_estrela(centro, raio, rot)
	# >>> TROQUE AQUI (estrela): troque por sua imagem no lugar do poligono.
	if tex_estrela != null and cheia:
		var lado: float = raio * 2.05
		draw_texture_rect(tex_estrela,
			Rect2(centro - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
		return
	# desenha a estrela como leque de triangulos a partir do centro
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		draw_colored_polygon(PackedVector2Array([centro, a, b]), cor)
	if cheia:
		draw_arc(centro, raio, 0, TAU, 32, COR_HUD_BORDA, 3.0)


func drawGameOver() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAM_DESENHO), COR_MODAL)
	var p := _rect_painel_modal()
	draw_rect(p, COR_PAINEL)
	draw_rect(p, COR_LIMITE, false, 6.0)
	_texto_centrado("FIM DE JOGO", 360, p.position.y + 120, 54, COR_LIMITE)
	_texto_centrado("Fase alcançada: %d" % modal_fase, 360, p.position.y + 210, 30, COR_TEXTO)
	_texto_centrado("Pontuação: %d" % pontuacao, 360, p.position.y + 270, 30, COR_TEXTO)
	var b := _rect_botao_modal()
	draw_rect(b, COR_BOTAO_VERDE)
	_texto_centrado("JOGAR DE NOVO", b.position.x + b.size.x * 0.5, b.position.y + b.size.y * 0.64, 32, COR_TEXTO_ESCURO)


func drawVitoria() -> void:
	draw_rect(Rect2(Vector2.ZERO, TAM_DESENHO), COR_MODAL)
	var p := _rect_painel_modal()
	draw_rect(p, COR_PAINEL)
	draw_rect(p, COR_HUD_BORDA, false, 6.0)
	_texto_centrado("VOCÊ VENCEU!", 360, p.position.y + 110, 50, COR_HUD_BORDA)
	_texto_centrado("Todas as 5 fases concluídas", 360, p.position.y + 180, 28, COR_TEXTO)

	# 3 estrelas cheias
	var centros: Array[Vector2] = [Vector2(232, 560), Vector2(360, 560), Vector2(488, 560)]
	for i in range(3):
		var esc: float = lerpf(0.5, 1.0, _ease_out_elastic(clampf((tempo_modal - float(i) * 0.2) / 0.4, 0.0, 1.0)))
		_draw_estrela(centros[i], 62.0 * esc, (1.0 - esc) * -0.7, COR_ESTRELA_CHEIA, true)

	_texto_centrado("Pontuação total: %d" % pontuacao_total, 360, 690, 30, COR_TEXTO)
	var b := _rect_botao_modal()
	draw_rect(b, COR_BOTAO_VERDE)
	_texto_centrado("JOGAR DE NOVO", b.position.x + b.size.x * 0.5, b.position.y + b.size.y * 0.64, 32, COR_TEXTO_ESCURO)


# =============================================================================
# HELPERS DE DESENHO
# =============================================================================

func _pontos_elipse(centro: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(centro + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _pontos_estrela(centro: Vector2, raio: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pontas: int = 5
	for i in range(pontas * 2):
		var r: float = raio if i % 2 == 0 else raio * 0.45
		var ang: float = -PI * 0.5 + rot + float(i) * PI / float(pontas)
		pts.append(centro + Vector2(cos(ang), sin(ang)) * r)
	return pts


func _texto_centrado(texto: String, centro_x: float, linha_y: float, tamanho: int, cor: Color) -> void:
	if fonte == null:
		return
	var largura: float = 640.0
	draw_string(fonte, Vector2(centro_x - largura * 0.5, linha_y),
		texto, HORIZONTAL_ALIGNMENT_CENTER, largura, tamanho, cor)


func _ease_out_elastic(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var c4: float = TAU / 3.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0
