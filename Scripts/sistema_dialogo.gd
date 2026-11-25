extends Node2D

const ID_CUTSCENE_INICIAL: String = "cutscene_july_inicial"

@export_group("Referências da Fase")
@export var spell: CharacterBody2D
@export var july: CharacterBody2D
@export var cutscene_player: AnimationPlayer

@onready var som_fala: AudioStreamPlayer = $SomFala
@onready var hud_dialogo: CanvasLayer = $HUD_Dialogo
@onready var caixa_dialogo: PanelContainer = $HUD_Dialogo/CaixaDialogo
@onready var retrato: TextureRect = $HUD_Dialogo/CaixaDialogo/HBoxContainer/Retrato
@onready var texto_fala: RichTextLabel = $HUD_Dialogo/CaixaDialogo/HBoxContainer/TextoFala
@onready var barra_topo: ColorRect = $HUD_Dialogo/BarraTopo
@onready var barra_base: ColorRect = $HUD_Dialogo/BarraBase

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
@export var sons_voz: Array[AudioStream] = []
@export_range(-40.0, 6.0) var volume_voz_db: float = -22.0
@export_range(1, 10) var toques_min_por_dialogo: int = 2
@export_range(1, 10) var toques_max_por_dialogo: int = 3

@export_group("Câmera e Cinema (Faroeste)")
@export var zoom_cutscene: Vector2 = Vector2(1.1, 1.1)
@export var intensidade_balanco: float = 4.5
@export var velocidade_balanco: float = 2.2

@export_group("Encontro com a July")
@export var margem_fora_camera: float = 80.0
@export var distancia_parada_spell: float = 300.0
@export var velocidade_chegada_july: float = 220.0

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
var _dialogo_ativo_voz: bool = false
var _total_chars_dialogo: int = 0
var _chars_revelados_dialogo: int = 0
var _alvos_toque: Array[int] = []
var _proximo_alvo: int = 0
var _ultimo_som_voz: AudioStream = null
# Blips por fala: 1 obrigatório, no máximo 3, até o fim de cada fala
var _alvos_fala_atual: Array[int] = []
var _proximo_alvo_fala: int = 0

# Elementos de cinema e câmera
var _pos_topo_visivel: Vector2 = Vector2.ZERO
var _pos_base_visivel: Vector2 = Vector2.ZERO
var _camera_spell: Camera2D
var _zoom_original: Vector2 = Vector2(0.8, 0.8)
var _offset_original: Vector2 = Vector2.ZERO
var _tempo_balanco: float = 0.0

func _ready() -> void:
	caixa_dialogo.visible = false
	add_to_group("gerenciador_dialogo")
	_preparar_barras_cinema()
	
	if spell != null and spell.has_node("Camera2D"):
		_camera_spell = spell.get_node("Camera2D")
		_zoom_original = _camera_spell.zoom
		_offset_original = _camera_spell.offset

	if cutscene_player != null and not cutscene_player.animation_finished.is_connected(_on_cutscene_animation_finished):
		cutscene_player.animation_finished.connect(_on_cutscene_animation_finished)

	# A abertura animada só acontece uma vez, mesmo depois de sair e voltar à fase.
	if cutscene_player != null and spell != null and (Jogo.tocar_intro_principal or (tocar_intro_ao_iniciar and not Jogo.gatilho_foi_concluido(ID_CUTSCENE_INICIAL))):
		spell.em_cutscene = true
		spell.sprite.flip_h = false
		_em_cutscene_animada = true
		ativar_modo_cinema(true)
		cutscene_player.play("intro_july")
		Jogo.tocar_intro_principal = false

func _on_cutscene_animation_finished(nome_animacao: StringName) -> void:
	if nome_animacao == &"intro_july":
		Jogo.marcar_gatilho_concluido(ID_CUTSCENE_INICIAL)


func _process(delta: float) -> void:
	if _em_cutscene_ativa and _camera_spell != null:
		_tempo_balanco += delta * velocidade_balanco
		var balanco_x: float = sin(_tempo_balanco) * intensidade_balanco
		var balanco_y: float = cos(_tempo_balanco * 1.4) * (intensidade_balanco * 0.6)
		_camera_spell.offset = _offset_original + Vector2(balanco_x, balanco_y)

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
		_dialogo_ativo_voz = false
		_revelar_ate(texto_fala.get_total_character_count())
		_digitando = false
		return

	indice_fala += 1
	if indice_fala < falas.size():
		mostrar_fala_atual()
	else:
		encerrar_dialogo()

