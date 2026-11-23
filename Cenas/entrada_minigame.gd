extends Area2D

@export_file("*.tscn") var cena_minigame: String = "res://minigames/Cenas/separe_corretamente.tscn"
@export var exigir_botao_interagir: bool = false

var _spell_na_area: bool = false
var _ja_trocou: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "spell" and not _ja_trocou:
		_spell_na_area = true
		if not exigir_botao_interagir:
			_ir_para_minigame()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "spell":
		_spell_na_area = false

func _process(_delta: float) -> void:
	if _spell_na_area and exigir_botao_interagir and not _ja_trocou:
		if Input.is_action_just_pressed("interagir") or Input.is_physical_key_pressed(KEY_E):
			_ir_para_minigame()

func _ir_para_minigame() -> void:
	if cena_minigame != "" and ResourceLoader.exists(cena_minigame):
		_ja_trocou = true
		get_tree().change_scene_to_file(cena_minigame)
