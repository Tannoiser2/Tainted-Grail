## Finestra dell'Incontro. In alto la guida al passo attuale e i comandi; poi il tavolo: la carta nemica
## con la Sequenza collegata alla sua destra come sul tavolo vero (ogni carta copre la precedente lasciando
## scoperte le sue semichiavi), con i cubetti universali, i gettoni Tempo, le Cariche e le semichiavi che si
## possono collegare evidenziate; sotto, la mano del Personaggio (un tocco sceglie e mostra cosa succede, il
## secondo tocco o GIOCA la gioca); in fondo cosa fa la carta scelta, cosa succede se si termina, lo stato
## della Compagnia e la cronaca. Non si ripete ciò che è già stampato sulla carta nemica.
class_name FinestraIncontro
extends Control

signal finito(esito: String)

var partita: Partita
var inc: Incontro
var domande: Domande
var _guida: RichTextLabel
var _comandi: HFlowContainer
var _scorri_tavolo: ScrollContainer
var _fila: Control
var _mano: HBoxContainer
var _anteprima: RichTextLabel
var _compagnia: RichTextLabel
var _log: RichTextLabel
var _fase := "inizio"   # inizio, scegli, gioca, fine, speciale
var _occupato := false
var _scelta := ""       # carta della mano scelta (primo tocco)
var _sopra := ""        # carta sotto il puntatore

const VERDE_T := "#8fcf6a"
const ROSSO_T := "#e0614f"
const ORO_T := "#d4ae63"
const GRIGIO_T := "#a89a84"
## Altezza delle carte sul tavolo e in mano: si adatta all'altezza dello schermo (più grandi in 4:3, su iPad).
var H_TAVOLO := 400.0
var H_MANO := 280.0
var _sm: ScrollContainer

func _init(partita_: Partita, img: String, colore: String, domande_: Domande = null) -> void:
	partita = partita_
	inc = Incontro.new(partita, img, colore)
	domande = domande_
	inc.ui = domande

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.015, 1.0)
	_dimensioni()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 12)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	# guida e comandi
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", Tema.box(Color(0.16, 0.11, 0.06, 0.95), Tema.ORO, 1, 4, 10))
	v.add_child(gp)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 8)
	gp.add_child(gv)
	_guida = Tema.testo_ricco(19)
	_guida.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guida.custom_minimum_size = Vector2(600, 0)
	gv.add_child(_guida)
	_comandi = HFlowContainer.new()
	_comandi.add_theme_constant_override("h_separation", 10)
	_comandi.add_theme_constant_override("v_separation", 6)
	gv.add_child(_comandi)
	# tavolo: carta nemica + Sequenza
	_scorri_tavolo = ScrollContainer.new()
	_scorri_tavolo.custom_minimum_size = Vector2(0, H_TAVOLO + 14)
	_scorri_tavolo.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scorri_tavolo)
	_fila = Control.new()
	_fila.mouse_filter = Control.MOUSE_FILTER_PASS
	_scorri_tavolo.add_child(_fila)
	# mano
	var sm := ScrollContainer.new()
	_sm = sm
	sm.custom_minimum_size = Vector2(0, H_MANO + 44)
	sm.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sm)
	_mano = HBoxContainer.new()
	_mano.add_theme_constant_override("separation", 12)
	sm.add_child(_mano)
	# in fondo: cosa succede | Compagnia e cronaca
	var basso := HBoxContainer.new()
	basso.size_flags_vertical = Control.SIZE_EXPAND_FILL
	basso.custom_minimum_size = Vector2(0, 150)
	basso.add_theme_constant_override("separation", 10)
	v.add_child(basso)
	var ap := PanelContainer.new()
	ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ap.add_theme_stylebox_override("panel", Tema.box(Color(0.09, 0.07, 0.05, 0.95), Tema.ORO_SCURO, 1, 4, 10))
	basso.add_child(ap)
	var sap := ScrollContainer.new()
	sap.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ap.add_child(sap)
	_anteprima = Tema.testo_ricco(17)
	_anteprima.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anteprima.custom_minimum_size = Vector2(500, 0)
	sap.add_child(_anteprima)
	var dx := PanelContainer.new()
	dx.custom_minimum_size = Vector2(560, 0)
	dx.add_theme_stylebox_override("panel", Tema.box(Color(0.09, 0.07, 0.05, 0.95), Tema.ORO_SCURO, 1, 4, 10))
	basso.add_child(dx)
	var sd := ScrollContainer.new()
	sd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dx.add_child(sd)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sd.add_child(dv)
	_compagnia = Tema.testo_ricco(16)
	_compagnia.custom_minimum_size = Vector2(530, 0)
	dv.add_child(_compagnia)
	dv.add_child(Tema.etichetta("CRONACA DELL'INCONTRO", 14, Tema.ORO))
	_log = Tema.testo_ricco(15)
	_log.custom_minimum_size = Vector2(530, 0)
	dv.add_child(_log)
	inc.messaggio.connect(func(t):
		_log.text = "• " + Dati.testo_bb(t, 16) + "\n" + _log.text)
	inc.cambiato.connect(_aggiorna)
	inc.finito.connect(func(_e):
		_fase = "fine"
		_aggiorna())
	get_viewport().size_changed.connect(func():
		if is_instance_valid(_fila):
			_dimensioni()
			_scorri_tavolo.custom_minimum_size.y = H_TAVOLO + 14
			_sm.custom_minimum_size.y = H_MANO + 44
			_aggiorna())
	if inc.speciale():
		_fase = "speciale"
	else:
		inc.inizia(partita.compagnia().filter(func(p): return int(p["salute"]) > 0))
	_aggiorna()

