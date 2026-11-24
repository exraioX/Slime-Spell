@tool
extends Control

@export_group("Navegação")
@export_file("*.tscn") var cena_mundo_principal: String = "res://Cenas/principal.tscn"

@export_group("1. Fases Deitadas (Usa fase1, fase2... de ContainerDeitada)")
@export var deitadas_originais: Array[Texture2D] = []
@export var deitadas_com_erros: Array[Texture2D] = []

@export_group("2. Fases Em Pé (Usa fase1, fase2... de ContainerEmPe)")
@export var em_pe_originais: Array[Texture2D] = []
@export var em_pe_com_erros: Array[Texture2D] = []

@export_group("Configurações Gerais")
@export var tempo_por_imagem: float = 120.0
@export var raio_circulo: float = 24.0
@export var distancia_acerto: float = 40.0
@export var margem_lateral_em_pe: float = 25.0
@export var espacamento_vertical_em_pe: float = 58.0

@export_group("Estilo Visual e Fonte")
@export var fonte_personalizada: Font
@export var tamanho_fonte_hud: int = 20

@export_group("Modo Editor (Para marcar os pontos)")
@export var fase_para_marcar_no_editor: int = 1:
	set(valor):
		fase_para_marcar_no_editor = max(1, valor)
		if Engine.is_editor_hint():
			_atualizar_preview_editor()

@export_group("Áudios")
@export var som_colocar: AudioStream
@export var som_acerto: AudioStream
@export var som_erro: AudioStream

@onready var container_em_pe: Container = get_node_or_null("ContainerEmPe")
@onready var container_deitada: Container = get_node_or_null("ContainerDeitada")
@onready var label_erros: Label = find_child("LabelErros", true, false) as Label
@onready var label_tempo: Label = find_child("LabelTempo", true, false) as Label

var _fila_fases: Array[Dictionary] = []
var _img_certa_ativa: TextureRect
var _img_errada_ativa: TextureRect

var indice_fase_atual: int = 0
var tempo_restante: float = 0.0
var fase_encerrada: bool = true
var _modo_em_pe: bool = false

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
	_configurar_containers()
	
	if Engine.is_editor_hint():
		_atualizar_preview_editor()
		return
		
	_player_som = AudioStreamPlayer.new()
	add_child(_player_som)
	_montar_fila_de_fases()
	_criar_ui_dinamica()
	
	await get_tree().process_frame
	_reiniciar_tudo()

func _atualizar_preview_editor() -> void:
	if not is_inside_tree():
		return
	container_em_pe = get_node_or_null("ContainerEmPe")
	container_deitada = get_node_or_null("ContainerDeitada")
	
	_configurar_containers()
	_montar_fila_de_fases()
	
	if _fila_fases.is_empty():
		return
		
	var idx: int = clampi(fase_para_marcar_no_editor - 1, 0, _fila_fases.size() - 1)
	var dados: Dictionary = _fila_fases[idx]
	var eh_em_pe: bool = dados["em_pe"]
	
	if container_em_pe != null:
		container_em_pe.visible = eh_em_pe
	if container_deitada != null:
		container_deitada.visible = not eh_em_pe
		
	var cont: Container = container_em_pe if eh_em_pe else container_deitada
	if cont != null and cont.get_child_count() >= 2:
		var img_c: TextureRect = cont.get_child(0) as TextureRect
		var img_e: TextureRect = cont.get_child(1) as TextureRect
		if img_c != null:
			img_c.texture = dados["original"]
		if img_e != null:
			img_e.texture = dados["errada"]
			for filho in img_e.get_children():
				if filho.name.to_lower().begins_with("fase"):
					filho.visible = (filho.name.to_lower() == dados["pasta"])

func _configurar_containers() -> void:
	for cont in [container_em_pe, container_deitada]:
		if cont != null:
			cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cont.offset_left = 10.0
			cont.offset_right = -95.0 if cont == container_em_pe else -10.0
			cont.offset_top = 75.0
			cont.offset_bottom = -85.0
			cont.add_theme_constant_override("separation", 170)
			
			for filho in cont.get_children():
				if filho is TextureRect:
					filho.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					filho.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					filho.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					filho.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _montar_fila_de_fases() -> void:
	_fila_fases.clear()
	
	for i in range(deitadas_com_erros.size()):
		var orig: Texture2D = deitadas_originais[i] if i < deitadas_originais.size() else null
		_fila_fases.append({
			"em_pe": false,
			"pasta": "fase" + str(i + 1),
			"original": orig,
			"errada": deitadas_com_erros[i]
		})
		
	for i in range(em_pe_com_erros.size()):
		var orig: Texture2D = em_pe_originais[i] if i < em_pe_originais.size() else null
		_fila_fases.append({
			"em_pe": true,
			"pasta": "fase" + str(i + 1),
			"original": orig,
			"errada": em_pe_com_erros[i]
		})
