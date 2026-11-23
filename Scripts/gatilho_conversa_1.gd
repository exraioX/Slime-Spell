extends Area2D

@onready var principal: Node2D = get_tree().current_scene

@export var vir_da_esquerda: bool = true

@export_multiline var textos_fala: Array[String] = [
	"Olha só, você chegou até aqui!",
	"Essa Arte é muito legal, né?",
	"É sobre os 3R's, já ouviu falar?"
]

# Opções: "normal", "assustada", "feliz", "megaF", "passifica", "pistola", "preocupada", "zangada"
@export var expressoes: Array[String] = [
	"feliz",
	""
]

var ja_ativou: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "spell" and not ja_ativou:
		ja_ativou = true
		
		var lista_formatada: Array[Dictionary] = []
		for i in range(textos_fala.size()):
			var exp_nome: String = expressoes[i] if i < expressoes.size() else "normal"
			lista_formatada.append({
				"rosto": principal.obter_rosto(exp_nome),
				"texto": textos_fala[i]
			})
			
		principal.iniciar_encontro_area(lista_formatada, vir_da_esquerda)
