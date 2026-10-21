extends Node
## Esegue tutte le voci codificate (data/automazione.json) su partite di prova, senza interfaccia:
## ogni condizione viene valutata e ogni lista di effetti eseguita, per scovare errori di esecuzione.
## TG_DB_URL=off godot --headless --path . -s res://tests/prova_automazione.gd
var errori := 0
var passi := 0

func _ready() -> void:
	_run.call_deferred()

func _nuova(C) -> Partita:
	C.nuova(1, "Prova automazione", ["arev", "beor"], {})
	var p: Partita = C.partita
	for x in p.personaggi():
		for r in ["cibo", "ricchezza", "magia", "esp", "rep"]:
			x[r] = 5
	return p

func _run() -> void:
	var C = get_node("/root/Campagna")
	var p := _nuova(C)
	var diario: Dictionary = Dati.automazione.get("diario", {})
	var n := 0
	for k in diario:
		var v: Dictionary = diario[k]
		var it := Interprete.new(p, null, null, {"tiro": 4, "in_diario": true})
		if v.get("condizione") is Dictionary:
			it.valuta(v["condizione"])
		for campo in ["costo", "effetti"]:
			if v.get(campo) is Array:
				await it.esegui(v[campo])
				passi += v[campo].size()
		if v.get("menhir") is Dictionary:
			await it.esegui(v["menhir"].get("costo", []))
			await it.esegui(v["menhir"].get("effetti", []))
		n += 1
		if n % 200 == 0:
			p = _nuova(C)  # partita nuova ogni tanto, perché gli effetti la consumano
	printerr("Diario: %d voci eseguite" % n)
	# carte fuori dagli Incontri
	var carte: Dictionary = Dati.automazione.get("carte", {})
	var nc := 0
	for img in carte:
		var a: Dictionary = carte[img]
		var it2 := Interprete.new(p, null, null, {"carta": img, "luogo": 101})
		for campo in ["rivelato", "giorno", "ottenuta"]:
			if a.get(campo) is Array:
				for s in a[campo]:
					if s is Dictionary and s.has("quando"):
						await it2.esegui(s.get("effetti", []))
					elif s is Dictionary:
						await it2.esegui([s])
		for campo in ["inneschi"]:
			if a.get(campo) is Array:
				for inn in a[campo]:
					if inn is Dictionary and not str(inn.get("quando", "")).begins_with("inizio_") and str(inn.get("quando", "")) not in ["attacco", "dopo_attacco", "attivazione", "collega_chiave", "ferite", "vittoria", "fallimento", "fine_incontro"]:
						if inn.get("condizione") is Dictionary:
							it2.valuta(inn["condizione"])
						await it2.esegui(inn.get("effetti", []))
		if a.get("facce") is Array:
			for f in a["facce"]:
				if f is Dictionary:
					for inn in f.get("inneschi", []):
						if inn is Dictionary and str(inn.get("quando", "")) in ["azione", "sempre", "riposo", "inizio_giornata", "fine_giornata", "viaggio", "esplorazione"]:
							await it2.esegui(inn.get("effetti", []))
		if a.get("azione") is Dictionary:
			await it2.esegui(a["azione"].get("effetti", []))
		if a.get("cerca") is Dictionary and a["cerca"].get("successo") is Dictionary:
			it2.valuta(a["cerca"]["successo"])
		nc += 1
		if nc % 100 == 0:
			p = _nuova(C)
	printerr("Carte: %d eseguite fuori dagli Incontri" % nc)
	# Incontri: ogni carta Incontro, una partita con le capacità delle carte dei Personaggi
	var ni := 0
	for img in carte:
		var a2: Dictionary = carte[img]
		if str(a2.get("gruppo", "")) != "incontri":
			continue
		p = _nuova(C)
		var colore := str(Carte.dati(img).get("colore", "grigio"))
		var inc := Incontro.new(p, img, colore)
		if inc.speciale():
			continue
		await inc.inizia(p.compagnia())
		var t := 0
		while inc.concluso == "" and t < 8:
			t += 1
			for x in inc.da_attivare():
				if inc.concluso != "":
					break
				await inc.attiva(str(x["id"]))
				var g := 0
				while g < 3 and inc.concluso == "":
					var gi := ""
					for c in inc.mani.get(str(x["id"]), []):
						if inc.giocabile(c):
							gi = c
							break
					if gi == "":
						break
					await inc.gioca(gi)
					g += 1
				if inc.concluso == "":
					await inc.termina_carte()
			if inc.concluso == "":
				inc.fine_turno()
		ni += 1
		printerr("  %s: %s (%d turni)" % [Carte.nome(img), inc.concluso if inc.concluso != "" else "in corso", t])
	printerr("Incontri giocati: %d" % ni)
	# tutte le Capacità delle carte Combattimento/Diplomazia
	p = _nuova(C)
	var nk := 0
	for img in carte:
		var a3: Dictionary = carte[img]
		if not (str(a3.get("gruppo", "")) in ["combattimento", "diplomazia"]):
			continue
		var inc2 := Incontro.new(p, "", "grigio" if a3["gruppo"] == "combattimento" else "blu")
		inc2.membri = p.compagnia().duplicate()
		inc2.attivo_id = str(p.attivo()["id"])
		for x in inc2.membri:
			inc2.mani[str(x["id"])] = []
			inc2.mazzi[str(x["id"])] = []
			inc2.scarti[str(x["id"])] = []
		inc2.sequenza.append({"img": img, "tempo": 0, "magia": 0, "pid": inc2.attivo_id, "chiavi": ["aggression"]})
		for tipo in ["piazza", "ritardata", "attacco", "passiva"]:
			await inc2.esegui_capacita(img, tipo, {"cubi_dati": 2})
		nk += 1
		if nk % 60 == 0:
			p = _nuova(C)
	printerr("Carte Combattimento/Diplomazia: %d" % nk)
	# Preparazione di tutti i Capitoli
	for cap in range(2, 16):
		for l in ["", "A", "B"]:
			if Preparazione.carta_preparazione(cap, l) == "" or (l != "" and Carte.txt(Carte.dati(Preparazione.carta_preparazione(cap, l)), "lettera") != l):
				continue
			p = _nuova(C)
			Preparazione.capitolo(p, cap, l)
			printerr("Capitolo %d%s: %d Eventi (%s), Guardiani %s, livelli %s" % [cap, l, p.d["mazzi"]["eventi"].size(),
				", ".join(p.d["mazzi"]["eventi"].map(func(x): return "P%d" % Carte.num(Carte.dati(x), "parte"))),
				Partita.guardiani(p).map(func(g): return Carte.nome(g["img"]) + "@" + str(g["luogo"])),
				Preparazione.livelli_capitolo(cap, 2, l)])
	printerr("FINE")
	get_tree().quit()
