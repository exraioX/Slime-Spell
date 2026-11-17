class_name GameConfig
extends Resource
## Configuração central do minigame Snack Baskets.
## TODOS os parâmetros podem ser alterados no Inspector (nó Game -> config).
## Nenhum deles exige editar código.

# ============================ LAYOUT (base 1920x1080) ============================
@export_group("Layout")
## Região da esteira (vertical, central). Independente de qualquer imagem.
@export var esteira_rect: Rect2 = Rect2(760, 180, 400, 820)
## Altura (Y) onde os objetos surgem na esteira.
@export var spawn_y: float = 230.0
## Janela de decisão (onde o objeto pode ser classificado).
@export var janela_y: float = 320.0
@export var janela_altura: float = 240.0
## Altura da barreira vermelha no fim da esteira.
@export var barreira_altura: float = 26.0

## Posição do centro de cada cesto-destino.
@export var cesto_esquerda_pos: Vector2 = Vector2(300, 210)
@export var cesto_direita_pos: Vector2 = Vector2(1620, 210)
@export var cesto_tamanho: Vector2 = Vector2(320, 180)

# ============================ MOVIMENTO ============================
@export_group("Movimento")
@export var velocidade_inicial: float = 165.0    ## px/s
@export var velocidade_maxima: float = 540.0
@export var aceleracao_velocidade: float = 5.5   ## ganho de velocidade por segundo

# ============================ GERAÇÃO ============================
@export_group("Geração")
@export var intervalo_inicial: float = 1.35      ## segundos entre objetos
@export var intervalo_minimo: float = 0.55
@export var distancia_minima: float = 140.0      ## distância mínima entre objetos na esteira
@export var max_objetos_ativos: int = 8
@export var chance_especial: float = 0.12        ## probabilidade de objeto especial
@export var pontos_bonus_especial: int = 25

# ============================ PONTUAÇÃO ============================
@export_group("Pontuação")
@export var pontos_por_acerto: int = 10
@export var bonus_combo_por_nivel: int = 2
@export var combo_maximo: int = 10

# ============================ CORES (placeholders substituíveis) ============================
@export_group("Cores")
@export var cor_fundo: Color = Color("241d2e")
@export var cor_esteira: Color = Color("3c3c44")
@export var cor_esteira_linha: Color = Color("8d8d97")
@export var cor_esteira_borda: Color = Color("1d1d22")
@export var cor_barreira: Color = Color("d13b3b")
@export var cor_janela: Color = Color(1, 1, 1, 0.07)
@export var cor_cesto_esquerda: Color = Color("e8b21e")   ## amarelo (comida)
@export var cor_cesto_direita: Color = Color("2f6fd0")    ## azul (lixo)

# ============================ TEXTURAS SUBSTITUÍVEIS ============================
@export_group("Texturas substituíveis")
## >>> TROQUE AQUI: arraste suas imagens para estes campos.
@export var tex_fundo: Texture2D
@export var tex_esteira: Texture2D
@export var tex_barreira: Texture2D
@export var tex_cesto_esquerda: Texture2D
@export var tex_cesto_direita: Texture2D

# ============================ HELPERS ============================
func janela_rect() -> Rect2:
	return Rect2(esteira_rect.position.x, janela_y, esteira_rect.size.x, janela_altura)

func barreira_rect() -> Rect2:
	var y: float = esteira_rect.position.y + esteira_rect.size.y - barreira_altura
	return Rect2(esteira_rect.position.x, y, esteira_rect.size.x, barreira_altura)