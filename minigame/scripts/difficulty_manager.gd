class_name DifficultyManager
extends Node
## Controla a dificuldade progressiva (velocidade da esteira e intervalo de geração).

signal velocidade_mudou(valor: float)
signal intervalo_mudou(valor: float)

var velocidade: float = 165.0
var intervalo: float = 1.35
var _config: GameConfig = null


func configurar(config: GameConfig) -> void:
	_config = config
	resetar()


func resetar() -> void:
	if _config == null:
		return
	velocidade = _config.velocidade_inicial
	intervalo = _config.intervalo_inicial
	velocidade_mudou.emit(velocidade)
	intervalo_mudou.emit(intervalo)


## Aumenta a velocidade gradualmente e reduz o intervalo de geração.
func atualizar(delta: float) -> void:
	if _config == null:
		return

	var v_anterior: float = velocidade
	velocidade = minf(velocidade + _config.aceleracao_velocidade * delta, _config.velocidade_maxima)
	if not is_equal_approx(v_anterior, velocidade):
		velocidade_mudou.emit(velocidade)

	var t: float = 0.0
	var faixa: float = _config.velocidade_maxima - _config.velocidade_inicial
	if faixa > 0.0:
		t = clampf((velocidade - _config.velocidade_inicial) / faixa, 0.0, 1.0)
	intervalo = lerpf(_config.intervalo_inicial, _config.intervalo_minimo, t)
	intervalo_mudou.emit(intervalo)