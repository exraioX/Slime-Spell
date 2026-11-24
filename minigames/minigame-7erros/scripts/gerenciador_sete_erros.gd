extends HBoxContainer

@export_group("Navegação")
@export_file("*.tscn") var cena_mundo_principal: String = "res://Cenas/principal.tscn"

@export_group("Sequência de Imagens")
@export var imagens_originais: Array[Texture2D] = []
@export var imagens_com_erros: Array[Texture2D] = []

@export_group("Configurações Gerais")
@export var tempo_por_imagem: float = 120.0
@export var raio_circulo: float = 24.0
@export var distancia_acerto: float = 40.0

@export_group("Áudios")
@export var som_colocar: AudioStream
@export var som_acerto: AudioStream
@export var som_erro: AudioStream

@onready var imagem_original: TextureRect = $ImagemOriginal
@onready var imagem_com_erros: TextureRect = $ImagemComErros
@onready var label_erros: Label = get_parent().get_node_or_null("HUD/LabelErros")
@onready var label_tempo: Label = get_parent().get_node_or_null("HUD/LabelTempo")

var indice_fase_atual: int = 0
var tempo_restante: float = 0.0
var fase_encerrada: bool = false

var _historico_acertos: Array[int] = []
var _historico_totais: Array[int] = []

var _pontos_gabarito: Array[Vector2] = []
var _circulos_bandeja: Array[Panel] = []
var _circulos_colocados: Array[Panel] = []
var _circulo_arrastando: Panel = null
var _offset_arrasto: Vector2 = Vector2.ZERO

var _camada_ui: CanvasLayer
var _label_titulo_certa: Label
var _label_titulo_errada: Label
var _botao_enviar: Button
var _painel_resultado: PanelContainer
var _label_resultado: Label
var _btn_avancar: Button
var _btn_repetir: Button
var _btn_sair: Button
var _player_som: AudioStreamPlayer

func _ready() -> void:
	_configurar_enquadramento_imagens()
	
	_player_som = AudioStreamPlayer.new()
	add_child(_player_som)
	_criar_ui_dinamica()
	
	await get_tree().process_frame
	_reiniciar_tudo()

func _configurar_enquadramento_imagens() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_top = 85.0
	offset_bottom = -95.0
	
	for img in [imagem_original, imagem_com_erros]:
		if img != null:
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			img.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _reiniciar_tudo() -> void:
	_historico_acertos.clear()
	_historico_totais.clear()
	_iniciar_fase(0)

func _criar_ui_dinamica() -> void:
	_camada_ui = CanvasLayer.new()
	_camada_ui.layer = 10
	add_child(_camada_ui)
	
	# Títulos "CERTA" e "ERRADA" acima das imagens
	_label_titulo_certa = _fabricar_titulo("CERTA", Color(0.2, 0.95, 0.35, 1.0))
	_camada_ui.add_child(_label_titulo_certa)
	
	_label_titulo_errada = _fabricar_titulo("ERRADA", Color(1.0, 0.3, 0.3, 1.0))
	_camada_ui.add_child(_label_titulo_errada)
	
	# Botão Enviar Respostas
	_botao_enviar = Button.new()
	_botao_enviar.text = "ENVIAR RESPOSTAS"
	_botao_enviar.custom_minimum_size = Vector2(240, 52)
	_botao_enviar.add_theme_font_size_override("font_size", 20)
	_botao_enviar.visible = false
	_botao_enviar.pressed.connect(_ao_clicar_enviar)
	_camada_ui.add_child(_botao_enviar)
	
	# Painel de Resultado
	_painel_resultado = PanelContainer.new()
	_painel_resultado.custom_minimum_size = Vector2(480, 240)
	_painel_resultado.visible = false
	
	var estilo_painel := StyleBoxFlat.new()
	estilo_painel.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	estilo_painel.border_color = Color(1.0, 0.85, 0.2, 1.0)
	estilo_painel.set_border_width_all(3)
	estilo_painel.set_corner_radius_all(14)
	estilo_painel.set_content_margin_all(24)
	_painel_resultado.add_theme_stylebox_override("panel", estilo_painel)
	_camada_ui.add_child(_painel_resultado)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_painel_resultado.add_child(vbox)
	
	_label_resultado = Label.new()
	_label_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_resultado.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_label_resultado)
	
	var hbox_botoes := HBoxContainer.new()
	hbox_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_botoes.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox_botoes)
	
	_btn_avancar = Button.new()
	_btn_avancar.text = "Avançar"
	_btn_avancar.custom_minimum_size = Vector2(140, 48)
	_btn_avancar.add_theme_font_size_override("font_size", 18)
	_btn_avancar.pressed.connect(_ao_clicar_avancar)
	hbox_botoes.add_child(_btn_avancar)
	
	_btn_repetir = Button.new()
	_btn_repetir.text = "Repetir"
	_btn_repetir.custom_minimum_size = Vector2(140, 48)
	_btn_repetir.add_theme_font_size_override("font_size", 18)
	_btn_repetir.pressed.connect(_ao_clicar_repetir)
	hbox_botoes.add_child(_btn_repetir)
	
	_btn_sair = Button.new()
	_btn_sair.text = "Sair"
	_btn_sair.custom_minimum_size = Vector2(140, 48)
	_btn_sair.add_theme_font_size_override("font_size", 18)
	_btn_sair.pressed.connect(_ao_clicar_sair)
	hbox_botoes.add_child(_btn_sair)

