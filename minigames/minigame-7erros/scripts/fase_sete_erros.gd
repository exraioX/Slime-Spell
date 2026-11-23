extends Control

@export_group("Navegação entre Fases")
## Coloque aqui a cena da próxima imagem. Na última fase, deixe vazio para voltar ao mapa principal.
@export_file("*.tscn") var proxima_fase: String = ""
@export_file("*.tscn") var cena_mundo_principal: String = "res://Cenas/principal.tscn"

@export_group("Configurações da Fase")
@export var numero_fase: int = 1
@export var total_fases: int = 3
@export var total_erros: int = 7
@export var tempo_limite: float = 120.0
@export var permitir_clicar_nas_duas_imagens: bool = true

@export_group("Áudios")
@export var som_acerto: AudioStream
@export var som_erro_clique: AudioStream

@onready var imagem_original: TextureRect = $ContainerImagens/ImagemOriginal
@onready var imagem_com_erros: TextureRect = $ContainerImagens/ImagemComErros
@onready var area_erros: Control = $ContainerImagens/ImagemComErros/AreaErros
@onready var label_erros: Label = $HUD/LabelErros
@onready var label_tempo: Label = $HUD/LabelTempo
@onready var label_final: Label = $LabelMensagemFinal

var erros_encontrados: int = 0
var tempo_restante: float = 0.0
var fase_encerrada: bool = false
var _player_som: AudioStreamPlayer

func _ready() -> void:
	tempo_restante = tempo_limite
	if label_final != null:
		label_final.visible = false
		
	_player_som = AudioStreamPlayer.new()
	add_child(_player_som)
	
	_configurar_botoes_erros()
	_atualizar_hud()

func _configurar_botoes_erros() -> void:
	for botao in area_erros.get_children():
		if botao is BaseButton:
			botao.modulate.a = 0.0
			botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			botao.pressed.connect(_ao_encontrar_erro.bind(botao))
			
			# Se ativado, duplica o botão invisível na imagem original para aceitar clique nos dois lados
			if permitir_clicar_nas_duas_imagens:
				var botao_espelho := Button.new()
				botao_espelho.position = botao.position
				botao_espelho.size = botao.size
				botao_espelho.modulate.a = 0.0
				botao_espelho.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				imagem_original.add_child(botao_espelho)
				botao_espelho.pressed.connect(_ao_encontrar_erro.bind(botao))

func _process(delta: float) -> void:
	if fase_encerrada:
		return
		
	tempo_restante -= delta
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		_encerrar_fase(false)
		
	_atualizar_hud()

func _ao_encontrar_erro(botao_principal: BaseButton) -> void:
	if fase_encerrada or botao_principal.disabled:
		return
		
	botao_principal.disabled = true
	erros_encontrados += 1
	_tocar_som(som_acerto)
	
	# Desenha o círculo verde nas duas imagens exatamente na mesma posição
	var centro: Vector2 = botao_principal.position + (botao_principal.size / 2.0)
	_criar_marcador(imagem_com_erros, centro)
	_criar_marcador(imagem_original, centro)
	
	_atualizar_hud()
	
	if erros_encontrados >= total_erros:
		_encerrar_fase(true)

func _criar_marcador(pai: Control, pos_centro: Vector2) -> void:
	var painel := Panel.new()
	var raio: float = 28.0
	painel.size = Vector2(raio * 2, raio * 2)
	painel.position = pos_centro - Vector2(raio, raio)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 1, 0, 0.15)
	estilo.border_color = Color(0.1, 0.9, 0.2, 1.0)
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(int(raio))
	
	painel.add_theme_stylebox_override("panel", estilo)
	pai.add_child(painel)

func _unhandled_input(event: InputEvent) -> void:
	if fase_encerrada:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicou_orig: bool = permitir_clicar_nas_duas_imagens and imagem_original.get_global_rect().has_point(event.position)
		var clicou_mod: bool = imagem_com_erros.get_global_rect().has_point(event.position)
		
		if clicou_orig or clicou_mod:
			tempo_restante = maxf(0.0, tempo_restante - 3.0)
			_tocar_som(som_erro_clique)

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
			if proxima_fase != "":
				label_final.text = "MUITO BEM! Indo para a próxima imagem..."
			else:
				label_final.text = "PARABÉNS! VOCÊ COMPLETOU TODAS AS IMAGENS!\nVoltando ao mapa..."
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
