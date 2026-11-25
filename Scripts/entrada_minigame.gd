extends Area2D

# Barraca que abre uma lista textual de minigames.
# Nenhuma imagem é usada neste menu.

@export_group("Jogo dos 7 erros")
@export var nome_minigame: String = "Jogo dos 7 erros"
@export_dir var pasta_minigame: String = "res://minigames/minigame-7erros"
@export_file("*.tscn") var cena_minigame: String = ""

@export_group("Minigame de Separação")
@export var nome_minigame_separacao: String = "Separe Corretamente"
@export_file("*.tscn") var cena_minigame_separacao: String = "res://minigames/minigame-seleta/Cenas/separe_corretamente.tscn"

@export_group("Outros jogos")
# Para adicionar outro minigame, inclua um Dictionary:
# { "nome": "Nome do jogo", "cena": "res://caminho/cena.tscn" }
@export var jogos_adicionais: Array[Dictionary] = []

@export_group("Interação")
@export var exigir_botao_interagir: bool = true
@export var texto_interacao: String = "Pressione E para escolher um jogo"

var _spell_na_area: bool = false
var _ja_trocou: bool = false
var _menu_aberto: bool = false
var _label_aviso: Label
var _spell: Node
var _camada_menu: CanvasLayer
var _root_menu: Control
var _lista_botoes: VBoxContainer
var _label_contagem: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_criar_aviso_visual()
	_criar_menu_selecao()


func _criar_aviso_visual() -> void:
	_label_aviso = Label.new()
	_label_aviso.text = texto_interacao
	_label_aviso.visible = false
	_label_aviso.z_index = 100
	_label_aviso.add_theme_font_size_override("font_size", 34)
	_label_aviso.add_theme_color_override("font_color", Color.WHITE)
	_label_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_aviso.add_theme_constant_override("outline_size", 4)
	_label_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_aviso.position = Vector2(-230, -65)
	add_child(_label_aviso)


func _criar_menu_selecao() -> void:
	_camada_menu = CanvasLayer.new()
	_camada_menu.name = "MenuEscolhaJogo"
	_camada_menu.layer = 40
	add_child(_camada_menu)

	_root_menu = Control.new()
	_root_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_menu.visible = false
	_camada_menu.add_child(_root_menu)

	# Fundo simples, sem imagem ou textura.
	var fundo := ColorRect.new()
	fundo.color = Color(0.0, 0.0, 0.0, 0.72)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_menu.add_child(fundo)

	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -270
	painel.offset_right = 270
	painel.offset_top = -210
	painel.offset_bottom = 210
	_root_menu.add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Qual jogo você quer jogar?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 28)
	coluna.add_child(titulo)

	_label_contagem = Label.new()
	_label_contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_contagem.add_theme_font_size_override("font_size", 18)
	coluna.add_child(_label_contagem)
	_atualizar_contagem()

	_lista_botoes = VBoxContainer.new()
	_lista_botoes.add_theme_constant_override("separation", 10)
	coluna.add_child(_lista_botoes)

	var cancelar := Button.new()
	cancelar.text = "Voltar"
	cancelar.custom_minimum_size.y = 48
	cancelar.pressed.connect(_fechar_menu)
	coluna.add_child(cancelar)


func _obter_jogos() -> Array[Dictionary]:
	var jogos: Array[Dictionary] = []
	var caminho_principal := _resolver_cena_minigame()

	if not caminho_principal.is_empty():
		jogos.append({"nome": nome_minigame, "cena": caminho_principal})

	if not cena_minigame_separacao.strip_edges().is_empty() and ResourceLoader.exists(cena_minigame_separacao, "PackedScene"):
		jogos.append({"nome": nome_minigame_separacao, "cena": cena_minigame_separacao})

	for opcao in jogos_adicionais:
		var nome: String = str(opcao.get("nome", "Jogo"))
		var caminho: String = str(opcao.get("cena", ""))
		if not caminho.is_empty() and ResourceLoader.exists(caminho, "PackedScene"):
			jogos.append({"nome": nome, "cena": caminho})

	return jogos


