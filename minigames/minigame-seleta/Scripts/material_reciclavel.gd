extends Area2D

@export var tipo_material: String = "plastico"
@export var velocidade_esteira: float = 180.0
@export var limite_x_destruir: float = 2000.0
@export var escala_material: Vector2 = Vector2(0.15, 0.15)

@onready var sprite: Sprite2D = $Sprite2D

var esta_sendo_segurado: bool = false
var na_esteira: bool = true

func _ready() -> void:
	add_to_group("reciclavel")
	scale = escala_material

func configurar(novo_tipo: String, textura: Texture2D, vel: float) -> void:
	tipo_material = novo_tipo
	velocidade_esteira = vel
	scale = escala_material
	if sprite != null and textura != null:
		sprite.texture = textura

func _process(delta: float) -> void:
	if na_esteira and not esta_sendo_segurado:
		position.x += velocidade_esteira * delta
		if position.x > limite_x_destruir:
			queue_free()

func ao_ser_pego() -> void:
	esta_sendo_segurado = true
	na_esteira = false

func ao_ser_solto() -> void:
	esta_sendo_segurado = false
