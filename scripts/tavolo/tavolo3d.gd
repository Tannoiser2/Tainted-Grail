## Tavolo 3D: la mappa dei Luoghi (carte sul tavolo), le miniature dei Personaggi, i Menhir con
## il loro Quadrante e i Guardiani. Telecamera orbitale: trascina col sinistro per spostare,
## col destro per ruotare, rotellina per lo zoom verso il cursore. Clic su un Luogo = segnale.
class_name Tavolo3D
extends Node3D

signal luogo_cliccato(numero: int)
signal luogo_sopra(numero: int)

## dimensioni di una carta Luogo sul tavolo (rapporto 0.66 come le carte vere)
const CARTA := Vector2(2.0, 3.03)
const PASSO := Vector2(2.06, 3.09)
const ALTEZZA_EROE := 0.95

var partita: Partita
var _cam: Camera3D
var _perno := Vector3.ZERO
var _yaw := 0.0
var _pitch := deg_to_rad(58.0)
var _dist := 13.0
var _carte := {}          # numero -> MeshInstance3D
var _mini := {}           # chiave -> Node3D (eroi, menhir, guardiani)

## Miniature TTS dei Guardiani (nomi italiani delle carte -> nomi inglesi dei modelli).
const MINI_GUARDIANI := {"Accolita Arciera": "Bowmaiden", "Beccomartello": "Hammerbeak", "Cavaliere Errante": "Knight Errant",
	"Figlio del Wyrd": "Wyrdchild", "Folla Inferocita": "Angry Mob", "Orso Anomalo": "Wyrdbear", "Rivendicatore": "Reclaimer",
	"Selkie": "Selkie", "Serpe del Sottobosco": "Underbrush Wyrm", "Uomo di Muschio": "Mulch Man", "Predecessore": "Fore-dweller",
	"Massacro": "Unchained Warbeast"}
var _evidenza := {}       # numero -> MeshInstance3D (cornice luminosa)
var _trascina := false
var _ruota := false
var _premuto_at := Vector2.ZERO
var _sopra := 0
var _bersagli: Array = []  # numeri dei Luoghi evidenziati come destinazioni possibili

func _init(partita_: Partita) -> void:
	partita = partita_

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0e0a08")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a7a66")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("1a1410")
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, -35, 0)
	sole.light_color = Color("ffe6c0")
	sole.light_energy = 1.15
	sole.shadow_enabled = true
	sole.directional_shadow_max_distance = 60
	add_child(sole)
	var riempi := OmniLight3D.new()
	riempi.position = Vector3(0, 9, 0)
	riempi.omni_range = 40
	riempi.light_color = Color("c9a46a")
	riempi.light_energy = 0.4
	add_child(riempi)
	# tavolo: legno scuro con vignettatura
	var tav := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	tav.mesh = pm
	var mt := ShaderMaterial.new()
	mt.shader = Shader.new()
	mt.shader.code = """shader_type spatial;
render_mode diffuse_lambert;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
void fragment(){
	vec2 p = UV * 160.0;
	float v = n(vec2(p.x * 0.08, p.y * 1.6)) * 0.6 + n(p * vec2(0.3, 5.0)) * 0.25;
	vec3 c = mix(vec3(0.16,0.10,0.06), vec3(0.27,0.17,0.10), v);
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = c * mix(1.0, 0.35, smoothstep(0.08, 0.5, d));
	ROUGHNESS = 0.8;
}"""
	tav.material_override = mt
	tav.position.y = -0.02
	add_child(tav)
	_cam = Camera3D.new()
	_cam.fov = 45
	_cam.far = 300
	add_child(_cam)
	_aggiorna_camera()
	aggiorna()

