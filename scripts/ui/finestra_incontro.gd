## Finestra dell'Incontro: carta nemica e sua tabella a sinistra, guida al passo attuale, Sequenza,
## anteprima di cosa succede giocando la carta indicata e mano del personaggio attivo al centro,
## cronaca a destra. Sotto ogni carta della mano è scritto se si può giocare e che cosa darebbe.
class_name FinestraIncontro
extends Control

signal finito(esito: String)

var partita: Partita
var inc: Incontro
var domande: Domande
var _nemico: TextureRect
var _stato: RichTextLabel
var _guida: RichTextLabel
var _seq: HBoxContainer
var _mano: HBoxContainer
var _comandi: HBoxContainer
var _log: RichTextLabel
var _anteprima: RichTextLabel
var _fase := "inizio"   # inizio, scegli, gioca, fine, speciale
var _occupato := false

const VERDE_T := "#8fcf6a"
const ROSSO_T := "#e0614f"
const ORO_T := "#d4ae63"
const GRIGIO_T := "#a89a84"

func _init(partita_: Partita, img: String, colore: String, domande_: Domande = null) -> void:
	partita = partita_
	inc = Incontro.new(partita, img, colore)
	domande = domande_
	inc.ui = domande

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.015, 0.95)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 16)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	m.add_child(h)
	# sinistra: carta nemica e sua scheda (tratti spiegati, tabella d'attacco con la riga attuale)
	var sx := VBoxContainer.new()
	sx.custom_minimum_size = Vector2(400, 0)
	sx.add_theme_constant_override("separation", 8)
	h.add_child(sx)
	_nemico = TextureRect.new()
	_nemico.custom_minimum_size = Vector2(400, 420)
	_nemico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nemico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Immagini.carica(Carte.immagine(inc.img), func(t): if is_instance_valid(_nemico): _nemico.texture = t)
	sx.add_child(_nemico)
	var ss := ScrollContainer.new()
	ss.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ss.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sx.add_child(ss)
	_stato = Tema.testo_ricco(17)
	_stato.custom_minimum_size = Vector2(384, 0)
	ss.add_child(_stato)
	# centro: guida, Sequenza, anteprima, comandi, mano
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 8)
	h.add_child(c)
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", Tema.box(Color(0.16, 0.11, 0.06, 0.95), Tema.ORO, 1, 4, 12))
	c.add_child(gp)
	_guida = Tema.testo_ricco(19)
	gp.add_child(_guida)
	c.add_child(Tema.etichetta("SEQUENZA (la carta a destra è quella a cui si collega la prossima)", 14, Tema.TESTO_2))
	var sseq := ScrollContainer.new()
	sseq.custom_minimum_size = Vector2(0, 215)
	sseq.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sseq)
	_seq = HBoxContainer.new()
	_seq.add_theme_constant_override("separation", -90)
	sseq.add_child(_seq)
	var ap := PanelContainer.new()
	ap.add_theme_stylebox_override("panel", Tema.box(Color(0.09, 0.07, 0.05, 0.95), Tema.ORO_SCURO, 1, 4, 10))
	ap.custom_minimum_size = Vector2(0, 225)
	c.add_child(ap)
	var sap := ScrollContainer.new()
	sap.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ap.add_child(sap)
	_anteprima = Tema.testo_ricco(17)
	_anteprima.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sap.add_child(_anteprima)
	_comandi = HBoxContainer.new()
	_comandi.add_theme_constant_override("separation", 10)
	c.add_child(_comandi)
	var sm := ScrollContainer.new()
	sm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sm.custom_minimum_size = Vector2(0, 330)
	sm.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(sm)
	_mano = HBoxContainer.new()
	_mano.add_theme_constant_override("separation", 12)
	sm.add_child(_mano)
	# destra: cronaca
	var dx := PanelContainer.new()
	dx.custom_minimum_size = Vector2(330, 0)
	h.add_child(dx)
	var dv := VBoxContainer.new()
	dx.add_child(dv)
	dv.add_child(Tema.etichetta("CRONACA DELL'INCONTRO", 15))
	var sl := ScrollContainer.new()
	sl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sl.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(sl)
	_log = Tema.testo_ricco(15)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_child(_log)
	inc.messaggio.connect(func(t):
		_log.text = "• " + Dati.testo_bb(t, 16) + "\n" + _log.text)
	inc.cambiato.connect(_aggiorna)
	inc.finito.connect(func(_e):
		_fase = "fine"
		_aggiorna())
	if inc.speciale():
		_fase = "speciale"
	else:
		inc.inizia(partita.compagnia().filter(func(p): return int(p["salute"]) > 0))
	_aggiorna()

