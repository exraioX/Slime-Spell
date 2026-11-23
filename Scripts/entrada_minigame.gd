extends Area2D

@export_file("*.tscn") var cena_minigame: String = "res://minigames/minigame-seleta/Cenas/separe_corretamente.tscn"
@export var exigir_botao_interagir: bool = true
@export var texto_interacao: String = "Pressione E para interagir"

var _spell_na_area: bool = false
var _ja_trocou: bool = false
var _label_aviso: Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_criar_aviso_visual()

func _criar_aviso_visual() -> void:
	_label_aviso = Label.new()
	_label_aviso.text = texto_interacao
	_label_aviso.visible = false
	_label_aviso.z_index = 100
	
	# Estilização para destacar o texto no mapa
	_label_aviso.add_theme_font_size_override("font_size", 40)
	_label_aviso.add_theme_color_override("font_color", Color.WHITE)
	_label_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_aviso.add_theme_constant_override("outline_size", 4)
	
	# Centraliza e posiciona acima da área de interação
	_label_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_aviso.position = Vector2(-115, -55)
	
	add_child(_label_aviso)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "spell" and not _ja_trocou:
		_spell_na_area = true
		if exigir_botao_interagir:
			_label_aviso.visible = true
		else:
			_ir_para_minigame()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "spell":
		_spell_na_area = false
		_label_aviso.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _spell_na_area and exigir_botao_interagir and not _ja_trocou:
		if event.is_action_pressed("interagir") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
			_label_aviso.visible = false
			_ir_para_minigame()

func _ir_para_minigame() -> void:
	if cena_minigame != "" and ResourceLoader.exists(cena_minigame):
		_ja_trocou = true
		get_tree().change_scene_to_file.call_deferred(cena_minigame)
