extends CharacterBody2D

# Configurações ajustáveis no Inspetor
@export var velocidade: float = 80.0
@export var tempo_espera: float = 2.0         # Duração da pausa de 5s
@export var intervalo_patrulha: float = 5.0    # Anda por 5 segundos antes de pausar

# Referências aos novos nós (Certifique-se de que os nomes na árvore de Cena estão idênticos)
@onready var ray1: RayCast2D = $ray1 # Sensor posicionado na esquerda
@onready var ray2: RayCast2D = $ray2 # Sensor posicionado na direita
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Controle de estado interno
var direcao: float = 1.0 # 1.0 = Direita, -1.0 = Esquerda
var aguardando: bool = false
var cronometro_movimento: float = 0.0

func _physics_process(delta: float) -> void:
	# 1. Gerenciamento de Gravidade Seguro
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	else:
		velocity.y = 0

	# 2. Máquina de Estados
	if not aguardando:
		# Processa a movimentação horizontal
		velocity.x = direcao * velocidade
		
		if sprite.animation != "walk":
			sprite.play("walk")
		
		sprite.flip_h = (direcao < 0)
		cronometro_movimento += delta

		# LÓGICA DE DETECÇÃO COM DOIS RAYCASTS:
		# Se estiver indo para a direita (direcao > 0), checa apenas o ray2.
		# Se estiver indo para a esquerda (direcao < 0), checa apenas o ray1.
		var perdeu_o_chao = false
		if direcao > 0:
			perdeu_o_chao = not ray2.is_colliding()
		else:
			perdeu_o_chao = not ray1.is_colliding()

		# SE TOCOU NA BORDA CORRESPONDENTE OU BATEU NA PAREDE:
		if is_on_floor() and (perdeu_o_chao or is_on_wall()):
			retorno_imediato()
		# SE APENAS DEU OS 5 SEGUNDOS:
		elif cronometro_movimento >= intervalo_patrulha:
			iniciar_pausa()
	else:
		# Processa o estado de repouso (Pausa dos 5 segundos)
		velocity.x = 0
		if sprite.animation != "idle":
			sprite.play("idle")

	# Executa a movimentação física
	move_and_slide()

# Comportamento instantâneo ao atingir obstáculos físicos
func retorno_imediato() -> void:
	cronometro_movimento = 0.0   # Reinicia o contador de 5 segundos
	direcao *= -1.0              # Inverte o rumo na hora
	
	# Força a velocidade a mudar imediatamente e aplica o empurrão de segurança 
	# para tirá-la da borda antes do próximo frame
	velocity.x = direcao * velocidade
	global_position.x += direcao * 2.0

# Comportamento de repouso por tempo (A cada 5 segundos de caminhada livre)
func iniciar_pausa() -> void:
	aguardando = true
	cronometro_movimento = 0.0
	velocity.x = 0
	
	# Primeira metade da pausa
	await get_tree().create_timer(tempo_espera / 2.0).timeout
	
	# Segunda metade da pausa (Olha temporariamente para trás)
	sprite.flip_h = not sprite.flip_h
	await get_tree().create_timer(tempo_espera / 2.0).timeout
	
	# Restaura o estado para continuar andando
	aguardando = false