func _bb(t: String) -> String:
	return Dati.testo_bb(t, 18)

func _aggiorna() -> void:
	if not is_instance_valid(_stato):
		return
	_stato.text = _testo_stato()
	for x in _seq.get_children():
		x.queue_free()
	for i in inc.sequenza.size():
		var s: Dictionary = inc.sequenza[i]
		var t := _carta(str(s["img"]), Vector2(142, 215))
		var info := []
		if int(s.get("tempo", 0)) > 0:
			info.append("Gettoni Tempo: %d" % int(s["tempo"]))
			t.modulate = Color(1, 0.92, 0.8)
		if int(s.get("cariche", 0)) > 0:
			info.append("Cariche: %d" % int(s["cariche"]))
		t.tooltip_text = Carte.nome(str(s["img"])) + ("\n" + "\n".join(info) if not info.is_empty() else "")
		_seq.add_child(t)
	for x in _mano.get_children():
		x.queue_free()
	for x in _comandi.get_children():
		x.queue_free()
	match _fase:
		"speciale":
			_guida.text = "[b]Incontro speciale[/b]: non si combatte. Applica l'effetto della carta."
			_speciale()
		"inizio":
			_guida.text = _bb("[b]Prima di iniziare[/b] guarda la mano: puoi [b]rimescolarla[/b] (ne riprendi una carta in meno)%s. Poi premi [b]INIZIA[/b].\n%s" % [
				", oppure [b]Evitare[/b] l'Incontro pagando il costo" if _evitabile_mostrato() else "", _obiettivo()])
			_anteprima.text = _spiegazione_regole()
			_mostra_mano(inc.membri[0] if not inc.membri.is_empty() else {}, false)
			for p in inc.membri:
				var id := str(p["id"])
				_comandi.add_child(Tema.pulsante("RIMESCOLA (%s)" % p["nome"], func(): inc.rimescola_mano(id), 15))
			if _evitabile_mostrato():
				var testo_ev := Dati.testo_leggibile(str(inc.carta.get("evitare", {}).get("it", ""))) if inc.carta.get("evitare") is Dictionary else ""
				var be := Tema.pulsante("EVITARE (" + testo_ev + ")", func():
					await inc.evita()
					_aggiorna(), 15)
				be.disabled = not inc.evitabile()
				be.tooltip_text = "Non potete pagare il costo" if be.disabled else ""
				_comandi.add_child(be)
			_comandi.add_child(Tema.pulsante_primario("INIZIA", func():
				_fase = "scegli"
				_aggiorna()))
		"scegli":
			var liberi := inc.da_attivare()
			if liberi.is_empty():
				inc.fine_turno()
				return
			_guida.text = _bb("[b]Turno %d[/b] — scegli quale Personaggio si attiva. %s" % [inc.turno, _obiettivo()])
			_anteprima.text = _bb("Quando un Personaggio si attiva gioca [b]una carta qualsiasi[/b] dalla mano; altre carte solo se collegano una [b]Chiave dorata[/b]. Poi il nemico %s." % ("risponde (Risposta della fase)" if inc.diplomazia else "attacca secondo la riga della tabella che corrisponde alla Riserva"))
			for p in liberi:
				var id := str(p["id"])
				_comandi.add_child(Tema.pulsante_primario("ATTIVA %s" % str(p["nome"]).to_upper(), func():
					_fase = "gioca"
					await inc.attiva(id)
					_aggiorna()))
			_mostra_mano(liberi[0], false)
		"gioca":
			var a := inc.attivo()
			if inc.concluso != "":
				_fase = "fine"
				_aggiorna()
				return
			if a.is_empty():
				_fase = "scegli"
				_aggiorna()
				return
			var prima := inc.carte_attivazione == 0
			var panico := inc.in_panico() and prima
			_guida.text = _bb("[b]%s[/b] — %s\n%s" % [a["nome"],
				("[color=%s]IN PANICO[/color]: la prima carta è quella in cima al mazzo." % ROSSO_T) if panico else
				("Gioca [b]una carta qualsiasi[/b] della mano (passa sopra una carta per vedere cosa succede)." if prima else
				"Puoi giocare un'[b]altra carta[/b] solo se collega una Chiave dorata, oppure [b]TERMINA[/b]."),
				_esito_termina()])
			if _anteprima.text == "" or prima:
				_anteprima.text = _bb("Passa il mouse su una carta della mano: qui vedrai quali Chiavi si collegano, quanti segnalini o quanta Affinità ottieni, cosa pescherai e come risponderà il nemico.")
			if panico and not inc.mazzi[str(a["id"])].is_empty():
				var cima: String = inc.mazzi[str(a["id"])][0]
				_anteprima.text = _descrivi_anteprima(cima)
				_comandi.add_child(Tema.pulsante_primario("GIOCA LA CARTA IN CIMA AL MAZZO", func(): await _gioca(cima), 15))
			else:
				_mostra_mano(a, true)
			var fine := Tema.pulsante_primario("TERMINA L'ATTIVAZIONE", func():
				if _occupato:
					return
				_occupato = true
				await inc.termina_carte()
				_occupato = false
				if inc.concluso == "":
					_fase = "scegli"
				_anteprima.text = ""
				_aggiorna(), 16)
			fine.tooltip_text = Dati.testo_leggibile(_esito_termina())
			_comandi.add_child(fine)
			var sc := Tema.pulsante("SCAPPARE" if not inc.diplomazia else "RINUNCIARE", func():
				await inc.scappa()
				if inc.concluso == "":
					_fase = "scegli"
				_aggiorna(), 15)
			sc.tooltip_text = "Rinunci: Fallimento della Diplomazia." if inc.diplomazia else "−1 Energia e subisci l'attacco di opportunità: " + Dati.testo_leggibile(str(inc.carta.get("opportunita", {}).get("it", "")))
			_comandi.add_child(sc)
			var pm := CheckBox.new()
			pm.text = "Usa la Magia per le Chiavi Magiche"
			pm.button_pressed = inc.paga_magia
			pm.toggled.connect(func(v):
				inc.paga_magia = v
				_aggiorna())
			_comandi.add_child(pm)
			# Oggetti, Segreti e Abilità usabili in qualsiasi momento
			for u in partita.inneschi("in_qualsiasi_momento", a):
				var uu: Dictionary = u
				_comandi.add_child(Tema.pulsante("USA: " + Carte.nome(str(uu["img"])), func(): await _usa_carta(uu), 14))
		"fine":
			var nomi := {"vittoria": "VITTORIA!", "fallimento": "Fallimento.", "fuga": "Siete scappati.", "fuga_nemico": "Il nemico è fuggito: niente Ricompensa.", "evitato": "Incontro evitato.", "morte": "La Compagnia è caduta.", "speciale": "Effetto applicato."}
			_guida.text = "[b]%s[/b]" % nomi.get(inc.concluso, inc.concluso)
			_anteprima.text = "Il riepilogo è nella cronaca a destra."
			_comandi.add_child(Tema.pulsante_primario("TORNA ALLA MAPPA", _chiudi, 17))

