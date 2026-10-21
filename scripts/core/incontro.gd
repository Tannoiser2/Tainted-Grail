## Motore degli Incontri (regole §6): Combattimento e Diplomazia con la Sequenza di carte a Chiavi.
##
## La carta Incontro fa da "carta 0": la prima carta giocata si collega alle Chiavi del suo bordo
## destro. Ogni carta ha 4 righe di Chiavi + una riga in fondo; una Chiave si collega quando la
## semichiave destra della carta precedente (attributo o Magia) e quella sinistra della nuova (bonus)
## sono nella stessa riga e il personaggio attivo ha l'attributo richiesto (o paga 1 Magia).
## La riga in fondo si collega sempre: bonus × moltiplicatore della carta precedente.
class_name Incontro
extends RefCounted

signal cambiato
signal messaggio(testo: String)
signal finito(esito: String)

var partita: Partita
var img: String
var carta: Dictionary
var colore: String
var diplomazia := false
var membri: Array = []            # personaggi coinvolti (dizionari della partita)
var mani := {}                    # id -> [img]
var mazzi := {}                   # id -> [img] (mazzo dell'Incontro: copia del mazzo del personaggio)
var scarti := {}                  # id -> [img]
var sequenza: Array = []          # [{img, tempo, magia, pid}]
var riserva := 0
var affinita := 0
var fase := 0
var fasi_vinte := 0
var attivo_id := ""
var attivati: Array = []
var turno := 1
var carte_attivazione := 0
var extra_disponibili := 0
var prevenzione := 0
var meno_cubi := 0
var primo_attivato := true
var concluso := ""
var paga_magia := true
var registro: Array = []

func _init(partita_: Partita, img_: String, colore_: String) -> void:
	partita = partita_
	img = img_
	carta = Carte.dati(img)
	colore = colore_
	diplomazia = colore == "blu" or str(carta.get("sottotipo", "")) == "diplomazia"

## --- Preparazione --------------------------------------------------------------------

func speciale() -> bool:
	return carta.get("speciale", false) or (not carta.has("valore") and not carta.has("fasi"))

func tratti() -> Array:
	return carta.get("tratti", [])

func ha_tratto(t: String) -> bool:
	for x in tratti():
		if str(x).to_lower().begins_with(t.to_lower()):
			return true
	return false

func inizia(compagnia: Array) -> void:
	membri = compagnia.duplicate()
	var tipo := "diplomazia" if diplomazia else "combattimento"
	var n_mano := 2 if partita.personaggi().size() >= 4 else 3
	if ha_tratto("Lento"):
		n_mano += 1
	for p in membri:
		var id := str(p["id"])
		var m: Array = p["mazzi"][tipo]["mazzo"].duplicate()
		m.shuffle()
		mazzi[id] = m
		scarti[id] = []
		mani[id] = []
		for i in n_mano:
			pesca(id)
	nota("Inizia %s: %s (%s)" % ["la Diplomazia" if diplomazia else "il Combattimento", Carte.nome(img), ", ".join(tratti()) if not tratti().is_empty() else "nessun tratto"])

func nota(t: String) -> void:
	registro.append(t)
	messaggio.emit(t)

func personaggio(id: String) -> Dictionary:
	for p in membri:
		if str(p["id"]) == id:
			return p
	return {}

func attivo() -> Dictionary:
	return personaggio(attivo_id)

func pesca(id: String, n := 1) -> int:
	var k := 0
	for i in n:
		if mazzi[id].is_empty():
			break
		mani[id].append(mazzi[id].pop_front())
		k += 1
	return k

## Mulligan: scarta la mano e ne pesca una con 1 carta in meno.
func rimescola_mano(id: String) -> void:
	var n: int = mani[id].size() - 1
	if n < 1:
		return
	mazzi[id].append_array(mani[id])
	mani[id].clear()
	mazzi[id].shuffle()
	pesca(id, n)
	cambiato.emit()

## --- Attivazione ------------------------------------------------------------------

func da_attivare() -> Array:
	return membri.filter(func(p): return not attivati.has(str(p["id"])) and int(p["salute"]) > 0)

