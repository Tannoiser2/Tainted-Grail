## Svolgimento della Giornata (regole §3-4): Inizio della Giornata automatico, azioni dei
## Personaggi a turno, Fine della Giornata (Riposo, Energia, Sogni). Lavora sulla Partita e
## restituisce i testi/carte da mostrare; l'interfaccia (Gioco) decide come presentarli.
class_name Giornata
extends RefCounted

var p: Partita

func _init(partita: Partita) -> void:
	p = partita

## --- I) Inizio della Giornata ------------------------------------------------------
## Restituisce {"evento": img o "", "messaggi": [testi]}.
func inizio() -> Dictionary:
	var msg := []
	var d := p.d
	# 1. Menhir spenti (Quadrante tolto il giorno prima) vengono rimossi
	for k in d["menhir"].keys():
		if int(d["menhir"][k].get("quadrante", 0)) <= 0:
			d["menhir"].erase(k)
			msg.append("Il Menhir del Luogo %s si è spento." % k)
	# 2. Luoghi fuori dal raggio dei Menhir
	if d["menhir"].is_empty():
		for x in p.personaggi():
			p.modifica(x, "salute", -2)
			p.modifica(x, "terrore", 2)
		msg.append("Nessun Menhir è attivo: ogni Personaggio perde 2 Salute e ottiene 2 Terrore.")
	else:
		for k in d["mappa"].keys():
			var c := p.cella(int(k))
			if not p.in_raggio(c):
				var n := int(k)
				p.rimuovi_luogo(n)
				msg.append("Il Luogo %d svanisce nella Nebbia (fuori dal raggio dei Menhir)." % n)
				for x in p.personaggi():
					if int(x["luogo"]) == n:
						p.modifica(x, "salute", -2)
						p.modifica(x, "terrore", 2)
						x["luogo"] = _luogo_piu_vicino(c)
						msg.append("%s fugge al Luogo %d (−2 Salute, +2 Terrore)." % [x["nome"], int(x["luogo"])])
	# 3. Quadranti dei Menhir −1
	for k in d["menhir"]:
		var q := int(d["menhir"][k]["quadrante"]) - 1
		d["menhir"][k]["quadrante"] = maxi(q, 0)
		if q <= 0:
			msg.append("Il Quadrante del Menhir al Luogo %s è finito: il Menhir si spegnerà domani." % k)
	# 4. Gettoni Tempo sui Luoghi (azioni una volta al giorno) e quadranti Tempo
	d["gettoni"]["tempo"] = {}
	for x in p.personaggi():
		x["passato"] = false
		x["usate"] = {}
	# 5. Evento
	var ev := pesca_evento()
	if ev != "":
		msg.append("Evento: " + Carte.nome(ev))
	d["fase"] = "giorno"
	d["attivo"] = 0
	p.racconta("— Giornata %d —" % int(d["giorno"]))
	for m in msg:
		p.racconta(m)
	p.cambiato()
	return {"evento": ev, "messaggi": msg}

func _luogo_piu_vicino(c: Vector2i) -> int:
	var meglio := 0
	var dist := 99999
	for k in p.d["mappa"]:
		var cc := p.cella(int(k))
		var dd := absi(cc.x - c.x) + absi(cc.y - c.y)
		if dd < dist or (dd == dist and int(k) < meglio):
			dist = dd
			meglio = int(k)
	return meglio

