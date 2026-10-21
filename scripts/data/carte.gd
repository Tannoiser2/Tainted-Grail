## Accesso alle carte trascritte (data/carte.json, generato da tools/unisci_carte.py a partire dalle
## trascrizioni in tools/trascrizione/out). Ogni carta è identificata dal percorso della sua immagine
## nel modulo TTS (es. "carte/objetos/espada_oxidada_32001.webp"); la versione ridisegnata in
## italiano, se esiste, sta in "it/<stesso percorso>".
class_name Carte
extends RefCounted

## Dati trascritti di una carta (vuoto se non trascritta).
static func dati(img: String) -> Dictionary:
	return Dati.carte.get("carte", {}).get(img, {})

## Immagine da mostrare: quella italiana se disponibile, altrimenti l'originale.
static func immagine(img: String) -> String:
	var d := dati(img)
	if d.get("it_img", "") != "":
		return str(d["it_img"])
	return img

static func nome(img: String) -> String:
	var n = dati(img).get("nome", dati(img).get("titolo", {}))
	if n is Dictionary:
		return str(n.get("it", n.get("es", "")))
	return str(n)

## Carta Luogo per numero.
static func luogo(numero: int) -> Dictionary:
	var img: String = Dati.carte.get("luoghi", {}).get(str(numero), "")
	return dati(img) if img != "" else {}

static func immagine_luogo(numero: int) -> String:
	var img: String = Dati.carte.get("luoghi", {}).get(str(numero), "")
	if img == "":
		img = Dati.carte.get("luoghi_tts", {}).get(str(numero), "")
	return immagine(img) if img != "" else ""

## Segreto per numero.
static func segreto(numero: int) -> String:
	return Dati.carte.get("segreti", {}).get(str(numero), "")

## Elenco delle immagini di un gruppo ("oggetti", "eventi", "incontri_verde_1"…).
static func gruppo(nome_: String) -> Array:
	return Dati.carte.get("gruppi", {}).get(nome_, [])
