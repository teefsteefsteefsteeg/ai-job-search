extends SceneTree
const OUT := "/tmp/claude-0/-home-user-ai-job-search/864a0408-33a2-546f-9756-7e229d14d585/scratchpad/"
var f := 0
var g
func _init():
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nongtrai_save.json"))
	change_scene_to_file("res://main.tscn")
func _process(_d):
	f += 1
	if f == 5: g = current_scene; g.ui._creator_select("Pirate_Female")
	if f == 30: get_root().get_texture().get_image().save_png(OUT + "creator.png")
	if f == 32:
		var le := LineEdit.new(); le.text = "Lan"; var le2 := LineEdit.new(); le2.text = "Hoa Sen"
		g.ui._creator_done(le, le2, null, true); g.ui._start_game(); g.cam_dist = 6.0
	if f == 50: get_root().get_texture().get_image().save_png(OUT + "creator2.png"); quit()
	return false
