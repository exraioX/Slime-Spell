class_name GameOver
extends CanvasLayer
## Tela de derrota. Mostra motivo, pontuação e recorde.

signal tentar_novamente_pressionado()
signal menu_pressionado()

var _raiz: Control
var _label_motivo: Label
var _label_pontos: Label
var _label_recorde: Label
var _btn_re: Button


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.05, 0.05, 0.82)
	_raiz.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "FIM DE JOGO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 76)
	titulo.add_theme_color_override("font_color", Color("e35b5b"))
	vbox.add_child(titulo)

	_label_motivo = Label.new()
	_label_motivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_motivo.add_theme_font_size_override("font_size", 30)
	_label_motivo.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	vbox.add_child(_label_motivo)

	_label_pontos = Label.new()
	_label_pontos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_pontos.add_theme_font_size_override("font_size", 44)
	_label_pontos.add_theme_color_override("font_color", Color("ffd700"))
	vbox.add_child(_label_pontos)

	_label_recorde = Label.new()
	_label_recorde.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_recorde.add_theme_font_size_override("font_size", 30)
	_label_recorde.add_theme_color_override("font_color", Color("7fe08a"))
	vbox.add_child(_label_recorde)

	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(esp)

	_btn_re = _criar_botao("TENTAR NOVAMENTE")
	_btn_re.pressed.connect(func() -> void: tentar_novamente_pressionado.emit())
	vbox.add_child(_btn_re)

	var btn_menu := _criar_botao("MENU PRINCIPAL")
	btn_menu.pressed.connect(func() -> void: menu_pressionado.emit())
	vbox.add_child(btn_menu)

	_raiz.visible = false


func _criar_botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(400, 70)
	b.add_theme_font_size_override("font_size", 32)
	return b


func mostrar(pontuacao: int, recorde: int, motivo: String, novo_recorde: bool) -> void:
	_label_pontos.text = "PONTUAÇÃO: %d" % pontuacao
	_label_recorde.text = "RECORDE: %d" % recorde
	if novo_recorde:
		_label_recorde.text += "   NOVO RECORDE!"
	match motivo:
		SnackBasketsGame.MOTIVO_ERRO:
			_label_motivo.text = "Você classificou um objeto no cesto errado."
		SnackBasketsGame.MOTIVO_NAO_CLASSIFICADO:
			_label_motivo.text = "Um objeto alcançou a barreira vermelha."
		_:
			_label_motivo.text = "Fim de jogo."
	_raiz.visible = true
	if _btn_re != null:
		_btn_re.grab_focus()


func esconder() -> void:
	_raiz.visible = false