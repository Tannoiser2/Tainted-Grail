## Domande al giocatore durante l'esecuzione automatica degli effetti (Interprete): scelte fra
## opzioni, a quale Personaggio dare qualcosa, Incontri da risolvere. Ogni metodo si usa con await.
## Le finestre stanno su un CanvasLayer alto, sopra il tavolo, il Diario e gli Incontri.
class_name Domande
extends Node

signal _risposta(i: int)

## Callable(colore, nome, livello) -> esito (coroutine), fornita dal Gioco.
var incontro: Callable
## Callable(luogo, verso), fornita dal Gioco.
var diario: Callable
## Callable(img), fornita dal Gioco.
var evento: Callable

var _strato: CanvasLayer

func _ready() -> void:
	_strato = CanvasLayer.new()
	_strato.layer = 60
	add_child(_strato)

## Mostra una domanda con pulsanti; restituisce l'indice scelto.
func scegli(titolo: String, opzioni: Array) -> int:
	if opzioni.size() <= 1:
		return 0
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.6)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	vel.theme = Tema.tema
	_strato.add_child(vel)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.box_pannello(Color(0.08, 0.06, 0.045, 0.98), Tema.ORO))
	p.custom_minimum_size = Vector2(640, 0)
	vel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_testo("[b]" + Dati.testo_bb(titolo, 22) + "[/b]", 21, 600))
	v.add_child(Tema.fregio(400))
	for i in opzioni.size():
		var b := Tema.pulsante(Dati.testo_leggibile(str(opzioni[i])), func(): _risposta.emit(i), 17)
		b.custom_minimum_size = Vector2(600, 44)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = Dati.testo_leggibile(str(opzioni[i]))
		v.add_child(b)
	var centra := func():
		p.reset_size()
		p.position = ((vel.size - p.size) / 2).max(Vector2.ZERO)
	p.resized.connect(func(): p.position = ((vel.size - p.size) / 2).max(Vector2.ZERO))
	vel.resized.connect(centra)
	v.minimum_size_changed.connect(func(): centra.call_deferred())
	centra.call_deferred()
	var r: int = await _risposta
	vel.queue_free()
	return r

func scegli_personaggio(titolo: String, lista: Array) -> Dictionary:
	if lista.size() == 1:
		return lista[0]
	var i := await scegli(titolo, lista.map(func(x): return str(x["nome"])))
	return lista[i]

func risolvi_incontro(colore: String, nome: String, livello: int) -> String:
	if incontro.is_valid():
		return await incontro.call(colore, nome, livello)
	return "vittoria"

func apri_diario(luogo: int, verso: int) -> void:
	if diario.is_valid():
		diario.call(luogo, verso)

func mostra_evento(img: String) -> void:
	if evento.is_valid():
		evento.call(img)

## Messaggio con un solo pulsante (attende la chiusura).
func avvisa(titolo: String, testo: String) -> void:
	await _avviso(titolo, testo)

func _avviso(titolo: String, testo: String) -> void:
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.6)
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	vel.theme = Tema.tema
	_strato.add_child(vel)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.box_pannello(Color(0.08, 0.06, 0.045, 0.98), Tema.ORO))
	p.custom_minimum_size = Vector2(700, 0)
	vel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Tema.etichetta(titolo.to_upper(), 21, Tema.ORO, true))
	v.add_child(_testo(Dati.testo_bb(testo, 20), 19, 660))
	v.add_child(Tema.pulsante_primario("CONTINUA", func(): _risposta.emit(0), 17))
	var centra := func():
		p.reset_size()
		p.position = ((vel.size - p.size) / 2).max(Vector2.ZERO)
	p.resized.connect(func(): p.position = ((vel.size - p.size) / 2).max(Vector2.ZERO))
	vel.resized.connect(centra)
	v.minimum_size_changed.connect(func(): centra.call_deferred())
	centra.call_deferred()
	await _risposta
	vel.queue_free()

## Testo ricco di larghezza fissa dentro uno scorrimento (al massimo 560 px di altezza).
func _testo(bb: String, dim: int, larghezza: int) -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(larghezza, 40)
	var r := Tema.testo_ricco(dim)
	r.custom_minimum_size = Vector2(larghezza - 16, 0)
	r.text = bb
	sc.add_child(r)
	r.resized.connect(func(): sc.custom_minimum_size.y = minf(r.size.y, 560))
	return sc
