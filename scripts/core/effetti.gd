## Esecuzione automatica degli effetti scritti in italiano (risultati del Diario, carte trascritte):
## "Ogni membro della Compagnia ottiene 2 {i:terror} e perde 1 {i:energy}", "Ottenete la parte 3
## dello status “Canto Funebre”", "Ottenete la carta Segreto 66", "Pescare e risolvere un Incontro
## viola"… Quello che non si riconosce viene restituito come promemoria da fare a mano.
class_name Effetti
extends RefCounted

## Azioni che il gioco deve avviare dopo l'effetto (Incontri, movimenti speciali…), in coda.
static var richieste: Array = []

const VERBI_PIU := ["ottiene", "ottieni", "ottenete", "ottengono", "riceve", "ricevi", "ricevete", "guadagna", "guadagnate", "recupera", "recuperate", "ripristina"]
const VERBI_MENO := ["perde", "perdi", "perdete", "perdono", "paga", "pagate", "pagare", "spende", "spendete"]

static func _piano(t: String) -> String:
	return Dati.testo_piano(t).replace("’", "'").replace("“", "\"").replace("”", "\"").replace("«", "\"").replace("»", "\"")

static func _frasi(t: String) -> Array:
	var out := []
	for f in RegEx.create_from_string("(?<=[.!;])\\s+|\\n+").sub(t, "\u0001", true).split("\u0001"):
		var s := f.strip_edges()
		if s != "":
			out.append(s)
	return out

static func _risorsa(tok: String) -> String:
	return Condizioni._risorsa(tok)

## Applica un testo di effetti alla partita. Restituisce [{testo, fatto}].
static func applica(testo: String, partita: Partita) -> Array:
	var esito := []
	for f in _frasi(_piano(testo)):
		var fatti := _frase(f, partita)
		if fatti.is_empty():
			if _meccanica(f):
				esito.append({"testo": f, "fatto": false})
		else:
			esito.append_array(fatti)
	partita.cambiato()
	return esito

## Una frase "meccanica" (da segnalare se non riconosciuta) contiene numeri o parole di gioco.
static func _meccanica(f: String) -> bool:
	var l := f.to_lower()
	if l.begins_with("l'esplorazione termina") or l.begins_with("poi, l'esplorazione termina") or l == "continua." or l.begins_with("prendere un'altra scelta") or l.begins_with("poi, prendere un'altra scelta") or l.begins_with("non accade nulla"):
		return false
	for k in ["status", "segreto", "luogo", "incontro", "oggetto", "@", "gettone", "carta", "evento", "capitolo", "menhir", "quadrante", "attributo", "scarta", "pesca", "risolv", "spostare", "muovere", "passare"]:
		if l.find(k) >= 0:
			return true
	return RegEx.create_from_string("\\d").search(l) != null

static func _destinatari(f: String, partita: Partita) -> Array:
	var l := f.to_lower()
	if l.find("ogni membro") >= 0 or l.find("ciascun membro") >= 0 or l.find("ogni personaggio") >= 0 or l.find("ciascun personaggio") >= 0 or l.find("tutti i membri") >= 0 or l.find("per membro") >= 0:
		return partita.compagnia()
	return [partita.attivo()]

