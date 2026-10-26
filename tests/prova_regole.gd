extends SceneTree
## Regole particolari di Oggetti/Abilità e regola della Morte (vedi prova_regole_nodo.gd).
## TG_PROVA=1 TG_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/prova_regole.gd
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	root.add_child.call_deferred(load("res://tests/prova_regole_nodo.gd").new())
