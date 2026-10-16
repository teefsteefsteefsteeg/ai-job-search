class_name World
extends Node3D
## The 64x64 tile map: ground texture, water, scenery, buildings and crops.

enum { GRASS, WATER, SAND, TILLED, PATH }
const W := Db.W
const H := Db.H
const BLOCK := {"tree": true, "rock": true, "bush": true, "shrub": true, "stump": true, "house": true, "shop": true,
	"bin": true, "well": true, "stable": true, "decor": true, "campfire": true}
const INSTANCED := {"tree": true, "rock": true, "bush": true, "shrub": true, "grass": true, "stump": true, "log": true, "pebble": true}
const TREES := ["CommonTree", "BirchTree", "PineTree"]

var ttype := PackedByteArray()
var wet := PackedByteArray()
var objs: Array = []
var crops: Array = []
var all_objs: Array = []
var season := 0
var seed := 1

var img: Image
var tex: ImageTexture
var dirty := false
var ground: MeshInstance3D
var outer: MeshInstance3D
var outer_mat: StandardMaterial3D
var water_mi: MeshInstance3D
var statics: Node3D

func _ready() -> void:
	Models.pool_parent = self
	img = Image.create(W * Db.PX, H * Db.PX, false, Image.FORMAT_RGB8)
	tex = ImageTexture.create_from_image(img)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(W, H); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_texture = tex; gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; gm.roughness = 1.0
	ground.material_override = gm; ground.position = Vector3(W * 0.5, 0, H * 0.5); add_child(ground)
	outer = MeshInstance3D.new()
	var om := PlaneMesh.new(); om.size = Vector2(500, 500); outer.mesh = om
	outer_mat = StandardMaterial3D.new(); outer_mat.roughness = 1.0; outer.material_override = outer_mat
	outer.position = Vector3(W * 0.5, -0.03, H * 0.5); add_child(outer)
	statics = Node3D.new(); add_child(statics)

func idx(i: int, j: int) -> int: return j * W + i
func inb(i: int, j: int) -> bool: return i >= 0 and j >= 0 and i < W and j < H
func obj_at(i: int, j: int): return objs[idx(i, j)] if inb(i, j) else null
func crop_at(i: int, j: int): return crops[idx(i, j)] if inb(i, j) else null

static func hash2(i: int, j: int) -> float:
	var h: int = (i * 374761393 + j * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return float((h ^ (h >> 16)) & 0xffffff) / 16777216.0

func vnoise(x: float, z: float, s: int) -> float:
	var xi := floori(x); var zi := floori(z); var xf := x - xi; var zf := z - zi
	var u := xf * xf * (3.0 - 2.0 * xf); var v := zf * zf * (3.0 - 2.0 * zf)
	var a := hash2(xi + s * 31, zi - s * 17); var b := hash2(xi + 1 + s * 31, zi - s * 17)
	var c := hash2(xi + s * 31, zi + 1 - s * 17); var d := hash2(xi + 1 + s * 31, zi + 1 - s * 17)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)

# ---------------------------------------------------------------- terrain
func gen_terrain(s: int) -> void:
	seed = s
	ttype.resize(W * H); wet.resize(W * H)
	objs.resize(W * H); crops.resize(W * H)
	for k in W * H:
		ttype[k] = GRASS; wet[k] = 0; objs[k] = null; crops[k] = null
	var ponds := [[46.0, 46.0, 6.0], [15.0, 47.0, 4.0], [50.0, 13.0, 3.2]]
	for j in H:
		for i in W:
			var t := GRASS
			for p in ponds:
				var d := Vector2(i + 0.5, j + 0.5).distance_to(Vector2(p[0], p[1]))
				var r: float = p[2] + (vnoise(i * 0.3, j * 0.3, s % 997) - 0.5) * 2.4
				if d < r: t = WATER
				elif d < r + 1.3 and t != WATER: t = SAND
			if t == GRASS and j == Db.HZ + 2 and i >= Db.HX - 6 and i <= Db.HX + 5: t = PATH
			if t == GRASS and i == Db.HX and j >= Db.HZ + 2 and j <= Db.HZ + 3: t = PATH
			ttype[idx(i, j)] = t
	build_water()

func build_water() -> void:
	if water_mi: water_mi.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for j in H:
		for i in W:
			if ttype[idx(i, j)] != WATER: continue
			var a := Vector3(i, 0.04, j); var b := Vector3(i + 1, 0.04, j); var c := Vector3(i + 1, 0.04, j + 1); var d := Vector3(i, 0.04, j + 1)
			for v in [a, b, c, a, c, d]:
				st.set_uv(Vector2(v.x, v.z) * 0.25); st.add_vertex(v)
	water_mi = MeshInstance3D.new()
	water_mi.mesh = st.commit()
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.24, 0.55, 0.78, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08; wm.metallic = 0.15
	water_mi.material_override = wm
	water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water_mi)

