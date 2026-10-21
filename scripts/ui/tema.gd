## Tema grafico fantasy celtico: pergamena scura, oro antico, verde muschio e rosso sangue,
## come le carte di Tainted Grail.
## Font: Cinzel per i titoli (simile alle intestazioni delle carte), Alegreya per il testo
## (lo stesso usato dall'app ufficiale). Entrambi SIL Open Font License.
extends Node

const FONDO := Color("120d0a")
const PANNELLO := Color(0.09, 0.066, 0.05, 0.94)
const PANNELLO_2 := Color(0.14, 0.105, 0.075, 0.97)
const PERGAMENA := Color("e8dcc0")
const BORDO := Color("6b5232")
const ORO := Color("d4ae63")
const ORO_SCURO := Color("8a6a36")
const VERDE := Color("7fb069")
const VERDE_SCURO := Color("2f4a2a")
const ROSSO := Color("c0473a")
const VIOLA := Color("a184d0")
const AZZURRO := Color("7fb5d9")
const TESTO := Color("ece2cc")
const TESTO_2 := Color("b9a98a")
## colore delle risorse nel testo ({r:Ricchezza}), come sulle carte
const RISORSA := Color("e59a4a")

var titolo: FontVariation
var titolo_forte: FontVariation
var decorativo: FontFile
var testo: FontFile
var testo_corsivo: FontFile
var testo_grassetto: FontFile
var testo_grassetto_corsivo: FontFile
var tema: Theme

func _ready() -> void:
	testo = _f("Alegreya-Regular.ttf")
	testo_corsivo = _f("Alegreya-Italic.ttf")
	testo_grassetto = _f("Alegreya-Bold.ttf")
	testo_grassetto_corsivo = _f("Alegreya-BoldItalic.ttf")
	var cz := _f("cinzel-latin-700-normal.woff2", [_f("cinzel-latin-ext-700-normal.woff2"), testo_grassetto])
	titolo = FontVariation.new()
	titolo.base_font = cz
	titolo.spacing_glyph = 1
	var cz8 := _f("cinzel-latin-800-normal.woff2", [testo_grassetto])
	titolo_forte = FontVariation.new()
	titolo_forte.base_font = cz8
	titolo_forte.spacing_glyph = 2
	decorativo = _f("cinzel-decorative-latin-700-normal.woff2", [cz])
	tema = _crea_tema()

func _f(nome: String, fallback: Array = []) -> FontFile:
	var f: FontFile = load("res://assets/font/" + nome)
	if f == null:
		return ThemeDB.fallback_font as FontFile
	f = f.duplicate()
	f.fallbacks = fallback
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	return f

