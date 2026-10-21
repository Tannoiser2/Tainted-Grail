## Stato della partita di Tainted Grail e operazioni elementari (risorse, status, Segreti,
## Oggetti, mappa dei Luoghi, Menhir). Tutto vive nel dizionario `d` (salvato nella campagna).
##
##  d = {
##    giorno, capitolo, lettera ("A"/"B" per i capitoli divisi), fase,
##    personaggi: [ {id, nome, luogo, salute, energia, terrore, cibo, ricchezza, magia, esp, rep,
##                   attributi:{aggression…}, mazzi:{combattimento:{mazzo,mano,scarti}, diplomazia:{…}},
##                   oggetti:[], compagni:[], segreti:[], attivato, usate:{} } ],
##    attivo: indice del personaggio di turno,
##    mappa: { "101": {x, y, carta} },        # Luoghi sul tavolo, coordinate di griglia
##    menhir: { "101": {quadrante} },          # Menhir attivi e valore del Quadrante
##    status: { "Canto Funebre": [1, 2] },     # parti degli status ottenute
##    segreti: [66, …], mazzi: {…}, gettoni: {cerca, tempo:{…}}, note_capitolo
##  }
class_name Partita
extends RefCounted

signal modificata
signal annota(testo: String)

const RISORSE := ["salute", "energia", "terrore", "cibo", "ricchezza", "magia", "esp", "rep"]
const NOMI_RISORSE := {"salute": "Salute", "energia": "Energia", "terrore": "Terrore", "cibo": "Cibo",
	"ricchezza": "Ricchezza", "magia": "Magia", "esp": "Esp", "rep": "Rep"}
const ATTRIBUTI := ["aggression", "courage", "practicality", "spirituality", "caution", "empathy"]
const NOMI_ATTRIBUTI := {"aggression": "Aggressività", "courage": "Coraggio", "practicality": "Praticità",
	"spirituality": "Spiritualità", "caution": "Cautela", "empathy": "Empatia"}
## coppie opposte sulla plancia: aumentare uno diminuisce l'altro
const OPPOSTO := {"aggression": "empathy", "empathy": "aggression", "courage": "caution", "caution": "courage",
	"practicality": "spirituality", "spirituality": "practicality"}

var camp: int
var d: Dictionary
var diario: MotoreDiario

func _init(camp_: int, dati: Dictionary, stato_diario: Dictionary) -> void:
	camp = camp_
	d = dati
	diario = MotoreDiario.new(camp, stato_diario, self)

func cambiato() -> void:
	modificata.emit()

func racconta(t: String) -> void:
	annota.emit(t)

## --- Nuova partita ------------------------------------------------------------------

func prepara_nuova(ids: Array, opzioni: Dictionary) -> void:
	d.clear()
	d["giorno"] = 1
	d["capitolo"] = 1
	d["lettera"] = ""
	d["fase"] = "inizio"
	d["personaggi"] = []
	for id in ids:
		d["personaggi"].append(Personaggi.nuovo(str(id)))
	d["attivo"] = 0
	d["mappa"] = {}
	d["menhir"] = {}
	d["status"] = {}
	d["segreti"] = []
	d["gettoni"] = {"cerca": 0, "tempo": {}}
	d["mazzi"] = {}
	d["opzioni"] = opzioni
	Preparazione.capitolo_1(self)

## --- Personaggi -----------------------------------------------------------------------

func personaggi() -> Array:
	return d.get("personaggi", [])

func attivo() -> Dictionary:
	var p := personaggi()
	if p.is_empty():
		return {}
	return p[clampi(int(d.get("attivo", 0)), 0, p.size() - 1)]

## Membri della Compagnia: i personaggi nello stesso Luogo di quello attivo.
func compagnia() -> Array:
	var a := attivo()
	var out := []
	for p in personaggi():
		if int(p.get("luogo", 0)) == int(a.get("luogo", -1)):
			out.append(p)
	return out

