## Radice del gioco: passa dal menu alla partita e viceversa.
extends Node

var _attuale: Node

func _ready() -> void:
	get_window().title = "Tainted Grail — La Caduta di Avalon"
	randomize()
	var prova := OS.get_environment("TG_PROVA")
	if prova != "":
		# prove automatiche (tests/): niente menu
		return
	mostra_menu()

func _cambia(n: Node) -> void:
	if is_instance_valid(_attuale):
		_attuale.queue_free()
	_attuale = n
	add_child(n)

func mostra_menu() -> void:
	var m := Menu.new()
	m.inizia.connect(mostra_gioco)
	m.diario_libero.connect(mostra_diario_libero)
	# i Control hanno bisogno di un CanvasLayer (o di un Control) sopra di sé per occupare lo schermo
	var cl := CanvasLayer.new()
	cl.add_child(m)
	_cambia(cl)

## Il Diario usato come l'app ufficiale: si sceglie il numero del Luogo e si legge, senza partita.
func mostra_diario_libero() -> void:
	var d := DiarioLibero.new()
	d.esci.connect(mostra_menu)
	var cl := CanvasLayer.new()
	cl.add_child(d)
	_cambia(cl)

func mostra_gioco() -> void:
	var g := Gioco.new()
	g.esci.connect(func():
		await Campagna.chiudi()
		mostra_menu())
	_cambia(g)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
