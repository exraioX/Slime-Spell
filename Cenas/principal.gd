extends Node2D

@export var tempo_fade_musica_menu: float = 1.2

func _ready() -> void:
	# Abaixa o volume da música do menu suavemente até parar assim que a fase começa
	MusicaMenu.parar_com_fade(tempo_fade_musica_menu)
