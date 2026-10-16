extends Node3D
## Nông Trại Hoang Dã: farm by day, survive the night, lasso and tame animals that work the farm or can be ridden.

enum Mode { INTRO, PLAY, MODAL, TAMING, DEAD }
const SAVE_PATH := "user://nongtrai_save.json"
const W := Db.W
const H := Db.H
const HOLD_ROT := Vector3(0, 0, -90)

var world: World
var ui: GameUI
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var rain_fx: GPUParticles3D
var animals_root: Node3D
var highlight: MeshInstance3D
var rope_mesh: MeshInstance3D

var item_names := Db.item_names()
var sell_prices := Db.sell_prices()
var food_vals := Db.food_values()
var food_list := Db.foods()

# ---------------- state (saved)
var mode := Mode.INTRO
var seed := 0
var day := 1
var hour := 6.0
var gold := 150
var pending := 0
var hp := 100.0
var hunger := 100.0
var sanity := 100.0
var water := 20
var sel := 0
var seed_sel := "carrot"
var food_sel := "berry"
var tools := {"axe": false, "pickaxe": false}
var inv := {}
var trough := 0
var rain := false
var torch_time := 0.0
var uid := 1

# ---------------- player
var player: Node3D
var p_anim: Models.AnimCtl
var ppos := Vector3(Db.HX + 0.5, 0, Db.HZ + 3.5)
var pyaw := 0.0
var moving := false
var running := false
var hand_items := {}
var torch_light: OmniLight3D
var riding = null

# ---------------- animals: Dictionary per animal (see make_animal)
var animals: Array = []
var follower = null
var tame = null

# ---------------- camera / timers
var cam_yaw := 0.0
var cam_dist := 13.0
var clock_t := 0.0
var dark_timer := 0.0
var dark_hit := 0.0
var autosave := 0.0
var spawn_t := 0.0
var last_warn := 0.0
var starve_t := 0.0
var rmb := false
var occlude_t := 0.0
var occluded := {}

func _ready() -> void:
	randomize()
	_setup_input()
	world = World.new(); add_child(world)
	animals_root = Node3D.new(); add_child(animals_root)
	_setup_env()
	_setup_player()
	cam = Camera3D.new(); cam.fov = 50.0; cam.far = 250.0; add_child(cam); cam.current = true
	highlight = MeshInstance3D.new()
	var hm := BoxMesh.new(); hm.size = Vector3(1.0, 0.04, 1.0); highlight.mesh = hm
	var hmat := StandardMaterial3D.new(); hmat.albedo_color = Color(1, 0.95, 0.75, 0.35); hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; highlight.material_override = hmat; add_child(highlight)
	rope_mesh = MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.025; cm.bottom_radius = 0.025; cm.height = 1.0; rope_mesh.mesh = cm
	var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color("b8925a"); rope_mesh.material_override = rmat; rope_mesh.visible = false; add_child(rope_mesh)
	ui = GameUI.new(); ui.game = self; add_child(ui)
	if not load_game():
		new_game()
	else:
		mode = Mode.PLAY
		ui.msg("Chào mừng trở lại! Ngày %d, mùa %s." % [day, Db.SEASONS[season()].name], "good")

func _setup_input() -> void:
	var keys := {
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"act": [KEY_SPACE, KEY_ENTER], "ride": [KEY_F], "cycle": [KEY_R], "bag": [KEY_C, KEY_TAB], "herd": [KEY_H],
		"menu": [KEY_ESCAPE], "cam_l": [KEY_Q], "cam_r": [KEY_E], "run": [KEY_SHIFT],
	}
	for a in keys:
		if not InputMap.has_action(a): InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new(); ev.physical_keycode = k; InputMap.action_add_event(a, ev)

func season() -> int: return int((day - 1) / 7) % 4
func is_night() -> bool: return hour >= 18.0 or hour < 6.0
func day_factor() -> float:
	if hour >= 6.5 and hour < 17.5: return 1.0
	if hour >= 5.0 and hour < 6.5: return (hour - 5.0) / 1.5
	if hour >= 17.5 and hour < 19.5: return 1.0 - (hour - 17.5) / 2.0
	return 0.0

# ================================================================= environment
func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new(); sky.sky_material = sky_mat; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.glow_enabled = true; env.glow_intensity = 0.7; env.glow_bloom = 0.08; env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true; env.ssao_radius = 1.2; env.ssao_intensity = 1.6
	env.fog_enabled = true; env.fog_density = 0.006; env.fog_sky_affect = 0.25
	env.adjustment_enabled = true; env.adjustment_saturation = 1.05; env.adjustment_contrast = 1.08
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.directional_shadow_max_distance = 60.0
	sun.light_angular_distance = 1.0; add_child(sun)
	rain_fx = GPUParticles3D.new(); rain_fx.amount = 1600; rain_fx.lifetime = 1.2; rain_fx.visibility_aabb = AABB(Vector3(-25, -20, -25), Vector3(50, 40, 50))
	var pm := ParticleProcessMaterial.new(); pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX; pm.emission_box_extents = Vector3(18, 0.5, 18)
	pm.direction = Vector3.DOWN; pm.spread = 3.0; pm.initial_velocity_min = 14.0; pm.initial_velocity_max = 18.0; pm.gravity = Vector3(0, -6, 0)
	rain_fx.process_material = pm
	var drop := QuadMesh.new(); drop.size = Vector2(0.03, 0.5)
	var dm := StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dm.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; drop.material = dm
	rain_fx.draw_pass_1 = drop; rain_fx.emitting = false; add_child(rain_fx)

