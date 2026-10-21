## Caricatore delle miniature 3D (file .glb in web/modelli, estratti dal modulo TTS con
## tools/estrai_miniature.py). Come le immagini, non stanno nel .pck: si scaricano quando servono
## e si costruiscono a runtime con GLTFDocument.
extends Node

const SITO := "https://tannoiser2.github.io/Tainted-Grail/"

var indice := {}         # nome -> {file, altezza, triangoli}
var _scene := {}         # nome -> Node3D modello (fuori dall'albero), null se mancante
var _attesa := {}        # nome -> Array[Callable]
var _base := ""
var _locale := ""

func _ready() -> void:
	var f := FileAccess.open("res://data/miniature.json", FileAccess.READ)
	if f:
		indice = JSON.parse_string(f.get_as_text())
	if OS.has_feature("web"):
		var href = JavaScriptBridge.eval("location.href.split('?')[0].split('#')[0]")
		_base = str(href).get_base_dir() + "/"
	else:
		var p := ProjectSettings.globalize_path("res://web/modelli")
		if DirAccess.dir_exists_absolute(p):
			_locale = p + "/"
		_base = SITO

func esiste(nome: String) -> bool:
	return indice.has(nome)

## Altezza originale del modello (le miniature dei personaggi sono tutte in scala simile).
func altezza(nome: String) -> float:
	return float(indice.get(nome, {}).get("altezza", 1.0))

## Chiede una miniatura: cb(Node3D) riceve una nuova istanza (null se non disponibile).
func istanza(nome: String, cb: Callable) -> void:
	if _scene.has(nome):
		cb.call(_crea(nome))
		return
	if _attesa.has(nome):
		_attesa[nome].append(cb)
		return
	_attesa[nome] = [cb]
	var file: String = indice.get(nome, {}).get("file", "")
	if file == "":
		_fine(nome, PackedByteArray())
		return
	if _locale != "":
		_fine(nome, FileAccess.get_file_as_bytes(_locale + file))
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request(_base + "modelli/" + file.uri_encode())
	var res: Array = await http.request_completed
	http.queue_free()
	_fine(nome, res[3] if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200 else PackedByteArray())

func _fine(nome: String, dati: PackedByteArray) -> void:
	var ps: Node3D = null
	if dati.size() > 0:
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_buffer(dati, "", st) == OK:
			ps = doc.generate_scene(st) as Node3D
	if ps == null:
		push_warning("Miniatura non disponibile: " + nome)
	_scene[nome] = ps
	var cbs: Array = _attesa.get(nome, [])
	_attesa.erase(nome)
	for cb in cbs:
		if cb.is_valid():
			cb.call(_crea(nome))

func _crea(nome: String) -> Node3D:
	var ps: Node3D = _scene.get(nome)
	return ps.duplicate() as Node3D if ps else null
