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
var domande: Domande
var _stati_noti := {}     # personaggio -> {"morendo": bool, "impazzendo": bool}

func _ready() -> void:
	partita = Campagna.partita
	giornata = Giornata.new(partita)
	domande = Domande.new()
	add_child(domande)
	domande.incontro = _incontro_richiesto
	# una domanda nasconde la finestra di messaggio sotto (la si rivede dopo la risposta)
	domande.aperta.connect(func():
		if is_instance_valid(_modale):
			_modale.visible = false)
	domande.chiusa.connect(func():
		if is_instance_valid(_modale):
			_modale.visible = true)
	domande.diario = func(l, v):
		if partita.diario.apri_numero(l, v):
			_apri_diario()
	domande.evento = func(img): _messaggio("Evento · " + Carte.nome(img), str(Carte.dati(img).get("testo", {}).get("it", "")), Callable(), {}, img)
	for x in partita.personaggi():
		_stati_noti[str(x["id"])] = {"morendo": Personaggi.morente(x), "impazzendo": Personaggi.in_follia(x)}
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
	sc.offset_right = 440
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
	var fase := str(partita.d.get("fase", ""))
	if fase != "giorno":
		# la barra non resta mai vuota: si può sempre riprendere il passo in corso
		if fase == "fine":
			_info.text = "Fine della Giornata %d." % int(partita.d.get("giorno", 1))
			_azioni.add_child(Tema.pulsante_primario("FINE DELLA GIORNATA", func(): _fine_giornata(), 17))
		else:
			_info.text = "Inizio della Giornata %d." % int(partita.d.get("giorno", 1))
			_azioni.add_child(Tema.pulsante_primario("INIZIA LA GIORNATA", func(): _inizio_giornata(), 17))
		return
	if giornata.attivi().is_empty():
		_info.text = "Nessun Personaggio può più agire oggi."
		_azioni.add_child(Tema.pulsante_primario("FINE DELLA GIORNATA", func(): _fine_giornata(), 17))
		return
	_info.text = "Tocca a %s — Luogo %d · Energia %d. Compagnia: %s" % [x["nome"], n, int(x["energia"]),
		", ".join(partita.compagnia().map(func(y): return y["nome"]))]
	var puo: bool = not x.get("passato", false) and partita.energia_spendibile(x) > 0
	_azione("VIAGGIARE", _inizia_viaggio, puo and not giornata.puo_viaggiare(x).is_empty(), "1 Energia: muovi in un Luogo collegato")
	_azione("ESPLORARE", _esplora, puo, "1 Energia per membro: leggi il Diario di questo Luogo")
	var aza = _azioni_luogo_auto(n)
	if not aza.is_empty():
		for i in aza.size():
			var a: Dictionary = aza[i]
			var costo := _costo_energia(a.get("costo", []))
			var usata: bool = a.get("una_volta_al_giorno", false) and partita.d["gettoni"]["tempo"].has(str(n) + ("" if i == 0 else ":%d" % i))
			var nome_a := _nome_azione_luogo(n, i)
			var ok_c: bool = not (a.get("condizione") is Dictionary) or a["condizione"].is_empty() or Interprete.new(partita).valuta(a["condizione"]) != false
			var ii := i
			_azione(nome_a.to_upper(), func(): _azione_luogo_auto(n, ii), puo and not usata and ok_c and partita.energia_spendibile(x) >= costo,
				"%d Energia%s" % [costo, " · una volta al giorno" if a.get("una_volta_al_giorno", false) else ""])
	var az := giornata.azione_luogo(n) if aza.is_empty() else {}
	if not az.is_empty():
		var nome := str(az.get("nome", {}).get("it", "Azione del Luogo"))
		_azione(nome.to_upper(), _azione_luogo, puo and not giornata.azione_luogo_usata(n) and partita.energia_spendibile(x) >= int(az.get("costo", 0)),
			Dati.testo_leggibile("%d Energia: %s" % [int(az.get("costo", 0)), str(az.get("it", ""))]))
	var dd := Personaggi.dati(str(x["id"]))
	_azione(str(dd["azione"]["nome"]).to_upper(), _azione_personaggio, puo and partita.energia_spendibile(x) >= int(dd["azione"]["costo"]) and partita.modificatori("no_azione_personaggio", x).is_empty(),
		Dati.testo_leggibile("%d Energia: %s" % [int(dd["azione"]["costo"]), dd["azione"]["testo"]]))
	if _ha_menhir(n):
		_azione("MENHIR", _menhir, true, "Ispeziona il Menhir del Luogo e attivalo")
	var a_terra: Array = partita.d.get("oggetti_terra", {}).get(str(n), [])
	if not a_terra.is_empty():
		_azione("RACCOGLI OGGETTI (%d)" % a_terra.size(), _raccogli_oggetti, true, "Oggetti lasciati qui da un Personaggio caduto")
	var usabili := partita.inneschi("azione", x) + partita.inneschi("in_qualsiasi_momento", x)
	if not usabili.is_empty():
		_azione("CARTE (%d)" % usabili.size(), _usa_carte, true, "Oggetti, Segreti e Abilità con un'azione o usabili in qualsiasi momento")
	if not partita.d.get("cerche", []).is_empty():
		_azione("CERCHE", _mostra_cerche, true, "Cerche attive e loro condizioni di successo")
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

