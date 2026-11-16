## Carta disegnata nella finestra dell'Incontro (carta nemica, Sequenza, mano), con sopra i segni di gioco:
## semichiavi che si collegano (riquadro verde) o no (riquadro rosso barrato), gettoni Tempo, Cariche,
## cubetti universali (Riserva in combattimento, marcatore sul misuratore di Affinità in diplomazia)
## e la riga della tabella del nemico in vigore. Tutto è disegnato: nessun simbolo da font.
class_name CartaIncontro
extends TextureRect

## Proporzioni delle carte (combattimento, diplomazia e Incontri hanno lo stesso formato).
const RAPPORTO := 585.0 / 826.0
## Centri verticali delle righe di Chiavi 1-4 e della Chiave in fondo (frazioni dell'altezza).
const RIGHE_GIOCO := {1: 0.115, 2: 0.258, 3: 0.403, 4: 0.57, 5: 0.9}
const RIGHE_NEMICO := {1: 0.11, 2: 0.255, 3: 0.4, 4: 0.57, 5: 0.9}
## Colonne delle semichiavi: bonus (a sinistra) e apertura (a destra) sulle carte del Personaggio,
## apertura sul bordo destro della carta nemica.
const COL_BONUS := Vector2(0.0, 0.15)
const COL_APRE := Vector2(0.172, 0.322)
const COL_NEMICO := Vector2(0.853, 0.997)
const MEZZA_ALTEZZA := 0.056
## Parte della carta che resta scoperta quando sopra se ne gioca un'altra.
const SCOPERTA := 0.316
## Misuratore di Affinità: centro della casella più bassa e passo fra le caselle.
const AFF_X := 0.062
const AFF_FONDO := 0.849
const AFF_PASSO := 0.081

var img := ""
var nemico := false
## Segni sulle semichiavi: [{"riga": int, "col": "bonus"|"apre", "ok": bool}]
var segni: Array = []
var tempo := 0
var cariche := 0
## Cubetti della Riserva sul nemico (−1: non mostrati) e Valore da raggiungere.
var cubi := -1
var valore := 0
## Casella del misuratore di Affinità dal basso (−1: non mostrata).
var casella_affinita := -1
## Riga della tabella del nemico in vigore (frazioni della carta), vuota se nessuna.
var riga_tabella := Rect2()
var selezionata := false

func _init(img_: String, altezza: float, nemico_ := false) -> void:
	img = img_
	nemico = nemico_
	custom_minimum_size = Vector2(altezza * RAPPORTO, altezza)
	size = custom_minimum_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = Carte.nome(img)
	Immagini.carica(Carte.immagine(img), func(t): if is_instance_valid(self): texture = t)

func rettangolo_chiave(riga: int, col: String) -> Rect2:
	var cy: float = (RIGHE_NEMICO if nemico else RIGHE_GIOCO).get(riga, 0.5)
	var cx: Vector2 = COL_NEMICO if nemico else (COL_BONUS if col == "bonus" else COL_APRE)
	return Rect2(cx.x * size.x, (cy - MEZZA_ALTEZZA) * size.y, (cx.y - cx.x) * size.x, MEZZA_ALTEZZA * 2 * size.y)

