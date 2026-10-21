## Finestra dell'Incontro: carta nemica a sinistra, Sequenza al centro, mano del personaggio
## attivo in basso. Le carte giocabili sono evidenziate; passando sopra una carta si vedono i bonus
## delle Chiavi che otterrebbe. Riserva / Affinità e registro dei passi a destra.
class_name FinestraIncontro
extends Control

signal finito(esito: String)

var partita: Partita
var inc: Incontro
var _nemico: TextureRect
var _stato: RichTextLabel
var _seq: HBoxContainer
var _mano: HBoxContainer
var _comandi: HBoxContainer
var _log: RichTextLabel
var _anteprima: Label
var _fase := "inizio"   # inizio, scegli, gioca, fine

func _init(partita_: Partita, img: String, colore: String) -> void:
	partita = partita_
	inc = Incontro.new(partita, img, colore)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.015, 0.94)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 20)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	m.add_child(h)
	# carta nemica
	var sx := VBoxContainer.new()
	sx.custom_minimum_size = Vector2(430, 0)
	h.add_child(sx)
	_nemico = TextureRect.new()
	_nemico.custom_minimum_size = Vector2(430, 652)
	_nemico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nemico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Immagini.carica(Carte.immagine(inc.img), func(t): if is_instance_valid(_nemico): _nemico.texture = t)
	sx.add_child(_nemico)
	_stato = Tema.testo_ricco(19)
	sx.add_child(_stato)
	# centro: Sequenza, mano, comandi
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 12)
	h.add_child(c)
	c.add_child(Tema.etichetta("SEQUENZA", 16, Tema.TESTO_2))
	var sseq := ScrollContainer.new()
	sseq.custom_minimum_size = Vector2(0, 340)
	sseq.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sseq)
	_seq = HBoxContainer.new()
	_seq.add_theme_constant_override("separation", -150)
	sseq.add_child(_seq)
	_anteprima = Label.new()
	_anteprima.add_theme_color_override("font_color", Tema.ORO)
	_anteprima.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anteprima.custom_minimum_size = Vector2(0, 50)
	c.add_child(_anteprima)
	_comandi = HBoxContainer.new()
	_comandi.add_theme_constant_override("separation", 10)
	c.add_child(_comandi)
	c.add_child(Tema.etichetta("MANO", 16, Tema.TESTO_2))
	var sm := ScrollContainer.new()
	sm.custom_minimum_size = Vector2(0, 330)
	sm.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sm)
	_mano = HBoxContainer.new()
	_mano.add_theme_constant_override("separation", 12)
	sm.add_child(_mano)
	# destra: registro
	var dx := PanelContainer.new()
	dx.custom_minimum_size = Vector2(380, 0)
	h.add_child(dx)
	var dv := VBoxContainer.new()
	dx.add_child(dv)
	dv.add_child(Tema.etichetta("CRONACA DELL'INCONTRO", 15))
	var sl := ScrollContainer.new()
	sl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sl.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(sl)
	_log = Tema.testo_ricco(16)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_child(_log)
	inc.messaggio.connect(func(t):
		_log.text = "• " + Dati.testo_bb(t, 18) + "\n" + _log.text)
	inc.cambiato.connect(_aggiorna)
	inc.finito.connect(func(e): _fase = "fine"; _aggiorna())
	if inc.speciale():
		_fase = "speciale"
	else:
		inc.inizia(partita.compagnia().filter(func(p): return int(p["salute"]) > 0))
	_aggiorna()

