## Dati statici del gioco: Diario di Esplorazione e Libro dei Segreti (dall'app ufficiale,
## in italiano), catalogo dei componenti estratti dal modulo Tabletop Simulator, carte trascritte.
## Tutto viene letto dai JSON in res://data, generati dagli script in tools/.
extends Node

const CAMPAGNE := {
	1: {"nome": "La Caduta di Avalon", "file": "res://data/diario/c1.json", "copertina": "res://assets/app/cover_1.webp"},
}

## Icone nel testo: {i:nome} -> res://assets/icone/nome.png
const ICONE_ALIAS := {"woundregular": "wound", "lighttt": "lighttt", "darktt": "darktt", "rep": ""}

var _diario := {}         # id campagna -> dizionario della campagna
var componenti := {}      # catalogo TTS
var carte := {}           # carte trascritte: id -> voce (vedi tools/trascrizione)
var automazione := {}     # effetti strutturati (tools/automazione/DSL.md): {diario, carte}

func _ready() -> void:
	componenti = _leggi("res://data/componenti.json")
	var c = _leggi("res://data/carte.json")
	carte = c if c is Dictionary else {}
	var a = _leggi("res://data/automazione.json")
	automazione = a if a is Dictionary else {}

## Voce automatizzata del Diario per un testo: prefisso "r:" (risultato), "q:" (requisito o costo),
## "c:" (condizione), "s:" (Sogno, Incubo, Menhir). {} se il testo non è stato codificato.
func auto_diario(prefisso: String, testo: String) -> Dictionary:
	if testo == "":
		return {}
	var v = automazione.get("diario", {}).get(prefisso + testo.sha1_text().substr(0, 12))
	return v if v is Dictionary else {}

## Voce automatizzata di un verso (dado da tirare): chiave "v:<id del verso>".
func auto_verso(id_verso: int) -> Dictionary:
	var v = automazione.get("diario", {}).get("v:%d" % id_verso)
	return v if v is Dictionary else {}

func _leggi(p: String):
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("File dati mancante: " + p)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d != null else {}

## Dati del Diario di una campagna (caricati alla prima richiesta).
func diario(camp: int) -> Dictionary:
	if not _diario.has(camp):
		_diario[camp] = _leggi(CAMPAGNE[camp]["file"])
	return _diario[camp]

## Luogo del Diario per id interno.
func luogo(camp: int, id_luogo: int) -> Dictionary:
	return diario(camp).get("luoghi", {}).get(str(id_luogo), {})

## Id interni dei luoghi del Diario con questo numero (di solito uno solo).
func cerca_numero(camp: int, numero: int) -> Array:
	return diario(camp).get("indice", {}).get(str(numero), [])

## Id interno del primo luogo con questo numero (0 se non esiste).
func id_numero(camp: int, numero: int) -> int:
	var a := cerca_numero(camp, numero)
	return int(a[0]) if not a.is_empty() else 0

## Illustrazione del Luogo nell'app ufficiale (web/app/<camp>/<id>_vertical.webp).
func illustrazione(camp: int, id_luogo: int) -> String:
	return "app/%d/%d_vertical.webp" % [camp, id_luogo]

func icona(nome: String) -> String:
	nome = nome.to_lower()
	if ICONE_ALIAS.has(nome):
		nome = ICONE_ALIAS[nome]
	var p := "res://assets/icone/%s.png" % nome
	return p if nome != "" and ResourceLoader.exists(p) else ""

## Converte i segnaposto del Diario in BBCode per RichTextLabel:
##   {i:nome} -> immagine dell'icona, {r:Ricchezza} -> risorsa in grassetto colorato.
func testo_bb(t: String, dim := 24) -> String:
	t = t.replace("💀", "☠")
	if t.find("{") < 0:
		return t
	var rx := RegEx.create_from_string("\\{([ir]):([^}]*)\\}")
	var out := ""
	var k := 0
	for m in rx.search_all(t):
		out += t.substr(k, m.get_start() - k)
		var v := m.get_string(2)
		if m.get_string(1) == "i" and v == "bullet":
			out += "•"
		elif m.get_string(1) == "i":
			var p := icona(v)
			out += ("[img height=%d]%s[/img]" % [dim, p]) if p != "" else "[b]%s[/b]" % v
		else:
			out += "[color=#%s][b]%s[/b][/color]" % [Tema.RISORSA.to_html(false), v]
		k = m.get_end()
	return out + t.substr(k)

## Testo senza segnaposto né BBCode (per cercare parole chiave negli effetti).
func testo_piano(t: String) -> String:
	var rx := RegEx.create_from_string("\\[/?[a-z]+[^\\]]*\\]")
	t = rx.sub(t, "", true)
	t = RegEx.create_from_string("\\{r:([^}]*)\\}").sub(t, "$1", true)
	t = RegEx.create_from_string("\\{i:([^}]*)\\}").sub(t, "@$1@", true)
	return t.replace("[lb]", "[").replace("[rb]", "]")

## --- Componenti TTS ---------------------------------------------------------------

## Cerca un oggetto del catalogo per GUID.
func oggetto(guid: String) -> Dictionary:
	return _per_guid().get(guid, {})

var _guid := {}
func _per_guid() -> Dictionary:
	if _guid.is_empty():
		for o in componenti.get("oggetti", []):
			_indicizza_guid(o)
	return _guid

func _indicizza_guid(o: Dictionary) -> void:
	if o.get("guid", "") != "":
		_guid[o["guid"]] = o
	for k in ["contenuto", "stati"]:
		for x in o.get(k, []):
			_indicizza_guid(x)
