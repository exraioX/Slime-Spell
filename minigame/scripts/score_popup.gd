class_name ScorePopup
extends Node2D
## Texto flutuante ("+10") que sobe e desaparece. Criado via código pelo HUD/Game.

var texto: String = "+10"
var cor: Color = Color("ffd700")
var _vida: float = 0.0
var _duracao: float = 0.8
var _subindo: bool = false


func _ready() -> void:
	z_index = 100
	# pequeno "pop" de escala
	scale = Vector2(0.6, 0.6)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_subindo = true
	set_process(true)


func _process(delta: float) -> void:
	if not _subindo:
		return
	_vida += delta
	position.y -= 70.0 * delta
	modulate.a = clampf(1.0 - _vida / _duracao, 0.0, 1.0)
	queue_redraw()
	if _vida >= _duracao:
		queue_free()


func _draw() -> void:
	var fonte: Font = ThemeDB.fallback_font
	if fonte == null:
		return
	# contorno
	draw_string(fonte, Vector2(-90, 0), texto, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 40, Color(0, 0, 0, 0.6))
	draw_string(fonte, Vector2(-90, -2), texto, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 40, cor)