func paint(i: int, j: int) -> void:
	var t := ttype[idx(i, j)]
	var se: Dictionary = Db.SEASONS[season]
	var h := hash2(i, j)
	var base: Color; var spk: Color
	match t:
		WATER: base = Color("2f6f9a"); spk = Color("3d82ad")
		SAND: base = Color("d6c38c"); spk = Color("c4ad77")
		TILLED:
			if wet[idx(i, j)]: base = Color("4a3222"); spk = Color("3a271a")
			else: base = Color("7a5636"); spk = Color("664629")
		PATH: base = Color("b9a27a"); spk = Color("a48d66")
		_: base = se.grass if h < 0.5 else se.grass2; spk = se.speck
	var x0 := i * Db.PX; var y0 := j * Db.PX
	img.fill_rect(Rect2i(x0, y0, Db.PX, Db.PX), base)
	for k in 3:
		img.set_pixel(x0 + int(hash2(i * 7 + k, j * 13 - k) * Db.PX), y0 + int(hash2(i * 11 - k, j * 5 + k * 3) * Db.PX), spk)
	if t == TILLED:
		var line := Color("2e1f14") if wet[idx(i, j)] else Color("5a3e24")
		img.fill_rect(Rect2i(x0, y0 + 2, Db.PX, 1), line); img.fill_rect(Rect2i(x0, y0 + 5, Db.PX, 1), line)
	dirty = true

func paint_all() -> void:
	for j in H:
		for i in W: paint(i, j)
	outer_mat.albedo_color = (Db.SEASONS[season].grass as Color).darkened(0.12)

func flush() -> void:
	if dirty: tex.update(img); dirty = false

# ---------------------------------------------------------------- objects
func model_for(o: Dictionary) -> Array:
	## returns [path, scale]
	var suf: String = Db.SEASONS[season].suffix
	match o.kind:
		"tree": return ["nature/%s%s_%d" % [TREES[int(o.v) / 3], suf, int(o.v) % 3 + 1], 1.0]
		"rock":
			var rs := "_Snow" if season == 3 else ("_Moss" if int(o.v) >= 3 else "")
			var n := int(o.v) % 3 + 1
			if rs == "_Moss": n = mini(n, 2)
			return ["nature/Rock%s_%d" % [rs, n], 1.1]
		"bush": return ["crops/BushBerries_4" if o.get("berries", false) else "crops/BushBerries_Harvested", 0.75]
		"shrub": return ["nature/Bush%s_%d" % ["_Snow" if season == 3 else "", int(o.v) % 2 + 1], 0.9]
		"grass":
			if season == 3: return ["nature/Grass_Short", 1.0]
			return [["nature/Grass", "nature/Grass_2", "nature/Plant_1", "nature/Flowers"][int(o.v) % 4], 0.9]
		"stump": return ["nature/TreeStump_Snow" if season == 3 else "nature/TreeStump", 0.8]
		"log": return ["nature/WoodLog", 0.55]
		"pebble": return ["nature/Rock_Snow_2" if season == 3 else "nature/Rock_2", 0.45]
	return ["", 1.0]

func place_inst(o: Dictionary) -> void:
	var m := model_for(o)
	var h := hash2(o.i * 3 + 1, o.j * 5 + 2)
	var sc := 1.0
	if o.kind == "tree": sc = 0.7 + h * 0.35
	elif o.kind in ["rock", "shrub", "bush", "grass"]: sc = 0.85 + h * 0.35
	var off := Vector3((h - 0.5) * 0.25, 0, (hash2(o.j, o.i) - 0.5) * 0.25)
	o.base = Transform3D(Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * sc), Vector3(o.i + 0.5, 0, o.j + 0.5) + off)
	o.pool = Models.pool(m[0], m[1], o.kind != "grass")
	o.slot = (o.pool as Models.Pool).add(o.base)

func drop_visual(o: Dictionary) -> void:
	if o.get("pool") != null:
		(o.pool as Models.Pool).remove(o.slot); o.pool = null
	elif o.get("node") != null:
		(o.node as Node).queue_free(); o.node = null

func add_obj(kind: String, i: int, j: int, data := {}):
	if not inb(i, j) or objs[idx(i, j)] != null: return null
	var o := {"kind": kind, "i": i, "j": j, "v": 0, "hp": 0}
	o.merge(data, true)
	if INSTANCED.has(kind): place_inst(o)
	else: o.node = make_node(o)
	objs[idx(i, j)] = o
	all_objs.append(o)
	return o

