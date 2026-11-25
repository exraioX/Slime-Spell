extends Node2D

@export var tempo_fade_musica_menu: float = 1.2

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
	var mapa_node: Node = get_node_or_null("mapa")
	if mapa_node == null:
		return
	# Encontra sprites de lixo e cria Area2D com collision shape em cima deles
	var alvos: Array[Node] = []
	for filho in mapa_node.get_children():
		if filho is Sprite2D and (str(filho.name).begins_with("PilhaDeLixo") or str(filho.name).begins_with("Lixeira")):
			alvos.append(filho)
	var lixos_chao: Node = mapa_node.get_node_or_null("Lixos-Chão")
	if lixos_chao != null:
		for filho in lixos_chao.get_children():
			if filho is Sprite2D:
				alvos.append(filho)

	for sprite in alvos:
		var area := Area2D.new()
		area.name = "SlowArea_" + str(sprite.name)
		area.collision_mask = 1
		area.monitoring = true
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var tex_size: Vector2 = Vector2(32, 32)
		if sprite is Sprite2D and (sprite as Sprite2D).texture != null:
			tex_size = (sprite as Sprite2D).texture.get_size() * (sprite as Sprite2D).scale.abs()
		rect_shape.size = tex_size
		shape.shape = rect_shape
		area.add_child(shape)
		# posiciona a area igual ao sprite
		area.global_position = (sprite as Node2D).global_position
		area.rotation = (sprite as Node2D).rotation
		mapa_node.add_child(area)
		area.body_entered.connect(_on_lixo_body_entered.bind(area))
		area.body_exited.connect(_on_lixo_body_exited.bind(area))

func _on_lixo_body_entered(body: Node) -> void:
	if body != null and body.has_method("entrar_lixo"):
		body.entrar_lixo()

func _on_lixo_body_exited(body: Node) -> void:
	if body != null and body.has_method("sair_lixo"):
		body.sair_lixo()