## Ricostruisce carte e miniature dallo stato della partita.
func aggiorna() -> void:
	if partita == null:
		return
	var mappa: Dictionary = partita.d.get("mappa", {})
	# carte Luogo
	for k in _carte.keys():
		if not mappa.has(str(k)):
			_carte[k].queue_free()
			_carte.erase(k)
	for k in mappa:
		var n := int(k)
		var info: Dictionary = mappa[k]
		if not _carte.has(n):
			_carte[n] = _crea_carta(n, info)
		_carte[n].position = posizione_cella(Vector2i(int(info["x"]), int(info["y"])))
	# Menhir
	var menhir: Dictionary = partita.d.get("menhir", {})
	var usati := 0
	for k in _mini.keys():
		if str(k).begins_with("menhir:") and not menhir.has(str(k).substr(7)):
			_mini[k].queue_free()
			_mini.erase(k)
	for k in menhir:
		var chiave := "menhir:" + str(k)
		usati += 1
		if not _mini.has(chiave):
			_mini[chiave] = _crea_miniatura("Menhir %d" % ((usati - 1) % 3 + 1), 1.35)
		var pos := _centro_luogo(int(k)) + Vector3(-0.55, 0, -0.85)
		_mini[chiave].position = pos
		_etichetta_quadrante(_mini[chiave], int(menhir[k].get("quadrante", 0)))
	# Guardiani
	var gl := Partita.guardiani(partita)
	var chiavi_g := []
	for i in gl.size():
		var g: Dictionary = gl[i]
		var chiave_g := "guardiano:" + str(g["img"])
		chiavi_g.append(chiave_g)
		if not _mini.has(chiave_g):
			_mini[chiave_g] = _crea_miniatura(MINI_GUARDIANI.get(Carte.nome(str(g["img"])), "Hooded Crow"), ALTEZZA_EROE * 1.25, Color("8a2be2") if str(g.get("colore", "")) == "viola" else (Color("4f8a3a") if str(g.get("colore", "")) == "verde" else Color("8c8c8c")))
		_sposta(_mini[chiave_g], _centro_luogo(int(g["luogo"])) + Vector3(-0.5, 0, 0.45))
	for k in _mini.keys():
		if str(k).begins_with("guardiano:") and not chiavi_g.has(k):
			_mini[k].queue_free()
			_mini.erase(k)
	# Personaggi: disposti in cerchio sul loro Luogo
	var per_luogo := {}
	for p in partita.personaggi():
		per_luogo.get_or_add(int(p["luogo"]), []).append(p)
	for l in per_luogo:
		var gruppo: Array = per_luogo[l]
		for i in gruppo.size():
			var p: Dictionary = gruppo[i]
			var chiave := "eroe:" + str(p["id"])
			if not _mini.has(chiave):
				var dd := Personaggi.dati(str(p["id"]))
				_mini[chiave] = _crea_miniatura(str(dd.get("miniatura", "")), ALTEZZA_EROE, dd.get("colore", Color.WHITE))
			var ang := TAU * float(i) / maxf(1, gruppo.size()) + 0.6
			var off := Vector3(cos(ang), 0, sin(ang)) * (0.0 if gruppo.size() == 1 else 0.42)
			var dest := _centro_luogo(int(l)) + Vector3(0.25, 0, 0.35) + off
			_sposta(_mini[chiave], dest)
	_aggiorna_evidenze()

func posizione_cella(c: Vector2i) -> Vector3:
	return Vector3(c.x * PASSO.x, 0, c.y * PASSO.y)

func _centro_luogo(n: int) -> Vector3:
	var info: Dictionary = partita.d.get("mappa", {}).get(str(n), {})
	if info.is_empty():
		return Vector3.ZERO
	return posizione_cella(Vector2i(int(info["x"]), int(info["y"])))

## Inquadra un Luogo.
func centra(n: int, animato := true) -> void:
	var dest := _centro_luogo(n)
	if animato:
		var tw := create_tween()
		tw.tween_method(func(v): _perno = v; _aggiorna_camera(), _perno, dest, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		_perno = dest
		_aggiorna_camera()

## Evidenzia i Luoghi raggiungibili (es. per il Viaggio); [] per togliere.
func evidenzia(numeri: Array) -> void:
	_bersagli = numeri
	_aggiorna_evidenze()

func _aggiorna_evidenze() -> void:
	for k in _evidenza.keys():
		_evidenza[k].queue_free()
	_evidenza.clear()
	for n in _bersagli:
		if not _carte.has(int(n)):
			continue
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CARTA.x + 0.16, 0.01, CARTA.y + 0.16)
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.95, 0.75, 0.3, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.position = _centro_luogo(int(n)) + Vector3(0, 0.005, 0)
		add_child(m)
		var tw := m.create_tween().set_loops()
		tw.tween_property(mat, "albedo_color:a", 0.2, 0.7)
		tw.tween_property(mat, "albedo_color:a", 0.6, 0.7)
		_evidenza[int(n)] = m