func add_static(kind: String, i: int, j: int, w: int, d: int, data := {}) -> Dictionary:
	var o := {"kind": kind, "i": i, "j": j, "static": true}
	o.merge(data, true)
	o.node = make_node(o)
	all_objs.append(o)
	for dj in range(-(d / 2), d - d / 2):
		for di in range(-(w / 2), w - w / 2):
			if inb(i + di, j + dj): objs[idx(i + di, j + dj)] = o
	return o

func remove_obj(o: Dictionary) -> void:
	drop_visual(o)
	if inb(o.i, o.j) and objs[idx(o.i, o.j)] == o: objs[idx(o.i, o.j)] = null
	all_objs.erase(o)

func refresh(o: Dictionary) -> void:
	if not INSTANCED.has(o.kind): return
	drop_visual(o); place_inst(o)

func make_node(o: Dictionary) -> Node3D:
	var n: Node3D
	match o.kind:
		"house": n = Models.spawn_scaled("village/House_1", 2.0)
		"shop":
			n = Models.spawn_scaled("village/MarketStand_1", 1.7)
			var keeper := Models.spawn("chars/OldClassy_Female", 1.65)
			keeper.position = Vector3(0, 0, -0.55); n.add_child(keeper)
			o.anim = Models.AnimCtl.new(keeper); (o.anim as Models.AnimCtl).loop("Idle")
		"bin": n = Models.spawn_scaled("village/Crate", 5.0)
		"well": n = Models.spawn_scaled("village/Well", 1.25)
		"stable": n = Models.spawn_scaled("village/Stable", 1.25)
		"decor": n = Models.spawn_scaled(o.file, o.scale)
		"campfire":
			n = Node3D.new()
			n.add_child(Models.spawn_scaled("village/Bonfire", 2.6))
			var fire := Models.spawn_scaled("village/Bonfire_Lit", 2.6); n.add_child(fire); o.fire_model = fire
			var light := OmniLight3D.new(); light.light_color = Color(1.0, 0.62, 0.3); light.omni_range = 9.0; light.light_energy = 2.2
			light.shadow_enabled = false; light.position = Vector3(0, 1.0, 0); n.add_child(light); o.light = light
			n.add_child(_fire_particles()); o.particles = n.get_child(n.get_child_count() - 1)
		_: n = Node3D.new()
	n.position = Vector3(o.i + 0.5, 0, o.j + 0.5)
	if o.has("rot"): n.rotation.y = o.rot
	statics.add_child(n)
	return n

func _fire_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40; p.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP; pm.spread = 18.0; pm.initial_velocity_min = 0.8; pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0); pm.scale_min = 0.12; pm.scale_max = 0.28
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 0.18
	var grad := Gradient.new(); grad.set_color(0, Color(1.0, 0.85, 0.3, 1.0)); grad.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var gt := GradientTexture1D.new(); gt.gradient = grad; pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new(); quad.size = Vector2(0.5, 0.5)
	var qm := StandardMaterial3D.new(); qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; qm.vertex_color_use_as_albedo = true
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; qm.albedo_texture = _soft_dot()
	quad.material = qm; p.draw_pass_1 = quad
	p.position = Vector3(0, 0.35, 0)
	return p

static var _dot: ImageTexture
static func _soft_dot() -> ImageTexture:
	if _dot: return _dot
	var im := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := clampf(1.0 - Vector2(x, y).distance_to(Vector2(15.5, 15.5)) / 15.5, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, d * d))
	_dot = ImageTexture.create_from_image(im)
	return _dot

func clear_all() -> void:
	for o in all_objs.duplicate(): drop_visual(o)
	all_objs.clear()
	for c in crops:
		if c != null: _drop_crop_visual(c)
	Models.clear_pools()
	for ch in statics.get_children(): ch.queue_free()

func build_statics() -> void:
	add_static("house", Db.HX, Db.HZ, 3, 3)
	add_static("shop", Db.HX - 5, Db.HZ + 1, 1, 1)
	add_static("bin", Db.HX + 3, Db.HZ + 1, 1, 1)
	add_static("well", Db.HX + 3, Db.HZ - 2, 1, 1)
	add_static("stable", Db.HX + 8, Db.HZ, 4, 3, {"rot": PI})
	add_static("decor", Db.HX - 2, Db.HZ - 1, 1, 1, {"file": "village/Hay", "scale": 5.0})
	add_static("decor", Db.HX + 2, Db.HZ - 1, 1, 1, {"file": "village/Barrel", "scale": 4.5})
	add_static("decor", Db.HX + 5, Db.HZ + 3, 1, 1, {"file": "village/Cart", "scale": 1.4, "rot": 0.6})
	for i in range(Db.HX - 9, Db.HX + 12):
		if i == Db.HX or i == Db.HX - 1 or i == Db.HX + 1: continue
		if inb(i, 11) and ttype[idx(i, 11)] == GRASS and objs[idx(i, 11)] == null:
			add_static("decor", i, 11, 1, 1, {"file": "village/Fence", "scale": 1.25})