func pular_toda_a_cena() -> void:
	if _em_cutscene_animada:
		Jogo.marcar_gatilho_concluido(ID_CUTSCENE_INICIAL)
	if _tween_digitacao != null and _tween_digitacao.is_valid():
		_tween_digitacao.kill()

	if falando and caixa_dialogo.visible:
		_dialogo_ativo_voz = false
		_revelar_ate(texto_fala.get_total_character_count())
	_dialogo_ativo_voz = false
	_alvos_toque.clear()
	_alvos_fala_atual.clear()
	_proximo_alvo_fala = 0

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
		july.cancelar_caminhada()
		july.em_cutscene = false
		july.velocity = Vector2.ZERO
		july.tocar_animacao("idle")

func _preparar_barras_cinema() -> void:
	if barra_topo != null:
		_pos_topo_visivel = barra_topo.position
		barra_topo.position.y = _pos_topo_visivel.y - barra_topo.size.y
		barra_topo.visible = false
		
	if barra_base != null:
		_pos_base_visivel = barra_base.position
		barra_base.position.y = _pos_base_visivel.y + barra_base.size.y
		barra_base.visible = false

func ativar_modo_cinema(ativar: bool) -> void:
	_em_cutscene_ativa = ativar
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if ativar:
		if barra_topo != null:
			barra_topo.visible = true
			barra_topo.modulate.a = 1.0
			tween.tween_property(barra_topo, "position:y", _pos_topo_visivel.y, 0.4)
		if barra_base != null:
			barra_base.visible = true
			barra_base.modulate.a = 1.0
			tween.tween_property(barra_base, "position:y", _pos_base_visivel.y, 0.4)
		if _camera_spell != null:
			tween.tween_property(_camera_spell, "zoom", zoom_cutscene, 0.6)
	else:
		if barra_topo != null:
			tween.tween_property(barra_topo, "position:y", _pos_topo_visivel.y - barra_topo.size.y, 0.4)
			tween.tween_property(barra_topo, "modulate:a", 0.0, 0.4)
		if barra_base != null:
			tween.tween_property(barra_base, "position:y", _pos_base_visivel.y + barra_base.size.y, 0.4)
			tween.tween_property(barra_base, "modulate:a", 0.0, 0.4)
		if _camera_spell != null:
			tween.tween_property(_camera_spell, "zoom", _zoom_original, 0.5)
			tween.tween_property(_camera_spell, "offset", _offset_original, 0.3)
		
		tween.chain().tween_callback(func():
			if not _em_cutscene_ativa:
				if barra_topo != null: barra_topo.visible = false
				if barra_base != null: barra_base.visible = false
		)
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

func _calcular_borda_esquerda_camera() -> float:
	var largura_tela: float = get_viewport_rect().size.x
	if _camera_spell != null:
		# Usa o menor zoom entre o atual e o da cutscene para garantir que ela nasça fora mesmo antes do zoom terminar
		var zoom_ref: float = minf(_camera_spell.zoom.x, zoom_cutscene.x)
		var centro_x: float = _camera_spell.get_screen_center_position().x
		var metade_visivel: float = (largura_tela * 0.5) / maxf(zoom_ref, 0.1)
		return centro_x - metade_visivel - margem_fora_camera
	return spell.global_position.x - (largura_tela * 0.6) - margem_fora_camera

func iniciar_encontro_area(novas_falas: Array[Dictionary], _vir_da_esquerda: bool = true) -> void:
	if spell == null or july == null:
		return
		
	_em_cutscene_animada = false
	spell.em_cutscene = true
	july.em_cutscene = true
	july.velocity = Vector2.ZERO
	ativar_modo_cinema(true)
	
	# Nasce fora da borda esquerda real da câmera e para a 100px à esquerda do Spell
	var pos_inicial_x: float = _calcular_borda_esquerda_camera()
	var pos_final_x: float = spell.global_position.x - distancia_parada_spell
	
	# Garante que o ponto inicial fique sempre à esquerda do ponto de parada
	if pos_inicial_x > pos_final_x - 150.0:
		pos_inicial_x = pos_final_x - 150.0
	
	var pos_inicial_y: float = _encontrar_y_chao(pos_inicial_x, spell.global_position.y)
	
	july.global_position = Vector2(pos_inicial_x, pos_inicial_y)
	july.olhar_para_direita()
	spell.sprite.flip_h = true # Spell vira para a esquerda para olhar para ela
	
	# Manda a July caminhar usando física e colisão de chão até parar a 100px do Spell
	july.caminhar_ate_x(pos_final_x, velocidade_chegada_july)
	await july.chegou_ao_destino
	
	if not _em_cutscene_ativa:
		return
		
	july.tocar_animacao("idle")
	falas = novas_falas
	abrir_caixa()

func _encontrar_y_chao(pos_x: float, y_referencia: float) -> float:
	var espaco: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var de := Vector2(pos_x, y_referencia - 400.0)
	var ate := Vector2(pos_x, y_referencia + 600.0)
	var consulta := PhysicsRayQueryParameters2D.create(de, ate)
	if july != null:
		consulta.exclude = [july.get_rid()]
	if spell != null:
		consulta.exclude.append(spell.get_rid())
	
	var resultado: Dictionary = espaco.intersect_ray(consulta)
	if not resultado.is_empty():
		return resultado.position.y - 2.0
	return y_referencia

