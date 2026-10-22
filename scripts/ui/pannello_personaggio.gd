## Scheda compatta di un Personaggio: tracce (Energia, Salute, Terrore), risorse e attributi.
class_name PannelloPersonaggio
extends PanelContainer

signal scelto(id: String)
signal apri_scheda(id: String)

var partita: Partita
var pid: String
var _corpo: VBoxContainer

func _init(partita_: Partita, id: String) -> void:
	partita = partita_
	pid = id

func _ready() -> void:
	custom_minimum_size = Vector2(410, 0)
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 4)
	add_child(_corpo)
	aggiorna()

func personaggio() -> Dictionary:
	for x in partita.personaggi():
		if str(x["id"]) == pid:
			return x
	return {}

func aggiorna() -> void:
	for c in _corpo.get_children():
		c.queue_free()
	var x := personaggio()
	if x.is_empty():
		return
	var dd := Personaggi.dati(pid)
	var attivo: bool = partita.attivo() == x
	add_theme_stylebox_override("panel", Tema.box_pannello(Color(0.11, 0.08, 0.06, 0.93) if attivo else Color(0.07, 0.055, 0.045, 0.85), Tema.ORO if attivo else Tema.BORDO))
	var testa := HBoxContainer.new()
	testa.add_theme_constant_override("separation", 8)
	var pall := ColorRect.new()
	pall.color = dd.get("colore", Color.WHITE)
	pall.custom_minimum_size = Vector2(8, 26)
	testa.add_child(pall)
	var nome := Tema.etichetta(str(x["nome"]).to_upper(), 20, Tema.ORO if attivo else Tema.TESTO, attivo)
	nome.mouse_filter = Control.MOUSE_FILTER_STOP
	nome.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: apri_scheda.emit(pid))
	nome.tooltip_text = "Apri la scheda completa"
	testa.add_child(nome)
	var stato := []
	if x.get("passato", false):
		stato.append("ha passato")
	if Personaggi.esausto(x):
		stato.append("Esausto")
	if Personaggi.in_panico(x):
		stato.append("Panico")
	if Personaggi.in_follia(x):
		stato.append("Follia")
	if Personaggi.morente(x):
		stato.append("MORENTE")
	var st := Label.new()
	st.text = "  ·  ".join(stato)
	st.add_theme_color_override("font_color", Tema.ROSSO if Personaggi.morente(x) or Personaggi.in_follia(x) else Tema.TESTO_2)
	st.add_theme_font_size_override("font_size", 15)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	testa.add_child(st)
	_corpo.add_child(testa)
	var luogo := Label.new()
	var nl := Dati.testo_piano(str(Dati.luogo(partita.camp, Dati.id_numero(partita.camp, int(x["luogo"]))).get("nome", "")))
	luogo.text = "Luogo %d · %s" % [int(x["luogo"]), nl]
	luogo.add_theme_font_size_override("font_size", 16)
	luogo.add_theme_color_override("font_color", Tema.TESTO_2)
	_corpo.add_child(luogo)
	# plancia originale con i segnalini sulle tracce, i valori di risorse e Attributi
	_corpo.add_child(_plancia(x, dd))
	var og: Array = x.get("oggetti", [])
	if not og.is_empty():
		var o := Label.new()
		o.text = "Oggetti: " + ", ".join(og.map(func(i): return Carte.nome(i)))
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.add_theme_font_size_override("font_size", 15)
		o.add_theme_color_override("font_color", Tema.TESTO_2)
		_corpo.add_child(o)

## Posizioni sulla plancia (frazioni dell'immagine): colonne delle tracce, righe, riquadri.
const COL_TRACCE := {"energia": 0.734, "salute": 0.788, "terrore": 0.841}
const RIGA_0 := 0.095
const PASSO_RIGA := 0.0792
const CELLA := Vector2(0.05, 0.072)
const RISORSE_X := {"cibo": 0.198, "ricchezza": 0.307, "rep": 0.414, "esp": 0.523, "magia": 0.631}
const RISORSE_Y := 0.80
const ATTRIBUTI_POS := {"aggression": Vector2(0.054, 0.178), "courage": Vector2(0.054, 0.496), "practicality": Vector2(0.054, 0.814),
	"empathy": Vector2(0.946, 0.178), "caution": Vector2(0.946, 0.496), "spirituality": Vector2(0.946, 0.814)}
