class_name AreaInteracao
extends Area2D
## Área de interação: quando o protagonista (spell) entra nela, o jogo
## troca para a cena de destino (por padrão, o minigame Snack Baskets).
##
## COMO USAR:
##   1. Instancie area_interacao.tscn em qualquer cena.
##   2. Posicione onde quiser e ajuste o CollisionShape2D.
##   3. (Opcional) arraste uma imagem no campo "textura" para mostrar um ícone.
##
## >>> TROQUE AQUI: campo "textura" abaixo aceita sua imagem sem alterar código.

@export_file("*.tscn") var cena_destino: String = "res://minigame/scenes/game.tscn"
@export var grupo_jogador: StringName = &"Player"
@export var aceitar_por_nome: String = "spell"   ## nome alternativo do protagonista
@export var exigir_tecla: bool = true           ## se true, espera a ação "interagir"
@export var acao_confirmar: StringName = &"ui_accept"   ## Enter / Action confirm
@export var mostrar_area: bool = true            ## desenha um retângulo de ajuda
@export var textura: Texture2D                   ## imagem opcional da área/portal
@export var cor_area: Color = Color(0.4, 0.8, 1.0, 0.18)
@export var cor_borda: Color = Color(0.4, 0.8, 1.0, 0.7)

var _jogador_dentro: Node = null
var _trocando: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if not is_in_group("interagivel"):
		add_to_group("interagivel")
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not _e_o_jogador(body):
		return
	_jogador_dentro = body
	queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body == _jogador_dentro:
		_jogador_dentro = null
		queue_redraw()


func _e_o_jogador(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group(grupo_jogador):
		return true
	if aceitar_por_nome != "" and body.name == aceitar_por_nome:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not exigir_tecla or _jogador_dentro == null:
		return
	if event.is_action_pressed(acao_confirmar):
		_ir_para_destino()


func _ir_para_destino() -> void:
	if _trocando or cena_destino.is_empty():
		return
	_trocando = true
	get_tree().change_scene_to_file(cena_destino)


func _draw() -> void:
	var rect: Rect2 = _retangulo_shape()
	if rect == Rect2():
		return

	if textura != null:
		draw_texture_rect(textura, rect, false)

	if mostrar_area:
		draw_rect(rect, cor_area)
		draw_rect(rect, cor_borda, false, 4.0)

	if exigir_tecla and _jogador_dentro != null:
		var fonte: Font = ThemeDB.fallback_font
		if fonte != null:
			draw_string(fonte, Vector2(rect.position.x, rect.position.y - 16.0),
				"Pressione %s para jogar" % String(acao_confirmar).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 30, Color(1, 1, 1, 0.95))


func _retangulo_shape() -> Rect2:
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var cs: CollisionShape2D = c
			var rs: RectangleShape2D = cs.shape
			var tam: Vector2 = rs.size * cs.scale
			return Rect2(cs.position - tam * 0.5, tam)
	return Rect2()
