## Preparazione della partita e dei Capitoli (regole §2 e carte "Preparazione del Capitolo").
class_name Preparazione
extends RefCounted

## Preparazione iniziale: Cuanacht (101) al centro con i 4 Luoghi collegati, Menhir sul 101,
## mazzi Oggetti/Segreti/Eventi e mazzi Incontro del Capitolo 1.
static func capitolo_1(p: Partita) -> void:
	var d := p.d
	mappa_iniziale(p)
	# Oggetti mescolati, Segreti in ordine di numero
	var ogg: Array = Carte.gruppo("oggetti").duplicate()
	ogg.shuffle()
	d["mazzi"]["oggetti"] = ogg
	d["mazzi"]["abilita"] = Carte.gruppo("abilita").duplicate()
	prepara_incontri(p, 1)
	prepara_eventi(p, 1)
	p.racconta("Preparazione del Capitolo 1: Cuanacht, Menhir con Quadrante %d" % int(d["menhir"]["101"]["quadrante"]))

## Mappa di partenza: Cuanacht (101) con il Menhir attivo e i 4 Luoghi collegati; Personaggi sul 101.
static func mappa_iniziale(p: Partita) -> void:
	var d := p.d
	p.piazza_luogo(101, Vector2i(0, 0))
	d["menhir"]["101"] = {"quadrante": p.quadrante_iniziale(8)}
	# i 4 Luoghi collegati al 101 (anche se la carta non è ancora trascritta)
	var vicini := {"su": 102, "sinistra": 103, "destra": 104, "giu": 105}
	var dirs := p.direzioni(101)
	for k in vicini:
		var n := int(dirs.get(k, vicini[k])) if dirs.get(k) != null else int(vicini[k])
		p.piazza_luogo(n, Vector2i(0, 0) + Partita.DIREZIONI[k])
	for x in p.personaggi():
		x["luogo"] = 101

## Mazzi Incontro di un capitolo: le carte dei livelli previsti (dalla carta Preparazione,
## se trascritta; altrimenti il livello 1 al Capitolo 1, +1 livello ogni 3 Capitoli).
static func prepara_incontri(p: Partita, capitolo: int, lettera := "") -> void:
	var tutte: Dictionary = Dati.carte.get("gruppi", {}).get("incontri", {})
	var livelli := livelli_capitolo(capitolo, p.personaggi().size(), lettera)
	for colore in ["grigio", "verde", "viola", "blu"]:
		var m := []
		var primo := ""
		for liv in tutte.get(colore, {}):
			if not livelli.has(int(liv)):
				continue
			for img in tutte[colore][liv]:
				var c := Carte.dati(img)
				if str(c.get("nome", {}).get("it", "")).to_lower().begins_with("il tuo primo") or str(c.get("nome", {}).get("es", "")).to_lower().begins_with("tu primer"):
					primo = img
					continue
				m.append(img)
		m.shuffle()
		if primo != "" and capitolo == 1:
			m.push_front(primo)
		p.d["mazzi"]["incontri_" + colore] = m

## Livelli dei mazzi Incontro per il capitolo e il numero di giocatori, dalla carta Preparazione.
static func livelli_capitolo(capitolo: int, giocatori: int, lettera := "") -> Array:
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if str(c.get("sottotipo", "")) != "preparazione" or Carte.num(c, "capitolo") != capitolo:
			continue
		if lettera != "" and Carte.txt(c, "lettera") not in ["", lettera, "<null>"]:
			continue
		var lp: Dictionary = c.get("preparazione", {}).get("mazzi_incontro", {}).get("livelli_per_giocatori", {})
		var ap = Carte.auto(img).get("preparazione")
		if ap is Dictionary and ap.get("mazzi_incontro") is Dictionary:
			lp = ap["mazzi_incontro"].get("livelli_per_giocatori", lp)
		for k in lp:
			var parti := str(k).split("-")
			var a := int(parti[0])
			var b := int(parti[-1])
			if giocatori >= a and giocatori <= b:
				return lp[k].map(func(x): return int(x))
	return [clampi(1 + int((capitolo - 1) / 3), 1, 4)]

## Mazzo Eventi del capitolo: le Parti impilate dalla 1 (in cima) all'ultima.
static func prepara_eventi(p: Partita, capitolo: int) -> void:
	var parti := []
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if Carte.num(c, "capitolo") == capitolo and str(c.get("sottotipo", "")) == "storia":
			parti.append(img)
	parti.sort_custom(func(a, b): return int(Carte.dati(a).get("parte", 0)) < int(Carte.dati(b).get("parte", 0)))
	p.d["mazzi"]["eventi"] = parti
	p.d["mazzi"]["eventi_scarti"] = []
	var cas: Array = Carte.gruppo("eventi_casuali").duplicate()
	cas.shuffle()
	p.d["mazzi"]["eventi_casuali"] = cas

## Carta "Preparazione del Capitolo" (capitolo e lettera), "" se non trovata.
static func carta_preparazione(capitolo: int, lettera := "") -> String:
	var trovata := ""
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if str(c.get("sottotipo", "")) != "preparazione" or Carte.num(c, "capitolo") != capitolo:
			continue
		var l = c.get("lettera")
		var ls := "" if l == null else str(l)
		if ls == lettera:
			return img
		if trovata == "" and (ls == "" or lettera == ""):
			trovata = img
	return trovata

