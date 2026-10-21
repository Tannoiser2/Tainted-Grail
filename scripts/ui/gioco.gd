## Schermata della partita: tavolo 3D con la mappa e le miniature, schede dei Personaggi a sinistra,
## barra delle azioni in basso, Diario a destra quando si esplora. Guida la Giornata passo per passo.
class_name Gioco
extends Node

signal esci

var partita: Partita
var giornata: Giornata
var tavolo: Tavolo3D
var _ui: Control
var _schede: VBoxContainer
var _azioni: HBoxContainer
var _info: Label
var _salvataggio: Label
var _titolo: Label
var _diario: PannelloDiario
var _modale: Control
var _viaggio := false
var _evento_btn: Button

func _ready() -> void:
	partita = Campagna.partita
	giornata = Giornata.new(partita)
	tavolo = Tavolo3D.new(partita)
	add_child(tavolo)
	tavolo.luogo_cliccato.connect(_luogo_cliccato)
	tavolo.luogo_sopra.connect(_luogo_sopra)
	var cl := CanvasLayer.new()
	add_child(cl)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Tema.tema
	cl.add_child(_ui)
	_costruisci_hud()
	Campagna.cambiata.connect(_aggiorna)
	Campagna.salvata.connect(func(ok, dove):
		if is_instance_valid(_salvataggio):
			_salvataggio.text = ("✔ salvata " + dove) if ok else ("✘ non salvata " + dove)
			_salvataggio.add_theme_color_override("font_color", Tema.VERDE if ok else Tema.ROSSO))
	tavolo.centra(partita.luogo_attivo(), false)
	_aggiorna()
	if partita.diario.aperto():
		_apri_diario()
	elif str(partita.d.get("fase", "inizio")) == "inizio":
		_inizio_giornata.call_deferred()
	elif str(partita.d.get("fase", "")) == "fine":
		_fine_giornata.call_deferred()

## --- HUD ----------------------------------------------------------------------------

