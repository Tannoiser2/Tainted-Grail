extends Node
## Corpo della prova delle regole particolari (lanciato da prova_regole.gd).
var main
var errori := 0

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()

func verifica(cond: bool, cosa: String) -> void:
	print(("OK   " if cond else "ERRORE ") + cosa)
	if not cond:
		errori += 1

func aspetta(sec: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < sec * 1000:
		await get_tree().process_frame

func _img_parola(parola: String, n: int) -> Array:
	var out := []
	for img in Carte.gruppo("oggetti"):
		if Partita.parola_oggetto(img) == parola:
			out.append(img)
			if out.size() >= n:
				break
	return out

func _run() -> void:
	await aspetta(0.5)
	var C = get_node("/root/Campagna")
	C.nuova(1, "Prova regole", ["beor", "ailei"], {})
	var p: Partita = C.partita
	var beor: Dictionary = p.personaggi()[0]
	var ailei: Dictionary = p.personaggi()[1]
	# 1. un solo Oggetto attivo per parola chiave
	var armi := _img_parola("arma", 2)
	beor["oggetti"] = armi.duplicate()
	verifica(p.oggetti_attivi(beor).size() == 1, "2 Armi: 1 sola attiva")
	p.attiva_oggetto(beor, armi[1])
	verifica(p.attivo_oggetto(beor, armi[1]) and not p.attivo_oggetto(beor, armi[0]), "si sceglie quale Arma è attiva")
	# Doppia maestria (armi_attive 2)
	beor["abilita"] = [{"img": "carte/mazzo/32700.webp", "faccia": 1, "attributo": "aggression", "nome": "Doppia maestria"}]
	verifica(p.oggetti_attivi(beor).size() == 2, "Doppia maestria: 2 Armi attive")
	beor["abilita"] = []
	# 2. cedere un Oggetto
	p.dai_oggetto(beor, ailei, armi[0])
	verifica(ailei["oggetti"].has(armi[0]) and not beor["oggetti"].has(armi[0]), "Oggetto dato ad Ailei")
	verifica(not p.cedibile("carte/objetos/32542.webp"), "carta non cedibile riconosciuta")
	# 3. Talismano Opaco: si perde 1 Terrore in più
	p.d["segreti"] = [21]
	ailei["terrore"] = 4
	p.modifica(ailei, "terrore", -1)
	verifica(int(ailei["terrore"]) == 2, "Talismano Opaco: −1 Terrore diventa −2 (%d)" % int(ailei["terrore"]))
	p.d["segreti"] = []
	# 4. Instancabile: Esausto solo a 0 Energia; Muoversi o morire
	beor["abilita"] = [{"img": "carte/mazzo/32706.webp", "faccia": 1, "attributo": "courage", "nome": "Instancabile"}]
	beor["energia"] = 1
	p.cambiato()
	verifica(not Personaggi.esausto(beor), "Instancabile: con 1 Energia non è Esausto")
	beor["abilita"] = [{"img": "carte/mazzo/32709.webp", "faccia": 1, "attributo": "courage", "nome": "Muoversi o morire"}]
	beor["energia"] = 0
	p.cambiato()
	var s0 := int(beor["salute"])
	verifica(p.energia_spendibile(beor) == s0 - 1, "Esausto: può spendere Salute")
	p.spendi_energia(beor, 2)
	verifica(int(beor["salute"]) == s0 - 2, "2 Energia pagate con la Salute")
	beor["abilita"] = []
	# 5. Apprendista rapido: 4 carte fra cui scegliere
	ailei["abilita"] = [{"img": "carte/mazzo/32721.webp", "faccia": 1, "attributo": "empathy", "nome": "Apprendista rapido"}]
	ailei["esp"] = 5
	var g := Giornata.new(p)
	verifica(g.pesca_avanzate(ailei, "combattimento").size() == 4, "Apprendista rapido: 4 carte")
	ailei["abilita"] = []
	# 6. Morte in cooperativo
	main.mostra_gioco()
	await aspetta(3.0)
	var gi = main._attuale
	for i in 6:
		gi.domande._risposta.emit(0)
		await aspetta(0.3)
	beor["oggetti"] = [armi[1]]
	beor["morto"] = true
	var fine := [false]
	(func():
		await gi._controlla_stati()
		fine[0] = true).call()
	for i in 10:
		await aspetta(0.3)
		if fine[0]:
			break
		gi.domande._risposta.emit(0)   # avviso, poi "Prendi Arev"
	verifica(not p.personaggi().any(func(x): return str(x["id"]) == "beor"), "Beor tolto dalla partita")
	verifica(p.d.get("caduti", []).has("beor"), "Beor fra i caduti")
	verifica(p.d.get("oggetti_terra", {}).values().any(func(a): return a.has(armi[1])), "i suoi Oggetti restano nel Luogo")
	verifica(p.personaggi().any(func(x): return str(x["id"]) == "arev"), "Arev preso dalla scatola")
	verifica(gi._schede.get_child_count() >= 2, "schede ricostruite")
	# 7. tutti morti → Misericordia della Madre di Tutti
	for x in p.personaggi():
		x["morto"] = true
	fine[0] = false
	(func():
		await gi._controlla_stati()
		fine[0] = true).call()
	for i in 12:
		await aspetta(0.3)
		if fine[0]:
			break
		gi.domande._risposta.emit(0)   # avviso, Misericordia
	verifica(not p.d["status"].is_empty() and p.d["status"].keys().any(func(k): return str(k).to_lower().find("salvat") >= 0), "status Salvati dalla Dea")
	verifica(p.personaggi().all(func(x): return not x.get("morto", false) and int(x["salute"]) > 0), "Personaggi tornati in vita")
	verifica(p.diario.aperto() and int(p.diario.luogo().get("n", 0)) == 999, "Libro dei Segreti aperto (verso 500)")
	print("ERRORI: ", errori)
	get_tree().quit()
