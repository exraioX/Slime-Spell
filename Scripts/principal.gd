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
	# Encontra sprites de lixo e cria Area2D com collision shape em cima deles
	var alvos: Array[Node] = []
	for filho in mapa_node.get_children():
		if filho is Sprite2D and (str(filho.name).begins_with("PilhaDeLixo") or str(filho.name).begins_with("Lixeira")):
			alvos.append(filho)
	# Coleta todos os nós de lixo no chão (pode haver mais de um)
	var lixos_nodes: Array[Node] = []
	for filho in mapa_node.get_children():
		if str(filho.name).to_lower().contains("lixos") or str(filho.name).to_lower().contains("lixo"):
			lixos_nodes.append(filho)
	# Também busca recursivamente por segurança
	for n in mapa_node.find_children("Lixos*", "", true):
		if not (n in lixos_nodes):
			lixos_nodes.append(n)
	for ln in lixos_nodes:
		for filho in ln.get_children():
			if filho is Sprite2D:
				alvos.append(filho)

	for sprite in alvos:
		var area_name: String = "SlowArea_" + str(sprite.name)
		# Evita áreas duplicadas se _ready/_configurar for chamado novamente
		if mapa_node.has_node(area_name):
			continue
		var area := Area2D.new()
		area.name = area_name
		# Detecta apenas o spell (collision_layer = 1)
		area.collision_mask = 1
		area.collision_layer = 0
		area.monitoring = true
		area.monitorable = false
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var tex_size: Vector2 = Vector2(32, 32)
		if sprite is Sprite2D:
			var sp: Sprite2D = sprite as Sprite2D
			if sp.texture != null:
				var base_size: Vector2 = sp.texture.get_size()
				if sp.region_enabled:
					base_size = sp.region_rect.size
				tex_size = base_size * sp.scale.abs()
		rect_shape.size = tex_size
		shape.shape = rect_shape
		area.add_child(shape)
		# Adiciona à árvore ANTES de definir posição global
		mapa_node.add_child(area)
		area.global_position = (sprite as Node2D).global_position
		area.rotation = (sprite as Node2D).rotation
		area.body_entered.connect(_on_lixo_body_entered)
		area.body_exited.connect(_on_lixo_body_exited)

	_lixo_slow_configurado = true

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
