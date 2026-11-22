extends Node

const LARGURA_LAYOUT := 1920.0
const ALTURA_LAYOUT := 1080.0
const CENTRO_LAYOUT := Vector2(LARGURA_LAYOUT * 0.5, ALTURA_LAYOUT * 0.5)

@onready var camera: Camera2D = get_parent().get_node("Camera2D")


func _ready() -> void:
	# Garante que o minigame também use a tela inteira quando executado isoladamente.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().size_changed.connect(_ajustar_camera)
	# Espera a janela aplicar o modo e atualizar o tamanho do viewport.
	await get_tree().process_frame
	_ajustar_camera()


func _ajustar_camera() -> void:
	if not is_instance_valid(camera):
		return

	# O desenho do minigame usa um layout-base de 1920x1080. Ajusta o zoom
	# para que todo esse espaço caiba na resolução atual, sem cortar as lixeiras.
	var tamanho_viewport := get_viewport().get_visible_rect().size
	if tamanho_viewport.x <= 0.0 or tamanho_viewport.y <= 0.0:
		return

	var zoom_uniforme := minf(
		tamanho_viewport.x / LARGURA_LAYOUT,
		tamanho_viewport.y / ALTURA_LAYOUT
	)
	camera.position = CENTRO_LAYOUT
	camera.zoom = Vector2(zoom_uniforme, zoom_uniforme)