func compagnia_completa() -> bool:
	return compagnia().size() == personaggi().size()

func limite(p: Dictionary, ris: String) -> int:
	return Personaggi.limite(p, ris)

## Modifica una risorsa di un personaggio rispettando i limiti; restituisce la variazione reale.
func modifica(p: Dictionary, ris: String, delta: int) -> int:
	if ris == "" or delta == 0:
		return 0
	var prima := int(p.get(ris, 0))
	var dopo := clampi(prima + delta, 0, limite(p, ris))
	p[ris] = dopo
	if ris == "salute":
		# l'Energia non può stare sopra la Salute (marcatore a T)
		p["energia"] = mini(int(p.get("energia", 0)), limite(p, "energia"))
		if dopo == 0 and prima > 0:
			racconta("%s sta morendo (Salute 0)!" % p["nome"])
	if ris == "energia" and dopo <= 1 and prima > 1 and str(p.get("id", "")) == "beor":
		# Ferita Infetta: Beor perde 1 Salute ogni volta che diventa Esausto
		modifica(p, "salute", -1)
		racconta("Beor è Esausto: Ferita Infetta, −1 Salute")
	if dopo != prima:
		cambiato()
	return dopo - prima

func puo_pagare(ris: String, n: int, per_membro := false) -> bool:
	if per_membro:
		for p in compagnia():
			if int(p.get(ris, 0)) < n:
				return false
		return true
	# un costo della Compagnia si può dividere fra i membri
	var tot := 0
	for p in compagnia():
		tot += int(p.get(ris, 0))
	return tot >= n

## Paga un costo della Compagnia (prima il personaggio attivo, poi gli altri).
func paga(ris: String, n: int, per_membro := false) -> bool:
	if not puo_pagare(ris, n, per_membro):
		return false
	if per_membro:
		for p in compagnia():
			modifica(p, ris, -n)
		return true
	var resto := n
	var ordine := [attivo()]
	for p in compagnia():
		if p != attivo():
			ordine.append(p)
	for p in ordine:
		var x := mini(resto, int(p.get(ris, 0)))
		modifica(p, ris, -x)
		resto -= x
	return true

func attributo(p: Dictionary, a: String) -> int:
	return int(p.get("attributi", {}).get(a, 0))

## Valore più alto di un attributo nella Compagnia.
func attributo_compagnia(a: String) -> int:
	var m := 0
	for p in compagnia():
		m = maxi(m, attributo(p, a))
	return m

## --- Status, Segreti, capitolo ------------------------------------------------------------

func parti_status(nome: String) -> Array:
	return d.get("status", {}).get(_chiave_status(nome), [])

func _chiave_status(nome: String) -> String:
	var n := nome.strip_edges().trim_suffix(".").trim_suffix(",")
	for k in d.get("status", {}):
		if str(k).to_lower() == n.to_lower():
			return k
	return n

## Aggiunge parti di uno status ([] = status senza parti numerate: si registra come parte 1).
func ottieni_status(nome: String, parti: Array) -> void:
	var k := _chiave_status(nome)
	var a: Array = d["status"].get_or_add(k, [])
	if parti.is_empty():
		parti = [1]
	for x in parti:
		if not a.has(int(x)):
			a.append(int(x))
	a.sort()
	racconta("Status \"%s\": parte %s" % [k, ", ".join(parti.map(func(x): return str(x)))])
	cambiato()

func perdi_status(nome: String, parti: Array = []) -> void:
	var k := _chiave_status(nome)
	if not d["status"].has(k):
		return
	if parti.is_empty():
		d["status"].erase(k)
	else:
		for x in parti:
			d["status"][k].erase(int(x))
		if d["status"][k].is_empty():
			d["status"].erase(k)
	cambiato()

func ha_segreto(n: int) -> bool:
	return d.get("segreti", []).has(n)

func ottieni_segreto(n: int) -> void:
	if not ha_segreto(n):
		d["segreti"].append(n)
		racconta("Ottenuto il Segreto %d" % n)
		cambiato()

