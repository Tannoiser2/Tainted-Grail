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
	if s.get("riduci") is Array:
		# "perdi N, ridotto della tua Cautela": la quantità cala, senza cambiare segno
		var rid := 0
		var a := _attivo()
		for r in s["riduci"]:
			if not (r is Dictionary):
				continue
			if r.has("attributo"):
				if str(r["attributo"]) == "piu_alto":
					rid += Partita.ATTRIBUTI.map(func(k): return p.attributo(a, k)).max()
				else:
					rid += p.attributo(a, str(r["attributo"]))
			elif r.has("quantita"):
				rid += int(ctx.get("quantita", 0))
			elif r.has("n"):
				rid += int(r["n"])
		n = mini(0, n + rid) if n < 0 else maxi(0, n - rid)
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
				if v > 0 and not ctx.get("in_innesco_risorsa", false):
					ctx["in_innesco_risorsa"] = true
					for i in p.inneschi("ottieni_risorsa", x):
						var inn: Dictionary = i["innesco"]
						if inn.has("ris") and str(inn["ris"]) != ris:
							continue
						if inn.has("colore") and (inc == null or str(inn["colore"]) != inc.colore):
							continue
						if inn.get("condizione") is Dictionary and not inn["condizione"].is_empty() and valuta(inn["condizione"]) != true:
							continue
						_r(Carte.nome(str(i["img"])))
						await esegui(inn.get("effetti", []))
					ctx.erase("in_innesco_risorsa")
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
			if s.get("prossima", false):
				var gia: Array = p.parti_status(str(s["nome"]))
				var nx := 1
				while gia.has(nx):
					nx += 1
				parti = [nx]
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
			ctx["lancio"] = "graal" if graal else "teschio"
			p.d["ultimo_lancio"] = ctx["lancio"]
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
						vm = await _chiedi(s.get("condizione", {}), x)
					await esegui(s.get("allora", []) if vm else s.get("altrimenti", []))
				if vecchio_m == null:
					ctx.erase("membro")
				else:
					ctx["membro"] = vecchio_m
				return
			var v = valuta(s.get("condizione", {}))
			if v == null:
				v = await _chiedi(s.get("condizione", {}), {})
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
		"spunta":
			var sp: Dictionary = p.d.get_or_add("spunte", {})
			var nome := str(s.get("nome", ""))
			sp[nome] = maxi(0, int(sp.get(nome, 0)) + int(s.get("n", 1)))
			_r("Status \"%s\": %d spunte" % [nome, int(sp[nome])])
		"mercato":
			await _mercato(s)
		"quantita":
			# il giocatore sceglie quanto pagare (anche più risorse, anche ogni membro): il totale va in ctx.quantita
			var lr = s.get("ris", "salute")
			var risorse: Array = lr if lr is Array else [str(lr)]
			var chi_q: Array = p.compagnia() if s.get("totale", false) or str(s.get("chi", "")) == "compagnia" else [_attivo()]
			var mx = s.get("max", "tutto")
			var tot := 0
			for x in chi_q:
				for r in risorse:
					var disp := 0
					match str(r):
						"oggetti":
							disp = x.get("oggetti", []).size()
						"carte":
							disp = inc.mani.get(str(x["id"]), []).size() if inc else 0
						_:
							disp = int(x.get(str(r), 0))
					var lim := disp if str(mx) == "tutto" else mini(int(mx), disp)
					var opz := []
					for k in lim + 1:
						opz.append(str(k))
					var nome_r: String = {"oggetti": "Oggetti", "carte": "carte"}.get(str(r), Partita.NOMI_RISORSE.get(str(r), str(r)))
					var q: int = await _scegli("%s: quanti %s spendi? %s" % [x.get("nome", ""), nome_r, Dati.testo_leggibile(str(s.get("testo", "")))], opz) if lim > 0 else 0
					for k in q:
						match str(r):
							"oggetti":
								var og: Array = x.get("oggetti", [])
								var ko := await _scegli("Quale Oggetto scarti?", og.map(func(z): return Carte.nome(z)))
								p.scarta_oggetto(x, og[ko])
							"carte":
								if inc:
									inc._scarta_mano(1)
							_:
								p.modifica(x, str(r), -1)
					tot += q
					if q > 0:
						_r("%s spende %d %s" % [x.get("nome", ""), q, nome_r])
			if s.get("dividi_per_membri", false):
				tot = int(floor(float(tot) / maxf(1.0, float(p.compagnia().size()))))
			ctx["quantita"] = tot
			ctx["carte_scartate"] = tot
		"rimando":
			p.d["rimando"] = {"luogo": int(s.get("luogo", 0)), "verso": int(s.get("verso", -1))}
			_r("All'Inizio della prossima Giornata il Diario riprenderà dal Luogo %d" % int(s.get("luogo", 0)))
		"morte":
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				x["salute"] = 0
				x["morto"] = true
				p.racconta("%s muore." % x["nome"])
				_r("%s muore (regola della Morte)" % x["nome"])
		"guardiano":
			if str(s.get("azione", "piazza")) == "rimuovi":
				var gl := Partita.guardiani(p)
				for g in gl.duplicate():
					if Carte.nome(str(g["img"])).to_lower().replace(" ", "") == str(s.get("nome", "")).to_lower().replace(" ", ""):
						gl.erase(g)
						p.d["mazzi"].get_or_add("incontri_" + str(g.get("colore", "")), []).append(g["img"])
						p.d["mazzi"]["incontri_" + str(g.get("colore", ""))].shuffle()
				p.d.get("miniature", {}).erase(str(s.get("nome", "")))
				_r("%s tolto dalla mappa" % str(s.get("nome", "")))
			else:
				var prima := Partita.guardiani(p).size()
				var dove = s.get("luogo", "rivelato_numero_piu_basso")
				if str(dove) == "qui":
					dove = str(_luogo("qui"))
				Preparazione.piazza_guardiano(p, str(s.get("colore", "")), str(s.get("nome", "")), str(dove))
				if Partita.guardiani(p).size() > prima:
					var g2: Dictionary = Partita.guardiani(p).back()
					_r("Guardiano %s sul Luogo %d" % [Carte.nome(str(g2["img"])), int(g2["luogo"])])
					if s.get("inizia_se_personaggi", false) and p.personaggi().any(func(x): return int(x["luogo"]) == int(g2["luogo"])):
						var es := "vittoria"
						if ui and ui.has_method("risolvi_incontro"):
							es = await ui.risolvi_incontro(str(g2.get("colore", "")), Carte.nome(str(g2["img"])), 0)
						ctx["esito_incontro"] = es
		"miniatura":
			var mn: Dictionary = p.d.get_or_add("miniature", {})
			var luogo_m := int(s["luogo"]) if str(s.get("luogo", "")).is_valid_int() else _luogo_speciale(str(s.get("luogo", "qui")))
			mn[str(s.get("nome", ""))] = luogo_m
			_r("%s sul Luogo %d" % [str(s.get("nome", "")), luogo_m])
		"regola":
			p.d.get_or_add("regole", {})[str(s.get("nome", ""))] = bool(s.get("attiva", true))
			_r("Regola \"%s\" %s" % [str(s.get("nome", "")), "attiva" if s.get("attiva", true) else "non più attiva"])
		"tieni_risorse":
			var lr: Array = s["ris"] if s.get("ris") is Array else [str(s.get("ris", ""))]
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				var mx := 0
				if s.get("max") is Dictionary:
					var vals := Partita.ATTRIBUTI.map(func(k): return p.attributo(x, k))
					vals.sort()
					vals.reverse()
					for i in int(s["max"].get("attributi_piu_alti", 1)):
						mx += int(vals[i]) if i < vals.size() else 0
				else:
					mx = int(s.get("max", 0))
				var tot := 0
				for r in lr:
					tot += int(x.get(r, 0))
				while tot > mx:
					var opz := lr.filter(func(r): return int(x.get(r, 0)) > 0)
					var r2: String = opz[0] if opz.size() == 1 else opz[await _scegli("%s può tenere al massimo %d fra %s: cosa scarti? (ancora %d)" % [x["nome"], mx, ", ".join(lr.map(func(z): return Partita.NOMI_RISORSE.get(z, z))), tot - mx], opz.map(func(z): return Partita.NOMI_RISORSE.get(z, z)))]
					p.modifica(x, r2, -1)
					tot -= 1
				_r("%s tiene al massimo %d risorse" % [x["nome"], mx])
		"mod_tiro":
			if ctx.has("tiro"):
				ctx["tiro"] = maxi(int(s.get("min", -99)), int(ctx["tiro"]) + int(s.get("n", 0)))
				_r("Tiro modificato: %d" % int(ctx["tiro"]))
		"miglioramento":
			var tipo_m := str(s.get("mazzo", "combattimento"))
			for x in await _bersagli(str(s.get("chi", "attivo"))):
				for i in int(s.get("n", 1)):
					var r3: Array = x["mazzi"][tipo_m]["riserva"]
					var tre := r3.slice(0, 3)
					if tre.is_empty():
						continue
					var k3 := await _scegli("%s: scegli una carta di %s da aggiungere al mazzo" % [x["nome"], tipo_m.capitalize()], tre.map(func(z): return Carte.nome(z)))
					r3.erase(tre[k3])
					r3.shuffle()
					x["mazzi"][tipo_m]["mazzo"].append(tre[k3])
					_r("%s ottiene %s" % [x["nome"], Carte.nome(tre[k3])])
		"offerta":
			var punti := 0
			var val: Dictionary = s.get("valori", {})
			while ui != null and ui.has_method("scegli"):
				var opz2 := []
				var az2 := []
				var a3 := _attivo()
				if p.compagnia().any(func(x): return int(x.get("ricchezza", 0)) > 0):
					opz2.append("Dona 1 Ricchezza (+%d)" % int(val.get("ricchezza", 1)))
					az2.append({"ris": "ricchezza"})
				for x in p.compagnia():
					for o in x.get("oggetti", []):
						var fab: bool = Carte.dati(o).get("fabbricabile", false) or Carte.auto(o).get("fabbricabile", false)
						var pt := int(val.get("oggetto_fabbricabile", 1)) if fab else int(val.get("oggetto", 2))
						opz2.append("Dona %s di %s (+%d)" % [Carte.nome(o), x["nome"], pt])
						az2.append({"oggetto": o, "chi": x, "punti": pt})
				opz2.append("Basta così (punteggio %d)" % punti)
				az2.append({})
				var k4 := await _scegli("Offerta — punteggio attuale %d" % punti, opz2)
				var az: Dictionary = az2[k4]
				if az.is_empty():
					break
				if az.has("ris"):
					p.paga("ricchezza", 1, false)
					punti += int(val.get("ricchezza", 1))
				else:
					p.scarta_oggetto(az["chi"], az["oggetto"])
					punti += int(az["punti"])
			ctx["quantita"] = punti
			_r("Offerta: %d punti" % punti)
		"ignora_fallimento":
			p.d["ignora_fallimento"] = true
		"cambia_attivo":
			var lc := p.compagnia()
			if lc.size() > 1:
				var xc := await _scegli_personaggio("Chi risolve il prossimo Verso?", lc)
				p.d["attivo"] = p.personaggi().find(xc)
				_r("%s risolve il prossimo Verso" % xc["nome"])
		"unisciti", "unisci_personaggio":
			var qui := _luogo("qui")
			var vicini := p.collegati(qui)
			var lontani := p.personaggi().filter(func(x): return vicini.has(int(x["luogo"])))
			for x in lontani:
				if await _scegli("%s può unirsi alla Compagnia al Luogo %d. Lo fa?" % [x["nome"], qui], ["Sì", "No"]) == 0:
					var vecchio_p = ctx.get("proprietario")
					ctx["proprietario"] = x
					var ok2 := await esegui(s.get("costo", []))
					ctx["proprietario"] = vecchio_p
					if ok2:
						x["luogo"] = qui
						_r("%s si unisce alla Compagnia" % x["nome"])
					interrotto = false
		"rimescola_incontro", "ripesca_incontro":
			var ui2 := str(p.d.get("ultimo_incontro", ""))
			if ui2 != "":
				var col := str(Carte.dati(ui2).get("colore", ""))
				var mi: Array = p.d["mazzi"].get_or_add("incontri_" + col, [])
				mi.erase(ui2)
				if t == "ripesca_incontro" or s.get("in_fondo", false):
					mi.append(ui2)
				else:
					mi.append(ui2)
					mi.shuffle()
				_r("Incontro %s rimesso nel mazzo" % Carte.nome(ui2))
			if t == "ripesca_incontro" and ui and ui.has_method("risolvi_incontro"):
				var col2 := str(Carte.dati(ui2).get("colore", "grigio"))
				ctx["esito_incontro"] = await ui.risolvi_incontro(col2, "", 0)
		"abilita":
			var x2 := _attivo()
			var ab: Array = x2.get("abilita", [])
			if ab.is_empty():
				_r("%s non ha Abilità da cambiare" % x2.get("nome", ""), false)
				return
			var k := await _scegli("Quale Abilità scarti?", ab.map(func(z): return str(z.get("nome", ""))))
			var vecchia: Dictionary = ab[k]
			ab.remove_at(k)
			await scegli_abilita(x2, str(vecchia.get("attributo", "")))
		_:
			if inc:
				await _passo_incontro(s)
			else:
				_r("(effetto d'Incontro fuori dall'Incontro: %s)" % t, false)

