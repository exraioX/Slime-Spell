class_name ScoreManager
extends Node
## Controla pontuação, combo e recorde (salvo localmente em user://).

signal pontuacao_mudou(valor: int)
signal combo_mudou(valor: int)
signal recorde_mudou(valor: int)

const CAMINHO_SAVE := "user://minigame_snackbaskets.cfg"
const SECAO := "recorde"

var pontuacao: int = 0
var combo: int = 0
var recorde: int = 0


func _ready() -> void:
	carregar()


func resetar() -> void:
	pontuacao = 0
	combo = 0
	pontuacao_mudou.emit(pontuacao)
	combo_mudou.emit(combo)


## Registra um acerto, aplicando bônus de combo. Retorna os pontos ganhos.
func registrar_acerto(pontos_base: int, bonus_por_nivel: int, combo_max: int) -> int:
	combo = mini(combo + 1, combo_max)
	var ganho: int = pontos_base + bonus_por_nivel * (combo - 1)
	pontuacao += ganho
	pontuacao_mudou.emit(pontuacao)
	combo_mudou.emit(combo)
	return ganho


func registrar_bonus(pontos: int) -> void:
	pontuacao += pontos
	pontuacao_mudou.emit(pontuacao)


func quebrar_combo() -> void:
	combo = 0
	combo_mudou.emit(combo)


## Encerra a partida; salva e retorna true se houve novo recorde.
func finalizar() -> bool:
	if pontuacao > recorde:
		recorde = pontuacao
		recorde_mudou.emit(recorde)
		salvar()
		return true
	return false


func definir_recorde(valor: int) -> void:
	recorde = maxi(recorde, valor)
	recorde_mudou.emit(recorde)
	salvar()


func carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO_SAVE) == OK:
		recorde = int(cfg.get_value(SECAO, "valor", 0))
	recorde_mudou.emit(recorde)


func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECAO, "valor", recorde)
	cfg.save(CAMINHO_SAVE)