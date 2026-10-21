## Scheda compatta di un Personaggio: tracce (Energia, Salute, Terrore), risorse e attributi.
## Ogni valore si corregge a mano con un clic (sinistro +1, destro −1): serve quando un effetto
## del Diario o di una carta non è stato automatizzato.
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
	custom_minimum_size = Vector2(330, 0)
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
	# tracce
	_corpo.add_child(_traccia(x, "energia", "energy", Personaggi.limite(x, "energia"), Tema.VERDE))
	_corpo.add_child(_traccia(x, "salute", "health", Personaggi.limite(x, "salute"), Tema.ROSSO))
	_corpo.add_child(_traccia(x, "terrore", "terror", Personaggi.limite(x, "terrore"), Tema.VIOLA))
	# risorse
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	for k in ["cibo", "ricchezza", "magia", "esp", "rep"]:
		r.add_child(_valore(x, k, Partita.NOMI_RISORSE[k], ""))
	_corpo.add_child(r)
	# attributi in coppie
	var a := HFlowContainer.new()
	a.add_theme_constant_override("h_separation", 8)
	for k in ["aggression", "empathy", "courage", "caution", "practicality", "spirituality"]:
		a.add_child(_valore(x, k, "", k, true))
	_corpo.add_child(a)
	var og: Array = x.get("oggetti", [])
	if not og.is_empty():
		var o := Label.new()
		o.text = "Oggetti: " + ", ".join(og.map(func(i): return Carte.nome(i)))
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.add_theme_font_size_override("font_size", 15)
		o.add_theme_color_override("font_color", Tema.TESTO_2)
		_corpo.add_child(o)

func _traccia(x: Dictionary, k: String, ic: String, mx: int, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := TextureRect.new()
	t.texture = load(Dati.icona(ic))
	t.custom_minimum_size = Vector2(22, 22)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(t)
	var barra := Control.new()
	barra.custom_minimum_size = Vector2(200, 18)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := int(x.get(k, 0))
	barra.draw.connect(func():
		var w := barra.size.x
		var n := maxi(mx, 1)
		var cw := w / n
		for i in n:
			var r := Rect2(i * cw + 1, 2, cw - 2, barra.size.y - 4)
			barra.draw_rect(r, col if i < v else Color(0.18, 0.14, 0.11), true)
		)
	barra.mouse_filter = Control.MOUSE_FILTER_STOP
	barra.tooltip_text = "%s %d/%d — clic sinistro +1, destro −1" % [k.capitalize(), v, mx]
	barra.gui_input.connect(func(e): _correggi(e, x, k))
	h.add_child(barra)
	var l := Label.new()
	l.text = "%d" % v
	l.custom_minimum_size = Vector2(26, 0)
	l.add_theme_font_override("font", Tema.titolo)
	h.add_child(l)
	return h

func _valore(x: Dictionary, k: String, nome: String, icona: String, attributo := false) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	if icona != "":
		var t := TextureRect.new()
		t.texture = load(Dati.icona(icona))
		t.custom_minimum_size = Vector2(20, 20)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
	var v := partita.attributo(x, k) if attributo else int(x.get(k, 0))
	var l := Label.new()
	l.text = ("%s %d" % [nome, v]) if nome != "" else str(v)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Tema.RISORSA if nome != "" else Tema.TESTO)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	h.tooltip_text = "%s — clic sinistro +1, destro −1" % (Partita.NOMI_ATTRIBUTI.get(k, nome))
	h.gui_input.connect(func(e): _correggi(e, x, k, attributo))
	return h

func _correggi(e: InputEvent, x: Dictionary, k: String, attributo := false) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	var dlt := 1 if e.button_index == MOUSE_BUTTON_LEFT else (-1 if e.button_index == MOUSE_BUTTON_RIGHT else 0)
	if dlt == 0:
		return
	if attributo:
		x["attributi"][k] = maxi(0, partita.attributo(x, k) + dlt)
		partita.cambiato()
	else:
		partita.modifica(x, k, dlt)
	partita.racconta("Correzione a mano: %s %s %+d" % [x["nome"], Partita.NOMI_ATTRIBUTI.get(k, Partita.NOMI_RISORSE.get(k, k)), dlt])
	aggiorna()
