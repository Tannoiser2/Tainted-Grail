## Motore del Diario di Esplorazione (e del Libro dei Segreti): navigazione fra Luoghi e versi
## come nell'app ufficiale, con le condizioni verificate sullo stato della partita.
##
## Ogni verso ha elementi di tre tipi:
##   0 = testo narrativo
##   1 = condizione o prosecuzione ("Se avete lo status…", "Continua.", fasce del dado "4-5")
##   2 = scelta del giocatore (azione)
## Ogni elemento ha uno o più esiti {l, v, q, r}: l/v = Luogo e verso di destinazione (assenti:
## fine dell'Esplorazione), q = requisito o costo, r = risultato da applicare.
class_name MotoreDiario
extends RefCounted

var camp: int
var stato: Dictionary          # salvato nella campagna: corrente, cronologia, visitati, usate
var partita                    # Partita oppure null (Diario libero)

func _init(camp_: int, stato_: Dictionary, partita_ = null) -> void:
	camp = camp_
	stato = stato_
	partita = partita_
	for k in ["visitati", "usate"]:
		if not (stato.get(k) is Dictionary):
			stato[k] = {}
	if not (stato.get("cronologia") is Array):
		stato["cronologia"] = []

## --- Navigazione ----------------------------------------------------------------

func id_luogo() -> int:
	return int(stato.get("luogo", 0))

func id_verso() -> int:
	return int(stato.get("verso", 0))

func luogo() -> Dictionary:
	return Dati.luogo(camp, id_luogo())

func verso() -> Dictionary:
	return luogo().get("versi", {}).get(str(id_verso()), {})

func aperto() -> bool:
	return id_luogo() != 0 and not verso().is_empty()

## Apre un Luogo per numero (101, 999 = Libro dei Segreti…). Restituisce false se non esiste.
func apri_numero(numero: int, verso_numero := -1) -> bool:
	var id := Dati.id_numero(camp, numero)
	if id == 0:
		return false
	var l := Dati.luogo(camp, id)
	var v := int(l.get("inizio", 0))
	if verso_numero >= 0:
		for k in l.get("versi", {}):
			if int(l["versi"][k].get("d", -1)) == verso_numero:
				v = int(k)
				break
	vai(id, v)
	return true

## Segreto del Libro dei Segreti (Luogo 999), verso = numero del Segreto.
func apri_segreto(numero: int) -> bool:
	return apri_numero(999, numero)

func vai(id_l: int, id_v: int) -> void:
	if id_l == 0:
		id_l = id_luogo()
	stato["luogo"] = id_l
	stato["verso"] = id_v
	stato["visitati"][str(id_v)] = int(stato["visitati"].get(str(id_v), 0)) + 1
	var cr: Array = stato["cronologia"]
	cr.append([id_l, id_v])
	if cr.size() > 300:
		cr.pop_front()

## Torna al verso precedente (correzione di un clic sbagliato).
func indietro() -> bool:
	var cr: Array = stato["cronologia"]
	if cr.size() < 2:
		return false
	cr.pop_back()
	var p: Array = cr[-1]
	stato["luogo"] = int(p[0])
	stato["verso"] = int(p[1])
	return true

func chiudi() -> void:
	stato["luogo"] = 0
	stato["verso"] = 0

func visitato(id_v: int) -> bool:
	return int(stato["visitati"].get(str(id_v), 0)) > 0

## --- Elementi del verso ------------------------------------------------------------

## Testi narrativi del verso, nell'ordine.
func testi() -> Array:
	var out := []
	for e in verso().get("e", []):
		if int(e.get("t", 0)) == 0 and str(e.get("x", "")) != "":
			out.append(e["x"])
	return out

## Elementi con esiti (condizioni e scelte) nell'ordine del Diario.
## Ogni voce: {tipo, testo, esiti:[{l,v,q,r, valida}], valida}
## valida: true/false se la condizione si può verificare, null se va giudicata dal giocatore.
func opzioni() -> Array:
	var out := []
	var tiro := tiro_richiesto()
	for e in verso().get("e", []):
		var t := int(e.get("t", 0))
		if t == 0 and not e.has("c"):
			continue
		var voce := {"tipo": t, "testo": str(e.get("x", "")), "esiti": [], "valida": null}
		if t == 1:
			voce["valida"] = _valuta("c:", str(e.get("x", "")), tiro)
		for c in e.get("c", []):
			var es: Dictionary = c.duplicate()
			es["valida"] = _valuta("q:", str(c.get("q", "")), tiro) if str(c.get("q", "")) != "" else null
			voce["esiti"].append(es)
		out.append(voce)
	return out

## Contesto per l'interprete: tiro del verso ed esito dell'ultimo Incontro chiesto dal Diario.
func contesto() -> Dictionary:
	var ctx := {"in_diario": true, "luogo": int(luogo().get("n", 0))}
	if stato.get("tiro_verso", 0) == id_verso() and stato.has("tiro"):
		ctx["tiro"] = int(stato["tiro"])
	if stato.has("esito_incontro"):
		ctx["esito_incontro"] = str(stato["esito_incontro"])
	return ctx

