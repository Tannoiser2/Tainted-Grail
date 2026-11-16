extends SceneTree
## Screenshot della finestra dell'Incontro (combattimento e diplomazia), anche in 4:3 come su iPad.
## TG_PROVA=1 TG_DB_URL=off [TG_DIM=1536x1152] xvfb-run -s "-screen 0 2048x1536x24" godot --path . -s res://tests/foto_incontro.gd
var main
var cartella := ""
var suffisso := ""

func _initialize() -> void:
	cartella = OS.get_user_data_dir() + "/foto"
	DirAccess.make_dir_recursive_absolute(cartella)
	var dim := OS.get_environment("TG_DIM")
	if dim != "":
		var p := dim.split("x")
		root.size = Vector2i(int(p[0]), int(p[1]))
		suffisso = "_" + dim
	else:
		root.size = Vector2i(1920, 1080)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func foto(nome: String) -> void:
	for i in 8:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(cartella + "/inc_%s%s.png" % [nome, suffisso])
	print("foto ", nome)

func aspetta(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await process_frame

## Gioca carte finché si può: la prima qualsiasi, poi quelle giocabili.
func gioca_alcune(fi, id: String, quante: int) -> void:
	for k in quante:
		var mano: Array = fi.inc.mani[id]
		var trovata := ""
		for c in mano:
			if fi.inc.anteprima(c)["giocabile"]:
				trovata = c
				break
		if trovata == "":
			# per la prova: si forza la Chiave dorata
			if mano.is_empty():
				return
			fi.inc.carte_attivazione = 0
			trovata = mano[0]
		await fi._gioca(trovata)
		await aspetta(0.6)
		if fi.inc.concluso != "":
			return

## Risponde da sola alle domande (prima opzione) mentre si fanno le foto.
func _rispondi(g) -> void:
	while true:
		await aspetta(1.2)
		if is_instance_valid(g) and g.domande._strato.get_child_count() > 0:
			g.domande._risposta.emit(0)

func _run() -> void:
	root.get_node("Campagna").nuova(1, "Prova", ["arev", "ailei"], {})
	main.mostra_gioco()
	await aspetta(4.0)
	var g = main._attuale
	for i in 5:
		g.domande._risposta.emit(0)
		await aspetta(0.4)
	if is_instance_valid(g._modale):
		g._modale.queue_free()
	await aspetta(1.0)
	for x in g.partita.personaggi():
		x["salute"] = 99
		x["courage"] = 3
		x["aggression"] = 2
	# nemico con Valore alto, per vedere la Sequenza crescere
	var mv: Array = g.partita.d["mazzi"]["incontri_verde"]
	var mig := 0
	for i in mv.size():
		if int(root.get_node("Dati").carte["carte"].get(mv[i], {}).get("valore", 0)) > int(root.get_node("Dati").carte["carte"].get(mv[mig], {}).get("valore", 0)):
			mig = i
	mv.push_front(mv.pop_at(mig))
	_rispondi(g)
	g._avvia_incontro("verde")
	await aspetta(3.0)
	var fi = g._ui.get_child(g._ui.get_child_count() - 1)
	await foto("1_inizio")
	fi._fase = "scegli"
	fi._aggiorna()
	await fi.inc.attiva("arev")
	fi._fase = "gioca"
	fi._aggiorna()
	await aspetta(2.0)
	await gioca_alcune(fi, "arev", 3)
	fi._fase = "gioca" if fi.inc.concluso == "" else fi._fase
	if not fi.inc.sequenza.is_empty():
		fi.inc.sequenza[0]["tempo"] = 2
		fi.inc.sequenza.back()["cariche"] = 1
	var m: Array = fi.inc.mani["arev"]
	if not m.is_empty():
		fi._scelta = m[0]
	fi._aggiorna()
	await aspetta(2.0)
	await foto("2_combattimento")
	fi.queue_free()
	await aspetta(0.5)
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
	await gioca_alcune(fd, "arev", 2)
	var md: Array = fd.inc.mani["arev"]
	if not md.is_empty():
		fd._scelta = md[0]
	fd._aggiorna()
	await aspetta(2.0)
	await foto("3_diplomazia")
	quit()