func update_sky() -> void:
	var df := day_factor()
	var se: Dictionary = Db.SEASONS[season()]
	var night_top := Color(0.03, 0.05, 0.13); var night_hor := Color(0.08, 0.1, 0.2)
	var dusk := Color(0.95, 0.55, 0.35)
	var top: Color = (se.sky as Color).darkened(0.25); var hor: Color = se.sky
	var t_top: Color; var t_hor: Color
	if df < 0.5:
		t_top = night_top.lerp(top.darkened(0.4), df * 2.0); t_hor = night_hor.lerp(dusk, df * 2.0)
	else:
		t_top = top.darkened(0.4).lerp(top, (df - 0.5) * 2.0); t_hor = dusk.lerp(hor, (df - 0.5) * 2.0)
	if rain:
		t_top = t_top.lerp(Color(0.4, 0.44, 0.5) * maxf(df, 0.15), 0.6); t_hor = t_hor.lerp(Color(0.55, 0.58, 0.62) * maxf(df, 0.15), 0.6)
	sky_mat.sky_top_color = t_top; sky_mat.sky_horizon_color = t_hor
	sky_mat.ground_horizon_color = t_hor.darkened(0.2); sky_mat.ground_bottom_color = t_top.darkened(0.5)
	sky_mat.sun_angle_max = 30.0
	env.fog_light_color = t_hor
	env.fog_density = (0.012 if rain else 0.006) + (0.01 if df < 0.2 else 0.0)
	var a := (hour - 6.0) / 12.0 * PI
	if df > 0.0:
		sun.rotation = Vector3(-maxf(0.25, sin(a)) * 1.25, -cos(a) * 1.2 + 0.6, 0)
		sun.light_energy = (0.2 + df * 0.85) * (0.6 if rain else 1.0)
		sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.96, 0.88), clampf((df - 0.3) / 0.7, 0, 1))
	else:
		sun.rotation = Vector3(-1.0, 0.8, 0)
		sun.light_energy = 0.18
		sun.light_color = Color(0.55, 0.65, 1.0)
	env.ambient_light_energy = 0.22 + df * 0.5
	env.background_energy_multiplier = 0.35 + df * 0.65
	rain_fx.emitting = rain
	rain_fx.global_position = ppos + Vector3(0, 14, 0)
	var rmat := (rain_fx.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	if season() == 3:
		(rain_fx.process_material as ParticleProcessMaterial).initial_velocity_min = 1.5
		(rain_fx.process_material as ParticleProcessMaterial).initial_velocity_max = 2.5
		(rain_fx.draw_pass_1 as QuadMesh).size = Vector2(0.09, 0.09); rmat.albedo_color = Color(1, 1, 1, 0.9)
		rain_fx.lifetime = 7.0
	else:
		(rain_fx.process_material as ParticleProcessMaterial).initial_velocity_min = 14.0
		(rain_fx.process_material as ParticleProcessMaterial).initial_velocity_max = 18.0
		(rain_fx.draw_pass_1 as QuadMesh).size = Vector2(0.03, 0.5); rmat.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
		rain_fx.lifetime = 1.2

# ================================================================= player
func _setup_player() -> void:
	player = Models.spawn("chars/Cowboy_Male", 1.75)
	add_child(player)
	p_anim = Models.AnimCtl.new(player)
	p_anim.loop("Idle")
	var skel: Skeleton3D = null
	for n in player.find_children("*", "Skeleton3D", true, false): skel = n
	if skel:
		var bone := -1
		for b in skel.get_bone_count():
			var bn := skel.get_bone_name(b).to_lower()
			if (bn.contains("fist") or bn.contains("hand") or bn.contains("palm")) and (bn.ends_with(".r") or bn.ends_with("_r") or bn.ends_with("right") or bn.ends_with("r")):
				bone = b; break
		if bone >= 0:
			var att := BoneAttachment3D.new(); att.bone_idx = bone; skel.add_child(att)
			var holder := Node3D.new(); att.add_child(holder)
			# bones of these FBX rigs are in centimetres: cancel the bone scale so items are sized in metres
			var bone_scale := (skel.global_transform.basis * skel.get_bone_global_rest(bone).basis).get_scale().x
			holder.scale = Vector3.ONE / maxf(bone_scale, 0.0001)
			holder.rotation_degrees = HOLD_ROT
			for spec in [["axe", "survival/Axe", 0.3], ["pickaxe", "survival/Axe_Small", 0.32], ["hoe", "survival/Shovel", 0.55], ["torch", "survival/WoodenTorch_Fire", 0.42]]:
				var item := Models.spawn_scaled(spec[1], spec[2]); item.visible = false; holder.add_child(item); hand_items[spec[0]] = item
	torch_light = OmniLight3D.new(); torch_light.light_color = Color(1.0, 0.65, 0.35); torch_light.omni_range = 7.5; torch_light.light_energy = 0.0
	torch_light.position = Vector3(0.3, 1.9, 0.3); player.add_child(torch_light)

func show_tool() -> void:
	var id: String = Db.HOTBAR[sel].id
	for k in hand_items:
		var vis: bool = k == id and riding == null
		if k == "axe" or k == "pickaxe": vis = vis and tools[k]
		if k == "torch": vis = vis and torch_time > 0.0
		(hand_items[k] as Node3D).visible = vis

func torch_on() -> bool: return torch_time > 0.0 and Db.HOTBAR[sel].id == "torch"

func update_player(dt: float) -> void:
	var input := Vector2(Input.get_axis("left", "right"), Input.get_axis("down", "up"))
	if Input.is_action_pressed("cam_l"): cam_yaw += dt * 2.0
	if Input.is_action_pressed("cam_r"): cam_yaw -= dt * 2.0
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)); var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var mv := fwd * input.y + right * input.x
	var amt := minf(1.0, mv.length())
	moving = amt > 0.1 and p_anim.lock <= 0.0
	running = Input.is_action_pressed("run")
	if moving:
		mv = mv.normalized()
		var speed := (6.0 if running else 4.0) * amt
		if riding != null: speed = float(riding.def.ride) * (1.0 if running else 0.6) * amt
		if hunger <= 0.0: speed *= 0.7
		var r := 0.45 if riding != null else 0.28
		var nx := ppos.x + mv.x * speed * dt; var nz := ppos.z + mv.z * speed * dt
		if world.can_stand(nx, ppos.z, r): ppos.x = nx
		if world.can_stand(ppos.x, nz, r): ppos.z = nz
		pyaw = lerp_angle(pyaw, atan2(mv.x, mv.z), minf(1.0, dt * 12.0))
		if running: hunger -= dt * (0.08 if riding != null else 0.25)
	if torch_on():
		torch_time -= dt
		if torch_time <= 0.0: ui.msg("Đuốc đã cháy hết.", "bad")

func place_player() -> void:
	if riding != null:
		var seat: float = float(riding.def.height) * 0.62
		player.position = riding.pos + Vector3(0, seat, 0)
		player.rotation.y = riding.yaw
		riding.node.position = riding.pos; riding.node.rotation.y = riding.yaw
	else:
		player.position = ppos; player.rotation.y = pyaw
		if mode != Mode.DEAD and p_anim.lock <= 0.0:
			if moving: p_anim.loop("Walk", 1.6 if running else 1.1)
			else: p_anim.loop("Idle")
	torch_light.light_energy = (2.0 + sin(clock_t * 17.0) * 0.15) if torch_on() else 0.0

func front_tile() -> Vector2i:
	var f := ppos + Vector3(sin(pyaw), 0, cos(pyaw)) * 0.9
	return Vector2i(floori(f.x), floori(f.z))

# ================================================================= animals
func make_animal(id: String, pos: Vector3, state := "wild") -> Dictionary:
	var def: Dictionary = Db.ANIMALS[id]
	var lvl_scale := 1.0
	var node := Models.spawn(def.model, def.height, def.get("yaw", 0.0))
	animals_root.add_child(node)
	var a := {"id": id, "def": def, "node": node, "anim": Models.AnimCtl.new(node), "pos": pos, "yaw": randf() * TAU, "state": state,
		"trust": 0, "happy": 3, "unfed": 0, "fed": false, "target": pos, "timer": 0.0, "cooldown": 1.5, "hit_cd": 0.0, "calm": 0.0,
		"moving": false, "fast": false, "uid": uid, "hits": 0, "scale": lvl_scale}
	uid += 1
	(a.anim as Models.AnimCtl).loop(def.get("idle", "Idle"))
	node.position = pos
	animals.append(a)
	return a

func remove_animal(a: Dictionary) -> void:
	(a.node as Node).queue_free()
	animals.erase(a)
	if follower == a: follower = null

func tamed_list() -> Array:
	return animals.filter(func(x): return x.state != "wild" and x.state != "tied")

func wild_count() -> int:
	return animals.filter(func(x): return x.state == "wild").size()

func is_lit_at(p: Vector3) -> bool:
	if day_factor() >= 0.2: return true
	if torch_on() and p.distance_to(ppos) < 6.5: return true
	for o in world.all_objs:
		if o.kind == "campfire" and float(o.get("fuel", 0.0)) > 0.0:
			if Vector2(o.i + 0.5, o.j + 0.5).distance_to(Vector2(p.x, p.z)) < float(o.get("radius", 6.0)): return true
	for a in animals:
		if a.id == "rong" and a.state != "wild" and a.pos.distance_to(p) < 7.0: return true
	return false

func habitat_pick(i: int, j: int) -> String:
	var water_n := 0; var rock_n := 0; var tree_n := 0
	for dj in range(-3, 4):
		for di in range(-3, 4):
			if not world.inb(i + di, j + dj): continue
			if world.ttype[world.idx(i + di, j + dj)] == World.WATER: water_n += 1
			var o = world.objs[world.idx(i + di, j + dj)]
			if o != null:
				if o.kind == "rock": rock_n += 1
				elif o.kind == "tree": tree_n += 1
	var far := Vector2(i, j).distance_to(Vector2(Db.HX, Db.HZ)) > 26
	var pool := []
	for id in Db.ANIMALS:
		var d: Dictionary = Db.ANIMALS[id]
		if d.get("hostile", false): continue
		var w: float = d.get("weight", 1.0)
		match d.habitat:
			"water": w *= 3.0 if water_n > 3 else 0.0
			"rocky": w *= 2.5 if rock_n > 2 else 0.3
			"forest": w *= 2.5 if tree_n > 6 else 0.4
			"meadow": w *= 1.5 if tree_n < 5 else 0.6
			"far": w *= 1.0 if far else 0.0
		if d.get("aggressive", false) and not far and id != "soi": w = 0.0
		if w > 0.0: pool.append([id, w])
	var total := 0.0
	for p in pool: total += p[1]
	var r := randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0: return p[0]
	return "cuu"