## Testo di un attacco con le parole chiave spiegate ("Fuggire" = il nemico scappa…).
func _spiega_attacco(t: String) -> String:
	var p := Dati.testo_piano(t).strip_edges().to_lower()
	if p.begins_with("fugg"):
		return t + " (il nemico scappa: Incontro finito senza Bottino)"
	t = t.replace("{i:discard}", "{i:discard} (scarti 1 carta dalla mano)").replace("(inevitabile)", "(inevitabile: non si previene)")
	if t.strip_edges() == "" or t.strip_edges() == "-":
		return "nessun danno"
	return t

func _evitabile_mostrato() -> bool:
	return inc.carta.get("evitare") is Dictionary or inc.auto.get("evitare") is Dictionary

func _gioca(c: String) -> void:
	if _occupato:
		return
	_occupato = true
	await inc.gioca(c)
	_occupato = false
	_anteprima.text = ""
	_aggiorna()

## Obiettivo dell'Incontro in una riga.
func _obiettivo() -> String:
	if inc.diplomazia:
		var a: Dictionary = inc.carta.get("affinita", {})
		var fs: Array = inc.carta.get("fasi", [])
		return "Obiettivo: portare l'Affinità a [color=%s]+%d[/color] in ogni fase (%d fasi); a [color=%s]−%d[/color] fallisci." % [VERDE_T, int(a.get("verdi", 3)), maxi(1, fs.size()), ROSSO_T, int(a.get("rossi", 3))]
	return "Obiettivo: [b]%d segnalini[/b] nella Riserva (ora %d). Il nemico attacca secondo la Riserva che hai a fine attivazione." % [int(inc.carta.get("valore", 0)), inc.riserva]

