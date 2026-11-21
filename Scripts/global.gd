extends Node
## Singleton global da aplicação.
## Guarda o estado compartilhado entre cenas/scripts (ex.: lixo coletado).

var lixo_coletado: int = 0
var nome_jogador: String = "Slime"

func coletar() -> void:
	lixo_coletado += 1

func resetar() -> void:
	lixo_coletado = 0