func pesca_evento() -> String:
	var m: Array = p.d["mazzi"].get_or_add("eventi", [])
	if m.is_empty():
		return ""
	var ev: String = m.pop_front()
	var c := Carte.dati(ev)
	if c.get("missione", false) or c.get("cerca") is Dictionary:
		# le Cerche restano attive finché la carta non dice di scartarle
		var att: Array = p.d.get_or_add("cerche", [])
		if not att.has(ev):
			att.push_front(ev)
	else:
		p.d["mazzi"].get_or_add("eventi_scarti", []).append(ev)
	var ec = c.get("eventi_casuali")
	if ec is Dictionary:
		var n := int(ec.get("base", 0)) - int(ec.get("meno_per_giocatore", 0)) * p.personaggi().size()
		if ec.has("per_giocatori"):
			n = int(ec["per_giocatori"].get(str(p.personaggi().size()), n))
		aggiungi_casuali(maxi(0, n))
		p.racconta("Aggiunti %d Eventi Casuali in cima al mazzo Eventi" % maxi(0, n))
	p.d["evento"] = ev
	return ev

## Mette N Eventi Casuali in cima al mazzo Eventi.
func aggiungi_casuali(n: int) -> void:
	var cas: Array = p.d["mazzi"].get_or_add("eventi_casuali", [])
	for i in n:
		if cas.is_empty():
			break
		p.d["mazzi"]["eventi"].push_front(cas.pop_front())

## --- II) Azioni ------------------------------------------------------------------

## Personaggi che possono ancora agire oggi.
func attivi() -> Array:
	return p.personaggi().filter(func(x): return not x.get("passato", false) and int(x.get("energia", 0)) > 0 and int(x.get("salute", 0)) > 0)

## Passa al prossimo personaggio che può agire; false se la giornata è finita.
func prossimo() -> bool:
	var tutti := p.personaggi()
	if attivi().is_empty():
		return false
	var i := int(p.d.get("attivo", 0))
	for k in tutti.size():
		i = (i + 1) % tutti.size()
		if attivi().has(tutti[i]):
			p.d["attivo"] = i
			p.cambiato()
			return true
	return false

func puo_viaggiare(x: Dictionary) -> Array:
	return p.collegati(int(x["luogo"]))

## Viaggio di un personaggio (o della sua Compagnia) verso un Luogo collegato.
func viaggia(gruppo: Array, dest: int) -> Array:
	for x in gruppo:
		p.modifica(x, "energia", -1)
		x["luogo"] = dest
	p.racconta("%s viaggia al Luogo %d" % [" e ".join(gruppo.map(func(x): return x["nome"])), dest])
	var nuovi := p.rivela_attorno(dest)
	p.cambiato()
	return nuovi

## Costo dell'Esplorazione: 1 Energia per ogni membro della Compagnia.
func esplora(gruppo: Array) -> bool:
	for x in gruppo:
		if int(x.get("energia", 0)) < 1:
			return false
	for x in gruppo:
		p.modifica(x, "energia", -1)
	p.racconta("%s esplora il Luogo %d" % [" e ".join(gruppo.map(func(x): return x["nome"])), int(gruppo[0]["luogo"])])
	return true

## Azione del Luogo: costo in Energia pagato una volta dalla Compagnia; "una volta al giorno" segnato.
func azione_luogo(n: int) -> Dictionary:
	var c := Carte.luogo(n)
	var az = c.get("azione")
	if az is Array:
		az = az[0] if not az.is_empty() else null
	if not (az is Dictionary):
		return {}
	return az

func azione_luogo_usata(n: int) -> bool:
	return p.d["gettoni"]["tempo"].has(str(n))

func esegui_azione_luogo(n: int) -> Array:
	var az := azione_luogo(n)
	if az.is_empty():
		return []
	var costo := int(az.get("costo", 0))
	if not p.paga("energia", costo):
		return [{"testo": "Energia insufficiente", "fatto": false}]
	if az.get("una_volta_al_giorno", false):
		p.d["gettoni"]["tempo"][str(n)] = 1
	p.racconta("Azione del Luogo %d: %s" % [n, str(az.get("nome", {}).get("it", ""))])
	return Effetti.applica(str(az.get("it", "")), p)

func passa(x: Dictionary) -> void:
	x["passato"] = true
	p.racconta("%s Passa" % x["nome"])
	p.cambiato()

func giornata_finita() -> bool:
	return attivi().is_empty()