func _raccogli_oggetti() -> void:
	var x := partita.attivo()
	var terra: Array = partita.d.get("oggetti_terra", {}).get(str(int(x["luogo"])), [])
	while not terra.is_empty():
		var opz: Array = terra.map(func(o): return Carte.nome(o))
		opz.append("Basta così")
		var k := await domande.scegli("Oggetti nel Luogo %d: quale prende %s?" % [int(x["luogo"]), x["nome"]], opz)
		if k >= terra.size():
			break
		var img: String = terra[k]
		terra.remove_at(k)
		x["oggetti"].append(img)
		partita.racconta("%s raccoglie %s" % [x["nome"], Carte.nome(img)])
	if terra.is_empty():
		partita.d.get("oggetti_terra", {}).erase(str(int(x["luogo"])))
	await _controlla_stati()
	partita.cambiato()
	_aggiorna()

## Oggetti di un Personaggio: quale è attivo per parola chiave, darli a chi è nello stesso Luogo, scartarli.
func _gestisci_oggetti(x: Dictionary) -> void:
	while true:
		var og: Array = x.get("oggetti", [])
		if og.is_empty():
			return
		var opz: Array = og.map(func(o):
			var pw := Partita.parola_oggetto(o)
			var st := ""
			if Partita.PAROLE_OGGETTO.has(pw):
				st = " — %s %s" % [pw.capitalize(), "ATTIVO" if partita.attivo_oggetto(x, o) else "coperto (non attivo)"]
			return Carte.nome(o) + st)
		opz.append("Chiudi")
		var k := await domande.scegli("Oggetti di %s (al massimo 1 attivo per Arma, Armatura, Scudo, Compagno, Reliquia)" % x["nome"], opz)
		if k >= og.size():
			return
		var img: String = og[k]
		var azioni := []
		var cb := []
		if Partita.PAROLE_OGGETTO.has(Partita.parola_oggetto(img)) and not partita.attivo_oggetto(x, img):
			azioni.append("Rendilo attivo")
			cb.append(func(): partita.attiva_oggetto(x, img))
		if partita.cedibile(img):
			for y in partita.personaggi():
				if y != x and int(y["luogo"]) == int(x["luogo"]):
					azioni.append("Dallo a " + str(y["nome"]))
					var yy: Dictionary = y
					cb.append(func(): partita.dai_oggetto(x, yy, img))
		else:
			azioni.append("(non cedibile)")
			cb.append(func(): pass)
		azioni.append("Scartalo")
		cb.append(func(): partita.scarta_oggetto(x, img))
		azioni.append("Indietro")
		cb.append(func(): pass)
		var j := await domande.scegli(Carte.nome(img), azioni)
		cb[j].call()
		_aggiorna()

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
	await _controlla_stati()
	await _controlla_cerche()
	if partita.d.get("salta_fine_giornata", false):
		partita.d.erase("salta_fine_giornata")
		giornata.nuova_giornata()
		_inizio_giornata()
		return
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
			for y in gruppo:
				await _scatena("viaggio", y)
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
	# 1. Guardiani nel Luogo: Incontro immediato, prima delle regole col fulmine
	for g in partita.guardiani_in(n):
		await _domanda_avviso("Guardiano", "Nel Luogo %d c'è il Guardiano %s: Incontro immediato!" % [n, Carte.nome(str(g["img"]))])
		await _incontro_carta(str(g["img"]), str(g.get("colore", "")))
	# 2. regola immediata codificata
	var ai = Carte.auto(Carte.img_luogo(n)).get("immediata")
	if ai is Dictionary and ai.get("effetti") is Array and not ai["effetti"].is_empty():
		var chiave := "imm:%d" % n
		if not (ai.get("una_volta_al_giorno", false) and partita.d["gettoni"]["tempo"].has(chiave)):
			if ai.get("una_volta_al_giorno", false):
				partita.d["gettoni"]["tempo"][chiave] = 1
			var testo_imm := str(Carte.luogo(n).get("immediata", {}).get("it", "")) if Carte.luogo(n).get("immediata") is Dictionary else ""
			await _domanda_avviso("Regola immediata · Luogo %d" % n, testo_imm)
			var it := Interprete.new(partita, null, domande, {"luogo": n, "carta": Carte.img_luogo(n)})
			await it.esegui(ai["effetti"])
			_riassunto(it.rapporto)
		await _scatena("arrivo")
		_dopo_azione()
		return
	await _scatena("arrivo")
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
	for y in g:
		await _scatena("esplorazione", y)
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
	_diario.domande = domande
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
			partita.spendi_energia(x, costo)
			partita.modifica(x, "cibo", 1)
			partita.racconta("Arev raccoglie: +1 Cibo")
		"ailei":
			var bersagli := partita.compagnia()
			var ferito: Dictionary = x
			for y in bersagli:
				if Personaggi.limite(y, "salute") - int(y["salute"]) > Personaggi.limite(ferito, "salute") - int(ferito["salute"]):
					ferito = y
			partita.spendi_energia(x, costo)
			partita.modifica(ferito, "salute", 1)
			partita.racconta("Ailei usa le Erbe Curative su %s: +1 Salute" % ferito["nome"])
		"maggot":
			if int(x.get("magia", 0)) >= 4:
				_messaggio("Meditazione", "Puoi meditare solo se hai meno di 4 {r:Magia}.")
				return
			partita.spendi_energia(x, costo)
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
	partita.spendi_energia(x, costo)
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
	var am = Dati.auto_diario("s:", str(l.get("menhir", ""))).get("menhir")
	if not (am is Dictionary):
		am = Carte.auto(Carte.img_luogo(n)).get("menhir")
	if am is Dictionary:
		var it0 := Interprete.new(partita, null, domande, {"luogo": n})
		var q0 := int(am.get("quadrante", 8))
		if am.get("meno_per_giocatore", false):
			q0 -= partita.personaggi().size() - 1
		var ok0: bool = not (am.get("condizione") is Dictionary) or am["condizione"].is_empty() or it0.valuta(am["condizione"]) != false
		_messaggio("Menhir · Luogo %d" % n, t + ("\n\n[color=#d4ae63]Pagando i costi il Menhir si attiva con il Quadrante a %d.[/color]" % q0 if ok0 else "\n\n[color=#e05a4a]Non soddisfate la condizione per attivarlo.[/color]"), Callable(),
			{"ATTIVA IL MENHIR": func(): _attiva_menhir_auto(n, am)} if ok0 else {})
		return
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