func try_spawn() -> void:
	var night := day_factor() < 0.2
	var wild := wild_count()
	if wild >= (11 if night else 9): return
	for k in 10:
		var ang := randf() * TAU; var dist := 11.0 + randf() * 14.0
		var p := ppos + Vector3(cos(ang), 0, sin(ang)) * dist
		var i := floori(p.x); var j := floori(p.z)
		if not world.inb(i, j) or not world.can_stand(p.x, p.z, 0.45): continue
		var id: String
		if night and randf() < 0.6: id = "doi" if randf() < 0.5 else "xuong"
		else:
			if Db.in_farm(i, j): continue
			id = habitat_pick(i, j)
		if sanity < 30 and randf() < 0.3: id = "xuong"
		make_animal(id, p)
		return

func update_animals(dt: float) -> void:
	var playing := mode == Mode.PLAY
	var night := day_factor() < 0.2
	for a in animals.duplicate():
		var ctl: Models.AnimCtl = a.anim
		ctl.tick(dt)
		var def: Dictionary = a.def
		if a.state == "ridden":
			_anim_move(a, moving, running)
			continue
		if a.state == "tied":
			a.node.position = a.pos
			var to: Vector3 = ppos - a.pos
			a.yaw = lerp_angle(a.yaw, atan2(-to.x, -to.z), dt * 3.0)
			a.node.rotation.y = a.yaw
			_anim_move(a, true, true)
			continue
		var dp: float = a.pos.distance_to(ppos)
		if a.state == "wild" and (dp > 40.0 or (def.get("night", false) and not night and dp > 10.0)):
			remove_animal(a); continue
		if not playing:
			_anim_move(a, false, false)
			a.node.position = a.pos + Vector3(0, _fly_y(a), 0)
			continue
		a.cooldown -= dt; a.hit_cd -= dt; a.calm -= dt
		var speed := 1.3
		var target: Vector3 = a.target
		var flee := false
		match a.state:
			"wild":
				if def.get("hostile", false):
					var guard := _guard_near(a.pos, 7.0)
					if (is_lit_at(a.pos) and day_factor() < 0.2) or guard or a.calm > 0.0:
						flee = true
					elif dp < 15.0:
						target = ppos; speed = 2.6
				elif def.get("aggressive", false) and a.trust < 2 and a.calm <= 0.0 and ((dp < 6.5 and (night or a.id == "rong")) or dp < 3.0):
					target = ppos; speed = 3.3
				elif def.get("skittish", false) and a.trust < 2 and dp < 4.5:
					flee = true
				if flee:
					target = a.pos + (a.pos - ppos).normalized() * 5.0; speed = 4.0
				if target == a.target:
					a.timer -= dt
					if a.timer <= 0.0:
						a.timer = 2.0 + randf() * 3.0
						a.target = a.pos + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
					target = a.target
				# bites
				if (def.get("hostile", false) or (def.get("aggressive", false) and a.trust < 2 and a.calm <= 0.0)) and not flee and dp < 1.4 and a.hit_cd <= 0.0 and riding == null:
					a.hit_cd = 1.6
					ctl.once(def.get("attack", "Jump"), 1.2)
					hurt(10.0 if def.get("hostile", false) else 13.0, "%s tấn công bạn!" % def.name)
			"follow":
				target = ppos - Vector3(sin(pyaw), 0, cos(pyaw)) * (1.4 + float(def.size) * 0.4)
				if a.pos.distance_to(target) > 14.0: a.pos = target
				speed = 6.5 if a.pos.distance_to(target) > 3.0 else 4.0
				if a.pos.distance_to(target) < 0.5: target = a.pos
			"farm":
				a.timer -= dt
				if a.timer <= 0.0 or a.pos.distance_to(a.target) < 0.3:
					a.timer = 3.0 + randf() * 4.0
					a.target = Vector3(randf_range(24, 41), 0, randf_range(21, 34))
				target = a.target
				if not Db.in_farm(floori(a.pos.x), floori(a.pos.z)):
					speed = 3.5
					if a.pos.distance_to(ppos) > 30.0: a.pos = Vector3(Db.HX + 6.5, 0, Db.HZ + 4.5)
		var dir: Vector3 = target - a.pos; dir.y = 0
		var r := 0.22 + float(def.size) * 0.12
		a.moving = false
		if dir.length() > 0.25:
			dir = dir.normalized()
			var nx: float = a.pos.x + dir.x * speed * dt; var nz: float = a.pos.z + dir.z * speed * dt
			var moved := false
			if def.get("fly", false) or world.can_stand(nx, a.pos.z, r): a.pos.x = nx; moved = true
			if def.get("fly", false) or world.can_stand(a.pos.x, nz, r): a.pos.z = nz; moved = true
			a.pos.x = clampf(a.pos.x, 1.0, W - 1.0); a.pos.z = clampf(a.pos.z, 1.0, H - 1.0)
			if not moved: a.timer = 0.0
			a.moving = moved
			a.yaw = lerp_angle(a.yaw, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))
		a.fast = speed > 2.5
		_anim_move(a, a.moving, a.fast)
		a.node.position = a.pos + Vector3(0, _fly_y(a), 0)
		a.node.rotation.y = a.yaw
		if a.state == "wild" and not def.get("hostile", false) and def.get("aggressive", false) == false and dp < 0.9 and a.cooldown <= 0.0:
			a.cooldown = 1.0
			a.target = a.pos + (a.pos - ppos).normalized() * 3.0

func _fly_y(a: Dictionary) -> float:
	if not a.def.get("fly", false): return 0.0
	return 0.9 + sin(clock_t * 2.5 + float(a.uid)) * 0.15

func _anim_move(a: Dictionary, mv: bool, fast: bool) -> void:
	var ctl: Models.AnimCtl = a.anim
	var def: Dictionary = a.def
	if not mv:
		ctl.loop(def.get("idle", "Idle"))
	elif def.get("hop", false):
		ctl.loop("Jump", 1.5 if fast else 1.0)
	elif fast and def.has("run"):
		ctl.loop(def.run, 1.0)
	else:
		ctl.loop(def.get("walk", "Walk"), 1.6 if fast else 1.0)

func _guard_near(p: Vector3, r: float) -> bool:
	for a in animals:
		if a.state in ["follow", "farm", "ridden"] and a.def.get("job", "") in ["guard", "dragon"] and a.pos.distance_to(p) < r: return true
	return false

func animal_in_front(max_d: float, cone := 0.55, filter := Callable()):
	var best = null; var best_d := max_d
	var f := Vector3(sin(pyaw), 0, cos(pyaw))
	for a in animals:
		if a == riding or a.state == "tied": continue
		var to: Vector3 = a.pos - ppos; to.y = 0
		var d := to.length()
		if d > best_d or d < 0.01: continue
		if f.dot(to / d) < cone and d > 1.2: continue
		if filter.is_valid() and not filter.call(a): continue
		best = a; best_d = d
	return best

