extends Control

@export_group("Navegação entre Fases")
@export_file("*.tscn") var proxima_fase: String = ""
@export_file("*.tscn") var cena_mundo_principal: String = "res://Cenas/principal.tscn"

@export_group("Configurações da Fase")
@export var numero_fase: int = 1
@export var total_fases: int = 3
@export var total_erros: int = 7
@export var tempo_limite: float = 120.0
@export var raio_circulo: float = 26.0
@export var distancia_encaixe: float = 38.0

@export_group("Áudios")
@export var som_acerto: AudioStream
@export var som_erro: AudioStream

@onready var imagem_original: TextureRect = $ContainerImagens/ImagemOriginal
@onready var imagem_com_erros: TextureRect = $ContainerImagens/ImagemComErros
@onready var area_erros: Control = $ContainerImagens/ImagemComErros/AreaErros
@onready var label_erros: Label = $HUD/LabelErros
@onready var label_tempo: Label = $HUD/LabelTempo
@onready var label_final: Label = $LabelMensagemFinal

var erros_encontrados: int = 0
var tempo_restante: float = 0.0
var fase_encerrada: bool = false

var _pontos_erro: Array[Dictionary] = []
var _circulos: Array[Panel] = []
var _circulo_arrastando: Panel = null
var _offset_arrasto: Vector2 = Vector2.ZERO
var _player_som: AudioStreamPlayer

func _ready() -> void:
	tempo_restante = tempo_limite
	if label_final != null:
		label_final.visible = false
		
	_player_som = AudioStreamPlayer.new()
	add_child(_player_som)
	
	# Aguarda 1 frame para os containers centralizarem as imagens na tela
	await get_tree().process_frame
	_coletar_pontos_de_erro()
	_criar_circulos_arrastaveis()
	_atualizar_hud()

func _coletar_pontos_de_erro() -> void:
	_pontos_erro.clear()
	for filho in area_erros.get_children():
		if filho is Node2D or filho is Control:
			_pontos_erro.append({
				"pos_local": filho.position,
				"encontrado": false
			})

func _criar_circulos_arrastaveis() -> void:
	var tela_tam: Vector2 = get_viewport_rect().size
	var espacamento: float = 75.0
	var largura_total: float = (total_erros - 1) * espacamento
	var inicio_x: float = (tela_tam.x - largura_total) * 0.5 - raio_circulo
	var pos_y: float = tela_tam.y - 95.0

	for i in range(total_erros):
		var circulo := _fabricar_visual_circulo(Color(1.0, 0.85, 0.1, 1.0), Color(1.0, 0.85, 0.1, 0.25))
		var pos_inicial := Vector2(inicio_x + (i * espacamento), pos_y)
		circulo.position = pos_inicial
		circulo.z_index = 20
		circulo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		circulo.set_meta("pos_inicial", pos_inicial)
		circulo.set_meta("travado", false)
		
		circulo.gui_input.connect(_ao_interagir_circulo.bind(circulo))
		add_child(circulo)
		_circulos.append(circulo)

func _fabricar_visual_circulo(cor_borda: Color, cor_fundo: Color) -> Panel:
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
	if fase_encerrada or circulo.get_meta("travado"):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_circulo_arrastando = circulo
			_offset_arrasto = get_global_mouse_position() - circulo.global_position
			circulo.z_index = 30
		elif _circulo_arrastando == circulo:
			circulo.z_index = 20
			_circulo_arrastando = null
			_verificar_encaixe(circulo)

func _process(delta: float) -> void:
	if fase_encerrada:
		return
		
	if _circulo_arrastando != null:
		_circulo_arrastando.global_position = get_global_mouse_position() - _offset_arrasto
		
	tempo_restante -= delta
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		_encerrar_fase(false)
		
	_atualizar_hud()

