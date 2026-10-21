## Interprete del linguaggio degli effetti (tools/automazione/DSL.md): esegue gli effetti strutturati
## del Diario e delle carte e verifica le condizioni sullo stato della partita.
##
## Le richieste al giocatore (scelte, a chi dare una risorsa, quale attributo, Incontri da risolvere)
## passano per `ui`, un oggetto che implementa (con await):
##   scegli(titolo: String, opzioni: Array[String]) -> int
##   scegli_personaggio(titolo: String, lista: Array) -> Dictionary
##   risolvi_incontro(colore: String, nome: String, livello: int) -> String   ("vittoria", "fallimento"…)
##   apri_diario(luogo: int, verso: int) -> void
##   mostra_evento(img: String) -> void
## Senza ui (prove automatiche) si sceglie la prima opzione e gli Incontri si considerano vinti.
class_name Interprete
extends RefCounted

var p: Partita
var inc: Incontro
var ui
var ctx := {}               # carta (img) di provenienza, cubi_dati, luogo…
var rapporto: Array = []    # [{testo, fatto}]
var interrotto := false     # un costo non pagato interrompe gli effetti successivi

func _init(partita: Partita, incontro: Incontro = null, ui_ = null, contesto: Dictionary = {}) -> void:
	p = partita
	inc = incontro
	ui = ui_
	ctx = contesto

func _r(testo: String, fatto := true) -> void:
	rapporto.append({"testo": testo, "fatto": fatto})

## --- Chi riceve -----------------------------------------------------------------------

func _attivo() -> Dictionary:
	if ctx.get("membro") is Dictionary:
		return ctx["membro"]
	if ctx.get("proprietario") is Dictionary and not ctx["proprietario"].is_empty():
		return ctx["proprietario"]
	if inc and not inc.attivo().is_empty():
		return inc.attivo()
	return p.attivo()

func _bersagli(chi: String) -> Array:
	match chi:
		"compagnia", "ognuno", "totale":
			return inc.membri.duplicate() if inc else p.compagnia()
		"tutti":
			return p.personaggi()
		"proprietario":
			return [_attivo()]
		"scelto":
			var l := p.compagnia()
			if l.size() <= 1:
				return l
			return [await _scegli_personaggio("A quale Personaggio?", l)]
		"diviso":
			var l2 := p.compagnia()
			if l2.size() <= 1:
				return l2
			return [await _scegli_personaggio("Chi riceve?", l2)]
	return [_attivo()]

func _scegli(titolo: String, opzioni: Array) -> int:
	if ui and ui.has_method("scegli"):
		return await ui.scegli(titolo, opzioni)
	return 0

func _scegli_personaggio(titolo: String, lista: Array) -> Dictionary:
	if ui and ui.has_method("scegli_personaggio"):
		return await ui.scegli_personaggio(titolo, lista)
	return lista[0]

## --- Esecuzione -------------------------------------------------------------------------

## Esegue una lista di passi. Restituisce false se un costo non è stato pagato.
func esegui(passi) -> bool:
	if not (passi is Array):
		return true
	for s in passi:
		if interrotto:
			return false
		if s is Dictionary:
			await _passo(s)
	p.cambiato()
	return not interrotto

func _n(s: Dictionary) -> int:
	var n := int(s.get("n", 0))
	if s.has("per"):
		n *= _conta(s["per"])
	return n