# ================================================================= taming (lasso minigame)
func start_tame(a: Dictionary) -> void:
	var item := "rope2" if inv.get("rope2", 0) > 0 else "rope"
	if a.id == "rong" and item != "rope2":
		ui.msg("Rồng quá khỏe! Cần Dây thừng len (len cừu + dây thừng).", "bad"); return
	if inv.get(item, 0) <= 0:
		ui.msg("Bạn không có dây thừng. Chế tạo từ 3 sợi cỏ (phím C).", "bad"); return
	var size: int = a.def.size
	var zone: float = [0.3, 0.24, 0.18, 0.13][size] + float(a.trust) * 0.05
	tame = {"a": a, "marker": 0.0, "dir": 1.0, "zone_c": randf_range(0.3, 0.7), "zone_w": zone, "speed": [0.9, 1.15, 1.4, 1.7][size],
		"prog": 0, "need": [3, 4, 5, 7][size], "str": 5 if item == "rope2" else 3, "item": item, "max_str": 5 if item == "rope2" else 3}
	a.state = "tied"
	mode = Mode.TAMING
	p_anim.once("Shoot_OneHanded", 1.4)
	ui.msg("Quăng dây trúng %s! Bấm Space khi kim nằm trong vùng xanh." % a.def.name, "mon")

func update_taming(dt: float) -> void:
	var t: Dictionary = tame
	var a: Dictionary = t.a
	t.marker += t.dir * t.speed * dt
	if t.marker > 1.0: t.marker = 1.0; t.dir = -1.0
	if t.marker < 0.0: t.marker = 0.0; t.dir = 1.0
	var to: Vector3 = ppos - a.pos
	pyaw = lerp_angle(pyaw, atan2(-to.x, -to.z), dt * 6.0)
	var hand := ppos + Vector3(0, 1.2, 0)
	var neck: Vector3 = a.pos + Vector3(0, float(a.def.height) * 0.75, 0)
	var mid := (hand + neck) * 0.5
	rope_mesh.visible = true
	var dist := hand.distance_to(neck)
	var up := (neck - hand).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	rope_mesh.global_transform = Transform3D(Basis(side, up * dist, side.cross(up)), mid)

func tame_press() -> void:
	var t: Dictionary = tame
	var a: Dictionary = t.a
	if absf(t.marker - t.zone_c) <= t.zone_w * 0.5:
		t.prog += 1
		t.zone_c = randf_range(0.2, 0.8)
		t.speed *= 1.08
		ui.msg("Ghì chặt! (%d/%d)" % [t.prog, t.need], "good")
		if t.prog >= t.need: _tame_success()
	else:
		t.str -= 1
		ppos = ppos.move_toward(a.pos, 0.4)
		(a.anim as Models.AnimCtl).once(a.def.get("attack", "Jump"), 1.3)
		if a.def.get("aggressive", false): hurt(7.0, "%s giằng mạnh và cắn bạn!" % a.def.name)
		else: ui.msg("%s vùng mạnh! Dây còn %d/%d." % [a.def.name, t.str, t.max_str], "bad")
		if t.str <= 0:
			inv[t.item] = inv.get(t.item, 0) - 1
			ui.msg("Dây thừng đứt! %s chạy mất." % a.def.name, "bad")
			_tame_end(false)

func _tame_success() -> void:
	var t: Dictionary = tame
	var a: Dictionary = t.a
	inv[t.item] = inv.get(t.item, 0) - 1
	a.happy = 3; a.unfed = 0; a.fed = true; a.trust = 3
	if follower == null or float(a.def.get("ride", 0.0)) > 0.0:
		if follower != null: follower.state = "farm"
		a.state = "follow"; follower = a
	else:
		a.state = "farm"
	p_anim.once("Victory", 1.0)
	ui.msg("Đã thuần hóa %s! %s" % [a.def.name, "Nó sẽ đi theo bạn." if a.state == "follow" else "Nó tự về nông trại."], "good")
	if a.def.get("ride", 0.0) > 0.0: ui.msg("Đứng cạnh %s và bấm F để cưỡi." % a.def.name, "mon")
	_tame_end(true)

func _tame_end(ok: bool) -> void:
	var a: Dictionary = tame.a
	if not ok:
		a.state = "wild"; a.calm = 6.0; a.trust = maxi(0, a.trust - 1)
		a.target = a.pos + (a.pos - ppos).normalized() * 8.0
	tame = null
	rope_mesh.visible = false
	mode = Mode.PLAY

# ================================================================= riding
func toggle_ride() -> void:
	if riding != null:
		var a: Dictionary = riding
		riding = null
		var side := Vector3(cos(a.yaw), 0, -sin(a.yaw)) * 1.2
		ppos = a.pos + side
		if not world.can_stand(ppos.x, ppos.z): ppos = a.pos - side
		if not world.can_stand(ppos.x, ppos.z): ppos = a.pos
		pyaw = a.yaw
		a.state = "follow"
		if follower != null and follower != a: follower.state = "farm"
		follower = a
		p_anim.release()
		ui.msg("Bạn xuống khỏi %s." % a.def.name)
		show_tool()
		return
	var best = null
	for a in animals:
		if a.state in ["follow", "farm"] and float(a.def.get("ride", 0.0)) > 0.0 and a.pos.distance_to(ppos) < 2.6:
			best = a; break
	if best == null:
		ui.msg("Không có thú cưỡi nào ở gần. Thuần hóa ngựa, lạc đà, sói hay rồng để cưỡi.")
		return
	riding = best
	if follower != null and follower != best: follower.state = "farm"
	follower = null
	best.state = "ridden"
	best.pos = Vector3(ppos.x, 0, ppos.z) if world.can_stand(ppos.x, ppos.z, 0.45) else best.pos
	ppos = best.pos
	p_anim.once("SitDown", 2.0, true)
	ui.msg("Bạn cưỡi %s! Shift để phi nhanh, F để xuống." % best.def.name, "good")
	show_tool()

# ================================================================= actions
func give(item: String, n: int, quiet := false) -> void:
	inv[item] = inv.get(item, 0) + n
	if not quiet: ui.msg("+%d %s" % [n, item_names.get(item, item)], "good")

