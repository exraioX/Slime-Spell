extends Label

func _process(_delta: float) -> void:
	text = "Lixo Coletado: " + str(Global.lixo_coletado)
