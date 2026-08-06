extends Area2D

@export var valor_item: int = 1
@export var flutuar: bool = true

var tempo_flutuacao: float = 0.0

func _process(delta: float) -> void:
	if flutuar:
		tempo_flutuacao += delta
		position.y += sin(tempo_flutuacao * 5.0) * 0.5

func _on_body_entered(body: Node2D) -> void:
	if body.name.to_lower() == "spell":
		coletar()

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().name.to_lower() == "spell":
		coletar()

func coletar() -> void:
	# Envia o valor diretamente para o Autoload 'Global'
	if has_node("/root/Global"):
		get_node("/root/Global").adicionar_item(valor_item)
	queue_free()
