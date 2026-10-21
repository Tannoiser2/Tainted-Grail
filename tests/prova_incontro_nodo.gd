extends Node
## Simula un Combattimento e una Diplomazia giocando sempre la prima carta giocabile.
## godot --headless --path . -s res://tests/prova_incontro.gd
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var C = get_node("/root/" + "Campagna")
	var D = get_node("/root/" + "Dati")
	C.nuova(1, "Prova incontri", ["beor"], {})
	var p = C.partita
	for colore in ["verde", "grigio", "viola", "blu"]:
		var m: Array = p.d["mazzi"]["incontri_" + colore]
		printerr("Mazzo ", colore, ": ", m.size(), " carte")
		for k in 3:
			if m.is_empty():
				break
			var img: String = m[k % m.size()]
			var inc := Incontro.new(p, img, colore)
			if inc.speciale():
				printerr("  speciale: ", Carte.nome(img))
				continue
			inc.inizia(p.compagnia())
			var t := 0
			while inc.concluso == "" and t < 12:
				t += 1
				inc.attiva("beor")
				var giocate := 0
				while giocate < 4:
					var gioc := ""
					for c in inc.mani["beor"]:
						if inc.giocabile(c):
							gioc = c
							break
					if gioc == "":
						break
					inc.gioca(gioc)
					giocate += 1
					if inc.concluso != "":
						break
				inc.termina_carte()
				if inc.concluso == "":
					inc.fine_turno()
			printerr("  %s: %s in %d turni (Riserva %d, Affinità %d, Salute Beor %d)" % [Carte.nome(img), inc.concluso, t, inc.riserva, inc.affinita, int(p.attivo()["salute"])])
			p.attivo()["salute"] = 9
	get_tree().quit()
