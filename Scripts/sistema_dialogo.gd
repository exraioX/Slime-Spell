extends Node

@export_group("Referências da Fase")
@export var spell: CharacterBody2D
@export var july: CharacterBody2D
@export var cutscene_player: AnimationPlayer

@onready var som_fala: AudioStreamPlayer = $SomFala
@onready var hud_dialogo: CanvasLayer = $HUD_Dialogo
@onready var caixa_dialogo: PanelContainer = $HUD_Dialogo/CaixaDialogo
@onready var retrato: TextureRect = $HUD_Dialogo/CaixaDialogo/HBoxContainer/Retrato
@onready var texto_fala: RichTextLabel = $HUD_Dialogo/CaixaDialogo/HBoxContainer/TextoFala

# =========================
# ROSTOS DA JULY
# =========================
@export_group("Expressões da July")
@export var rosto_july_normal: Texture2D
@export var rosto_july_assustada: Texture2D
@export var rosto_july_feliz: Texture2D
@export var rosto_july_megaF: Texture2D
@export var rosto_july_passifica: Texture2D
@export var rosto_july_pistola: Texture2D
@export var rosto_july_preocupada: Texture2D
@export var rosto_july_zangada: Texture2D

# =========================
# FALAS DA CUTSCENE INICIAL
# =========================
@export_group("Cutscene Inicial")
@export var tocar_intro_ao_iniciar: bool = true
@export_multiline var textos_intro: Array[String] = [
	"Ai! Que susto!",
	"O que é você?",
	"Você, não tem nome?",
	"Já SEI!!, vou te chamar de SPELL.",
	"Gostou?, que bom."
]
@export var expressoes_intro: Array[String] = [
	"assustada",
	"normal",
	"normal",
	"feliz",
	"megaF"
]

# =========================
# CONFIGURAÇÕES DE PULO, VOZ E CÂMERA FAROESTE
# =========================
@export_group("Configurações de Diálogo")
@export var tempo_segurar_pular_tudo: float = 0.65
@export var intervalo_letras_som: int = 3

@export_group("Câmera e Cinema (Faroeste)")
@export var altura_barra_topo: float = 95.0
@export var altura_barra_base: float = 160.0
@export var zoom_cutscene: Vector2 = Vector2(0.95, 0.95)
@export var intensidade_balanco: float = 4.5
@export var velocidade_balanco: float = 2.2

var falas: Array[Dictionary] = []
var indice_fala: int = 0
var falando: bool = false
var _em_cutscene_ativa: bool = false
var _em_cutscene_animada: bool = false

# Controle do botão Espaço (clique vs segurar)
var _espaco_pressionado_antes: bool = false
var _tempo_segurando_espaco: float = 0.0
var _ja_pulou_neste_aperto: bool = false

# Controle de digitação e som
var _ultimo_char_som: int = -1
var _tween_digitacao: Tween = null
var _digitando: bool = false

# Elementos de cinema e câmera
var _barra_topo: ColorRect
var _barra_base: ColorRect
var _camera_spell: Camera2D
var _zoom_original: Vector2 = Vector2(0.8, 0.8)
var _tempo_balanco: float = 0.0

func _ready() -> void:
	caixa_dialogo.visible = false
	add_to_group("gerenciador_dialogo")
	_criar_barras_cinema()
	
	if spell != null and spell.has_node("Camera2D"):
		_camera_spell = spell.get_node("Camera2D")
		_zoom_original = _camera_spell.zoom
	
	if tocar_intro_ao_iniciar and cutscene_player != null and spell != null:
		spell.em_cutscene = true
		spell.sprite.flip_h = false
		_em_cutscene_animada = true
		ativar_modo_cinema(true)
		cutscene_player.play("intro_july")

