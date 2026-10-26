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
var auto: Dictionary = {}         # effetti strutturati della carta Incontro (data/automazione.json)
var ui = null                     # finestra per le scelte del giocatore (vedi Interprete)
var tratti_ignorati: Array = []
var scegli_attacco := false
var ferite_subite := 0
var usati_inneschi := {}
# effetti delle Capacità che valgono per l'attacco/Risposta di questa attivazione
var salta_attacco := false
var frecce_giu_ignorate := 0
var inverti_frecce := false
var previeni_scarti := 0
var ferite_extra := 0
var ferite_in_cubi := false
var cubi_invertiti := false
var riga_forzata := -1          # indice della riga della tabella da usare
var sposta_riga := 0
var nessun_bottino := false
var senza_opportunita := false
var raddoppia_prossima := false
var magia_gratis := 0
var salta_al_fine_turno := false
var _frecce_tolte := false
var giocando := false              # si sta risolvendo la carta appena giocata
var _speciale_doppio := false
var _speciale_su := false
var extra_regole: Array = []     # modificatori aggiunti dal Diario per questo Incontro          # inneschi "una volta per Incontro" già usati / carte girate

func _init(partita_: Partita, img_: String, colore_: String) -> void:
	partita = partita_
	img = img_
	carta = Carte.dati(img)
	auto = Carte.auto(img)
	colore = colore_
	diplomazia = colore == "blu" or str(carta.get("sottotipo", "")) == "diplomazia"

## --- Preparazione --------------------------------------------------------------------

func speciale() -> bool:
	return carta.get("speciale", false) or (not carta.has("valore") and not carta.has("fasi"))

func tratti() -> Array:
	var t: Array = carta.get("tratti", []).duplicate()
	for m in regole_carta("tratto_extra") + partita.modificatori("tratto_extra"):
		if not t.has(str(m.get("tratto", ""))):
			t.append(str(m.get("tratto", "")))
	return t

## Valore del nemico (modificato da regole e carte).
func valore() -> int:
	var v := int(carta.get("valore", 99))
	for m in regole_carta("valore_nemico") + partita.modificatori("valore_nemico"):
		v += int(m.get("n", 0))
	return v

## Modificatori dati dalle regole speciali della carta Incontro e dagli effetti "inizio" del Diario.
func regole_carta(cosa: String) -> Array:
	var out := []
	for fonte in [auto.get("regola_speciale", []), extra_regole]:
		if not (fonte is Array):
			continue
		for inn in fonte:
			if not (inn is Dictionary):
				continue
			var lst: Array = inn.get("effetti", []) if inn.has("effetti") else [inn]
			for s in lst:
				if s is Dictionary and str(s.get("tipo", "")) == "modificatore" and str(s.get("cosa", "")) == cosa:
					out.append(s)
	return out

## Modificatori attivi ora per il personaggio attivo: carte dei Personaggi, regole della carta Incontro
## e Capacità delle carte nella Sequenza.
func mod(cosa: String) -> Array:
	var out: Array = partita.modificatori(cosa, attivo()) + regole_carta(cosa)
	for v in sequenza:
		for cap in Carte.auto(str(v.get("img", ""))).get("capacita", []) if Carte.auto(str(v.get("img", ""))).get("capacita") is Array else []:
			if cap is Dictionary and str(cap.get("innesco", "")) in ["passiva", "piazza"]:
				for s in cap.get("effetti", []):
					if s is Dictionary and str(s.get("tipo", "")) == "modificatore" and str(s.get("cosa", "")) == cosa:
						var s2: Dictionary = s.duplicate()
						s2["_voce"] = v
						out.append(s2)
	return out

