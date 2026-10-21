#!/usr/bin/env python3
"""Unisce le codifiche nel linguaggio degli effetti (tools/automazione/out/*.json) in
data/automazione.json, letto dal gioco (Dati.automazione).

  diario: { "<chiave>": {effetti|condizione|costo|menhir} }   chiave = prefisso + sha1(testo)[:12]
          (r: risultato, q: requisito/costo, c: condizione, s: sogno/incubo/menhir, v:<id verso> = dado)
  carte:  { "<img>": {…, "gruppo": "oggetti_segreti"|"abilita"|"luoghi"|"eventi"|"combattimento"|…} }

Stampa anche la copertura: voci presenti rispetto ai lotti e numero di passi "manuale".
"""
import glob
import json
import os
import re
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "tools", "automazione", "out")
LOTTI = os.path.join(BASE, "tools", "automazione", "lotti")


def conta_manuali(x):
    n = 0
    if isinstance(x, dict):
        if x.get("tipo") == "manuale":
            n += 1
        if x.get("tipo") == "modificatore" and x.get("cosa") == "altro":
            n += 1
        for v in x.values():
            n += conta_manuali(v)
    elif isinstance(x, list):
        for v in x:
            n += conta_manuali(v)
    return n


def main():
    diario, carte = {}, {}
    attese_d, attese_c = set(), {}
    copie = {}  # copia -> originale
    for f in sorted(glob.glob(os.path.join(LOTTI, "*.json"))):
        nome = os.path.basename(f)[:-5]
        gruppo = re.sub(r"_\d+$", "", nome)
        d = json.load(open(f, encoding="utf-8"))
        if gruppo == "diario":
            attese_d.update(v["chiave"] for v in d["voci"])
        else:
            for c in d["carte"]:
                attese_c[c["img"]] = gruppo
                for k in c.get("copie_img", []) or []:
                    attese_c[k] = gruppo
                    copie[k] = c["img"]
    manuali = {}
    for f in sorted(glob.glob(os.path.join(OUT, "*.json"))):
        nome = os.path.basename(f)[:-5]
        gruppo = re.sub(r"_\d+$", "", nome)
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception as e:  # file in scrittura o rotto
            print("SALTATO", nome, e, file=sys.stderr)
            continue
        if gruppo == "diario":
            for k, v in d.get("voci", {}).items():
                diario[k] = v
            manuali[gruppo] = manuali.get(gruppo, 0) + conta_manuali(d.get("voci", {}))
        else:
            for k, v in d.get("carte", {}).items():
                if not isinstance(v, dict):
                    continue
                v = dict(v)
                v["gruppo"] = gruppo
                carte[k] = v
            manuali[gruppo] = manuali.get(gruppo, 0) + conta_manuali(d.get("carte", {}))
    for k, o in copie.items():
        if k not in carte and o in carte:
            carte[k] = carte[o]
    os.makedirs(os.path.join(BASE, "data"), exist_ok=True)
    json.dump({"diario": diario, "carte": carte}, open(os.path.join(BASE, "data", "automazione.json"), "w", encoding="utf-8"),
              ensure_ascii=False, separators=(",", ":"))
    md = attese_d - set(diario)
    mc = set(attese_c) - set(carte)
    print("Diario: %d/%d voci codificate (%d mancanti)" % (len(attese_d & set(diario)), len(attese_d), len(md)))
    print("Carte: %d/%d codificate (%d mancanti)" % (len(set(attese_c) & set(carte)), len(attese_c), len(mc)))
    per = {}
    for k in mc:
        per[attese_c[k]] = per.get(attese_c[k], 0) + 1
    if per:
        print("  mancanti per gruppo:", per)
    print("Passi manuali per gruppo:", manuali)


if __name__ == "__main__":
    main()
