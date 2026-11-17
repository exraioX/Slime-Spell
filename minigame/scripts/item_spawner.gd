class_name ItemSpawner
extends Node
## Gera objetos continuamente respeitando intervalo, limite de ativos
## e distância mínima entre objetos. Respeita pausa e game over.

signal item_gerado(item: SortableItem)

const ITEM_SCENE := preload("res://minigame/scenes/sortable_item.tscn")

var config: GameConfig = null
var catalogo: Array[ItemData] = []
var container: Node2D = null
var itens_ativos: Array = []          ## referência à lista do GameManager
var ativo: bool = false

var _tempo: float = 0.0
var _intervalo: float = 1.35
var _peso_total: float = 0.0


func configurar(cfg: GameConfig, cat: Array, cont: Node2D, ativos: Array) -> void:
	config = cfg
	catalogo = cat
	container = cont
	itens_ativos = ativos
	_peso_total = 0.0
	for d in catalogo:
		_peso_total += maxf(d.peso, 0.001)


func iniciar() -> void:
	ativo = true
	_tempo = 0.55   # pequeno respiro no começo


func parar() -> void:
	ativo = false


func definir_intervalo(v: float) -> void:
	_intervalo = v


func atualizar(delta: float) -> void:
	if not ativo or config == null:
		return
	_tempo -= delta
	if _tempo > 0.0:
		return
	_tempo = _intervalo
	if _pode_gerar():
		gerar()


func _pode_gerar() -> bool:
	if itens_ativos.size() >= config.max_objetos_ativos:
		return false
	# distância mínima: se o item mais alto estiver perto do topo, espera
	for it in itens_ativos:
		var si: SortableItem = it
		if si.estado == SortableItem.EstadoItem.CAINDO and si.position.y < config.spawn_y + config.distancia_minima:
			return false
	return true


func gerar() -> SortableItem:
	if catalogo.is_empty():
		return null

	var dado: ItemData = _escolher_dado()
	var item: SortableItem = ITEM_SCENE.instantiate()
	container.add_child(item)

	# posição X aleatória dentro da esteira, com margem
	var margem: float = config.esteira_rect.size.x * 0.14
	var x: float = randf_range(
		config.esteira_rect.position.x + margem,
		config.esteira_rect.position.x + config.esteira_rect.size.x - margem
	)
	item.preparar(dado, config, x)
	itens_ativos.append(item)
	item_gerado.emit(item)
	return item


func _escolher_dado() -> ItemData:
	# chance de item especial
	if randf() < config.chance_especial:
		for d in catalogo:
			if d.especial:
				return d
	# sorteio ponderado entre itens comuns
	var r: float = randf() * _peso_total
	for d in catalogo:
		if d.especial:
			continue
		r -= maxf(d.peso, 0.001)
		if r <= 0.0:
			return d
	# fallback: primeiro item comum
	for d in catalogo:
		if not d.especial:
			return d
	return catalogo[0]