func get_action():
	var tool: String = Db.HOTBAR[sel].id
	if riding != null: return {"label": "Đang cưỡi %s · F để xuống" % riding.def.name}
	# animals first
	var near = animal_in_front(2.2)
	if near != null and (near.def.get("hostile", false) or (near.def.get("aggressive", false) and near.state == "wild" and near.trust < 2)):
		return {"label": "Đuổi %s" % near.def.name, "fn": shove.bind(near), "an": "Punch"}
	if tool == "food":
		if near != null and not near.def.get("hostile", false):
			var likes: bool = near.def.diet.has(food_sel)
			if inv.get(food_sel, 0) <= 0: return {"label": "Hết %s · R để đổi món" % item_names[food_sel]}
			return {"label": "Cho %s ăn %s%s" % [near.def.name, item_names[food_sel], "" if likes else " (nó không thích)"], "fn": feed_animal.bind(near), "an": "PickUp"}
		if inv.get(food_sel, 0) > 0: return {"label": "Ăn %s" % item_names[food_sel], "fn": eat.bind(food_sel), "an": "PickUp"}
		return {"label": "Hết %s · R để đổi món" % item_names[food_sel]}
	if tool == "rope":
		var target = animal_in_front(7.0, 0.7, func(x): return x.state == "wild" and not x.def.get("hostile", false))
		if target != null:
			var have: int = inv.get("rope", 0) + inv.get("rope2", 0)
			if have <= 0: return {"label": "Hết dây thừng · chế tạo bằng 3 sợi cỏ (C)"}
			return {"label": "Quăng dây vào %s%s" % [target.def.name, " (đã quen bạn)" if target.trust >= 2 else ""], "fn": start_tame.bind(target)}
		return {"label": "Hướng về một con thú hoang trong 7m để quăng dây"}
	var ft := front_tile()
	var ti := ft.x; var tj := ft.y
	if not world.inb(ti, tj): return null
	var o = world.obj_at(ti, tj)
	if o != null:
		match o.kind:
			"house":
				if is_night(): return {"label": "Đi ngủ (lưu game)", "fn": sleep}
				return {"label": "Nhà của bạn · ngủ được sau 18:00"}
			"shop": return {"label": "Cửa hàng của bà Tư", "fn": ui.open_shop}
			"bin": return {"label": "Thùng hàng: bán nông sản", "fn": ui.open_bin}
			"well": return {"label": "Múc nước giếng (%d/20)" % water, "fn": refill_water, "an": "PickUp"}
			"stable": return {"label": "Chuồng thú: máng ăn & đàn thú", "fn": ui.open_herd}
			"campfire":
				if inv.get("wood", 0) > 0: return {"label": "Thêm gỗ vào lửa (%ds)" % int(o.fuel), "fn": add_wood.bind(o), "an": "PickUp"}
				return {"label": "Lửa trại %s · cần gỗ" % ("%ds" % int(o.fuel) if o.fuel > 0 else "đã tắt")}
			"bush":
				if o.get("berries", false): return {"label": "Hái quả mọng", "fn": pick_bush.bind(o), "an": "PickUp"}
				return {"label": "Bụi quả chưa chín lại"}
			"tree", "stump":
				if tool == "axe" and tools.axe: return {"label": "Chặt cây" if o.kind == "tree" else "Đào gốc cây", "fn": chop.bind(o, true), "an": "Punch"}
				if tool == "hand": return {"label": "Bẻ cành bằng tay (chậm)", "fn": chop.bind(o, false), "an": "Punch"}
				return {"label": "Chọn Rìu (phím 4)" if tools.axe else "Chọn Tay để bẻ cành, hoặc chế tạo Rìu"}
			"rock":
				if tool == "pickaxe" and tools.pickaxe: return {"label": "Đập đá", "fn": mine.bind(o), "an": "Punch"}
				return {"label": "Chọn Rìu đá (phím 5)" if tools.pickaxe else "Cần Rìu đá để đập đá"}
			"shrub":
				if tool == "axe" and tools.axe: return {"label": "Phát bụi cây", "fn": take_obj.bind(o, "fiber", 2), "an": "Punch"}
				return {"label": "Bụi cây rậm · dùng Rìu để phát"}
			"pebble": return {"label": "Nhặt đá cuội", "fn": take_obj.bind(o, "stone", 1), "an": "PickUp"}
			"log": return {"label": "Nhặt khúc gỗ", "fn": take_obj.bind(o, "wood", 2), "an": "PickUp"}
			"grass":
				if tool == "hoe": return {"label": "Cuốc đất", "fn": hoe_grass.bind(o, ti, tj), "an": "Punch"}
				return {"label": "Nhổ cỏ (lấy sợi cỏ)", "fn": take_obj.bind(o, "fiber", -1), "an": "PickUp"}
			"decor": return null
	var c = world.crop_at(ti, tj)
	var k := world.idx(ti, tj)
	if c != null:
		var d: int = Db.CROPS[c.type].days
		var cname: String = Db.CROPS[c.type].name
		if c.dead: return {"label": "Dọn cây héo", "fn": world.remove_crop.bind(ti, tj), "an": "PickUp"}
		if c.days >= d: return {"label": "Thu hoạch %s" % cname, "fn": harvest.bind(ti, tj), "an": "PickUp"}
		if tool == "can" and world.wet[k] == 0:
			if water > 0: return {"label": "Tưới nước", "fn": water_tile.bind(ti, tj), "an": "PickUp"}
			return {"label": "Bình hết nước · ra giếng hoặc ao múc"}
		return {"label": "%s: còn %d ngày%s" % [cname, d - c.days, " · đã tưới" if world.wet[k] else " · cần tưới"]}
	var tt := world.ttype[k]
	match tool:
		"hoe":
			if tt == World.GRASS or tt == World.SAND: return {"label": "Cuốc đất", "fn": till.bind(ti, tj), "an": "Punch"}
		"can":
			if tt == World.WATER: return {"label": "Múc nước (%d/20)" % water, "fn": refill_water, "an": "PickUp"}
			if tt == World.TILLED and world.wet[k] == 0:
				if water > 0: return {"label": "Tưới đất", "fn": water_tile.bind(ti, tj), "an": "PickUp"}
				return {"label": "Bình hết nước · ra giếng hoặc ao múc"}
		"seeds":
			if tt == World.TILLED:
				if inv.get("seed_" + seed_sel, 0) > 0: return {"label": "Gieo %s" % Db.CROPS[seed_sel].name, "fn": plant.bind(ti, tj, seed_sel), "an": "PickUp"}
				return {"label": "Hết hạt %s · R đổi loại / mua ở cửa hàng" % Db.CROPS[seed_sel].name}
		"campfire":
			if inv.get("campfire", 0) > 0 and tt in [World.GRASS, World.SAND, World.PATH]:
				return {"label": "Đặt lửa trại", "fn": place_campfire.bind(ti, tj), "an": "PickUp"}
			if inv.get("campfire", 0) <= 0: return {"label": "Chưa có lửa trại · chế tạo (C)"}
		"torch":
			if torch_time > 0.0: return {"label": "Đuốc đang cháy (%ds)" % int(torch_time)}
			if inv.get("torch", 0) > 0: return {"label": "Thắp đuốc", "fn": light_torch, "an": "PickUp"}
			return {"label": "Chưa có đuốc · chế tạo từ gỗ và sợi cỏ (C)"}
		"axe":
			if not tools.axe: return {"label": "Chế tạo Rìu: 2 gỗ + 3 sợi cỏ (C)"}
		"pickaxe":
			if not tools.pickaxe: return {"label": "Chế tạo Rìu đá: 3 gỗ + 2 sợi cỏ (C)"}
	if near != null and near.state != "wild":
		return {"label": "%s · %s" % [near.def.name, Db.JOB_NAMES.get(near.def.get("job", "none"), "")]}
	return null

func do_action() -> void:
	if p_anim.lock > 0.08 and riding == null: return
	var a = get_action()
	if a == null: return
	if a.has("fn"):
		(a.fn as Callable).call()
		if a.has("an") and riding == null: p_anim.once(a.an, 1.5 if a.an == "Punch" else 1.6)
		show_tool()
	else:
		ui.msg(a.label)

func swing(o: Dictionary) -> void:
	if o.get("pool") == null: return
	var pool: Models.Pool = o.pool
	var base: Transform3D = o.base
	var tw := create_tween()
	tw.tween_method(_swing_step.bind(o, pool, base), 0.0, 1.0, 0.35)

func _swing_step(k: float, o: Dictionary, pool: Models.Pool, base: Transform3D) -> void:
	if o.get("pool") == pool: pool.set_xf(o.slot, base * Transform3D(Basis(Vector3.FORWARD, sin(k * PI * 3.0) * 0.08 * (1.0 - k)), Vector3.ZERO))

func refill_water() -> void:
	water = 20; ui.msg("Đã đổ đầy bình tưới.")

func add_wood(o: Dictionary) -> void:
	inv.wood -= 1; o.fuel = minf(200.0, float(o.fuel) + 50.0); ui.msg("Lửa cháy mạnh hơn.")

func take_obj(o: Dictionary, item: String, n: int) -> void:
	world.remove_obj(o)
	give(item, n if n > 0 else 1 + (1 if randf() < 0.4 else 0))

func hoe_grass(o: Dictionary, i: int, j: int) -> void:
	world.remove_obj(o); till(i, j)

func place_campfire(i: int, j: int) -> void:
	inv.campfire -= 1; world.add_obj("campfire", i, j, {"fuel": 120.0}); ui.msg("Lửa trại bùng cháy!", "good")

func light_torch() -> void:
	inv.torch -= 1; torch_time = 90.0; show_tool()

func chop(o: Dictionary, axe: bool) -> void:
	o.hp = int(o.get("hp", 0)) + 1
	swing(o); hunger -= 0.6
	var need := (3 if axe else 6) if o.kind == "tree" else (2 if axe else 4)
	if o.hp >= need:
		var i: int = o.i; var j: int = o.j
		var was_tree: bool = o.kind == "tree"
		world.remove_obj(o)
		give("wood", (3 if axe else 1) if was_tree else 1)
		if was_tree:
			if randf() < 0.35: give("fiber", 1)
			world.add_obj("stump", i, j)