func ha_tratto(t: String) -> bool:
	for ig in tratti_ignorati:
		if t.to_lower().begins_with(str(ig).to_lower().substr(0, 5)) or str(ig).to_lower().begins_with(t.to_lower()):
			return false
	if partita.tratto_ignorato(t):
		return false
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
		for i in n_mano + partita.somma_modificatori("mano_iniziale", p):
			pesca(id)
	nota("Inizia %s: %s (%s)" % ["la Diplomazia" if diplomazia else "il Combattimento", Carte.nome(img), ", ".join(tratti()) if not tratti().is_empty() else "nessun tratto"])
	# regole speciali della carta, effetti iniziali, inneschi delle carte dei Personaggi
	if auto.get("regola_speciale") is Array:
		for inn in auto["regola_speciale"]:
			if inn is Dictionary and str(inn.get("quando", "sempre")) in ["sempre", "inizio_incontro"]:
				var it0 := Interprete.new(partita, self, ui, {"carta": img})
				if inn.get("condizione") is Dictionary and not inn["condizione"].is_empty() and it0.valuta(inn["condizione"]) == false:
					continue
				await _esegui(inn.get("effetti", []), {"carta": img})
	if auto.get("inizio") is Array and not auto["inizio"].is_empty():
		await _esegui(auto["inizio"], {"carta": img})
	var ri = partita.d.get("regole_incontro", [])
	if ri is Array and not ri.is_empty():
		for s in ri:
			if s is Dictionary and str(s.get("tipo", "")) == "modificatore":
				extra_regole.append(s)
		await _esegui(ri.filter(func(s): return s is Dictionary and str(s.get("tipo", "")) != "modificatore"), {"carta": img})
	var sa := regole_carta("solo_abilita")
	if not sa.is_empty():
		partita.d["solo_abilita"] = str(sa[0].get("attr", ""))
		nota("Si possono usare solo le Abilità di %s." % Partita.NOMI_ATTRIBUTI.get(partita.d["solo_abilita"], partita.d["solo_abilita"]))
	await scatena("inizio_incontro")
	await scatena("inizio_diplomazia" if diplomazia else "inizio_combattimento")
	if speciale() and auto.get("effetto") is Array and not auto["effetto"].is_empty():
		nota("Incontro speciale: " + Dati.testo_piano(str(carta.get("testo", {}).get("it", ""))))
		await _esegui(auto["effetto"], {"carta": img})
		if concluso == "":
			concludi("vittoria")

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
	salta_attacco = false
	frecce_giu_ignorate = 0
	inverti_frecce = false
	previeni_scarti = 0
	ferite_extra = 0
	ferite_in_cubi = false
	cubi_invertiti = false
	riga_forzata = -1
	sposta_riga = 0
	nota("Si attiva %s." % attivo()["nome"])
	if primo_attivato:
		primo_attivato = false
		if ha_tratto("Imbosc"):
			while mani[id].size() > 1:
				scarti[id].append(mani[id].pop_back())
			nota("Imboscata: %s scarta fino ad avere 1 carta." % attivo()["nome"])
		if ha_tratto("Improvv"):
			await _ferite(2, false)
			nota("Improvviso: 2 Ferite a %s." % attivo()["nome"])
	# 1. Capacità ritardate: −1 gettone Tempo su ogni carta della Sequenza (e carte dei Personaggi)
	await scatena("capacita_ritardate", attivo())
	for s in sequenza:
		if int(s.get("tempo", 0)) > 0:
			s["tempo"] = int(s["tempo"]) - 1
			esegui_capacita(str(s["img"]), "tempo_rimosso")
			if s["tempo"] == 0 and sequenza.back() == s:
				nota("Capacità ritardata di %s." % Carte.nome(str(s["img"])))
				await esegui_capacita(str(s["img"]), "ritardata")
	await scatena("attivazione", attivo())
	cambiato.emit()

## Il personaggio attivo è in Panico: la prima carta è quella in cima al mazzo.
func in_panico() -> bool:
	if not partita.modificatori("ignora_panico", attivo()).is_empty():
		return false
	if not regole_carta("panico_sempre").is_empty():
		return true
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
				var bm: Array = b.duplicate()
				if not bm.has("extra") and not mod("chiave_magia_come").is_empty():
					bm.append("extra")
				out.append({"riga": r, "bonus": bm, "tipo": "magia", "attr": "magic", "ok": _magia_disponibile() > 0})
			continue
		var liv := int(prev.get("liv", 1))
		out.append({"riga": r, "bonus": b, "tipo": "attributo", "attr": str(a), "ok": partita.attributo(attivo(), str(a)) >= liv, "liv": liv})
	var fb := _lista(d.get("fondo", {}).get("bonus"))
	if not fb.is_empty():
		var mf := _moltiplicatore(ap["molt"])
		if mf == 0 and not mod("chiavi_senza_costo_1x").is_empty():
			mf = 1
		out.append({"riga": 5, "bonus": fb, "tipo": "fondo", "attr": "", "ok": true, "molt": mf})
	return out

## Cariche sulle carte della Sequenza che si possono spendere come Magia (Magia di sangue).
func _cariche_magia() -> Array:
	return mod("cariche_come_risorsa").filter(func(m): return str(m.get("ris", "")) == "magia" and m.get("_voce") is Dictionary and int(m["_voce"].get("cariche", 0)) > 0)