func _costruisci_hud() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 58
	top.add_theme_stylebox_override("panel", Tema.box(Color(0.06, 0.045, 0.035, 0.92), Tema.ORO_SCURO, 0, 0, 16))
	_ui.add_child(top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	top.add_child(h)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(150, 40)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(logo)
	_titolo = Tema.etichetta("", 20, Tema.ORO, true)
	h.add_child(_titolo)
	var f := Control.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(f)
	_salvataggio = Label.new()
	_salvataggio.add_theme_font_size_override("font_size", 15)
	h.add_child(_salvataggio)
	var cod := Tema.etichetta("CODICE " + Campagna.codice(), 17, Tema.TESTO)
	cod.tooltip_text = "Con questo codice riprendi la campagna da qualunque dispositivo."
	cod.mouse_filter = Control.MOUSE_FILTER_STOP
	h.add_child(cod)
	_evento_btn = Tema.pulsante("EVENTO", _mostra_evento, 15)
	h.add_child(_evento_btn)
	h.add_child(Tema.pulsante("STATUS", _mostra_status, 15))
	h.add_child(Tema.pulsante("DIARIO", func(): _apri_diario(true), 15))
	h.add_child(Tema.pulsante("CRONACA", _mostra_cronaca, 15))
	h.add_child(Tema.pulsante("MENU", func(): esci.emit(), 15))
	# schede dei Personaggi
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sc.offset_top = 70
	sc.offset_bottom = -110
	sc.offset_left = 12
	sc.offset_right = 360
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui.add_child(sc)
	_schede = VBoxContainer.new()
	_schede.add_theme_constant_override("separation", 10)
	sc.add_child(_schede)
	for x in partita.personaggi():
		var pp := PannelloPersonaggio.new(partita, str(x["id"]))
		pp.apri_scheda.connect(_scheda_personaggio)
		_schede.add_child(pp)
	# barra delle azioni
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -98
	bar.add_theme_stylebox_override("panel", Tema.box(Color(0.06, 0.045, 0.035, 0.94), Tema.ORO_SCURO, 0, 0, 14))
	_ui.add_child(bar)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bar.add_child(bv)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", Tema.TESTO_2)
	bv.add_child(_info)
	_azioni = HBoxContainer.new()
	_azioni.add_theme_constant_override("separation", 10)
	bv.add_child(_azioni)

func _aggiorna() -> void:
	if not is_instance_valid(_titolo):
		return
	var cap := partita.capitolo()
	_titolo.text = "GIORNATA %d  ·  CAPITOLO %d%s" % [int(partita.d.get("giorno", 1)), cap, partita.lettera_capitolo()]
	for c in _schede.get_children():
		(c as PannelloPersonaggio).aggiorna()
	tavolo.aggiorna()
	_aggiorna_azioni()

func _aggiorna_azioni() -> void:
	for c in _azioni.get_children():
		c.queue_free()
	var x := partita.attivo()
	if x.is_empty():
		return
	var n := int(x["luogo"])
	if _viaggio:
		_info.text = "Scegli sul tavolo il Luogo collegato in cui viaggiare (1 Energia per membro della Compagnia)."
		_azioni.add_child(Tema.pulsante("ANNULLA IL VIAGGIO", func():
			_viaggio = false
			tavolo.evidenzia([])
			_aggiorna_azioni()))
		return
	if str(partita.d.get("fase", "")) != "giorno":
		_info.text = ""
		return
	_info.text = "Tocca a %s — Luogo %d · Energia %d. Compagnia: %s" % [x["nome"], n, int(x["energia"]),
		", ".join(partita.compagnia().map(func(y): return y["nome"]))]
	var puo: bool = not x.get("passato", false) and int(x["energia"]) > 0
	_azione("VIAGGIARE", _inizia_viaggio, puo and not giornata.puo_viaggiare(x).is_empty(), "1 Energia: muovi in un Luogo collegato")
	_azione("ESPLORARE", _esplora, puo, "1 Energia per membro: leggi il Diario di questo Luogo")
	var az := giornata.azione_luogo(n)
	if not az.is_empty():
		var nome := str(az.get("nome", {}).get("it", "Azione del Luogo"))
		_azione(nome.to_upper(), _azione_luogo, puo and not giornata.azione_luogo_usata(n) and int(x["energia"]) >= int(az.get("costo", 0)),
			Dati.testo_piano("%d Energia: %s" % [int(az.get("costo", 0)), str(az.get("it", ""))]))
	var dd := Personaggi.dati(str(x["id"]))
	_azione(str(dd["azione"]["nome"]).to_upper(), _azione_personaggio, puo and int(x["energia"]) >= int(dd["azione"]["costo"]),
		Dati.testo_piano("%d Energia: %s" % [int(dd["azione"]["costo"]), dd["azione"]["testo"]]))
	if _ha_menhir(n):
		_azione("MENHIR", _menhir, true, "Ispeziona il Menhir del Luogo e attivalo")
	_azione("INCONTRO", _incontro_manuale, true, "Pesca un Incontro di un colore (quando il Diario o una carta lo chiedono)")
	var f := Control.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_azioni.add_child(f)
	if partita.personaggi().size() > 1:
		_azione("PROSSIMO PERSONAGGIO", func():
			if not giornata.prossimo():
				_fine_giornata()
			_aggiorna(), true, "Passa il turno al prossimo Personaggio")
	var pb := Tema.pulsante_primario("PASSARE", func():
		giornata.passa(x)
		_dopo_azione(), 17)
	pb.disabled = x.get("passato", false)
	_azioni.add_child(pb)

func _azione(t: String, cb: Callable, attiva: bool, suggerimento := "") -> void:
	var b := Tema.pulsante(t, cb, 16)
	b.disabled = not attiva
	b.tooltip_text = suggerimento
	b.custom_minimum_size = Vector2(0, 50)
	_azioni.add_child(b)

func _ha_menhir(n: int) -> bool:
	var sig: Array = Carte.luogo(n).get("sigilli", [])
	if sig.has("menhir"):
		return true
	var l := Dati.luogo(partita.camp, Dati.id_numero(partita.camp, n))
	return l.has("menhir")

## Dopo ogni azione: se il personaggio non può più agire si passa al prossimo; se nessuno può, fine giornata.
func _dopo_azione() -> void:
	_viaggio = false
	tavolo.evidenzia([])
	_controlla_richieste()
	var x := partita.attivo()
	if x.get("passato", false) or int(x.get("energia", 0)) <= 0:
		if not giornata.prossimo():
			_fine_giornata()
			return
	_aggiorna()
	tavolo.centra(partita.luogo_attivo())

## --- Azioni -----------------------------------------------------------------------

func _inizia_viaggio() -> void:
	_viaggio = true
	tavolo.evidenzia(giornata.puo_viaggiare(partita.attivo()))
	_aggiorna_azioni()

func _luogo_cliccato(n: int) -> void:
	if _viaggio:
		if giornata.puo_viaggiare(partita.attivo()).has(n):
			var gruppo := _gruppo_azione()
			var nuovi := giornata.viaggia(gruppo, n)
			_viaggio = false
			tavolo.evidenzia([])
			_aggiorna()
			tavolo.centra(n)
			_arrivo(n, nuovi)
		return
	_mostra_luogo(n)

func _luogo_sopra(n: int) -> void:
	if n == 0 or _viaggio:
		return
	var nome := Dati.testo_piano(str(Dati.luogo(partita.camp, Dati.id_numero(partita.camp, n)).get("nome", "")))
	_info.text = "Luogo %d · %s" % [n, nome] if not _viaggio else _info.text

## Compagnia che compie l'azione: per ora chi è nello stesso Luogo e non ha passato.
func _gruppo_azione() -> Array:
	return partita.compagnia().filter(func(y): return not y.get("passato", false) and int(y.get("energia", 0)) > 0)

## Arrivo in un Luogo: regola immediata (fulmine) e Insediamento nemico.
func _arrivo(n: int, _nuovi: Array) -> void:
	var c := Carte.luogo(n)
	var imm = c.get("immediata")
	if imm is Dictionary and str(imm.get("it", "")) != "":
		_messaggio("Regola immediata · Luogo %d" % n, str(imm["it"]), func():
			var fatti := Effetti.applica(str(imm["it"]), partita)
			_riassunto(fatti)
			_dopo_azione())
	else:
		_dopo_azione()

func _esplora() -> void:
	var g := _gruppo_azione()
	if not giornata.esplora(g):
		return
	partita.diario.apri_numero(partita.luogo_attivo())
	_apri_diario()
	_aggiorna()

func _apri_diario(libero := false) -> void:
	if is_instance_valid(_diario):
		_diario.queue_free()
	if libero and not partita.diario.aperto():
		_scegli_numero_diario()
		return
	_diario = PannelloDiario.new(partita.diario, partita)
	_diario.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_diario.offset_left = -820
	_diario.offset_top = 66
	_diario.offset_bottom = -106
	_diario.offset_right = -10
	_ui.add_child(_diario)
	_diario.avanzato.connect(func():
		Campagna.modificata()
		_aggiorna())
	_diario.chiudi.connect(func():
		_diario.queue_free()
		_dopo_azione())
	_diario.fine_esplorazione.connect(func(_r):
		_diario.queue_free()
		_dopo_azione())

func _scegli_numero_diario() -> void:
	var d := AcceptDialog.new()
	d.title = "Diario di Esplorazione"
	d.ok_button_text = "Apri"
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "Numero del Luogo da leggere (999 = Libro dei Segreti, oppure \"S\" e il numero del verso):"
	v.add_child(l)
	var e := LineEdit.new()
	e.text = str(partita.luogo_attivo())
	v.add_child(e)
	d.add_child(v)
	d.confirmed.connect(func():
		var t := e.text.strip_edges().to_upper()
		var ok := partita.diario.apri_segreto(int(t.substr(1))) if t.begins_with("S") else partita.diario.apri_numero(int(t))
		if ok:
			_apri_diario())
	_ui.add_child(d)
	d.popup_centered(Vector2i(640, 0))

func _azione_luogo() -> void:
	var n := partita.luogo_attivo()
	var fatti := giornata.esegui_azione_luogo(n)
	_riassunto(fatti)
	_dopo_azione()

func _azione_personaggio() -> void:
	var x := partita.attivo()
	var dd := Personaggi.dati(str(x["id"]))
	var costo := int(dd["azione"]["costo"])
	match str(x["id"]):
		"arev":
			partita.modifica(x, "energia", -costo)
			partita.modifica(x, "cibo", 1)
			partita.racconta("Arev raccoglie: +1 Cibo")
		"ailei":
			var bersagli := partita.compagnia()
			var ferito: Dictionary = x
			for y in bersagli:
				if Personaggi.limite(y, "salute") - int(y["salute"]) > Personaggi.limite(ferito, "salute") - int(ferito["salute"]):
					ferito = y
			partita.modifica(x, "energia", -costo)
			partita.modifica(ferito, "salute", 1)
			partita.racconta("Ailei usa le Erbe Curative su %s: +1 Salute" % ferito["nome"])
		"maggot":
			if int(x.get("magia", 0)) >= 4:
				_messaggio("Meditazione", "Puoi meditare solo se hai meno di 4 {r:Magia}.")
				return
			partita.modifica(x, "energia", -costo)
			partita.modifica(x, "magia", 1)
			partita.racconta("Verme medita: +1 Magia")
		"beor":
			_fabbrica(x, costo)
			return
	_dopo_azione()

## Beor: pesca 3 Oggetti Fabbricabili e ne tiene 1.
func _fabbrica(x: Dictionary, costo: int) -> void:
	var m: Array = partita.d["mazzi"].get("oggetti", [])
	var scelta := []
	for img in m:
		if Carte.dati(img).get("fabbricabile", false):
			scelta.append(img)
		if scelta.size() == 3:
			break
	if scelta.is_empty():
		_messaggio("Fabbricare", "Non ci sono Oggetti Fabbricabili nel mazzo (o le carte Oggetto non sono ancora trascritte).")
		return
	partita.modifica(x, "energia", -costo)
	_scegli_carta("Fabbricare: scegli un Oggetto", scelta, func(img):
		m.erase(img)
		x["oggetti"].append(img)
		m.shuffle()
		partita.racconta("Beor fabbrica: %s" % Carte.nome(img))
		_dopo_azione())

func _menhir() -> void:
	var n := partita.luogo_attivo()
	var l := Dati.luogo(partita.camp, Dati.id_numero(partita.camp, n))
	var t := str(l.get("menhir", "Il testo del Menhir di questo Luogo è sulla carta."))
	var q := partita.quadrante_iniziale(8)
	var mq := RegEx.create_from_string("[Qq]uadrante su (?:\\[b\\])?(\\d+)").search(t)
	if mq:
		q = int(mq.get_string(1)) - (partita.personaggi().size() - 1) if t.find("-1 per") >= 0 or t.find("–1 per") >= 0 or t.find("(-1") >= 0 else int(mq.get_string(1))
	_messaggio("Menhir · Luogo %d" % n, t + "\n\n[color=#d4ae63]Se paghi i costi indicati, il Menhir si attiva con il Quadrante a %d.[/color]" % q, Callable(),
		{"ATTIVA IL MENHIR (paga i costi)": func():
			_paga_menhir(t)
			partita.attiva_menhir(n, q)
			_dopo_azione()})

## Paga i costi elencati nel testo del Menhir ("Pagare 2 {i:energy}, 2 {i:health}, 2 {r:Ricchezza}… per giocatore").
func _paga_menhir(t: String) -> void:
	var l := Dati.testo_piano(t).to_lower()
	var i := l.find("pagare")
	if i < 0:
		return
	var seg := l.substr(i, l.find(":", i) - i if l.find(":", i) > 0 else 200)
	var per := seg.find("per giocatore") >= 0 or seg.find("per membro") >= 0 or seg.find("ogni personaggio") >= 0
	for m in RegEx.create_from_string("(\\d+)\\s*(@\\w+@|ricchezza|magia|cibo|esp|rep)").search_all(seg):
		var ris := Condizioni._risorsa(m.get_string(2))
		if ris == "":
			continue
		if per:
			for y in partita.personaggi():
				partita.modifica(y, ris, -int(m.get_string(1)))
		else:
			partita.paga(ris, int(m.get_string(1)))
	for y in partita.personaggi():
		if str(y["id"]) == "arev":
			partita.modifica(y, "magia", -1)
			partita.racconta("Arev è Maledetto: −1 Magia per attivare il Menhir")

func _incontro_manuale() -> void:
	_messaggio("Incontro", "Di che colore è l'Incontro da pescare?", Callable(), {
		"VERDE": func(): _avvia_incontro("verde"),
		"GRIGIO": func(): _avvia_incontro("grigio"),
		"VIOLA": func(): _avvia_incontro("viola"),
		"BLU": func(): _avvia_incontro("blu")})

func _avvia_incontro(colore: String, nome := "") -> void:
	var m: Array = partita.d["mazzi"].get_or_add("incontri_" + colore, [])
	if m.is_empty():
		_messaggio("Incontro", "Il mazzo Incontro %s è vuoto." % colore)
		return
	var img: String = m.pop_front()
	if nome != "":
		for i in m.size():
			if Carte.nome(m[i]).to_lower() == nome.to_lower():
				m.push_front(img)
				img = m.pop_at(i + 1)
				break
	var fi := FinestraIncontro.new(partita, img, colore)
	fi.finito.connect(func(_esito):
		m.append(img)  # in fondo al mazzo
		_dopo_azione())
	_ui.add_child(fi)

## Effetti in coda (Incontri chiesti dal Diario o dalle carte).
func _controlla_richieste() -> void:
	while not Effetti.richieste.is_empty():
		var r: Dictionary = Effetti.richieste.pop_front()
		if r.get("tipo") == "incontro":
			_avvia_incontro(str(r["colore"]), str(r.get("nome", "")))
			return

## --- Inizio e fine della Giornata --------------------------------------------------

func _inizio_giornata() -> void:
	var r := giornata.inizio()
	_aggiorna()
	var t := "\n".join(r["messaggi"])
	if str(r["evento"]) != "":
		_mostra_evento(t)
	elif t != "":
		_messaggio("Inizio della Giornata %d" % int(partita.d["giorno"]), t)

func _mostra_evento(prefisso := "") -> void:
	var ev := str(partita.d.get("evento", ""))
	if ev == "":
		_messaggio("Evento", (prefisso + "\n\n" if prefisso != "" else "") + "Nessun Evento attivo (il mazzo Eventi del capitolo non è ancora pronto).")
		return
	var c := Carte.dati(ev)
	var testo := str(c.get("testo", {}).get("it", ""))
	_messaggio("Evento · " + Carte.nome(ev), (prefisso + "\n\n" if prefisso != "" else "") + testo, Callable(), {}, ev)

func _fine_giornata() -> void:
	partita.d["fase"] = "fine"
	Campagna.modificata()
	var righe := []
	var sogni := []
	for x in partita.personaggi():
		righe.append(giornata.riposa(x, int(x.get("cibo", 0)) > 0))
		var s := giornata.sogno(x)
		if not s.is_empty() and not sogni.any(func(z): return z["testo"] == s["testo"]):
			sogni.append(s)
	var t := "[b]Riposo:[/b]\n" + "\n".join(righe)
	for s in sogni:
		t += "\n\n[b]%s:[/b]\n%s" % [s["tipo"], s["testo"]]
	_aggiorna()
	_messaggio("Fine della Giornata %d" % int(partita.d["giorno"]), t + "\n\n[color=#b9a98a]Puoi spendere Esp dalla scheda dei Personaggi (clic sul nome) prima di iniziare la nuova giornata.[/color]", Callable(), {
		"NUOVA GIORNATA": func():
			for s in sogni:
				Effetti.applica(str(s["testo"]), partita)
			giornata.nuova_giornata()
			_inizio_giornata()})

## --- Finestre ------------------------------------------------------------------------

func _riassunto(fatti: Array) -> void:
	if fatti.is_empty():
		return
	var r := []
	for f in fatti:
		r.append(("✔ " if f.get("fatto", false) else "☐ ") + str(f["testo"]))
	_messaggio("Risultato", "\n".join(r))

func _messaggio(titolo: String, testo: String, alla_chiusura: Callable = Callable(), pulsanti: Dictionary = {}, img := "") -> void:
	if is_instance_valid(_modale):
		_modale.queue_free()
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.55)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(vel)
	_modale = vel
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(1100 if img != "" else 760, 0)
	vel.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	if img != "":
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(440, 320)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		Immagini.carica(Carte.immagine(img), func(tx): if is_instance_valid(t): t.texture = tx)
		h.add_child(t)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Tema.etichetta(titolo.to_upper(), 22, Tema.ORO, true))
	v.add_child(Tema.fregio(400))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 80)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var r := Tema.testo_ricco(20)
	r.text = Dati.testo_bb(testo, 22)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(r)
	v.add_child(sc)
	r.resized.connect(func(): sc.custom_minimum_size.y = minf(r.size.y, 620))
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_END
	b.add_theme_constant_override("separation", 10)
	v.add_child(b)
	var chiudi := func():
		vel.queue_free()
	for k in pulsanti:
		var cb: Callable = pulsanti[k]
		b.add_child(Tema.pulsante_primario(k, func():
			chiudi.call()
			cb.call(), 17))
	b.add_child(Tema.pulsante("CHIUDI" if not pulsanti.is_empty() else "CONTINUA", func():
		chiudi.call()
		if alla_chiusura.is_valid():
			alla_chiusura.call()))
	p.resized.connect(func(): p.position = (vel.size - p.size) / 2)
	vel.resized.connect(func(): p.position = (vel.size - p.size) / 2)