## Luoghi indicati a parole: "rivelato_numero_piu_basso"/"_alto", "qui", "personaggio_numero_piu_alto".
func _luogo_speciale(dove: String) -> int:
	var luoghi: Array = p.d["mappa"].keys().map(func(k): return int(k))
	luoghi.sort()
	match dove:
		"rivelato_numero_piu_basso":
			return luoghi[0] if not luoghi.is_empty() else 0
		"rivelato_numero_piu_alto":
			return luoghi[-1] if not luoghi.is_empty() else 0
		"personaggio_numero_piu_alto":
			var mx := 0
			for x in p.personaggi():
				mx = maxi(mx, int(x["luogo"]))
			return mx
	return _luogo("qui")

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
				var o := p.pesca_oggetto(str(s.get("modo")) == "fabbricabile", a, str(s.get("parola", "")), str(s.get("escludi_parola", "")))
				if o == "" and s.get("alternativa") is Array:
					await esegui(s["alternativa"])
					continue
				_r(("Oggetto: " + Carte.nome(o)) if o != "" else "Nessun Oggetto disponibile", o != "")
		"nome":
			var o2 := p.prendi_oggetto_nome(str(s.get("nome", "")), a)
			if o2 == "" and s.get("alternativa") is Array:
				_r("Oggetto \"%s\" non disponibile" % s.get("nome", ""))
				await esegui(s["alternativa"])
				return
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
		dove = _chiave_quadrante(dove)
		if s.get("rimuovi", false):
			q.erase(dove)
			_r("Quadrante %s tolto" % dove)
			return
		var v := int(s["valore"]) if s.has("valore") else int(q.get(dove, {}).get("valore", 0)) + int(s.get("n", 0))
		if s.has("max"):
			v = mini(v, int(s["max"]))
		v = maxi(0, v)
		q[dove] = {"valore": v, "gettone": str(s.get("gettone", "tempo"))}
		_r("Quadrante %s: %d" % [dove, v])
		if dove.begins_with("personaggio:") and v == 0 and s.has("n") and int(s["n"]) < 0:
			# il quadrante accanto alla miniatura arrivato a 0: il Personaggio muore
			var id := dove.substr(12)
			for x in p.personaggi():
				if str(x["id"]) == id:
					x["salute"] = 0
					x["morto"] = true
					p.racconta("%s muore: il suo Quadrante è arrivato a 0." % x["nome"])
					_r("%s muore (Quadrante a 0)" % x["nome"])