func mine(o: Dictionary) -> void:
	o.hp = int(o.get("hp", 0)) + 1
	swing(o); hunger -= 0.8
	if o.hp >= 4:
		world.remove_obj(o)
		give("stone", 2 + (1 if randf() < 0.4 else 0))

func pick_bush(o: Dictionary) -> void:
	o.berries = false; o.regrow = 2
	world.refresh(o)
	give("berry", 2 + (1 if randf() < 0.5 else 0))

func till(i: int, j: int) -> void:
	var k := world.idx(i, j)
	world.ttype[k] = World.TILLED; world.wet[k] = 1 if rain else 0
	world.paint(i, j); hunger -= 0.3

func water_tile(i: int, j: int) -> void:
	var k := world.idx(i, j)
	if world.wet[k]: return
	world.wet[k] = 1; water -= 1; world.paint(i, j)

func plant(i: int, j: int, type: String) -> void:
	inv["seed_" + type] -= 1
	world.plant(i, j, type)
	if season() == 3: ui.msg("Mùa đông lạnh giá: cây sẽ không lớn tới mùa xuân.", "bad")

func harvest(i: int, j: int) -> void:
	var type: String = world.crop_at(i, j).type
	world.remove_crop(i, j)
	give(type, 1 + (1 if randf() < 0.25 else 0))

func eat(item: String) -> void:
	if inv.get(item, 0) <= 0: return
	inv[item] -= 1
	var v: Dictionary = food_vals[item]
	hunger = clampf(hunger + float(v.get("h", 0)), 0, 100)
	hp = clampf(hp + float(v.get("hp", 0)), 0, 100)
	sanity = clampf(sanity + float(v.get("s", 0)), 0, 100)
	ui.msg("Bạn ăn %s. No bụng +%d" % [item_names[item], int(v.get("h", 0))], "good")

func feed_animal(a: Dictionary) -> void:
	if inv.get(food_sel, 0) <= 0: return
	if not a.def.diet.has(food_sel):
		ui.msg("%s không thích %s. Nó thích: %s." % [a.def.name, item_names[food_sel], diet_names(a.def.diet)], "bad")
		return
	inv[food_sel] -= 1
	(a.anim as Models.AnimCtl).once("Jump" if (a.anim as Models.AnimCtl).has("Jump") else a.def.get("idle", "Idle"), 1.2)
	if a.state == "wild":
		a.trust = mini(3, a.trust + 1); a.calm = 25.0
		ui.msg("%s thích lắm! Độ quen: %d/3. Quăng dây sẽ dễ hơn." % [a.def.name, a.trust], "good")
	else:
		a.fed = true; a.happy = mini(5, a.happy + 1)
		ui.msg("%s đã no bụng hôm nay." % a.def.name, "good")

func shove(a: Dictionary) -> void:
	var push: Vector3 = (a.pos - ppos).normalized() * 2.0
	if world.can_stand(a.pos.x + push.x, a.pos.z + push.z, 0.3) or a.def.get("fly", false): a.pos += push
	a.calm = 5.0
	a.hits += 1
	if a.def.get("hostile", false) and a.hits >= 3:
		ui.msg("%s tan biến vào bóng tối." % a.def.name, "good")
		(a.anim as Models.AnimCtl).once(a.def.get("death", "Death"), 1.0)
		var node: Node3D = a.node
		animals.erase(a)
		get_tree().create_timer(0.8).timeout.connect(func(): node.queue_free())
	else:
		ui.msg("Bạn đuổi %s lùi lại!" % a.def.name)

func hurt(dmg: float, text: String) -> void:
	hp -= dmg; sanity -= dmg * 0.3
	p_anim.once("RecieveHit", 1.6)
	ui.flash_hurt(); ui.msg(text, "bad")

# ================================================================= time & days
func update_time(dt: float) -> void:
	var before := hour
	hour += dt * 24.0 / Db.DAY_SECONDS
	if hour >= 24.0: hour -= 24.0
	if before < 6.0 and hour >= 6.0: new_day()
	if before < 18.0 and hour >= 18.0: ui.msg("Mặt trời lặn. Chuẩn bị lửa trại, đuốc, hoặc về nhà ngủ.", "bad")

func new_day() -> void:
	var night_guard := _guard_near(Vector3(Db.HX + 0.5, 0, Db.HZ + 6), 40.0)
	var fire_in_farm := false
	for o in world.all_objs:
		if o.kind == "campfire" and Db.in_farm(o.i, o.j) and o.fuel > 0: fire_in_farm = true
	day += 1
	var report := {}
	if pending > 0:
		ui.msg("Thùng hàng đã bán được %d G." % pending, "good"); gold += pending; pending = 0
	# shadows take an unguarded small animal
	if not night_guard and not fire_in_farm:
		var smalls := tamed_list().filter(func(x): return x.state == "farm" and int(x.def.size) == 0)
		if not smalls.is_empty() and randf() < 0.25:
			var lost: Dictionary = smalls.pick_random()
			ui.msg("Đêm qua bóng tối đã bắt mất %s! Hãy có thú gác đêm hoặc lửa trại trong nông trại." % lost.def.name, "bad")
			remove_animal(lost)
	# feeding from the trough
	var water_jobs := 0; var fruit := 0
	for a in tamed_list():
		var need := 2 if int(a.def.size) >= 2 else 1
		var ok: bool = a.fed
		if not ok and trough >= need: trough -= need; ok = true
		a.fed = false
		if not ok:
			a.unfed += 1; a.happy = maxi(0, a.happy - 1)
			if a.unfed >= 3:
				ui.msg("%s bỏ đi vì đói 3 ngày liền!" % a.def.name, "bad")
				if riding == a: toggle_ride()
				a.state = "wild"; a.trust = 0
				if follower == a: follower = null
			continue
		a.unfed = 0; a.happy = mini(5, a.happy + 1)
		match a.def.get("job", "none"):
			"milk": _add(report, "milk", 1)
			"wool": _add(report, "wool", 1)
			"truffle":
				if randf() < 0.5: _add(report, "truffle", 1)
			"forage":
				var s: String = Db.CROPS.keys().pick_random(); _add(report, "seed_" + s, 1 + randi() % 2)
			"water": water_jobs += int(a.def.get("amount", 12))
			"fruit": fruit += int(a.def.get("amount", 3))
	if fruit > 0: _add(report, "berry", fruit)
	# crops grow
	var was_rain := rain
	for j in H:
		for i in W:
			var k := world.idx(i, j)
			var c = world.crops[k]
			if c != null and not c.dead:
				var d: int = Db.CROPS[c.type].days
				if world.wet[k] or was_rain:
					c.dry = 0
					if season() != 3 and c.days < d: c.days += 1
				elif c.days < d:
					c.dry += 1
					if c.dry >= 3: c.dead = true; ui.msg("Một cây %s đã héo vì thiếu nước." % Db.CROPS[c.type].name, "bad")
				world.crop_visual(i, j)
			if world.ttype[k] == World.TILLED:
				world.wet[k] = 0
				if c == null and randf() < 0.06: world.ttype[k] = World.GRASS
			var o = world.objs[k]
			if o != null and o.kind == "bush" and not o.get("berries", false):
				o.regrow = int(o.get("regrow", 0)) - 1
				if o.regrow <= 0: o.berries = true; world.refresh(o)
	rain = randf() < (0.15 if season() == 1 else 0.25)
	if rain:
		for k in W * H:
			if world.ttype[k] == World.TILLED: world.wet[k] = 1
	elif water_jobs > 0:
		var n := 0
		for k in W * H:
			if n >= water_jobs: break
			if world.ttype[k] == World.TILLED and world.wet[k] == 0 and world.crops[k] != null: world.wet[k] = 1; n += 1
		if n > 0: ui.msg("Slime đã tưới %d ô đất." % n, "good")
	# regrowth
	var counts := {"tree": 0, "rock": 0, "grass": 0, "pebble": 0, "log": 0}
	for o in world.all_objs:
		if counts.has(o.kind): counts[o.kind] += 1
	_sprout("tree", 6 if counts.tree < 260 else 0, func(): return {"v": randi() % 9})
	_sprout("rock", 3 if counts.rock < 70 else 0, func(): return {"v": randi() % 6})
	_sprout("grass", 10 if counts.grass < 160 else 0, func(): return {"v": randi() % 4})
	_sprout("pebble", 3 if counts.pebble < 25 else 0, func(): return {})
	_sprout("log", 2 if counts.log < 15 else 0, func(): return {})
	world.set_season(season())
	world.paint_all()
	for a in animals.duplicate():
		if a.state == "wild" and a.def.get("night", false): remove_animal(a)
	if not report.is_empty():
		var parts := []
		for item in report:
			give(item, report[item], true); parts.append("%d %s" % [report[item], item_names.get(item, item)])
		ui.msg("Đàn thú mang về: " + ", ".join(parts), "good")
	ui.msg("Ngày %d bắt đầu%s." % [day, (" · tuyết rơi" if season() == 3 else " · trời mưa, cây được tưới") if rain else ""])
	if day % 7 == 1: ui.msg("Mùa %s đã đến!" % Db.SEASONS[season()].name, "good")