func _aggiorna() -> void:
	_stato.text = _testo_stato()
	for x in _seq.get_children():
		x.queue_free()
	for s in inc.sequenza:
		var t := _carta(str(s["img"]), Vector2(220, 333))
		if int(s.get("tempo", 0)) > 0:
			t.tooltip_text = "Gettoni Tempo: %d" % int(s["tempo"])
			t.modulate = Color(1, 0.92, 0.8)
		_seq.add_child(t)
	for x in _mano.get_children():
		x.queue_free()
	for x in _comandi.get_children():
		x.queue_free()
	match _fase:
		"speciale":
			_speciale()
		"inizio":
			_anteprima.text = "Puoi rimescolare la mano (con una carta in meno) prima di iniziare."
			_mostra_mano(inc.membri[0] if not inc.membri.is_empty() else {}, false)
			for p in inc.membri:
				var id := str(p["id"])
				_comandi.add_child(Tema.pulsante("RIMESCOLA (%s)" % p["nome"], func(): inc.rimescola_mano(id), 15))
			if inc.diplomazia and inc.carta.get("evitare") is Dictionary:
				_comandi.add_child(Tema.pulsante("EVITARE: " + Dati.testo_piano(str(inc.carta["evitare"].get("it", ""))), func(): inc.evita(), 15))
			_comandi.add_child(Tema.pulsante_primario("INIZIA", func(): _fase = "scegli"; _aggiorna()))
		"scegli":
			var liberi := inc.da_attivare()
			if liberi.is_empty():
				inc.fine_turno()
				return
			_anteprima.text = "Turno %d: chi si attiva?" % inc.turno
			for p in liberi:
				var id := str(p["id"])
				_comandi.add_child(Tema.pulsante_primario("ATTIVA %s" % str(p["nome"]).to_upper(), func():
					inc.attiva(id)
					_fase = "gioca"
					_aggiorna()))
			if not liberi.is_empty():
				_mostra_mano(liberi[0], false)
		"gioca":
			var a := inc.attivo()
			if inc.concluso != "":
				_fase = "fine"
				_aggiorna()
				return
			_anteprima.text = "%s: gioca una carta%s, poi TERMINA. %s" % [a["nome"],
				"" if inc.carte_attivazione == 0 else " collegata con una Chiave dorata (carta aggiuntiva)",
				"IN PANICO: la prima carta è quella in cima al mazzo." if inc.in_panico() and inc.carte_attivazione == 0 else ""]
			if inc.in_panico() and inc.carte_attivazione == 0 and not inc.mazzi[str(a["id"])].is_empty():
				var cima: String = inc.mazzi[str(a["id"])][0]
				_comandi.add_child(Tema.pulsante_primario("GIOCA LA CARTA IN CIMA AL MAZZO", func(): inc.gioca(cima), 15))
			else:
				_mostra_mano(a, true)
			var pm := CheckBox.new()
			pm.text = "Paga Magia per le Chiavi Magiche"
			pm.button_pressed = inc.paga_magia
			pm.toggled.connect(func(v): inc.paga_magia = v; _aggiorna())
			_comandi.add_child(pm)
			_comandi.add_child(Tema.pulsante_primario("TERMINA L'ATTIVAZIONE", func():
				inc.termina_carte()
				if inc.concluso == "":
					_fase = "scegli"
				_aggiorna(), 16))
			_comandi.add_child(Tema.pulsante("SCAPPARE" if not inc.diplomazia else "RINUNCIARE", func():
				inc.scappa()
				if inc.concluso == "":
					_fase = "scegli"
				_aggiorna(), 15))
			_correzioni()
		"fine":
			_anteprima.text = {"vittoria": "Vittoria!", "fallimento": "Fallimento.", "fuga": "Siete scappati.", "fuga_nemico": "Il nemico è fuggito.", "evitato": "Incontro evitato.", "morte": "La Compagnia è caduta."}.get(inc.concluso, inc.concluso)
			_comandi.add_child(Tema.pulsante_primario("TORNA ALLA MAPPA", _chiudi, 17))

func _chiudi() -> void:
	if inc.guardiano_resta():
		partita.d.get_or_add("guardiani", {})[str(partita.luogo_attivo())] = inc.img
		partita.racconta("Il Guardiano %s resta al Luogo %d" % [Carte.nome(inc.img), partita.luogo_attivo()])
	finito.emit(inc.concluso)
	queue_free()

## Incontri speciali (senza Chiavi): si mostra il testo e si applica l'effetto.
func _speciale() -> void:
	var e = inc.carta.get("effetto", inc.carta.get("testo", {}))
	var t := str(e.get("it", "")) if e is Dictionary else ""
	_anteprima.text = Dati.testo_piano(t)
	_comandi.add_child(Tema.pulsante_primario("APPLICA L'EFFETTO", func():
		var fatti := Effetti.applica(t, partita)
		for f in fatti:
			inc.nota(("✔ " if f.get("fatto", false) else "☐ da fare: ") + str(f["testo"]))
		inc.concluso = "speciale"
		_fase = "fine"
		_aggiorna()))
	_comandi.add_child(Tema.pulsante("CHIUDI", func(): inc.concluso = "speciale"; _chiudi()))