func perdi_segreto(n: int) -> void:
	d["segreti"].erase(n)
	cambiato()

func capitolo() -> int:
	return int(d.get("capitolo", 1))

func lettera_capitolo() -> String:
	return str(d.get("lettera", ""))

## --- Mappa e Menhir ------------------------------------------------------------------

func luogo_attivo() -> int:
	return int(attivo().get("luogo", 0))

func menhir_presente_qui() -> bool:
	return d.get("menhir", {}).has(str(luogo_attivo()))

func menhir_attivo_qui() -> bool:
	var m: Dictionary = d.get("menhir", {}).get(str(luogo_attivo()), {})
	return not m.is_empty() and int(m.get("quadrante", 0)) > 0

## --- Mappa: piazzamento e rivelazione dei Luoghi ---------------------------------------

const DIREZIONI := {"su": Vector2i(0, -1), "giu": Vector2i(0, 1), "sinistra": Vector2i(-1, 0), "destra": Vector2i(1, 0)}
const OPPOSTA := {"su": "giu", "giu": "su", "sinistra": "destra", "destra": "sinistra"}

func cella(n: int) -> Vector2i:
	var i: Dictionary = d["mappa"].get(str(n), {})
	return Vector2i(int(i.get("x", 0)), int(i.get("y", 0))) if not i.is_empty() else Vector2i(99999, 99999)

func luogo_in(c: Vector2i) -> int:
	for k in d["mappa"]:
		var i: Dictionary = d["mappa"][k]
		if int(i["x"]) == c.x and int(i["y"]) == c.y:
			return int(k)
	return 0

func piazza_luogo(n: int, c: Vector2i) -> void:
	d["mappa"][str(n)] = {"x": c.x, "y": c.y}
	d.get_or_add("rivelati", [])
	if not d["rivelati"].has(n):
		d["rivelati"].append(n)
	cambiato()

## Una cella è nel raggio di un Menhir attivo se è adiacente (anche in diagonale) o coincide.
func in_raggio(c: Vector2i) -> bool:
	var menhir: Dictionary = d.get("menhir", {})
	if menhir.is_empty():
		return true  # senza Menhir non si rimuove nulla (regola dell'ultimo Menhir)
	for k in menhir:
		var mc := cella(int(k))
		if absi(mc.x - c.x) <= 1 and absi(mc.y - c.y) <= 1:
			return true
	return false

## Chiavi di Direzione di un Luogo (dalla carta trascritta).
func direzioni(n: int) -> Dictionary:
	return Carte.luogo(n).get("direzioni", {})

## Il Luogo con quel numero, o quello che lo ha come "numero antico" se è stato sostituito.
func luogo_attuale(numero: int) -> int:
	if d.get("rimossi", []).has(numero):
		for k in d.get("sostituzioni", {}):
			if int(k) == numero:
				return int(d["sostituzioni"][k])
		return 0
	return numero

## Rivela i Luoghi collegati a un Luogo (all'arrivo). Restituisce i numeri piazzati.
func rivela_attorno(n: int) -> Array:
	var nuovi := []
	var c := cella(n)
	var dirs := direzioni(n)
	for k in dirs:
		if dirs[k] == null or not DIREZIONI.has(k):
			continue
		var num := luogo_attuale(int(dirs[k]))
		if num == 0 or d["mappa"].has(str(num)):
			continue
		var dc: Vector2i = c + DIREZIONI[k]
		if luogo_in(dc) != 0 or not in_raggio(dc):
			continue
		piazza_luogo(num, dc)
		nuovi.append(num)
	if not nuovi.is_empty():
		racconta("Rivelati i Luoghi " + ", ".join(nuovi.map(func(x): return str(x))))
	return nuovi

