## Lettura delle condizioni scritte nel Diario ("Se avete la parte 2 dello status “Canto Funebre”",
## "Richiede la carta Segreto 66", "Pagare 2 {i:energy}", "4-5"...) e verifica sullo stato della partita.
## valuta() restituisce true/false quando sa rispondere, null quando deve decidere il giocatore.
class_name Condizioni
extends RefCounted

const ATTRIBUTI := ["aggression", "courage", "practicality", "spirituality", "caution", "empathy"]

static func _piano(t: String) -> String:
	return Dati.testo_piano(t).replace("’", "'").replace("“", "\"").replace("”", "\"").replace("«", "\"").replace("»", "\"").strip_edges()

## Fascia di risultato del dado: [min, max] (max = 99 per "6+"), [] se il testo non è una fascia.
static func fascia(testo: String) -> Array:
	var p := _piano(testo).to_lower()
	var rx := RegEx.create_from_string("^(?:se )?(?:il (?:tuo|vostro) (?:risultato|resultato)(?: è stato| e stato)?:?\\s*|risultato:?\\s*)?(\\d+)\\s*(?:-|–|—)\\s*(\\d+)|^(?:se )?(?:il (?:tuo|vostro) (?:risultato|resultato)(?: è stato| e stato)?:?\\s*)?(\\d+)\\s*\\+|^(?:se )?(?:il (?:tuo|vostro) (?:risultato|resultato)(?: è stato| e stato)?:?\\s*)(\\d+)\\b|^(\\d+)\\s*[.:]?$")
	var m := rx.search(p)
	if m == null:
		return []
	if m.get_string(1) != "":
		return [int(m.get_string(1)), int(m.get_string(2))]
	if m.get_string(3) != "":
		return [int(m.get_string(3)), 99]
	var n := m.get_string(4) if m.get_string(4) != "" else m.get_string(5)
	return [int(n), int(n)]

## Verifica una condizione. partita può essere null (Diario libero): allora solo fasce del dado.
static func valuta(testo: String, partita, tiro: Dictionary = {}):
	var p := _piano(testo)
	var low := p.to_lower()
	if low == "" or low.begins_with("continua") or low.begins_with("continue") or low == "verificare il risultato." or low.begins_with("verifica"):
		return true
	var f := fascia(p)
	if f.size() == 2:
		if tiro.has("valore"):
			var v := int(tiro["valore"])
			return v >= int(f[0]) and v <= int(f[1])
		return null
	if partita == null:
		return null
	# più clausole unite da " e " / ";": tutte vere, una falsa basta a escludere
	var esito = true
	var riconosciuta := false
	for cl in _clausole(low):
		var r = _clausola(cl, partita)
		if r == null:
			continue
		riconosciuta = true
		if r == false:
			return false
	return esito if riconosciuta else null

static func _clausole(low: String) -> Array:
	# separa "Se avete lo status "X" e non avete la parte 2 dello status "Y"" in due clausole
	var out := []
	var rx := RegEx.create_from_string("\\s+e\\s+(?=(?:non\\s+)?(?:avete|ha |hai |la parte|lo status|la carta|il capitolo|almeno|richiede))|;\\s*|,\\s*(?=(?:non\\s+)?avete)")
	var k := 0
	for m in rx.search_all(low):
		out.append(low.substr(k, m.get_start() - k))
		k = m.get_end()
	out.append(low.substr(k))
	# la negazione all'inizio vale anche per le clausole successive senza verbo ("non avete la parte 1 e la parte 2")
	return out