func _magia_disponibile() -> int:
	var t := 0
	for m in _cariche_magia():
		t += int(m["_voce"].get("cariche", 0))
	var pg := partita.paganti("magia")
	for p in membri:
		if pg.has(p):
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
	for m in partita.modificatori("max_carte_attivazione") + regole_carta("max_carte_attivazione"):
		if carte_attivazione >= int(m.get("n", 99)):
			return false
	var draw_extra := not mod("bonus_equivalenti").is_empty() or not partita.modificatori("bonus_equivalenti").is_empty()
	for k in collegamenti(c):
		if k["ok"] and (k["bonus"].has("extra") or (draw_extra and k["bonus"].has("draw"))) and (k["tipo"] != "magia" or paga_magia):
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
	var unite := []
	giocando = true
	_frecce_tolte = false
	# carte che cambiano i bonus speciali (Lacrima, Posa intimidatoria, Singhiozzo lamentoso)
	_speciale_doppio = false
	_speciale_su = not mod("speciale_come_su").filter(func(m): return not m.get("solo_carta_giocata", false)).is_empty()
	for cap in (Carte.auto(c).get("capacita", []) if Carte.auto(c).get("capacita") is Array else []):
		if cap is Dictionary:
			for s in cap.get("effetti", []):
				if s is Dictionary and str(s.get("cosa", "")) == "raddoppia_speciale":
					_speciale_doppio = true
	if diplomazia and not _speciale_su and cols.any(func(k): return k["ok"] and k["bonus"].has("special")):
		for m in mod("speciale_come_su"):
			if m.get("solo_carta_giocata", false) and m.get("_voce") is Dictionary and int(m["_voce"].get("cariche", 0)) > 0 and m["_voce"] != sequenza.back():
				var si := true
				if ui and ui.has_method("scegli"):
					si = await ui.scegli("Spendere 1 Carica di %s per considerare i bonus speciali di questa carta come Frecce su?" % Carte.nome(str(m["_voce"]["img"])), ["Sì", "No"]) == 0
				if si:
					m["_voce"]["cariche"] = int(m["_voce"]["cariche"]) - 1
					_speciale_su = true
				break
	for k in cols:
		if not k["ok"]:
			continue
		if k["tipo"] != "fondo":
			unite.append(str(k.get("attr", "")))
		if k["tipo"] == "magia":
			if not paga_magia:
				continue
			_paga_magia()
			sequenza.back()["magia"] = int(sequenza.back()["magia"]) + 1
		var molt := int(k.get("molt", 1)) if k["tipo"] == "fondo" else 1
		if raddoppia_prossima:
			molt *= 2
		for b in k["bonus"]:
			cubi += _bonus(str(b), molt, str(k.get("attr", "")), prima)
	if prima and not diplomazia and cubi > 0 and not partita.modificatori("raddoppia_prima_carta", attivo()).is_empty():
		riserva += cubi
		nota("Attacco furtivo: segnalini raddoppiati (+%d)." % cubi)
		cubi *= 2
	if prima and ha_tratto("Difens") and cubi > 0 and not diplomazia:
		riserva = maxi(0, riserva - 1)
		nota("Difensivo: un segnalino in meno.")
	raddoppia_prossima = false
	sequenza.back()["chiavi"] = unite
	for a in unite:
		await scatena("collega_chiave", attivo(), {"attr": a})
	# Capacità "al piazzarla" (dopo i bonus delle Chiavi), passive, o ritardata (gettone Tempo)
	for cap in _capacita(c):
		if str(cap.get("innesco", "")) == "ritardata":
			sequenza.back()["tempo"] = maxi(1, int(cap.get("tempo", 1)))
	await esegui_capacita(c, "piazza", {"cubi_dati": cubi})
	await esegui_capacita(c, "passiva", {"cubi_dati": cubi})
	await scatena("gioca_carta", attivo())
	giocando = false
	_controlla_fine_carte()
	cambiato.emit()

func _paga_magia() -> void:
	if magia_gratis > 0:
		magia_gratis -= 1
		return
	var cm := _cariche_magia()
	if not cm.is_empty():
		var v: Dictionary = cm[0]["_voce"]
		v["cariche"] = int(v["cariche"]) - 1
		nota("Speso 1 Carica di %s come Magia." % Carte.nome(str(v.get("img", ""))))
		return
	var a := attivo()
	var pg := partita.paganti("magia")
	if int(a.get("magia", 0)) > 0 and pg.has(a):
		partita.modifica(a, "magia", -1)
		return
	for p in membri:
		if int(p.get("magia", 0)) > 0 and pg.has(p):
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
			if prima and diplomazia and not _frecce_tolte:
				_frecce_tolte = true
				var meno := partita.somma_modificatori("frecce_prima_carta", attivo())
				if meno != 0:
					n = maxi(0, n + meno)
					nota("Prima carta dell'Attivazione: %+d Freccia su." % meno)
			_affinita(n)
		"arrowdown":
			_affinita(-n)
		"special":
			for i in (2 if _speciale_doppio else 1):
				if _speciale_su and diplomazia:
					_affinita(1)
				else:
					_speciale(attr)
	return 0

func _scarta_ultima() -> void:
	if sequenza.is_empty():
		return
	var s: Dictionary = sequenza.pop_back()
	scarti[str(s.get("pid", attivo_id))].append(s["img"])
	nota("Scartata l'ultima carta della Sequenza (%s)." % Carte.nome(str(s["img"])))
	esegui_capacita(str(s["img"]), "scartata")

## Colore della casella dove sta il marcatore di Affinità ("verde", "grigio", "rosso"), dalla sequenza
## stampata sulla carta (dall'alto: es. "VVVRRGR" ha anche caselle rosse sopra la grigia di partenza).
func colore_affinita() -> String:
	var seq := str(carta.get("affinita", {}).get("sequenza", "")) if carta.get("affinita") is Dictionary else ""
	var g := seq.find("G")
	if seq == "" or g < 0:
		return "verde" if affinita > 0 else ("rosso" if affinita < 0 else "grigio")
	var i := clampi(g - affinita, 0, seq.length() - 1)
	return {"V": "verde", "G": "grigio", "R": "rosso"}.get(seq[i], "grigio")

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
	var af: Array = auto.get("fasi", []) if auto.get("fasi") is Array else []
	if fase < af.size() and af[fase] is Dictionary and af[fase].get("speciale") is Dictionary:
		var spa: Dictionary = af[fase]["speciale"]
		var passi = spa.get(attr, spa.get("*"))
		if passi is Array:
			nota("Bonus speciale (%s)." % Partita.NOMI_ATTRIBUTI.get(attr, attr))
			await _esegui(passi, {"carta": img})
			return
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
	if p.is_empty():
		return
	var nn := n
	# Guardia del corpo: un altro membro può subire le Ferite al suo posto (diventano inevitabili)
	if not diplomazia and n > 0:
		for y in membri:
			if y != p and int(y.get("salute", 0)) > 1 and not partita.modificatori("assorbi_ferite_compagni", y).is_empty():
				var si := false
				if ui and ui.has_method("scegli"):
					si = await ui.scegli("%s può subire le %d Ferite al posto di %s (Guardia del corpo, inevitabili)." % [y["nome"], n, p["nome"]], ["Sì, le subisce %s" % y["nome"], "No"]) == 0
				if si:
					partita.modifica(y, "salute", -n)
					nota("%s subisce %d Ferite al posto di %s (Salute %d)." % [y["nome"], n, p["nome"], int(y["salute"])])
					ferite_subite += n
					return
	if prevenibili and prevenzione > 0:
		var x := mini(prevenzione, nn)
		nn -= x
		prevenzione -= x
		if x > 0:
			nota("%d Ferite prevenute." % x)
	if nn > 0:
		partita.modifica(p, "salute", -nn)
		nota("%s subisce %d Ferite (Salute %d)." % [p["nome"], nn, int(p["salute"])])
		ferite_subite += nn
		scatena("ferite", p, {"ferite": nn})
		scatena("perdi_salute", p, {"ferite": nn})