func _reiniciar_tudo() -> void:
	_historico_acertos.clear()
	_historico_totais.clear()
	_iniciar_fase(0)

func _criar_ui_dinamica() -> void:
	_camada_ui = CanvasLayer.new()
	_camada_ui.layer = 10
	add_child(_camada_ui)
	
	_label_titulo_certa = _fabricar_titulo("CERTA", Color(0.2, 0.95, 0.35, 1.0))
	_camada_ui.add_child(_label_titulo_certa)
	
	_label_titulo_errada = _fabricar_titulo("ERRADA", Color(1.0, 0.3, 0.3, 1.0))
	_camada_ui.add_child(_label_titulo_errada)
	
	for lbl in [label_erros, label_tempo]:
		if lbl != null:
			if lbl.get_parent() != _camada_ui:
				lbl.reparent(_camada_ui)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", tamanho_fonte_hud)
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 4)
			if fonte_personalizada != null:
				lbl.add_theme_font_override("font", fonte_personalizada)
	
	_botao_enviar = Button.new()
	_botao_enviar.text = "ENVIAR RESPOSTAS"
	_botao_enviar.custom_minimum_size = Vector2(240, 52)
	_botao_enviar.add_theme_font_size_override("font_size", 20)
	if fonte_personalizada != null:
		_botao_enviar.add_theme_font_override("font", fonte_personalizada)
	_botao_enviar.visible = false
	_botao_enviar.pressed.connect(_ao_clicar_enviar)
	_camada_ui.add_child(_botao_enviar)
	
	_painel_resultado = PanelContainer.new()
	_painel_resultado.custom_minimum_size = Vector2(480, 240)
	_painel_resultado.visible = false
	
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	estilo.border_color = Color(1.0, 0.85, 0.2, 1.0)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(14)
	estilo.set_content_margin_all(24)
	_painel_resultado.add_theme_stylebox_override("panel", estilo)
	_camada_ui.add_child(_painel_resultado)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_painel_resultado.add_child(vbox)
	
	_label_resultado = Label.new()
	_label_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_resultado.add_theme_font_size_override("font_size", 22)
	if fonte_personalizada != null:
		_label_resultado.add_theme_font_override("font", fonte_personalizada)
	vbox.add_child(_label_resultado)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(hbox)
	
	_btn_avancar = Button.new()
	_btn_avancar.text = "Avançar"
	_btn_avancar.custom_minimum_size = Vector2(140, 48)
	_btn_avancar.add_theme_font_size_override("font_size", 18)
	_btn_avancar.pressed.connect(func(): _iniciar_fase(indice_fase_atual + 1))
	hbox.add_child(_btn_avancar)
	
	_btn_repetir = Button.new()
	_btn_repetir.text = "Repetir"
	_btn_repetir.custom_minimum_size = Vector2(140, 48)
	_btn_repetir.add_theme_font_size_override("font_size", 18)
	_btn_repetir.pressed.connect(_ao_clicar_repetir)
	hbox.add_child(_btn_repetir)
	
	_btn_sair = Button.new()
	_btn_sair.text = "Sair"
	_btn_sair.custom_minimum_size = Vector2(140, 48)
	_btn_sair.add_theme_font_size_override("font_size", 18)
	_btn_sair.pressed.connect(_ao_clicar_sair)
	hbox.add_child(_btn_sair)

func _fabricar_titulo(texto: String, cor: Color) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", cor)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	if fonte_personalizada != null:
		lbl.add_theme_font_override("font", fonte_personalizada)
	return lbl

func _iniciar_fase(indice: int) -> void:
	if _fila_fases.is_empty():
		return
		
	indice_fase_atual = indice
	fase_encerrada = false
	tempo_restante = tempo_por_imagem
	_botao_enviar.visible = false
	_painel_resultado.visible = false
	
	_limpar_elementos()
	
	var dados_fase: Dictionary = _fila_fases[indice]
	_modo_em_pe = dados_fase["em_pe"]
	
	container_em_pe.visible = _modo_em_pe
	container_deitada.visible = not _modo_em_pe
	
	var container_ativo: Container = container_em_pe if _modo_em_pe else container_deitada
	_img_certa_ativa = container_ativo.get_child(0) as TextureRect
	_img_errada_ativa = container_ativo.get_child(1) as TextureRect
	
	_img_certa_ativa.texture = dados_fase["original"]
	_img_errada_ativa.texture = dados_fase["errada"]
		
	await get_tree().process_frame
	_posicionar_titulos_imagens()
	_carregar_gabarito_fase(dados_fase["pasta"])
	_criar_circulos_bandeja()
	_atualizar_hud()