## Misuratore di Affinità della carta (alcune carte non lo hanno nei dati).
func _aff() -> Dictionary:
	return inc.carta["affinita"] if inc.carta.get("affinita") is Dictionary else {}

func _bb(t: String) -> String:
	return Dati.testo_bb(t, 18)

func _dimensioni() -> void:
	var vh := get_viewport_rect().size.y
	var libero := maxf(600.0, vh - 330.0)
	H_TAVOLO = floorf(libero * 0.555)
	H_MANO = floorf(libero * 0.385)

## Il Personaggio di cui si mostra la mano.
func _chi_mano() -> Dictionary:
	var a := inc.attivo()
	if not a.is_empty():
		return a
	var liberi := inc.da_attivare()
	if not liberi.is_empty():
		return liberi[0]
	return inc.membri[0] if not inc.membri.is_empty() else {}

func _aggiorna() -> void:
	if not is_instance_valid(_guida):
		return
	for x in _comandi.get_children():
		x.queue_free()
	match _fase:
		"speciale":
			_guida.text = "[b]Incontro speciale[/b]: non si combatte. Applica l'effetto della carta."
			_speciale()
		"inizio":
			_guida.text = _bb("[b]Prima di iniziare[/b] guarda la mano: puoi [b]rimescolarla[/b] (ne riprendi una carta in meno)%s. Poi premi [b]INIZIA[/b]. %s" % [
				", oppure [b]Evitare[/b] l'Incontro pagando il costo" if _evitabile_mostrato() else "", _obiettivo()])
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
			if inc.concluso != "":
				_fase = "fine"
				_aggiorna()
				return
			var liberi := inc.da_attivare()
			if liberi.is_empty():
				if inc.membri.all(func(x): return int(x.get("salute", 0)) <= 0):
					inc.concludi("morte")
					return
				inc.fine_turno.call_deferred()
				return
			_guida.text = _bb("[b]Turno %d[/b]: scegli quale Personaggio si attiva. %s" % [inc.turno, _obiettivo()])
			for p in liberi:
				var id := str(p["id"])
				_comandi.add_child(Tema.pulsante_primario("ATTIVA %s" % str(p["nome"]).to_upper(), func():
					_fase = "gioca"
					_scelta = ""
					await inc.attiva(id)
					_aggiorna()))
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
			_guida.text = _bb("[b]%s[/b]: %s" % [a["nome"],
				("[color=%s]IN PANICO[/color]: la prima carta è quella in cima al mazzo." % ROSSO_T) if panico else
				("tocca una carta della mano per vedere cosa fa, toccala di nuovo (o GIOCA) per giocarla." if prima else
				"puoi giocare un'[b]altra carta[/b] solo se collega una Chiave dorata, oppure [b]TERMINA[/b].")])
			if panico and not inc.mazzi[str(a["id"])].is_empty():
				var cima: String = inc.mazzi[str(a["id"])][0]
				_scelta = cima
				_comandi.add_child(Tema.pulsante_primario("GIOCA LA CARTA IN CIMA AL MAZZO", func(): await _gioca(cima), 15))
			elif _scelta != "" and inc.mani.get(str(a["id"]), []).has(_scelta) and inc.anteprima(_scelta)["giocabile"]:
				_comandi.add_child(Tema.pulsante_primario("GIOCA %s" % Carte.nome(_scelta).to_upper(), func(): await _gioca(_scelta), 16))
			var fine := Tema.pulsante_primario("TERMINA L'ATTIVAZIONE", func():
				if _occupato:
					return
				_occupato = true
				_scelta = ""
				await inc.termina_carte()
				_occupato = false
				if inc.concluso == "":
					_fase = "scegli"
				_aggiorna(), 16)
			fine.tooltip_text = Dati.testo_leggibile(_esito_termina())
			_comandi.add_child(fine)
			var sc := Tema.pulsante("SCAPPARE" if not inc.diplomazia else "RINUNCIARE", func():
				await inc.scappa()
				if inc.concluso == "":
					_fase = "scegli"
				_aggiorna(), 15)
			sc.disabled = not inc.puo_scappare()
			sc.tooltip_text = "In questo Incontro non si può Scappare." if sc.disabled else "Rinunci: Fallimento della Diplomazia." if inc.diplomazia else "−1 Energia e subisci l'attacco di opportunità: " + Dati.testo_leggibile(str(inc.carta.get("opportunita", {}).get("it", "")))
			_comandi.add_child(sc)
			var pm := CheckBox.new()
			pm.text = "Usa la Magia per le Chiavi Magiche"
			pm.button_pressed = inc.paga_magia
			pm.toggled.connect(func(vv):
				inc.paga_magia = vv
				_aggiorna())
			_comandi.add_child(pm)
			# Oggetti, Segreti e Abilità usabili in qualsiasi momento
			for u in partita.inneschi("in_qualsiasi_momento", a):
				var uu: Dictionary = u
				_comandi.add_child(Tema.pulsante("USA: " + Carte.nome(str(uu["img"])), func(): await _usa_carta(uu), 14))
		"fine":
			var nomi := {"vittoria": "VITTORIA!", "fallimento": "Fallimento.", "fuga": "Siete scappati.", "fuga_nemico": "Il nemico è fuggito: niente Ricompensa.", "evitato": "Incontro evitato.", "morte": "La Compagnia è caduta.", "speciale": "Effetto applicato."}
			_guida.text = "[b]%s[/b]  Il riepilogo è nella cronaca qui sotto." % nomi.get(inc.concluso, inc.concluso)
			_comandi.add_child(Tema.pulsante_primario("TORNA ALLA MAPPA", _chiudi, 17))
	_disegna_tavolo()
	_disegna_mano()
	_aggiorna_info()