func _perdi_cubi(n: int) -> void:
	var resto := n - riserva
	riserva = maxi(0, riserva - n)
	nota("−%d segnalini (Riserva %d)." % [n, riserva])
	if resto > 0:
		_scarta_mano(resto)

func _scarta_mano(n: int) -> void:
	var id := attivo_id
	if attivo().is_empty() or not mani.has(id):
		return
	if previeni_scarti > 0:
		var x := mini(previeni_scarti, n)
		previeni_scarti -= x
		n -= x
		if x > 0:
			nota("%d scarti prevenuti." % x)
	var scartate := []
	for i in n:
		if not mani[id].is_empty():
			var c: String = mani[id].pop_back()
			scarti[id].append(c)
			scartate.append(c)
		elif not mazzi[id].is_empty():
			scarti[id].append(mazzi[id].pop_front())
	if n > 0:
		nota("%s scarta %d carta." % [attivo()["nome"], n])
	for c in scartate:
		esegui_capacita(c, "scartata")

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
	elif riserva >= valore():
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
			await opportunita()
			if carte_attivazione == 0:
				pesca(attivo_id)
		if concluso == "" and riserva >= valore():
			concludi("vittoria")
			return
		if concluso == "":
			var volte := 2 if ha_tratto("Furia") else 1
			for i in volte:
				await _attacco()
				if concluso != "":
					break
			if ha_tratto("Orda") and concluso == "":
				for i in 2:
					if not mazzi[attivo_id].is_empty():
						scarti[attivo_id].append(mazzi[attivo_id].pop_front())
				nota("Orda: scartate le 2 carte in cima al mazzo.")
			if concluso == "" and riserva >= valore():
				concludi("vittoria")
	else:
		# inizio della verifica dell'Affinità (Ultima risorsa…)
		await scatena("verifica_affinita", attivo())
		var fase_vinta := _controlla_affinita() if concluso == "" else true
		if concluso == "" and not fase_vinta:
			var fs: Array = carta.get("fasi", [])
			if not fs.is_empty():
				var r = fs[clampi(fase, 0, fs.size() - 1)].get("risposta", {})
				var t := str(r.get("it", "")) if r is Dictionary else str(r)
				nota("Risposta: " + Dati.testo_piano(t))
				var af: Array = auto.get("fasi", []) if auto.get("fasi") is Array else []
				await scatena("attacco", attivo())
				if salta_attacco:
					salta_attacco = false
					nota("La Risposta è ignorata.")
				elif fase < af.size() and af[fase] is Dictionary and af[fase].get("risposta") is Array:
					await _esegui(af[fase]["risposta"], {"carta": img, "attacco": true, "finta": ha_tratto("Finta")})
				else:
					applica_testo(t, true)
				scatena("dopo_attacco", attivo())
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
	var ra := riga_tabella_auto()
	if scegli_attacco and ui and ui.has_method("scegli"):
		var righe: Array = carta.get("tabella", [])
		var nomi := []
		var indici := []
		for i in righe.size():
			var tx := Dati.testo_piano(str(righe[i].get("it", "")))
			if tx.to_lower().begins_with("fugg"):
				continue
			nomi.append("%d-%d: %s" % [int(righe[i].get("da", 0)), int(righe[i].get("a", 0)), tx])
			indici.append(i)
		if not nomi.is_empty():
			var k: int = indici[await ui.scegli("Scegli l'attacco nemico", nomi)]
			r = righe[k]
			ra = {}
			var at: Array = auto.get("tabella", []) if auto.get("tabella") is Array else []
			for x in at:
				if x is Dictionary and int(x.get("da", -1)) == int(r.get("da", -2)):
					ra = x
	var righe_t: Array = carta.get("tabella", [])
	if (riga_forzata >= 0 or sposta_riga != 0) and not righe_t.is_empty():
		var idx := righe_t.find(r) if riga_forzata < 0 else riga_forzata
		idx = clampi(idx + sposta_riga, 0, righe_t.size() - 1)
		r = righe_t[idx]
		ra = {}
		for x in (auto.get("tabella", []) if auto.get("tabella") is Array else []):
			if x is Dictionary and int(x.get("da", -1)) == int(r.get("da", -2)):
				ra = x
	if r.is_empty() and ra.is_empty():
		return
	# Capacità visibile "durante l'attacco" (ultima carta della Sequenza) e carte dei Personaggi
	if not sequenza.is_empty():
		await esegui_capacita(str(sequenza.back()["img"]), "attacco")
	await scatena("attacco", attivo())
	if concluso != "":
		return
	if salta_attacco:
		salta_attacco = false
		nota("L'attacco nemico è ignorato.")
		return
	nota("Attacco nemico (Riserva %d): %s" % [riserva, Dati.testo_piano(str(r.get("it", "")))])
	ferite_subite = 0
	if ra.get("effetti") is Array:
		await _esegui(ra["effetti"], {"carta": img, "attacco": true, "finta": ha_tratto("Finta")})
	else:
		applica_testo(str(r.get("it", "")), true)
	scatena("dopo_attacco", attivo())