static func _frase(f: String, partita: Partita) -> Array:
	var out := []
	var l := f.to_lower()
	# --- status ---
	var rs := RegEx.create_from_string("(?:(?:la |le )?part[ei]\\s+((?:\\d+\\s*(?:,|e)?\\s*)+)(?:dello|degli)\\s+status|lo status|status)\\s+\"([^\"]+)\"")
	for m in rs.search_all(f):
		var nome := m.get_string(2).strip_edges()
		var parti := []
		for n in RegEx.create_from_string("\\d+").search_all(m.get_string(1)):
			parti.append(int(n.get_string()))
		var prima := l.substr(0, m.get_start()).to_lower()
		if prima.find("perde") >= 0 or prima.find("rimuov") >= 0 or prima.find("cancella") >= 0 or prima.find("scarta") >= 0:
			partita.perdi_status(nome, parti)
			out.append({"testo": "Status \"%s\" rimosso" % nome, "fatto": true})
		elif prima.find("se ") < 0 and prima.find("richiede") < 0:
			partita.ottieni_status(nome, parti)
			out.append({"testo": "Status \"%s\"%s" % [nome, (" parte " + ", ".join(parti.map(func(x): return str(x)))) if not parti.is_empty() else ""], "fatto": true})
	# --- Segreti ---
	var rg := RegEx.create_from_string("carta segreto\\s+(?:\"[^\"]*\"\\s*)?\\(?(\\d+)\\)?")
	for m in rg.search_all(l):
		var n := int(m.get_string(1))
		var prima := l.substr(0, m.get_start())
		if prima.find("rimuover") >= 0 or prima.find("scartar") >= 0 or prima.find("restituire") >= 0:
			partita.perdi_segreto(n)
			out.append({"testo": "Segreto %d rimosso" % n, "fatto": true})
		elif prima.find("se ") < 0 and prima.find("richiede") < 0:
			partita.ottieni_segreto(n)
			out.append({"testo": "Segreto %d ottenuto" % n, "fatto": true})
	# --- Gettoni Cerca ---
	var rc := RegEx.create_from_string("(\\d+)\\s+gettoni? cerca")
	var mc := rc.search(l)
	if mc and l.find("su questo luogo") < 0 and (l.find("ottenete") >= 0 or l.find("ricevete") >= 0 or l.find("ottieni") >= 0):
		partita.d["gettoni"]["cerca"] = int(partita.d["gettoni"].get("cerca", 0)) + int(mc.get_string(1))
		out.append({"testo": "%s Gettone Cerca" % mc.get_string(1), "fatto": true})
	# --- risorse: sequenze "verbo N risorsa (e N risorsa)" ---
	var dest := _destinatari(f, partita)
	var segno := 0
	var rx := RegEx.create_from_string("([a-zà-ù']+)|(\\d+)\\s*(@\\w+@|(?:cibo|ricchezza|richcezza|magia|esp|rep)\\b)")
	var applicate := []
	for m in rx.search_all(l):
		if m.get_string(1) != "":
			var w := m.get_string(1)
			if VERBI_PIU.has(w):
				segno = 1
			elif VERBI_MENO.has(w):
				segno = -1
			elif w == "se" or w == "richiede" or w == "almeno":
				segno = 0
			continue
		if segno == 0:
			continue
		var ris := _risorsa(m.get_string(3))
		if ris == "":
			continue
		var n := int(m.get_string(2)) * segno
		# "N per membro della Compagnia" senza "ogni membro": a ognuno
		for p in dest:
			partita.modifica(p, ris, n)
		applicate.append("%+d %s%s" % [n, Partita.NOMI_RISORSE.get(ris, ris), (" a ogni membro" if dest.size() > 1 else "")])
	if not applicate.is_empty():
		out.append({"testo": ", ".join(applicate), "fatto": true})
	# "riporta a N il proprio Cibo, Magia e Ricchezza"
	var rr := RegEx.create_from_string("riporta a (\\d+) il proprio (.+)")
	var mr := rr.search(l)
	if mr:
		for p in partita.personaggi():
			for k in ["cibo", "magia", "ricchezza", "esp", "rep"]:
				if mr.get_string(2).find(k) >= 0:
					p[k] = int(mr.get_string(1))
		out.append({"testo": "Risorse riportate a %s" % mr.get_string(1), "fatto": true})
	# --- Oggetti ---
	if l.find("oggetto casuale") >= 0 or l.find("oggetti casuali") >= 0:
		var mo := RegEx.create_from_string("(\\d+) oggett").search(l)
		var n := int(mo.get_string(1)) if mo else 1
		for i in n:
			var o := partita.pesca_oggetto()
			if o != "":
				out.append({"testo": "Oggetto: " + Carte.nome(o), "fatto": true})
	var mog := RegEx.create_from_string("(?:ottenete|ottieni|ottiene) l'oggetto \"([^\"]+)\"").search(l)
	if mog:
		var o2 := partita.prendi_oggetto_nome(mog.get_string(1))
		out.append({"testo": ("Oggetto: " + Carte.nome(o2)) if o2 != "" else "Prendi l'Oggetto \"%s\"" % mog.get_string(1), "fatto": o2 != ""})
	# --- Passare il resto della giornata ---
	if l.find("passare il resto della giornata") >= 0 or l.find("passare per il resto della giornata") >= 0:
		for p in partita.compagnia():
			p["passato"] = true
		out.append({"testo": "La Compagnia Passa per il resto della giornata", "fatto": true})
	# --- Luoghi sostituiti ---
	var ml := RegEx.create_from_string("rimuovere questa carta luogo dal gioco e rimpiazzarla con (?:la carta |il )?luogo (\\d+)").search(l)
	if ml:
		partita.sostituisci_luogo(partita.luogo_attivo(), int(ml.get_string(1)))
		out.append({"testo": "Luogo sostituito dal %s" % ml.get_string(1), "fatto": true})
	var ml2 := RegEx.create_from_string("rimpiazzare il luogo (\\d+).*con il luogo (\\d+)").search(l)
	if ml2:
		partita.sostituisci_luogo(int(ml2.get_string(1)), int(ml2.get_string(2)))
		out.append({"testo": "Luogo %s sostituito dal %s" % [ml2.get_string(1), ml2.get_string(2)], "fatto": true})
	# --- Incontri da risolvere ---
	var mi := RegEx.create_from_string("(?:pescare e risolvere|risolvere|pescate e risolvete|pescare|pesca) (?:un |l')incontro (verde|grigio|viola|blu)(?:\\s+\"([^\"]+)\")?").search(l)
	if mi:
		richieste.append({"tipo": "incontro", "colore": mi.get_string(1), "nome": mi.get_string(2)})
		out.append({"testo": "Incontro %s%s" % [mi.get_string(1), (" \"" + mi.get_string(2) + "\"") if mi.get_string(2) != "" else ""], "fatto": true})
	return out