func _passo(s: Dictionary) -> void:
	var t := str(s.get("tipo", ""))
	match t:
		"risorsa":
			var ris := str(s.get("ris", ""))
			var n := _n(s)
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				if n > 0:
					n = p.guadagno(x, ris, n, inc.colore if inc else "")
				var v := p.modifica(x, ris, n if n < 90 else Personaggi.limite(x, ris))
				_r("%s %+d %s" % [x["nome"], v, Partita.NOMI_RISORSE.get(ris, ris)])
		"imposta":
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				x[str(s["ris"])] = int(s.get("n", 0))
				_r("%s: %s a %d" % [x["nome"], Partita.NOMI_RISORSE.get(str(s["ris"]), s["ris"]), int(s.get("n", 0))])
		"paga":
			var ris := str(s.get("ris", ""))
			var n := _n(s)
			n = p.costo_modificato(ris, n)
			var chi := str(s.get("chi", "attivo"))
			var ok := false
			if chi == "compagnia":
				ok = p.paga(ris, n, true)
			elif chi == "diviso":
				ok = p.paga(ris, n, false)
			elif chi == "tutti":
				ok = p.personaggi().all(func(x): return int(x.get(ris, 0)) >= n)
				if ok:
					for x in p.personaggi():
						p.modifica(x, ris, -n)
			else:
				var a := _attivo()
				ok = int(a.get(ris, 0)) >= n
				if ok:
					p.modifica(a, ris, -n)
			if ok:
				_r("Pagato %d %s" % [n, Partita.NOMI_RISORSE.get(ris, ris)])
			else:
				_r("Non potete pagare %d %s" % [n, Partita.NOMI_RISORSE.get(ris, ris)], false)
				interrotto = true
		"attributo":
			var n := int(s.get("n", 0))
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				var a := str(s.get("attr", ""))
				if a == "scelta" or a == "":
					var opz := Partita.ATTRIBUTI.filter(func(k): return n > 0 or p.attributo(x, k) > 0)
					if opz.is_empty():
						continue
					a = opz[await _scegli("%s: quale Attributo?" % x["nome"], opz.map(func(k): return Partita.NOMI_ATTRIBUTI[k]))]
				await cambia_attributo(x, a, n)
		"status":
			var parti: Array = s.get("parti", []).map(func(v): return int(v))
			if s.get("rimuovi", false):
				p.perdi_status(str(s["nome"]), parti)
				_r("Status \"%s\" rimosso" % s["nome"])
			else:
				p.ottieni_status(str(s["nome"]), parti)
				_r("Status \"%s\"%s" % [s["nome"], (" parte " + ", ".join(parti.map(func(v): return str(v)))) if not parti.is_empty() else ""])
		"segreto":
			var n := int(s.get("n", 0))
			if s.get("rimuovi", false):
				p.perdi_segreto(n)
				_r("Segreto %d rimosso" % n)
			else:
				p.ottieni_segreto(n)
				_r("Segreto %d: %s" % [n, Carte.nome(Carte.segreto(n))])
		"oggetto":
			await _oggetto(s)
		"gettoni_cerca":
			var n := int(s.get("n", 0))
			if s.has("luogo"):
				var l := _luogo(s["luogo"])
				var g: Dictionary = p.d["gettoni"].get_or_add("cerca_luoghi", {})
				g[str(l)] = maxi(0, int(g.get(str(l), 0)) + n)
				_r("%+d Gettoni Cerca sul Luogo %d" % [n, l])
			else:
				p.d["gettoni"]["cerca"] = maxi(0, int(p.d["gettoni"].get("cerca", 0)) + n)
				_r("%+d Gettoni Cerca (%d)" % [n, int(p.d["gettoni"]["cerca"])])
		"gettone_tempo":
			var l := _luogo(s.get("luogo", "qui"))
			var nt := maxi(0, int(p.d["gettoni"]["tempo"].get(str(l), 0)) + int(s.get("n", 1)))
			if nt == 0:
				p.d["gettoni"]["tempo"].erase(str(l))
			else:
				p.d["gettoni"]["tempo"][str(l)] = nt
			_r("Gettoni Tempo sul Luogo %d: %d" % [l, nt])
		"quadrante":
			_quadrante(s)
		"menhir":
			var l := _luogo(s.get("luogo", "qui"))
			var q := int(s.get("quadrante", 8))
			if s.get("meno_per_giocatore", false):
				q -= p.personaggi().size() - 1
			p.attiva_menhir(l, q)
			_r("Menhir attivo al Luogo %d (Quadrante %d)" % [l, q])
		"luogo":
			_luogo_azione(s)
		"muovi":
			await _muovi(s)
		"incontro":
			await _incontro(s)
		"diario":
			if ctx.get("in_diario", false):
				ctx["salto_diario"] = [int(s.get("luogo", 999)), int(s.get("verso", -1))]
			elif ui and ui.has_method("apri_diario"):
				ui.apri_diario(int(s.get("luogo", 999)), int(s.get("verso", -1)))
			_r("Diario: Luogo %d%s" % [int(s.get("luogo", 999)), (" verso %d" % int(s["verso"])) if s.has("verso") else ""])
		"evento":
			await _evento(s)
		"capitolo":
			await _capitolo(s)
		"passa":
			for x in await _bersagli(str(s.get("chi", "compagnia"))):
				x["passato"] = true
			_r("Passate il resto della giornata")
		"nuova_giornata":
			p.d["salta_fine_giornata"] = true
			_r("Inizia subito una nuova giornata")
		"fine_esplorazione":
			pass
		"altra_scelta":
			ctx["altra_scelta"] = true
		"dado":
			await _dado(s)
		"quadrante_lancio":
			var graal := randi() % 2 == 0
			_r("Lancio del Quadrante: %s" % ("Graal" if graal else "Teschio"))
			await esegui(s.get("graal" if graal else "teschio", []))
		"scelta":
			var opz: Array = s.get("opzioni", [])
			if opz.is_empty():
				return
			var nomi := opz.map(func(o): return Dati.testo_leggibile(str(o.get("testo", "?"))))
			var i := await _scegli("Scegli", nomi)
			_r("Scelta: " + str(nomi[i]))
			var salva := interrotto
			await esegui(opz[i].get("effetti", []))
			if interrotto and not salva and opz.size() > 1:
				# costo non pagabile: si offre di nuovo la scelta senza quell'opzione
				interrotto = false
				var resto := opz.duplicate()
				resto.remove_at(i)
				await _passo({"tipo": "scelta", "opzioni": resto})
		"se":
			var chi_se := str(s.get("chi", ""))
			if chi_se in ["ognuno", "compagnia", "tutti"]:
				# condizione valutata membro per membro: gli effetti "attivo" vanno a quel membro
				var vecchio_m = ctx.get("membro")
				for x in (p.personaggi() if chi_se == "tutti" else (inc.membri.duplicate() if inc else p.compagnia())):
					ctx["membro"] = x
					var vm = valuta(s.get("condizione", {}))
					if vm == null:
						vm = await _scegli("%s: è vero? %s" % [x["nome"], descrivi(s.get("condizione", {}))], ["Sì", "No"]) == 0
					await esegui(s.get("allora", []) if vm else s.get("altrimenti", []))
				if vecchio_m == null:
					ctx.erase("membro")
				else:
					ctx["membro"] = vecchio_m
				return
			var v = valuta(s.get("condizione", {}))
			if v == null:
				v = await _scegli("È vero? " + descrivi(s.get("condizione", {})), ["Sì", "No"]) == 0
			await esegui(s.get("allora", []) if v else s.get("altrimenti", []))
		"ripeti":
			var n := _conta(s.get("per", {}))
			for i in n:
				await esegui(s.get("effetti", []))
		"nota":
			p.d.get_or_add("note", []).append(str(s.get("testo", "")))
			_r("Nota: " + Dati.testo_leggibile(str(s.get("testo", ""))))
		"manuale":
			_r(Dati.testo_leggibile(str(s.get("testo", ""))), false)
		"modificatore":
			pass
		_:
			if inc:
				await _passo_incontro(s)
			else:
				_r("(effetto d'Incontro fuori dall'Incontro: %s)" % t, false)

