extends Node2D

@export var tempo_fade_musica_menu: float = 1.2

var _lixo_slow_configurado: bool = false

func _ready() -> void:
	# Abaixa o volume da música do menu suavemente até parar assim que a fase começa
	MusicaMenu.parar_com_fade(tempo_fade_musica_menu)
	# Toca a música de fundo do principal
	var sons: Node = get_node_or_null("Sons")
	if sons != null and sons.has_method("tocar"):
		var faixa: AudioStream = sons.get("som_mundo")
		if faixa != null:
			sons.tocar(faixa)

	_configurar_lixo_slow()

func _configurar_lixo_slow() -> void:
	if _lixo_slow_configurado:
		return
	var mapa_node: Node = get_node_or_null("mapa")
	if mapa_node == null:
		return
	# Usa as Area2D j� existentes no mapa (ex.: "Lixos-gosma") em vez de criar em runtime.
	var areas: Array[Node] = []
	_coletar_areas_lixo(mapa_node, areas)
	for area in areas:
		if area is Area2D:
			var a: Area2D = area as Area2D
			if not a.body_entered.is_connected(_on_lixo_body_entered):
				a.body_entered.connect(_on_lixo_body_entered)
			if not a.body_exited.is_connected(_on_lixo_body_exited):
				a.body_exited.connect(_on_lixo_body_exited)
			a.collision_mask = 1
			a.monitoring = true
	_lixo_slow_configurado = true


func _coletar_areas_lixo(no: Node, out: Array[Node]) -> void:
	for filho in no.get_children():
		if filho is Area2D:
			var nome: String = str(filho.name).to_lower()
			var eh_area_lixo: bool = nome.contains("gosma") or nome.contains("lixo") or nome.contains("slow") or _area_contem_sprite_lixo(filho)
			if eh_area_lixo:
				out.append(filho)
		_coletar_areas_lixo(filho, out)

func _area_contem_sprite_lixo(area: Node) -> bool:
	for c in area.get_children():
		var n: String = str(c.name).to_lower()
		if n.contains("pilhad") or n.contains("lixeira") or n.contains("lixo"):
			return true
	return false

func _on_lixo_body_entered(body: Node) -> void:
	if body != null and body.has_method("entrar_lixo"):
		body.entrar_lixo()

func _on_lixo_body_exited(body: Node) -> void:
	if body != null and body.has_method("sair_lixo"):
		body.sair_lixo()

func iniciar_sequencia_final() -> void:
	var spell_node: CharacterBody2D = get_node_or_null("spell") as CharacterBody2D
	if spell_node == null:
		return

	# Desabilita o movimento do jogador
	spell_node.em_cutscene = true

	var posicao_spell: Vector2 = spell_node.global_position

	# Cria uma câmera temporária e a torna a câmera atual
	var camera_final: Camera2D = Camera2D.new()
	camera_final.name = "CameraFinal"
	camera_final.position_smoothing_enabled = false
	add_child(camera_final)
	camera_final.global_position = Vector2(-1500.0, posicao_spell.y)
	camera_final.make_current()

	# Voa da esquerda do mapa até o spell
	var tween_camera: Tween = create_tween()
	tween_camera.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_camera.tween_property(camera_final, "global_position", posicao_spell, 4.0)
	await tween_camera.finished

	# Tela preta com fade + texto final
	var canvas_final: CanvasLayer = CanvasLayer.new()
	canvas_final.name = "CanvasFinal"
	add_child(canvas_final)

	var fundo_preto: ColorRect = ColorRect.new()
	fundo_preto.name = "FundoPreto"
	fundo_preto.color = Color(0.0, 0.0, 0.0, 0.0)
	fundo_preto.mouse_filter = Control.MOUSE_FILTER_STOP
	fundo_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_final.add_child(fundo_preto)

	var texto_final: Label = Label.new()
	texto_final.name = "TextoFinal"
	texto_final.text = "FIM\nMesmo com pouco fazemos muito."
	texto_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_final.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_final.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texto_final.add_theme_font_size_override("font_size", 48)
	texto_final.add_theme_color_override("font_color", Color.WHITE)
	canvas_final.add_child(texto_final)

	var tween_fade: Tween = create_tween()
	tween_fade.tween_property(fundo_preto, "color:a", 1.0, 1.0)
	await tween_fade.finished

	# Mantém a tela preta
	fundo_preto.color = Color.BLACK