func attiva(id: String) -> void:
	attivo_id = id
	attivati.append(id)
	carte_attivazione = 0
	extra_disponibili = 0
	prevenzione = 0
	meno_cubi = 0
	nota("Si attiva %s." % attivo()["nome"])
	if primo_attivato:
		primo_attivato = false
		if ha_tratto("Imbosc"):
			while mani[id].size() > 1:
				scarti[id].append(mani[id].pop_back())
			nota("Imboscata: %s scarta fino ad avere 1 carta." % attivo()["nome"])
		if ha_tratto("Improvv"):
			_ferite(2, false)
			nota("Improvviso: 2 Ferite a %s." % attivo()["nome"])
	# 1. Capacità ritardate: −1 gettone Tempo su ogni carta della Sequenza
	for s in sequenza:
		if int(s.get("tempo", 0)) > 0:
			s["tempo"] = int(s["tempo"]) - 1
			if s["tempo"] == 0 and sequenza.back() == s:
				for cap in _capacita(str(s["img"])):
					if str(cap.get("innesco", "")) == "ritardata":
						nota("Capacità ritardata di %s." % Carte.nome(str(s["img"])))
						applica_testo(str(cap.get("it", "")))
	cambiato.emit()

## Il personaggio attivo è in Panico: la prima carta è quella in cima al mazzo.
func in_panico() -> bool:
	return Personaggi.in_panico(attivo())

## Capacità di una carta (lista).
func _capacita(c: String) -> Array:
	var x = Carte.dati(c).get("capacita")
	if x is Array:
		return x
	if x is Dictionary:
		return [x]
	return []

## Semichiavi destre dell'ultima carta della Sequenza (o della carta Incontro).
func _aperture() -> Dictionary:
	var righe := {}
	var molt = null
	if sequenza.is_empty():
		for k in carta.get("chiavi_destra", []):
			righe[int(k.get("riga", 0))] = {"apre": k.get("apre"), "liv": int(k.get("liv", k.get("livello", 1)))}
		molt = carta.get("fondo_molt")
	else:
		var d := Carte.dati(str(sequenza.back()["img"]))
		for k in d.get("chiavi", []):
			righe[int(k.get("riga", 0))] = {"apre": k.get("apre"), "liv": int(k.get("liv", k.get("livello", 1)))}
		molt = d.get("fondo", {}).get("molt")
	return {"righe": righe, "molt": molt}

static func _moltiplicatore(m) -> int:
	if m == null:
		return 0
	var s := str(m).to_lower()
	if s == "x" or s == "✖":
		return 0
	var r := RegEx.create_from_string("(\\d+)").search(s)
	return int(r.get_string(1)) if r else 1

static func _lista(b) -> Array:
	if b == null:
		return []
	if b is Array:
		return b
	return [b]

## Collegamenti che la carta c otterrebbe se giocata ora:
## [{riga, bonus:[...], tipo: "attributo"|"magia"|"fondo", attr, ok, molt}]
func collegamenti(c: String) -> Array:
	var d := Carte.dati(c)
	var ap := _aperture()
	var out := []
	for k in d.get("chiavi", []):
		var r := int(k.get("riga", 0))
		var b := _lista(k.get("bonus"))
		if b.is_empty() or not ap["righe"].has(r):
			continue
		var prev: Dictionary = ap["righe"][r]
		var a = prev.get("apre")
		if a == null:
			continue
		var cornice := str(k.get("cornice", "attributo"))
		if str(a) == "magic" or cornice == "magia":
			if str(a) == "magic" and cornice == "magia":
				out.append({"riga": r, "bonus": b, "tipo": "magia", "attr": "magic", "ok": _magia_disponibile() > 0})
			continue
		var liv := int(prev.get("liv", 1))
		out.append({"riga": r, "bonus": b, "tipo": "attributo", "attr": str(a), "ok": partita.attributo(attivo(), str(a)) >= liv, "liv": liv})
	var fb := _lista(d.get("fondo", {}).get("bonus"))
	if not fb.is_empty():
		out.append({"riga": 5, "bonus": fb, "tipo": "fondo", "attr": "", "ok": true, "molt": _moltiplicatore(ap["molt"])})
	return out

func _magia_disponibile() -> int:
	var t := 0
	for p in membri:
		t += int(p.get("magia", 0))
	return t