func _luogo(v) -> int:
	if str(v) == "qui" or str(v) == "questo" or v == null:
		return int(ctx.get("luogo", p.luogo_attivo()))
	return int(v)

func _oggetto(s: Dictionary) -> void:
	var a := _attivo()
	var modo := str(s.get("modo", "")) if s.get("modo") != null else ""
	if modo == "":
		modo = "nome" if s.has("nome") else "casuale"
	match modo:
		"casuale", "fabbricabile":
			for i in maxi(1, int(s.get("n", 1))):
				var o := p.pesca_oggetto(str(s.get("modo")) == "fabbricabile", a, str(s.get("parola", "")))
				_r(("Oggetto: " + Carte.nome(o)) if o != "" else "Nessun Oggetto disponibile", o != "")
		"nome":
			var o2 := p.prendi_oggetto_nome(str(s.get("nome", "")), a)
			_r(("Oggetto: " + Carte.nome(o2)) if o2 != "" else "Oggetto \"%s\" non disponibile" % s.get("nome", ""), o2 != "")
		"scegli_fra":
			var m: Array = p.d["mazzi"].get("oggetti", [])
			var tre := m.slice(0, maxi(1, int(s.get("n", 3))))
			if tre.is_empty():
				return
			var i := await _scegli("Scegli un Oggetto", tre.map(func(x): return Carte.nome(x)))
			m.erase(tre[i])
			a["oggetti"].append(tre[i])
			_r("Oggetto: " + Carte.nome(tre[i]))
		"scarta":
			var og: Array = a.get("oggetti", [])
			if og.is_empty():
				_r("Nessun Oggetto da scartare", false)
				return
			var i2 := await _scegli("Scarta un Oggetto", og.map(func(x): return Carte.nome(x)))
			var o3: String = og[i2]
			p.scarta_oggetto(a, o3)
			_r("Scartato " + Carte.nome(o3))
		"scarta_tutti":
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				for o4 in x.get("oggetti", []).duplicate():
					p.scarta_oggetto(x, o4)
			_r("Scartati tutti gli Oggetti")
		"scarta_questo":
			var c := str(ctx.get("carta", ""))
			if c == "":
				return
			for x in p.personaggi():
				if x.get("oggetti", []).has(c):
					p.scarta_oggetto(x, c)
					_r("Scartato " + Carte.nome(c))
					return
			for n in Dati.carte.get("segreti", {}):
				if Dati.carte["segreti"][n] == c:
					p.perdi_segreto(int(n))
					_r("Scartato il Segreto " + str(n))
					return

