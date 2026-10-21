## Finestra per iniziare una nuova campagna: nome e scelta dei Personaggi (1-4).
class_name NuovaCampagna
extends Control

signal confermata(camp: int, nome: String, personaggi: Array, opzioni: Dictionary)

var _scelti: Array = []
var _nome: LineEdit
var _carte := {}
var _ok: Button
var _modo: OptionButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.75)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(1500, 0)
	p.position = Vector2(-750, -400)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(Tema.etichetta("NUOVA CAMPAGNA · LA CADUTA DI AVALON", 28, Tema.ORO, true))
	v.add_child(Tema.fregio(600))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = "Nome della campagna:"
	h.add_child(l)
	_nome = LineEdit.new()
	_nome.text = "Avalon " + Time.get_date_string_from_system()
	_nome.custom_minimum_size = Vector2(420, 0)
	h.add_child(_nome)
	var l2 := Label.new()
	l2.text = "   Modalità:"
	h.add_child(l2)
	_modo = OptionButton.new()
	_modo.add_item("Standard")
	_modo.add_item("Storia (più facile)")
	h.add_child(_modo)
	v.add_child(h)
	var info := Label.new()
	info.text = "Scegli da 1 a 4 Personaggi (in solitario se ne possono guidare anche due insieme). Clic sulla tessera per sceglierla."
	info.add_theme_color_override("font_color", Tema.TESTO_2)
	v.add_child(info)
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 16)
	v.add_child(g)
	for id in Personaggi.ORDINE:
		g.add_child(_tessera(id))
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", 12)
	b.alignment = BoxContainer.ALIGNMENT_END
	b.add_child(Tema.pulsante("ANNULLA", func(): queue_free()))
	_ok = Tema.pulsante_primario("INIZIA LA CAMPAGNA", _conferma)
	_ok.disabled = true
	b.add_child(_ok)
	v.add_child(b)

func _tessera(id: String) -> Control:
	var dd := Personaggi.dati(id)
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(350, 0)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(330, 254)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Immagini.carica(str(dd["tessera"]), func(tx): if is_instance_valid(t): t.texture = tx)
	v.add_child(t)
	var n := Tema.etichetta(str(dd["nome"]).to_upper(), 22, dd["colore"], true)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var r := Tema.testo_ricco(17)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var att := []
	for k in ["aggression", "empathy", "courage", "caution", "practicality", "spirituality"]:
		if int(dd["attributi"][k]) > 0:
			att.append("%s %d" % [Partita.NOMI_ATTRIBUTI[k], int(dd["attributi"][k])])
	var ris := []
	for k in dd["risorse"]:
		ris.append("%d %s" % [int(dd["risorse"][k]), Partita.NOMI_RISORSE[k]])
	r.text = Dati.testo_bb("Salute %d · Energia %d\n%s\n%s\n\n[b]%s[/b] (%d {i:energy}): %s\n[b]%s:[/b] %s" % [
		int(dd["salute"]), int(dd["energia"]), ", ".join(att), ", ".join(ris),
		dd["azione"]["nome"], int(dd["azione"]["costo"]), dd["azione"]["testo"], dd["tratto"]["nome"], dd["tratto"]["testo"]], 18)
	v.add_child(r)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _scelti.has(id):
				_scelti.erase(id)
			elif _scelti.size() < 4:
				_scelti.append(id)
			_aggiorna())
	_carte[id] = c
	return c

func _aggiorna() -> void:
	for id in _carte:
		var sel := _scelti.has(id)
		_carte[id].add_theme_stylebox_override("panel", Tema.box_pannello(Color(0.2, 0.15, 0.08, 0.97) if sel else Tema.PANNELLO, Tema.ORO if sel else Tema.BORDO))
	_ok.disabled = _scelti.is_empty()

func _conferma() -> void:
	confermata.emit(1, _nome.text.strip_edges(), _scelti.duplicate(), {"modo": "storia" if _modo.selected == 1 else "standard"})
	queue_free()
