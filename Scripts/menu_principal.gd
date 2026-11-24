extends CanvasLayer

@export var musica_tema: AudioStream
@export_file("*.tscn") var cena_cutscene_inicial: String = "res://Cenas/cutscene_inicial.tscn"
@export_file("*.tscn") var cena_principal: String = "res://Cenas/principal.tscn"

@export_group("Botões")
@export var textura_play_hover: Texture2D
@export var textura_config_hover: Texture2D

@onready var tela_loading: CanvasLayer = $TelaLoading
@onready var latinha: Sprite2D = $TelaLoading/Latinha
@onready var sprite_play: Sprite2D = $Areaplay/play
@onready var sprite_config: Sprite2D = $Areaconfig/config
@onready var area_play: Area2D = $Areaplay
@onready var area_config: Area2D = $Areaconfig

var ja_clicou := false
var _regiao_play: Rect2
var _regiao_config: Rect2
var _regiao_play_hover: Rect2 = Rect2(8, 212, 90, 36)
var _regiao_config_hover: Rect2 = Rect2(6, 279, 113, 37)
var _tex_play_normal: Texture2D
var _tex_config_normal: Texture2D
var _scale_play_normal: Vector2 = Vector2.ONE
var _scale_config_normal: Vector2 = Vector2.ONE

func _ready() -> void:
	tela_loading.visible = false
	# Inicia a música global assim que o menu abre
	MusicaMenu.tocar_musica(musica_tema)
	_tex_play_normal = sprite_play.texture
	_tex_config_normal = sprite_config.texture
	_regiao_play = sprite_play.region_rect
	_regiao_config = sprite_config.region_rect
	_scale_play_normal = sprite_play.scale
	_scale_config_normal = sprite_config.scale

	area_play.mouse_entered.connect(func(): _set_hover(sprite_play, textura_play_hover))
	area_play.mouse_exited.connect(func(): _set_normal(sprite_play, _tex_play_normal, _regiao_play))
	area_config.mouse_entered.connect(func(): _set_hover(sprite_config, textura_config_hover))
	area_config.mouse_exited.connect(func(): _set_normal(sprite_config, _tex_config_normal, _regiao_config))
 

func _set_hover(sprite: Sprite2D, tex: Texture2D) -> void:
	if tex == null:
		return
	sprite.texture = tex
	sprite.region_enabled = true
	if sprite == sprite_play:
		sprite.region_rect = _regiao_play_hover
		sprite.scale = Vector2(178.348 / 90.0 * 1.15, 77.236 / 36.0 * 1.15)
	else:
		sprite.region_rect = _regiao_config_hover
		sprite.scale = Vector2(218.962 / 113.0 * 1.15, 75.718 / 37.0 * 1.15)

func _set_normal(sprite: Sprite2D, tex: Texture2D, regiao: Rect2) -> void:
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = regiao
	if sprite == sprite_play:
		sprite.scale = _scale_play_normal
	else:
		sprite.scale = _scale_config_normal

func _process(delta: float) -> void:
	if ja_clicou:
		latinha.rotation += 5.0 * delta

func _on_areaplay_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not ja_clicou and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ja_clicou = true
		
		# Fica branco por 0.2s antes de carregar
		_set_normal(sprite_play, _tex_play_normal, _regiao_play)
		await get_tree().create_timer(0.2).timeout
		
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
		
		# MODO DE TESTE: sempre abre a cutscene, mesmo se ela ja foi assistida.
		await Jogo.trocar_cena(cena_cutscene_inicial, false)

func _on_areaconfig_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_normal(sprite_config, _tex_config_normal, _regiao_config)
		await get_tree().create_timer(0.2).timeout
