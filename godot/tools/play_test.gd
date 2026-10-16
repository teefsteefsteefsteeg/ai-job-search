extends SceneTree
## Runs the game, drives a few actions and saves screenshots: xvfb-run godot --path . -s tools/play_test.gd
const OUT := "/tmp/claude-0/-home-user-ai-job-search/864a0408-33a2-546f-9756-7e229d14d585/scratchpad/"
var f := 0
var g
func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nongtrai_save.json"))
	change_scene_to_file("res://main.tscn")
func shot(n: String): get_root().get_texture().get_image().save_png(OUT + n + ".png"); print("shot ", n)
func _process(_d):
	f += 1
	if f % 50 == 0: print("frame ", f, " fps ", Engine.get_frames_per_second(), " t ", Time.get_ticks_msec())
	if f == 5: g = current_scene
	if f == 40: shot("t1_intro")
	if f == 45: g.ui._start_game()
	if f == 50:
		g.select_slot(1); g.do_action()
	if f == 80:
		g.select_slot(5); g.do_action()
	if f == 110: shot("t2_farm")
	if f == 115:
		g.ppos = Vector3(26, 0, 30); g.cam_yaw = 0.8
		g.make_animal("ngua", g.ppos + Vector3(2.5, 0, -1.5)); g.make_animal("bo", g.ppos + Vector3(-2, 0, -3)); g.make_animal("cuu", g.ppos + Vector3(1, 0, -4)); g.make_animal("soi", g.ppos + Vector3(-3.5, 0, 0))
	if f == 170: shot("t3_animals")
	if f == 175:
		var a = g.animals.filter(func(x): return x.id == "ngua")[0]
		g.pyaw = atan2(a.pos.x - g.ppos.x, a.pos.z - g.ppos.z); g.start_tame(a)
	if f == 185: shot("t4_tame")
	if f == 205:
		for i in 8:
			if g.tame == null: break
			g.tame.marker = g.tame.zone_c; g.tame_press()
	if f == 240:
		g.toggle_ride()
	if f == 280: shot("t5_ride")
	if f == 285:
		g.hour = 21.5; g.toggle_ride(); g.inv.campfire = 1; g.select_slot(9); g.pyaw = PI; g.p_anim.release(); g.do_action(); g.inv.torch = 1; g.select_slot(8); g.p_anim.release(); g.do_action()
	if f == 340: shot("t6_night")
	if f == 345:
		g.ui.open_herd()
	if f == 360: shot("t7_herd")
	if f == 365:
		g.ui.close_modal(); for k in 15: g.new_day()
		g.hour = 12.0
	if f == 420: shot("t8_autumn")
	if f == 425:
		for k in 8: g.new_day()
	if f == 470: shot("t9_winter"); quit()
	return false
