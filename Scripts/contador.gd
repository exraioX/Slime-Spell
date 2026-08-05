extends CanvasLayer

# Certifique-se de que o nome do nó filho é exatamente 'Label'
@onready var label: Label = $Control/Label

func _ready() -> void:
	# Mostra o valor inicial (0) assim que o jogo começa
	atualizar_texto_contador(Global.itens_coletados)
	
	# Conecta o sinal do Global para atualizar automaticamente ao coletar itens
	Global.itens_atualizados.connect(atualizar_texto_contador)

func atualizar_texto_contador(quantidade: int) -> void:
	# Altera o texto exibido na tela
	label.text = str(quantidade)