## Condizione di un elemento: prima la versione codificata (data/automazione.json), poi la lettura
## del testo con le regole di Condizioni. true/false oppure null (da giudicare al tavolo).
func _valuta(prefisso: String, testo: String, tiro: Dictionary):
	if partita != null:
		var a := Dati.auto_diario(prefisso, testo)
		if a.get("condizione") is Dictionary:
			return Interprete.new(partita, null, null, contesto()).valuta(a["condizione"])
		if not a.is_empty() and prefisso == "q:":
			return null if not a.has("costo") else _pagabile(a["costo"])
	return Condizioni.valuta(testo, partita, tiro)

## Un costo codificato è pagabile? (solo i passi "paga" semplici; le scelte restano da decidere)
func _pagabile(costo) -> Variant:
	if not (costo is Array):
		return null
	for c in costo:
		if c is Dictionary and str(c.get("tipo", "")) == "paga":
			var n := int(c.get("n", 0))
			if c.get("per") is Dictionary and c["per"].has("giocatori"):
				n *= partita.personaggi().size()
			if not partita.puo_pagare(str(c.get("ris", "")), n, str(c.get("chi", "")) == "compagnia"):
				return false
	return true

## Se il verso chiede di tirare un dado, restituisce {"mod": [...] descrizione dei modificatori};
## altrimenti {}.
func tiro_richiesto() -> Dictionary:
	if stato.get("tiro_verso", 0) == id_verso() and stato.has("tiro"):
		return {"valore": int(stato["tiro"])}
	if not dado_codificato().is_empty():
		return {"da_tirare": true}
	var tutto := " ".join(testi())
	for e in verso().get("e", []):
		tutto += " " + str(e.get("x", ""))
	var p := Dati.testo_piano(tutto).to_lower()
	if p.find("tira") >= 0 and (p.find("dado") >= 0 or p.find("dadi") >= 0):
		return {"da_tirare": true}
	return {}

## Fasce del risultato ("1-3", "4-5", "6+", "Il vostro risultato è stato: 2-4") presenti fra le opzioni.
func ha_fasce() -> bool:
	if not dado_codificato().is_empty():
		return true
	for o in opzioni():
		if Condizioni.fascia(o["testo"]).size() > 0:
			return true
		for es in o["esiti"]:
			if Condizioni.fascia(str(es.get("q", ""))).size() > 0:
				return true
	return false

## Passo "dado" codificato per il verso (dal testo del verso o da una sua condizione), {} se assente.
func dado_codificato() -> Dictionary:
	var fonti := [Dati.auto_verso(id_verso())]
	for e in verso().get("e", []):
		if int(e.get("t", 0)) == 1:
			fonti.append(Dati.auto_diario("c:", str(e.get("x", ""))))
	for f in fonti:
		for s in f.get("effetti", []):
			if s is Dictionary and str(s.get("tipo", "")) == "dado":
				return s
	return {}

## Modificatore del tiro: {"valore", "testo"} dalla codifica o dal testo del verso.
func modificatore_tiro() -> Dictionary:
	var d := dado_codificato()
	if not d.is_empty() and partita != null:
		var it := Interprete.new(partita, null, null, contesto())
		var v := it.modificatore_dado(d.get("mod", []))
		var parti := []
		for m in d.get("mod", []):
			if m is Dictionary and m.has("attr"):
				parti.append(Partita.NOMI_ATTRIBUTI.get(str(m["attr"]), str(m["attr"])) + ((" ×%s" % str(m["per"])) if m.has("per") and float(m["per"]) != 1.0 else ""))
			elif m is Dictionary and m.has("n"):
				parti.append("%+d" % int(m["n"]))
			elif m is Dictionary:
				parti.append(str(m.get("ris", m.get("parti_status", ""))))
		return {"valore": v, "testo": ", ".join(parti)}
	return Effetti.modificatore_tiro(self, partita)

## Registra il risultato del tiro di dado per il verso corrente (le fasce si valutano da sole).
func imposta_tiro(valore: int) -> void:
	stato["tiro"] = valore
	stato["tiro_verso"] = id_verso()

## Il giocatore segue un esito: restituisce {"fine": bool, "risultato": testo da applicare}.
func segui(esito: Dictionary) -> Dictionary:
	var chiave := "%d:%s" % [id_verso(), str(esito.get("id", hash(esito)))]
	stato["usate"][chiave] = true
	var r := str(esito.get("r", ""))
	var l := int(esito.get("l", 0))
	var v := int(esito.get("v", 0))
	if v != 0:
		vai(l, v)
		return {"fine": false, "risultato": r}
	return {"fine": true, "risultato": r}