func _attiva_menhir_auto(n: int, am: Dictionary) -> void:
	var it := Interprete.new(partita, null, domande, {"luogo": n})
	if am.get("costo") is Array and not await it.esegui(await _costo_menhir(am["costo"])):
		_riassunto(it.rapporto)
		return
	for y in partita.personaggi():
		if str(y["id"]) == "arev" and partita.compagnia().has(y):
			partita.modifica(y, "magia", -1)
			partita.racconta("Arev è Maledetto: −1 Magia per attivare il Menhir")
	var q := int(am.get("quadrante", 8))
	if am.get("meno_per_giocatore", false):
		q -= partita.personaggi().size() - 1
	for m in partita.modificatori("costo_menhir", partita.attivo()):
		await it.esegui([{"tipo": "paga", "ris": str(m.get("ris", "magia")), "n": int(m.get("n", 1)), "chi": "diviso"}])
	partita.attiva_menhir(n, maxi(1, q))
	await it.esegui(am.get("effetti", []))
	await _scatena("attiva_menhir")
	_riassunto(it.rapporto)
	_dopo_azione()

## Costo di attivazione di un Menhir con le carte che lo cambiano (Infondere odio, Duro lavoro: pagare
## con Magia invece che con Energia o viceversa; Eventi che tolgono 1 Magia dal costo).
func _costo_menhir(costo: Array) -> Array:
	var x := partita.attivo()
	var out := []
	var sconto := 0
	for m in partita.modificatori("niente_menhir_costo_magia", x):
		sconto += int(m.get("n", 1))
	for s in costo:
		if not (s is Dictionary) or str(s.get("tipo", "")) != "paga":
			out.append(s)
			continue
		var s2: Dictionary = s.duplicate()
		var ris := str(s2.get("ris", ""))
		if ris == "magia" and sconto > 0:
			var tolti := mini(sconto, int(s2.get("n", 1)))
			sconto -= tolti
			s2["n"] = int(s2.get("n", 1)) - tolti
			partita.racconta("Costo del Menhir: −%d Magia" % tolti)
			if int(s2["n"]) <= 0:
				continue
		for m in partita.modificatori("menhir_paga_con", x):
			if str(m.get("da", "")) == ris:
				var con := str(m.get("con", ""))
				var k := await domande.scegli("Come pagate %d %s per il Menhir?" % [int(s2.get("n", 1)), ris.capitalize()],
					["Con %s" % ris.capitalize(), "Con %s (%s)" % [con.capitalize(), Carte.nome(str(m.get("_img", "")))] if m.has("_img") else "Con %s" % con.capitalize()])
				if k == 1:
					s2["ris"] = con
				break
		out.append(s2)
	return out

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
	var fi := FinestraIncontro.new(partita, img, colore, domande)
	fi.finito.connect(func(_esito):
		if not Partita.guardiani(partita).any(func(g): return str(g["img"]) == img):
			m.append(img)  # in fondo al mazzo
		_dopo_azione())
	_ui.add_child(fi)