## Chiave di un quadrante: "personaggio" diventa "personaggio:<id dell'attivo>", "qui" il Luogo attuale.
func _chiave_quadrante(dove: String) -> String:
	if dove == "personaggio":
		return "personaggio:" + str(_attivo().get("id", ""))
	if dove == "luogo:qui" or dove == "luogo" or dove == "qui":
		return "luogo:%d" % _luogo("qui")
	if dove == "nemico" and inc:
		return "nemico:" + inc.img
	return dove

## Negozio di Oggetti: si pescano N Oggetti, si comprano a prezzo, si vendono i propri; il resto torna nel mazzo.
func _mercato(s: Dictionary) -> void:
	var ris := str(s.get("risorsa", "ricchezza"))
	var m: Array = p.d["mazzi"].get_or_add("oggetti", [])
	var pila: Array = m.slice(0, int(s.get("n", 3)))
	for o in pila:
		m.erase(o)
	var comprati := 0
	var troppo_cari := []
	while ui != null and ui.has_method("scegli"):
		var opz := []
		var azioni := []
		for o in pila:
			var fab: bool = Carte.dati(o).get("fabbricabile", false) or Carte.auto(o).get("fabbricabile", false)
			var prezzo := int(s.get("prezzo_fabbricabile", s.get("prezzo", 2))) if fab else int(s.get("prezzo", 2))
			if s.has("max") and comprati >= int(s["max"]):
				break
			if troppo_cari.has(o):
				continue
			opz.append("Compra %s (%d %s)" % [Carte.nome(o), prezzo, Partita.NOMI_RISORSE.get(ris, ris)])
			azioni.append({"compra": o, "prezzo": prezzo})
		if s.has("vendita"):
			for x in p.compagnia():
				for o2 in x.get("oggetti", []):
					opz.append("Vendi %s di %s (+%d %s)" % [Carte.nome(o2), x["nome"], int(s["vendita"]), Partita.NOMI_RISORSE.get(ris, ris)])
					azioni.append({"vendi": o2, "chi": x})
		opz.append("Fine degli acquisti")
		azioni.append({})
		var k := await _scegli("Mercato", opz)
		var az: Dictionary = azioni[k]
		if az.is_empty():
			break
		if az.has("compra"):
			if not p.paga(ris, int(az["prezzo"]), false):
				_r("Non avete abbastanza %s" % Partita.NOMI_RISORSE.get(ris, ris), false)
				troppo_cari.append(az["compra"])
				continue
			var chi: Dictionary = await _scegli_personaggio("Chi prende %s?" % Carte.nome(az["compra"]), p.compagnia())
			chi["oggetti"].append(az["compra"])
			pila.erase(az["compra"])
			comprati += 1
			_r("Comprato %s" % Carte.nome(az["compra"]))
		elif az.has("vendi"):
			p.scarta_oggetto(az["chi"], az["vendi"])
			p.modifica(az["chi"], ris, int(s["vendita"]))
			_r("Venduto %s" % Carte.nome(az["vendi"]))
	for o in pila:
		m.append(o)
	m.shuffle()

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
	p.d["regole_incontro"] = s.get("inizio", []) if s.get("inizio") is Array else []
	if ui and ui.has_method("risolvi_incontro"):
		esito = await ui.risolvi_incontro(colore, str(s.get("nome", "")), int(s.get("livello", 0)))
	p.d.erase("regole_incontro")
	_r("Incontro %s: %s" % [colore, esito])
	ctx["esito_incontro"] = esito
	p.d["esito_incontro"] = esito
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
		"in_cima":
			var img3 := ""
			if s.get("questa", false):
				img3 = str(ctx.get("carta", ""))
			elif s.has("speciale"):
				img3 = p.trova_evento_speciale(str(s["speciale"]))
			elif s.has("parte"):
				var cv = s.get("capitolo")
				var lv = s.get("lettera")
				img3 = p.trova_evento(p.capitolo() if cv == null else int(cv), int(s["parte"]), p.lettera_capitolo() if lv == null else str(lv))
			if img3 != "":
				var me: Array = p.d["mazzi"].get_or_add("eventi", [])
				me.erase(img3)
				p.d.get_or_add("cerche", []).erase(img3)
				me.push_front(img3)
				_r("%s in cima al mazzo Eventi" % Carte.nome(img3))
			else:
				_r("Carta Evento non trovata", false)
		"scarta_cima":
			var me2: Array = p.d["mazzi"].get_or_add("eventi", [])
			for i in int(s.get("n", 1)):
				if not me2.is_empty():
					p.d["mazzi"].get_or_add("eventi_scarti", []).append(me2.pop_front())
			_r("Scartate %d carte dalla cima del mazzo Eventi" % int(s.get("n", 1)))
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
			if n < 0 and ctx.get("attacco", false) and inc.cubi_invertiti:
				n = -n
			if n >= 0:
				inc.riserva += n
				inc.nota("+%d alla Riserva (%d)." % [n, inc.riserva])
			else:
				inc._perdi_cubi(maxi(0, -n - inc.meno_cubi))
		"meno_cubi":
			inc.meno_cubi += _n(s)
		"ferite":
			var nf := _n(s)
			if ctx.get("attacco", false):
				nf += inc.ferite_extra
				inc.ferite_extra = 0
				if inc.ferite_in_cubi:
					inc.nota("Le Ferite diventano segnalini persi.")
					inc._perdi_cubi(maxi(0, nf - inc.meno_cubi))
					return
			inc._ferite(nf, ctx.get("attacco", false) and not s.get("inevitabile", false) and not ctx.get("finta", false))
		"previeni":
			inc.prevenzione += _n(s)
			inc.nota("Previeni %d Ferite." % int(s.get("n", 0)))
		"affinita":
			var na := _n(s)
			if na < 0 and ctx.get("attacco", false):
				var ig := mini(inc.frecce_giu_ignorate, -na)
				inc.frecce_giu_ignorate -= ig
				na += ig
				if ig > 0:
					inc.nota("%d ↓ ignorate." % ig)
				if inc.inverti_frecce:
					na = -na
			inc._affinita(na)
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
			var su := str(s.get("su", ""))
			if su == "scelta" and not inc.sequenza.is_empty():
				var k := await _scegli("Su quale carta della Sequenza?", inc.sequenza.map(func(z): return Carte.nome(str(z["img"]))))
				voce = inc.sequenza[k]
			elif su != "":
				for c in inc.sequenza:
					if Carte.nome(str(c.get("img", ""))).to_lower() == su.to_lower():
						voce = c
			if voce.is_empty():
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
		"ignora_attacco":
			inc.salta_attacco = true
			inc.nota("Il prossimo attacco nemico sarà ignorato.")
		"ignora_frecce_giu":
			inc.frecce_giu_ignorate += int(s.get("n", 99))
		"inverti_frecce":
			inc.inverti_frecce = true
		"previeni_scarto":
			inc.previeni_scarti += int(s.get("n", 1))
		"vinci_fase":
			inc.affinita = int(inc.carta.get("affinita", {}).get("verdi", 3))
			inc._controlla_affinita()
		"fallisci":
			inc.concludi("fallimento")
		"attacco_riga":
			if s.has("riga"):
				inc.riga_forzata = int(s["riga"])
			inc.sposta_riga += int(s.get("sposta", 0))
		"ferite_extra":
			inc.ferite_extra += _n(s)
		"ferite_in_cubi":
			inc.ferite_in_cubi = true
		"cubi_invertiti":
			inc.cubi_invertiti = true
		"nessun_bottino":
			inc.nessun_bottino = true
		"senza_opportunita":
			inc.senza_opportunita = true
		"rimescola_scarti":
			var sc: Array = inc.scarti.get(inc.attivo_id, [])
			sc.shuffle()
			for i in mini(int(s.get("n", 99)), sc.size()):
				inc.mazzi[inc.attivo_id].append(sc.pop_back())
			inc.mazzi[inc.attivo_id].shuffle()
			inc.nota("Carte scartate rimescolate nel mazzo.")
		"rimescola_mano":
			inc.rimescola_mano(inc.attivo_id)
		"attacco_opportunita":
			await inc.opportunita()
		"termina_incontro":
			var frazione := float(s.get("ricompensa", 0))
			if frazione > 0 and inc.auto.get("ricompensa") is Array:
				for st in inc.auto["ricompensa"]:
					if st is Dictionary and st.has("n"):
						var st2: Dictionary = st.duplicate()
						st2["n"] = int(floor(int(st["n"]) * frazione))
						if int(st2["n"]) != 0:
							await esegui([st2])
			inc.nessun_bottino = true
			inc.concludi("fuga_nemico")
		"raddoppia_chiavi":
			ctx["raddoppia_chiavi"] = true
			inc.nota("Le Chiavi della prossima carta contano doppio.")
			inc.raddoppia_prossima = true
		"chiave_magica_gratis":
			inc.magia_gratis += int(s.get("n", 1))
		"disattiva_oggetto":
			inc.nota("Un'Arma o uno Scudo resta inattivo fino alla fine del Combattimento.")
		"fine_turno":
			inc.salta_al_fine_turno = true
		"gioca_carta":
			var mano: Array = inc.mani.get(inc.attivo_id, [])
			if not mano.is_empty():
				var kg := await _scegli("Gioca subito una carta", mano.map(func(z): return Carte.nome(z)))
				inc.extra_disponibili += 1
				await inc.gioca(mano[kg])
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
	if per.has("ferite_subite"):
		return inc.ferite_subite if inc else 0
	if per.has("salute_mancante"):
		var a := _attivo()
		return maxi(0, Personaggi.limite(a, "salute") - int(a.get("salute", 0)))
	if per.has("quantita"):
		return int(ctx.get("quantita", 0))
	if per.has("spunte"):
		return int(p.d.get("spunte", {}).get(str(per["spunte"]), 0))
	if per.has("carte_scartate"):
		return int(ctx.get("carte_scartate", 0))
	if per.has("chiavi_questa_carta"):
		if inc:
			for sq in inc.sequenza:
				if str(sq.get("img", "")) == str(ctx.get("carta", "")):
					return sq.get("chiavi", []).size()
		return 0
	if per.has("menhir_attivi"):
		return p.d["menhir"].values().filter(func(m): return int(m.get("quadrante", 0)) > 0).size()
	if per.has("frecce_invertite"):
		return int(ctx.get("frecce_invertite", 0))
	if per.has("ogni"):
		var base := 1
		var resto: Dictionary = per.duplicate()
		resto.erase("ogni")
		if not resto.is_empty():
			base = _conta(resto)
		return int(floor(float(base) / maxf(1.0, float(per["ogni"]))))
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
			if c.get("max", false) is bool and c.get("max", false):
				var chi_m := str(c.get("chi", "attivo"))
				var lm: Array = [_attivo()] if chi_m == "attivo" else p.compagnia()
				return lm.any(func(x): return int(x.get(ris, 0)) >= Personaggi.limite(x, ris))
			if str(c.get("chi", "")).begins_with("id:"):
				var idc := str(c["chi"]).substr(3)
				return p.personaggi().any(func(x): return str(x["id"]) == idc and int(x.get(ris, 0)) >= mn)
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
			var gc := int(p.d["gettoni"].get("cerca_luoghi", {}).get(str(_luogo(c["luogo"])), 0)) if c.has("luogo") else int(p.d["gettoni"].get("cerca", 0))
			return gc >= int(c.get("min", 1 if not c.has("max") else 0)) and gc <= int(c.get("max", 999))
		"gettone_tempo":
			var gt := int(p.d["gettoni"]["tempo"].get(str(_luogo(c.get("luogo", "qui"))), 0))
			return gt >= int(c.get("min", 1 if not c.has("max") else 0)) and gt <= int(c.get("max", 999))
		"quadrante":
			var dq := str(c.get("dove", "menhir_qui"))
			var val = null
			if dq == "menhir_qui":
				var mq: Dictionary = p.d["menhir"].get(str(_luogo("qui")), {})
				val = null if mq.is_empty() else int(mq.get("quadrante", 0))
			elif dq.begins_with("menhir:"):
				var mq2: Dictionary = p.d["menhir"].get(dq.substr(7), {})
				val = null if mq2.is_empty() else int(mq2.get("quadrante", 0))
			else:
				var qd: Dictionary = p.d.get("quadranti", {}).get(_chiave_quadrante(dq), {})
				val = null if qd.is_empty() else int(qd.get("valore", 0))
			if not c.has("da") and not c.has("a"):
				return val != null
			return val != null and int(val) >= int(c.get("da", -99)) and int(val) <= int(c.get("a", 99))
		"lancio":
			var es = ctx.get("lancio", p.d.get("ultimo_lancio"))
			return null if es == null else str(es) == str(c.get("esito", "graal"))
		"menhir":
			var ml: Dictionary = p.d["menhir"].get(str(_luogo(c.get("luogo", "qui"))), {})
			if ml.is_empty():
				return false
			if c.get("attivo", false) and int(ml.get("quadrante", 0)) <= 0:
				return false
			return int(ml.get("quadrante", 0)) >= int(c.get("min_quadrante", 0))
		"luogo_rimosso":
			return p.d.get("rimossi", []).has(int(c.get("n", 0)))
		"luogo_disponibile":
			var nl := int(c.get("n", 0))
			return not p.d.get("rimossi", []).has(nl)
		"in_raggio_menhir":
			var nr := int(c.get("n", 0))
			if not p.d["mappa"].has(str(nr)):
				return false
			for k in p.d["menhir"]:
				if int(p.d["menhir"][k].get("quadrante", 0)) > 0:
					var a1 := p.cella(int(k))
					var b1 := p.cella(nr)
					if absi(a1.x - b1.x) <= 1 and absi(a1.y - b1.y) <= 1:
						return true
			return false
		"esito_incontro":
			var ei = ctx.get("esito_incontro", p.d.get("esito_incontro"))
			if ei == null:
				return false
			var vole := str(c.get("esito", "vittoria"))
			if vole == "fuga" and str(ei) == "morte":
				return false
			return str(ei) == vole
		"incontro_pescato":
			return Carte.nome(str(p.d.get("ultimo_incontro", ""))).to_lower() == str(c.get("nome", "")).to_lower()
		"tratto":
			return inc != null and inc.ha_tratto(str(c.get("nome", "")))
		"somma":
			var tot := 0.0
			for tm in c.get("termini", []):
				if tm is Dictionary:
					tot += _termine(tm)
			var molt := p.personaggi().size() if c.get("per_giocatori", false) else 1
			return tot >= float(c.get("da", -999)) * molt and tot <= float(c.get("a", 999)) * molt
		"spunte":
			var ns := int(p.d.get("spunte", {}).get(str(c.get("nome", "")), 0))
			return ns >= int(c.get("min", 0)) and ns <= int(c.get("max", 999))
		"evento_in_gioco", "cerca_attiva":
			var carte_g: Array = p.d.get("cerche", []).duplicate()
			if str(c.get("tipo")) == "evento_in_gioco" and str(p.d.get("evento", "")) != "":
				carte_g.append(p.d["evento"])
			for e in carte_g:
				var de := Carte.dati(str(e))
				if Carte.num(de, "capitolo") == int(c.get("capitolo", -2)) and Carte.num(de, "parte") == int(c.get("parte", -2)):
					if c.get("lettera") == null or Carte.txt(de, "lettera") == "" or Carte.txt(de, "lettera") == str(c["lettera"]):
						return true
			return false
		"rimando":
			return ctx.get("rimando", false)
		"oggetto_disponibile":
			for o in p.d["mazzi"].get("oggetti", []):
				if Carte.nome(o).to_lower() == str(c.get("nome", "")).to_lower():
					return true
			return false
		"ferite_subite":
			return inc != null and inc.ferite_subite >= int(c.get("min", 1))
		"sequenza_termina":
			return inc != null and inc.chiavi_unite(str(c.get("attr", ""))) > 0
		"affinita_minima":
			return inc != null and inc.affinita <= -int(inc.carta.get("affinita", {}).get("rossi", 3)) + 0
		"mazzo_vuoto":
			return inc != null and inc.mazzi.get(inc.attivo_id, []).is_empty()
		"carta_girata":
			return inc != null and inc.usati_inneschi.has(str(ctx.get("carta", "")) + ":girata")
		"evento_casuale":
			return Carte.gruppo("eventi_casuali").has(str(p.d.get("evento", "")))
		"incubo":
			return _attivo().get("incubo", false)
		"ha_mangiato":
			return _attivo().get("ha_mangiato", false)
		"esausto":
			return Personaggi.esausto(_attivo())
		"sacrificio":
			var q2 := int(ctx.get("quantita", 0))
			return q2 >= int(c.get("da", 0)) and q2 <= int(c.get("a", 999))
		"luogo_rivelato":
			return p.d["mappa"].has(str(int(c.get("n", 0))))
		"personaggio":
			return p.compagnia().any(func(x): return str(x["id"]) == str(c.get("id", "")))
		"incontro_vinto":
			var ev1 = ctx.get("esito_incontro", p.d.get("esito_incontro"))
			return null if ev1 == null else str(ev1) == "vittoria"
		"incontro_perso":
			var ev2 = ctx.get("esito_incontro", p.d.get("esito_incontro"))
			return null if ev2 == null else str(ev2) != "vittoria"
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
		"conta_luoghi":
			var nc := 0
			for k in p.d["mappa"]:
				if int(k) == int(c.get("numero", 0)) or str(k).begins_with(str(int(c.get("numero", 0))) + "_"):
					nc += 1
			nc = maxi(nc, int(p.d.get("tuathan", 0)) if int(c.get("numero", 0)) == 199 else 0)
			return nc >= int(c.get("min", 0)) and nc <= int(c.get("max", 999))
		"posizione":
			return p.personaggi().any(func(x): return int(x["luogo"]) == int(c.get("luogo", 0)))
		"miniatura":
			var nm := str(c.get("nome", "")).to_lower()
			if p.d.get("miniature", {}).has(str(c.get("nome", ""))):
				return not c.has("luogo") or int(p.d["miniature"][str(c["nome"])]) == _luogo(c["luogo"])
			return Partita.guardiani(p).any(func(g): return Carte.nome(str(g["img"])).to_lower() == nm and (not c.has("luogo") or int(g["luogo"]) == _luogo(c["luogo"])))
		"attacco_opportunita":
			return ctx.get("opportunita", false)
		"cubi_carta":
			return int(ctx.get("cubi_dati", 0)) >= int(c.get("min", 1))
		"manuale":
			return null
	push_warning("Condizione sconosciuta: " + t)
	return false