func _fabricar_titulo(texto: String, cor: Color) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", cor)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	return lbl

func _posicionar_titulos_imagens() -> void:
	if imagem_original != null and _label_titulo_certa != null:
		var r_certa: Rect2 = _obter_retangulo_real_desenho(imagem_original)
		_label_titulo_certa.size = Vector2(r_certa.size.x, 36)
		_label_titulo_certa.position = Vector2(r_certa.position.x, maxf(44.0, r_certa.position.y - 38.0))
		
	if imagem_com_erros != null and _label_titulo_errada != null:
		var r_errada: Rect2 = _obter_retangulo_real_desenho(imagem_com_erros)
		_label_titulo_errada.size = Vector2(r_errada.size.x, 36)
		_label_titulo_errada.position = Vector2(r_errada.position.x, maxf(44.0, r_errada.position.y - 38.0))
func _iniciar_fase(indice: int) -> void:
	indice_fase_atual = indice
	fase_encerrada = false
	tempo_restante = tempo_por_imagem
	_botao_enviar.visible = false
	_painel_resultado.visible = false
	
	_limpar_elementos()
	
	if indice < imagens_originais.size() and imagens_originais[indice] != null:
		imagem_original.texture = imagens_originais[indice]
	if indice < imagens_com_erros.size() and imagens_com_erros[indice] != null:
		imagem_com_erros.texture = imagens_com_erros[indice]
		
	await get_tree().process_frame
	_posicionar_titulos_imagens()
	_carregar_gabarito_fase(indice)
	_criar_circulos_bandeja()
	_atualizar_hud()

func _limpar_elementos() -> void:
	for c in _circulos_bandeja:
		if is_instance_valid(c):
			c.queue_free()
	_circulos_bandeja.clear()
	
	for c in _circulos_colocados:
		if is_instance_valid(c):
			c.queue_free()
	_circulos_colocados.clear()

func _carregar_gabarito_fase(indice: int) -> void:
	_pontos_gabarito.clear()
	var alvo_lower: String = "fase" + str(indice + 1)
	var container_pontos: Node = null
	
	for filho in imagem_com_erros.get_children():
		if filho.name.to_lower().begins_with("fase"):
			var eh_atual: bool = (filho.name.to_lower() == alvo_lower)
			if "visible" in filho:
				filho.visible = eh_atual
			if eh_atual:
				container_pontos = filho
				
	if container_pontos == null:
		container_pontos = imagem_com_erros
		
	var rect_desenho: Rect2 = _obter_retangulo_real_desenho(imagem_com_erros)
	for ponto in container_pontos.get_children():
		if ponto is Node2D or ponto is Control:
			if rect_desenho.size.x > 0 and rect_desenho.size.y > 0:
				var pos_norm: Vector2 = (ponto.global_position - rect_desenho.position) / rect_desenho.size
				_pontos_gabarito.append(pos_norm)

func _obter_retangulo_real_desenho(tex_rect: TextureRect) -> Rect2:
	var rect_box: Rect2 = tex_rect.get_global_rect()
	if tex_rect.texture == null:
		return rect_box
		
	var tex_size: Vector2 = tex_rect.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return rect_box
		
	var escala: float = minf(rect_box.size.x / tex_size.x, rect_box.size.y / tex_size.y)
	var tam_real: Vector2 = tex_size * escala
	var offset: Vector2 = (rect_box.size - tam_real) * 0.5
	return Rect2(rect_box.position + offset, tam_real)

