#!/usr/bin/env python3
"""Ridisegna in italiano le carte trascritte: cancella i testi spagnoli nelle aree indicate dalla
trascrizione (filtro mediano + sfocatura, che toglie i tratti sottili delle lettere lasciando lo sfondo
dipinto) e vi scrive il testo italiano con Alegreya/Cinzel e le icone del gioco.

Uso: python3 tools/ridisegna_carte.py [filtro_sul_percorso] [--prova cartella]
Scrive web/img/it/<percorso originale> (poi rilanciare tools/unisci_carte.py).
"""
import json, os, re, sys, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageStat

PRJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(PRJ, "assets/font")
ICONE = os.path.join(PRJ, "assets/icone")
ALIAS_ICONE = {"cube1": "cube", "inevitable": "woundinevitable", "dream": "dolmen", "magic": "wyrdness",
               "key_connected": "key", "settlement_friend": "settlement", "journal": "questtoken"}

_font_cache = {}
def font(stile, dim):
    k = (stile, dim)
    if k not in _font_cache:
        f = {"r": "Alegreya-Regular.ttf", "b": "Alegreya-Bold.ttf", "i": "Alegreya-Italic.ttf",
             "bi": "Alegreya-BoldItalic.ttf", "t": "Alegreya-Bold.ttf"}[stile]
        if stile == "t":
            # Cinzel per i titoli (woff2 non è leggibile da PIL: si usa Alegreya maiuscoletto se manca)
            p = os.path.join(PRJ, "tools/font/Cinzel-Bold.ttf")
            f = p if os.path.exists(p) else os.path.join(FONT, f)
        else:
            f = os.path.join(FONT, f)
        _font_cache[k] = ImageFont.truetype(f, dim)
    return _font_cache[k]

_icone = {}
def icona(nome, h):
    nome = ALIAS_ICONE.get(nome, nome)
    p = os.path.join(ICONE, nome + ".png")
    m = re.match(r"([a-z]+?)(\d)$", nome)
    if not os.path.exists(p) and m and os.path.exists(os.path.join(ICONE, m.group(1) + ".png")):
        # "courage2" = due icone affiancate
        uno = icona(m.group(1), h)
        n = int(m.group(2))
        im = Image.new("RGBA", (uno.width * n + 2 * (n - 1), h), (0, 0, 0, 0))
        for k in range(n):
            im.paste(uno, (k * (uno.width + 2), 0), uno)
        return im
    if not os.path.exists(p):
        return None
    k = (nome, h)
    if k not in _icone:
        im = Image.open(p).convert("RGBA")
        _icone[k] = im.resize((max(1, round(im.width * h / im.height)), h), Image.LANCZOS)
    return _icone[k]

def tokens(testo):
    """Testo con [b] [i] {i:x} {r:X} \\n -> lista di (tipo, valore, stile)."""
    out = []
    b = i = False
    for parte in re.split(r"(\[/?[bi]\]|\{[ir]:[^}]*\}|\n)", testo or ""):
        if not parte:
            continue
        if parte in ("[b]", "[/b]"):
            b = parte == "[b]"; continue
        if parte in ("[i]", "[/i]"):
            i = parte == "[i]"; continue
        st = ("b" if b else "") + ("i" if i else "") or "r"
        if parte == "\n":
            out.append(("a_capo", None, st)); continue
        m = re.match(r"\{([ir]):([^}]*)\}", parte)
        if m:
            if m.group(1) == "i" and m.group(2) == "bullet":
                out.append(("parola", "•", st))
            elif m.group(1) == "i":
                out.append(("icona", m.group(2), st))
            else:
                out.append(("parola", m.group(2), "b", "risorsa"))
            continue
        parte = parte.replace("[lb]", "[").replace("[rb]", "]")
        for w in re.split(r"(\s+)", parte):
            if w and not w.isspace():
                out.append(("parola", w, st))
            elif w:
                out.append(("spazio", " ", st))
    return out

def impagina(tok, larghezza, dim, titolo=False):
    """Restituisce righe di elementi (larghezza, disegno) e altezza totale."""
    righe, riga, x = [], [], 0
    lh = round(dim * 1.18)
    def misura(t):
        if t[0] == "icona":
            ic = icona(t[1], round(dim * 1.05))
            return (ic.width + 2) if ic else font("b", dim).getlength("[" + t[1] + "]")
        st = "t" if titolo else t[2]
        return font(st, dim).getlength(t[1])
    for t in tok:
        if t[0] == "a_capo":
            righe.append(riga); riga, x = [], 0; continue
        w = misura(t)
        if t[0] == "spazio":
            if riga:
                riga.append((t, w)); x += w
            continue
        if x + w > larghezza and riga:
            while riga and riga[-1][0][0] == "spazio":
                x -= riga[-1][1]; riga.pop()
            righe.append(riga); riga, x = [], 0
        riga.append((t, w)); x += w
    if riga:
        righe.append(riga)
    return righe, lh * len(righe), lh

