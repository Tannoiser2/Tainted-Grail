extends SceneTree
## Esegue tutte le voci di data/automazione.json (vedi prova_automazione_nodo.gd).
## TG_DB_URL=off godot --headless --path . -s res://tests/prova_automazione.gd
func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/prova_automazione_nodo.gd").new())