func _quadrante(s: Dictionary) -> void:
	var dove := str(s.get("dove", "menhir_qui"))
	if dove == "menhir_qui" or dove == "menhir":
		var l := p.luogo_attivo()
		var m: Dictionary = p.d["menhir"].get(str(l), {})
		if m.is_empty() and dove == "menhir" and not p.d["menhir"].is_empty():
			l = int(p.d["menhir"].keys()[0])
			m = p.d["menhir"][str(l)]
		if m.is_empty():
			_r("Nessun Menhir da modificare", false)
			return
		if s.has("valore"):
			m["quadrante"] = int(s["valore"])
		else:
			m["quadrante"] = clampi(int(m["quadrante"]) + int(s.get("n", 0)), 0, 12)
		_r("Quadrante del Menhir %d: %d" % [l, int(m["quadrante"])])
	else:
		var q: Dictionary = p.d.get_or_add("quadranti", {})
		var v := int(s["valore"]) if s.has("valore") else int(q.get(dove, {}).get("valore", 0)) + int(s.get("n", 0))
		q[dove] = {"valore": v, "gettone": str(s.get("gettone", "tempo"))}
		_r("Quadrante %s: %d" % [dove, v])

func _luogo_azione(s: Dictionary) -> void:
	match str(s.get("azione", "")):
		"sostituisci":
			var v := _luogo(s.get("vecchio", "questo"))
			p.sostituisci_luogo(v, int(s.get("nuovo", 0)))
			_r("Luogo %d sostituito dal %d" % [v, int(s.get("nuovo", 0))])
		"prepara", "rivela":
			var n := int(s.get("n", 0))
			if not p.d["mappa"].has(str(n)):
				p.piazza_vicino(n, p.luogo_attivo())
			_r("Luogo %d sul tavolo" % n)
		"rimuovi":
			var n2 := _luogo(s.get("n", "questo"))
			p.rimuovi_luogo(n2)
			_r("Luogo %d rimosso dal gioco" % n2)

func _muovi(s: Dictionary) -> void:
	var dove = s.get("dove")
	var dest := 0
	var da := p.luogo_attivo()
	if dove is int or dove is float or str(dove).is_valid_int():
		dest = int(dove)
		if not p.d["mappa"].has(str(dest)):
			p.piazza_vicino(dest, da)
	else:
		var d := str(dove)
		var base := da
		if d.begins_with("collegato_a:"):
			base = int(d.substr(12))
		var coll := p.collegati(base)
		coll.sort()
		if coll.is_empty():
			return
		if d == "collegato_scelto":
			dest = coll[await _scegli("Dove andate?", coll.map(func(x): return "Luogo %d" % x))]
		else:
			dest = coll[0]
	for x in await _bersagli(str(s.get("chi", "compagnia"))):
		x["luogo"] = dest
	p.rivela_attorno(dest)
	_r("Spostamento al Luogo %d" % dest)

func _incontro(s: Dictionary) -> void:
	var colore := str(s.get("colore", "verde"))
	var esito := "vittoria"
	if ui and ui.has_method("risolvi_incontro"):
		esito = await ui.risolvi_incontro(colore, str(s.get("nome", "")), int(s.get("livello", 0)))
	_r("Incontro %s: %s" % [colore, esito])
	ctx["esito_incontro"] = esito
	var e: Dictionary = s.get("esito", {})
	if e.has(esito):
		await esegui(e[esito])
	elif esito in ["fuga", "fuga_nemico"] and e.has("fallimento"):
		pass

