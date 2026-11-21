extends Node


func _ready() -> void:
	# Garante que o minigame também use a tela inteira quando executado isoladamente.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
