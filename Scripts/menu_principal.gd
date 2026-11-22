extends CanvasLayer

@onready var tela_loading: CanvasLayer = $TelaLoading
@onready var latinha: Sprite2D = $TelaLoading/Latinha

var ja_clicou := false

func _ready() -> void:
	# Garante que a tela preta com a latinha comece escondida.
	tela_loading.visible = false

func _process(delta: float) -> void:
	# Se o jogador já clicou, gira a latinha continuamente.
	if ja_clicou:
		latinha.rotation += 5.0 * delta

func _on_areaplay_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not ja_clicou and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ja_clicou = true
		tela_loading.visible = true
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Cenas/principal.tscn")