## Paga il costo scritto nel requisito di una scelta ("Pagare 2 {r:Ricchezza}", "Pagare 1 {i:energy} per membro").
static func paga_costo(q: String, partita: Partita) -> void:
	var l := _piano(q).to_lower()
	var rx := RegEx.create_from_string("pagare\\s+(\\d+)\\s*(@\\w+@|cibo|ricchezza|magia|esp|rep)(\\s+per membro)?")
	for m in rx.search_all(l):
		var ris := _risorsa(m.get_string(2))
		if ris != "":
			partita.paga(ris, int(m.get_string(1)), m.get_string(3) != "")

## Modificatore del tiro di dado letto nel testo del verso:
## "sommate +2 per ogni punto della vostra {i:aggression}", "sommare la vostra {i:practicality}".
static func modificatore_tiro(motore: MotoreDiario, partita) -> Dictionary:
	var t := ""
	for x in motore.testi():
		t += " " + x
	for e in motore.verso().get("e", []):
		t += " " + str(e.get("x", ""))
	var l := _piano(t).to_lower()
	var tot := 0
	var desc := []
	var rx := RegEx.create_from_string("somma(?:te|re|ndo)?\\s+(?:\\+?(\\d+)\\s+per ogni punto (?:della|di) (?:vostra|tua|sua)\\s*|la (?:vostra|tua|sua)\\s*|il (?:vostro|tuo)\\s*)@(\\w+)@")
	for m in rx.search_all(l):
		var mult := int(m.get_string(1)) if m.get_string(1) != "" else 1
		var a := m.get_string(2)
		var v := 0
		if partita and Partita.ATTRIBUTI.has(a):
			v = partita.attributo_compagnia(a)
		elif partita:
			v = int(partita.attivo().get(_risorsa(a), 0))
		tot += v * mult
		desc.append("%s %d%s" % [Partita.NOMI_ATTRIBUTI.get(a, a), v, (" ×%d" % mult) if mult != 1 else ""])
	return {"valore": tot, "testo": ", ".join(desc)}