## Riga codificata della tabella d'attacco per la Riserva attuale.
func riga_tabella_auto() -> Dictionary:
	if not (auto.get("tabella") is Array):
		return {}
	for r in auto["tabella"]:
		if r is Dictionary and riserva >= int(r.get("da", 0)) and riserva <= int(r.get("a", 99)):
			return r
	return {}

## Attacco di opportunità (Combattimento).
func opportunita() -> void:
	await scatena("attacco_opportunita", attivo(), {"opportunita": true})
	nota("Attacco di opportunità: " + Dati.testo_piano(str(carta.get("opportunita", {}).get("it", ""))))
	if auto.get("opportunita") is Array:
		await _esegui(auto["opportunita"], {"carta": img, "attacco": true, "finta": ha_tratto("Finta")})
	else:
		applica_testo(str(carta.get("opportunita", {}).get("it", "")), true)

## Fine del turno: si scarta fino a 3, si pesca 1 (non in Panico; +1 se Lento), nuovo turno.
func fine_turno() -> void:
	for p in membri:
		var id := str(p["id"])
		while mani[id].size() > 3 + partita.somma_modificatori("limite_mano", p):
			scarti[id].append(mani[id].pop_back())
		if not Personaggi.in_panico(p) or not partita.modificatori("ignora_panico", p).is_empty():
			var n := (2 if ha_tratto("Lento") else 1) + partita.somma_modificatori("pesca_fine_turno", p)
			if pesca(id, n) < n:
				if diplomazia:
					concludi("fallimento")
				else:
					nota("%s non ha più carte: deve Scappare." % p["nome"])
	scatena("fine_turno")
	attivati.clear()
	attivo_id = ""
	turno += 1
	nota("— Turno %d —" % turno)
	cambiato.emit()

## Scappare (chi è attivo): −1 Energia e attacco di opportunità; esce dall'Incontro.
func puo_scappare() -> bool:
	return regole_carta("no_fuga").is_empty()

func scappa() -> void:
	if not puo_scappare():
		nota("In questo Incontro non si può Scappare.")
		return
	var p := attivo()
	if p.is_empty():
		p = membri[0]
		attivo_id = str(p["id"])
	if diplomazia:
		concludi("fallimento")
		return
	partita.modifica(p, "energia", -1)
	if senza_opportunita or not partita.modificatori("senza_opportunita", p).is_empty():
		nota("Nessun attacco di opportunità.")
	else:
		await opportunita()
	nota("%s Scappa." % p["nome"])
	membri.erase(p)
	if membri.is_empty() and concluso == "":
		concludi("fuga")

## Evitare (solo Diplomazia, prima di iniziare).
func evita() -> void:
	var ea = auto.get("evitare")
	if ea is Dictionary:
		var it := Interprete.new(partita, null, ui, {"carta": img})
		if ea.get("condizione") is Dictionary and not ea["condizione"].is_empty() and it.valuta(ea["condizione"]) == false:
			nota("Non potete Evitare questo Incontro.")
			return
		if not await it.esegui(ea.get("costo", [])):
			nota("Non potete pagare il costo per Evitare.")
			return
		concludi("evitato")
		return
	var e = carta.get("evitare")
	if e is Dictionary:
		Effetti.paga_costo("Pagare " + Dati.testo_piano(str(e.get("it", ""))).to_lower().trim_prefix("pagare ").trim_prefix("paga "), partita)
	concludi("evitato")

func concludi(esito: String) -> void:
	if concluso != "":
		return
	concluso = esito
	partita.d.erase("solo_abilita")
	var tutti := partita.compagnia()
	match esito:
		"vittoria":
			nota("VITTORIA!")
			var ric = carta.get("ricompensa") if not nessun_bottino else null
			var ric_t := str(ric.get("it", "")) if ric is Dictionary else ""
			if nessun_bottino:
				pass
			elif auto.get("ricompensa") is Array and (not auto["ricompensa"].is_empty() or ric_t == ""):
				if not auto["ricompensa"].is_empty():
					nota("Ricompensa a ogni membro: " + Dati.testo_piano(ric_t))
					await _esegui_fuori(auto["ricompensa"])
			elif ric_t != "":
				for p in tutti:
					partita.d["attivo"] = partita.personaggi().find(p)
					Effetti.applica(ric_t, partita)
				nota("Ricompensa a ogni membro: " + Dati.testo_piano(ric_t))
			var bot = carta.get("bottino") if not nessun_bottino else null
			var bot_t := str(bot.get("it", "")) if bot is Dictionary else ""
			if nessun_bottino:
				nota("Niente Ricompensa né Bottino per questo Incontro.")
			if nessun_bottino:
				pass
			elif auto.get("bottino") is Array and (not auto["bottino"].is_empty() or bot_t == ""):
				if not auto["bottino"].is_empty():
					nota("Bottino: " + Dati.testo_piano(bot_t))
					await _esegui_fuori(auto["bottino"])
			elif bot_t != "":
				Effetti.applica(bot_t, partita)
				nota("Bottino: " + Dati.testo_piano(bot_t))
			partita.racconta("Incontro vinto: " + Carte.nome(img))
			await scatena("vittoria")
			await scatena("vittoria_diplomazia" if diplomazia else "vittoria_combattimento")
		"fallimento":
			nota("FALLIMENTO.")
			var f = carta.get("fallimento")
			if partita.d.get("ignora_fallimento", false):
				partita.d.erase("ignora_fallimento")
				nota("Il Fallimento della carta non si applica (lo sostituisce il Diario).")
			elif auto.get("fallimento") is Array and not auto["fallimento"].is_empty():
				await _esegui_fuori(auto["fallimento"])
			elif f is Dictionary and str(f.get("it", "")) != "":
				for p in tutti:
					partita.d["attivo"] = partita.personaggi().find(p)
					Effetti.applica(str(f["it"]), partita)
			partita.racconta("Incontro fallito: " + Carte.nome(img))
			await scatena("fallimento")
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
	await scatena("fine_incontro")
	cambiato.emit()
	finito.emit(esito)

