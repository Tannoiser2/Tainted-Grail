#!/usr/bin/env python3
"""Esporta i paragrafi (Diario di Esplorazione e Libro dei Segreti) dal database dell'app
ufficiale Tainted Grail Companion in file JSON leggibili da Godot, uno per campagna.

Uso: python3 tools/esporta_diario.py <appData.sqlite> <cartella_uscita> [id_campagna ...]

Testo italiano (lingua 11); dove manca si usa l'inglese (lingua 1).
Il testo è convertito in BBCode per RichTextLabel di Godot:
  <b>..</b> -> [b]..[/b], <i>..</i> -> [i]..[/i]
  <cb>Ricchezza</cb> -> {r:Ricchezza}        (risorsa, resa in grassetto colorato dal gioco)
  @Terror@ -> {i:terror}                      (icona)
  <link="999@734">..</link> -> [url=999@734]..[/url]   (rimando a un Segreto)

Struttura di ogni elemento di un verso: "t" = tipo
   0 = testo narrativo, 1 = condizione/continuazione automatica, 2 = scelta del giocatore
e "c" = esiti: "l"/"v" = luogo e verso di destinazione (assenti = fine dell'Esplorazione),
"q" = requisito o costo, "r" = risultato da applicare.
"""
import sqlite3, json, re, sys, os, collections

IT, EN = 11, 1
db, out = sys.argv[1], sys.argv[2]
SOLO = {int(x) for x in sys.argv[3:]}
c = sqlite3.connect(db)
q = lambda s, *a: c.execute(s, a).fetchall()

ICONE = {"agrression": "aggression", "incontro": "encounter"}

def bb(t):
    if not t:
        return ""
    t = t.replace("\r", "").replace("\\n", "\n")
    t = t.replace("[", "\x03").replace("]", "\x04")
    t = re.sub(r'<link="([^"]+)">', lambda m: "\x05url=%s\x06" % m.group(1), t)
    t = t.replace("</link>", "\x05/url\x06")
    t = re.sub(r"@(\w+)@", lambda m: "\x01" + ICONE.get(m.group(1).lower(), m.group(1).lower()) + "\x02", t)
    t = re.sub(r"<cb>\s*([^<]*?)\s*</cb>", lambda m: "\x07%s\x08" % m.group(1).strip(" ."), t)
    t = re.sub(r"<c>\s*([^<]*?)\s*</c>", lambda m: "\x07%s\x08" % m.group(1).strip(" ."), t)
    # tag html, con le varianti sporche presenti nel database
    t = re.sub(r"\(?(?<!<)/b>", "</b>", t)
    t = re.sub(r"</\s*[bB]\s*>|<b/>|</b(?=[\s<])", "\x05/b\x06", t)
    t = re.sub(r"<\s*[bB]\s*>|<b(?=[A-Z])|<(?=[A-Z][a-z]+ [^<]*</b)", "\x05b\x06", t)
    t = re.sub(r"</\s*[iI]\s*>|</i(?=[\s<(])", "\x05/i\x06", t)
    t = re.sub(r"<\s*[iI]\s*>|<i(?=[A-Z])", "\x05i\x06", t)
    t = re.sub(r"<\s*(?=\d)", "\x05b\x06", t)  # "< 6</b>", "<5</b>"
    t = re.sub(r"<[^>\x05\x06]{0,3}>", "", t)
    t = t.replace("<<", "<")
    t = t.replace("\x03", "[lb]").replace("\x04", "[rb]")
    t = t.replace("\x05", "[").replace("\x06", "]")
    t = t.replace("\x01", "{i:").replace("\x02", "}")
    t = t.replace("\x07", "{r:").replace("\x08", "}")
    for tag in ("b", "i"):
        o, cl = t.count("[%s]" % tag), t.count("[/%s]" % tag)
        if o > cl:
            t += "[/%s]" % tag * (o - cl)
        elif cl > o:
            for _ in range(cl - o):
                k = t.rfind("[/%s]" % tag)
                t = t[:k] + t[k + len(tag) + 3:]
    return re.sub(r"\n{3,}", "\n\n", t).strip()

