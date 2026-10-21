#!/usr/bin/env python3
"""Controlla che ogni tipo di passo, condizione, moltiplicatore, innesco e modificatore usato in
data/automazione.json sia gestito dal motore (scripts/core/interprete.gd, incontro.gd, partita.gd…).
Stampa quelli sconosciuti con il numero di usi."""
import collections
import glob
import json
import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
codice = ""
for f in glob.glob(os.path.join(BASE, "scripts", "**", "*.gd"), recursive=True):
    codice += open(f, encoding="utf-8").read()
# nomi fra virgolette presenti nel codice
noti_tutti = set(re.findall(r'"([a-z_0-9]+)"', codice))
# tipi di passo e di condizione: solo i rami dei match dell'interprete
interp = open(os.path.join(BASE, "scripts", "core", "interprete.gd"), encoding="utf-8").read()
rami = set()
for riga in interp.splitlines():
    m = re.match(r'^\t+((?:"[a-z_0-9]+",?\s*)+):$', riga)
    if m:
        rami.update(re.findall(r'"([a-z_0-9]+)"', m.group(1)))

a = json.load(open(os.path.join(BASE, "data", "automazione.json"), encoding="utf-8"))
mancano = collections.defaultdict(collections.Counter)


def visita(x, cond=False):
    if isinstance(x, dict):
        t = x.get("tipo")
        if isinstance(t, str) and t not in rami:
            mancano["condizione" if cond else "passo"][t] += 1
        if t == "modificatore" and x.get("cosa") not in noti_tutti:
            mancano["modificatore"][str(x.get("cosa"))] += 1
        q = x.get("quando")
        for qq in (q if isinstance(q, list) else [q]):
            if isinstance(qq, str) and qq not in noti_tutti:
                mancano["quando"][qq] += 1
        if isinstance(x.get("innesco"), str) and x["innesco"] not in noti_tutti:
            mancano["innesco"][x["innesco"]] += 1
        if isinstance(x.get("per"), dict):
            for k in x["per"]:
                if k not in noti_tutti:
                    mancano["per"][k] += 1
        for k, v in x.items():
            visita(v, cond or k in ("condizione", "successo", "tutte", "una", "non"))
    elif isinstance(x, list):
        for v in x:
            visita(v, cond)


visita(a)
for k, c in mancano.items():
    print(k, sum(c.values()), dict(c.most_common()))