## --- Effetti strutturati (data/automazione.json) --------------------------------------

## Esegue passi del linguaggio degli effetti dentro l'Incontro (Capacità, tabelle, Risposte).
func _esegui(passi, contesto := {}) -> void:
	if not (passi is Array) or passi.is_empty():
		return
	var it := Interprete.new(partita, self, ui, contesto)
	await it.esegui(passi)
	for r in it.rapporto:
		if not r.get("fatto", true):
			nota("Da applicare a mano: " + str(r["testo"]))
	_controlla_vita()
	cambiato.emit()

## Esegue passi fuori dalla Sequenza (Ricompensa, Bottino, Fallimento): valgono per la Compagnia.
func _esegui_fuori(passi) -> void:
	var it := Interprete.new(partita, null, ui, {"carta": img})
	await it.esegui(passi)
	for r in it.rapporto:
		nota(("✔ " if r.get("fatto", true) else "☐ ") + str(r["testo"]))

## Capacità di una carta per un innesco ("piazza", "ritardata", "attacco", "passiva").
func esegui_capacita(c: String, innesco: String, contesto := {}) -> void:
	var testo := _capacita(c)
	var ac: Array = Carte.auto(c).get("capacita", []) if Carte.auto(c).get("capacita") is Array else []
	var usa_auto := not ac.is_empty() and ac.size() == testo.size()
	var n := ac.size() if usa_auto else testo.size()
	for i in n:
		var cap: Dictionary = ac[i] if usa_auto else testo[i]
		var inn_cap := str(cap.get("innesco", ""))
		var cond_c = cap.get("condizione")
		if usa_auto and cond_c is Dictionary and str(cond_c.get("tipo", "")) == "manuale":
			var tc := str(cond_c.get("testo", "")).to_lower()
			if tc.find("scartat") >= 0:
				inn_cap = "scartata"
			elif tc.find("delay") >= 0 or tc.find("gettone tempo") >= 0:
				inn_cap = "tempo_rimosso"
		if inn_cap != innesco:
			continue
		if not usa_auto:
			if innesco != "passiva":
				applica_testo(str(cap.get("it", "")))
			continue
		var ctx: Dictionary = contesto.duplicate()
		ctx["carta"] = c
		var it := Interprete.new(partita, self, ui, ctx)
		if cap.get("condizione") is Dictionary and not cap["condizione"].is_empty() and inn_cap == str(cap.get("innesco", "")):
			var v = it.valuta(cap["condizione"])
			if v == null and ui and ui.has_method("scegli"):
				v = await ui.scegli("%s: %s?" % [Carte.nome(c), Interprete.descrivi(cap["condizione"])], ["Sì", "No"]) == 0
			if v != true:
				continue
		if cap.get("facoltativo", false) and ui and ui.has_method("scegli"):
			if await ui.scegli("Usare la Capacità di %s?" % Carte.nome(c), ["Sì", "No"]) != 0:
				continue
		if cap.get("costo") is Array and not cap["costo"].is_empty():
			if not await it.esegui(cap["costo"]):
				continue
		await it.esegui(cap.get("effetti", []))
		for r in it.rapporto:
			if not r.get("fatto", true):
				nota("Da applicare a mano: " + str(r["testo"]))
	_controlla_vita()
	cambiato.emit()

## Inneschi delle carte dei Personaggi (Oggetti, Segreti, Abilità…) per un momento dell'Incontro.
func scatena(quando: String, chi: Dictionary = {}, extra := {}) -> void:
	for i in partita.inneschi(quando, chi):
		var inn: Dictionary = i["innesco"]
		if not i["chi"].is_empty() and not membri.has(i["chi"]):
			continue
		if quando == "collega_chiave" and inn.has("attr") and str(inn["attr"]).trim_suffix("2").replace("magia", "magic") != str(extra.get("attr", "")):
			continue
		if quando.begins_with("inizio_") and inn.get("condizione") is Dictionary and str(inn["condizione"].get("tipo", "")) == "incontro_tipo":
			pass
		var chiave := str(i["img"]) + ":" + str(inn.get("quando"))
		if (inn.get("gira", false) or str(inn.get("una_volta", "")) == "incontro") and usati_inneschi.has(chiave):
			continue
		var ctx: Dictionary = extra.duplicate()
		ctx["carta"] = i["img"]
		ctx["proprietario"] = i["chi"]
		var it := Interprete.new(partita, self, ui, ctx)
		if inn.get("condizione") is Dictionary and not inn["condizione"].is_empty() and it.valuta(inn["condizione"]) != true:
			continue
		if inn.get("facoltativo", false) or (inn.get("costo") is Array and not inn["costo"].is_empty()):
			if not (ui and ui.has_method("scegli")):
				continue
			if await ui.scegli("%s: usare \"%s\"?" % [str(i["chi"].get("nome", "Compagnia")), Carte.nome(i["img"])], ["Sì", "No"]) != 0:
				continue
		if inn.get("costo") is Array and not await it.esegui(inn["costo"]):
			continue
		usati_inneschi[chiave] = true
		nota("%s (%s)." % [Carte.nome(i["img"]), quando.replace("_", " ")])
		await it.esegui(inn.get("effetti", []))
		for r in it.rapporto:
			if not r.get("fatto", true):
				nota("Da applicare a mano: " + str(r["testo"]))
	_controlla_vita()

