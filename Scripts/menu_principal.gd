extends CanvasLayer

@export var musica_tema: AudioStream
@export_file("*.tscn") var cena_cutscene_inicial: String = "res://Cenas/cutscene_inicial.tscn"
@export_file("*.tscn") var cena_principal: String = "res://Cenas/principal.tscn"

@export_group("Botões")
@export var textura_play_hover: Texture2D
@export var textura_config_hover: Texture2D
@export var textura_continuar_hover: Texture2D

@onready var tela_loading: CanvasLayer = $TelaLoading
@onready var latinha: Sprite2D = $TelaLoading/Latinha
@onready var sprite_play: Sprite2D = $Areaplay/play
@onready var sprite_config: Sprite2D = $Areaconfig/config
@onready var sprite_continuar: Sprite2D = $Areacontinuar/continuar
@onready var area_play: Area2D = $Areaplay
@onready var area_config: Area2D = $Areaconfig
@onready var area_continuar: Area2D = $Areacontinuar

var ja_clicou := false
var _regiao_play: Rect2
var _regiao_config: Rect2
var _regiao_continuar: Rect2
var _regiao_play_hover: Rect2 = Rect2(14.449, 400.461, 178.348, 77.236)
var _regiao_config_hover: Rect2 = Rect2(9.851, 533.692, 218.962, 75.718)
var _regiao_continuar_hover: Rect2 = Rect2(21, 551, 350, 76)
var _tex_play_normal: Texture2D
var _tex_config_normal: Texture2D
var _tex_continuar_normal: Texture2D
var _scale_play_normal: Vector2 = Vector2.ONE
var _scale_config_normal: Vector2 = Vector2.ONE
var _scale_continuar_normal: Vector2 = Vector2.ONE

func _ready() -> void:
	tela_loading.visible = false
	# Inicia a música global assim que o menu abre
	MusicaMenu.tocar_musica(musica_tema)
	_tex_play_normal = sprite_play.texture
	_tex_config_normal = sprite_config.texture
	_tex_continuar_normal = sprite_continuar.texture
	_regiao_play = sprite_play.region_rect
	_regiao_config = sprite_config.region_rect
	_regiao_continuar = sprite_continuar.region_rect
	_scale_play_normal = sprite_play.scale
	_scale_config_normal = sprite_config.scale
	_scale_continuar_normal = sprite_continuar.scale

	area_play.mouse_entered.connect(func(): _set_hover(sprite_play, textura_play_hover))
	area_play.mouse_exited.connect(func(): _set_normal(sprite_play, _tex_play_normal, _regiao_play))
	area_config.mouse_entered.connect(func(): _set_hover(sprite_config, textura_config_hover))
	area_config.mouse_exited.connect(func(): _set_normal(sprite_config, _tex_config_normal, _regiao_config))
	area_continuar.mouse_entered.connect(func(): _set_hover(sprite_continuar, textura_continuar_hover))
	area_continuar.mouse_exited.connect(func(): _set_normal(sprite_continuar, _tex_continuar_normal, _regiao_continuar))


func _set_hover(sprite: Sprite2D, tex: Texture2D) -> void:
	if tex == null:
		return
	sprite.texture = tex
	sprite.region_enabled = true
	if sprite == sprite_play:
		sprite.region_rect = _regiao_play_hover
		sprite.scale = Vector2.ONE
	elif sprite == sprite_continuar:
		sprite.region_rect = _regiao_continuar_hover
		sprite.scale = Vector2.ONE
	else:
		sprite.region_rect = _regiao_config_hover
		sprite.scale = Vector2.ONE

func _set_normal(sprite: Sprite2D, tex: Texture2D, regiao: Rect2) -> void:
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = regiao
	if sprite == sprite_play:
		sprite.scale = _scale_play_normal
	elif sprite == sprite_continuar:
		sprite.scale = _scale_continuar_normal
	else:
		sprite.scale = _scale_config_normal

func _process(delta: float) -> void:
	if ja_clicou:
		latinha.rotation += 5.0 * delta

func _iniciar_transicao(caminho: String) -> void:
	tela_loading.visible = true
	var tween := create_tween().set_parallel(true)
	for filho in tela_loading.get_children():
		if filho is CanvasItem:
			filho.modulate.a = 0.0
			tween.tween_property(filho, "modulate:a", 1.0, 0.4)

	await tween.finished
	await get_tree().create_timer(1.6).timeout

	# Para a música do menu quando a tela de carregamento termina.
	await MusicaMenu.parar_com_fade(0.3)

	await Jogo.trocar_cena(caminho, false)

func _on_areaplay_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not ja_clicou and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ja_clicou = true

		# Fica branco por 0.2s antes de carregar
		_set_normal(sprite_play, _tex_play_normal, _regiao_play)
		await get_tree().create_timer(0.2).timeout

		Jogo.iniciar_novo_jogo()
		await _iniciar_transicao(cena_cutscene_inicial)

func _on_areacontinuar_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not ja_clicou and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ja_clicou = true

		_set_normal(sprite_continuar, _tex_continuar_normal, _regiao_continuar)
		await get_tree().create_timer(0.2).timeout

		var cena_destino := cena_principal
		if Jogo.existe_progresso():
			Jogo.recarregar_progresso()
		else:
			Jogo.iniciar_novo_jogo()
			cena_destino = cena_cutscene_inicial
		await _iniciar_transicao(cena_destino)

func _on_areaconfig_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_normal(sprite_config, _tex_config_normal, _regiao_config)
		await get_tree().create_timer(0.2).timeout