## Preparazione di un nuovo Capitolo (dopo il completamento del precedente): mazzi Incontro,
## mazzo Eventi con le Parti del Capitolo, Guardiani, Segreti ed effetti della carta Preparazione.
static func capitolo(p: Partita, cap: int, lettera := "") -> void:
	var d := p.d
	d["capitolo"] = cap
	d["lettera"] = lettera
	d["capitolo_completato"] = false
	var img := carta_preparazione(cap, lettera)
	var ap = Carte.auto(img).get("preparazione") if img != "" else null
	if not (ap is Dictionary):
		ap = {}
	prepara_incontri(p, cap, lettera)
	# mazzo Eventi: le Parti dalla prima (in cima) all'ultima
	var ev: Dictionary = ap.get("eventi", {}) if ap.get("eventi") is Dictionary else {}
	var it := Interprete.new(p)
	var parti: Array = ev.get("parti_dal_fondo", [])
	for v in ev.get("varianti", []):
		if v is Dictionary and it.valuta(v.get("condizione", {})) == true:
			parti = v.get("parti_dal_fondo", parti)
	var mazzo := []
	if parti.is_empty():
		prepara_eventi(p, cap)
		mazzo = d["mazzi"]["eventi"]
	else:
		for n in parti:
			var e := _parte(cap, int(n), lettera)
			if e != "":
				mazzo.push_front(e)
		d["mazzi"]["eventi"] = mazzo
	for sc in ev.get("scarta_dalla_cima", []):
		if sc is Dictionary and it.valuta(sc.get("condizione", {})) == true:
			for i in int(sc.get("n", 1)):
				if not mazzo.is_empty():
					d["mazzi"].get_or_add("eventi_scarti", []).append(mazzo.pop_front())
	var cas: Array = Carte.gruppo("eventi_casuali").duplicate()
	cas.shuffle()
	d["mazzi"]["eventi_casuali"] = cas
	# Guardiani
	var g := p.personaggi().size()
	for gu in ap.get("guardiani", []):
		if not (gu is Dictionary):
			continue
		var gg: Dictionary = gu.get("giocatori", {}) if gu.get("giocatori") is Dictionary else {}
		if g < int(gg.get("da", 1)) or g > int(gg.get("a", 4)):
			continue
		if gu.get("condizione") is Dictionary and it.valuta(gu["condizione"]) != true:
			continue
		piazza_guardiano(p, str(gu.get("colore", "")), str(gu.get("nome", "")), str(gu.get("luogo", "rivelato_numero_piu_basso")))
	for sg in ap.get("segreti", []):
		if sg is Dictionary and (not (sg.get("condizione") is Dictionary) or it.valuta(sg["condizione"]) == true):
			p.ottieni_segreto(int(sg.get("n", 0)))
	if ap.get("effetti") is Array:
		it.esegui(ap["effetti"])
	p.racconta("Preparazione del Capitolo %d%s" % [cap, lettera])
	p.cambiato()

static func _parte(cap: int, parte: int, lettera: String) -> String:
	var di_riserva := ""
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if str(c.get("sottotipo", "")) != "storia" or Carte.num(c, "capitolo") != cap or Carte.num(c, "parte") != parte:
			continue
		var l = c.get("lettera")
		var ls := "" if l == null else str(l)
		if ls == lettera:
			return img
		if di_riserva == "":
			di_riserva = img
	return di_riserva

## Piazza un Guardiano (carta Incontro col nome dato) su un Luogo della mappa.
static func piazza_guardiano(p: Partita, colore: String, nome: String, dove: String) -> void:
	var img := ""
	var m: Array = p.d["mazzi"].get("incontri_" + colore, [])
	var chiave := _scheletro(nome)
	for x in m:
		if _scheletro(Carte.nome(x)) == chiave:
			img = x
	if img == "":
		var tutte: Dictionary = Dati.carte.get("gruppi", {}).get("incontri", {}).get(colore, {})
		for liv in tutte:
			for x in tutte[liv]:
				if _scheletro(Carte.nome(x)) == chiave:
					img = x
	if img == "":
		p.racconta("Guardiano \"%s\" non trovato fra le carte Incontro." % nome)
		return
	m.erase(img)
	var luoghi: Array = p.d["mappa"].keys().map(func(k): return int(k))
	luoghi.sort()
	if luoghi.is_empty():
		return
	var l: int = luoghi[-1] if dove.ends_with("alto") else luoghi[0]
	if dove.is_valid_int():
		l = int(dove)
	p.d.get_or_add("guardiani", []).append({"img": img, "colore": colore, "luogo": l})
	p.racconta("Guardiano %s sul Luogo %d" % [Carte.nome(img), l])

## Nome ridotto alle consonanti (per riconoscere "Becco a Martello" = "Beccomartello").
static func _scheletro(t: String) -> String:
	var out := ""
	for ch in t.to_lower():
		if not (ch in " aeiouàèéìòù'’-"):
			out += ch
	return out