func _evento(s: Dictionary) -> void:
	var g := Giornata.new(p)
	match str(s.get("azione", "")):
		"risolvi_parte":
			var cap_v = s.get("capitolo")
			var let_v = s.get("lettera")
			var img := p.trova_evento(p.capitolo() if cap_v == null else int(cap_v), int(s.get("parte", 0)) if s.get("parte") != null else 0, p.lettera_capitolo() if let_v == null else str(let_v))
			if img == "":
				_r("Parte %s del Capitolo %s non trovata nel mazzo Eventi" % [s.get("parte"), s.get("capitolo")], false)
				return
			_r("Evento: " + Carte.nome(img))
			await risolvi_evento(img)
		"casuali_in_cima":
			var mpg = s.get("meno_per_giocatore", false)
			var meno := 0
			if mpg is bool:
				meno = p.personaggi().size() if mpg else 0
			elif mpg is int or mpg is float:
				meno = int(mpg) * p.personaggi().size()
			var n := int(s.get("n", 0)) - meno
			g.aggiungi_casuali(maxi(0, n))
			_r("%d Eventi Casuali in cima al mazzo Eventi" % maxi(0, n))
		"scarta_tutti":
			p.d["cerche"] = []
			p.d["mazzi"]["eventi"] = []
			_r("Scartate tutte le carte Evento e le Cerche")
		"scarta_questo":
			var c := str(ctx.get("carta", ""))
			p.d.get_or_add("cerche", []).erase(c)
			if p.d.get("evento", "") == c:
				p.d["evento"] = ""
		"cerca_attiva":
			var c2 := str(ctx.get("carta", ""))
			var att: Array = p.d.get_or_add("cerche", [])
			if c2 != "" and not att.has(c2):
				att.push_front(c2)
		"speciale":
			var img2 := p.trova_evento_speciale(str(s.get("lettera", "")))
			if img2 != "":
				_r("Evento Speciale " + str(s.get("lettera", "")))
				await risolvi_evento(img2)

## Risolve una carta Evento: effetti al momento della rivelazione e Cerca.
func risolvi_evento(img: String) -> void:
	var a: Dictionary = Carte.auto(img)
	var vecchio = ctx.get("carta")
	ctx["carta"] = img
	p.d["evento"] = img
	if ui and ui.has_method("mostra_evento"):
		ui.mostra_evento(img)
	await esegui(a.get("rivelato", []))
	if a.get("cerca") is Dictionary:
		var att: Array = p.d.get_or_add("cerche", [])
		if not att.has(img):
			att.push_front(img)
	ctx["carta"] = vecchio

func _capitolo(s: Dictionary) -> void:
	match str(s.get("azione", "")):
		"completato":
			p.d["capitolo_completato"] = true
			_r("Capitolo completato!")
		"prepara":
			var c := int(s["capitolo"]) if s.get("capitolo") != null else p.capitolo() + 1
			Preparazione.capitolo(p, c, "" if s.get("lettera") == null else str(s.get("lettera")))
			_r("Preparato il Capitolo %d%s" % [c, str(s.get("lettera", ""))])

func _dado(s: Dictionary) -> void:
	var v := randi_range(1, 6)
	var mod := 0
	mod = modificatore_dado(s.get("mod", []))
	var tot := v + mod
	ctx["tiro"] = tot
	_r("Dado: %d%s = %d" % [v, (" %+d" % mod) if mod != 0 else "", tot])
	for r in s.get("risultati", []):
		if tot >= int(r.get("da", 0)) and tot <= int(r.get("a", 99)):
			await esegui(r.get("effetti", []))
			break

## Cambia un attributo: dal 3° punto ogni punto è una carta Abilità (si sceglie la faccia);
## perdendo un punto si scarta prima un'Abilità di quell'attributo.
func cambia_attributo(x: Dictionary, a: String, n: int) -> void:
	for i in absi(n):
		if n > 0:
			x["attributi"][a] = p.attributo(x, a) + 1
			_r("%s: %s %d" % [x["nome"], Partita.NOMI_ATTRIBUTI.get(a, a), p.attributo(x, a)])
			if p.attributo(x, a) >= 3:
				await scegli_abilita(x, a)
		else:
			if p.attributo(x, a) <= 0:
				return
			x["attributi"][a] = p.attributo(x, a) - 1
			var ab: Array = x.get("abilita", [])
			for k in range(ab.size() - 1, -1, -1):
				if ab[k] is Dictionary and str(ab[k].get("attributo", "")) == a:
					_r("%s perde l'Abilità %s" % [x["nome"], str(ab[k].get("nome", ""))])
					ab.remove_at(k)
					break
			_r("%s: %s %d" % [x["nome"], Partita.NOMI_ATTRIBUTI.get(a, a), p.attributo(x, a)])