## Cosa succede premendo TERMINA ora.
func _esito_termina() -> String:
	if inc.diplomazia:
		var r := inc.attacco_previsto(inc.riserva)
		return "Se termini ora, Risposta: [color=%s]%s[/color]" % [ROSSO_T, str(r.get("testo", "nessuna"))] if not r.is_empty() else ""
	var t := ""
	var min_carte := 2 if inc.ha_tratto("Opportun") else 1
	if inc.carte_attivazione < min_carte:
		t += "Se termini con %s subisci anche l'[b]attacco di opportunità[/b]: [color=%s]%s[/color]. " % ["0 carte" if min_carte == 1 else "meno di 2 carte", ROSSO_T, _spiega_attacco(str(inc.carta.get("opportunita", {}).get("it", "")))]
	if inc.riserva >= int(inc.carta.get("valore", 99)):
		return t + "[color=%s]Hai già raggiunto il Valore: TERMINA per vincere.[/color]" % VERDE_T
	var r2 := inc.attacco_previsto(inc.riserva)
	if not r2.is_empty():
		t += "Se termini ora (Riserva %d) il nemico attacca: [color=%s]%s[/color]%s" % [inc.riserva, ROSSO_T, str(r2.get("testo", "")), (" — %d Ferite" % int(r2["ferite"])) if int(r2.get("ferite", 0)) > 0 else ""]
		if inc.ha_tratto("Furia"):
			t += " (due volte: Furia)"
	return t

## Riepilogo delle regole dell'Incontro (fase iniziale).
func _spiegazione_regole() -> String:
	var t := "[b]Come funziona[/b]\n"
	t += "• A ogni turno ogni Personaggio si attiva una volta: gioca una carta qualsiasi, poi altre carte solo collegando una [b]Chiave dorata[/b].\n"
	t += "• Una carta si collega a quella precedente riga per riga: la semichiave di destra della carta precedente indica l'Attributo richiesto (o la Magia, pagando 1 Magia); se lo possiedi ottieni il bonus della semichiave sinistra della nuova carta. La Chiave in fondo si collega sempre, moltiplicata dal numero della carta precedente.\n"
	if inc.diplomazia:
		t += "• Le frecce spostano l'Affinità: a fine attivazione, se non hai vinto la fase, il nemico dà la sua Risposta.\n"
	else:
		t += "• I segnalini vanno nella Riserva: a fine attivazione, se non hai raggiunto il Valore, il nemico attacca con la riga della tabella che corrisponde alla Riserva. Se perdi segnalini che non hai, scarti carte dalla mano.\n"
	t += "• A fine turno si scartano carte fino a 3 in mano e se ne pesca 1."
	return _bb(t)