## Carta nemica e Sequenza, collegate come sul tavolo.
func _disegna_tavolo() -> void:
	for x in _fila.get_children():
		x.queue_free()
	var nem := CartaIncontro.new(inc.img, H_TAVOLO, true)
	nem.position = Vector2.ZERO
	nem.valore = inc.valore()
	if inc.diplomazia:
		var a: Dictionary = _aff()
		nem.casella_affinita = clampi(int(a.get("rossi", 3)) + inc.affinita, 0, int(a.get("rossi", 3)) + int(a.get("verdi", 3)))
	elif _fase != "speciale":
		nem.cubi = inc.riserva
	nem.riga_tabella = _riga_tabella()
	_fila.add_child(nem)
	var w := H_TAVOLO * CartaIncontro.RAPPORTO
	var x := w
	var aperture := inc.aperture_visibili(_chi_mano()) if _fase in ["inizio", "scegli", "gioca"] else []
	for i in inc.sequenza.size():
		var s: Dictionary = inc.sequenza[i]
		var t := CartaIncontro.new(str(s["img"]), H_TAVOLO)
		t.position = Vector2(x, 0)
		t.tempo = int(s.get("tempo", 0))
		t.cariche = int(s.get("cariche", 0))
		var info := []
		if t.tempo > 0:
			info.append("Gettoni Tempo: %d" % t.tempo)
		if t.cariche > 0:
			info.append("Cariche: %d" % t.cariche)
		t.tooltip_text = Carte.nome(str(s["img"])) + ("\n" + "\n".join(info) if not info.is_empty() else "")
		_fila.add_child(t)
		x += w * CartaIncontro.SCOPERTA
	# semichiavi dell'ultima carta: verde si collega, rosso barrato no
	var ultima: CartaIncontro = _fila.get_child(_fila.get_child_count() - 1)
	for ap in aperture:
		ultima.segni.append({"riga": int(ap["riga"]), "col": "apre", "ok": ap["ok"]})
	ultima.queue_redraw()
	var larghezza := x + w * (1.0 - CartaIncontro.SCOPERTA) if not inc.sequenza.is_empty() else w
	_fila.custom_minimum_size = Vector2(larghezza + 8, H_TAVOLO)
	# si tiene in vista l'ultima carta
	var sb := _scorri_tavolo.get_h_scroll_bar()
	(func(): if is_instance_valid(sb): _scorri_tavolo.scroll_horizontal = int(sb.max_value)).call_deferred()