func abrir_caixa() -> void:
	indice_fala = 0
	falando = true
	_iniciar_plano_sons_dialogo()
	caixa_dialogo.visible = true
	mostrar_fala_atual()

func _iniciar_plano_sons_dialogo() -> void:
	# Planejamento global antigo removido: os blips agora são planejados por fala
	# em mostrar_fala_atual() (1 obrigatório, no máximo 3, até o fim de cada fala).
	_dialogo_ativo_voz = false
	_chars_revelados_dialogo = 0
	_alvos_toque.clear()
	_proximo_alvo = 0
	_total_chars_dialogo = 0
	_ultimo_som_voz = null
	_alvos_fala_atual.clear()
	_proximo_alvo_fala = 0

func mostrar_fala_atual() -> void:
	var dados = falas[indice_fala]
	retrato.texture = dados["rosto"]
	texto_fala.text = dados["texto"]
	
	var total_letras: int = texto_fala.get_total_character_count()
	texto_fala.visible_characters = 0
	_ultimo_char_som = -1
	_digitando = true

	# Planeja os blips desta fala: 1 obrigatório, no máximo 3, até o fim da fala.
	_alvos_fala_atual.clear()
	_proximo_alvo_fala = 0
	_dialogo_ativo_voz = false
	if not sons_voz.is_empty() and total_letras > 0:
		var parsed: String = texto_fala.get_parsed_text()
		var candidatos: Array[int] = []
		for i in range(total_letras):
			var ch: String = ""
			if i < parsed.length():
				ch = parsed.substr(i, 1)
			if not ch.strip_edges().is_empty():
				candidatos.append(i + 1)
		if not candidatos.is_empty():
			var max_blips: int = mini(3, candidatos.size())
			var min_blips: int = 1
			var qtd: int = randi_range(min_blips, max_blips)
			var pool: Array[int] = candidatos.duplicate()
			var escolhidos: Array[int] = []
			while escolhidos.size() < qtd and not pool.is_empty():
				var idx: int = randi() % pool.size()
				escolhidos.append(pool[idx])
				pool.remove_at(idx)
			escolhidos.sort()
			_alvos_fala_atual = escolhidos
			_dialogo_ativo_voz = true
	
	if _tween_digitacao != null and _tween_digitacao.is_valid():
		_tween_digitacao.kill()
		
	var duracao: float = clampf(total_letras * 0.03, 0.3, 1.2)
	_tween_digitacao = create_tween()
	_tween_digitacao.tween_method(_atualizar_digitacao_com_som, 0, total_letras, duracao)
	_tween_digitacao.finished.connect(func(): _digitando = false)

func _atualizar_digitacao_com_som(qtd_atual: int) -> void:
	_revelar_ate(qtd_atual)


func _revelar_ate(qtd_atual: int) -> void:
	var total: int = texto_fala.get_total_character_count()
	qtd_atual = clampi(qtd_atual, 0, total)
	texto_fala.visible_characters = qtd_atual

	while _dialogo_ativo_voz and _proximo_alvo_fala < _alvos_fala_atual.size() and qtd_atual >= _alvos_fala_atual[_proximo_alvo_fala]:
		_tocar_bip_voz()
		_proximo_alvo_fala += 1
		if _proximo_alvo_fala >= _alvos_fala_atual.size():
			_dialogo_ativo_voz = false

	_ultimo_char_som = maxi(_ultimo_char_som, qtd_atual - 1)

func _tocar_bip_voz() -> void:
	if som_fala == null or sons_voz.is_empty():
		return
	var stream: AudioStream = sons_voz.pick_random()
	if stream == null:
		return
	if sons_voz.size() > 1:
		var tentativas: int = 0
		while stream == _ultimo_som_voz and tentativas < 8:
			stream = sons_voz.pick_random()
			tentativas += 1
	_ultimo_som_voz = stream
	som_fala.stream = stream
	som_fala.volume_db = volume_voz_db
	som_fala.pitch_scale = randf_range(0.95, 1.12)
	som_fala.play()

func encerrar_dialogo() -> void:
	_dialogo_ativo_voz = false
	_alvos_toque.clear()
	_alvos_fala_atual.clear()
	_proximo_alvo_fala = 0
	falando = false
	_digitando = false
	caixa_dialogo.visible = false
	ativar_modo_cinema(false)
	
	if _em_cutscene_animada and cutscene_player != null:
		cutscene_player.play()
	else:
		if spell != null: spell.em_cutscene = false
		if july != null: july.em_cutscene = false
