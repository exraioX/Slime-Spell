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