func box(fondo: Color, bordo: Color = BORDO, spessore := 1, raggio := 4, margine := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = margine
	s.content_margin_right = margine
	s.content_margin_top = margine * 0.6
	s.content_margin_bottom = margine * 0.6
	s.anti_aliasing = true
	return s

## Pannello "di cuoio": bordo dorato doppio, ombra morbida.
func box_pannello(fondo: Color = PANNELLO, bordo: Color = BORDO) -> StyleBoxFlat:
	var s := box(fondo, bordo, 2, 6, 16)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 10
	s.expand_margin_left = 0
	return s

func _crea_tema() -> Theme:
	var t := Theme.new()
	t.default_font = testo
	t.default_font_size = 21
	# pulsanti: placche di cuoio con bordo dorato
	var n := box(Color(0.17, 0.12, 0.08, 0.96), ORO_SCURO, 1, 4, 14)
	var h := box(Color(0.25, 0.18, 0.11, 1), ORO, 1, 4, 14)
	var p := box(Color(0.33, 0.24, 0.13, 1), ORO, 2, 4, 14)
	var d := box(Color(0.1, 0.08, 0.06, 0.8), Color(0.28, 0.24, 0.2), 1, 4, 14)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = {"normal": n, "hover": h, "pressed": p, "disabled": d, "focus": h}[k]
		t.set_stylebox(k, "Button", sb)
		t.set_stylebox(k, "OptionButton", sb)
		t.set_stylebox(k, "MenuButton", sb)
	t.set_font("font", "Button", titolo)
	t.set_font_size("font_size", "Button", 17)
	t.set_color("font_color", "Button", TESTO)
	t.set_color("font_hover_color", "Button", Color("fff4d6"))
	t.set_color("font_pressed_color", "Button", ORO)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.4))
	t.set_font("font", "OptionButton", testo_grassetto)
	t.set_color("font_color", "Label", TESTO)
	t.set_color("default_color", "RichTextLabel", TESTO)
	t.set_font("normal_font", "RichTextLabel", testo)
	t.set_font("italics_font", "RichTextLabel", testo_corsivo)
	t.set_font("bold_font", "RichTextLabel", testo_grassetto)
	t.set_font("bold_italics_font", "RichTextLabel", testo_grassetto_corsivo)
	t.set_font("mono_font", "RichTextLabel", testo)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size", "mono_font_size"]:
		t.set_font_size(k, "RichTextLabel", 21)
	t.set_stylebox("panel", "PanelContainer", box_pannello())
	t.set_stylebox("panel", "Panel", box_pannello())
	t.set_stylebox("panel", "PopupPanel", box_pannello(PANNELLO_2, ORO_SCURO))
	t.set_stylebox("panel", "PopupMenu", box(PANNELLO_2, ORO_SCURO, 1, 4, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.3, 0.22, 0.12), ORO, 0, 2, 8))
	t.set_font("font", "PopupMenu", testo)
	t.set_font_size("font_size", "PopupMenu", 19)
	t.set_stylebox("panel", "AcceptDialog", box_pannello(PANNELLO_2, ORO_SCURO))
	t.set_stylebox("embedded_border", "Window", box_pannello(PANNELLO_2, ORO_SCURO))
	t.set_font("title_font", "Window", titolo)
	var le := box(Color(0.06, 0.045, 0.035, 1), ORO_SCURO, 1, 3, 10)
	var lef := box(Color(0.08, 0.06, 0.045, 1), ORO, 1, 3, 10)
	for c in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", c, le)
		t.set_stylebox("focus", c, lef)
		t.set_font("font", c, testo)
		t.set_font_size("font_size", c, 21)
	t.set_color("caret_color", "LineEdit", ORO)
	t.set_color("selection_color", "LineEdit", Color(0.6, 0.45, 0.2, 0.5))
	var g := box(Color(0.55, 0.42, 0.22, 0.6), Color(0, 0, 0, 0), 0, 3, 0)
	var gh := box(ORO, Color(0, 0, 0, 0), 0, 3, 0)
	var sc := box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 3, 0)
	sc.content_margin_left = 4
	sc.content_margin_right = 4
	for c in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", c, g)
		t.set_stylebox("grabber_highlight", c, gh)
		t.set_stylebox("grabber_pressed", c, gh)
		t.set_stylebox("scroll", c, sc)
	t.set_stylebox("panel", "TooltipPanel", box(PANNELLO_2, ORO_SCURO, 1, 3, 8))
	t.set_font("font", "TooltipLabel", testo)
	t.set_font_size("font_size", "TooltipLabel", 18)
	t.set_color("font_color", "TooltipLabel", TESTO)
	t.set_stylebox("panel", "TabContainer", box(PANNELLO, BORDO, 1, 0, 8))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.25, 0.18, 0.1), ORO, 1, 0, 12))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.1, 0.075, 0.055), ORO_SCURO, 1, 0, 12))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.18, 0.13, 0.08), ORO, 1, 0, 12))
	t.set_font("font", "TabContainer", titolo)
	t.set_font_size("font_size", "TabContainer", 15)
	t.set_stylebox("separator", "HSeparator", box(ORO_SCURO, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 8)
	var chk := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
	for k in ["normal", "hover", "pressed"]:
		t.set_stylebox(k, "CheckBox", chk)
	t.set_font("font", "CheckBox", testo)
	t.set_font_size("font_size", "CheckBox", 19)
	return t

## Etichetta con il font dei titoli.
func etichetta(testo_: String, dim := 18, colore := ORO, forte := false) -> Label:
	var l := Label.new()
	l.text = testo_
	l.add_theme_font_override("font", titolo_forte if forte else titolo)
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", colore)
	return l

func pulsante(testo_: String, cb: Callable = Callable(), dim := 17) -> Button:
	var b := Button.new()
	b.text = testo_
	b.add_theme_font_size_override("font_size", dim)
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Pulsante in evidenza (azione principale): rosso sangue con bordo d'oro.
func pulsante_primario(testo_: String, cb: Callable = Callable(), dim := 19) -> Button:
	var b := pulsante(testo_, cb, dim)
	b.add_theme_stylebox_override("normal", box(Color(0.42, 0.11, 0.08, 0.96), ORO, 1, 4, 18))
	b.add_theme_stylebox_override("hover", box(Color(0.56, 0.16, 0.1, 1), Color("ffd98a"), 1, 4, 18))
	b.add_theme_stylebox_override("pressed", box(Color(0.68, 0.2, 0.12, 1), Color.WHITE, 2, 4, 18))
	return b

## Pulsante di scelta del Diario (verde muschio, come le opzioni dell'app).
func pulsante_scelta(testo_: String, cb: Callable = Callable(), dim := 19) -> Button:
	var b := pulsante(testo_, cb, dim)
	b.add_theme_font_override("font", testo_grassetto)
	b.add_theme_stylebox_override("normal", box(Color(0.14, 0.2, 0.12, 0.95), Color("5d7f4b"), 1, 4, 14))
	b.add_theme_stylebox_override("hover", box(Color(0.2, 0.3, 0.16, 1), VERDE, 1, 4, 14))
	b.add_theme_stylebox_override("pressed", box(Color(0.26, 0.38, 0.2, 1), Color.WHITE, 2, 4, 14))
	return b

func testo_ricco(dim := 21) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = false
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, dim)
	r.add_theme_constant_override("line_separation", 4)
	return r

## Separatore ornamentale: linea dorata con un rombo al centro.
func fregio(larghezza := 260) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(larghezza, 18)
	c.draw.connect(func():
		var w := c.size.x
		var y := c.size.y / 2
		c.draw_line(Vector2(0, y), Vector2(w / 2 - 12, y), ORO_SCURO, 1.5, true)
		c.draw_line(Vector2(w / 2 + 12, y), Vector2(w, y), ORO_SCURO, 1.5, true)
		var p := PackedVector2Array([Vector2(w / 2, y - 6), Vector2(w / 2 + 7, y), Vector2(w / 2, y + 6), Vector2(w / 2 - 7, y)])
		c.draw_colored_polygon(p, ORO))
	return c
