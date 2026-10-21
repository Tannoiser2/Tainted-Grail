## Preparazione della partita e dei Capitoli (regole §2 e carte "Preparazione del Capitolo").
class_name Preparazione
extends RefCounted

## Preparazione iniziale: Cuanacht (101) al centro con i 4 Luoghi collegati, Menhir sul 101,
## mazzi Oggetti/Segreti/Eventi e mazzi Incontro del Capitolo 1.
static func capitolo_1(p: Partita) -> void:
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
	# Oggetti mescolati, Segreti in ordine di numero
	var ogg: Array = Carte.gruppo("oggetti").duplicate()
	ogg.shuffle()
	d["mazzi"]["oggetti"] = ogg
	d["mazzi"]["abilita"] = Carte.gruppo("abilita").duplicate()
	prepara_incontri(p, 1)
	prepara_eventi(p, 1)
	p.racconta("Preparazione del Capitolo 1: Cuanacht, Menhir con Quadrante %d" % int(d["menhir"]["101"]["quadrante"]))

## Mazzi Incontro di un capitolo: le carte dei livelli previsti (dalla carta Preparazione,
## se trascritta; altrimenti il livello 1 al Capitolo 1, +1 livello ogni 3 Capitoli).
static func prepara_incontri(p: Partita, capitolo: int) -> void:
	var tutte: Dictionary = Dati.carte.get("gruppi", {}).get("incontri", {})
	var livelli := livelli_capitolo(capitolo, p.personaggi().size())
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
static func livelli_capitolo(capitolo: int, giocatori: int) -> Array:
	for img in Carte.gruppo("eventi_storia"):
		var c := Carte.dati(img)
		if str(c.get("sottotipo", "")) != "preparazione" or int(c.get("capitolo", -1)) != capitolo:
			continue
		var lp: Dictionary = c.get("preparazione", {}).get("mazzi_incontro", {}).get("livelli_per_giocatori", {})
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
		if int(c.get("capitolo", -1)) == capitolo and str(c.get("sottotipo", "")) == "storia":
			parti.append(img)
	parti.sort_custom(func(a, b): return int(Carte.dati(a).get("parte", 0)) < int(Carte.dati(b).get("parte", 0)))
	p.d["mazzi"]["eventi"] = parti
	p.d["mazzi"]["eventi_scarti"] = []
	var cas: Array = Carte.gruppo("eventi_casuali").duplicate()
	cas.shuffle()
	p.d["mazzi"]["eventi_casuali"] = cas