## Luoghi collegati (per il Viaggio): adiacenti in ortogonale e con le Chiavi di Direzione
## corrispondenti sui lati che si toccano. Se la carta non è ancora trascritta, basta l'adiacenza.
func collegati(n: int) -> Array:
	var out := []
	var c := cella(n)
	var dn := direzioni(n)
	for k in DIREZIONI:
		var m := luogo_in(c + DIREZIONI[k])
		if m == 0:
			continue
		if dn.is_empty() or Carte.luogo(m).is_empty():
			out.append(m)
			continue
		var dm := direzioni(m)
		if dn.get(k) != null or dm.get(OPPOSTA[k]) != null:
			out.append(m)
	return out

func sostituisci_luogo(vecchio: int, nuovo: int) -> void:
	if not d["mappa"].has(str(vecchio)):
		return
	var info: Dictionary = d["mappa"][str(vecchio)]
	d["mappa"].erase(str(vecchio))
	d["mappa"][str(nuovo)] = info
	d.get_or_add("rimossi", []).append(vecchio)
	d.get_or_add("sostituzioni", {})[str(vecchio)] = nuovo
	for p in personaggi():
		if int(p["luogo"]) == vecchio:
			p["luogo"] = nuovo
	if d["menhir"].has(str(vecchio)):
		d["menhir"][str(nuovo)] = d["menhir"][str(vecchio)]
		d["menhir"].erase(str(vecchio))
	racconta("Il Luogo %d è sostituito dal Luogo %d" % [vecchio, nuovo])
	cambiato()

func rimuovi_luogo(n: int) -> void:
	d["mappa"].erase(str(n))
	d.get_or_add("rimossi", []).append(n)
	cambiato()

## --- Menhir --------------------------------------------------------------------------

func attiva_menhir(n: int, quadrante: int) -> void:
	var menhir: Dictionary = d["menhir"]
	if not menhir.has(str(n)) and menhir.size() >= 3:
		# massimo 3 Menhir: si toglie quello col Quadrante più basso
		var peggiore := ""
		for k in menhir:
			if peggiore == "" or int(menhir[k]["quadrante"]) < int(menhir[peggiore]["quadrante"]):
				peggiore = k
		menhir.erase(peggiore)
	menhir[str(n)] = {"quadrante": quadrante}
	racconta("Menhir attivato al Luogo %d (Quadrante %d)" % [n, quadrante])
	for p in personaggi():
		rivela_attorno(int(p["luogo"]))
	cambiato()

## Quadrante iniziale di un Menhir: 8 meno 1 per ogni giocatore oltre il primo.
func quadrante_iniziale(base := 8) -> int:
	return base - (personaggi().size() - 1)

## --- Oggetti --------------------------------------------------------------------------

func pesca_oggetto(fabbricabile := false, x: Dictionary = {}, parola := "") -> String:
	if x.is_empty():
		x = attivo()
	var m: Array = d["mazzi"].get_or_add("oggetti", [])
	for i in m.size():
		var img: String = m[i]
		if fabbricabile and not (Carte.dati(img).get("fabbricabile", false) or Carte.auto(img).get("fabbricabile", false)):
			continue
		if parola != "" and str(Carte.auto(img).get("parola", Carte.dati(img).get("parola", ""))).to_lower() != parola.to_lower():
			continue
		m.remove_at(i)
		x["oggetti"].append(img)
		if fabbricabile or parola != "":
			m.shuffle()
		racconta("%s ottiene l'Oggetto %s" % [x["nome"], Carte.nome(img)])
		cambiato()
		return img
	return ""

func prendi_oggetto_nome(nome: String, x: Dictionary = {}) -> String:
	if x.is_empty():
		x = attivo()
	var m: Array = d["mazzi"].get_or_add("oggetti", [])
	for i in m.size():
		if Carte.nome(m[i]).to_lower() == nome.to_lower():
			var img: String = m[i]
			m.remove_at(i)
			x["oggetti"].append(img)
			racconta("%s ottiene l'Oggetto %s" % [x["nome"], Carte.nome(img)])
			cambiato()
			return img
	return ""