## Chiavi di un attributo collegate dall'ultima carta della Sequenza.
func chiavi_unite(attr: String) -> int:
	if sequenza.is_empty():
		return 0
	var n := 0
	for a in sequenza.back().get("chiavi", []):
		if str(a) == attr:
			n += 1
	return n

## Si può Evitare? (costo pagabile e condizione soddisfatta)
func evitabile() -> bool:
	var ea = auto.get("evitare")
	if ea is Dictionary:
		var it := Interprete.new(partita, null, null, {"carta": img})
		if ea.get("condizione") is Dictionary and not ea["condizione"].is_empty() and it.valuta(ea["condizione"]) == false:
			return false
		for c in ea.get("costo", []):
			if c is Dictionary and str(c.get("tipo", "")) == "paga" and not partita.puo_pagare(str(c.get("ris", "")), int(c.get("n", 0)), str(c.get("chi", "")) == "compagnia"):
				return false
		return true
	return carta.get("evitare") is Dictionary

## Guardiano non sconfitto: resta sulla mappa nel Luogo.
func guardiano_resta() -> bool:
	return (carta.get("guardiano", false) or ha_tratto("Guardian")) and concluso in ["fuga", "morte"]

## --- Anteprima (per l'interfaccia): cosa succede giocando una carta, senza modificare nulla ---------

const NOMI_BONUS := {"cube": "segnalino", "draw": "pesca carta", "extra": "carta aggiuntiva", "discard": "scarta l'ultima carta",
	"arrowup": "Affinità ↑", "arrowdown": "Affinità ↓", "special": "bonus speciale"}

## Spiegazione dei tratti dei nemici.
const TRATTI := {
	"imbosc": "Imboscata: il primo personaggio che si attiva scarta fino ad avere 1 carta in mano.",
	"improvv": "Improvviso: il primo personaggio che si attiva subisce 2 Ferite inevitabili.",
	"difens": "Difensivo: se la prima carta dell'attivazione dà segnalini, se ne aggiunge uno in meno.",
	"rapid": "Rapido: al massimo 2 carte per attivazione.",
	"finta": "Finta: le Ferite dell'attacco non si possono prevenire.",
	"orda": "Orda: dopo ogni attacco scarti le 2 carte in cima al mazzo.",
	"opportun": "Opportunista: l'attacco di opportunità scatta se giochi meno di 2 carte.",
	"furia": "Furia: il nemico attacca due volte.",
	"lento": "Lento: mano iniziale +1 carta e a fine turno si pescano 2 carte.",
	"guardian": "Guardiano: se non lo sconfiggi resta sulla mappa nel Luogo.",
}

func spiega_tratto(t: String) -> String:
	var l := t.to_lower()
	for k in TRATTI:
		if l.begins_with(k):
			return TRATTI[k]
	return t

