## Pannello del Diario di Esplorazione: mostra il verso corrente come un libro (illustrazione del
## Luogo, testo, condizioni verificate e scelte), come l'app ufficiale ma collegato alla partita.
## Con una Partita le condizioni si verificano da sole e i risultati si applicano con Effetti.
class_name PannelloDiario
extends PanelContainer

signal fine_esplorazione(risultato: String)
signal chiudi
## emesso dopo ogni passo (per salvare e aggiornare il tavolo)
signal avanzato

var motore: MotoreDiario
var partita  # Partita o null
var _testa: TextureRect
var _titolo: Label
var _sotto: Label
var _corpo: VBoxContainer
var _scorri: ScrollContainer
var _esito_box: VBoxContainer
var _barra: HBoxContainer
var domande: Domande          # scelte del giocatore durante gli effetti automatici
var _occupato := false

func _init(motore_: MotoreDiario, partita_ = null) -> void:
	motore = motore_
	partita = partita_

func _ready() -> void:
	theme = Tema.tema
	add_theme_stylebox_override("panel", Tema.box_pannello(Color(0.075, 0.055, 0.04, 0.97), Tema.ORO_SCURO))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	# intestazione: illustrazione del Luogo con nome sovrapposto
	var testa := Control.new()
	testa.custom_minimum_size = Vector2(0, 170)
	testa.clip_contents = true
	v.add_child(testa)
	_testa = TextureRect.new()
	_testa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_testa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_testa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_testa.modulate = Color(0.85, 0.82, 0.78)
	testa.add_child(_testa)
	var vel := ColorRect.new()
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = "shader_type canvas_item;\nvoid fragment(){ COLOR = vec4(0.05,0.035,0.025, smoothstep(0.15, 1.0, UV.y) * 0.92); }"
	vel.material = sh
	testa.add_child(vel)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tv.offset_top = -78
	tv.offset_left = 18
	tv.offset_right = -18
	tv.add_theme_constant_override("separation", 0)
	testa.add_child(tv)
	_sotto = Tema.etichetta("", 15, Tema.TESTO_2)
	tv.add_child(_sotto)
	_titolo = Tema.etichetta("", 30, Tema.ORO, true)
	_titolo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_titolo.add_theme_constant_override("shadow_offset_x", 2)
	_titolo.add_theme_constant_override("shadow_offset_y", 2)
	tv.add_child(_titolo)
	_scorri = ScrollContainer.new()
	_scorri.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scorri)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.add_theme_constant_override("separation", 10)
	_scorri.add_child(_corpo)
	_barra = HBoxContainer.new()
	_barra.add_theme_constant_override("separation", 8)
	v.add_child(_barra)
	_barra.add_child(Tema.pulsante("◂ INDIETRO", func():
		if motore.indietro():
			aggiorna()
			avanzato.emit(), 15))
	var f := Control.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_barra.add_child(f)
	_barra.add_child(Tema.pulsante("CHIUDI IL DIARIO", func(): chiudi.emit(), 15))
	aggiorna()

func aggiorna() -> void:
	for c in _corpo.get_children():
		c.queue_free()
	_esito_box = null
	if not motore.aperto():
		_titolo.text = "Diario di Esplorazione"
		_sotto.text = ""
		return
	var l := motore.luogo()
	var n := int(l.get("n", 0))
	_titolo.text = Dati.testo_piano(str(l.get("nome", "")))
	var vd := int(motore.verso().get("d", 0))
	_sotto.text = ("LIBRO DEI SEGRETI · VERSO %d" % vd) if n == 999 else ("LUOGO %d%s" % [n, ("  ·  VERSO %d" % vd) if vd > 0 else ""])
	_testa.texture = null
	if n != 999:
		Immagini.carica(Dati.illustrazione(motore.camp, motore.id_luogo()), func(t):
			if is_instance_valid(_testa):
				_testa.texture = t)
	for t in motore.testi():
		var r := Tema.testo_ricco(22)
		r.text = Dati.testo_bb(_paragrafi(t), 24)
		_corpo.add_child(r)
	var tiro := motore.tiro_richiesto()
	if motore.ha_fasce():
		_corpo.add_child(_riga_tiro(tiro))
	var ops := motore.opzioni()
	var condizioni := ops.filter(func(o): return o["tipo"] == 1)
	var scelte := ops.filter(func(o): return o["tipo"] != 1)
	# come nell'app: prima le condizioni da verificare, poi le azioni a scelta
	var una_valida := false
	if not condizioni.is_empty():
		_corpo.add_child(Tema.fregio(400))
		if not scelte.is_empty():
			_corpo.add_child(Tema.etichetta("VERIFICA PRIMA DI SCEGLIERE", 15, Tema.TESTO_2))
		for o in condizioni:
			var ok = o["valida"]
			if o["testo"].to_lower().begins_with("altrimenti") and ok == null:
				ok = not una_valida
			if ok == true:
				una_valida = true
			_corpo.add_child(_voce(o, ok, true))
	if not scelte.is_empty():
		_corpo.add_child(Tema.fregio(400))
		_corpo.add_child(Tema.etichetta("SCEGLI L'AZIONE", 15, Tema.TESTO_2))
		for o in scelte:
			_corpo.add_child(_voce(o, null, false))
	await get_tree().process_frame
	if is_instance_valid(_scorri):
		_scorri.scroll_vertical = 0