func _criar_circulos_bandeja() -> void:
	var qtd_circulos: int = max(1, _pontos_gabarito.size())
	var tela_tam: Vector2 = get_viewport_rect().size
	var rect_errada: Rect2 = _obter_retangulo_real_desenho(imagem_com_erros)
	
	var imagem_em_pe: bool = false
	if imagem_com_erros.texture != null:
		imagem_em_pe = imagem_com_erros.texture.get_height() > imagem_com_erros.texture.get_width()
		
	var espacamento: float = 64.0
	var largura_ou_altura_total: float = (qtd_circulos - 1) * espacamento

	for i in range(qtd_circulos):
		var circulo := _fabricar_circulo(Color(1.0, 0.85, 0.1, 1.0), Color(1.0, 0.85, 0.1, 0.25))
		var pos_ini := Vector2.ZERO
		
		if imagem_em_pe:
			var pos_x_direita: float = minf(tela_tam.x - (raio_circulo * 2.0) - 20.0, rect_errada.end.x + 25.0)
			var inicio_y: float = rect_errada.position.y + (rect_errada.size.y - largura_ou_altura_total) * 0.5 - raio_circulo
			pos_ini = Vector2(pos_x_direita, inicio_y + (i * espacamento))
		else:
			var inicio_x: float = (tela_tam.x - largura_ou_altura_total) * 0.5 - raio_circulo
			var pos_y_baixo: float = tela_tam.y - 75.0
			pos_ini = Vector2(inicio_x + (i * espacamento), pos_y_baixo)
			
		circulo.position = pos_ini
		circulo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		circulo.set_meta("pos_inicial", pos_ini)
		circulo.set_meta("colocado", false)
		
		circulo.gui_input.connect(_ao_interagir_circulo.bind(circulo))
		_camada_ui.add_child(circulo)
		_circulos_bandeja.append(circulo)

func _fabricar_circulo(cor_borda: Color, cor_fundo: Color) -> Panel:
	var painel := Panel.new()
	painel.size = Vector2(raio_circulo * 2.0, raio_circulo * 2.0)
	
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor_fundo
	estilo.border_color = cor_borda
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(int(raio_circulo))
	painel.add_theme_stylebox_override("panel", estilo)
	return painel
func _ao_interagir_circulo(event: InputEvent, circulo: Panel) -> void:
	if fase_encerrada or circulo.get_meta("colocado"):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_circulo_arrastando = circulo
			_offset_arrasto = get_global_mouse_position() - circulo.global_position
		elif _circulo_arrastando == circulo:
			_circulo_arrastando = null
			_tentar_fixar_circulo(circulo)

func _tentar_fixar_circulo(circulo: Panel) -> void:
	var centro_global: Vector2 = circulo.global_position + Vector2(raio_circulo, raio_circulo)
	var rect_errada: Rect2 = _obter_retangulo_real_desenho(imagem_com_erros)
	
	if rect_errada.has_point(centro_global):
		circulo.set_meta("colocado", true)
		circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_atualizar_cor_circulo(circulo, Color(0.2, 0.7, 1.0, 1.0), Color(0.2, 0.7, 1.0, 0.25))
		_circulos_colocados.append(circulo)
		_tocar_som(som_colocar)
		_atualizar_hud()
		
		if _circulos_colocados.size() >= _pontos_gabarito.size():
			var tela: Vector2 = get_viewport_rect().size
			_botao_enviar.position = Vector2((tela.x - _botao_enviar.size.x) * 0.5, tela.y - 72.0)
			_botao_enviar.visible = true
	else:
		var tween := create_tween()
		tween.tween_property(circulo, "position", circulo.get_meta("pos_inicial"), 0.2)

func _ao_clicar_enviar() -> void:
	if fase_encerrada:
		return
		
	fase_encerrada = true
	_botao_enviar.visible = false
	
	var rect_errada: Rect2 = _obter_retangulo_real_desenho(imagem_com_erros)
	var pontos_usados: Array[int] = []
	var acertos_na_imagem: int = 0
	
	for circulo in _circulos_colocados:
		var centro_global: Vector2 = circulo.global_position + Vector2(raio_circulo, raio_circulo)
		var acertou_este: bool = false
		
		for i in range(_pontos_gabarito.size()):
			if i in pontos_usados:
				continue
			var pos_gabarito_global: Vector2 = rect_errada.position + (_pontos_gabarito[i] * rect_errada.size)
			if centro_global.distance_to(pos_gabarito_global) <= distancia_acerto:
				acertou_este = true
				pontos_usados.append(i)
				break
				
		if acertou_este:
			acertos_na_imagem += 1
			_atualizar_cor_circulo(circulo, Color(0.1, 0.9, 0.2, 1.0), Color(0.1, 0.9, 0.2, 0.3))
		else:
			_atualizar_cor_circulo(circulo, Color(0.95, 0.15, 0.15, 1.0), Color(0.95, 0.15, 0.15, 0.3))
			
	var total_da_imagem: int = _pontos_gabarito.size()
	var erros_na_imagem: int = total_da_imagem - acertos_na_imagem
	var acertou_tudo: bool = (acertos_na_imagem == total_da_imagem)
	
	if _historico_acertos.size() <= indice_fase_atual:
		_historico_acertos.append(acertos_na_imagem)
		_historico_totais.append(total_da_imagem)
	else:
		_historico_acertos[indice_fase_atual] = acertos_na_imagem
		_historico_totais[indice_fase_atual] = total_da_imagem
		
	_tocar_som(som_acerto if acertou_tudo else som_erro)
	await get_tree().create_timer(1.2).timeout
	
	var eh_ultima_imagem: bool = (indice_fase_atual + 1) >= imagens_com_erros.size()
	
	if acertou_tudo and eh_ultima_imagem:
		_exibir_resumo_final()
	else:
		_exibir_opcoes_fase(acertou_tudo, acertos_na_imagem, erros_na_imagem)