## Effetto della carta se giocata ora: {giocabile, motivo, righe:[testo], cubi, pesca, extra, affinita,
## magia, riserva_dopo, affinita_dopo, vittoria, fase_vinta, attacco (testo della riga prevista), ferite}
func anteprima(c: String) -> Dictionary:
	var out := {"giocabile": giocabile(c), "righe": [], "cubi": 0, "pesca": 0, "extra": 0, "affinita": 0, "magia": 0,
		"scarta": 0, "speciali": []}
	if not out["giocabile"]:
		if attivo_id == "":
			out["motivo"] = "Prima scegli chi si attiva."
		elif carte_attivazione > 0 and ha_tratto("Rapid") and carte_attivazione >= 2:
			out["motivo"] = "Rapido: non puoi giocare più di 2 carte."
		elif carte_attivazione > 0:
			out["motivo"] = "Per giocare un'altra carta deve collegare una Chiave dorata (carta aggiuntiva) all'ultima della Sequenza."
		else:
			out["motivo"] = "Non giocabile ora."
	var prima := carte_attivazione == 0
	var magia_disp := _magia_disponibile()
	for k in collegamenti(c):
		var nome_chiave := ""
		match k["tipo"]:
			"fondo":
				nome_chiave = "Chiave in fondo (×%d)" % int(k.get("molt", 1))
			"magia":
				nome_chiave = "riga %d · Chiave Magica" % int(k["riga"])
			_:
				nome_chiave = "riga %d · %s%s" % [int(k["riga"]), Partita.NOMI_ATTRIBUTI.get(k["attr"], k["attr"]), (" %d" % int(k.get("liv", 1))) if int(k.get("liv", 1)) > 1 else ""]
		var ok: bool = k["ok"]
		var nota_ok := ""
		if k["tipo"] == "magia":
			if not paga_magia:
				ok = false
				nota_ok = "pagamento della Magia disattivato"
			elif magia_disp - int(out["magia"]) <= 0:
				ok = false
				nota_ok = "serve 1 Magia"
			else:
				out["magia"] += 1
				nota_ok = "costa 1 Magia"
		elif k["tipo"] == "attributo" and not ok:
			nota_ok = "serve %s %d (hai %d)" % [Partita.NOMI_ATTRIBUTI.get(k["attr"], k["attr"]), int(k.get("liv", 1)), partita.attributo(attivo(), str(k["attr"]))]
		var molt := int(k.get("molt", 1)) if k["tipo"] == "fondo" else 1
		if k["tipo"] == "fondo" and molt == 0:
			ok = false
			nota_ok = "la carta precedente annulla la Chiave in fondo (×0)"
		var effetti := []
		for b in k["bonus"]:
			var m := RegEx.create_from_string("^([a-z]+?)(\\d*)$").search(str(b))
			var nome := m.get_string(1) if m else str(b)
			var n := (int(m.get_string(2)) if m and m.get_string(2) != "" else 1) * molt
			match nome:
				"cube":
					if not diplomazia:
						effetti.append("+%d segnalin%s" % [n, "o" if n == 1 else "i"])
						if ok:
							out["cubi"] += n
				"draw":
					effetti.append("pesca %d" % n)
					if ok:
						out["pesca"] += n
				"extra":
					effetti.append("carta aggiuntiva")
					if ok and not prima:
						out["extra"] += 1
				"discard":
					effetti.append("scarta l'ultima carta della Sequenza")
					if ok:
						out["scarta"] += 1
				"arrowup":
					effetti.append("Affinità +%d" % n)
					if ok and diplomazia:
						out["affinita"] += n
				"arrowdown":
					effetti.append("Affinità −%d" % n)
					if ok and diplomazia:
						out["affinita"] -= n
				"special":
					var sp := _testo_speciale(str(k.get("attr", "")))
					effetti.append("bonus speciale" + ((": " + sp) if sp != "" else ""))
					if ok:
						out["speciali"].append(sp)
				_:
					effetti.append(str(b))
		out["righe"].append({"chiave": nome_chiave, "ok": ok, "effetti": ", ".join(effetti), "nota": nota_ok})
	var cubi_eff: int = out["cubi"]
	if prima and ha_tratto("Difens") and cubi_eff > 0 and not diplomazia:
		cubi_eff -= 1
		out["righe"].append({"chiave": "Difensivo", "ok": true, "effetti": "−1 segnalino", "nota": ""})
	out["riserva_dopo"] = riserva + cubi_eff
	out["affinita_dopo"] = affinita + int(out["affinita"])
	out["vittoria"] = not diplomazia and int(out["riserva_dopo"]) >= valore()
	var a: Dictionary = carta.get("affinita", {})
	out["fase_vinta"] = diplomazia and int(out["affinita_dopo"]) >= int(a.get("verdi", 3))
	out["fallita"] = diplomazia and int(out["affinita_dopo"]) <= -int(a.get("rossi", 3))
	var cap := []
	for x in _capacita(c):
		var tipo: String = {"piazza": "subito", "ritardata": "ritardata (%d turni)" % int(x.get("tempo", 1)), "attacco": "durante l'attacco nemico", "passiva": "sempre"}.get(str(x.get("innesco", "")), "")
		cap.append("%s: %s" % [tipo, str(x.get("it", ""))])
	out["capacita"] = cap
	# Chiavi che la carta lascia aperte per la carta successiva
	var aperte := []
	for k in Carte.dati(c).get("chiavi", []):
		if k.get("apre") != null:
			var liv := int(k.get("liv", k.get("livello", 1)))
			aperte.append("riga %d %s%s" % [int(k.get("riga", 0)), "Magia" if str(k["apre"]) == "magic" else Partita.NOMI_ATTRIBUTI.get(str(k["apre"]), str(k["apre"])), (" %d" % liv) if liv > 1 else ""])
	out["aperte"] = aperte
	out["attacco"] = attacco_previsto(int(out["riserva_dopo"]))
	return out

func _testo_speciale(attr: String) -> String:
	var fs: Array = carta.get("fasi", [])
	if fs.is_empty() or attr == "":
		return ""
	var sp = fs[clampi(fase, 0, fs.size() - 1)].get("speciale", {}).get(attr)
	if sp == null:
		return "nessun effetto per questo attributo"
	return str(sp.get("it", sp)) if sp is Dictionary else str(sp)

## Riga della tabella d'attacco per una certa Riserva: {testo, ferite, da, a}.
func attacco_previsto(ris: int) -> Dictionary:
	if diplomazia:
		var fs: Array = carta.get("fasi", [])
		if fs.is_empty():
			return {}
		var r = fs[clampi(fase, 0, fs.size() - 1)].get("risposta", {})
		return {"testo": str(r.get("it", "")) if r is Dictionary else str(r), "ferite": 0}
	for r in carta.get("tabella", []):
		if ris >= int(r.get("da", 0)) and ris <= int(r.get("a", 99)):
			var fer := 0
			for x in auto.get("tabella", []) if auto.get("tabella") is Array else []:
				if x is Dictionary and int(x.get("da", -1)) == int(r.get("da", -2)):
					for s in x.get("effetti", []):
						if s is Dictionary and str(s.get("tipo", "")) == "ferite":
							fer += int(s.get("n", 0))
			return {"testo": str(r.get("it", "")), "ferite": fer, "da": int(r.get("da", 0)), "a": int(r.get("a", 99))}
	return {}
