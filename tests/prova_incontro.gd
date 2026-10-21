extends SceneTree
## Simula alcuni Incontri giocando sempre la prima carta giocabile (vedi prova_incontro_nodo.gd).
## TG_DB_URL=off godot --headless --path . -s res://tests/prova_incontro.gd
func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/prova_incontro_nodo.gd").new())
