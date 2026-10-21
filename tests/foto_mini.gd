extends SceneTree
## Primo piano di alcune miniature: godot --path . -s res://tests/foto_mini.gd (con xvfb-run)
func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	_run.call_deferred()

func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-45, -30, 0)
	w.add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	w.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 4.5, 6.5)
	w.add_child(cam)
	cam.look_at(Vector3(0, 0.2, -2.2))
	var M = root.get_node("Modelli")
	var nomi: Array = M.indice.keys()
	nomi.sort()
	print(nomi)
	for i in nomi.size():
		var nome: String = nomi[i]
		var fatto := [false]
		M.istanza(nome, func(n):
			if n:
				var s: float = 1.0 / M.altezza(nome)
				n.scale = Vector3.ONE * s
				n.position = Vector3((i % 12 - 5.5) * 0.62, 0, -int(i / 12) * 1.1)
				w.add_child(n)
			fatto[0] = true)
		while not fatto[0]:
			await process_frame
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/foto/mini.png")
	print("ok")
	quit()