const RIQUADRO := Rect2(0.129, 0.019, 0.542, 0.636)

func _plancia(x: Dictionary, dd: Dictionary) -> Control:
	var radice := Control.new()
	radice.custom_minimum_size = Vector2(390, 390 * 1572.0 / 2400.0)
	radice.mouse_filter = Control.MOUSE_FILTER_STOP
	radice.tooltip_text = "%s — clic sul nome per la scheda completa" % x["nome"]
	var fondo := TextureRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(fondo)
	Immagini.carica(str(dd.get("plancia", "")), func(t): if is_instance_valid(fondo): fondo.texture = t)
	var tessera := TextureRect.new()
	tessera.anchor_left = RIQUADRO.position.x
	tessera.anchor_top = RIQUADRO.position.y
	tessera.anchor_right = RIQUADRO.end.x
	tessera.anchor_bottom = RIQUADRO.end.y
	tessera.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tessera.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tessera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(tessera)
	Immagini.carica(str(dd.get("tessera", "")), func(t): if is_instance_valid(tessera): tessera.texture = t)
	var sopra := Control.new()
	sopra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sopra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(sopra)
	var f_num := Tema.titolo_forte
	sopra.draw.connect(func():
		var dim := sopra.size
		# segnalini delle tracce: riga = 9 − valore (sfalsata per Salute e Terrore come sulla plancia)
		var tr := {"energia": [int(x.get("energia", 0)), 0, Color(0.45, 0.95, 0.35)],
			"salute": [int(x.get("salute", 0)), int(dd.get("scarto_s", 0)), Color(1.0, 0.3, 0.25)],
			"terrore": [int(x.get("terrore", 0)), int(dd.get("scarto_t", 0)), Color(0.8, 0.45, 1.0)]}
		for k in tr:
			var riga := clampi(9 - int(tr[k][1]) - int(tr[k][0]), 0, 9)
			var c := Vector2(COL_TRACCE[k] * dim.x, (RIGA_0 + riga * PASSO_RIGA) * dim.y)
			var r := Rect2(c - CELLA * dim / 2.0, CELLA * dim)
			var col: Color = tr[k][2]
			sopra.draw_rect(r.grow(1), Color(col, 0.35), true)
			sopra.draw_rect(r.grow(1), col, false, 2.5)
		# risorse nei riquadri in basso
		for k in RISORSE_X:
			var c2 := Vector2(RISORSE_X[k] * dim.x, RISORSE_Y * dim.y)
			var t2 := str(int(x.get(k, 0)))
			var fs := int(dim.y * 0.13)
			var w := f_num.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			sopra.draw_string_outline(f_num, c2 + Vector2(-w / 2, fs * 0.35), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.9))
			sopra.draw_string(f_num, c2 + Vector2(-w / 2, fs * 0.35), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tema.ORO)
		# Attributi sulle icone ai lati
		for k in ATTRIBUTI_POS:
			var c3: Vector2 = ATTRIBUTI_POS[k] * dim
			var v := partita.attributo(x, k)
			var rr := dim.y * 0.045
			sopra.draw_circle(c3, rr, Color(0.08, 0.05, 0.03, 0.85))
			sopra.draw_arc(c3, rr, 0, TAU, 24, Tema.ORO if v > 0 else Tema.TESTO_2, 2.0)
			var t3 := str(v)
			var fs3 := int(rr * 1.5)
			var w3 := f_num.get_string_size(t3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
			sopra.draw_string(f_num, c3 + Vector2(-w3 / 2, fs3 * 0.36), t3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, Tema.ORO if v > 0 else Tema.TESTO_2)
		)
	sopra.resized.connect(sopra.queue_redraw)
	return radice
