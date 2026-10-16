extends SceneTree
## Headless smoke test of game logic: godot --headless --path . -s tools/logic_test.gd
var f := 0
var g
func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nongtrai_save.json"))
	change_scene_to_file("res://main.tscn")
func free_tile(skip := 0) -> Vector2i:
	for j in range(3, 60):
		for i in range(3, 60):
			var k: int = g.world.idx(i, j)
			if g.world.objs[k] == null and g.world.ttype[k] == World.GRASS and g.world.crops[k] == null:
				if skip == 0: return Vector2i(i, j)
				skip -= 1
	return Vector2i(-1, -1)

func check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
func _process(_d):
	f += 1
	if f == 3:
		g = current_scene
		g.ui._start_game()
		# farming
		g.ppos = Vector3(Db.HX + 0.5, 0, Db.HZ + 5.5); g.pyaw = 0.0
		var ft: Vector2i = g.front_tile()
		g.till(ft.x, ft.y); g.plant(ft.x, ft.y, "carrot"); g.water_tile(ft.x, ft.y)
		check(g.world.crop_at(ft.x, ft.y) != null, "planted carrot")
		for k in 3:
			g.world.wet[g.world.idx(ft.x, ft.y)] = 1; g.new_day()
		check(g.world.crop_at(ft.x, ft.y).days >= 3, "carrot grew to ripe")
		g.harvest(ft.x, ft.y); check(g.inv.carrot >= 1, "harvested carrot")
		# crafting & shop & bin
		g.inv.fiber = 10; g.inv.wood = 10; g.inv.stone = 5
		g.ui.open_bag(); g.ui._craft(Db.RECIPES[0]); g.ui._craft(Db.RECIPES[2]); check(g.tools.axe and g.inv.rope >= 3, "crafted axe and rope")
		g.ui.open_shop(); var gold0: int = g.gold; g.ui._buy("seed_corn", 35, 1); check(g.gold == gold0 - 35, "bought seed")
		g.ui.open_bin(); g.ui._sell("wood", 2, -1); check(g.pending > 0, "sold wood")
		g.ui.close_modal()
		# taming a cow and a horse
		var cow = g.make_animal("bo", g.ppos + Vector3(0, 0, 3))
		g.start_tame(cow)
		while g.tame != null:
			g.tame.marker = g.tame.zone_c; g.tame_press()
		check(cow.state in ["follow", "farm"], "tamed cow (" + cow.state + ")")
		var horse = g.make_animal("ngua", g.ppos + Vector3(1, 0, 3))
		g.start_tame(horse)
		var misses := 0
		while g.tame != null and misses < 2:
			g.tame.marker = fposmod(g.tame.zone_c + 0.5, 1.0); g.tame_press(); misses += 1
		while g.tame != null:
			g.tame.marker = g.tame.zone_c; g.tame_press()
		check(horse.state == "follow", "tamed horse follows")
		horse.pos = g.ppos + Vector3(1, 0, 0)
		g.toggle_ride(); check(g.riding == horse, "riding horse")
		g.toggle_ride(); check(g.riding == null, "dismounted")
		# feeding, jobs, herd UI
		var sheep = g.make_animal("cuu", g.ppos + Vector3(-2, 0, 0)); sheep.state = "farm"; sheep.trust = 3
		var slime = g.make_animal("slime", g.ppos + Vector3(-3, 0, 0)); slime.state = "farm"
		g.trough = 20; g.ui.open_herd(); g.ui._to_trough("carrot", 2) if g.inv.carrot > 0 else null; g.ui.close_modal()
		var milk0: int = g.inv.milk; var wool0: int = g.inv.wool
		g.new_day()
		check(g.inv.milk > milk0 and g.inv.wool > wool0, "cow gave milk, sheep gave wool")
		g.food_sel = "berry"; g.inv.berry = 3; g.pyaw = atan2(sheep.pos.x - g.ppos.x, sheep.pos.z - g.ppos.z); sheep.pos = g.ppos + Vector3(sin(g.pyaw), 0, cos(g.pyaw)) * 1.5
		g.feed_animal(sheep)
		# hostile shove
		var bat = g.make_animal("doi", g.ppos + Vector3(0, 0, 1.5))
		for k in 3: g.shove(bat)
		check(not g.animals.has(bat), "bat banished after 3 shoves")
		# chopping & mining with tools
		g.tools.pickaxe = true
		var t1 := free_tile()
		var placed = g.world.add_obj("tree", t1.x, t1.y, {"v": 1})
		for k in 3: g.chop(placed, true)
		check(g.world.obj_at(t1.x, t1.y) != null and g.world.obj_at(t1.x, t1.y).kind == "stump", "tree became stump")
		var t2 := free_tile()
		var rock = g.world.add_obj("rock", t2.x, t2.y, {"v": 0})
		for k in 4: g.mine(rock)
		check(g.world.obj_at(t2.x, t2.y) == null, "rock mined")
		var t3 := free_tile()
		g.inv.campfire = 1; g.place_campfire(t3.x, t3.y); check(g.world.obj_at(t3.x, t3.y).kind == "campfire", "campfire placed")
		g.inv.torch = 1; g.select_slot(8); g.light_torch(); check(g.torch_on(), "torch lit")
		# many days incl. seasons
		g.trough = 999
		for k in 25: g.new_day()
		check(g.world.season == g.season(), "season switched to " + str(g.season()))
		# save / load roundtrip
		var tamed_before: int = g.tamed_list().size()
		check(g.save_game(), "saved")
		check(g.load_game(), "loaded")
		check(g.tamed_list().size() == tamed_before, "animals restored (%d of %d)" % [g.tamed_list().size(), tamed_before])
		# death & wake
		g.hunger = 0; g.hp = 0; g.update_survival(0.1)
	if f == 120:
		check(g.mode == g.Mode.DEAD, "died at hp 0")
		g.wake_up(); check(g.mode == g.Mode.PLAY and g.hp > 0, "woke up")
		g.ui.open_menu(); g.ui.close_modal()
		print("DONE"); quit()
	return false