func _verificar_encaixe(circulo: Panel) -> void:
	var centro_circulo_global: Vector2 = circulo.global_position + Vector2(raio_circulo, raio_circulo)
	var rect_modificada: Rect2 = imagem_com_erros.get_global_rect()
	
	# Verifica se o jogador soltou o círculo em cima da imagem com erros
	if rect_modificada.has_point(centro_circulo_global):
		var pos_relativa: Vector2 = centro_circulo_global - rect_modificada.position
		
		for ponto in _pontos_erro:
			if not ponto["encontrado"] and pos_relativa.distance_to(ponto["pos_local"]) <= distancia_encaixe:
				_confirmar_acerto(circulo, ponto)
				return
				
		# Soltou dentro da imagem, mas longe dos 7 pontinhos: penaliza e devolve o círculo
		tempo_restante = maxf(0.0, tempo_restante - 3.0)
		_tocar_som(som_erro)
		
	_devolver_circulo(circulo)

func _confirmar_acerto(circulo: Panel, ponto: Dictionary) -> void:
	ponto["encontrado"] = true
	circulo.set_meta("travado", true)
	circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Encaixa o círculo perfeitamente centralizado no ponto do erro e muda a cor para verde
	var pos_alvo_global: Vector2 = imagem_com_erros.get_global_rect().position + ponto["pos_local"] - Vector2(raio_circulo, raio_circulo)
	circulo.global_position = pos_alvo_global
	_atualizar_cor_circulo(circulo, Color(0.1, 0.9, 0.2, 1.0), Color(0.1, 0.9, 0.2, 0.2))
	
	# Cria também um círculo verde espelhado na imagem original
	var espelho := _fabricar_visual_circulo(Color(0.1, 0.9, 0.2, 1.0), Color(0.1, 0.9, 0.2, 0.2))
	espelho.position = ponto["pos_local"] - Vector2(raio_circulo, raio_circulo)
	espelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	imagem_original.add_child(espelho)
	
	erros_encontrados += 1
	_tocar_som(som_acerto)
	_atualizar_hud()
	
	if erros_encontrados >= total_erros:
		_encerrar_fase(true)

func _devolver_circulo(circulo: Panel) -> void:
	var tween := create_tween()
	tween.tween_property(circulo, "position", circulo.get_meta("pos_inicial"), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _atualizar_cor_circulo(circulo: Panel, cor_borda: Color, cor_fundo: Color) -> void:
	var estilo: StyleBoxFlat = circulo.get_theme_stylebox("panel").duplicate()
	estilo.border_color = cor_borda
	estilo.bg_color = cor_fundo
	circulo.add_theme_stylebox_override("panel", estilo)

func _atualizar_hud() -> void:
	if label_erros != null:
		label_erros.text = "Imagem %d/%d | Erros: %d / %d" % [numero_fase, total_fases, erros_encontrados, total_erros]
	if label_tempo != null:
		var min_rest: int = int(tempo_restante) / 60
		var seg_rest: int = int(tempo_restante) % 60
		label_tempo.text = "Tempo: %02d:%02d" % [min_rest, seg_rest]

func _encerrar_fase(venceu: bool) -> void:
	fase_encerrada = true
	if label_final != null:
		label_final.visible = true
		if venceu:
			label_final.text = "MUITO BEM! Indo para a próxima imagem..." if proxima_fase != "" else "PARABÉNS! VOCÊ COMPLETOU TODAS AS IMAGENS!\nVoltando ao mapa..."
		else:
			label_final.text = "TEMPO ESGOTADO!\nTentando novamente..."
			
	await get_tree().create_timer(3.0).timeout
	
	if venceu:
		var destino: String = proxima_fase if proxima_fase != "" else cena_mundo_principal
		if destino != "" and ResourceLoader.exists(destino):
			get_tree().change_scene_to_file.call_deferred(destino)
	else:
		get_tree().reload_current_scene()

func _tocar_som(audio: AudioStream) -> void:
	if audio != null and _player_som != null:
		_player_som.stream = audio
		_player_som.play()