func _add(d: Dictionary, k: String, n: int) -> void: d[k] = d.get(k, 0) + n

func diet_names(list: Array) -> String:
	var out := []
	for x in list: out.append(item_names.get(x, x))
	return ", ".join(out)

func has_carrier() -> bool:
	for a in tamed_list():
		if a.def.get("job", "") == "carry": return true
	return false

func shop_cheer() -> void:
	for o in world.all_objs:
		if o.kind == "shop" and o.has("anim"): (o.anim as Models.AnimCtl).once("Victory", 1.2)

func _sprout(kind: String, n: int, data: Callable) -> void:
	var made := 0
	for t in 80:
		if made >= n: break
		var i := 2 + randi() % (W - 4); var j := 2 + randi() % (H - 4)
		var k := world.idx(i, j)
		if world.objs[k] != null or world.crops[k] != null or world.ttype[k] != World.GRASS or Db.in_farm(i, j): continue
		if Vector2(i, j).distance_to(Vector2(ppos.x, ppos.z)) < 4: continue
		world.add_obj(kind, i, j, data.call()); made += 1

func sleep() -> void:
	mode = Mode.MODAL
	await ui.fade_out()
	hour = 6.0
	new_day()
	hp = clampf(hp + 35, 0, 100); sanity = clampf(sanity + 35, 0, 100); hunger = clampf(hunger - 12, 0, 100)
	if riding != null: toggle_ride()
	ppos = Vector3(Db.HX + 0.5, 0, Db.HZ + 2.6); pyaw = 0.0
	save_game()
	ui.msg("Bạn ngủ một giấc ngon. Đã lưu game.", "good")
	await ui.fade_in()
	mode = Mode.PLAY

# ================================================================= survival
func update_survival(dt: float) -> void:
	var winter := season() == 3
	hunger = maxf(0.0, hunger - dt * (100.0 / (Db.DAY_SECONDS * 1.5)) * (1.4 if winter else 1.0) * (0.7 if riding != null else 1.0))
	var df := day_factor()
	var lit := is_lit_at(ppos)
	var near_fire := false
	for o in world.all_objs:
		if o.kind == "campfire" and o.fuel > 0 and Vector2(o.i + 0.5, o.j + 0.5).distance_to(Vector2(ppos.x, ppos.z)) < 4.0: near_fire = true
	var comfort: bool = follower != null and follower.def.get("job", "") == "comfort"
	if df < 0.2: sanity -= dt * (0.15 if lit else 0.9) * (0.5 if comfort else 1.0)
	else: sanity += dt * (0.02 if rain else 0.12)
	if near_fire: sanity += dt * 0.3
	if follower != null: sanity += dt * 0.03
	if hunger > 60.0: hp += dt * 0.18
	if hunger <= 0.0:
		starve_t += dt
		if starve_t > 1.0: starve_t = 0.0; hp -= 1.5
		if clock_t - last_warn > 12.0: last_warn = clock_t; ui.msg("Bạn đang đói lả! Ăn gì đó đi (phím 7).", "bad")
	if sanity <= 0.0 and clock_t - last_warn > 8.0:
		last_warn = clock_t; hp -= 4.0; ui.flash_hurt(); ui.msg("Những tiếng thì thầm vây quanh bạn...", "bad")
	if not lit:
		if dark_timer == 0.0: ui.msg("Tối quá... Có gì đó đang rình rập. Hãy tìm ánh sáng!", "bad")
		dark_timer += dt
		if dark_timer > 5.0:
			dark_hit -= dt
			if dark_hit <= 0.0:
				dark_hit = 2.4; hurt(11.0, "Có thứ gì đó cào bạn trong bóng tối!")
	else:
		dark_timer = 0.0; dark_hit = 0.0
	hp = clampf(hp, 0, 100); sanity = clampf(sanity, 0, 100)
	if hp <= 0.0: die()
	autosave += dt
	if autosave > 45.0: autosave = 0.0; save_game()

func update_fires(dt: float) -> void:
	for o in world.all_objs:
		if o.kind != "campfire": continue
		if mode == Mode.PLAY: o.fuel = maxf(0.0, float(o.fuel) - dt * (1.6 if rain else 1.0))
		var on: bool = o.fuel > 0.0
		o.radius = 3.0 + 4.0 * minf(1.0, float(o.fuel) / 60.0)
		(o.fire_model as Node3D).visible = on
		(o.particles as GPUParticles3D).emitting = on
		(o.light as OmniLight3D).light_energy = ((2.0 + sin(clock_t * 15.0 + o.i) * 0.25) * (1.2 - day_factor() * 0.8)) if on else 0.0
		(o.light as OmniLight3D).omni_range = o.radius * 1.6

func die() -> void:
	mode = Mode.DEAD
	if riding != null: toggle_ride()
	p_anim.once("Defeat", 1.0, true)
	await get_tree().create_timer(1.2).timeout
	ui.open_death()

func wake_up() -> void:
	var lost := int(gold * 0.3); gold -= lost
	hp = 55; hunger = maxf(hunger, 45); sanity = maxf(sanity, 50)
	if hour >= 6.0: new_day()
	hour = 7.0
	ppos = Vector3(Db.HX + 0.5, 0, Db.HZ + 2.6)
	p_anim.release()
	mode = Mode.PLAY
	ui.msg("Bạn mất %d G." % lost, "bad")
	save_game()