## Riga della tabella del nemico in vigore (Riserva attuale) o fase attuale della diplomazia.
func _riga_tabella() -> Rect2:
	var ar = inc.carta.get("aree", {}).get("tabella") if inc.carta.get("aree") is Dictionary else null
	if not (ar is Array) or ar.size() < 4:
		return Rect2()
	var righe: Array = inc.carta.get("fasi", []) if inc.diplomazia else inc.carta.get("tabella", [])
	if righe.is_empty():
		return Rect2()
	var idx := -1
	if inc.diplomazia:
		idx = inc.fase
	else:
		for i in righe.size():
			if inc.riserva >= int(righe[i].get("da", 0)) and inc.riserva <= int(righe[i].get("a", 99)):
				idx = i
	if idx < 0 or idx >= righe.size():
		return Rect2()
	var h := (float(ar[3]) - float(ar[1])) / righe.size()
	return Rect2(float(ar[0]), float(ar[1]) + idx * h, float(ar[2]) - float(ar[0]), h)

func _disegna_mano() -> void:
	for x in _mano.get_children():
		x.queue_free()
	var p := _chi_mano()
	if p.is_empty() or _fase in ["fine", "speciale"]:
		return
	var giocabile := _fase == "gioca"
	var carte: Array = inc.mani.get(str(p["id"]), []).duplicate()
	# Un passo avanti: si gioca con la prima carta del mazzo scoperta
	var mz: Array = inc.mazzi.get(str(p["id"]), [])
	if not mz.is_empty() and not inc.partita.modificatori("mazzo_scoperto", p).is_empty():
		carte.append(mz[0])
	var et := Tema.etichetta("MANO DI\n%s" % str(p["nome"]).to_upper(), 15, Tema.ORO)
	et.custom_minimum_size = Vector2(110, 0)
	et.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mano.add_child(et)
	for c in carte:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var t := CartaIncontro.new(c, H_MANO)
		t.selezionata = c == _scelta
		v.add_child(t)
		var cap := Tema.testo_ricco(14)
		cap.custom_minimum_size = Vector2(H_MANO * CartaIncontro.RAPPORTO, 0)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cap)
		var a := inc.anteprima(c)
		# semichiavi della carta che si collegano (verde) o no (rosso barrato) all'ultima del tavolo
		for r in a["righe"]:
			if int(r.get("riga", -1)) < 1:
				continue
			t.segni.append({"riga": int(r["riga"]), "col": "bonus", "ok": r["ok"]})
		if giocabile:
			var ok: bool = a["giocabile"]
			t.modulate = Color.WHITE if ok else Color(0.55, 0.55, 0.55)
			cap.text = _bb(_riassunto_carta(a))
		t.mouse_entered.connect(func():
			_sopra = c
			_aggiorna_info())
		t.mouse_exited.connect(func():
			if _sopra == c:
				_sopra = ""
				_aggiorna_info())
		t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		t.gui_input.connect(func(e):
			var tocco: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
			if not tocco:
				return
			if giocabile and _scelta == c and inc.anteprima(c)["giocabile"]:
				await _gioca(c)
			else:
				_scelta = c
				_aggiorna())
		_mano.add_child(v)