func _process(delta: float) -> void:
	# 1. Efeito de câmera balançando estilo faroeste enquanto a cutscene estiver ativa
	if _em_cutscene_ativa and _camera_spell != null:
		_tempo_balanco += delta * velocidade_balanco
		var balanco_x: float = sin(_tempo_balanco) * intensidade_balanco
		var balanco_y: float = cos(_tempo_balanco * 1.4) * (intensidade_balanco * 0.6)
		_camera_spell.offset = Vector2(balanco_x, balanco_y)

	# 2. Controle unificado da tecla ESPAÇO (Clique = avança fala | Segurar = pula tudo)
	if not _em_cutscene_ativa:
		return

	var espaco_atual: bool = Input.is_physical_key_pressed(KEY_SPACE)

	if espaco_atual:
		if not _espaco_pressionado_antes:
			_tempo_segurando_espaco = 0.0
			_ja_pulou_neste_aperto = false
		else:
			_tempo_segurando_espaco += delta
			if _tempo_segurando_espaco >= tempo_segurar_pular_tudo and not _ja_pulou_neste_aperto:
				_ja_pulou_neste_aperto = true
				pular_toda_a_cena()
	else:
		if _espaco_pressionado_antes and not _ja_pulou_neste_aperto and falando:
			_tratar_clique_avancar_fala()
		_tempo_segurando_espaco = 0.0

	_espaco_pressionado_antes = espaco_atual
func _tratar_clique_avancar_fala() -> void:
	if _digitando and _tween_digitacao != null and _tween_digitacao.is_valid():
		_tween_digitacao.kill()
		texto_fala.visible_characters = texto_fala.get_total_character_count()
		_digitando = false
		return

	indice_fala += 1
	if indice_fala < falas.size():
		mostrar_fala_atual()
	else:
		encerrar_dialogo()

func pular_toda_a_cena() -> void:
	if _tween_digitacao != null and _tween_digitacao.is_valid():
		_tween_digitacao.kill()
	
	falando = false
	_digitando = false
	caixa_dialogo.visible = false
	
	if _em_cutscene_animada and cutscene_player != null:
		var fim_animacao: float = cutscene_player.current_animation_length
		cutscene_player.seek(fim_animacao, true)
		cutscene_player.stop()
	
	_em_cutscene_animada = false
	ativar_modo_cinema(false)
	
	if spell != null:
		spell.em_cutscene = false
	if july != null:
		july.em_cutscene = false
		july.velocity = Vector2.ZERO
		july.tocar_animacao("idle")

func _criar_barras_cinema() -> void:
	_barra_topo = ColorRect.new()
	_barra_topo.color = Color.BLACK
	_barra_topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_barra_topo.size.y = altura_barra_topo
	_barra_topo.position.y = -altura_barra_topo
	hud_dialogo.add_child(_barra_topo)
	hud_dialogo.move_child(_barra_topo, 0)

	_barra_base = ColorRect.new()
	_barra_base.color = Color.BLACK
	_barra_base.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_barra_base.size.y = altura_barra_base
	_barra_base.offset_top = 0
	_barra_base.offset_bottom = altura_barra_base
	hud_dialogo.add_child(_barra_base)
	hud_dialogo.move_child(_barra_base, 0)

func ativar_modo_cinema(ativar: bool) -> void:
	_em_cutscene_ativa = ativar
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if ativar:
		tween.tween_property(_barra_topo, "position:y", 0.0, 0.4)
		tween.tween_property(_barra_base, "offset_top", -altura_barra_base, 0.4)
		tween.tween_property(_barra_base, "offset_bottom", 0.0, 0.4)
		if _camera_spell != null:
			tween.tween_property(_camera_spell, "zoom", zoom_cutscene, 0.75)
	else:
		tween.tween_property(_barra_topo, "position:y", -altura_barra_topo, 0.4)
		tween.tween_property(_barra_base, "offset_top", 0.0, 0.4)
		tween.tween_property(_barra_base, "offset_bottom", altura_barra_base, 0.4)
		if _camera_spell != null:
			tween.tween_property(_camera_spell, "zoom", _zoom_original, 0.69)
			tween.tween_property(_camera_spell, "offset", Vector2.ZERO, 0.3)