func _testo_stato() -> String:
	var c := inc.carta
	var t := "[b]%s[/b]\n" % Carte.nome(inc.img)
	for tr in inc.tratti():
		t += "[color=%s]%s[/color]\n" % [ORO_T, inc.spiega_tratto(str(tr))]
	if inc.diplomazia:
		var a: Dictionary = c.get("affinita", {})
		var fs: Array = c.get("fasi", [])
		var verdi := int(a.get("verdi", 3))
		var rossi := int(a.get("rossi", 3))
		var barra := ""
		for i in range(-rossi, verdi + 1):
			var col := ROSSO_T if i < 0 else (VERDE_T if i > 0 else GRIGIO_T)
			barra += ("[color=%s][b]◆[/b][/color]" % col) if i == inc.affinita else ("[color=%s]◇[/color]" % col)
		t += "\nAffinità [b]%+d[/b]  %s\n" % [inc.affinita, barra]
		for i in fs.size():
			var f: Dictionary = fs[i]
			var nome := str(f.get("nome", {}).get("it", "")) if f.get("nome") is Dictionary else ""
			var cur := i == inc.fase
			t += "%s[b]Fase %d[/b] %s\n" % ["▸ " if cur else "   ", i + 1, nome]
			if cur:
				var sp: Dictionary = f.get("speciale", {})
				for k in sp:
					t += "    bonus speciale con %s: %s\n" % [Partita.NOMI_ATTRIBUTI.get(k, k), str(sp[k].get("it", sp[k])) if sp[k] is Dictionary else str(sp[k])]
				var r = f.get("risposta", {})
				t += "    Risposta: [color=%s]%s[/color]\n" % [ROSSO_T, str(r.get("it", "")) if r is Dictionary else str(r)]
	else:
		var val := int(c.get("valore", 0))
		t += "\nRiserva [b]%d[/b] / Valore [b]%d[/b]\n\n[b]Attacco del nemico[/b] (in base alla Riserva):\n" % [inc.riserva, val]
		for r in c.get("tabella", []):
			var cur := inc.riserva >= int(r.get("da", 0)) and inc.riserva <= int(r.get("a", 99))
			var fascia := ("%d" % int(r["da"])) if int(r.get("da", 0)) == int(r.get("a", 0)) else ("%d-%d" % [int(r.get("da", 0)), int(r.get("a", 0))])
			t += ("[color=%s][b]▸ %s: %s[/b][/color]\n" % [ROSSO_T, fascia, _spiega_attacco(str(r.get("it", "")))]) if cur else ("   %s: %s\n" % [fascia, _spiega_attacco(str(r.get("it", "")))])
		t += "   %d+: [color=%s]vittoria[/color]\n" % [val, VERDE_T]
		if c.get("opportunita") is Dictionary:
			t += "\n[b]Opportunità[/b] (se Scappi o termini con troppo poche carte): %s\n" % _spiega_attacco(str(c["opportunita"].get("it", "")))
	if inc.prevenzione > 0:
		t += "\nFerite prevenute in questo attacco: %d\n" % inc.prevenzione
	if c.get("ricompensa") is Dictionary and str(c["ricompensa"].get("it", "")) != "":
		t += "\n[b]Ricompensa[/b] (a ognuno): %s" % str(c["ricompensa"]["it"])
	if c.get("bottino") is Dictionary and str(c["bottino"].get("it", "")) != "":
		t += "\n[b]Bottino[/b] (da dividere): %s" % str(c["bottino"]["it"])
	if c.get("fallimento") is Dictionary and str(c["fallimento"].get("it", "")) != "":
		t += "\n[b]Fallimento[/b]: %s" % str(c["fallimento"]["it"])
	t += "\n"
	for p in inc.membri:
		var pan := "  [color=%s]PANICO[/color]" % ROSSO_T if Personaggi.in_panico(p) else ""
		t += "\n[b]%s[/b]%s — Salute %d · Energia %d · Terrore %d · Magia %d · mano %d, mazzo %d" % [p["nome"], pan, int(p["salute"]), int(p["energia"]), int(p["terrore"]), int(p["magia"]),
			inc.mani.get(str(p["id"]), []).size(), inc.mazzi.get(str(p["id"]), []).size()]
	return Dati.testo_bb(t, 17)