func _exibir_opcoes_fase(acertou_tudo: bool, acertos: int, erros: int) -> void:
	_btn_avancar.visible = acertou_tudo
	_btn_repetir.text = "Repetir"
	_btn_repetir.visible = true
	_btn_sair.visible = true
	
	if acertou_tudo:
		_label_resultado.text = "PARABÉNS! VOCÊ ACERTOU TODOS OS %d ERROS!" % acertos
	else:
		_label_resultado.text = "VOCÊ ACERTOU %d E ERROU %d!\nTente novamente para avançar." % [acertos, erros]
		
	_centralizar_painel_resultado()

func _exibir_resumo_final() -> void:
	var soma_acertos: int = 0
	var soma_totais: int = 0
	for i in range(_historico_acertos.size()):
		soma_acertos += _historico_acertos[i]
		soma_totais += _historico_totais[i]
		
	var porcentagem: float = (float(soma_acertos) / float(max(1, soma_totais))) * 100.0
	
	_btn_avancar.visible = false
	_btn_repetir.text = "Repetir Tudo"
	_btn_repetir.visible = true
	_btn_sair.visible = true
	
	_label_resultado.text = "MINIGAME CONCLUÍDO!\n\nTotal de Acertos: %d de %d\nAproveitamento: %.0f%%" % [
		soma_acertos, soma_totais, porcentagem
	]
	_centralizar_painel_resultado()

func _centralizar_painel_resultado() -> void:
	var tela: Vector2 = get_viewport_rect().size
	_painel_resultado.visible = true
	await get_tree().process_frame
	_painel_resultado.position = (tela - _painel_resultado.size) * 0.5

func _ao_clicar_avancar() -> void:
	_iniciar_fase(indice_fase_atual + 1)

func _ao_clicar_repetir() -> void:
	if _btn_repetir.text == "Repetir Tudo":
		_reiniciar_tudo()
	else:
		_iniciar_fase(indice_fase_atual)

func _ao_clicar_sair() -> void:
	if cena_mundo_principal != "" and ResourceLoader.exists(cena_mundo_principal):
		get_tree().change_scene_to_file.call_deferred(cena_mundo_principal)

func _process(delta: float) -> void:
	if fase_encerrada:
		return
	if _circulo_arrastando != null:
		_circulo_arrastando.global_position = get_global_mouse_position() - _offset_arrasto
	tempo_restante -= delta
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		_ao_clicar_enviar()
	_atualizar_hud()

func _atualizar_cor_circulo(circulo: Panel, cor_borda: Color, cor_fundo: Color) -> void:
	var estilo: StyleBoxFlat = circulo.get_theme_stylebox("panel").duplicate()
	estilo.border_color = cor_borda
	estilo.bg_color = cor_fundo
	circulo.add_theme_stylebox_override("panel", estilo)

func _atualizar_hud() -> void:
	var total_fases: int = max(1, imagens_com_erros.size())
	if label_erros != null:
		label_erros.text = "Imagem %d/%d | Marcados: %d / %d" % [
			indice_fase_atual + 1, total_fases, _circulos_colocados.size(), _pontos_gabarito.size()
		]
	if label_tempo != null:
		var seg_totais: int = int(tempo_restante)
		var min_rest: int = int(seg_totais / 60.0)
		var seg_rest: int = seg_totais % 60
		label_tempo.text = "Tempo: %02d:%02d" % [min_rest, seg_rest]

func _tocar_som(audio: AudioStream) -> void:
	if audio != null and _player_som != null:
		_player_som.stream = audio
		_player_som.play()