## Scelta di una carta Abilità (e della sua faccia) per un attributo.
func scegli_abilita(x: Dictionary, a: String) -> void:
	var mazzo: Array = p.d["mazzi"].get_or_add("abilita", Carte.gruppo("abilita").duplicate())
	var opz := []
	for img in mazzo:
		var fa: Array = Carte.dati(img).get("facce", [])
		for i in fa.size():
			if str(fa[i].get("attributo", "")) == a:
				var nome := str(fa[i].get("nome", {}).get("it", ""))
				opz.append({"img": img, "faccia": i, "nome": nome, "testo": "%s (%d): %s" % [nome, int(fa[i].get("numero", 0)), Dati.testo_leggibile(str(fa[i].get("effetto", {}).get("it", "")))]})
	if opz.is_empty():
		_r("Nessuna carta Abilità di %s disponibile" % Partita.NOMI_ATTRIBUTI.get(a, a), false)
		return
	var k := await _scegli("%s: scegli un'Abilità di %s (l'altra faccia della carta è persa)" % [x["nome"], Partita.NOMI_ATTRIBUTI.get(a, a)], opz.map(func(o): return o["testo"]))
	var o: Dictionary = opz[k]
	mazzo.erase(o["img"])
	x.get_or_add("abilita", []).append({"img": o["img"], "faccia": o["faccia"], "attributo": a, "nome": o["nome"]})
	_r("%s ottiene l'Abilità %s" % [x["nome"], o["nome"]])
	p.racconta("%s ottiene l'Abilità %s" % [x["nome"], o["nome"]])

## Inneschi delle carte fuori dagli Incontri (inizio/fine giornata, riposo, viaggio, esplorazione…).
func scatena(quando: String, chi: Dictionary = {}) -> void:
	for i in p.inneschi(quando, chi):
		var inn: Dictionary = i["innesco"]
		var vecchio = ctx.get("proprietario")
		ctx["carta"] = i["img"]
		ctx["proprietario"] = i["chi"] if not i["chi"].is_empty() else chi
		if inn.get("condizione") is Dictionary and not inn["condizione"].is_empty() and valuta(inn["condizione"]) != true:
			ctx["proprietario"] = vecchio
			continue
		if inn.get("facoltativo", false) or (inn.get("costo") is Array and not inn["costo"].is_empty()):
			if not (ui and ui.has_method("scegli")):
				ctx["proprietario"] = vecchio
				continue
			if await _scegli("%s: usare \"%s\"?" % [str(i["chi"].get("nome", "Compagnia")), Carte.nome(i["img"])], ["Sì", "No"]) != 0:
				ctx["proprietario"] = vecchio
				continue
		interrotto = false
		if inn.get("costo") is Array and not await esegui(inn["costo"]):
			interrotto = false
			ctx["proprietario"] = vecchio
			continue
		_r("%s (%s)" % [Carte.nome(i["img"]), quando.replace("_", " ")])
		await esegui(inn.get("effetti", []))
		interrotto = false
		ctx["proprietario"] = vecchio

## Usa una carta con innesco "azione" o "in_qualsiasi_momento" (pulsante del giocatore).
func usa(u: Dictionary) -> bool:
	var inn: Dictionary = u["innesco"]
	ctx["carta"] = u["img"]
	ctx["proprietario"] = u["chi"]
	if inn.get("condizione") is Dictionary and not inn["condizione"].is_empty() and valuta(inn["condizione"]) == false:
		_r("Condizione non soddisfatta", false)
		return false
	if inn.get("costo") is Array and not inn["costo"].is_empty():
		if not await esegui(inn["costo"]):
			return false
	_r("Usata: " + Carte.nome(str(u["img"])))
	await esegui(inn.get("effetti", []))
	return true

## Somma dei modificatori di un tiro di dado del Diario.
func modificatore_dado(mods) -> int:
	var mod := 0.0
	if not (mods is Array):
		return 0
	for m in mods:
		if not (m is Dictionary):
			continue
		var per := float(m.get("per", 1))
		if m.has("attr"):
			mod += p.attributo_compagnia(str(m["attr"])) * per
		elif m.has("ris"):
			mod += int(_attivo().get(str(m["ris"]), 0)) * per
		elif m.has("parti_status"):
			mod += p.parti_status(str(m["parti_status"])).size() * per
		else:
			mod += float(m.get("n", 0))
	return int(floor(mod))

## --- Effetti degli Incontri ---------------------------------------------------------------