func _crea_carta(n: int, info: Dictionary) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CARTA.x, 0.02, CARTA.y)
	m.mesh = bm
	var bordo := StandardMaterial3D.new()
	bordo.albedo_color = Color("2a2018")
	m.material_override = bordo
	# faccia superiore: un quad con la texture della carta
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = CARTA
	f.mesh = q
	f.rotation_degrees = Vector3(-90, 0, 0)
	f.position.y = 0.011
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.22, 0.2)
	mat.roughness = 0.75
	f.material_override = mat
	m.add_child(f)
	var img := Carte.immagine_luogo(n)
	if img != "":
		Immagini.carica(img, func(t):
			if is_instance_valid(f) and t:
				mat.albedo_color = Color.WHITE
				mat.albedo_texture = t)
	# area per il clic
	var area := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(CARTA.x, 0.05, CARTA.y)
	cs.shape = sh
	area.add_child(cs)
	area.set_meta("luogo", n)
	m.add_child(area)
	add_child(m)
	return m

## Miniatura dal modulo TTS, scalata all'altezza voluta, con basetta colorata.
func _crea_miniatura(nome: String, altezza: float, colore := Color(0.3, 0.25, 0.2)) -> Node3D:
	var radice := Node3D.new()
	add_child(radice)
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.26
	cil.bottom_radius = 0.28
	cil.height = 0.06
	base.mesh = cil
	var bm := StandardMaterial3D.new()
	bm.albedo_color = colore.darkened(0.35)
	bm.metallic = 0.3
	bm.roughness = 0.5
	base.material_override = bm
	base.position.y = 0.03
	radice.add_child(base)
	Modelli.istanza(nome, func(n: Node3D):
		if n == null or not is_instance_valid(radice):
			return
		var h := Modelli.altezza(nome)
		var s := altezza / maxf(h, 0.0001)
		n.scale = Vector3.ONE * s
		n.position.y = 0.06
		n.rotation_degrees.y = 180
		radice.add_child(n))
	return radice

func _etichetta_quadrante(mini: Node3D, valore: int) -> void:
	var l: Label3D = mini.get_node_or_null("Quadrante")
	if l == null:
		l = Label3D.new()
		l.name = "Quadrante"
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font = Tema.titolo_forte
		l.font_size = 96
		l.pixel_size = 0.004
		l.outline_size = 18
		l.outline_modulate = Color(0, 0, 0, 0.9)
		l.position = Vector3(0, 1.75, 0)
		l.no_depth_test = true
		mini.add_child(l)
	l.text = str(valore) if valore > 0 else "spento"
	l.modulate = Tema.ORO if valore > 2 else Tema.ROSSO

func _sposta(n: Node3D, dest: Vector3) -> void:
	if n.position.distance_to(dest) < 0.01:
		return
	if n.position == Vector3.ZERO:
		n.position = dest
		return
	var tw := create_tween()
	var mid := (n.position + dest) / 2 + Vector3(0, 0.8, 0)
	tw.tween_property(n, "position", mid, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position", dest, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## --- Telecamera e input ----------------------------------------------------------

func _aggiorna_camera() -> void:
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.position = _perno + dir * _dist
	_cam.look_at(_perno, Vector3.UP)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var f := 0.88 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88
				var verso = _punto_tavolo(mb.position)
				var nuova := clampf(_dist * f, 4.0, 60.0)
				if verso != null and f < 1.0:
					_perno = _perno.lerp(verso, 1.0 - nuova / _dist)
				_dist = nuova
				_aggiorna_camera()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_trascina = true
				_premuto_at = mb.position
			else:
				_trascina = false
				if mb.position.distance_to(_premuto_at) < 6:
					var n := _luogo_sotto(mb.position)
					if n != 0:
						luogo_cliccato.emit(n)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_ruota = mb.pressed
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _ruota:
			_yaw -= mm.relative.x * 0.006
			_pitch = clampf(_pitch + mm.relative.y * 0.005, deg_to_rad(20), deg_to_rad(88))
			_aggiorna_camera()
		elif _trascina:
			var dx := mm.relative * _dist * 0.0016
			var dest := Vector3(-dx.x, 0, -dx.y).rotated(Vector3.UP, _yaw)
			_perno += dest
			_aggiorna_camera()
		else:
			var n := _luogo_sotto(mm.position)
			if n != _sopra:
				_sopra = n
				luogo_sopra.emit(n)

func _punto_tavolo(p: Vector2):
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	return o + d * t if t > 0 else null

func _luogo_sotto(p: Vector2) -> int:
	var o := _cam.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(o, o + _cam.project_ray_normal(p) * 400)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return 0
	var c: Object = r["collider"]
	return int(c.get_meta("luogo", 0)) if c.has_meta("luogo") else 0
