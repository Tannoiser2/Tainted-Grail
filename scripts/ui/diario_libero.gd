## Il Diario di Esplorazione usato come l'app ufficiale: si digita il numero del Luogo (o di un
## Segreto) e si legge, senza partita. Utile per giocare con la scatola sul tavolo.
class_name DiarioLibero
extends Control

signal esci

var _motore: MotoreDiario
var _pannello: PannelloDiario
var _numero: LineEdit
var _stato := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema
	var bg := TextureRect.new()
	bg.texture = load("res://assets/app/cover_1.webp")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.35, 0.3, 0.27)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 40)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	m.add_child(h)
	var sx := VBoxContainer.new()
	sx.custom_minimum_size = Vector2(420, 0)
	sx.add_theme_constant_override("separation", 12)
	h.add_child(sx)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(420, 115)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	sx.add_child(logo)
	sx.add_child(Tema.etichetta("NUMERO DEL LUOGO", 18))
	_numero = LineEdit.new()
	_numero.placeholder_text = "101"
	_numero.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_numero.add_theme_font_override("font", Tema.titolo_forte)
	_numero.add_theme_font_size_override("font_size", 44)
	_numero.text_submitted.connect(func(_t): _apri())
	sx.add_child(_numero)
	var tast := GridContainer.new()
	tast.columns = 3
	tast.add_theme_constant_override("h_separation", 8)
	tast.add_theme_constant_override("v_separation", 8)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]:
		var b := Tema.pulsante(k, func():
			if k == "⌫":
				_numero.text = _numero.text.substr(0, maxi(0, _numero.text.length() - 1))
			elif k == "OK":
				_apri()
			else:
				_numero.text += k, 24)
		b.custom_minimum_size = Vector2(130, 64)
		tast.add_child(b)
	sx.add_child(tast)
	sx.add_child(Tema.pulsante("LIBRO DEI SEGRETI (verso)", func(): _apri(true)))
	var aiuti := Tema.pulsante("AIUTI PER CAPITOLO", _aiuti)
	sx.add_child(aiuti)
	var f := Control.new()
	f.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sx.add_child(f)
	sx.add_child(Tema.pulsante("◂ MENU PRINCIPALE", func(): esci.emit()))
	_motore = MotoreDiario.new(1, _stato, null)
	_pannello = PannelloDiario.new(_motore, null)
	_pannello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pannello.chiudi.connect(func(): _motore.chiudi(); _pannello.aggiorna())
	_pannello.fine_esplorazione.connect(func(_r): _pannello.aggiorna())
	h.add_child(_pannello)

func _apri(segreto := false) -> void:
	var n := int(_numero.text)
	var ok := _motore.apri_segreto(n) if segreto else _motore.apri_numero(n)
	if not ok:
		_numero.text = ""
		_numero.placeholder_text = "non esiste"
		return
	_pannello.aggiorna()
	_numero.text = ""

func _aiuti() -> void:
	var d := AcceptDialog.new()
	d.title = "Aiuti per La Caduta di Avalon"
	d.ok_button_text = "Chiudi"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 640)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for a in Dati.diario(1).get("aiuti", []):
		v.add_child(Tema.etichetta(Dati.testo_piano(str(a["titolo"])), 20))
		var r := Tema.testo_ricco(19)
		r.text = Dati.testo_bb(str(a["testo"]))
		r.custom_minimum_size = Vector2(860, 0)
		v.add_child(r)
	d.add_child(sc)
	add_child(d)
	d.popup_centered()