## La carta si può giocare ora? (prima carta: sempre; poi serve una Chiave "extra" collegata)
func giocabile(c: String) -> bool:
	if concluso != "" or attivo_id == "":
		return false
	if carte_attivazione == 0:
		return true
	if ha_tratto("Rapid") and carte_attivazione >= 2:
		return false
	for k in collegamenti(c):
		if k["ok"] and k["bonus"].has("extra") and (k["tipo"] != "magia" or paga_magia):
			return true
	return false

## Gioca una carta dalla mano del personaggio attivo (o dalla cima del mazzo in Panico).
func gioca(c: String) -> void:
	var id := attivo_id
	if mani[id].has(c):
		mani[id].erase(c)
	elif not mazzi[id].is_empty() and mazzi[id][0] == c:
		mazzi[id].pop_front()
	var cols := collegamenti(c)
	var prima := carte_attivazione == 0
	# la carta precedente viene coperta: se aveva gettoni Tempo, si scartano
	if not sequenza.is_empty():
		sequenza.back()["tempo"] = 0
	sequenza.append({"img": c, "tempo": 0, "magia": 0, "pid": id})
	carte_attivazione += 1
	nota("%s gioca %s." % [attivo()["nome"], Carte.nome(c)])
	var cubi := 0
	for k in cols:
		if not k["ok"]:
			continue
		if k["tipo"] == "magia":
			if not paga_magia:
				continue
			_paga_magia()
			sequenza.back()["magia"] = int(sequenza.back()["magia"]) + 1
		var molt := int(k.get("molt", 1)) if k["tipo"] == "fondo" else 1
		for b in k["bonus"]:
			cubi += _bonus(str(b), molt, str(k.get("attr", "")), prima)
	if prima and ha_tratto("Difens") and cubi > 0 and not diplomazia:
		riserva = maxi(0, riserva - 1)
		nota("Difensivo: un segnalino in meno.")
	# Capacità "al piazzarla" (dopo i bonus delle Chiavi) o ritardata (gettone Tempo)
	for cap in _capacita(c):
		match str(cap.get("innesco", "")):
			"piazza":
				applica_testo(str(cap.get("it", "")))
			"ritardata":
				sequenza.back()["tempo"] = maxi(1, int(cap.get("tempo", 1)))
	_controlla_fine_carte()
	cambiato.emit()

func _paga_magia() -> void:
	var a := attivo()
	if int(a.get("magia", 0)) > 0:
		partita.modifica(a, "magia", -1)
		return
	for p in membri:
		if int(p.get("magia", 0)) > 0:
			partita.modifica(p, "magia", -1)
			return

## Applica un bonus di Chiave. Restituisce i segnalini aggiunti.
func _bonus(b: String, molt: int, attr: String, prima: bool) -> int:
	if molt == 0:
		return 0
	var m := RegEx.create_from_string("^([a-z]+?)(\\d*)$").search(b)
	var nome := m.get_string(1) if m else b
	var n := (int(m.get_string(2)) if m and m.get_string(2) != "" else 1) * molt
	match nome:
		"cube":
			if diplomazia:
				return 0
			riserva += n
			nota("+%d alla Riserva (%d)." % [n, riserva])
			return n
		"draw":
			pesca(attivo_id, n)
			nota("Pesca %d carta." % n)
		"extra":
			if not prima:
				extra_disponibili += 1
		"discard":
			_scarta_ultima()
		"arrowup":
			_affinita(n)
		"arrowdown":
			_affinita(-n)
		"special":
			_speciale(attr)
	return 0

func _scarta_ultima() -> void:
	if sequenza.is_empty():
		return
	var s: Dictionary = sequenza.pop_back()
	scarti[str(s.get("pid", attivo_id))].append(s["img"])
	nota("Scartata l'ultima carta della Sequenza (%s)." % Carte.nome(str(s["img"])))

func _affinita(n: int) -> void:
	if not diplomazia:
		return
	affinita += n
	nota("Affinità %+d → %d." % [n, affinita])

## Bonus speciale (triquetra) della fase attuale per l'attributo della Chiave collegata.
func _speciale(attr: String) -> void:
	var fs: Array = carta.get("fasi", [])
	if fs.is_empty() or attr == "":
		return
	var f: Dictionary = fs[clampi(fase, 0, fs.size() - 1)]
	var sp = f.get("speciale", {}).get(attr)
	if sp == null:
		nota("Bonus speciale: nessun effetto per %s in questa fase." % Partita.NOMI_ATTRIBUTI.get(attr, attr))
		return
	var t := str(sp.get("it", sp)) if sp is Dictionary else str(sp)
	nota("Bonus speciale (%s): %s" % [Partita.NOMI_ATTRIBUTI.get(attr, attr), Dati.testo_piano(t)])
	applica_testo(t)