## Incontro chiesto da un effetto (Diario, Eventi, carte): restituisce l'esito.
func _incontro_richiesto(colore: String, nome: String, _livello: int) -> String:
	if nome == "":
		# Eventi che cambiano il colore dell'Incontro casuale ("pesca invece un Incontro viola")
		for md in partita.modificatori("pesca_incontro"):
			var cl = md.get("colore", "")
			if md.has("sostituisci") and ((cl is Array and cl.has(colore)) or str(cl) == colore):
				partita.racconta("Incontro %s pescato invece del %s" % [str(md["sostituisci"]), colore])
				colore = str(md["sostituisci"])
				break
	var m: Array = partita.d["mazzi"].get_or_add("incontri_" + colore, [])
	var img := ""
	if nome != "":
		for x in m:
			if Carte.nome(x).to_lower() == nome.to_lower():
				img = x
		if img == "":
			# Incontro specifico non nel mazzo: si cerca fra tutte le carte di quel colore
			var tutte: Dictionary = Dati.carte.get("gruppi", {}).get("incontri", {}).get(colore, {})
			for liv in tutte:
				for x in tutte[liv]:
					if Carte.nome(x).to_lower() == nome.to_lower():
						img = x
	if img == "":
		if m.is_empty():
			await _domanda_avviso("Incontro", "Il mazzo Incontro %s è vuoto." % colore)
			return "vittoria"
		img = m[0]
		for mod in partita.modificatori("incontro_in_fondo"):
			if Carte.nome(img).to_lower() == str(mod.get("nome", "")).to_lower():
				m.push_back(m.pop_front())
				img = m[0]
		if m.size() >= 2:
			# pescane 2: il valore più alto (Evento) o a scelta (Chiaroveggenza, Seguire le tracce…)
			var alto := partita.modificatori("pesca_incontro").any(func(md): return str(md.get("colore", "")) == colore and str(md.get("scegli", "")) == "maggiore")
			var scelta := partita.modificatori("scegli_incontro", partita.attivo()).any(func(md): return str(md.get("colore", "")) == colore)
			if alto or scelta:
				var due := [m[0], m[1]]
				var k := 0
				if alto:
					k = 0 if int(Carte.dati(due[0]).get("valore", 0)) >= int(Carte.dati(due[1]).get("valore", 0)) else 1
				else:
					k = await domande.scegli("Pescate 2 carte Incontro %s: quale affrontate? L'altra va in fondo al mazzo." % colore,
						due.map(func(z): return "%s (valore %s)" % [Carte.nome(z), str(Carte.dati(z).get("valore", "?"))]))
				img = due[k]
				var altra: String = due[1 - k]
				m.erase(altra)
				m.push_back(altra)
	m.erase(img)
	var esito := await _incontro_carta(img, colore)
	if not Partita.guardiani(partita).any(func(g): return str(g["img"]) == img):
		m.append(img)
	return esito

## Apre la finestra dell'Incontro per una carta e attende l'esito.
func _incontro_carta(img: String, colore: String) -> String:
	if colore == "":
		colore = str(Carte.dati(img).get("colore", "grigio"))
	await _scatena("pesca_incontro")
	partita.d["ultimo_incontro"] = img
	var fi := FinestraIncontro.new(partita, img, colore, domande)
	_ui.add_child(fi)
	var esito: String = await fi.finito
	partita.d["esito_incontro"] = esito
	_aggiorna()
	return esito

## Inneschi delle carte fuori dagli Incontri.
func _scatena(quando: String, x: Dictionary = {}) -> void:
	if partita.inneschi(quando, x).is_empty():
		return
	var it := Interprete.new(partita, null, domande, {})
	await it.scatena(quando, x)
	if not it.rapporto.is_empty():
		_riassunto(it.rapporto)
	_aggiorna()

## Avviso che attende la chiusura.
func _domanda_avviso(titolo: String, testo: String) -> void:
	await domande.avvisa(titolo, testo)

## Usa una carta (Oggetto, Segreto, Abilità) con un'azione o in qualsiasi momento.
func _usa_carte() -> void:
	var x := partita.attivo()
	var usabili := partita.inneschi("azione", x) + partita.inneschi("in_qualsiasi_momento", x)
	if usabili.is_empty():
		return
	var nomi := usabili.map(func(u): return "%s — %s" % [Carte.nome(str(u["img"])), _descrivi_innesco(u)])
	nomi.append("Annulla")
	var k := await domande.scegli("Quale carta usi?", nomi)
	if k >= usabili.size():
		return
	var it := Interprete.new(partita, null, domande, {})
	await it.usa(usabili[k])
	_riassunto(it.rapporto)
	_dopo_azione()

func _descrivi_innesco(u: Dictionary) -> String:
	var c := Carte.dati(str(u["img"]))
	var e = c.get("effetto", c.get("testo", {}))
	if u.has("faccia") or c.get("facce") is Array:
		for f in c.get("facce", []):
			if str(f.get("nome", {}).get("it", "")) != "":
				e = f.get("effetto", e)
	return Dati.testo_leggibile(str(e.get("it", ""))) if e is Dictionary else ""

## Azioni codificate di una carta Luogo (lista).
func _azioni_luogo_auto(n: int) -> Array:
	var a = Carte.auto(Carte.img_luogo(n)).get("azione")
	if a is Dictionary:
		return [a]
	if a is Array:
		return a.filter(func(y): return y is Dictionary)
	return []

func _nome_azione_luogo(n: int, i: int) -> String:
	var az = Carte.luogo(n).get("azione")
	if az is Array and i < az.size():
		az = az[i]
	if az is Dictionary:
		return str(az.get("nome", {}).get("it", "Azione del Luogo"))
	return "Azione del Luogo"

func _costo_energia(costo) -> int:
	var t := 0
	if costo is Array:
		for c in costo:
			if c is Dictionary and str(c.get("tipo", "")) == "paga" and str(c.get("ris", "")) == "energia":
				t += int(c.get("n", 0))
	elif costo is int or costo is float:
		t = int(costo)
	return t

