extends SceneTree
## TG_DB_URL=off godot --headless --path . -s res://tests/prova_giornata.gd
func _initialize() -> void:
	root.add_child.call_deferred(load("res://tests/prova_giornata_nodo.gd").new())
