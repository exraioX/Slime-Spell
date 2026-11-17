class_name GameHUD
extends CanvasLayer
## Interface de jogo: pontuação, combo, recorde e velocidade.
## Os dados chegam por sinais do ScoreManager (nunca acessando variáveis internas).

var config: GameConfig = null

var _raiz: Control
var _label_pontos: Label
var _label_combo: Label
var _label_recorde: Label
var _label_velocidade: Label


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_label_pontos = _criar_label(Vector2(40, 20), 44, Color("ffd700"))
	_label_combo = _criar_label(Vector2(40, 84), 34, Color("7fe08a"))
	_label_velocidade = _criar_label(Vector2(40, 138), 24, Color(1, 1, 1, 0.75))
	_label_recorde = _criar_label(Vector2(1480, 20), 34, Color(1, 1, 1, 0.9))
	_label_recorde.size = Vector2(400, 50)
	_label_recorde.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	definir_visivel(true)


func _criar_label(pos: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	_raiz.add_child(l)
	return l


func ligar(score: ScoreManager, cfg: GameConfig) -> void:
	config = cfg
	score.pontuacao_mudou.connect(_on_pontos)
	score.combo_mudou.connect(_on_combo)
	score.recorde_mudou.connect(_on_recorde)
	_on_pontos(score.pontuacao)
	_on_combo(score.combo)
	_on_recorde(score.recorde)


func definir_visivel(v: bool) -> void:
	if _raiz != null:
		_raiz.visible = v


func _on_pontos(v: int) -> void:
	if _label_pontos != null:
		_label_pontos.text = "PONTOS: %d" % v


func _on_combo(v: int) -> void:
	if _label_combo != null:
		_label_combo.text = "COMBO: x%d" % maxi(v, 1)


func _on_recorde(v: int) -> void:
	if _label_recorde != null:
		_label_recorde.text = "RECORDE: %d" % v


## Atualiza o indicador de velocidade/dificuldade (0..1).
func definir_progresso(t: float) -> void:
	if _label_velocidade != null:
		_label_velocidade.text = "VELOCIDADE: %d%%" % int(clampf(t, 0.0, 1.0) * 100.0)