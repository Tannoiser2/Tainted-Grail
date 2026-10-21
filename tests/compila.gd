extends SceneTree
## Compila tutti gli script e segnala gli errori: godot --headless --path . -s res://tests/compila.gd
func _initialize() -> void:
	var errori := 0
	for d in ["res://scripts/core", "res://scripts/data", "res://scripts/ui", "res://scripts/tavolo", "res://scripts/net"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("ERRORE: ", d + "/" + f)
					errori += 1
	print("script con errori: ", errori)
	quit(errori)
