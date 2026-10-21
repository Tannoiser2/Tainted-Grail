## Menu principale: nuova campagna, campagne salvate, ripresa con codice, Diario libero.
class_name Menu
extends Control

signal inizia
signal diario_libero

var _lista: VBoxContainer
var _stato: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	# sfondo: copertina della campagna con velatura
	var bg := TextureRect.new()
	bg.texture = load("res://assets/app/cover_1.webp")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var vel := ColorRect.new()
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = """shader_type canvas_item;
void fragment(){
	float x = UV.x;
	float a = mix(0.94, 0.15, smoothstep(0.28, 0.95, x));
	vec3 c = mix(vec3(0.07,0.05,0.035), vec3(0.03,0.025,0.02), UV.y);
	float vign = smoothstep(0.35, 1.1, distance(UV, vec2(0.6, 0.45)));
	COLOR = vec4(c, clamp(a + vign * 0.5, 0.0, 1.0));
}"""
	vel.material = sh
	add_child(vel)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 70)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 60)
	m.add_child(h)
	var sx := VBoxContainer.new()
	sx.custom_minimum_size = Vector2(560, 0)
	sx.add_theme_constant_override("separation", 14)
	h.add_child(sx)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(560, 170)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	sx.add_child(logo)
	var sub := Tema.testo_ricco(18)
	sub.text = "[font_size=30][color=#d4ae63]La Caduta di Avalon[/color][/font_size]\n[color=#b9a98a]Campagna in solitario · Diario di Esplorazione italiano completo · tavolo 3D con le miniature · salvataggi online[/color]"
	sx.add_child(sub)
	sx.add_child(Tema.fregio(520))
	sx.add_child(_spazio(16))
	sx.add_child(_largo(Tema.pulsante_primario("NUOVA CAMPAGNA", _nuova, 20)))
	sx.add_child(_largo(Tema.pulsante("RIPRENDI CON UN CODICE", _codice, 18)))
	sx.add_child(_largo(Tema.pulsante("DIARIO LIBERO (SOLO PARAGRAFI)", func(): diario_libero.emit(), 18)))
	if not OS.has_feature("web"):
		sx.add_child(_largo(Tema.pulsante("ESCI", func(): get_tree().quit(), 18)))
	_stato = Label.new()
	_stato.add_theme_color_override("font_color", Tema.ORO)
	_stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sx.add_child(_stato)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sx.add_child(fill)
	var cr := Label.new()
	cr.text = "Tainted Grail © Awaken Realms. Adattamento per uso personale; testi dall'app ufficiale Tainted Grail Companion,\ncomponenti e miniature dal modulo Tabletop Simulator. Font Cinzel e Alegreya (SIL OFL)."
	cr.add_theme_font_size_override("font_size", 12)
	cr.add_theme_color_override("font_color", Color(0.62, 0.56, 0.46))
	sx.add_child(cr)
	# campagne salvate
	var dx := PanelContainer.new()
	dx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dx.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dx.custom_minimum_size = Vector2(0, 300)
	h.add_child(dx)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	dx.add_child(dv)
	dv.add_child(Tema.etichetta("CAMPAGNE SALVATE SU QUESTO DISPOSITIVO", 16, Tema.ORO))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	dv.add_child(_lista)
	_aggiorna_lista()

func _spazio(hh: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, hh)
	return c

func _largo(b: Button) -> Button:
	b.custom_minimum_size = Vector2(420, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

func _aggiorna_lista() -> void:
	for c in _lista.get_children():
		c.queue_free()
	var el := Campagna.elenco_locale()
	if el.is_empty():
		var l := Label.new()
		l.text = "Nessuna campagna salvata. Inizia una nuova campagna, oppure riprendine una con il suo codice."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.TESTO_2)
		_lista.add_child(l)
		return
	for x in el:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var b := Tema.pulsante("", func():
			if Campagna.carica_locale(x["codice"]):
				inizia.emit(), 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var data := Time.get_datetime_string_from_unix_time(int(x["aggiornata"]) + _fuso(), true).substr(0, 16)
		b.text = "%s   ·   %s   ·   giorno %d   ·   %s   ·   %s" % [x["nome"], x["personaggi"], x["giorno"], x["codice"], data]
		r.add_child(b)
		var d := Tema.pulsante("✕", func():
			_conferma("Eliminare la copia locale di \"%s\"? (La copia online resta: si riprende con il codice %s.)" % [x["nome"], x["codice"]], func():
				Campagna.elimina_locale(x["codice"])
				_aggiorna_lista()), 14)
		d.tooltip_text = "Elimina dal dispositivo"
		r.add_child(d)
		_lista.add_child(r)

func _fuso() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func _conferma(t: String, cb: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = t
	d.ok_button_text = "Sì"
	d.cancel_button_text = "No"
	d.confirmed.connect(cb)
	add_child(d)
	d.popup_centered(Vector2i(640, 0))

func _nuova() -> void:
	var p := NuovaCampagna.new()
	p.confermata.connect(func(camp, nome, personaggi, opzioni):
		Campagna.nuova(camp, nome, personaggi, opzioni)
		inizia.emit())
	add_child(p)

func _codice() -> void:
	var d := AcceptDialog.new()
	d.title = "Riprendi con un codice"
	d.ok_button_text = "Riprendi"
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "Codice della campagna (6 caratteri, lo trovi in alto durante la partita):"
	v.add_child(l)
	var e := LineEdit.new()
	e.max_length = 6
	e.placeholder_text = "ABC123"
	v.add_child(e)
	d.add_child(v)
	d.confirmed.connect(func():
		var c := e.text.strip_edges().to_upper()
		if c.length() != 6:
			_stato.text = "Il codice ha 6 caratteri."
			return
		_stato.text = "Cerco la campagna %s online…" % c
		var ok: bool = await Campagna.carica_online(c)
		if ok:
			inizia.emit()
		elif Campagna.carica_locale(c):
			inizia.emit()
		else:
			_stato.text = "Campagna %s non trovata (%s)." % [c, Net.ultimo_errore if Net.ultimo_errore != "" else "codice inesistente"])
	add_child(d)
	d.popup_centered(Vector2i(520, 0))
	e.grab_focus()

