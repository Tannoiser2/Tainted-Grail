#!/usr/bin/env python3
"""Unisce le trascrizioni delle carte (tools/trascrizione/out/*.json) in data/carte.json,
con gli indici che servono al gioco.

Uso: python3 tools/unisci_carte.py

data/carte.json = {
  "carte":   { img: voce trascritta (+ "gruppo") },
  "luoghi":  { "101": img }   (dalle trascrizioni)
  "luoghi_tts": { "101": img } (dai nomi del modulo TTS, per i Luoghi non ancora trascritti)
  "segreti": { "66": img },
  "gruppi":  { "oggetti": [img…], "segreti": […], "abilita": […], "eventi": […],
               "incontri": {colore: {livello: [img…]}}, "combattimento:<guid>": [img…] … }
}
"""
import json, os, re, glob, collections

PRJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cat = json.load(open(os.path.join(PRJ, "data/componenti.json")))
g = {o["guid"]: o for o in cat["oggetti"]}

carte = {}
for f in sorted(glob.glob(os.path.join(PRJ, "tools/trascrizione/out/*.json"))):
    try:
        d = json.load(open(f))
    except Exception as e:
        print("JSON non valido:", f, e)
        continue
    lotto = os.path.basename(f)[:-5]
    for c in d.get("carte", []):
        if not c.get("img"):
            continue
        c["lotto"] = lotto
        carte[c["img"]] = c

# normalizzazione: "courage2" = attributo con requisito di livello 2; "liv"/"livello" unificati
def norm_chiave(k):
    a = k.get("apre")
    if isinstance(a, str):
        m = re.match(r"([a-z]+?)(\d)$", a)
        if m and m.group(1) != "cube":
            k["apre"] = m.group(1)
            k["livello"] = int(m.group(2))
    if "liv" in k:
        k["livello"] = k.pop("liv")
for c in carte.values():
    for k in c.get("chiavi", []) + c.get("chiavi_destra", []):
        norm_chiave(k)

# versione italiana ridisegnata (tools/ridisegna_carte.py) se esiste
for img, c in carte.items():
    p = os.path.join(PRJ, "web/img/it", img)
    if os.path.exists(p):
        c["it_img"] = "it/" + img

luoghi, luoghi_tts, segreti = {}, {}, {}
for c in carte.values():
    if c.get("tipo") == "luogo" and c.get("numero"):
        luoghi[str(int(c["numero"]))] = c["img"]
    if c.get("tipo") == "segreto" and c.get("numero"):
        segreti[str(int(c["numero"]))] = c["img"]
for x in g["f050c2"]["carte"]:
    m = re.match(r"\s*(\d+)", x.get("nome", ""))
    if m:
        luoghi_tts.setdefault(m.group(1), x["fronte"])

def imgs(guid):
    return [x["fronte"] for x in g[guid].get("carte", [])]

gruppi = {
    "oggetti": imgs("7a7d79"),
    "segreti": imgs("b31535"),
    "abilita": imgs("48cf79"),
    "eventi_storia": imgs("023ed6"),
    "eventi_casuali": imgs("ebd4cc"),
    "eventi_speciali": imgs("a85db0"),
    "morente": imgs("e7d993"),
    "follia": imgs("fc19df"),
}
COL = {"VERDES": "verde", "BLANCO": "grigio", "MORADO": "viola", "AZUL": "blu"}
inc = collections.defaultdict(lambda: collections.defaultdict(list))
for o in cat["oggetti"]:
    m = re.match(r"\[(\d)\]\s*-?\s*ENCUENTROS\s+(\w+)", o.get("nome", ""))
    if m and o["tipo"] in ("Deck", "DeckCustom"):
        inc[COL[m.group(2)]][m.group(1)] += imgs(o["guid"])
gruppi["incontri"] = {k: dict(v) for k, v in inc.items()}

out = {"carte": carte, "luoghi": luoghi, "luoghi_tts": luoghi_tts, "segreti": segreti, "gruppi": gruppi}
json.dump(out, open(os.path.join(PRJ, "data/carte.json"), "w"), ensure_ascii=False, separators=(",", ":"))
tipi = collections.Counter(c.get("tipo") for c in carte.values())
print("carte trascritte:", len(carte), dict(tipi), "| Luoghi:", len(luoghi), "| Segreti:", len(segreti))
