## Dati dei quattro Personaggi del gioco base (dalle tessere e dalle plance del modulo TTS)
## e creazione del loro stato iniziale.
##
## Le tre tracce (Energia, Salute, Terrore) stanno sulla plancia in righe affiancate ma sfalsate:
## "riga = valore + scarto". L'Energia non può salire sopra la riga della Salute (marcatore a T)
## e si è in Panico quando il Terrore è su una riga più alta della Salute.
class_name Personaggi
extends RefCounted

const DATI := {
	"arev": {
		"nome": "Arev", "colore": Color("c9c3b8"), "plancia": "oggetti/custom_tile_25da55.webp",
		"tessera": "oggetti/arev_32723e.webp", "miniatura": "Arev",
		"energia": 6, "energia_max": 9, "salute": 8, "terrore_max": 7, "follia": 6, "scarto_s": 1, "scarto_t": 1,
		"attributi": {"aggression": 1, "empathy": 1, "courage": 1, "caution": 1, "practicality": 1, "spirituality": 0},
		"risorse": {"cibo": 2, "ricchezza": 1, "magia": 1},
		"azione": {"nome": "Raccogliere", "costo": 2, "testo": "Ottieni 1 {r:Cibo} (solo fuori dagli Insediamenti).", "fuori_insediamenti": true},
		"tratto": {"nome": "Maledetto", "testo": "Attivare i Menhir ti costa 1 {r:Magia} in più."},
		"storia": "Un semplice contadino con un passato non così semplice. Anni fa, da giovane mercenario, aiutò a saccheggiare e radere al suolo molti villaggi e santuari. Ora lo perseguita una misteriosa maledizione.",
		"mazzi": {"combattimento": ["3b3541", "f92f49", "0c2a0d"], "diplomazia": ["7ae812", "cd3375", "b10a1d"]},
	},
	"ailei": {
		"nome": "Ailei", "colore": Color("7fb069"), "plancia": "oggetti/custom_tile_caa770.webp",
		"tessera": "oggetti/ailei_63d71a.webp", "miniatura": "Ailei",
		"energia": 7, "energia_max": 8, "salute": 7, "terrore_max": 6, "follia": 5, "scarto_s": 1, "scarto_t": 1,
		"attributi": {"aggression": 0, "empathy": 2, "courage": 1, "caution": 1, "practicality": 1, "spirituality": 0},
		"risorse": {"cibo": 3, "rep": 1},
		"azione": {"nome": "Erbe Curative", "costo": 2, "testo": "Ripristina 1 {i:health} a te o a un altro Personaggio nel tuo Luogo (solo fuori dagli Insediamenti).", "fuori_insediamenti": true},
		"tratto": {"nome": "Traumatizzata", "testo": "Non puoi perdere {i:terror} quando Riposi in un Luogo senza un Menhir attivo."},
		"storia": "",
		"mazzi": {"combattimento": ["ace6eb", "f7e098", "36e6a4"], "diplomazia": ["562d7a", "f39a47", "4cc599"]},
	},
	"beor": {
		"nome": "Beor", "colore": Color("6f9fd8"), "plancia": "oggetti/custom_tile_f018e4.webp",
		"tessera": "oggetti/beor_9b0598.webp", "miniatura": "Beor",
		"energia": 6, "energia_max": 9, "salute": 9, "terrore_max": 6, "follia": 5, "scarto_s": 0, "scarto_t": 1,
		"attributi": {"aggression": 2, "empathy": 0, "courage": 1, "caution": 1, "practicality": 1, "spirituality": 0},
		"risorse": {"cibo": 3, "ricchezza": 1},
		"azione": {"nome": "Fabbricare", "costo": 4, "testo": "Pesca 3 Oggetti Fabbricabili a caso e scegline 1 (solo negli Insediamenti).", "solo_insediamenti": true},
		"tratto": {"nome": "Ferita Infetta", "testo": "Perdi 1 {i:health} ogni volta che diventi Esausto."},
		"storia": "",
		"mazzi": {"combattimento": ["cd0854", "d5aa7b", "6413f1"], "diplomazia": ["47e961", "c7fbd2", "ed43ce"]},
	},
	"maggot": {
		"nome": "Verme", "colore": Color("b5653f"), "plancia": "oggetti/custom_tile_9bea36.webp",
		"tessera": "oggetti/maggot_ca49d6.webp", "miniatura": "Maggot",
		"energia": 6, "energia_max": 8, "salute": 8, "terrore_max": 6, "follia": 5, "scarto_s": 0, "scarto_t": 0,
		"attributi": {"aggression": 1, "empathy": 0, "courage": 1, "caution": 1, "practicality": 0, "spirituality": 2},
		"risorse": {"cibo": 2, "magia": 2},
		"azione": {"nome": "Meditazione", "costo": 2, "testo": "Ottieni 1 {r:Magia} (solo se hai meno di 4 {r:Magia}).", "magia_max": 3},
		"tratto": {"nome": "In Disintossicazione", "testo": "Quando Sogni, lancia un Quadrante. Teschio: invece di Sognare, leggi l'Incubo (se disponibile)."},
		"storia": "",
		"mazzi": {"combattimento": ["96def0", "440bf4", "85f922"], "diplomazia": ["a1c5e0", "063e55", "f3c6f5"]},
	},
}