# ================================================================= camera & loop
func update_camera(dt: float) -> void:
	var focus := player.position + Vector3(0, 1.0, 0)
	var pitch := deg_to_rad(42.0)
	var target := focus + Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	cam.global_position = cam.global_position.lerp(target, minf(1.0, dt * 6.0))
	cam.look_at(focus, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: cam_dist = clampf(cam_dist - 1.0, 6.0, 22.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: cam_dist = clampf(cam_dist + 1.0, 6.0, 22.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT: rmb = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mode == Mode.PLAY: do_action()
			elif mode == Mode.TAMING: tame_press()
	elif event is InputEventMouseMotion and rmb:
		cam_yaw -= (event as InputEventMouseMotion).relative.x * 0.006
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).physical_keycode
		if mode == Mode.TAMING:
			if event.is_action("act"): tame_press()
			elif event.is_action("menu"): ui.msg("Bạn thả dây ra."); _tame_end(false)
			return
		if mode == Mode.MODAL:
			if event.is_action("menu") or event.is_action("bag") or event.is_action("herd"): ui.close_modal()
			return
		if mode != Mode.PLAY: return
		if event.is_action("act"): do_action()
		elif event.is_action("ride"): toggle_ride()
		elif event.is_action("cycle"): cycle_sel()
		elif event.is_action("bag"): ui.open_bag()
		elif event.is_action("herd"): ui.open_herd()
		elif event.is_action("menu"): ui.open_menu()
		elif key >= KEY_1 and key <= KEY_9: select_slot(key - KEY_1)
		elif key == KEY_0: select_slot(9)

func select_slot(i: int) -> void:
	sel = clampi(i, 0, Db.HOTBAR.size() - 1)
	show_tool()

func cycle_sel() -> void:
	var id: String = Db.HOTBAR[sel].id
	if id == "seeds":
		var ks := Db.CROPS.keys(); seed_sel = ks[(ks.find(seed_sel) + 1) % ks.size()]
		ui.msg("Hạt đang chọn: %s (còn %d)" % [Db.CROPS[seed_sel].name, inv.get("seed_" + seed_sel, 0)])
	elif id == "food":
		food_sel = food_list[(food_list.find(food_sel) + 1) % food_list.size()]
		ui.msg("Món đang chọn: %s (còn %d)" % [item_names[food_sel], inv.get(food_sel, 0)])

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	clock_t += dt
	p_anim.tick(dt)
	if mode == Mode.PLAY:
		update_time(dt)
		update_player(dt)
		update_survival(dt)
		spawn_t -= dt
		if spawn_t <= 0.0: spawn_t = 2.5; try_spawn()
	elif mode == Mode.TAMING:
		update_taming(dt)
	if riding != null: riding.pos = ppos; riding.yaw = pyaw
	update_animals(dt)
	place_player()
	for o in world.all_objs:
		if o.has("anim"): (o.anim as Models.AnimCtl).tick(dt)
	update_fires(dt)
	update_camera(dt)
	update_sky()
	if mode == Mode.PLAY:
		var ft := front_tile()
		highlight.visible = world.inb(ft.x, ft.y) and riding == null and Db.HOTBAR[sel].id not in ["food", "rope"]
		highlight.position = Vector3(ft.x + 0.5, 0.03, ft.y + 0.5)
	else:
		highlight.visible = false
	world.flush()
	occlude_t -= dt
	if occlude_t <= 0.0: occlude_t = 0.2; update_occluders()

## Hide trees standing between the camera and the player so the farmer is never lost in the forest.
func update_occluders() -> void:
	var cam_p := Vector2(cam.global_position.x, cam.global_position.z)
	var pl := Vector2(player.position.x, player.position.z)
	var seg := cam_p - pl
	var seg_len := seg.length()
	var dir := seg / maxf(seg_len, 0.001)
	var now := {}
	for o in world.all_objs:
		if o.kind != "tree" or o.get("pool") == null: continue
		var p := Vector2(o.i + 0.5, o.j + 0.5) - pl
		var along := p.dot(dir)
		if along < -0.6 or along > minf(seg_len, 9.0): continue
		if absf(p.cross(dir)) < 1.6 + along * 0.12: now[world.idx(o.i, o.j)] = o
	for k in occluded:
		var o = occluded[k]
		if not now.has(k) and o.get("pool") != null and world.objs[k] == o: (o.pool as Models.Pool).set_xf(o.slot, o.base)
	for k in now:
		if not occluded.has(k):
			var o = now[k]
			(o.pool as Models.Pool).set_xf(o.slot, o.base * Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3.ZERO))
	occluded = now

# ================================================================= new game / save / load
func new_game() -> void:
	seed = randi() % 1000000
	day = 1; hour = 6.0; gold = 150; pending = 0; hp = 100; hunger = 100; sanity = 100; water = 20; sel = 0; trough = 6
	tools = {"axe": false, "pickaxe": false}; rain = false; torch_time = 0.0
	inv = {}
	for k in item_names: inv[k] = 0
	inv.berry = 4; inv.seed_carrot = 6; inv.rope = 2; inv.torch = 1
	for a in animals.duplicate(): remove_animal(a)
	riding = null; follower = null
	world.clear_all()
	world.season = 0
	world.gen_terrain(seed); world.build_statics(); world.gen_objects(seed); world.paint_all()
	ppos = Vector3(Db.HX + 0.5, 0, Db.HZ + 3.5); pyaw = 0.0; cam_yaw = 0.0
	var dog := make_animal("cho", ppos + Vector3(-1.2, 0, -1.0), "follow")
	dog.trust = 3; follower = dog
	cam.global_position = ppos + Vector3(0, 10, 12)
	mode = Mode.INTRO
	ui.open_intro()

func save_game() -> bool:
	var tl := []; var cr := []; var ob := []; var an := []
	for k in W * H:
		if world.ttype[k] == World.TILLED: tl.append([k, world.wet[k]])
		var c = world.crops[k]
		if c != null: cr.append([k, c.type, c.days, c.dry, c.dead])
	for o in world.all_objs:
		if o.get("static", false): continue
		ob.append([o.kind, o.i, o.j, o.get("v", 0), 1 if o.get("berries", false) else 0, int(o.get("regrow", 0)), float(o.get("fuel", 0.0))])
	for a in animals:
		if a.state == "wild" or a.state == "tied": continue
		an.append({"id": a.id, "state": "follow" if a.state == "ridden" else a.state, "happy": a.happy, "unfed": a.unfed, "x": a.pos.x, "z": a.pos.z})
	var data := {"v": 1, "seed": seed, "day": day, "hour": hour, "gold": gold, "pending": pending, "hp": hp, "hunger": hunger, "sanity": sanity,
		"water": water, "sel": sel, "seed_sel": seed_sel, "food_sel": food_sel, "tools": tools, "inv": inv, "trough": trough, "rain": rain,
		"tilled": tl, "crops": cr, "objs": ob, "animals": an, "px": ppos.x, "pz": ppos.z}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data)); f.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return false
	var d = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != 1: return false
	seed = int(d.seed); day = int(d.day); hour = float(d.hour); gold = int(d.gold); pending = int(d.pending)
	hp = float(d.hp); hunger = float(d.hunger); sanity = float(d.sanity); water = int(d.water); sel = int(d.sel)
	seed_sel = d.seed_sel; food_sel = d.food_sel; tools = d.tools; trough = int(d.trough); rain = bool(d.rain)
	inv = {}
	for k in item_names: inv[k] = 0
	for k in d.inv: inv[k] = int(d.inv[k])
	for a in animals.duplicate(): remove_animal(a)
	riding = null; follower = null; tame = null
	world.clear_all()
	world.season = season()
	world.gen_terrain(seed); world.build_statics()
	for t in d.tilled: world.ttype[int(t[0])] = World.TILLED; world.wet[int(t[0])] = int(t[1])
	for o in d.objs:
		var data := {"v": int(o[3])}
		if o[0] == "bush": data.berries = int(o[4]) == 1; data.regrow = int(o[5])
		if o[0] == "campfire": data.fuel = float(o[6])
		world.add_obj(o[0], int(o[1]), int(o[2]), data)
	for c in d.crops:
		var k := int(c[0])
		world.crops[k] = {"type": c[1], "days": int(c[2]), "dry": int(c[3]), "dead": bool(c[4])}
		world.crop_visual(k % W, k / W)
	world.paint_all()
	ppos = Vector3(float(d.px), 0, float(d.pz))
	if not world.can_stand(ppos.x, ppos.z): ppos = Vector3(Db.HX + 0.5, 0, Db.HZ + 3.5)
	for a in d.animals:
		var an := make_animal(a.id, Vector3(float(a.x), 0, float(a.z)), a.state)
		an.happy = int(a.happy); an.unfed = int(a.unfed); an.trust = 3
		if an.state == "follow":
			if follower == null: follower = an
			else: an.state = "farm"
	cam.global_position = ppos + Vector3(0, 10, 12)
	show_tool()
	return true