func _scegli_carta(titolo: String, imgs: Array, cb: Callable) -> void:
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.6)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(vel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.add_theme_constant_override("separation", 16)
	vel.add_child(v)
	v.add_child(Tema.etichetta(titolo.to_upper(), 24, Tema.ORO, true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	for img in imgs:
		var t := TextureButton.new()
		t.custom_minimum_size = Vector2(300, 454)
		t.ignore_texture_size = true
		t.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		Immagini.carica(Carte.immagine(img), func(tx): if is_instance_valid(t): t.texture_normal = tx)
		t.pressed.connect(func():
			vel.queue_free()
			cb.call(img))
		h.add_child(t)
	v.resized.connect(func(): v.position = (vel.size - v.size) / 2)

func _mostra_luogo(n: int) -> void:
	var c := Carte.luogo(n)
	var l := Dati.luogo(partita.camp, Dati.id_numero(partita.camp, n))
	var t := ""
	if not c.is_empty():
		var az = c.get("azione")
		if az is Array and not az.is_empty():
			az = az[0]
		if az is Dictionary:
			t += "[b]%s[/b] (%d {i:energy}): %s\n\n" % [str(az.get("nome", {}).get("it", "")), int(az.get("costo", 0)), str(az.get("it", ""))]
		if c.get("immediata") is Dictionary:
			t += "{i:thunder} " + str(c["immediata"].get("it", "")) + "\n\n"
		if c.get("ambientazione") is Dictionary:
			t += "[i]" + str(c["ambientazione"].get("it", "")) + "[/i]"
	var img := Carte.immagine_luogo(n)
	_messaggio("Luogo %d · %s" % [n, Dati.testo_piano(str(l.get("nome", "")))], t if t != "" else "Carta non ancora trascritta.", Callable(), {}, img.trim_prefix("") if img != "" else "")

func _mostra_status() -> void:
	var st: Dictionary = partita.d.get("status", {})
	var righe := []
	var chiavi := st.keys()
	chiavi.sort()
	for k in chiavi:
		righe.append("[b]%s[/b]: parte %s" % [k, ", ".join(st[k].map(func(x): return str(x)))])
	var seg: Array = partita.d.get("segreti", [])
	var t := ("\n".join(righe) if not righe.is_empty() else "Nessuno status.") + "\n\n[b]Segreti:[/b] " + (", ".join(seg.map(func(x): return str(x))) if not seg.is_empty() else "nessuno")
	t += "\n[b]Gettoni Cerca:[/b] %d" % int(partita.d["gettoni"].get("cerca", 0))
	_messaggio("Status e Segreti", t)

func _mostra_cronaca() -> void:
	var ev: Array = Campagna.dati.get("registro", {}).get("eventi", [])
	var righe := []
	for i in range(maxi(0, ev.size() - 80), ev.size()):
		righe.append("[color=#8a7a66]%s[/color]  %s" % [str(ev[i][0]).substr(11, 5), ev[i][1]])
	righe.reverse()
	_messaggio("Cronaca della campagna", "\n".join(righe))

func _scheda_personaggio(id: String) -> void:
	var x := {}
	for y in partita.personaggi():
		if str(y["id"]) == id:
			x = y
	var v := VBoxContainer.new()
	var t := "[b]Esp disponibile: %d[/b]\n\nMiglioramenti (il costo dipende dal totale della coppia di Attributi):\n" % int(x.get("esp", 0))
	var bot := {}
	for a in Partita.ATTRIBUTI:
		var c := giornata.costo_attributo(x, a)
		t += "• %s %d → %d: %d Esp\n" % [Partita.NOMI_ATTRIBUTI[a], partita.attributo(x, a), partita.attributo(x, a) + 1, c]
		if int(x.get("esp", 0)) >= c:
			bot["+ " + Partita.NOMI_ATTRIBUTI[a].to_upper()] = func():
				giornata.migliora_attributo(x, a)
				_aggiorna()
				_scheda_personaggio(id)
	if int(x.get("esp", 0)) >= 2:
		bot["CARTA DI COMBATTIMENTO (2 Esp)"] = func(): _carta_avanzata(x, "combattimento")
		bot["CARTA DI DIPLOMAZIA (2 Esp)"] = func(): _carta_avanzata(x, "diplomazia")
	t += "\nMazzo di Combattimento: %d carte · Diplomazia: %d carte" % [x["mazzi"]["combattimento"]["mazzo"].size(), x["mazzi"]["diplomazia"]["mazzo"].size()]
	_messaggio(str(x["nome"]), t, Callable(), bot, Personaggi.dati(id)["tessera"])

func _carta_avanzata(x: Dictionary, tipo: String) -> void:
	var tre := giornata.pesca_avanzate(x, tipo)
	if tre.is_empty():
		return
	_scegli_carta("Scegli una carta da aggiungere al mazzo", tre, func(img):
		giornata.scegli_avanzata(x, tipo, img)
		_aggiorna())