def pick(it, en):
    return it if (it is not None and str(it).strip() != "") else (en or "")

stats = collections.Counter()

def txt_elem(eid):
    r = dict(q("select _idLang, text from ElemetText where _idElem=?", eid))
    if (r.get(IT) or "").strip() == "" and (r.get(EN) or "").strip() != "":
        stats["testi_in_inglese"] += 1
    return bb(pick(r.get(IT), r.get(EN)))

def txt_choice(cid):
    r = {l: (a, b) for l, a, b in q("select _idLang, reqTxt, resTxt from ChoiceInfoText where _idChoice=?", cid)}
    it, en = r.get(IT, ("", "")), r.get(EN, ("", ""))
    return bb(pick(it[0], en[0])), bb(pick(it[1], en[1]))

os.makedirs(out, exist_ok=True)
indice = []
for camp, order in q("select _id, menu_order from Campaign order by menu_order, _id"):
    if SOLO and camp not in SOLO:
        continue
    nomi = dict(q("select _idLang, name from CampaignTexts where _idCamp=?", camp))
    data = {"camp": camp, "nome": pick(nomi.get(IT), nomi.get(EN)), "luoghi": {}, "indice": {}, "aiuti": []}
    for hid, in q("select _id from HelpVerse where _campaign=? order by menuOrder, _id", camp):
        ht = {l: (a, b) for l, a, b in q("select _idLang, title, content from HelpVerseText where _idHverse=?", hid)}
        it, en = ht.get(IT, ("", "")), ht.get(EN, ("", ""))
        data["aiuti"].append({"titolo": bb(pick(it[0], en[0])), "testo": bb(pick(it[1], en[1]))})
    for lid, dn in q("select _id, displayNumber from Location where _campId=? order by displayNumber, _id", camp):
        lt = {r[0]: r[1:] for r in q("select _idLang, name, dream, nightmare, menhirCost, danseMacabre from LocationTexts where _idLoc=?", lid)}
        it, en = lt.get(IT, (None,) * 5), lt.get(EN, (None,) * 5)
        luogo = {"n": dn, "nome": bb(pick(it[0], en[0])), "versi": {}, "inizio": None}
        for k, chiave in ((1, "sogno"), (2, "incubo"), (3, "menhir"), (4, "danza")):
            v = bb(pick(it[k], en[k]))
            if v:
                luogo[chiave] = v
        for vid, vdn in q("select _id, displayNumber from Verse where _locationId=? order by displayNumber, _id", lid):
            v = {"d": vdn, "e": []}
            for eid, ety in q("select _id, type from VerseElements where _idVer=? order by _id", vid):
                e = {"t": ety}
                tx = txt_elem(eid)
                if tx:
                    e["x"] = tx
                chs = []
                for cid, tl, tv in q("select _id, _idTargetLoc, _idTargetVer from ChoiceInfo where _elemId=? order by _id", eid):
                    ch = {}
                    if tl: ch["l"] = tl
                    if tv: ch["v"] = tv
                    a, b = txt_choice(cid)
                    if a: ch["q"] = a
                    if b: ch["r"] = b
                    chs.append(ch)
                if chs:
                    e["c"] = chs
                v["e"].append(e)
                stats["elementi"] += 1
            luogo["versi"][str(vid)] = v
            if luogo["inizio"] is None:
                luogo["inizio"] = vid
            stats["versi"] += 1
        data["luoghi"][str(lid)] = luogo
        data["indice"].setdefault(str(dn), []).append(lid)
    p = os.path.join(out, "c%d.json" % camp)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    indice.append({"camp": camp, "nome": data["nome"], "luoghi": len(data["luoghi"])})
    print(p, os.path.getsize(p) // 1024, "KB", len(data["luoghi"]), "luoghi")
print(dict(stats))
