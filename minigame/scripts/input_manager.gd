class_name InputManager
extends Node
## Interpreta os comandos de teclado e emite sinais. Não classifica nada:
## apenas traduz teclas em intenções para o GameManager.

signal sort_solicitado(direcao: int)   ## -1 = esquerda, +1 = direita
signal coletar_solicitado()
signal pausar_solicitado()

@export var ativo: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return

	if event.is_action_pressed("sort_left") or event.is_action_pressed("ui_left"):
		sort_solicitado.emit(-1)
	elif event.is_action_pressed("sort_right") or event.is_action_pressed("ui_right"):
		sort_solicitado.emit(1)
	elif event.is_action_pressed("collect_special") or event.is_action_pressed("ui_up"):
		coletar_solicitado.emit()
	elif event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
		pausar_solicitado.emit()