func _azione_luogo_auto(n: int, i: int) -> void:
	var a: Dictionary = _azioni_luogo_auto(n)[i]
	var it := Interprete.new(partita, null, domande, {"luogo": n, "carta": Carte.img_luogo(n)})
	var costo = a.get("costo", [])
	if costo is int or costo is float:
		costo = [{"tipo": "paga", "ris": "energia", "n": int(costo), "chi": "diviso"}]
	if costo is Array and not costo.is_empty() and not await it.esegui(costo):
		_riassunto(it.rapporto)
		return
	if a.get("una_volta_al_giorno", false):
		partita.d["gettoni"]["tempo"][str(n) + ("" if i == 0 else ":%d" % i)] = 1
	partita.racconta("Azione del Luogo %d: %s" % [n, _nome_azione_luogo(n, i)])
	await it.esegui(a.get("effetti", []))
	_riassunto(it.rapporto)
	_dopo_azione()

## Carte "Stai morendo" / "Stai impazzendo": effetti quando si ottengono.
func _controlla_stati() -> void:
	for x in partita.personaggi():
		var id := str(x["id"])
		var prima: Dictionary = _stati_noti.get(id, {})
		for k in ["morendo", "impazzendo"]:
			var ora: bool = Personaggi.morente(x) if k == "morendo" else Personaggi.in_follia(x)
			if ora and not prima.get(k, false):
				var img := partita.carta_stato(k)
				if img != "":
					await _domanda_avviso("%s · %s" % [x["nome"], Carte.nome(img)], str(Carte.dati(img).get("testo", {}).get("it", "")))
					var ot = Carte.auto(img).get("ottenuta")
					if ot is Array and not ot.is_empty():
						var it := Interprete.new(partita, null, domande, {"proprietario": x, "carta": img})
						await it.esegui(ot)
						_riassunto(it.rapporto)
					# limite di Oggetti (Stai morendo: 3)
					for m in partita.modificatori("limite_oggetti", x):
						while x.get("oggetti", []).size() > int(m.get("n", 99)):
							var og: Array = x["oggetti"]
							var j := await domande.scegli("%s può tenere solo %d Oggetti: quale scarti?" % [x["nome"], int(m.get("n", 99))], og.map(func(o): return Carte.nome(o)))
							partita.scarta_oggetto(x, og[j])
			prima[k] = ora
		_stati_noti[id] = prima
	# regole "finché" con effetti (Tuathan: chi ha o ottiene Stai impazzendo/morendo…)
	for i in partita.inneschi("sempre"):
		var inn: Dictionary = i["innesco"]
		var eff: Array = inn.get("effetti", []).filter(func(s): return s is Dictionary and str(s.get("tipo", "")) != "modificatore")
		if eff.is_empty() or not i.get("per_personaggio", false):
			continue
		for x in partita.personaggi():
			var it := Interprete.new(partita, null, domande, {"proprietario": x, "carta": i["img"]})
			if inn.get("condizione") is Dictionary and it.valuta(inn["condizione"]) == true:
				await it.esegui(eff)
				await _domanda_avviso(Carte.nome(str(i["img"])), "\n".join(it.rapporto.map(func(z): return ("✔ " if z.get("fatto", true) else "☐ ") + str(z["testo"]))))
	for x in partita.personaggi().duplicate():
		if x.get("morto", false):
			await _morte(x)

## --- Regola della Morte ------------------------------------------------------------------
## Cooperativo: gli Oggetti restano nel Luogo, le risorse tornano nella scatola, si può prendere un
## Personaggio ancora libero (sul Luogo rivelato col numero più basso). Se non ce ne sono, o in
## solitario, la partita fallisce: si può invocare la Misericordia della Madre di Tutti.
func _morte(x: Dictionary) -> void:
	var nome := str(x["nome"])
	partita.racconta("%s è morto." % nome)
	var vivi := partita.personaggi().filter(func(y): return y != x and not y.get("morto", false))
	var liberi := Personaggi.ORDINE.filter(func(id): return not partita.personaggi().any(func(y): return str(y["id"]) == id) and not partita.d.get("caduti", []).has(id))
	if vivi.is_empty() or liberi.is_empty():
		await _domanda_avviso("%s è morto" % nome, ("La partita in solitario termina con la morte del Personaggio." if partita.personaggi().size() == 1 else
			("Non ci sono altri Personaggi nella scatola: la partita fallisce per tutti." if not vivi.is_empty() else "Tutti i Personaggi sono morti: la partita fallisce.")))
		await _fallimento()
		return
	# Oggetti lasciati nel Luogo, risorse nella scatola
	var terra: Dictionary = partita.d.get_or_add("oggetti_terra", {})
	var qui: Array = terra.get_or_add(str(int(x["luogo"])), [])
	qui.append_array(x.get("oggetti", []))
	x["oggetti"] = []
	var i := partita.personaggi().find(x)
	partita.personaggi().erase(x)
	partita.d.get_or_add("caduti", []).append(str(x["id"]))
	partita.d["attivo"] = clampi(int(partita.d.get("attivo", 0)) - (1 if i < int(partita.d.get("attivo", 0)) else 0), 0, maxi(0, partita.personaggi().size() - 1))
	_stati_noti.erase(str(x["id"]))
	var testo := "%s è morto. I suoi Oggetti restano nel Luogo %d (chi passa di lì può raccoglierli); le sue risorse tornano nella scatola." % [nome, int(x["luogo"])]
	await _domanda_avviso("%s è morto" % nome, testo)
	var opz: Array = liberi.map(func(id): return "Prendi " + str(Personaggi.dati(id)["nome"]))
	opz.append("Continua senza un nuovo Personaggio")
	var k := await domande.scegli("Il giocatore di %s può prendere un Personaggio rimasto nella scatola" % nome, opz)
	if k < liberi.size():
		var nuovo := Personaggi.nuovo(str(liberi[k]))
		var luoghi: Array = partita.d["mappa"].keys().map(func(z): return int(z))
		luoghi.sort()
		nuovo["luogo"] = luoghi[0] if not luoghi.is_empty() else 101
		nuovo["passato"] = true
		partita.personaggi().append(nuovo)
		_stati_noti[str(nuovo["id"])] = {"morendo": false, "impazzendo": false}
		partita.racconta("%s entra in gioco nel Luogo %d" % [nuovo["nome"], int(nuovo["luogo"])])
	_ricostruisci_schede()
	partita.cambiato()
	_aggiorna()