const ORDINE := ["beor", "ailei", "arev", "maggot"]

static func dati(id: String) -> Dictionary:
	return DATI.get(id, {})

## Stato iniziale di un personaggio.
static func nuovo(id: String) -> Dictionary:
	var x: Dictionary = DATI[id]
	var p := {
		"id": id, "nome": x["nome"], "luogo": 101,
		"salute": x["salute"], "energia": x["energia"], "terrore": 0,
		"cibo": 0, "ricchezza": 0, "magia": 0, "esp": 0, "rep": 0,
		"attributi": x["attributi"].duplicate(),
		"abilita": [],
		"oggetti": [], "segreti": [],
		"mazzi": {},
		"passato": false,
	}
	for k in x["risorse"]:
		p[k] = int(x["risorse"][k])
	for tipo in ["combattimento", "diplomazia"]:
		var g: Array = x["mazzi"][tipo]
		var base := _carte_mazzo(g[0])
		var riserva := _carte_mazzo(g[1]) + _carte_mazzo(g[2])
		riserva.shuffle()
		base.shuffle()
		p["mazzi"][tipo] = {"mazzo": base, "collezione": [], "riserva": riserva}
	return p

## Immagini (identificativi) delle carte di un mazzo del catalogo TTS.
static func _carte_mazzo(guid: String) -> Array:
	var out := []
	for c in Dati.oggetto(guid).get("carte", []):
		out.append(str(c.get("fronte", "")))
	return out

## Limite di una risorsa per la plancia del personaggio.
static func limite(p: Dictionary, ris: String) -> int:
	var x: Dictionary = DATI.get(str(p.get("id", "")), {})
	match ris:
		"salute":
			return int(x.get("salute", 8))
		"energia":
			# l'Energia non supera la riga della Salute (marcatore a T)
			return mini(int(x.get("energia_max", 8)), int(p.get("salute", 0)) + int(x.get("scarto_s", 0)))
		"terrore":
			return int(x.get("terrore_max", 6))
	return 999

static func esausto(p: Dictionary) -> bool:
	return int(p.get("energia", 0)) <= 1

static func in_follia(p: Dictionary) -> bool:
	return int(p.get("terrore", 0)) >= int(DATI.get(str(p.get("id", "")), {}).get("follia", 5))

static func in_panico(p: Dictionary) -> bool:
	var x: Dictionary = DATI.get(str(p.get("id", "")), {})
	return int(p.get("terrore", 0)) + int(x.get("scarto_t", 0)) > int(p.get("salute", 0)) + int(x.get("scarto_s", 0))

static func morente(p: Dictionary) -> bool:
	return int(p.get("salute", 0)) <= 0

## Energia recuperata a fine giornata: torna al valore iniziale, ma solo +4 se Esausto.
static func energia_recuperata(p: Dictionary) -> int:
	var x: Dictionary = DATI.get(str(p.get("id", "")), {})
	var e := int(p.get("energia", 0))
	var obiettivo := int(x.get("energia", 6))
	if esausto(p):
		obiettivo = mini(obiettivo, e + 4)
	return maxi(e, mini(obiettivo, limite(p, "energia")))
