extends CharacterBody2D

@export var velocidade: float = 100.0
@export var dano: int = 1

var player: Node2D = null

func _ready() -> void:
	# Procura pelo player principal na cena atual
	# Se o seu player estiver em sub-nós, usaremos a busca pelo nome 'spell'
	var root_scene = get_tree().current_scene
	player = root_scene.find_child("spell", true, false) as Node2D

func _physics_process(_delta: float) -> void:
	if player:
		# Calcula a direção em direção ao player
		var direcao = (player.global_position - global_position).normalized()
		velocity = direcao * velocidade
		move_and_slide()

func _on_area_dano_body_entered(body: Node2D) -> void:
	# Se colidir com o jogador 'spell', causa dano
	if body.name.to_lower() == "spell":
		if body.has_method("receber_dano"):
			body.receber_dano(dano)


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
