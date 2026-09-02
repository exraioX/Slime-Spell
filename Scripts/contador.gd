extends CanvasLayer

@onready var label: Label = $Control/Label


func _ready() -> void:

	# Mostra o valor inicial
	atualizar_texto_contador(Global.itens_coletados)

	# Atualiza automaticamente quando coletar
	Global.itens_atualizados.connect(atualizar_texto_contador)


func atualizar_texto_contador(quantidade: int) -> void:

	label.text = str(quantidade)