func _mostra_mano(p: Dictionary, giocabile: bool) -> void:
	if p.is_empty():
		return
	for c in inc.mani.get(str(p["id"]), []):
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var t := _carta(c, Vector2(180, 272))
		v.add_child(t)
		var cap := Tema.testo_ricco(14)
		cap.custom_minimum_size = Vector2(180, 0)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cap)
		if giocabile:
			var a := inc.anteprima(c)
			var ok: bool = a["giocabile"]
			t.modulate = Color.WHITE if ok else Color(0.45, 0.45, 0.45)
			cap.text = _bb(_riassunto_carta(a))
			t.mouse_entered.connect(func(): _anteprima.text = _descrivi_anteprima(c))
			if ok:
				t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				t.gui_input.connect(func(e):
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						await _gioca(c))
		_mano.add_child(v)

## Riga breve sotto la carta: giocabile o no e cosa darebbe.
func _riassunto_carta(a: Dictionary) -> String:
	if not a["giocabile"]:
		return "[color=%s]✘ %s[/color]" % [GRIGIO_T, "serve una Chiave dorata" if inc.carte_attivazione > 0 else "non giocabile"]
	var parti := []
	if inc.diplomazia:
		if int(a["affinita"]) != 0:
			parti.append("Affinità %+d" % int(a["affinita"]))
	elif int(a["cubi"]) > 0:
		parti.append("+%d segnalini" % int(a["cubi"]))
	if int(a["pesca"]) > 0:
		parti.append("pesca %d" % int(a["pesca"]))
	if int(a["extra"]) > 0:
		parti.append("+carta")
	if int(a["magia"]) > 0:
		parti.append("−%d Magia" % int(a["magia"]))
	if not a["speciali"].is_empty():
		parti.append("speciale")
	if a.get("vittoria", false) or a.get("fase_vinta", false):
		parti.append("[color=%s]VINCI[/color]" % VERDE_T)
	return "[color=%s]✔[/color] " % VERDE_T + (", ".join(parti) if not parti.is_empty() else "nessun bonus")

## Descrizione completa di cosa succede giocando la carta.
func _descrivi_anteprima(c: String) -> String:
	var a := inc.anteprima(c)
	var t := "[b]%s[/b]  " % Carte.nome(c)
	t += ("[color=%s]si può giocare[/color]" % VERDE_T) if a["giocabile"] else ("[color=%s]non si può giocare[/color]: %s" % [ROSSO_T, a.get("motivo", "")])
	t += "\n"
	if a["righe"].is_empty():
		t += "Nessuna Chiave si collega alla carta precedente.\n"
	for r in a["righe"]:
		if r["ok"]:
			t += "[color=%s]✔ %s[/color] → %s%s\n" % [VERDE_T, r["chiave"], r["effetti"], (" (%s)" % r["nota"]) if r["nota"] != "" else ""]
		else:
			t += "[color=%s]✘ %s[/color] → %s (%s)\n" % [GRIGIO_T, r["chiave"], r["effetti"], r["nota"] if r["nota"] != "" else "non collegata"]
	if inc.diplomazia:
		t += "Affinità: %+d → [b]%+d[/b]" % [inc.affinita, int(a["affinita_dopo"])]
		if a.get("fase_vinta", false):
			t += "  [color=%s]fase vinta![/color]" % VERDE_T
		elif a.get("fallita", false):
			t += "  [color=%s]fallimento![/color]" % ROSSO_T
		t += "\n"
	else:
		t += "Riserva: %d → [b]%d[/b] / %d" % [inc.riserva, int(a["riserva_dopo"]), int(inc.carta.get("valore", 0))]
		if a.get("vittoria", false):
			t += "  [color=%s]raggiungi il Valore: VITTORIA![/color]" % VERDE_T
		t += "\n"
	if int(a["extra"]) > 0:
		t += "[color=%s]Chiave dorata: dopo potrai giocare un'altra carta.[/color]\n" % ORO_T
	for cp in a.get("capacita", []):
		t += "Capacità %s\n" % cp
	if not a.get("aperte", []).is_empty():
		t += "[color=%s]La carta seguente potrà collegarsi a: %s[/color]\n" % [GRIGIO_T, ", ".join(a["aperte"])]
	var att: Dictionary = a.get("attacco", {})
	if not a.get("vittoria", false) and not a.get("fase_vinta", false) and not att.is_empty():
		if inc.diplomazia:
			t += "Poi, se termini: Risposta [color=%s]%s[/color]" % [ROSSO_T, str(att.get("testo", ""))]
		else:
			t += "Poi, se termini: il nemico attacca [color=%s]%s[/color]%s" % [ROSSO_T, _spiega_attacco(str(att.get("testo", ""))), (" (%d Ferite)" % int(att["ferite"])) if int(att.get("ferite", 0)) > 0 else ""]
	return _bb(t)

