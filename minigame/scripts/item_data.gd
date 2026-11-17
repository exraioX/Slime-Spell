class_name ItemData
extends Resource
## Dados de um objeto classificável.
##
## COMO TROCAR A IMAGEM DE UM OBJETO:
##   1. Selecione um recurso .tres em res://minigame/resources/items/
##   2. No Inspector, arraste sua imagem (PNG com transparência) no campo "textura".
##   Pronto: nenhuma linha de código precisa ser alterada.
##
## COMO CADASTRAR UM NOVO OBJETO:
##   Duplique um .tres existente, ajuste nome/categoria/textura/pontuação e
##   adicione-o ao catálogo (res://minigame/resources/catalogo.tres ou no
##   array "catalogo_extra" do nó Game).

## Categorias (configuráveis). Cada uma vai para um cesto:
const CATEGORIA_COMIDA := 0   # comida fresca / boa  -> cesto ESQUERDA (amarelo)
const CATEGORIA_LIXO := 1     # lixo                 -> cesto DIREITA (azul)

@export var id: StringName = &"item"
@export var nome: String = "Item"
@export var categoria: int = CATEGORIA_COMIDA ## 0 = comida, 1 = lixo
@export var textura: Texture2D                ## imagem substituível pelo usuário
@export var cor_placeholder: Color = Color("f08a2c") ## cor usada enquanto não há textura
@export var forma: int = 0                    ## 0 = quadrado, 1 = círculo (placeholder)
@export var pontuacao: int = 10
@export var especial: bool = false            ## doces / bônus (coletados com CIMA/W)
@export var escala: float = 1.0               ## escala visual (não deforma proporção)
@export var peso: float = 1.0                 ## probabilidade relativa de aparecer