func gen_objects(s: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = s + 7
	for j in H:
		for i in W:
			var k := idx(i, j)
			if objs[k] != null or ttype[k] == WATER or ttype[k] == PATH: continue
			var edge := mini(mini(i, j), mini(W - 1 - i, H - 1 - j))
			if edge < 2:
				if ttype[k] == GRASS: add_obj("tree", i, j, {"v": 6 + rng.randi() % 3})
				continue
			if Db.in_farm(i, j): continue
			var forest := vnoise(i * 0.12, j * 0.12, s % 991 + 5)
			var rocky := vnoise(i * 0.15, j * 0.15, s % 983 + 11)
			var meadow := vnoise(i * 0.2, j * 0.2, s % 977 + 3)
			var r := rng.randf()
			if ttype[k] == GRASS and r < (0.11 if forest > 0.6 else 0.018):
				add_obj("tree", i, j, {"v": (6 + rng.randi() % 3) if forest > 0.7 else rng.randi() % 9})
			elif r < (0.1 if rocky > 0.62 else 0.012) + 0.03:
				var roll := rng.randf()
				if roll < 0.45: add_obj("rock", i, j, {"v": rng.randi() % 3 + (3 if forest > 0.55 else 0)})
				elif roll < 0.6: add_obj("pebble", i, j)
			elif ttype[k] == GRASS and r < 0.055: add_obj("bush", i, j, {"berries": rng.randf() < 0.7, "regrow": 0})
			elif ttype[k] == GRASS and r < 0.07: add_obj("shrub", i, j, {"v": rng.randi() % 2})
			elif ttype[k] == GRASS and r < 0.08 and forest > 0.5: add_obj("log", i, j)
			elif ttype[k] == GRASS and meadow > 0.56 and r < 0.45: add_obj("grass", i, j, {"v": rng.randi() % 4})
	for p in [[21, 24], [21, 28], [43, 20], [43, 30], [26, 36], [38, 36]]: add_obj("bush", p[0], p[1], {"berries": true})
	for p in [[20, 31], [44, 25], [24, 10]]: add_obj("pebble", p[0], p[1])
	for p in [[19, 22], [45, 33]]: add_obj("log", p[0], p[1])
	for p in [[22, 37], [41, 9], [18, 26]]: add_obj("grass", p[0], p[1], {"v": 1})

func set_season(s: int) -> void:
	if s == season: return
	season = s
	for o in all_objs: refresh(o)
	paint_all()

# ---------------------------------------------------------------- crops
func crop_stage(c: Dictionary) -> int:
	var d: int = Db.CROPS[c.type].days
	if c.days >= d: return 4
	if c.days == 0: return 1
	return 2 if c.days < d / 2.0 else 3

func crop_visual(i: int, j: int) -> void:
	var c: Dictionary = crops[idx(i, j)]
	_drop_crop_visual(c)
	var path := "crops/%s_%d" % [Db.CROPS[c.type].model, crop_stage(c)]
	var xf := Transform3D(Basis(Vector3.UP, hash2(i, j) * TAU), Vector3(i + 0.5, 0, j + 0.5))
	if c.dead:
		var n := Models.spawn_scaled(path, 0.7)
		var dm := StandardMaterial3D.new(); dm.albedo_color = Color("7a5a30"); dm.roughness = 1.0
		for mi in n.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_override = dm
		n.transform = xf; statics.add_child(n); c.node = n
	else:
		c.pool = Models.pool(path, 0.7)
		c.slot = (c.pool as Models.Pool).add(xf)

func _drop_crop_visual(c: Dictionary) -> void:
	if c.get("pool") != null: (c.pool as Models.Pool).remove(c.slot); c.pool = null
	if c.get("node") != null: (c.node as Node).queue_free(); c.node = null

func plant(i: int, j: int, type: String) -> void:
	crops[idx(i, j)] = {"type": type, "days": 0, "dry": 0, "dead": false}
	crop_visual(i, j)

func remove_crop(i: int, j: int) -> void:
	var c = crops[idx(i, j)]
	if c == null: return
	_drop_crop_visual(c)
	crops[idx(i, j)] = null

# ---------------------------------------------------------------- collision
func blocked(x: float, z: float) -> bool:
	var i := floori(x); var j := floori(z)
	if not inb(i, j) or ttype[idx(i, j)] == WATER: return true
	var o = objs[idx(i, j)]
	return o != null and BLOCK.has(o.kind)

func can_stand(x: float, z: float, r := 0.28) -> bool:
	return not blocked(x - r, z - r) and not blocked(x + r, z - r) and not blocked(x - r, z + r) and not blocked(x + r, z + r)