func _resolver_cena_minigame() -> String:
	# Se a cena foi escolhida manualmente no Inspector, ela tem prioridade.
	if not cena_minigame.strip_edges().is_empty():
		if ResourceLoader.exists(cena_minigame, "PackedScene"):
			return cena_minigame
		push_warning("A cena configurada para o jogo dos 7 erros não existe: %s" % cena_minigame)
		return ""

	var pasta := pasta_minigame.trim_suffix("/")
	var candidatos: Array[String] = []
	_buscar_cenas(pasta, candidatos)
	candidatos.sort()

	if candidatos.is_empty():
		push_warning("Nenhuma cena .tscn foi encontrada em: %s" % pasta)
		return ""

	# Tenta reconhecer nomes comuns usados na cena principal do minigame.
	var nomes_principais: Array[String] = [
		"main", "principal", "jogo", "game", "7erros", "7-erros",
		"minigame-7erros", "minigame_7erros", "sete-erros", "seteerros",
		"jogo-dos-7-erros", "jogo_7_erros"
	]

	for caminho in candidatos:
		var nome_arquivo := caminho.get_file().get_basename().to_lower()
		var nome_normalizado := nome_arquivo.replace("_", "-").replace(" ", "-")
		if nome_arquivo in nomes_principais or nome_normalizado in nomes_principais:
			return caminho

	# Também reconhece arquivos que mencionem 7 e erro no próprio nome.
	var candidatos_7_erros: Array[String] = []
	for caminho in candidatos:
		var nome := caminho.get_file().get_basename().to_lower()
		if nome.contains("7") and (nome.contains("erro") or nome.contains("error")):
			candidatos_7_erros.append(caminho)

	if candidatos_7_erros.size() == 1:
		return candidatos_7_erros[0]

	# Se a pasta tiver apenas uma cena, ela é considerada a cena do minigame.
	if candidatos.size() == 1:
		return candidatos[0]

	push_error(
		"Não consegui identificar a cena principal do jogo dos 7 erros. " +
		"Defina 'cena_minigame' no Inspector de EntradaMinigame. Cenas encontradas: %s" %
		str(candidatos)
	)
	return ""


func _buscar_cenas(pasta: String, resultado: Array[String]) -> void:
	var diretorio := DirAccess.open(pasta)
	if diretorio == null:
		return

	for arquivo in diretorio.get_files():
		if arquivo.to_lower().ends_with(".tscn"):
			resultado.append(pasta.path_join(arquivo))

	for subpasta in diretorio.get_directories():
		if subpasta.begins_with(".") or subpasta.to_lower() in ["addons", "tests", "test"]:
			continue
		_buscar_cenas(pasta.path_join(subpasta), resultado)


func _atualizar_opcoes() -> void:
	for filho in _lista_botoes.get_children():
		_lista_botoes.remove_child(filho)
		filho.queue_free()

	for jogo in _obter_jogos():
		var botao := Button.new()
		botao.text = str(jogo["nome"])
		botao.custom_minimum_size.y = 54
		botao.pressed.connect(_selecionar_jogo.bind(str(jogo["cena"])))
		_lista_botoes.add_child(botao)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "spell" or _ja_trocou:
		return

	_spell = body
	_spell_na_area = true
	if exigir_botao_interagir:
		_label_aviso.visible = true
	else:
		_abrir_menu()


func _on_body_exited(body: Node2D) -> void:
	if body != _spell:
		return

	_spell_na_area = false
	_label_aviso.visible = false
	if _menu_aberto:
		_fechar_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _menu_aberto:
		if event.is_action_pressed("ui_cancel"):
			_fechar_menu()
			get_viewport().set_input_as_handled()
		return

	if not _spell_na_area or not exigir_botao_interagir or _ja_trocou:
		return

	var tecla_e: bool = event.is_action_pressed("KEY_E")
	if event.is_action_pressed("interagir") or tecla_e:
		_label_aviso.visible = false
		_abrir_menu()
		get_viewport().set_input_as_handled()


func _atualizar_contagem() -> void:
	var concluidos := 0
	if Jogo.gatilho_foi_concluido("minigame_7erros"):
		concluidos += 1
	if Jogo.gatilho_foi_concluido("minigame_separacao"):
		concluidos += 1
	if is_instance_valid(_label_contagem):
		_label_contagem.text = "%d de 2 concluídos" % concluidos


func _abrir_menu() -> void:
	if _menu_aberto or _ja_trocou:
		return

	if Jogo.gatilho_foi_concluido("minigame_7erros") and Jogo.gatilho_foi_concluido("minigame_separacao"):
		_ja_trocou = true
		if _menu_aberto:
			_fechar_menu()
		var principal: Node = get_tree().current_scene
		if principal == null:
			principal = get_parent()
		if principal != null and principal.has_method("iniciar_sequencia_final"):
			principal.iniciar_sequencia_final()
		return

	_atualizar_opcoes()
	_atualizar_contagem()
	if _lista_botoes.get_child_count() == 0:
		push_warning("Não há minigames válidos configurados na barraca. Confira a pasta e a cena principal.")
		return

	_menu_aberto = true
	_root_menu.visible = true
	_set_spell_bloqueado(true)


func _fechar_menu() -> void:
	_menu_aberto = false
	if is_instance_valid(_root_menu):
		_root_menu.visible = false
	_set_spell_bloqueado(false)
	if _spell_na_area and not _ja_trocou:
		_label_aviso.visible = true


func _set_spell_bloqueado(bloquear: bool) -> void:
	if is_instance_valid(_spell) and _spell is CharacterBody2D:
		_spell.set("em_cutscene", bloquear)


func _selecionar_jogo(caminho: String) -> void:
	if _ja_trocou or caminho.is_empty():
		return

	if not ResourceLoader.exists(caminho, "PackedScene"):
		push_error("Cena do minigame não encontrada: %s" % caminho)
		return

	_ja_trocou = true
	_menu_aberto = false
	_root_menu.visible = false
	# Jogo salva a posição do Spell antes de iniciar a transição.
	Jogo.trocar_cena(caminho, true)
