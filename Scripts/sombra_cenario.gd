class_name SombraCenario
extends RefCounted

# =========================
# SOMBRA POR CENARIO
# =========================
#
# Olha para a arte solida das "paredes" do cenario (predios, paredes com
# portas, muros, cercas...) e descobre as faixas horizontais, em coordenadas
# de mundo, onde existe estrutura atras do personagem.
#
# A sombra existe dentro dessas faixas e desaparece suavemente fora delas
# (por exemplo, quando o personagem anda na frente do parallax da cidade).

# Cada Vector2 guarda um intervalo: x = inicio, y = fim (em mundo).
var _intervalos: Array[Vector2] = []

# Largura da transicao suave nas bordas de cada intervalo.
var _banda: float = 150.0


# Constroi os intervalos a partir dos sprites das paredes que tiverem
# pixels opacos dentro da faixa vertical [y_min, y_max] do personagem.
func construir(
	nos: Array,
	y_min: float,
	y_max: float,
	banda: float = 150.0,
	passo: int = 4
) -> void:
	_banda = banda
	_intervalos.clear()

	var xs: Array[float] = []

	for no in nos:
		if not (no is Sprite2D):
			continue

		var sprite: Sprite2D = no
		var textura: Texture2D = sprite.texture
		if textura == null:
			continue

		var img: Image = textura.get_image()
		if img == null:
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img = img.duplicate() as Image
			img.convert(Image.FORMAT_RGBA8)

		var w: int = img.get_width()
		var h: int = img.get_height()
		var pos: Vector2 = sprite.global_position
		var rot: float = sprite.global_rotation
		var scl: Vector2 = sprite.global_scale
		var ox: float = float(w) * 0.5
		var oy: float = float(h) * 0.5

		var ty: int = 0
		while ty < h:
			var tx: int = 0
			while tx < w:
				if img.get_pixel(tx, ty).a >= 0.5:
					var local := Vector2(
						(float(tx) - ox) * scl.x,
						(float(ty) - oy) * scl.y
					)
					var mundo: Vector2 = pos + local.rotated(rot)
					if mundo.y >= y_min and mundo.y <= y_max:
						xs.append(mundo.x)
				tx += passo
			ty += passo

	if xs.is_empty():
		return

	xs.sort()

	var inicio: float = xs[0]
	var anterior: float = xs[0]
	for x in xs:
		if x - anterior > 24.0:
			_intervalos.append(Vector2(inicio, anterior))
			inicio = x
		anterior = x
	_intervalos.append(Vector2(inicio, anterior))


# Retorna 0.0 fora de qualquer intervalo (sem parede atras) e 1.0 dentro,
# com uma transicao suave (smoothstep) ao longo de _banda nas bordas.
func alpha_em(x: float) -> float:
	if _intervalos.is_empty():
		# Sem paredes detectadas: mantem a sombra (comportamento seguro).
		return 1.0

	var melhor: float = 0.0
	for iv in _intervalos:
		var distancia: float = 0.0
		if x < iv.x:
			distancia = iv.x - x
		elif x > iv.y:
			distancia = x - iv.y

		var a: float = 1.0 - clampf(distancia / _banda, 0.0, 1.0)
		a = a * a * (3.0 - 2.0 * a)
		if a > melhor:
			melhor = a

	return melhor