func _ricostruisci_schede() -> void:
	for c in _schede.get_children():
		c.queue_free()
	for y in partita.personaggi():
		var pp := PannelloPersonaggio.new(partita, str(y["id"]))
		pp.apri_scheda.connect(_scheda_personaggio)
		_schede.add_child(pp)

func _fallimento() -> void:
	var k := await domande.scegli("La partita è fallita. Cosa volete fare?",
		["Misericordia della Madre di Tutti (Libro dei Segreti, verso 500)", "Torna al menu"])
	if k == 1:
		esci.emit()
		return
	# tutti i Personaggi tornano in vita con le tracce iniziali; mappa, Menhir e Guardiani si scartano
	for id in partita.d.get("caduti", []):
		partita.personaggi().append(Personaggi.nuovo(str(id)))
	partita.d["caduti"] = []
	for y in partita.personaggi():
		var dd := Personaggi.dati(str(y["id"]))
		y.erase("morto")
		y["salute"] = int(dd["salute"])
		y["energia"] = int(dd["energia"])
		y["terrore"] = 0
		y["passato"] = false
		y["luogo"] = 101
		_stati_noti[str(y["id"])] = {"morendo": false, "impazzendo": false}
	partita.d["mappa"] = {}
	partita.d["menhir"] = {}
	partita.d["guardiani"] = []
	partita.d["oggetti_terra"] = {}
	partita.d.get("miniature", {}).clear()
	partita.d["gettoni"] = {"cerca": 0, "tempo": {}}
	partita.ottieni_status("Salvati dalla Dea", [])
	partita.racconta("Misericordia della Madre di Tutti: Salvati dalla Dea")
	_ricostruisci_schede()
	partita.cambiato()
	_aggiorna()
	if partita.diario.apri_numero(999, 500):
		_apri_diario()

## Cerche attive: se la condizione di Successo è soddisfatta se ne applicano gli effetti.
func _controlla_cerche() -> void:
	for img in partita.d.get("cerche", []).duplicate():
		var c = Carte.auto(str(img)).get("cerca")
		if not (c is Dictionary):
			continue
		var it := Interprete.new(partita, null, domande, {"carta": img})
		var succ = c.get("successo")
		if not (succ is Dictionary) or it.valuta(succ) != true:
			continue
		await _domanda_avviso("Cerca completata · " + Carte.nome(str(img)), str(Carte.dati(str(img)).get("cerca", {}).get("it", "")))
		await _completa_cerca(str(img))
	await _controlla_capitolo()

func _completa_cerca(img: String) -> void:
	var c: Dictionary = Carte.auto(img).get("cerca", {})
	var it := Interprete.new(partita, null, domande, {"carta": img})
	partita.racconta("Cerca completata: " + Carte.nome(img))
	await it.esegui(c.get("effetti", []))
	if partita.d.get("cerche", []).has(img) and c.get("effetti", []).is_empty():
		partita.d["cerche"].erase(img)
	_riassunto(it.rapporto)
	_aggiorna()