static func _clausola(cl: String, partita):
	var neg := cl.find("non avete") >= 0 or cl.find("non hai") >= 0 or cl.find("non ha ") >= 0 or cl.begins_with("solo se non")
	# --- status ---
	var rs := RegEx.create_from_string("status\\s+\"([^\"]+)\"")
	var ms := rs.search(cl)
	if ms:
		var nome := ms.get_string(1).strip_edges()
		var parti: Array = partita.parti_status(nome)
		var ok: bool
		var mp := RegEx.create_from_string("part[ie]\\s+((?:\\d+(?:\\s*(?:,|e|o)\\s*)?)+)").search(cl)
		var ma := RegEx.create_from_string("almeno\\s+(\\d+)\\s+part").search(cl)
		if ma:
			ok = parti.size() >= int(ma.get_string(1))
		elif cl.find("qualsiasi parte") >= 0 or cl.find("una parte qualsiasi") >= 0:
			ok = parti.size() > 0
		elif mp:
			var nums := RegEx.create_from_string("\\d+").search_all(mp.get_string(1))
			var tutte := mp.get_string(1).find(" o ") < 0
			ok = tutte
			for n in nums:
				var c := parti.has(int(n.get_string()))
				if tutte and not c:
					ok = false
				if not tutte and c:
					ok = true
		else:
			ok = parti.size() > 0
		return ok != neg
	# --- carta Segreto ---
	var mg := RegEx.create_from_string("segreto\\s+(?:\"[^\"]*\"\\s*)?\\(?(\\d+)\\)?").search(cl)
	if mg and (cl.find("carta") >= 0 or cl.find("segreto") >= 0):
		var ok2: bool = partita.ha_segreto(int(mg.get_string(1)))
		return ok2 != neg
	# --- Capitolo ---
	var mc := RegEx.create_from_string("capitol[oi]\\s+(\\d+)([ab])?(?:\\s*(?:-|–|o)\\s*(\\d+))?").search(cl)
	if mc and (cl.find("giocando") >= 0 or cl.find("richiede") >= 0 or cl.find("capitolo") >= 0):
		var cap: int = partita.capitolo()
		var a := int(mc.get_string(1))
		var b := int(mc.get_string(3)) if mc.get_string(3) != "" else a
		var ok3 := cap >= a and cap <= b
		if mc.get_string(2) != "" and ok3:
			var lettera: String = partita.lettera_capitolo()
			if lettera != "":
				ok3 = lettera == mc.get_string(2)
		return ok3 != neg
	# --- Menhir nel Luogo ---
	if cl.find("menhir") >= 0 and cl.find("questo luogo") >= 0:
		var att: bool = partita.menhir_attivo_qui()
		if cl.find("non c'è") >= 0 or cl.find("non c’è") >= 0 or cl.find("non si trova") >= 0:
			return not partita.menhir_presente_qui()
		return att
	# --- tutti i Personaggi ---
	if cl.find("tutti i personaggi") >= 0 or cl.find("tutti i giocatori") >= 0:
		return partita.compagnia_completa()
	# --- attributi: "Richiede 2 {i:empathy}" (testo piano: @empathy@) ---
	var mt := RegEx.create_from_string("(?:richiede|almeno)\\s+(\\d+)\\s*@(\\w+)@").search(cl)
	if mt and ATTRIBUTI.has(mt.get_string(2)):
		return (partita.attributo_compagnia(mt.get_string(2)) >= int(mt.get_string(1))) != neg
	# --- risorse: "almeno 1 Rep", "Pagare 2 Ricchezza", "Pagare 1 @energy@ per membro" ---
	var mr := RegEx.create_from_string("(?:pagare|almeno|richiede)\\s+(\\d+)\\s*(@?\\w+@?)(\\s+per membro)?").search(cl)
	if mr:
		var ris := _risorsa(mr.get_string(2))
		if ris != "":
			var n := int(mr.get_string(1))
			var per_membro := mr.get_string(3) != ""
			return partita.puo_pagare(ris, n, per_membro) != neg
	return null

## Nome interno di una risorsa dal testo del Diario.
static func _risorsa(t: String) -> String:
	t = t.replace("@", "").to_lower()
	match t:
		"energy", "energia": return "energia"
		"health", "salute": return "salute"
		"terror", "terrore": return "terrore"
		"ricchezza", "richcezza", "riccchezza", "wealth": return "ricchezza"
		"cibo", "food": return "cibo"
		"magia", "magic": return "magia"
		"esp", "exp", "esposizione", "esperienza": return "esp"
		"rep", "reputazione": return "rep"
	return ""
