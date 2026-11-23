extends Node2D

@onready var cutscene_player: AnimationPlayer = $CutscenePlayer
@onready var spell: CharacterBody2D = $spell
@onready var july: CharacterBody2D = $july

@onready var caixa_dialogo: PanelContainer = $HUD_Dialogo/CaixaDialogo
@onready var retrato: TextureRect = $HUD_Dialogo/CaixaDialogo/HBoxContainer/Retrato
@onready var texto_fala: RichTextLabel = $HUD_Dialogo/CaixaDialogo/HBoxContainer/TextoFala

# =========================
# ROSTOS DA JULY (Arraste no Inspetor)
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

var falas: Array[Dictionary] = []
var indice_fala: int = 0
var falando: bool = false
var _tecla_avancar_pressionada: bool = false
var _em_cutscene_animada: bool = false

func _ready() -> void:
	caixa_dialogo.visible = false
	
	# Cutscene inicial da fase
	spell.em_cutscene = true
	spell.sprite.flip_h = false
	_em_cutscene_animada = true
	cutscene_player.play("intro_july")

func _process(_delta: float) -> void:
	var apertou_avancar: bool = Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_E)
	
	if falando and apertou_avancar:
		if not _tecla_avancar_pressionada:
			_tecla_avancar_pressionada = true
			indice_fala += 1
			if indice_fala < falas.size():
				mostrar_fala_atual()
			else:
				encerrar_dialogo()
	else:
		_tecla_avancar_pressionada = false

# Mapeia o nome da expressão para a textura correspondente
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

# 1. Chamada pela animação inicial (AnimationPlayer)
func iniciar_conversa_july() -> void:
	cutscene_player.pause()
	falas = [
		{"rosto": rosto_july_assustada, "texto": "Ai! Que susto!"},
		{"rosto": rosto_july_normal, "texto": "O que é você?"},
		{"rosto": rosto_july_normal, "texto": "Você, não tem nome?"},
		{"rosto": rosto_july_feliz, "texto": "Já SEI!!, vou te chamar de SPELL."},
		{"rosto": rosto_july_megaF, "texto": "Gostou?, que bom."},
	]
	abrir_caixa()

# 2. Chamada pelas Áreas espalhadas pelo mapa
func iniciar_encontro_area(novas_falas: Array[Dictionary], vir_da_esquerda: bool = true) -> void:
	_em_cutscene_animada = false
	
	spell.em_cutscene = true
	july.em_cutscene = true
	july.velocity = Vector2.ZERO
	
	var distancia_surgimento: float = 880.0
	var distancia_parada: float = 130.0
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
	
	texto_fala.visible_ratio = 0.0
	var tween = create_tween()
	tween.tween_property(texto_fala, "visible_ratio", 1.0, 0.8)

func encerrar_dialogo() -> void:
	falando = false
	caixa_dialogo.visible = false
	
	if _em_cutscene_animada:
		cutscene_player.play()
	else:
		spell.em_cutscene = false
		july.em_cutscene = false