func _posicionar_titulos_imagens() -> void:
	var r_certa := Rect2()
	var r_errada := Rect2()
	
	if _img_certa_ativa != null:
		r_certa = _obter_retangulo_real_desenho(_img_certa_ativa)
		_label_titulo_certa.size = Vector2(r_certa.size.x, 36)
		_label_titulo_certa.position = Vector2(r_certa.position.x, maxf(42.0, r_certa.position.y - 38.0))
		
	if _img_errada_ativa != null:
		r_errada = _obter_retangulo_real_desenho(_img_errada_ativa)
		_label_titulo_errada.size = Vector2(r_errada.size.x, 36)
		_label_titulo_errada.position = Vector2(r_errada.position.x, maxf(42.0, r_errada.position.y - 38.0))
		
	if r_certa.size.x > 0 and r_errada.size.x > 0:
		var centro_x: float = (r_certa.end.x + r_errada.position.x) * 0.5
		var centro_y: float = (r_certa.position.y + r_certa.end.y) * 0.5
		var largura_caixa: float = 160.0
		
		if label_tempo != null:
			label_tempo.size = Vector2(largura_caixa, 65)
			label_tempo.position = Vector2(centro_x - (largura_caixa * 0.5), centro_y - 70.0)
		if label_erros != null:
			label_erros.size = Vector2(largura_caixa, 75)
			label_erros.position = Vector2(centro_x - (largura_caixa * 0.5), centro_y + 5.0)
func _limpar_elementos() -> void:
	for c in _circulos_bandeja:
		if is_instance_valid(c): c.queue_free()
	_circulos_bandeja.clear()
	_circulos_colocados.clear()

func _carregar_gabarito_fase(nome_pasta: String) -> void:
	_pontos_gabarito.clear()
	var alvo_lower: String = nome_pasta.to_lower()
	var container_pontos: Node = null
	
	for filho in _img_errada_ativa.get_children():
		if filho.name.to_lower().begins_with("fase"):
			var eh_atual: bool = (filho.name.to_lower() == alvo_lower)
			if "visible" in filho:
				filho.visible = eh_atual
			if eh_atual:
				container_pontos = filho
				
	if container_pontos == null:
		container_pontos = _img_errada_ativa
		
	var rect_desenho: Rect2 = _obter_retangulo_real_desenho(_img_errada_ativa)
	for ponto in container_pontos.get_children():
		if ponto is Node2D or ponto is Control:
			if rect_desenho.size.x > 0 and rect_desenho.size.y > 0:
				var pos_norm: Vector2 = (ponto.global_position - rect_desenho.position) / rect_desenho.size
				_pontos_gabarito.append(pos_norm)

func _obter_retangulo_real_desenho(tex_rect: TextureRect) -> Rect2:
	if tex_rect == null:
		return Rect2()
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
	var qtd: int = max(1, _pontos_gabarito.size())
	var tela: Vector2 = get_viewport_rect().size
	var rect_errada: Rect2 = _obter_retangulo_real_desenho(_img_errada_ativa)
	
	var espacamento_horiz: float = 64.0
	var espacamento_vert: float = espacamento_vertical_em_pe
	var total_span_horiz: float = (qtd - 1) * espacamento_horiz
	var total_span_vert: float = (qtd - 1) * espacamento_vert

	for i in range(qtd):
		var circulo := _fabricar_circulo(Color(1.0, 0.85, 0.1, 1.0), Color(1.0, 0.85, 0.1, 0.25))
		var pos_ini := Vector2.ZERO
		
		if _modo_em_pe:
			var pos_x: float = minf(tela.x - (raio_circulo * 2.0) - 15.0, rect_errada.end.x + margem_lateral_em_pe)
			var inicio_y: float = rect_errada.position.y + (rect_errada.size.y - total_span_vert) * 0.5 - raio_circulo
			pos_ini = Vector2(pos_x, inicio_y + (i * espacamento_vert))
		else:
			var inicio_x: float = (tela.x - total_span_horiz) * 0.5 - raio_circulo
			pos_ini = Vector2(inicio_x + (i * espacamento_horiz), tela.y - 75.0)
			
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
	if fase_encerrada:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_circulo_arrastando = circulo
			_offset_arrasto = get_global_mouse_position() - circulo.global_position
			circulo.z_index = 30
		elif _circulo_arrastando == circulo:
			circulo.z_index = 10
			_circulo_arrastando = null
			_atualizar_posicao_circulo(circulo)