func _draw() -> void:
	var s := size
	var font := get_theme_default_font()
	# riga in vigore della tabella del nemico
	if riga_tabella.size != Vector2.ZERO:
		var rt := Rect2(riga_tabella.position * s, riga_tabella.size * s)
		draw_rect(rt.grow(2), Color(0.85, 0.2, 0.15, 0.18), true)
		draw_rect(rt.grow(2), Color(0.95, 0.3, 0.2), false, 3.0)
	# semichiavi
	for g in segni:
		var col := str(g.get("col", "apre"))
		var r := rettangolo_chiave(int(g["riga"]), col)
		var forma := _forma_chiave(r, col == "bonus" and not nemico)
		if g["ok"]:
			draw_colored_polygon(forma, Color(0.4, 1.0, 0.35, 0.18))
			forma.append(forma[0])
			draw_polyline(forma, Color(0.45, 1.0, 0.4, 0.35), 9.0, true)
			draw_polyline(forma, Color(0.55, 1.0, 0.45), 3.5, true)
		else:
			var rosso := Color(0.95, 0.3, 0.22, 0.9)
			draw_colored_polygon(forma, Color(0.3, 0, 0, 0.22))
			forma.append(forma[0])
			draw_polyline(forma, rosso, 3.0, true)
			var q := r.grow(-r.size.y * 0.22)
			draw_line(q.position, q.end, rosso, 2.5, true)
			draw_line(Vector2(q.end.x, q.position.y), Vector2(q.position.x, q.end.y), rosso, 2.5, true)
	# gettoni Tempo (nella parte che resta scoperta della carta)
	var rg := s.x * 0.055
	for i in tempo:
		var c := Vector2(s.x * 0.16, s.y * (0.65 + i * 0.07))
		draw_circle(c, rg + 2, Color(0.1, 0.06, 0.02))
		draw_circle(c, rg, Color(0.86, 0.68, 0.3))
		draw_arc(c, rg * 0.7, 0, TAU, 20, Color(0.25, 0.15, 0.05), 2.0)
		draw_line(c, c + Vector2(0, -rg * 0.6), Color(0.25, 0.15, 0.05), 2.5)
		draw_line(c, c + Vector2(rg * 0.45, 0), Color(0.25, 0.15, 0.05), 2.5)
	if cariche > 0:
		var cc := Vector2(s.x * 0.16, s.y * (0.65 + tempo * 0.07 + 0.02))
		draw_circle(cc, rg + 2, Color(0.02, 0.05, 0.12))
		draw_circle(cc, rg, Color(0.35, 0.6, 0.95))
		var t := str(cariche)
		var fs := int(rg * 1.3)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, cc + Vector2(-w / 2, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# cubetti universali della Riserva sull'illustrazione del nemico
	if cubi >= 0:
		var lato := s.x * 0.085
		var per_riga := 7
		var o := Vector2(s.x * 0.07, s.y * 0.19)
		var mostrati := mini(cubi, 28)
		for i in mostrati:
			var p := o + Vector2((i % per_riga) * lato * 1.12, (i / per_riga) * lato * 1.12)
			_cubo(p, lato, Color(0.78, 0.13, 0.1))
		var testo := "Riserva %d / %d" % [cubi, valore]
		var fs2 := int(s.y * 0.045)
		var y := o.y + (maxi(1, ceili(mostrati / float(per_riga)))) * lato * 1.12 + fs2
		var w2 := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_rect(Rect2(o.x - 6, y - fs2 - 2, w2 + 12, fs2 + 12), Color(0, 0, 0, 0.7), true)
		draw_string(font, Vector2(o.x, y + 4), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 0.85, 0.55) if cubi < valore else Color(0.55, 1, 0.5))
	# marcatore sul misuratore di Affinità
	if casella_affinita >= 0:
		var lato2 := s.x * 0.075
		var c2 := Vector2(s.x * AFF_X, s.y * (AFF_FONDO - casella_affinita * AFF_PASSO))
		draw_circle(c2, lato2 * 0.95, Color(1, 0.9, 0.5, 0.35))
		_cubo(c2 - Vector2(lato2, lato2) / 2, lato2, Color(0.92, 0.9, 0.85))
	if selezionata:
		draw_rect(Rect2(Vector2.ZERO, s).grow(-2), Tema.ORO, false, 4.0)

## Contorno di una semichiave come è stampata: cornice quadrata con gli angoli smussati e la punta a
## freccia sul lato esterno (a destra per le semichiavi che aprono, a sinistra per quelle dei bonus).
func _forma_chiave(r: Rect2, punta_a_sinistra: bool) -> PackedVector2Array:
	var punta := r.size.x * 0.13
	var a := r.size.y * 0.2      # mezza base della punta
	var c := r.size.y * 0.14     # smussatura degli angoli
	var L := r.position.x + (punta if punta_a_sinistra else 0.0)
	var R := r.end.x - (0.0 if punta_a_sinistra else punta)
	var T := r.position.y
	var B := r.end.y
	var m := (T + B) / 2.0
	var p := PackedVector2Array([Vector2(L + c, T), Vector2(R - c, T), Vector2(R, T + c)])
	if not punta_a_sinistra:
		p.append_array([Vector2(R, m - a), Vector2(r.end.x, m), Vector2(R, m + a)])
	p.append_array([Vector2(R, B - c), Vector2(R - c, B), Vector2(L + c, B), Vector2(L, B - c)])
	if punta_a_sinistra:
		p.append_array([Vector2(L, m + a), Vector2(r.position.x, m), Vector2(L, m - a)])
	p.append(Vector2(L, T + c))
	return p

## Cubetto in prospettiva (faccia, lato superiore più chiaro, lato destro più scuro).
func _cubo(p: Vector2, lato: float, col: Color) -> void:
	var d := lato * 0.22
	draw_rect(Rect2(p + Vector2(0, d), Vector2(lato - d, lato - d)), col, true)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, d), p + Vector2(d, 0), p + Vector2(lato, 0), p + Vector2(lato - d, d)]), col.lightened(0.35))
	draw_colored_polygon(PackedVector2Array([p + Vector2(lato - d, d), p + Vector2(lato, 0), p + Vector2(lato, lato - d), p + Vector2(lato - d, lato)]), col.darkened(0.35))
	draw_rect(Rect2(p + Vector2(0, d), Vector2(lato - d, lato - d)), Color(0, 0, 0, 0.6), false, 1.5)