func scarta_oggetto(p: Dictionary, img: String) -> void:
	p["oggetti"].erase(img)
	d["mazzi"].get_or_add("oggetti", []).append(img)  # in fondo al mazzo
	cambiato()

## --- Mappa: piazzamenti speciali ----------------------------------------------------

## Piazza un Luogo nella prima cella libera accanto a un altro (preparazioni e movimenti del Diario).
func piazza_vicino(n: int, base: int) -> void:
	if d["mappa"].has(str(n)):
		return
	var c := cella(base)
	if c.x > 9999:
		c = Vector2i.ZERO
	# se un Luogo collegato indica questo numero, si usa la sua Chiave di Direzione
	for k in d["mappa"]:
		var dirs := direzioni(int(k))
		for dk in dirs:
			if dirs[dk] != null and int(dirs[dk]) == n and DIREZIONI.has(dk):
				var cc: Vector2i = cella(int(k)) + DIREZIONI[dk]
				if luogo_in(cc) == 0:
					piazza_luogo(n, cc)
					return
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) + absi(dy) != r:
					continue
				var cc2 := c + Vector2i(dx, dy)
				if luogo_in(cc2) == 0:
					piazza_luogo(n, cc2)
					return

## --- Eventi -----------------------------------------------------------------------

## Carta Evento di una Parte di un Capitolo (dal mazzo Eventi o dal gruppo); la toglie dal mazzo.
func trova_evento(cap: int, parte: int, lettera := "") -> String:
	var candidati := []
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if c.get("capitolo") == null or c.get("parte") == null:
			continue
		if Carte.num(c, "capitolo") == cap and Carte.num(c, "parte") == parte and str(c.get("sottotipo", "")) == "storia":
			if lettera == "" or Carte.txt(c, "lettera") == "" or Carte.txt(c, "lettera") == lettera:
				candidati.append(img)
	if candidati.is_empty():
		return ""
	var img2: String = candidati[0]
	d["mazzi"].get_or_add("eventi", []).erase(img2)
	return img2

func trova_evento_speciale(lettera: String) -> String:
	for img in Carte.gruppo("eventi_speciali"):
		var c := Carte.dati(img)
		if Carte.txt(c, "lettera").to_upper() == lettera.to_upper() or Carte.nome(img).to_upper().ends_with(" " + lettera.to_upper()):
			return img
	return ""

## --- Inneschi delle carte (Oggetti, Segreti, Abilità, Eventi, Stai morendo/impazzendo) ---------

## Fonti di effetti in gioco: [{img, inneschi, chi}] (chi = personaggio proprietario, {} = della Compagnia).
func fonti_inneschi() -> Array:
	var out := []
	for x in personaggi():
		for o in x.get("oggetti", []):
			var a := Carte.auto(o)
			if a.get("inneschi") is Array:
				out.append({"img": o, "inneschi": a["inneschi"], "chi": x})
		for ab in x.get("abilita", []):
			if not (ab is Dictionary):
				continue
			var fa: Array = Carte.auto(str(ab.get("img", ""))).get("facce", [])
			var i := int(ab.get("faccia", 0))
			if i < fa.size() and fa[i] is Dictionary and fa[i].get("inneschi") is Array:
				out.append({"img": str(ab["img"]), "inneschi": fa[i]["inneschi"], "chi": x, "faccia": i})
		for g in ["morendo", "impazzendo"]:
			if (g == "morendo" and Personaggi.morente(x)) or (g == "impazzendo" and Personaggi.in_follia(x)):
				var scelta := carta_stato(g)
				if scelta != "" and Carte.auto(scelta).get("inneschi") is Array:
					out.append({"img": scelta, "inneschi": Carte.auto(scelta)["inneschi"], "chi": x})
	for n in d.get("segreti", []):
		var s := Carte.segreto(int(n))
		if s != "" and Carte.auto(s).get("inneschi") is Array:
			out.append({"img": s, "inneschi": Carte.auto(s)["inneschi"], "chi": {}})
	var ev := str(d.get("evento", ""))
	if ev != "" and Carte.auto(ev).get("giorno") is Array:
		out.append({"img": ev, "inneschi": Carte.auto(ev)["giorno"], "chi": {}})
	return out

