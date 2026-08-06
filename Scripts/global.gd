extends Node

# Sinal que avisa as telas quando a quantidade de itens muda
signal itens_atualizados(quantidade: int)

var itens_coletados: int = 0

func adicionar_item(valor: int) -> void:
	itens_coletados += valor
	# Dispara o sinal enviando o novo valor total
	itens_atualizados.emit(itens_coletados)