## --- III) Fine della Giornata ----------------------------------------------------

## Riposo e recupero dell'Energia per un personaggio. mangia: se consumare 1 Cibo.
func riposa(x: Dictionary, mangia: bool) -> String:
	var t := ""
	if mangia and int(x.get("cibo", 0)) > 0:
		p.modifica(x, "cibo", -1)
		p.modifica(x, "salute", 1)
		var senza_menhir: bool = not p.d["menhir"].has(str(x["luogo"])) or int(p.d["menhir"][str(x["luogo"])].get("quadrante", 0)) <= 0
		if str(x["id"]) == "ailei" and senza_menhir:
			t = "%s mangia: +1 Salute (Traumatizzata: il Terrore non scende senza Menhir)." % x["nome"]
		else:
			p.modifica(x, "terrore", -1)
			t = "%s mangia: +1 Salute, −1 Terrore." % x["nome"]
	else:
		if int(x.get("energia", 0)) == 0:
			p.modifica(x, "salute", -1)
			t = "%s non mangia ed è già senza Energia: −1 Salute." % x["nome"]
		else:
			x["energia"] = 0
			t = "%s non mangia: Energia a 0." % x["nome"]
	var prima := int(x["energia"])
	x["energia"] = Personaggi.energia_recuperata(x)
	t += " Energia %d → %d." % [prima, int(x["energia"])]
	p.racconta(t)
	p.cambiato()
	return t

## Costo in Esp del prossimo punto in un attributo (dipende dal totale della coppia).
func costo_attributo(x: Dictionary, a: String) -> int:
	var tot := p.attributo(x, a) + p.attributo(x, Partita.OPPOSTO[a])
	return mini(2 * (tot + 1), 10)

func migliora_attributo(x: Dictionary, a: String) -> bool:
	var c := costo_attributo(x, a)
	if int(x.get("esp", 0)) < c:
		return false
	x["esp"] = int(x["esp"]) - c
	x["attributi"][a] = p.attributo(x, a) + 1
	p.racconta("%s migliora %s a %d (−%d Esp)" % [x["nome"], Partita.NOMI_ATTRIBUTI[a], int(x["attributi"][a]), c])
	p.cambiato()
	return true

## 2 Esp: pesca 3 carte dalla Riserva Avanzata, se ne tiene 1 (restituisce le 3 per la scelta).
func pesca_avanzate(x: Dictionary, tipo: String) -> Array:
	var r: Array = x["mazzi"][tipo]["riserva"]
	if int(x.get("esp", 0)) < 2 or r.is_empty():
		return []
	return r.slice(0, 3)

func scegli_avanzata(x: Dictionary, tipo: String, img: String) -> void:
	var r: Array = x["mazzi"][tipo]["riserva"]
	x["esp"] = int(x["esp"]) - 2
	r.erase(img)
	r.shuffle()
	x["mazzi"][tipo]["mazzo"].append(img)
	p.racconta("%s ottiene la carta %s" % [x["nome"], Carte.nome(img)])
	p.cambiato()

## Sogno o Incubo del Luogo di un personaggio (testo dal Diario), "" se nessuno.
func sogno(x: Dictionary) -> Dictionary:
	var id := Dati.id_numero(p.camp, int(x["luogo"]))
	var l := Dati.luogo(p.camp, id)
	if Personaggi.in_follia(x) and l.has("incubo"):
		return {"tipo": "Incubo", "testo": l["incubo"]}
	var sigilli: Array = Carte.luogo(int(x["luogo"])).get("sigilli", [])
	if (sigilli.has("dream") or sigilli.is_empty()) and l.has("sogno"):
		return {"tipo": "Sogno", "testo": l["sogno"]}
	return {}

func nuova_giornata() -> void:
	p.d["giorno"] = int(p.d.get("giorno", 1)) + 1
	p.d["fase"] = "inizio"
	p.cambiato()