func _atualizar_posicao_circulo(circulo: Panel) -> void:
	var centro: Vector2 = circulo.global_position + Vector2(raio_circulo, raio_circulo)
	var rect_errada: Rect2 = _obter_retangulo_real_desenho(_img_errada_ativa)
	
	if rect_errada.has_point(centro):
		circulo.set_meta("colocado", true)
		_atualizar_cor_circulo(circulo, Color(0.2, 0.7, 1.0, 1.0), Color(0.2, 0.7, 1.0, 0.25))
		if not (circulo in _circulos_colocados):
			_circulos_colocados.append(circulo)
		_tocar_som(som_colocar)
	else:
		circulo.set_meta("colocado", false)
		_circulos_colocados.erase(circulo)
		_atualizar_cor_circulo(circulo, Color(1.0, 0.85, 0.1, 1.0), Color(1.0, 0.85, 0.1, 0.25))
		var tween := create_tween()
		tween.tween_property(circulo, "position", circulo.get_meta("pos_inicial"), 0.2)
		
	_atualizar_hud()
	
	if _circulos_colocados.size() >= _pontos_gabarito.size():
		var tela: Vector2 = get_viewport_rect().size
		_botao_enviar.position = Vector2((tela.x - _botao_enviar.size.x) * 0.5, tela.y - 72.0)
		_botao_enviar.visible = true
	else:
		_botao_enviar.visible = false

func _ao_clicar_enviar() -> void:
	if fase_encerrada:
		return
	fase_encerrada = true
	_botao_enviar.visible = false
	
	var rect_errada: Rect2 = _obter_retangulo_real_desenho(_img_errada_ativa)
	var pontos_usados: Array[int] = []
	var acertos_na_imagem: int = 0
	
	for circulo in _circulos_colocados:
		var centro: Vector2 = circulo.global_position + Vector2(raio_circulo, raio_circulo)
		var acertou: bool = false
		
		for i in range(_pontos_gabarito.size()):
			if i in pontos_usados:
				continue
			var pos_gabarito: Vector2 = rect_errada.position + (_pontos_gabarito[i] * rect_errada.size)
			if centro.distance_to(pos_gabarito) <= distancia_acerto:
				acertou = true
				pontos_usados.append(i)
				break
				
		if acertou:
			acertos_na_imagem += 1
			_atualizar_cor_circulo(circulo, Color(0.1, 0.9, 0.2, 1.0), Color(0.1, 0.9, 0.2, 0.3))
		else:
			_atualizar_cor_circulo(circulo, Color(0.95, 0.15, 0.15, 1.0), Color(0.95, 0.15, 0.15, 0.3))
			
	var total_img: int = _pontos_gabarito.size()
	var erros_img: int = total_img - acertos_na_imagem
	var acertou_tudo: bool = (acertos_na_imagem == total_img)
	
	if _historico_acertos.size() <= indice_fase_atual:
		_historico_acertos.append(acertos_na_imagem)
		_historico_totais.append(total_img)
	else:
		_historico_acertos[indice_fase_atual] = acertos_na_imagem
		_historico_totais[indice_fase_atual] = total_img
		
	_tocar_som(som_acerto if acertou_tudo else som_erro)
	await get_tree().create_timer(1.2).timeout
	
	var eh_ultima: bool = (indice_fase_atual + 1) >= _fila_fases.size()
	if acertou_tudo and eh_ultima:
		_exibir_resumo_final()
	else:
		_exibir_opcoes_fase(acertou_tudo, acertos_na_imagem, erros_img)

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

func _ao_clicar_repetir() -> void:
	if _btn_repetir.text == "Repetir Tudo":
		_reiniciar_tudo()
	else:
		_iniciar_fase(indice_fase_atual)

func _ao_clicar_sair() -> void:
	if cena_mundo_principal != "" and ResourceLoader.exists(cena_mundo_principal):
		get_tree().change_scene_to_file.call_deferred(cena_mundo_principal)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or fase_encerrada:
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
	var total_fases: int = max(1, _fila_fases.size())
	if label_erros != null:
		label_erros.text = "Fase %d/%d\nMarcados: %d/%d" % [
			indice_fase_atual + 1, total_fases, _circulos_colocados.size(), _pontos_gabarito.size()
		]
	if label_tempo != null:
		var seg_totais: int = int(tempo_restante)
		var min_rest: int = int(seg_totais / 60.0)
		var seg_rest: int = seg_totais % 60
		label_tempo.text = "Tempo\n%02d:%02d" % [min_rest, seg_rest]

func _tocar_som(audio: AudioStream) -> void:
	if audio != null and _player_som != null:
		_player_som.stream = audio
		_player_som.play()
