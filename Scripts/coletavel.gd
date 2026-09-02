extends Area2D


# =====================================================
# CONFIGURAÇÕES
# =====================================================

@export var valor_item: int = 1
@export var flutuar: bool = true


# =====================================================
# VARIÁVEIS
# =====================================================

var tempo_flutuacao: float = 0.0

var jogador_perto: bool = false
var coletando: bool = false

var jogador: Node2D = null


# =====================================================
# REFERÊNCIAS
# =====================================================

@onready var aviso: Label = $Label


# =====================================================
# INÍCIO
# =====================================================

func _ready() -> void:

	# Esconde o aviso quando o jogo começa
	aviso.visible = false


# =====================================================
# FLUTUAÇÃO
# =====================================================

func _process(delta: float) -> void:

	if flutuar:

		tempo_flutuacao += delta

		position.y += sin(
			tempo_flutuacao * 5.0
		) * 0.5


# =====================================================
# JOGADOR ENTROU
# =====================================================

func _on_body_entered(body: Node2D) -> void:

	if body.name.to_lower() == "spell":

		print("SPELL ENTROU NO ITEM")

		jogador_perto = true
		jogador = body

		# Mostra "Aperte (E)"
		aviso.visible = true

		# Informa ao Spell qual item está perto
		body.item_interacao_atual = self


# =====================================================
# JOGADOR SAIU
# =====================================================

func _on_body_exited(body: Node2D) -> void:

	if body == jogador:

		print("SPELL SAIU DO ITEM")

		jogador_perto = false
		jogador = null

		# Esconde "Aperte (E)"
		aviso.visible = false

		# Só limpa se este ainda for o item selecionado
		if body.item_interacao_atual == self:

			body.item_interacao_atual = null


# =====================================================
# TENTAR COLETAR
# =====================================================

func tentar_coletar() -> void:

	# Não está perto
	if not jogador_perto:

		print("JOGADOR NÃO ESTÁ PERTO")

		return


	# Já está coletando
	if coletando:

		return


	# Jogador não existe
	if jogador == null:

		return


	print("TENTANDO COLETAR ITEM")


	coletando = true

	# Esconde o aviso
	aviso.visible = false


	# Inicia o pick no jogador
	if jogador.has_method("iniciar_pick"):

		jogador.iniciar_pick(self)

	else:

		print("ERRO: Spell não possui iniciar_pick()")

		coletando = false


# =====================================================
# COLETA REAL
# =====================================================

func coletar() -> void:

	# Evita coletar novamente
	if not is_instance_valid(self):

		return


	print("ITEM COLETADO!")

	# Adiciona ao contador global
	if has_node("/root/Global"):

		get_node("/root/Global").adicionar_item(valor_item)

	else:

		print("ERRO: Global não encontrado!")


	# Remove o item da cena
	queue_free()