## Capitolo completato senza preparazione del successivo: si sceglie la carta Preparazione.
func _controlla_capitolo() -> void:
	if not partita.d.get("capitolo_completato", false):
		return
	var cap := partita.capitolo() + 1
	var opz := []
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if str(c.get("sottotipo", "")) == "preparazione" and int(c.get("capitolo", -1)) == cap:
			opz.append(img)
	partita.d["capitolo_completato"] = false
	if opz.is_empty():
		await _domanda_avviso("Capitolo completato", "Il Capitolo %d è completato. Non ci sono altre carte Preparazione: la storia è conclusa (o il prossimo capitolo non è ancora trascritto)." % (cap - 1))
		return
	var k := 0
	if opz.size() > 1:
		k = await domande.scegli("Capitolo %d completato. Quale Preparazione segue? (lo indica il Diario o la carta Evento)" % (cap - 1), opz.map(func(x): return Carte.nome(x) + " " + str(Carte.dati(x).get("lettera", "") if Carte.dati(x).get("lettera") != null else "")))
	var l = Carte.dati(opz[k]).get("lettera")
	Preparazione.capitolo(partita, cap, "" if l == null else str(l))
	await _domanda_avviso("Capitolo %d%s" % [cap, "" if l == null else str(l)], "Nuovo Capitolo preparato: mazzi Incontro aggiornati, nuove Parti nel mazzo Eventi%s." % (", Guardiani sulla mappa" if not Partita.guardiani(partita).is_empty() else ""))
	_aggiorna()