def cancella(im, box):
    """Toglie il testo dall'area lasciando lo sfondo dipinto."""
    reg = im.crop(box)
    k = max(3, (min(reg.size) // 6) | 1)
    k = min(k, 31)
    pul = reg.filter(ImageFilter.MedianFilter(min(k, 15)))
    pul = pul.filter(ImageFilter.MedianFilter(min(k, 15)))
    pul = pul.filter(ImageFilter.GaussianBlur(4))
    # bordi morbidi
    mask = Image.new("L", reg.size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((2, 2, reg.width - 3, reg.height - 3), radius=6, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2))
    im.paste(pul, box[:2], mask)
    return reg

def colori(reg):
    """Colore del testo e dell'ombra: chiaro su fondo scuro o viceversa."""
    l = ImageStat.Stat(reg.convert("L")).median[0]
    if l < 120:
        return (240, 230, 208), (0, 0, 0, 170)
    return (40, 28, 18), None

def scrivi(im, box, testo, titolo=False, centrato=True, dim_max=None):
    x0, y0, x1, y1 = box
    W, H = x1 - x0, y1 - y0
    reg = cancella(im, box)
    col, ombra = colori(reg)
    tok = tokens(testo)
    if titolo:
        tok = [(t[0], t[1].upper() if t[0] == "parola" else t[1], "t") for t in tok]
    # si parte grande (al massimo come il testo originale, ~2.6% dell'altezza della carta) e si riduce finché sta
    dim = dim_max or max(10, min(int(H * (0.5 if titolo else 0.8)), int(im.height * (0.045 if titolo else 0.03))))
    while dim > 9:
        righe, alt, lh = impagina(tok, W - 6, dim, titolo)
        if alt <= H - 2 and (not titolo or len(righe) <= 2):
            break
        dim -= 1
    d = ImageDraw.Draw(im)
    y = y0 + (H - alt) / 2
    for riga in righe:
        lw = sum(w for _, w in riga)
        x = x0 + ((W - lw) / 2 if centrato else 3)
        for t, w in riga:
            if t[0] == "icona":
                ic = icona(t[1], round(dim * 1.05))
                if ic:
                    im.paste(ic, (round(x + 1), round(y + (lh - ic.height) / 2 + dim * 0.05)), ic)
                else:
                    d.text((x, y), "[" + t[1] + "]", font=font("b", dim), fill=col)
            elif t[0] == "parola":
                st = "t" if titolo else t[2]
                c = (229, 154, 74) if len(t) > 3 and t[3] == "risorsa" else col
                if ombra:
                    d.text((x + 1, y + 1), t[1], font=font(st, dim), fill=ombra[:3])
                d.text((x, y), t[1], font=font(st, dim), fill=c)
            x += w
        y += lh

def px(area, w, h, margine=0.01):
    x0, y0, x1, y1 = area
    return (max(0, round((x0 - margine) * w)), max(0, round((y0 - margine) * h)),
            min(w, round((x1 + margine) * w)), min(h, round((y1 + margine) * h)))

def it(v):
    return (v or {}).get("it", "") if isinstance(v, dict) else (v or "")

def testi_carta(c, faccia=None):
    """Elenco (area, testo italiano, è_titolo, centrato) secondo il tipo di carta."""
    t = c.get("tipo")
    a = c.get("aree", {})
    src = faccia or c
    out = []
    def lista(v):
        if not v:
            return []
        return [v] if isinstance(v[0], (int, float)) else v
    # titolo
    if a.get("titolo"):
        nome = it(src.get("nome")) or it(src.get("titolo"))
        if t == "dorso":
            nome = it(c.get("nome")) or "Riserva Avanzata"
        if nome:
            out.append((a["titolo"], nome, True, True))
    # testi principali
    corpo = []
    if t in ("combattimento", "diplomazia"):
        cap = c.get("capacita")
        corpo = [it(x) for x in cap] if isinstance(cap, list) else [it(cap)]
    elif t in ("oggetto", "segreto", "abilita"):
        corpo = [it(src.get("effetto"))]
    elif t == "incontro":
        corpo = [it(c.get("testo"))]
    elif t in ("evento", "speciale"):
        corpo = [it(c.get("testo"))]
    boxes = lista(a.get("testo"))
    if len(corpo) > len(boxes) and boxes:
        corpo = ["\n".join(x for x in corpo if x)]
    for box, txt in zip(boxes, corpo):
        if txt:
            out.append((box, txt, False, True))
    # campi delle carte Incontro
    if t == "incontro":
        if a.get("tratti") and c.get("tratti"):
            out.append((a["tratti"], "[b]" + ", ".join(c["tratti"]) + "[/b]", False, False))
        if a.get("tabella"):
            righe = []
            if c.get("fasi"):
                for f in c["fasi"]:
                    sp = f.get("speciale") or {}
                    bon = " ".join("{i:%s} %s" % (k, it(v) if isinstance(v, dict) else v) for k, v in sp.items() if k != "*")
                    righe.append("[b]%s[/b]  %s  {i:skull} %s" % (it(f.get("nome")), bon, it(f.get("risposta"))))
            else:
                for r in c.get("tabella", []):
                    et = r.get("etichetta") or (str(r.get("da")) if r.get("da") == r.get("a") else ("%s+" % r.get("da") if r.get("a", 0) >= 99 else "%s-%s" % (r.get("da"), r.get("a"))))
                    righe.append("[b]%s[/b} » %s".replace("[/b}", "[/b]") % (et, it(r)))
            out.append((a["tabella"], "\n".join(righe), False, False))
        for k, pre in (("opportunita", "Opportunità"), ("bottino", "Bottino"), ("ricompensa", "Ricompensa"), ("evitare", "Evitare"), ("effetto", ""), ("regola_speciale", ""), ("regola", "")):
            if a.get(k) and c.get(k if k != "regola" else "regola_speciale"):
                v = it(c.get(k if k != "regola" else "regola_speciale"))
                if k == "ricompensa" and c.get("fallimento") and not a.get("fallimento"):
                    v = v + "\n[b]Fallimento:[/b] " + it(c.get("fallimento"))
                out.append((a[k], ("[b]%s:[/b] " % pre if pre else "") + v, False, True))
    if t == "luogo":
        az = c.get("azione")
        if isinstance(az, list):
            az = az[0] if az else None
        if a.get("azione") and az:
            ar = list(a["azione"])
            ar[0], ar[2] = min(ar[0], 0.08), max(ar[2], 0.92)
            out.append((ar, "[b]%s:[/b] %s" % (it(az.get("nome")), it(az)), False, True))
        imm = c.get("immediata")
        if a.get("immediata") and imm:
            out.append((a["immediata"], it(imm), False, True))
        if a.get("ambientazione") and c.get("ambientazione"):
            out.append((a["ambientazione"], "[i]" + it(c.get("ambientazione")) + "[/i]", False, True))
    if t == "evento":
        for k in ("cerca", "indizio"):
            if a.get(k) and c.get(k):
                out.append((a[k], it(c.get(k)), False, True))
    if t in ("oggetto", "segreto") and a.get("parola") and c.get("parola"):
        out.append((a["parola"], c["parola"], True, True))
    return out

def ridisegna(c, dest, faccia=None, img=None):
    src = os.path.join(PRJ, "web/img", img or c["img"])
    im = Image.open(src).convert("RGB")
    w, h = im.size
    a = c.get("aree", {})
    for area, testo, titolo, centrato in testi_carta(c, faccia):
        if not testo or not area or not isinstance(area[0], (int, float)):
            continue
        scrivi(im, px(area, w, h), testo, titolo=titolo, centrato=centrato)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest, "WEBP", quality=82, method=4)

if __name__ == "__main__":
    filtro = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else ""
    prova = sys.argv[sys.argv.index("--prova") + 1] if "--prova" in sys.argv else None
    n = 0
    RETRI = {}
    for f in glob.glob(os.path.join(PRJ, "tools/trascrizione/lotti/*.json")):
        for x in json.load(open(f))["carte"]:
            if x.get("retro"):
                RETRI[x["img"]] = x["retro"]
    for f in sorted(glob.glob(os.path.join(PRJ, "tools/trascrizione/out/*.json"))):
        for c in json.load(open(f)).get("carte", []):
            if filtro and filtro not in c["img"] and filtro not in os.path.basename(f):
                continue
            if not c.get("aree"):
                continue
            dest = os.path.join(prova, os.path.basename(c["img"])) if prova else os.path.join(PRJ, "web/img/it", c["img"])
            try:
                if c.get("tipo") == "abilita" and c.get("facce"):
                    ridisegna(c, dest, c["facce"][0])
                    r = RETRI.get(c["img"])
                    if r and len(c["facce"]) > 1:
                        d2 = os.path.join(prova, os.path.basename(r)) if prova else os.path.join(PRJ, "web/img/it", r)
                        ridisegna(c, d2, c["facce"][1], r)
                else:
                    ridisegna(c, dest)
                n += 1
            except Exception as e:
                print("errore", c["img"], e)
    print("carte ridisegnate:", n)
