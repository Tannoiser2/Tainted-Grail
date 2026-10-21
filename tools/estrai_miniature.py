#!/usr/bin/env python3
"""Estrae le miniature 3D dagli AssetBundle Unity del modulo TTS (UnityPy), le alleggerisce
(fast-simplification) e le salva come .glb con la texture dipinta, pronte per Godot.

Uso: python3 tools/estrai_miniature.py <componenti.json> <cartella_bundle> <cartella_uscita> [triangoli]
"""
import json, os, sys, re, io
import numpy as np
import UnityPy, trimesh, fast_simplification
from PIL import Image

cat = json.load(open(sys.argv[1]))
SRC, OUT = sys.argv[2], sys.argv[3]
TRI = int(sys.argv[4]) if len(sys.argv) > 4 else 9000
os.makedirs(OUT, exist_ok=True)

def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

voci = {}
def visita(o):
    if o.get("bundle") and o.get("nome") and o["tipo"] == "Custom_Assetbundle":
        voci.setdefault(o["bundle"], o["nome"])
    for k in ("contenuto", "stati"):
        for x in o.get(k, []):
            visita(x)
for o in cat["oggetti"]:
    visita(o)

indice = {}
for bundle, nome in sorted(voci.items(), key=lambda kv: kv[1]):
    p = os.path.join(SRC, bundle)
    if not os.path.exists(p):
        print("manca", nome); continue
    env = UnityPy.load(p)
    meshes, tex = [], None
    for ob in env.objects:
        if ob.type.name == "Mesh":
            d = ob.read()
            try:
                txt = d.export()
            except Exception as e:
                print("mesh illeggibile", nome, e); continue
            m = trimesh.load(io.StringIO(txt), file_type="obj", process=False, force="mesh")
            meshes.append(m)
        elif ob.type.name == "Texture2D":
            d = ob.read()
            im = d.image
            if tex is None or im.width * im.height > tex.width * tex.height:
                tex = im
    if not meshes:
        print("nessuna mesh", nome); continue
    m = max(meshes, key=lambda x: len(x.faces))
    uv = m.visual.uv if hasattr(m.visual, "uv") and m.visual.uv is not None else None
    v, f = np.asarray(m.vertices, dtype=np.float32), np.asarray(m.faces)
    n0 = len(f)
    if n0 > TRI:
        # semplifica tenendo le UV: si semplifica e poi si riprendono le UV del vertice originale più vicino
        v2, f2 = fast_simplification.simplify(v, f, target_reduction=1 - TRI / n0)
        if uv is not None:
            from scipy.spatial import cKDTree
            idx = cKDTree(v).query(v2)[1]
            uv = uv[idx]
        v, f = v2, f2
    # nei bundle TTS le miniature hanno assi diversi (spesso "sdraiate"): si cerca la basetta,
    # cioè l'estremità piatta e larga lungo uno dei 6 assi, e la si porta in basso (asse -Y).
    v = v.copy()
    def punteggio(t, a, b):
        r = t.max() - t.min()
        sel = t < t.min() + r * 0.02
        if sel.sum() < 30:
            return 0
        w = v[sel]
        area = (w[:, a].max() - w[:, a].min()) * (w[:, b].max() - w[:, b].min())
        tot = (v[:, a].max() - v[:, a].min()) * (v[:, b].max() - v[:, b].min())
        return area / max(tot, 1e-12) * min(1.0, sel.sum() / 200)
    migliore, scelta = -1, None
    for asse in range(3):
        a, b = [i for i in range(3) if i != asse]
        for segno in (1, -1):
            sc = punteggio(v[:, asse] * segno, a, b)
            if sc > migliore:
                migliore, scelta = sc, (asse, segno)
    asse, segno = scelta
    # rotazione che porta (asse*segno) su +Y verso l'alto: la base (minimo) va in basso
    if asse == 2:
        v = np.stack([v[:, 0], v[:, 2] * segno, -v[:, 1] * segno], axis=1)
    elif asse == 0:
        v = np.stack([-v[:, 1] * segno, v[:, 0] * segno, v[:, 2]], axis=1)
    elif segno == -1:
        v = np.stack([v[:, 0], -v[:, 1], -v[:, 2]], axis=1)
    mn, mx = v.min(0), v.max(0)
    v[:, 0] -= (mn[0] + mx[0]) / 2
    v[:, 2] -= (mn[2] + mx[2]) / 2
    v[:, 1] -= mn[1]
    h = float(mx[1] - mn[1])
    mat = None
    if tex is not None:
        tex = tex.convert("RGB")
        tex.thumbnail((1024, 1024))
        b = io.BytesIO()
        tex.save(b, "JPEG", quality=82)  # nel .glb la texture resta JPEG: file 4-5 volte più piccoli
        tex = Image.open(io.BytesIO(b.getvalue()))
        mat = trimesh.visual.material.PBRMaterial(baseColorTexture=tex, metallicFactor=0.0, roughnessFactor=0.85)
    vis = trimesh.visual.TextureVisuals(uv=uv, material=mat) if uv is not None else None
    out = trimesh.Trimesh(vertices=v, faces=f, visual=vis, process=False)
    fn = slug(nome) + ".glb"
    out.export(os.path.join(OUT, fn))
    indice[nome] = {"file": fn, "altezza": round(h, 4), "triangoli": int(len(f)), "originali": int(n0)}
    print("%-28s %6d -> %5d triangoli  h=%.3f  %4d KB" % (nome, n0, len(f), h, os.path.getsize(os.path.join(OUT, fn)) // 1024))
json.dump(indice, open(os.path.join(OUT, "miniature.json"), "w"), ensure_ascii=False, indent=1)
