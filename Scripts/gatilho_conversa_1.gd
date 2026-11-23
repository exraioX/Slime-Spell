extends Area2D

@export var vir_da_esquerda: bool = true

@export_multiline var textos_fala: Array[String] = [
	"Olha só, você chegou até aqui!",
	"Essa Arte é muito legal, né?",
	"É sobre os 3R's, já ouviu falar?"
]

# Opções: "normal", "assustada", "feliz", "megaF", "passifica", "pistola", "preocupada", "zangada"
@export var expressoes: Array[String] = [
	"feliz",
	"megaF",
	"normal"
]

var ja_ativou: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "spell" and not ja_ativou:
		ja_ativou = true
		
		var sistema = get_tree().get_first_node_in_group("gerenciador_dialogo")
		if sistema != null:
			var lista_formatada: Array[Dictionary] = sistema.montar_lista_falas(textos_fala, expressoes)
			sistema.iniciar_encontro_area(lista_formatada, vir_da_esquerda)