func _passo_incontro(s: Dictionary) -> void:
	var t := str(s.get("tipo", ""))
	if inc.concluso != "" and t not in ["vinci"]:
		return
	match t:
		"cubi":
			var n := _n(s)
			if n >= 0:
				inc.riserva += n
				inc.nota("+%d alla Riserva (%d)." % [n, inc.riserva])
			else:
				inc._perdi_cubi(maxi(0, -n - inc.meno_cubi))
		"meno_cubi":
			inc.meno_cubi += _n(s)
		"ferite":
			inc._ferite(_n(s), ctx.get("attacco", false) and not s.get("inevitabile", false) and not ctx.get("finta", false))
		"previeni":
			inc.prevenzione += _n(s)
			inc.nota("Previeni %d Ferite." % int(s.get("n", 0)))
		"affinita":
			inc._affinita(_n(s))
		"pesca_carte":
			inc.pesca(inc.attivo_id, _n(s))
		"scarta_carte":
			if str(s.get("da", "mano")) == "mazzo":
				for i in int(s.get("n", 1)):
					if not inc.mazzi[inc.attivo_id].is_empty():
						inc.scarti[inc.attivo_id].append(inc.mazzi[inc.attivo_id].pop_front())
			else:
				inc._scarta_mano(int(s.get("n", 1)))
		"scarta_ultima":
			inc._scarta_ultima()
		"carta_aggiuntiva":
			inc.extra_disponibili += int(s.get("n", 1))
		"fuga_nemico":
			inc.concludi("fuga_nemico")
		"scappa":
			inc.scappa()
		"vinci":
			inc.concludi("vittoria")
		"ignora_tratto":
			inc.tratti_ignorati.append(str(s.get("tratto", "")))
		"scegli_attacco":
			inc.scegli_attacco = true
		"gettone_tempo_carta":
			for c in inc.sequenza:
				c["tempo"] = maxi(0, int(c.get("tempo", 0)) + int(s.get("n", 0)))
		"cariche":
			var n := _n(s)
			var voce := {}
			for c in inc.sequenza:
				if str(c.get("img", "")) == str(ctx.get("carta", "")):
					voce = c
			if voce.is_empty():
				if not inc.sequenza.is_empty():
					voce = inc.sequenza.back()
				else:
					return
			var att := int(voce.get("cariche", 0))
			if n < 0 and att < -n:
				_r("Cariche insufficienti (%d)" % att, false)
				interrotto = true
				return
			voce["cariche"] = att + n
			if n < 0:
				ctx["cariche_rimosse"] = -n
			inc.nota("Cariche su %s: %d" % [Carte.nome(str(voce.get("img", ""))), int(voce["cariche"])])
		_:
			_r("Effetto sconosciuto: " + t, false)

## --- Moltiplicatori ------------------------------------------------------------------------

func _conta(per) -> int:
	if per is int or per is float:
		return int(per)
	if not (per is Dictionary):
		return 1
	if per.has("chiavi"):
		return inc.chiavi_unite(str(per["chiavi"])) if inc else 0
	if per.has("cubi_dati"):
		return int(ctx.get("cubi_dati", 0))
	if per.has("attributo"):
		return p.attributo(_attivo(), str(per["attributo"]))
	if per.has("membri"):
		return inc.membri.size() if inc else p.compagnia().size()
	if per.has("giocatori"):
		return p.personaggi().size()
	if per.has("parti_status"):
		return p.parti_status(str(per["parti_status"])).size()
	if per.has("risorsa"):
		return int(_attivo().get(str(per["risorsa"]), 0))
	if per.has("cariche"):
		return int(ctx.get("cariche_rimosse", 0))
	if per.has("tiro"):
		return int(ctx.get("tiro", 0))
	return 1

## --- Condizioni -------------------------------------------------------------------------

