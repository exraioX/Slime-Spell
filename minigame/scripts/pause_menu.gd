class_name PauseMenu
extends CanvasLayer
## Painel de pausa. Emite sinais de intenção.

signal continuar_pressionado()
signal reiniciar_pressionado()
signal menu_pressionado()

var _raiz: Control
var _btn_continuar: Button


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	_raiz.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "PAUSADO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 72)
	titulo.add_theme_color_override("font_color", Color("ffd700"))
	vbox.add_child(titulo)

	var dica := Label.new()
	dica.text = "ESC / Continuar para retomar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_size_override("font_size", 24)
	dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	vbox.add_child(dica)

	_btn_continuar = _criar_botao("CONTINUAR")
	_btn_continuar.pressed.connect(func() -> void: continuar_pressionado.emit())
	vbox.add_child(_btn_continuar)

	var btn_re := _criar_botao("REINICIAR")
	btn_re.pressed.connect(func() -> void: reiniciar_pressionado.emit())
	vbox.add_child(btn_re)

	var btn_menu := _criar_botao("MENU PRINCIPAL")
	btn_menu.pressed.connect(func() -> void: menu_pressionado.emit())
	vbox.add_child(btn_menu)

	_raiz.visible = false


func _criar_botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(360, 70)
	b.add_theme_font_size_override("font_size", 34)
	return b


func mostrar() -> void:
	_raiz.visible = true
	if _btn_continuar != null:
		_btn_continuar.grab_focus()


func esconder() -> void:
	_raiz.visible = false