func obter_rosto(nome_expressao: String) -> Texture2D:
	var mapa_rostos: Dictionary = {
		"normal": rosto_july_normal,
		"assustada": rosto_july_assustada,
		"feliz": rosto_july_feliz,
		"megaF": rosto_july_megaF,
		"passifica": rosto_july_passifica,
		"pistola": rosto_july_pistola,
		"preocupada": rosto_july_preocupada,
		"zangada": rosto_july_zangada
	}
	return mapa_rostos.get(nome_expressao, rosto_july_normal)

func montar_lista_falas(textos: Array[String], expressoes: Array[String]) -> Array[Dictionary]:
	var lista_formatada: Array[Dictionary] = []
	for i in range(textos.size()):
		var exp_nome: String = expressoes[i] if i < expressoes.size() else "normal"
		lista_formatada.append({
			"rosto": obter_rosto(exp_nome),
			"texto": textos[i]
		})
	return lista_formatada

func iniciar_conversa_july() -> void:
	if falando or not _em_cutscene_ativa:
		return
	if cutscene_player != null:
		cutscene_player.pause()
	falas = montar_lista_falas(textos_intro, expressoes_intro)
	abrir_caixa()

func iniciar_encontro_area(novas_falas: Array[Dictionary], vir_da_esquerda: bool = true) -> void:
	if spell == null or july == null:
		return
		
	_em_cutscene_animada = false
	spell.em_cutscene = true
	july.em_cutscene = true
	july.velocity = Vector2.ZERO
	ativar_modo_cinema(true)
	
	var distancia_surgimento: float = 880.0
	var distancia_parada: float = 30.0
	var tempo_caminhada: float = 1.2
	
	var lado: float = -1.0 if vir_da_esquerda else 1.0
	var pos_inicial_x: float = spell.global_position.x + (lado * distancia_surgimento)
	var pos_final_x: float = spell.global_position.x + (lado * distancia_parada)
	
	july.global_position = Vector2(pos_inicial_x, spell.global_position.y)
	july.sprite.flip_h = not vir_da_esquerda
	spell.sprite.flip_h = vir_da_esquerda
	
	july.tocar_animacao("walk")
	var tween_movimento = create_tween()
	tween_movimento.tween_property(july, "global_position:x", pos_final_x, tempo_caminhada)
	
	await tween_movimento.finished
	
	if not _em_cutscene_ativa:
		return
		
	july.tocar_animacao("idle")
	falas = novas_falas
	abrir_caixa()

func abrir_caixa() -> void:
	indice_fala = 0
	falando = true
	caixa_dialogo.visible = true
	mostrar_fala_atual()

func mostrar_fala_atual() -> void:
	var dados = falas[indice_fala]
	retrato.texture = dados["rosto"]
	texto_fala.text = dados["texto"]
	
	var total_letras: int = texto_fala.get_total_character_count()
	texto_fala.visible_characters = 0
	_ultimo_char_som = -1
	_digitando = true
	
	if _tween_digitacao != null and _tween_digitacao.is_valid():
		_tween_digitacao.kill()
		
	var duracao: float = clampf(total_letras * 0.03, 0.3, 1.2)
	_tween_digitacao = create_tween()
	_tween_digitacao.tween_method(_atualizar_digitacao_com_som, 0, total_letras, duracao)
	_tween_digitacao.finished.connect(func(): _digitando = false)

func _atualizar_digitacao_com_som(qtd_atual: int) -> void:
	texto_fala.visible_characters = qtd_atual
	if qtd_atual > 0 and qtd_atual != _ultimo_char_som:
		if qtd_atual % intervalo_letras_som == 0:
			_ultimo_char_som = qtd_atual
			_tocar_bip_voz()

func _tocar_bip_voz() -> void:
	if som_fala != null and som_fala.stream != null:
		som_fala.pitch_scale = randf_range(0.95, 1.12)
		som_fala.play()

func encerrar_dialogo() -> void:
	falando = false
	_digitando = false
	caixa_dialogo.visible = false
	ativar_modo_cinema(false)
	
	if _em_cutscene_animada and cutscene_player != null:
		cutscene_player.play()
	else:
		if spell != null: spell.em_cutscene = false
		if july != null: july.em_cutscene = false
