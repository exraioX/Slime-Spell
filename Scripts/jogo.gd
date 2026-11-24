extends CanvasLayer

# Adicione este script em Project > Project Settings > Globals > Autoload
# com o nome "Jogo". Ele centraliza transições e progresso.

const ARQUIVO_SAVE: String = "user://progresso_jogo.cfg"

@export var duracao_transicao: float = 0.55

var intro_assistida: bool = false
var _posicoes_salvas: Dictionary = {}
var _gatilhos_concluidos: Array[String] = []
var _trocando_cena: bool = false
var _parede_preta: ColorRect


func _ready() -> void:
	layer = 128
	_carregar_progresso()
	_criar_parede_preta()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_salvar_posicao_atual()
		salvar_progresso()


func _criar_parede_preta() -> void:
	_parede_preta = ColorRect.new()
	_parede_preta.name = "ParedePretaTransicao"
	_parede_preta.color = Color.BLACK
	_parede_preta.mouse_filter = Control.MOUSE_FILTER_STOP
	_parede_preta.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_parede_preta)
	_parede_preta.size = get_viewport().get_visible_rect().size
	_parede_preta.visible = false


func _carregar_progresso() -> void:
	var config := ConfigFile.new()
	var erro := config.load(ARQUIVO_SAVE)
	if erro != OK:
		return

	intro_assistida = bool(config.get_value("progresso", "intro_assistida", false))

	var posicoes: Variant = config.get_value("progresso", "posicoes", {})
	if posicoes is Dictionary:
		_posicoes_salvas = posicoes

	var gatilhos: Variant = config.get_value("progresso", "gatilhos_concluidos", [])
	if gatilhos is Array:
		for id in gatilhos:
			_gatilhos_concluidos.append(str(id))


func salvar_progresso() -> void:
	var config := ConfigFile.new()
	config.set_value("progresso", "intro_assistida", intro_assistida)
	config.set_value("progresso", "posicoes", _posicoes_salvas)
	config.set_value("progresso", "gatilhos_concluidos", _gatilhos_concluidos)

	var erro := config.save(ARQUIVO_SAVE)
	if erro != OK:
		push_error("Não foi possível salvar o progresso. Código: %s" % erro)


func _obter_jogador() -> Node:
	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador != null:
		return jogador

	if get_tree().current_scene != null:
		return get_tree().current_scene.find_child("spell", true, false)
	return null


func _salvar_posicao_atual() -> void:
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path.is_empty():
		return

	var jogador := _obter_jogador()
	if jogador is Node2D:
		_posicoes_salvas[cena.scene_file_path] = (jogador as Node2D).global_position


func _restaurar_posicao_da_cena() -> void:
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path.is_empty():
		return
	if not _posicoes_salvas.has(cena.scene_file_path):
		return

	var jogador := _obter_jogador()
	if not (jogador is Node2D):
		return

	var posicao: Variant = _posicoes_salvas[cena.scene_file_path]
	if typeof(posicao) == TYPE_VECTOR2:
		(jogador as Node2D).global_position = posicao
		if jogador is CharacterBody2D:
			(jogador as CharacterBody2D).velocity = Vector2.ZERO


func gatilho_foi_concluido(id: String) -> bool:
	return id in _gatilhos_concluidos


func marcar_gatilho_concluido(id: String) -> void:
	if id.is_empty() or gatilho_foi_concluido(id):
		return

	_gatilhos_concluidos.append(id)
	_salvar_posicao_atual()
	salvar_progresso()


func marcar_intro_assistida() -> void:
	if intro_assistida:
		return
	intro_assistida = true
	salvar_progresso()


func iniciar_jogo(cena_cutscene: String, cena_principal: String) -> void:
	if intro_assistida:
		await trocar_cena(cena_principal, false)
	else:
		await trocar_cena(cena_cutscene, false)


func trocar_cena(caminho: String, salvar_cena_atual: bool = true) -> void:
	if _trocando_cena or caminho.is_empty():
		return
	if not ResourceLoader.exists(caminho):
		push_error("Cena não encontrada: %s" % caminho)
		return

	_trocando_cena = true
	if salvar_cena_atual:
		_salvar_posicao_atual()
		salvar_progresso()

	await _cobrir_tela()
	var erro := get_tree().change_scene_to_file(caminho)
	if erro != OK:
		push_error("Falha ao abrir a cena %s. Código: %s" % [caminho, erro])
		await _revelar_tela()
		_trocando_cena = false
		return

	await get_tree().scene_changed
	await get_tree().process_frame
	_restaurar_posicao_da_cena()
	await _revelar_tela()
	_trocando_cena = false


func _cobrir_tela() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	_parede_preta.size = tamanho
	_parede_preta.visible = true
	_parede_preta.position = Vector2(-tamanho.x, 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_parede_preta, "position:x", 0.0, duracao_transicao)
	await tween.finished


func _revelar_tela() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	_parede_preta.size = tamanho
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_parede_preta, "position:x", tamanho.x, duracao_transicao)
	await tween.finished

	_parede_preta.visible = false
	_parede_preta.position.x = 0.0
