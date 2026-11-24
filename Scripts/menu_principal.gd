extends CanvasLayer

@export var musica_tema: AudioStream
@export_file("*.tscn") var cena_cutscene_inicial: String = "res://Cenas/cutscene_inicial.tscn"
@export_file("*.tscn") var cena_principal: String = "res://Cenas/principal.tscn"

@onready var tela_loading: CanvasLayer = $TelaLoading
@onready var latinha: Sprite2D = $TelaLoading/Latinha

var ja_clicou := false

func _ready() -> void:
	tela_loading.visible = false
	# Inicia a música global assim que o menu abre
	MusicaMenu.tocar_musica(musica_tema)
 

func _process(delta: float) -> void:
	if ja_clicou:
		latinha.rotation += 5.0 * delta

func _on_areaplay_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not ja_clicou and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ja_clicou = true
		
		tela_loading.visible = true
		var tween := create_tween().set_parallel(true)
		for filho in tela_loading.get_children():
			if filho is CanvasItem:
				filho.modulate.a = 0.0
				tween.tween_property(filho, "modulate:a", 1.0, 0.4)
		
		await tween.finished
		await get_tree().create_timer(1.6).timeout
		
		# MODO DE TESTE: sempre abre a cutscene, mesmo se ela ja foi assistida.
		await Jogo.trocar_cena(cena_cutscene_inicial, false)