## --- Effetti testuali (Capacità, tabelle, Risposte) -----------------------------------

## Applica un testo di effetto di Combattimento/Diplomazia al personaggio attivo.
## Restituisce le parti non riconosciute.
func applica_testo(t: String, attacco := false) -> Array:
	var l := Dati.testo_piano(t).to_lower().replace("↑", "@arrowup@").replace("↓", "@arrowdown@")
	var resto := []
	var finta := ha_tratto("Finta") and attacco
	for parte in l.split(","):
		var s := parte.strip_edges()
		if s == "":
			continue
		var fatto := false
		var mf := RegEx.create_from_string("(?:^|\\s)(\\d+)?\\s*@wound(inevitable)?@(.*inevitabil)?").search(s)
		if mf and s.find("previen") < 0:
			var n := int(mf.get_string(1)) if mf.get_string(1) != "" else 1
			_ferite(n, attacco and not finta and mf.get_string(2) == "" and mf.get_string(3) == "")
			fatto = true
		var mp := RegEx.create_from_string("previen\\w*\\s+(\\d+)\\s*@wound@").search(s)
		if mp:
			prevenzione += int(mp.get_string(1))
			nota("Previeni %s Ferite." % mp.get_string(1))
			fatto = true
		var mc := RegEx.create_from_string("(perd\\w*|ottien\\w*|aggiung\\w*)\\s*(\\d+)?\\s*@cube(\\d)?@(\\s*in meno)?").search(s)
		if mc and not diplomazia:
			var n := (int(mc.get_string(2)) if mc.get_string(2) != "" else 1) * (int(mc.get_string(3)) if mc.get_string(3) != "" else 1)
			if mc.get_string(4) != "":
				meno_cubi += n
				nota("Perdi %d segnalini in meno." % n)
			elif mc.get_string(1).begins_with("perd"):
				_perdi_cubi(maxi(0, n - meno_cubi))
			else:
				riserva += n
				nota("+%d alla Riserva (%d)." % [n, riserva])
			fatto = true
		var md := RegEx.create_from_string("(\\d+)?\\s*@discard@").search(s)
		if md and attacco:
			var n := int(md.get_string(1)) if md.get_string(1) != "" else 1
			_scarta_mano(n)
			fatto = true
		var su := s.count("@arrowup@")
		var giu := s.count("@arrowdown@")
		if su + giu > 0 and diplomazia:
			_affinita(su - giu)
			fatto = true
		if attacco and (s.begins_with("fugg") or s.begins_with("huir") or s.begins_with("il nemico fugge")):
			concludi("fuga_nemico")
			fatto = true
		var mpes := RegEx.create_from_string("pesca\\s+(\\d+|una|un)\\s+cart").search(s)
		if mpes:
			pesca(attivo_id, 1 if mpes.get_string(1) in ["una", "un"] else int(mpes.get_string(1)))
			fatto = true
		for ris in ["energy", "health", "terror"]:
			var mr := RegEx.create_from_string("(perd\\w*|ottien\\w*|recuper\\w*)\\s+(\\d+)\\s*@" + ris + "@").search(s)
			if mr:
				var nome: String = {"energy": "energia", "health": "salute", "terror": "terrore"}[ris]
				var dlt := int(mr.get_string(2)) * (-1 if mr.get_string(1).begins_with("perd") else 1)
				partita.modifica(attivo(), nome, dlt)
				nota("%s %+d %s." % [attivo()["nome"], dlt, Partita.NOMI_RISORSE[nome]])
				fatto = true
		for ris2 in ["ricchezza", "cibo", "magia", "esp", "rep"]:
			var mr2 := RegEx.create_from_string("(perd\\w*|ottien\\w*)\\s+(\\d+)\\s*" + ris2).search(s)
			if mr2:
				var dlt2 := int(mr2.get_string(2)) * (-1 if mr2.get_string(1).begins_with("perd") else 1)
				partita.modifica(attivo(), ris2, dlt2)
				fatto = true
		if not fatto:
			resto.append(parte.strip_edges())
	if not resto.is_empty():
		nota("Da applicare a mano: " + ", ".join(resto))
	_controlla_vita()
	cambiato.emit()
	return resto