func _mostra_cerche() -> void:
	var cerche: Array = partita.d.get("cerche", [])
	var t := ""
	for img in cerche:
		t += "[b]%s[/b]\n%s\n\n" % [Carte.nome(str(img)), str(Carte.dati(str(img)).get("cerca", {}).get("it", ""))]
	t += "[color=#b9a98a]Le Cerche si completano da sole quando ne raggiungete l'obiettivo (dal Diario o dalle carte).[/color]"
	_messaggio("Cerche attive", t)

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
	var ev := str(r["evento"])
	if ev != "" and not Carte.auto(ev).is_empty():
		t = "\n".join(r["messaggi"].filter(func(m): return not str(m).begins_with("Evento:")))
		await _domanda_avviso("Inizio della Giornata %d" % int(partita.d["giorno"]), (t + "\n\n" if t != "" else "") + "[b]Evento: " + Carte.nome(ev) + "[/b]\n" + str(Carte.dati(ev).get("testo", {}).get("it", "")))
		var it := Interprete.new(partita, null, domande, {})
		await it.risolvi_evento(ev)
		if not it.rapporto.is_empty():
			_riassunto(it.rapporto)
	elif ev != "":
		_mostra_evento(t)
	elif t != "":
		_messaggio("Inizio della Giornata %d" % int(partita.d["giorno"]), t)
	await _scatena("inizio_giornata")
	# rimando del Diario: si riprende dal verso indicato
	var rim = partita.d.get("rimando")
	if rim is Dictionary:
		partita.d.erase("rimando")
		await _domanda_avviso("Diario", "Il Diario vi aveva rimandato qui all'Inizio della Giornata: si riprende dal Luogo %d." % int(rim.get("luogo", 0)))
		if partita.diario.apri_numero(int(rim.get("luogo", 0)), int(rim.get("verso", -1))):
			partita.diario.stato["rimando"] = true
			_apri_diario()
	# Guardiani arrivati dove ci sono i Personaggi
	for g in giornata.guardiani_con_personaggi():
		await _domanda_avviso("Guardiano", "Il Guardiano %s raggiunge il Luogo %d: Incontro!" % [Carte.nome(str(g["img"])), int(g["luogo"])])
		await _incontro_carta(str(g["img"]), str(g.get("colore", "")))
	await _controlla_stati()
	await _controlla_cerche()
	_aggiorna()

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
	var giorno := int(partita.d.get("giorno", 1))
	var gia: Dictionary = partita.d.get("riposo", {})
	if int(gia.get("giorno", -1)) != giorno:
		# Riposo e Sogni si fanno una volta sola: se la finestra si riapre, si mostra il riepilogo salvato
		await _scatena("fine_giornata")
		for x in partita.personaggi():
			await _scatena("riposo", x)
		var righe0 := []
		var sogni0 := []
		for x in partita.personaggi():
			righe0.append(giornata.riposa(x, int(x.get("cibo", 0)) > 0))
			# Riposo a Tuathan: con un 6 si sceglie una risorsa
			while int(x.get("risorse_da_scegliere", 0)) > 0:
				x["risorse_da_scegliere"] = int(x["risorse_da_scegliere"]) - 1
				var rr: String = ["cibo", "ricchezza", "magia"][await domande.scegli("%s ottiene 1 risorsa a scelta (Riposo a Tuathan)" % x["nome"], ["1 Cibo", "1 Ricchezza", "1 Magia"])]
				partita.modifica(x, rr, 1)
				righe0[-1] += " Sceglie 1 %s." % Partita.NOMI_RISORSE.get(rr, rr)
			x.erase("risorse_da_scegliere")
			var s0 := giornata.sogno(x)
			if not s0.is_empty() and not sogni0.any(func(z): return z["testo"] == s0["testo"]):
				sogni0.append(s0)
		partita.d["riposo"] = {"giorno": giorno, "righe": righe0, "sogni": sogni0, "sogni_fatti": false}
		Campagna.modificata()
	var righe: Array = partita.d["riposo"]["righe"]
	var sogni: Array = partita.d["riposo"]["sogni"]
	var t := "[b]Riposo:[/b]\n" + "\n".join(righe)
	for s in sogni:
		t += "\n\n[b]%s:[/b]\n%s" % [s["tipo"], s["testo"]]
	_aggiorna()
	_messaggio("Fine della Giornata %d" % int(partita.d["giorno"]), t + "\n\n[color=#b9a98a]Puoi spendere Esp dalla scheda dei Personaggi (clic sul nome) prima di iniziare la nuova giornata.[/color]", Callable(), {
		"NUOVA GIORNATA": func():
			if partita.d["riposo"].get("sogni_fatti", false):
				giornata.nuova_giornata()
				_inizio_giornata()
				return
			partita.d["riposo"]["sogni_fatti"] = true
			for s in sogni:
				var asg := Dati.auto_diario("s:", str(s["testo"]))
				if asg.get("effetti") is Array:
					var it := Interprete.new(partita, null, domande, {})
					await it.esegui(asg["effetti"])
					if not it.rapporto.is_empty():
						await _domanda_avviso(str(s["tipo"]), "\n".join(it.rapporto.map(func(z): return ("✔ " if z.get("fatto", true) else "☐ ") + str(z["testo"]))))
				else:
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

var _coda: Array = []           # messaggi in attesa mentre è aperta una finestra con pulsanti di scelta
var _modale_importante := false

func _messaggio(titolo: String, testo: String, alla_chiusura: Callable = Callable(), pulsanti: Dictionary = {}, img := "") -> void:
	if is_instance_valid(_modale) and not _modale.is_queued_for_deletion():
		if _modale_importante:
			# la finestra aperta chiede una decisione (es. NUOVA GIORNATA): non la si sostituisce, si accoda
			_coda.append([titolo, testo, alla_chiusura, pulsanti, img])
			return
		_modale.queue_free()
	_modale_importante = not pulsanti.is_empty()
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
	r.custom_minimum_size = Vector2(600 if img != "" else 700, 0)
	sc.add_child(r)
	v.add_child(sc)
	r.resized.connect(func(): sc.custom_minimum_size.y = minf(r.size.y, 620))
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_END
	b.add_theme_constant_override("separation", 10)
	v.add_child(b)
	var chiudi := func():
		vel.queue_free()
		_modale_importante = false
		if not _coda.is_empty():
			var m: Array = _coda.pop_front()
			_messaggio.call_deferred(m[0], m[1], m[2], m[3], m[4])
	for k in pulsanti:
		var cb: Callable = pulsanti[k]
		b.add_child(Tema.pulsante_primario(k, func():
			chiudi.call()
			cb.call(), 17))
	b.add_child(Tema.pulsante("CHIUDI" if not pulsanti.is_empty() else "CONTINUA", func():
		chiudi.call()
		if alla_chiusura.is_valid():
			alla_chiusura.call()))
	var centra := func():
		p.reset_size()
		p.position = ((vel.size - p.size) / 2).max(Vector2.ZERO)
	p.resized.connect(func(): p.position = ((vel.size - p.size) / 2).max(Vector2.ZERO))
	vel.resized.connect(centra)
	v.minimum_size_changed.connect(func(): centra.call_deferred())
	centra.call_deferred()

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
	if n == 199 and partita.tuathan_corrente() != "":
		var ct := Carte.dati(partita.tuathan_corrente())
		_messaggio("Luogo 199 · Tuathan (%d/5)" % partita.tuathan_conta(), str(ct.get("retro_testo", {}).get("it", "")), Callable(), {}, "carte/mazzo/retro_" + partita.tuathan_corrente().get_file().trim_prefix("tuathan_"))
		return
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
				if giornata.migliora_attributo(x, a) and partita.attributo(x, a) >= 3:
					await Interprete.new(partita, null, domande, {}).scegli_abilita(x, a)
				_aggiorna()
				_scheda_personaggio(id)
	if not x.get("oggetti", []).is_empty():
		bot["OGGETTI"] = func(): _gestisci_oggetti(x)
	if int(x.get("esp", 0)) >= 2:
		bot["CARTA DI COMBATTIMENTO (2 Esp)"] = func(): _carta_avanzata(x, "combattimento")
		bot["CARTA DI DIPLOMAZIA (2 Esp)"] = func(): _carta_avanzata(x, "diplomazia")
	t += "\nMazzo di Combattimento: %d carte · Diplomazia: %d carte" % [x["mazzi"]["combattimento"]["mazzo"].size(), x["mazzi"]["diplomazia"]["mazzo"].size()]
	var ab: Array = x.get("abilita", [])
	if not ab.is_empty():
		t += "\n\n[b]Abilità:[/b] " + ", ".join(ab.map(func(z): return "%s (%s)" % [str(z.get("nome", "")), Partita.NOMI_ATTRIBUTI.get(str(z.get("attributo", "")), "")] if z is Dictionary else str(z)))
	var og: Array = x.get("oggetti", [])
	t += "\n[b]Oggetti:[/b] " + (", ".join(og.map(func(z): return Carte.nome(z))) if not og.is_empty() else "nessuno")
	_messaggio(str(x["nome"]), t, Callable(), bot, Personaggi.dati(id)["tessera"])

func _carta_avanzata(x: Dictionary, tipo: String) -> void:
	var tre := giornata.pesca_avanzate(x, tipo)
	if tre.is_empty():
		return
	_scegli_carta("Scegli una carta da aggiungere al mazzo", tre, func(img):
		giornata.scegli_avanzata(x, tipo, img)
		_aggiorna())
