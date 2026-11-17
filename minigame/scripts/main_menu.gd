class_name MainMenu
extends CanvasLayer
## Tela inicial independente. Emite sinais; não conhece o resto do jogo.

signal jogar_pressionado()
signal sair_pressionado()

var _raiz: Control
var _label_recorde: Label


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.08, 0.13, 0.86)
	_raiz.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "SNACK BASKETS"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 84)
	titulo.add_theme_color_override("font_color", Color("ffd700"))
	vbox.add_child(titulo)

	var sub := Label.new()
	sub.text = "Esteira de Classificação"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	vbox.add_child(sub)

	_label_recorde = Label.new()
	_label_recorde.text = "RECORDE: 0"
	_label_recorde.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_recorde.add_theme_font_size_override("font_size", 32)
	_label_recorde.add_theme_color_override("font_color", Color("7fe08a"))
	vbox.add_child(_label_recorde)

	var controles := Label.new()
	controles.text = "← / A = cesto ESQUERDA (comida)\n→ / D = cesto DIREITA (lixo)\n↑ / W = pegar doce (bônus)\nESC = pausar"
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controles.add_theme_font_size_override("font_size", 26)
	controles.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	vbox.add_child(controles)

	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(esp)

	var btn_jogar := _criar_botao("JOGAR")
	btn_jogar.pressed.connect(func() -> void: jogar_pressionado.emit())
	vbox.add_child(btn_jogar)

	var btn_sair := _criar_botao("SAIR")
	btn_sair.pressed.connect(func() -> void: sair_pressionado.emit())
	vbox.add_child(btn_sair)

	btn_jogar.grab_focus()


func _criar_botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(320, 72)
	b.add_theme_font_size_override("font_size", 36)
	return b


func mostrar(recorde: int) -> void:
	if _label_recorde != null:
		_label_recorde.text = "RECORDE: %d" % recorde
	_raiz.visible = true


func esconder() -> void:
	_raiz.visible = false