func _chiudi() -> void:
	var gl := Partita.guardiani(partita)
	var presente := -1
	for i in gl.size():
		if str(gl[i].get("img", "")) == inc.img:
			presente = i
	if inc.guardiano_resta():
		if presente < 0:
			gl.append({"img": inc.img, "colore": inc.colore, "luogo": partita.luogo_attivo()})
		partita.racconta("Il Guardiano %s resta al Luogo %d" % [Carte.nome(inc.img), partita.luogo_attivo()])
	elif presente >= 0 and inc.concluso in ["vittoria", "fuga_nemico", "evitato"]:
		gl.remove_at(presente)
		partita.racconta("Il Guardiano %s è sconfitto" % Carte.nome(inc.img))
	finito.emit(inc.concluso)
	queue_free()

## Usa una carta con innesco "in qualsiasi momento" durante l'Incontro.
func _usa_carta(u: Dictionary) -> void:
	var inn: Dictionary = u["innesco"]
	var it := Interprete.new(partita, inc, domande, {"carta": u["img"], "proprietario": u["chi"]})
	if inn.get("condizione") is Dictionary and not inn["condizione"].is_empty() and it.valuta(inn["condizione"]) == false:
		inc.nota("%s: condizione non soddisfatta." % Carte.nome(str(u["img"])))
		return
	if inn.get("costo") is Array and not await it.esegui(inn["costo"]):
		inc.nota("%s: costo non pagabile." % Carte.nome(str(u["img"])))
		return
	inc.nota("Usata: " + Carte.nome(str(u["img"])))
	await it.esegui(inn.get("effetti", []))
	for r in it.rapporto:
		inc.nota(("✔ " if r.get("fatto", true) else "☐ ") + str(r["testo"]))
	inc._controlla_fine_carte()
	_aggiorna()

## Incontri speciali (senza Chiavi): si mostra il testo e si applica l'effetto.
func _speciale() -> void:
	var e = inc.carta.get("effetto", inc.carta.get("testo", {}))
	var t := str(e.get("it", "")) if e is Dictionary else ""
	_anteprima.text = _bb(t)
	_comandi.add_child(Tema.pulsante_primario("APPLICA L'EFFETTO", func():
		if inc.auto.get("effetto") is Array and not inc.auto["effetto"].is_empty():
			inc.membri = partita.compagnia().duplicate()
			await inc._esegui_fuori(inc.auto["effetto"])
		else:
			var fatti := Effetti.applica(t, partita)
			for f in fatti:
				inc.nota(("✔ " if f.get("fatto", false) else "☐ da fare: ") + str(f["testo"]))
		if inc.concluso == "":
			inc.concluso = "speciale"
		_fase = "fine"
		_aggiorna()))
	_comandi.add_child(Tema.pulsante("CHIUDI", func(): inc.concluso = "speciale"; _chiudi()))

func _carta(c: String, dim: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = dim
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.tooltip_text = Carte.nome(c)
	Immagini.carica(Carte.immagine(c), func(tx): if is_instance_valid(t): t.texture = tx)
	return t
