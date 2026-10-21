extends SceneTree
## Screenshot automatici (serve un display: xvfb-run).
## TG_PROVA=1 TG_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto.gd
var main
var n := 0
var cartella := ""

func _initialize() -> void:
	cartella = OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(cartella)
	root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func foto(nome: String) -> void:
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(cartella + "/%02d_%s.png" % [n, nome])
	print("foto ", nome)

func aspetta(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

func _run() -> void:
	main.mostra_menu()
	await aspetta(1.0)
	await foto("menu")
	root.get_node("Campagna").nuova(1, "Prova", ["arev", "ailei"], {})
	main.mostra_gioco()
	await aspetta(4.0)
	await foto("inizio_giornata")
	main._attuale.domande._risposta.emit(0)
	await aspetta(1.0)
	await foto("evento")
	var g = main._attuale
	for i in 4:
		g.domande._risposta.emit(0)  # chiude le finestre dell'Inizio della Giornata
		await aspetta(0.5)
	if is_instance_valid(g._modale):
		g._modale.queue_free()
	await aspetta(2.0)
	await foto("tavolo")
	g._esplora()
	await aspetta(2.0)
	await foto("diario")
	if is_instance_valid(g._diario):
		g._diario.queue_free()
	g._avvia_incontro("verde")
	await aspetta(3.0)
	await foto("incontro")
	var fi = g._ui.get_child(g._ui.get_child_count() - 1)
	fi._fase = "scegli"
	fi._aggiorna()
	await fi.inc.attiva("arev")
	fi._fase = "gioca"
	fi._aggiorna()
	await aspetta(2.0)
	var mano: Array = fi.inc.mani["arev"]
	if not mano.is_empty():
		fi._anteprima.text = fi._descrivi_anteprima(mano[0])
	await aspetta(1.0)
	await foto("incontro_gioca")
	if not mano.is_empty():
		await fi._gioca(mano[0])
		await aspetta(1.0)
		var m2: Array = fi.inc.mani["arev"]
		if not m2.is_empty():
			fi._anteprima.text = fi._descrivi_anteprima(m2[0])
		await aspetta(1.5)
		await foto("incontro_seconda")
	fi.queue_free()
	await aspetta(0.5)
	# Diplomazia: prima carta blu non speciale
	var mb: Array = g.partita.d["mazzi"]["incontri_blu"]
	for i in mb.size():
		if root.get_node("Dati").carte["carte"].get(mb[0], {}).get("fasi") is Array:
			break
		mb.push_back(mb.pop_front())
	g._avvia_incontro("blu")
	await aspetta(2.0)
	var fd = g._ui.get_child(g._ui.get_child_count() - 1)
	fd._fase = "scegli"
	fd._aggiorna()
	await fd.inc.attiva("arev")
	fd._fase = "gioca"
	fd._aggiorna()
	await aspetta(1.5)
	var md: Array = fd.inc.mani["arev"]
	if not md.is_empty():
		fd._anteprima.text = fd._descrivi_anteprima(md[0])
	await aspetta(1.0)
	await foto("diplomazia")
	quit()