func _ferite(n: int, prevenibili := true) -> void:
	var p := attivo()
	var nn := n
	if prevenibili and prevenzione > 0:
		var x := mini(prevenzione, nn)
		nn -= x
		prevenzione -= x
		if x > 0:
			nota("%d Ferite prevenute." % x)
	if nn > 0:
		partita.modifica(p, "salute", -nn)
		nota("%s subisce %d Ferite (Salute %d)." % [p["nome"], nn, int(p["salute"])])

func _perdi_cubi(n: int) -> void:
	var resto := n - riserva
	riserva = maxi(0, riserva - n)
	nota("−%d segnalini (Riserva %d)." % [n, riserva])
	if resto > 0:
		_scarta_mano(resto)

func _scarta_mano(n: int) -> void:
	var id := attivo_id
	for i in n:
		if not mani[id].is_empty():
			scarti[id].append(mani[id].pop_back())
		elif not mazzi[id].is_empty():
			scarti[id].append(mazzi[id].pop_front())
	nota("%s scarta %d carta." % [attivo()["nome"], n])

func _controlla_vita() -> void:
	var p := attivo()
	if not p.is_empty() and int(p["salute"]) <= 0 and concluso == "":
		nota("%s sta morendo ed esce dall'Incontro!" % p["nome"])
		membri.erase(p)
		if membri.is_empty():
			concludi("morte")

## --- Fine della fase di gioco e attacco nemico --------------------------------------

func _controlla_fine_carte() -> void:
	if concluso != "":
		return
	if diplomazia:
		_controlla_affinita()
	elif riserva >= int(carta.get("valore", 99)):
		concludi("vittoria")

func _controlla_affinita() -> bool:
	var a: Dictionary = carta.get("affinita", {})
	var verdi := int(a.get("verdi", 3))
	var rossi := int(a.get("rossi", 3))
	if affinita >= verdi:
		fasi_vinte += 1
		var fs: Array = carta.get("fasi", [])
		if fase + 1 >= fs.size():
			concludi("vittoria")
		else:
			fase += 1
			affinita = 0
			nota("Fase vinta! Si passa alla fase %d." % (fase + 1))
		return true
	if affinita <= -rossi:
		concludi("fallimento")
		return true
	return false

## Fine delle carte dell'attivazione: Opportunità (Combattimento), poi attacco o Risposta.
func termina_carte() -> void:
	if concluso != "":
		return
	if not diplomazia:
		var min_carte := 2 if ha_tratto("Opportun") else 1
		if carte_attivazione < min_carte:
			nota("Attacco di opportunità: " + Dati.testo_piano(str(carta.get("opportunita", {}).get("it", ""))))
			applica_testo(str(carta.get("opportunita", {}).get("it", "")), true)
			if carte_attivazione == 0:
				pesca(attivo_id)
		if concluso == "" and riserva >= int(carta.get("valore", 99)):
			concludi("vittoria")
			return
		if concluso == "":
			var volte := 2 if ha_tratto("Furia") else 1
			for i in volte:
				_attacco()
				if concluso != "":
					break
			if ha_tratto("Orda") and concluso == "":
				for i in 2:
					if not mazzi[attivo_id].is_empty():
						scarti[attivo_id].append(mazzi[attivo_id].pop_front())
				nota("Orda: scartate le 2 carte in cima al mazzo.")
			if concluso == "" and riserva >= int(carta.get("valore", 99)):
				concludi("vittoria")
	else:
		var fase_vinta := _controlla_affinita()
		if concluso == "" and not fase_vinta:
			var fs: Array = carta.get("fasi", [])
			if not fs.is_empty():
				var r = fs[clampi(fase, 0, fs.size() - 1)].get("risposta", {})
				var t := str(r.get("it", "")) if r is Dictionary else str(r)
				nota("Risposta: " + Dati.testo_piano(t))
				applica_testo(t, true)
				_controlla_affinita()
	cambiato.emit()

