
class_name AreaInteracao
extends Area2D

@export_group("Destino")
@export_file("*.tscn") var cena_destino: String = "res://minigame/scenes/game.tscn"

@export_group("Jogador")
@export var grupo_jogador: StringName = &"Player"
@export var aceitar_por_nome: String = "spell"

@export_group("Interação")
@export var acao_confirmar: StringName = &"interagir"
@export var mensagem: String = "(Pressione E)"

var _jogador_dentro: Node2D = null
var _trocando := false
var _label: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_label = Label.new()
	_label.text = mensagem
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)

	add_child(_label)
	_label.position = Vector2(-65, -55)
	_label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not _e_o_jogador(body):
		return

	_jogador_dentro = body
	_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _jogador_dentro:
		return

	_jogador_dentro = null
	_label.visible = false


func _e_o_jogador(body: Node) -> bool:
	if body.is_in_group(grupo_jogador):
		return true

	return aceitar_por_nome != "" and body.name == aceitar_por_nome


func _unhandled_input(event: InputEvent) -> void:
	if _jogador_dentro == null or _trocando:
		return

	if event.is_action_pressed(acao_confirmar):
		get_viewport().set_input_as_handled()
		_ir_para_destino()


func _ir_para_destino() -> void:
	if cena_destino.is_empty() or _trocando:
		return

	_trocando = true

	var erro := get_tree().change_scene_to_file(cena_destino)

	if erro != OK:
		_trocando = false
		push_error("Erro ao carregar o minigame: " + cena_destino)