func _testo_stato() -> String:
	var c := inc.carta
	var t := "[b]%s[/b]" % Carte.nome(inc.img)
	if not inc.tratti().is_empty():
		t += "  ·  " + ", ".join(inc.tratti())
	t += "\n"
	if inc.diplomazia:
		var a: Dictionary = c.get("affinita", {})
		var fs: Array = c.get("fasi", [])
		t += "Affinità: [b]%+d[/b] (vittoria a +%d, fallimento a −%d)\n" % [inc.affinita, int(a.get("verdi", 3)), int(a.get("rossi", 3))]
		if not fs.is_empty():
			var f: Dictionary = fs[clampi(inc.fase, 0, fs.size() - 1)]
			t += "Fase %d/%d: %s\n" % [inc.fase + 1, fs.size(), str(f.get("nome", {}).get("it", "")) if f.get("nome") is Dictionary else ""]
	else:
		t += "Riserva: [b]%d[/b] / Valore %d\n" % [inc.riserva, int(c.get("valore", 0))]
		var r := inc.riga_tabella()
		if not r.is_empty():
			t += "Attacco previsto: %s\n" % Dati.testo_bb(str(r.get("it", "")), 18)
	if inc.prevenzione > 0:
		t += "Ferite prevenute: %d\n" % inc.prevenzione
	for p in inc.membri:
		t += "\n%s — Salute %d, Energia %d, Terrore %d, Magia %d · mano %d, mazzo %d" % [p["nome"], int(p["salute"]), int(p["energia"]), int(p["terrore"]), int(p["magia"]),
			inc.mani.get(str(p["id"]), []).size(), inc.mazzi.get(str(p["id"]), []).size()]
	return Dati.testo_bb(t, 18)

func _mostra_mano(p: Dictionary, giocabile: bool) -> void:
	if p.is_empty():
		return
	for c in inc.mani.get(str(p["id"]), []):
		var t := _carta(c, Vector2(200, 303))
		if giocabile:
			var ok := inc.giocabile(c)
			t.modulate = Color.WHITE if ok else Color(0.5, 0.5, 0.5)
			t.mouse_entered.connect(func(): _anteprima.text = _descrivi_collegamenti(c))
			if ok:
				t.gui_input.connect(func(e):
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						inc.gioca(c))
		_mano.add_child(t)

func _descrivi_collegamenti(c: String) -> String:
	var righe := []
	for k in inc.collegamenti(c):
		var b := ", ".join(k["bonus"].map(func(x): return str(x)))
		match k["tipo"]:
			"fondo":
				righe.append("fondo: %s ×%d" % [b, int(k["molt"])])
			"magia":
				righe.append("riga %d (Magia): %s%s" % [k["riga"], b, "" if k["ok"] else " — niente Magia"])
			_:
				righe.append("riga %d (%s%s): %s%s" % [k["riga"], Partita.NOMI_ATTRIBUTI.get(k["attr"], k["attr"]), (" %d" % int(k.get("liv", 1))) if int(k.get("liv", 1)) > 1 else "", b, "" if k["ok"] else " — attributo insufficiente"])
	var d := Carte.dati(c)
	var cap := ""
	var x = d.get("capacita")
	if x is Dictionary:
		cap = str(x.get("it", ""))
	elif x is Array:
		cap = " / ".join(x.map(func(y): return str(y.get("it", ""))))
	return "%s — collegamenti: %s%s" % [Carte.nome(c), "; ".join(righe) if not righe.is_empty() else "nessuno", ("\nCapacità: " + Dati.testo_piano(cap)) if cap != "" else ""]

func _carta(c: String, dim: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = dim
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.tooltip_text = Carte.nome(c)
	Immagini.carica(Carte.immagine(c), func(tx): if is_instance_valid(t): t.texture = tx)
	return t

## Correzioni a mano della Riserva / Affinità (per gli effetti non automatizzati).
func _correzioni() -> void:
	var nome := "Affinità" if inc.diplomazia else "Riserva"
	_comandi.add_child(Tema.pulsante("%s −1" % nome, func():
		if inc.diplomazia:
			inc.affinita -= 1
		else:
			inc.riserva = maxi(0, inc.riserva - 1)
		_aggiorna(), 14))
	_comandi.add_child(Tema.pulsante("%s +1" % nome, func():
		if inc.diplomazia:
			inc.affinita += 1
		else:
			inc.riserva += 1
		inc._controlla_fine_carte()
		_aggiorna(), 14))
