extends Area2D

signal material_despejado(acertou: bool, tipo_lixeira: String, quantidade: int)

@export var tipo_aceito: String = ""

func _ready() -> void:
	add_to_group("lixeira")
	if tipo_aceito == "":
		var nome_min: String = name.to_lower()
		if "plastico" in nome_min:
			tipo_aceito = "plastico"
		elif "papel" in nome_min:
			tipo_aceito = "papel"
		elif "metal" in nome_min:
			tipo_aceito = "metal"
		elif "vidro" in nome_min:
			tipo_aceito = "vidro"

func receber_despejo(_tipo_item: String, quantidade: int, acertou: bool) -> void:
	material_despejado.emit(acertou, tipo_aceito, quantidade)