func _paragrafi(t: String) -> String:
	return t.replace("\n", "\n")

## Riga per tirare il dado quando le opzioni sono fasce di risultato.
func _riga_tiro(tiro: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var b := Tema.pulsante_primario("🎲 TIRA IL DADO", func():
		var mod := motore.modificatore_tiro()
		var v := randi_range(1, 6)
		motore.imposta_tiro(v + int(mod["valore"]))
		var s := "Dado: %d" % v
		if int(mod["valore"]) != 0:
			s += " %+d (%s) = %d" % [int(mod["valore"]), mod["testo"], v + int(mod["valore"])]
		if partita:
			partita.racconta("Tiro di dado al Luogo %d: %s" % [int(motore.luogo().get("n", 0)), s])
		aggiorna()
		avanzato.emit(), 17)
	h.add_child(b)
	var l := Label.new()
	if tiro.has("valore"):
		l.text = "Risultato: %d" % int(tiro["valore"])
		l.add_theme_font_override("font", Tema.titolo)
		l.add_theme_color_override("font_color", Tema.ORO)
	else:
		var mod := motore.modificatore_tiro()
		l.text = ("Modificatore: %+d (%s)" % [int(mod["valore"]), mod["testo"]]) if int(mod["valore"]) != 0 else "Tira e confronta il risultato con le fasce."
		l.add_theme_color_override("font_color", Tema.TESTO_2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	return h

## Una condizione o una scelta, con i suoi esiti.
func _voce(o: Dictionary, ok, condizione: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var testo := Dati.testo_bb(str(o["testo"]), 22)
	for es in o["esiti"]:
		var q := str(es.get("q", ""))
		var valida = es.get("valida")
		var etichetta := testo
		if q != "":
			etichetta += "\n[color=#b9a98a][i]" + Dati.testo_bb(q, 20) + "[/i][/color]"
		var stato = ok if condizione else valida
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 8)
		var segno := Label.new()
		segno.custom_minimum_size = Vector2(28, 0)
		segno.add_theme_font_size_override("font_size", 22)
		if stato == true:
			segno.text = "✔"
			segno.add_theme_color_override("font_color", Tema.VERDE)
			segno.tooltip_text = "Condizione soddisfatta"
		elif stato == false:
			segno.text = "✘"
			segno.add_theme_color_override("font_color", Tema.ROSSO)
			segno.tooltip_text = "Condizione non soddisfatta (puoi comunque sceglierla se lo stato non è aggiornato)"
		else:
			segno.text = "•" if not condizione else "?"
			segno.add_theme_color_override("font_color", Tema.TESTO_2)
			if condizione:
				segno.tooltip_text = "Da verificare sul tavolo"
		riga.add_child(segno)
		# scelta: riquadro cliccabile con testo ricco (icone e grassetti come nell'app)
		var b := PanelContainer.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var verde: bool = stato == true and condizione
		var sn := Tema.box(Color(0.2, 0.3, 0.14, 1) if verde else Color(0.14, 0.2, 0.12, 0.95), Tema.VERDE if verde else Color("5d7f4b"), 2 if verde else 1, 4, 14)
		var sh := Tema.box(Color(0.22, 0.32, 0.17, 1), Tema.VERDE, 1, 4, 14)
		b.add_theme_stylebox_override("panel", sn)
		b.mouse_entered.connect(func(): b.add_theme_stylebox_override("panel", sh))
		b.mouse_exited.connect(func(): b.add_theme_stylebox_override("panel", sn))
		b.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_scegli(es))
		var r := Tema.testo_ricco(20)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.text = etichetta
		b.add_child(r)
		if stato == false:
			b.modulate = Color(1, 1, 1, 0.55)
		riga.add_child(b)
		v.add_child(riga)
		testo = ""  # più esiti della stessa voce: il testo una volta sola
	return v

func _scegli(es: Dictionary) -> void:
	if _occupato:
		return
	_occupato = true
	var q := str(es.get("q", ""))
	var applicati := []
	var salto: Array = []
	# requisiti e costi ("Pagare 2 Ricchezza") prima di seguire la scelta
	if partita and q != "":
		var aq := Dati.auto_diario("q:", q)
		if not aq.is_empty():
			var itq := Interprete.new(partita, null, domande, motore.contesto())
			if aq.get("costo") is Array and not aq["costo"].is_empty():
				if not await itq.esegui(aq["costo"]):
					_occupato = false
					_mostra_risultato("[color=#e05a4a]Non potete pagare il costo di questa scelta.[/color]", itq.rapporto)
					return
			if aq.get("effetti") is Array:
				await itq.esegui(aq["effetti"])
			applicati.append_array(itq.rapporto)
			if itq.ctx.has("salto_diario"):
				salto = itq.ctx["salto_diario"]
		else:
			Effetti.paga_costo(q, partita)
	var res := motore.segui(es)
	var r := str(res["risultato"])
	if partita and r != "":
		var ar := Dati.auto_diario("r:", r)
		if ar.get("effetti") is Array:
			var it := Interprete.new(partita, null, domande, motore.contesto())
			await it.esegui(ar["effetti"])
			applicati.append_array(it.rapporto)
			if it.ctx.has("esito_incontro"):
				motore.stato["esito_incontro"] = it.ctx["esito_incontro"]
			if it.ctx.has("salto_diario"):
				salto = it.ctx["salto_diario"]
		else:
			applicati.append_array(Effetti.applica(r, partita))
	_occupato = false
	avanzato.emit()
	if not salto.is_empty() and motore.apri_numero(int(salto[0]), int(salto[1])):
		aggiorna()
		_mostra_risultato(r, applicati)
		return
	if res["fine"]:
		_mostra_fine(r, applicati)
	else:
		aggiorna()
		if r != "":
			_mostra_risultato(r, applicati)

func _riquadro_risultato(r: String, applicati: Array) -> VBoxContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Tema.box(Color(0.16, 0.12, 0.07, 0.95), Tema.ORO, 1, 4, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var t := Tema.testo_ricco(21)
	t.text = Dati.testo_bb(r, 22)
	v.add_child(t)
	if not applicati.is_empty():
		var a := Tema.testo_ricco(17)
		var righe := []
		for x in applicati:
			righe.append(("[color=#7fb069]✔ %s[/color]" % x["testo"]) if x.get("fatto", false) else ("[color=#e59a4a]☐ %s[/color]" % x["testo"]))
		a.text = "\n".join(righe)
		v.add_child(a)
	var w := VBoxContainer.new()
	w.add_child(box)
	return w

func _mostra_risultato(r: String, applicati: Array) -> void:
	var w := _riquadro_risultato(r, applicati)
	_corpo.add_child(w)
	_corpo.move_child(w, 0)

func _mostra_fine(r: String, applicati: Array) -> void:
	for c in _corpo.get_children():
		c.queue_free()
	if r != "":
		_corpo.add_child(_riquadro_risultato(r, applicati))
	_corpo.add_child(Tema.etichetta("L'ESPLORAZIONE TERMINA", 22, Tema.ORO, true))
	var b := Tema.pulsante_primario("CONTINUA", func():
		motore.chiudi()
		fine_esplorazione.emit(r), 18)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_corpo.add_child(b)