## true / false, oppure null se va decisa dal giocatore.
func valuta(c):
	if not (c is Dictionary) or c.is_empty():
		return true
	if c.has("tutte"):
		var esito = true
		for x in c["tutte"]:
			var v = valuta(x)
			if v == false:
				return false
			if v == null:
				esito = null
		return esito
	if c.has("una"):
		var esito2 = false
		for x in c["una"]:
			var v2 = valuta(x)
			if v2 == true:
				return true
			if v2 == null:
				esito2 = null
		return esito2
	if c.has("non"):
		var v3 = valuta(c["non"])
		return null if v3 == null else not v3
	var t := str(c.get("tipo", ""))
	match t:
		"sempre":
			return true
		"altrimenti":
			return ctx.get("nessuna_valida", null)
		"status":
			var parti: Array = p.parti_status(str(c.get("nome", "")))
			if c.has("almeno"):
				return parti.size() >= int(c["almeno"])
			var richieste: Array = c.get("parti", [])
			if richieste.is_empty():
				return not parti.is_empty()
			for x in richieste:
				if not parti.has(int(x)):
					return false
			return true
		"segreto":
			if c.has("n"):
				return p.ha_segreto(int(c["n"]))
			for n in p.d.get("segreti", []):
				if Carte.nome(Carte.segreto(int(n))).to_lower() == str(c.get("nome", "")).to_lower():
					return true
			return false
		"oggetto":
			for x in p.compagnia():
				for o in x.get("oggetti", []):
					var d := Carte.dati(o)
					if c.has("nome") and Carte.nome(o).to_lower() == str(c["nome"]).to_lower():
						return true
					if c.has("parola") and str(d.get("parola", "")).to_lower() == str(c["parola"]).to_lower():
						return true
			return false
		"capitolo":
			var cap := p.capitolo()
			var ok := cap >= int(c.get("da", 0)) and cap <= int(c.get("a", c.get("da", 99)))
			if ok and str(c.get("lettera", "")) != "" and p.lettera_capitolo() != "":
				ok = p.lettera_capitolo() == str(c["lettera"])
			return ok
		"risorsa":
			var ris := str(c.get("ris", ""))
			var mn := int(c.get("min", 1))
			match str(c.get("chi", "compagnia")):
				"attivo":
					return int(_attivo().get(ris, 0)) >= mn
				"ognuno":
					return p.compagnia().all(func(x): return int(x.get(ris, 0)) >= mn)
				"totale":
					var tot := 0
					for x in p.compagnia():
						tot += int(x.get(ris, 0))
					return tot >= mn
			return p.compagnia().any(func(x): return int(x.get(ris, 0)) >= mn)
		"attributo":
			if inc or ctx.get("membro") is Dictionary:
				return p.attributo(_attivo(), str(c.get("attr", ""))) >= int(c.get("min", 1))
			return p.attributo_compagnia(str(c.get("attr", ""))) >= int(c.get("min", 1))
		"tiro":
			if not ctx.has("tiro"):
				return null
			return int(ctx["tiro"]) >= int(c.get("da", 0)) and int(ctx["tiro"]) <= int(c.get("a", 99))
		"menhir_qui":
			return p.menhir_attivo_qui() == bool(c.get("attivo", true))
		"tutti_personaggi":
			return p.compagnia_completa()
		"giocatori":
			var n := p.personaggi().size()
			return n >= int(c.get("da", 1)) and n <= int(c.get("a", 4))
		"gettoni_cerca":
			if c.has("luogo"):
				return int(p.d["gettoni"].get("cerca_luoghi", {}).get(str(_luogo(c["luogo"])), 0)) >= int(c.get("min", 1))
			return int(p.d["gettoni"].get("cerca", 0)) >= int(c.get("min", 1))
		"gettone_tempo":
			return int(p.d["gettoni"]["tempo"].get(str(_luogo(c.get("luogo", "qui"))), 0)) >= int(c.get("min", 1))
		"luogo_rivelato":
			return p.d["mappa"].has(str(int(c.get("n", 0))))
		"personaggio":
			return p.compagnia().any(func(x): return str(x["id"]) == str(c.get("id", "")))
		"incontro_vinto":
			return ctx.get("esito_incontro", null) == "vittoria" if ctx.has("esito_incontro") else null
		"incontro_perso":
			return ctx.get("esito_incontro", null) != "vittoria" if ctx.has("esito_incontro") else null
		"follia":
			return Personaggi.in_follia(_attivo())
		"morente":
			return Personaggi.morente(_attivo())
		"affinita":
			if not inc:
				return null
			return inc.affinita > 0 if str(c.get("colore", "verde")) == "verde" else inc.affinita < 0
		"riserva":
			return inc != null and inc.riserva >= int(c.get("min", 0))
		"carte_giocate":
			if not inc:
				return null
			if c.has("max"):
				return inc.carte_attivazione <= int(c["max"])
			return inc.carte_attivazione >= int(c.get("min", 0))
		"incontro_tipo":
			if not inc:
				return false
			if c.has("colore") and str(c["colore"]) != inc.colore:
				return false
			var tipo := "diplomazia" if inc.diplomazia else "combattimento"
			return str(c.get("tipo_incontro", tipo)) == tipo
		"insediamento":
			var sig: Array = Carte.luogo(p.luogo_attivo()).get("sigilli", [])
			if c.has("nemico"):
				return sig.has("settlement_enemy") if c["nemico"] else sig.has("settlement_friend")
			return sig.has("settlement_enemy") or sig.has("settlement_friend")
		"manuale":
			return null
	return null

## Descrizione leggibile di una condizione (per le domande al giocatore).
static func descrivi(c) -> String:
	if not (c is Dictionary):
		return ""
	if c.has("testo"):
		return Dati.testo_piano(str(c["testo"]))
	if c.has("tutte"):
		return " e ".join(c["tutte"].map(func(x): return descrivi(x)))
	if c.has("una"):
		return " o ".join(c["una"].map(func(x): return descrivi(x)))
	if c.has("non"):
		return "non " + descrivi(c["non"])
	return str(c.get("tipo", "")) + " " + str(c.get("nome", c.get("n", c.get("attr", ""))))
