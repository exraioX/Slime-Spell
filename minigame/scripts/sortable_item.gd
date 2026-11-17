class_name SortableItem
extends Node2D
## Um objeto que desce pela esteira. NÃO decide se está correto:
## apenas armazena dados e cuida do próprio visual/estado.
## A validação é responsabilidade do GameManager (sistema central).

enum EstadoItem { CAINDO, VOANDO, COLETADO }

var data: ItemData = null
var categoria: int = 0
var pontuacao: int = 10
var especial: bool = false
var escala: float = 1.0
var velocidade: float = 0.0
var estado: int = EstadoItem.CAINDO
var ja_classificado: bool = false
var cor: Color = Color("f08a2c")
var forma: int = 0
var _conteudo: float = 1.0     ## 1 = apenas apareceu, 0 = totalmente coletado
var pronto: bool = false       ## verdadeiro quando é o objeto disponível na janela
var _pulso: float = 0.0

const TAM_BASE := 96.0


## Inicializa o item a partir de um ItemData e da configuração.
func preparar(item_data: ItemData, cfg: GameConfig, x_inicial: float) -> void:
	data = item_data
	categoria = item_data.categoria
	pontuacao = item_data.pontuacao
	especial = item_data.especial
	escala = item_data.escala
	cor = item_data.cor_placeholder
	forma = item_data.forma
	position = Vector2(x_inicial, cfg.spawn_y)
	velocidade = cfg.velocidade_inicial
	# animação de entrada: surge crescendo
	_conteudo = 1.0
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Avança para baixo na esteira.
func descer(delta: float) -> void:
	if estado != EstadoItem.CAINDO:
		return
	position.y += velocidade * delta


func _process(delta: float) -> void:
	if pronto:
		_pulso += delta
		queue_redraw()


## Envia o item voando para um destino (cesto ou ponto de coleta).
func voar_para(destino: Vector2, apagar: bool = true) -> void:
	estado = EstadoItem.VOANDO
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", destino, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale", Vector2(0.35, 0.35), 0.32)
	t.tween_property(self, "rotation", 0.6, 0.32)
	t.chain().tween_callback(func() -> void:
		estado = EstadoItem.COLETADO
		if apagar:
			queue_free()
	)


func _draw() -> void:
	var tam: float = TAM_BASE * escala

	# sombra no chão da esteira
	draw_circle(Vector2(0, tam * 0.55), tam * 0.34, Color(0, 0, 0, 0.18))

	# Indicador de "pronto para classificar" (anel dourado pulsante)
	if pronto:
		var raio: float = tam * 0.62 + 4.0 * sin(_pulso * 6.0)
		draw_arc(Vector2.ZERO, raio, 0.0, TAU, 40, Color("ffd700"), 5.0)

	var tex: Texture2D = data.textura if data != null else null
	if tex != null:
		var r := Rect2(-tam * 0.5, -tam * 0.5, tam, tam)
		draw_texture_rect(tex, r, false)
		_desenhar_especial(r)
		return

	# >>> TROQUE AQUI (objetos): sem textura, desenha a forma placeholder.
	if forma == 0:
		var r := Rect2(-tam * 0.5, -tam * 0.5, tam, tam)
		draw_rect(r, cor)
		draw_rect(r, cor.darkened(0.35), false, 4.0)
	else:
		draw_circle(Vector2.ZERO, tam * 0.5, cor)
		draw_arc(Vector2.ZERO, tam * 0.5, 0.0, TAU, 28, cor.darkened(0.35), 4.0)

	_desenhar_especial(Rect2(-tam * 0.5, -tam * 0.5, tam, tam))


func _desenhar_especial(r: Rect2) -> void:
	if not especial:
		return
	# Coroa/estrela indicando objeto bônus (doce)
	var c := r.position + r.size * 0.5
	var raio: float = r.size.x * 0.62
	var pts := PackedVector2Array()
	for i in range(10):
		var rr: float = raio if i % 2 == 0 else raio * 0.45
		var a: float = -PI * 0.5 + float(i) * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("ffd700"), 4.0)