## Un termine di una somma: attributo (il più alto della Compagnia o di un Personaggio), risorse, numero.
func _termine(tm: Dictionary) -> float:
	var v := 0.0
	var chi := str(tm.get("chi", tm.get("id", "")))
	var persone: Array = p.compagnia()
	if tm.has("id"):
		persone = p.personaggi().filter(func(x): return str(x["id"]) == str(tm["id"]))
	if tm.has("attr"):
		var mx := 0
		for x in persone:
			mx = maxi(mx, p.attributo(x, str(tm["attr"])))
		v = mx
	elif tm.has("ris"):
		var lr: Array = tm["ris"] if tm["ris"] is Array else [tm["ris"]]
		var chi_l: Array = p.personaggi() if chi == "tutti" else ([_attivo()] if chi == "attivo" else persone)
		for x in chi_l:
			for r in lr:
				v += int(x.get(str(r), 0))
	else:
		v = float(tm.get("n", 0))
	if tm.has("per"):
		v = floor(v * float(tm["per"]))
	return v

## Condizione che il gioco non può verificare: si chiede al giocatore come una domanda chiara.
func _chiedi(c, x: Dictionary) -> bool:
	var testo := descrivi(c)
	var chi := ("%s: " % x["nome"]) if not x.is_empty() else ""
	return await _scegli("%s%s?" % [chi, testo.trim_suffix(".")], ["Sì", "No"]) == 0

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