## Riga della tabella per il numero di segnalini nella Riserva.
func riga_tabella() -> Dictionary:
	for r in carta.get("tabella", []):
		if riserva >= int(r.get("da", 0)) and riserva <= int(r.get("a", 99)):
			return r
	return {}

func _attacco() -> void:
	var r := riga_tabella()
	if r.is_empty():
		return
	# Capacità visibile "durante l'attacco" (ultima carta della Sequenza)
	if not sequenza.is_empty():
		for cap in _capacita(str(sequenza.back()["img"])):
			if str(cap.get("innesco", "")) == "attacco":
				applica_testo(str(cap.get("it", "")))
	nota("Attacco nemico (Riserva %d): %s" % [riserva, Dati.testo_piano(str(r.get("it", "")))])
	applica_testo(str(r.get("it", "")), true)

## Fine del turno: si scarta fino a 3, si pesca 1 (non in Panico; +1 se Lento), nuovo turno.
func fine_turno() -> void:
	for p in membri:
		var id := str(p["id"])
		while mani[id].size() > 3:
			scarti[id].append(mani[id].pop_back())
		if not Personaggi.in_panico(p):
			var n := 2 if ha_tratto("Lento") else 1
			if pesca(id, n) < n:
				if diplomazia:
					concludi("fallimento")
				else:
					nota("%s non ha più carte: deve Scappare." % p["nome"])
	attivati.clear()
	attivo_id = ""
	turno += 1
	nota("— Turno %d —" % turno)
	cambiato.emit()

## Scappare (chi è attivo): −1 Energia e attacco di opportunità; esce dall'Incontro.
func scappa() -> void:
	var p := attivo()
	if p.is_empty():
		p = membri[0]
		attivo_id = str(p["id"])
	if diplomazia:
		concludi("fallimento")
		return
	partita.modifica(p, "energia", -1)
	applica_testo(str(carta.get("opportunita", {}).get("it", "")), true)
	nota("%s Scappa." % p["nome"])
	membri.erase(p)
	if membri.is_empty() and concluso == "":
		concludi("fuga")

## Evitare (solo Diplomazia, prima di iniziare).
func evita() -> void:
	var e = carta.get("evitare")
	if e is Dictionary:
		Effetti.paga_costo("Pagare " + Dati.testo_piano(str(e.get("it", ""))).to_lower().trim_prefix("pagare ").trim_prefix("paga "), partita)
	concludi("evitato")

func concludi(esito: String) -> void:
	if concluso != "":
		return
	concluso = esito
	var tutti := partita.compagnia()
	match esito:
		"vittoria":
			nota("VITTORIA!")
			var ric = carta.get("ricompensa")
			if ric is Dictionary and str(ric.get("it", "")) != "":
				for p in tutti:
					partita.d["attivo"] = partita.personaggi().find(p)
					Effetti.applica(str(ric["it"]), partita)
				nota("Ricompensa a ogni membro: " + Dati.testo_piano(str(ric["it"])))
			var bot = carta.get("bottino")
			if bot is Dictionary and str(bot.get("it", "")) != "":
				Effetti.applica(str(bot["it"]), partita)
				nota("Bottino: " + Dati.testo_piano(str(bot["it"])))
			partita.racconta("Incontro vinto: " + Carte.nome(img))
		"fallimento":
			nota("FALLIMENTO.")
			var f = carta.get("fallimento")
			if f is Dictionary and str(f.get("it", "")) != "":
				for p in tutti:
					partita.d["attivo"] = partita.personaggi().find(p)
					Effetti.applica(str(f["it"]), partita)
			partita.racconta("Incontro fallito: " + Carte.nome(img))
		"fuga_nemico":
			nota("Il nemico fugge: nessun bottino.")
			partita.racconta("Il nemico è fuggito: " + Carte.nome(img))
		"fuga":
			nota("La Compagnia è scappata.")
			partita.racconta("Fuga dall'Incontro: " + Carte.nome(img))
		"evitato":
			partita.racconta("Incontro evitato: " + Carte.nome(img))
		"morte":
			partita.racconta("La Compagnia è caduta in " + Carte.nome(img))
	cambiato.emit()
	finito.emit(esito)

## Guardiano non sconfitto: resta sulla mappa nel Luogo.
func guardiano_resta() -> bool:
	return (carta.get("guardiano", false) or ha_tratto("Guardian")) and concluso in ["fuga", "morte"]
