class_name Conveyor
extends Node2D
## Desenha a esteira, a janela de decisão e a barreira vermelha.
## A estrutura é independente da imagem da esteira: se tex_esteira for definida,
## a imagem é usada no lugar do desenho; caso contrário, desenha-se a forma.

var config: GameConfig = null
var offset_linhas: float = 0.0
var barreira_flash: float = 0.0


func configurar(cfg: GameConfig) -> void:
	config = cfg
	queue_redraw()


func atualizar(delta: float, velocidade: float) -> void:
	offset_linhas = fmod(offset_linhas + velocidade * delta, 60.0)
	barreira_flash = maxf(barreira_flash - delta, 0.0)
	queue_redraw()


func pulsar_barreira() -> void:
	barreira_flash = 0.5


func _draw() -> void:
	if config == null:
		return

	# >>> TROQUE AQUI (esteira): substitua o corpo da esteira pela sua imagem.
	var conv: Rect2 = config.esteira_rect
	if config.tex_esteira != null:
		draw_texture_rect(config.tex_esteira, conv, false)
	else:
		draw_rect(conv, config.cor_esteira)
		var y: float = conv.position.y + offset_linhas - 60.0
		while y < conv.position.y + conv.size.y:
			if y >= conv.position.y:
				draw_rect(Rect2(conv.position.x, y, conv.size.x, 3.0), config.cor_esteira_linha)
			y += 60.0

	# Boradas laterais da esteira
	draw_rect(Rect2(conv.position.x, conv.position.y, 6.0, conv.size.y), config.cor_esteira_borda)
	draw_rect(Rect2(conv.position.x + conv.size.x - 6.0, conv.position.y, 6.0, conv.size.y), config.cor_esteira_borda)

	# Janela de decisão (área onde a classificação é permitida)
	var jan: Rect2 = config.janela_rect()
	draw_rect(jan, config.cor_janela)
	draw_rect(Rect2(jan.position.x, jan.position.y, jan.size.x, 3.0), Color(1, 1, 1, 0.22))
	draw_rect(Rect2(jan.position.x, jan.position.y + jan.size.y - 3.0, jan.size.x, 3.0), Color(1, 1, 1, 0.22))

	# Barreira vermelha
	var bar: Rect2 = config.barreira_rect()
	if config.tex_barreira != null:
		draw_texture_rect(config.tex_barreira, bar, false)
	else:
		var cor: Color = config.cor_barreira
		if barreira_flash > 0.0:
			cor = cor.lerp(Color.WHITE, barreira_flash)
		draw_rect(bar, cor)
		var x: float = bar.position.x
		while x < bar.position.x + bar.size.x:
			draw_rect(Rect2(x, bar.position.y, 9.0, bar.size.y), cor.darkened(0.28))
			x += 26.0