static func _quando_corrisponde(q, quando: String) -> bool:
	if q is Array:
		return q.has(quando)
	return str(q) == quando

## Inneschi attivi per un momento del gioco. x: limita alle carte di quel personaggio (e a quelle comuni).
func inneschi(quando: String, x: Dictionary = {}) -> Array:
	var out := []
	for f in fonti_inneschi():
		if not x.is_empty() and not f["chi"].is_empty() and f["chi"] != x:
			continue
		for inn in f["inneschi"]:
			if inn is Dictionary and _quando_corrisponde(inn.get("quando"), quando):
				out.append({"img": f["img"], "innesco": inn, "chi": f["chi"]})
	return out

## Passi "modificatore" attivi di un certo tipo (quando = "sempre").
func modificatori(cosa: String, x: Dictionary = {}) -> Array:
	var out := []
	for i in inneschi("sempre", x):
		var c = i["innesco"].get("condizione")
		if c is Dictionary and not c.is_empty() and Interprete.new(self).valuta(c) == false:
			continue
		for s in i["innesco"].get("effetti", []):
			if s is Dictionary and str(s.get("tipo", "")) == "modificatore" and str(s.get("cosa", "")) == cosa:
				var m: Dictionary = s.duplicate()
				m["img"] = i["img"]
				out.append(m)
	return out

func somma_modificatori(cosa: String, x: Dictionary = {}, ris := "") -> int:
	var t := 0
	for m in modificatori(cosa, x):
		if ris != "" and m.has("ris") and str(m["ris"]) != ris:
			continue
		t += int(m.get("n", 0))
	return t

## Guadagno di una risorsa modificato dalle carte ("ogni volta che ottieni Ricchezza, +1").
func guadagno(x: Dictionary, ris: String, n: int, _colore := "") -> int:
	if n <= 0:
		return n
	return maxi(0, n + somma_modificatori("guadagno", x, ris))

## Costo in Energia modificato dalle carte (minimo 1 se indicato).
func costo_modificato(ris: String, n: int) -> int:
	if ris != "energia" or n <= 0:
		return n
	var mods := modificatori("costo_energia", attivo())
	var c := n
	var minimo := 0
	for m in mods:
		c += int(m.get("n", 0))
		minimo = maxi(minimo, int(m.get("min", 0)))
	return maxi(minimo, c)

## Il tratto di un nemico è ignorato per effetto di una carta?
func tratto_ignorato(t: String) -> bool:
	for m in modificatori("ignora_tratto"):
		if str(m.get("tratto", "")).to_lower().begins_with(t.to_lower().substr(0, 5)):
			return true
	return false

## Guardiani sulla mappa: [{img, colore, luogo}] (converte i salvataggi vecchi).
static func guardiani(partita) -> Array:
	var gl = partita.d.get("guardiani", [])
	if gl is Dictionary:
		var nuova := []
		for k in gl:
			nuova.append({"img": gl[k], "colore": "", "luogo": int(k)})
		gl = nuova
	partita.d["guardiani"] = gl
	return gl

func guardiani_in(n: int) -> Array:
	return Partita.guardiani(self).filter(func(g): return int(g.get("luogo", 0)) == n)

## Carta "Stai morendo" / "Stai impazzendo" adatta al numero di giocatori (parola: "morendo"/"impazzendo").
func carta_stato(parola: String) -> String:
	var scelta := ""
	for g in ["morente", "follia"]:
		for img in Carte.gruppo(g):
			if Carte.nome(img).to_lower().find(parola) < 0:
				continue
			var mod := str(Carte.dati(img).get("modalita", ""))
			var solo := mod.begins_with("solit") or Carte.nome(img).to_lower().find("solitari") >= 0
			if scelta == "" or (solo == (personaggi().size() == 1)):
				scelta = img
	return scelta
