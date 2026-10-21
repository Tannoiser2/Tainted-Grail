extends Node
## Giro completo di due giornate senza interfaccia (vedi prova_giornata.gd).
func _ready() -> void:
	var C = get_node("/root/Campagna")
	C.nuova(1, "Prova giornata", ["arev", "beor"], {})
	var p: Partita = C.partita
	var g := Giornata.new(p)
	var r := g.inizio()
	print("Inizio: ", r["messaggi"])
	print("Mappa: ", p.d["mappa"].keys(), " collegati a 101: ", p.collegati(101))
	var nuovi := g.viaggia([p.attivo()], 102)
	print("Viaggio a 102, rivelati: ", nuovi, " collegati a 102: ", p.collegati(102))
	p.diario.apri_numero(102)
	print("Diario 102: ", Dati.testo_piano(str(p.diario.luogo().get("nome", ""))), " opzioni: ", p.diario.opzioni().size())
	var f := Effetti.applica("Ogni membro della Compagnia ottiene 2 {i:terror} e perde 1 {i:energy}. Ottenete la parte 2 dello status “Canto Funebre”. Ottenete la carta Segreto “Riti del Menhir” (11).", p)
	print("Effetti: ", f.map(func(x): return x["testo"]))
	print("Condizione: ", Condizioni.valuta("Se avete la parte 2 dello status “Canto Funebre”", p), " ", Condizioni.valuta("Se non avete la carta Segreto 11", p))
	for x in p.personaggi():
		g.passa(x)
	print("Giornata finita: ", g.giornata_finita())
	for x in p.personaggi():
		print(g.riposa(x, true))
		print("Sogno: ", g.sogno(x).get("tipo", "-"))
	g.nuova_giornata()
	r = g.inizio()
	print("Giornata ", p.d["giorno"], ": ", r["messaggi"], " Menhir: ", p.d["menhir"])
	get_tree().quit()
