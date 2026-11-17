class_name Basket
extends Node2D
## Cesto-destino. Representa uma categoria. Visual desenhado (substituível).

@export var categoria: int = 0                 ## categoria aceita (ItemData.CATEGORIA_*)
@export var cor: Color = Color("e8b21e")
@export var tamanho: Vector2 = Vector2(320, 180)
@export var rotulo: String = "COMIDA"
## >>> TROQUE AQUI (cesto): arraste sua imagem aqui.
@export var textura: Texture2D

var destaque: float = 0.0      ## 0..1 brilho temporário ao acertar


func configurar(cfg: GameConfig, cat: int, e_esquerda: bool) -> void:
	categoria = cat
	if e_esquerda:
		cor = cfg.cor_cesto_esquerda
		textura = cfg.tex_cesto_esquerda
		rotulo = "COMIDA"
	else:
		cor = cfg.cor_cesto_direita
		textura = cfg.tex_cesto_direita
		rotulo = "LIXO"
	tamanho = cfg.cesto_tamanho
	queue_redraw()


func atualizar(delta: float) -> void:
	if destaque > 0.0:
		destaque = maxf(destaque - delta, 0.0)
		queue_redraw()


func brilhar() -> void:
	destaque = 0.5
	queue_redraw()


func _draw() -> void:
	var largura: float = tamanho.x * (1.0 + destaque * 0.06)
	var altura: float = tamanho.y * (1.0 + destaque * 0.06)
	var ret := Rect2(-largura * 0.5, -altura * 0.5, largura, altura)

	# sombra
	draw_rect(Rect2(ret.position + Vector2(0, 10), ret.size), Color(0, 0, 0, 0.25))

	if textura != null:
		draw_texture_rect(textura, ret, false)
		_desenhar_indicador(ret)
		return

	# Trapézio (topo mais largo que a base) - pontos em coordenadas locais (0,0)
	var pts := PackedVector2Array([
		Vector2(-largura * 0.5, -altura * 0.5),  # topo-esquerdo
		Vector2(largura * 0.5, -altura * 0.5),   # topo-direito
		Vector2(largura * 0.40, altura * 0.5),   # base-direita (recuo menor)
		Vector2(-largura * 0.40, altura * 0.5),  # base-esquerda (recuo menor)
	])
	draw_colored_polygon(pts, cor)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[3], pts[0]]), cor.darkened(0.4), 5.0)

	# Fendas verticais (dá aparência de recipiente)
	for k in range(-1, 2):
		var fx: float = k * tamanho.x * 0.22
		draw_rect(Rect2(fx - 5, -altura * 0.22, 10, altura * 0.44), cor.darkened(0.45))

	_desenhar_indicador(ret)


func _desenhar_indicador(ret: Rect2) -> void:
	# Setinha / rótulo indicando a categoria (clareza visual)
	var seta_y: float = ret.position.y - 44.0
	var dir: float = -1.0 if categoria == ItemData.CATEGORIA_COMIDA else 1.0
	# Seta apontando para o lado do cesto correspondente
	draw_colored_polygon(PackedVector2Array([
		Vector2(dir * -14.0, seta_y - 18.0),
		Vector2(dir * -14.0, seta_y + 18.0),
		Vector2(dir * 22.0, seta_y),
	]), cor.lightened(0.15))

	var fonte: Font = ThemeDB.fallback_font
	if fonte != null:
		draw_string(fonte, Vector2(-140, ret.position.y - 66.0), rotulo,
			HORIZONTAL_ALIGNMENT_CENTER, 280.0, 30, Color(1, 1, 1, 0.92))