## Pannelli in basso: cosa fa la carta scelta (o sotto il puntatore) e cosa succede terminando;
## stato della Compagnia e tratti del nemico.
func _aggiorna_info() -> void:
	var c := _sopra if _sopra != "" else _scelta
	var t := ""
	match _fase:
		"inizio":
			t = _spiegazione_regole()
			if c != "":
				t = _descrivi_anteprima(c) + "\n\n" + t
		"scegli":
			t = _bb("Quando un Personaggio si attiva gioca [b]una carta qualsiasi[/b] dalla mano; altre carte solo se collegano una [b]Chiave dorata[/b]. Poi il nemico %s.\n%s" % [
				"risponde (Risposta della fase)" if inc.diplomazia else "attacca secondo la riga della sua tabella che corrisponde alla Riserva (riquadrata in rosso sulla carta)", _esito_termina()])
		"gioca":
			if c != "":
				t = _descrivi_anteprima(c)
			else:
				t = _bb("Tocca una carta della mano: qui vedrai quali Chiavi si collegano (riquadri verdi sulle carte; i rossi barrati non si collegano), cosa ottieni e come risponderà il nemico.\n" + _esito_termina())
		"fine":
			t = ""
		"speciale":
			pass
	if _fase != "speciale":
		_anteprima.text = t
	_compagnia.text = _testo_compagnia()

func _testo_compagnia() -> String:
	var t := ""
	if inc.diplomazia:
		t += "Affinità [b]%+d[/b] (vinci la fase a +%d, fallisci a −%d) · Fase %d di %d\n" % [inc.affinita, int(_aff().get("verdi", 3)), int(_aff().get("rossi", 3)), inc.fase + 1, maxi(1, inc.carta.get("fasi", []).size())]
	else:
		t += "Riserva [b]%d[/b] / Valore [b]%d[/b]\n" % [inc.riserva, inc.valore()]
	for tr in inc.tratti():
		t += "[color=%s]%s[/color]\n" % [ORO_T, inc.spiega_tratto(str(tr))]
	if inc.prevenzione > 0:
		t += "Ferite prevenute in questo attacco: %d\n" % inc.prevenzione
	for p in inc.membri:
		var pan := "  [color=%s]PANICO[/color]" % ROSSO_T if Personaggi.in_panico(p) else ""
		var att := "  [color=%s](attivo)[/color]" % VERDE_T if inc.attivo() == p else ""
		t += "[b]%s[/b]%s%s: Salute %d · Energia %d · Terrore %d · Magia %d · mano %d, mazzo %d\n" % [p["nome"], att, pan, int(p["salute"]), int(p["energia"]), int(p["terrore"]), int(p["magia"]),
			inc.mani.get(str(p["id"]), []).size(), inc.mazzi.get(str(p["id"]), []).size()]
	return Dati.testo_bb(t, 16)

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
	_scelta = ""
	_sopra = ""
	await inc.gioca(c)
	_occupato = false
	_aggiorna()

## Obiettivo dell'Incontro in una riga.
func _obiettivo() -> String:
	if inc.diplomazia:
		var a: Dictionary = _aff()
		var fs: Array = inc.carta.get("fasi", [])
		return "Obiettivo: portare l'Affinità a [color=%s]+%d[/color] in ogni fase (%d fasi); a [color=%s]−%d[/color] fallisci." % [VERDE_T, int(a.get("verdi", 3)), maxi(1, fs.size()), ROSSO_T, int(a.get("rossi", 3))]
	return "Obiettivo: [b]%d segnalini[/b] nella Riserva (ora %d). Il nemico attacca secondo la Riserva che hai a fine attivazione." % [inc.valore(), inc.riserva]

## Cosa succede premendo TERMINA ora.
func _esito_termina() -> String:
	if inc.diplomazia:
		var r := inc.attacco_previsto(inc.riserva)
		return "Se termini ora, Risposta: [color=%s]%s[/color]" % [ROSSO_T, str(r.get("testo", "nessuna"))] if not r.is_empty() else ""
	var t := ""
	var min_carte := 2 if inc.ha_tratto("Opportun") else 1
	if inc.carte_attivazione < min_carte:
		t += "Se termini con %s subisci anche l'[b]attacco di opportunità[/b]: [color=%s]%s[/color]. " % ["0 carte" if min_carte == 1 else "meno di 2 carte", ROSSO_T, _spiega_attacco(str(inc.carta.get("opportunita", {}).get("it", "")))]
	if inc.riserva >= inc.valore():
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
		t += "Riserva: %d → [b]%d[/b] / %d" % [inc.riserva, int(a["riserva_dopo"]), inc.valore()]
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
