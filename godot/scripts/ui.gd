class_name GameUI
extends CanvasLayer
## HUD, hotbar, lasso minigame bar and modal panels, all built in code.

var game
var theme_ui: Theme
var font_body: FontFile
var font_bold: FontFile
var font_display: FontFile

const INK := Color("f3ead3")
const MUTED := Color("b5b099")
const WHEAT := Color("e8b84a")
const LEAF := Color("7fb069")
const HP_C := Color("e2604c")
const FOOD_C := Color("e8a33d")
const MIND_C := Color("a58ad6")
const PANEL := Color(0.067, 0.098, 0.082, 0.88)

var root: Control
var bars := {}
var clock_time: Label
var clock_day: Label
var gold_label: Label
var follower_box: PanelContainer
var follower_label: Label
var log_box: VBoxContainer
var prompt: Label
var prompt_panel: PanelContainer
var slots: Array = []
var tame_panel: PanelContainer
var tame_bar: Control
var tame_label: Label
var modal: Control
var modal_body: VBoxContainer
var modal_title: Label
var fade: ColorRect
var hurt: TextureRect
var vignette: TextureRect
var prompt_t := 0.0
var stats_panel: PanelContainer
var clock_panel: PanelContainer
var help_label: Label
var hotbar_panel: PanelContainer
var modal_panel: Panel

func _ready() -> void:
	font_body = load("res://assets/fonts/Be_Vietnam_Pro_wght-500.ttf")
	font_bold = load("res://assets/fonts/Be_Vietnam_Pro_wght-700.ttf")
	font_display = load("res://assets/fonts/Baloo_2_wght-800.ttf")
	_build_theme()
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_ui; add_child(root)
	vignette = _radial(Color(0.24, 0.08, 0.36, 0.85)); root.add_child(vignette); vignette.modulate.a = 0.0
	hurt = _radial(Color(0.8, 0.1, 0.05, 0.75)); root.add_child(hurt); hurt.modulate.a = 0.0
	_build_stats(); _build_clock(); _build_follower(); _build_log(); _build_hotbar(); _build_prompt(); _build_tame(); _build_modal()
	fade = ColorRect.new(); fade.color = Color.BLACK; fade.set_anchors_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0; root.add_child(fade)

# ---------------------------------------------------------------- theme helpers
func _box(bg: Color, radius := 12, border := Color(0.95, 0.92, 0.83, 0.14), pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.set_corner_radius_all(radius)
	sb.border_color = border; sb.set_border_width_all(1)
	sb.content_margin_left = pad; sb.content_margin_right = pad; sb.content_margin_top = pad * 0.7; sb.content_margin_bottom = pad * 0.7
	return sb

func _build_theme() -> void:
	theme_ui = Theme.new()
	theme_ui.default_font = font_body
	theme_ui.default_font_size = 17
	theme_ui.set_color("font_color", "Label", INK)
	theme_ui.set_stylebox("panel", "PanelContainer", _box(PANEL))
	theme_ui.set_stylebox("panel", "Panel", _box(Color("1d2b23"), 16, Color(0.95, 0.92, 0.83, 0.16), 18))
	var bn := _box(WHEAT, 9, Color(0, 0, 0, 0), 12); var bh := _box(WHEAT.lightened(0.15), 9, Color(0, 0, 0, 0), 12)
	var bp := _box(WHEAT.darkened(0.15), 9, Color(0, 0, 0, 0), 12); var bd := _box(Color(0.5, 0.5, 0.45, 0.35), 9, Color(0, 0, 0, 0), 12)
	theme_ui.set_stylebox("normal", "Button", bn); theme_ui.set_stylebox("hover", "Button", bh); theme_ui.set_stylebox("pressed", "Button", bp)
	theme_ui.set_stylebox("disabled", "Button", bd); theme_ui.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 9, INK, 12))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: theme_ui.set_color(st, "Button", Color("2a1d05"))
	theme_ui.set_color("font_disabled_color", "Button", Color(0.9, 0.88, 0.8, 0.5))
	theme_ui.set_font("font", "Button", font_bold)
	theme_ui.set_stylebox("background", "ProgressBar", _box(Color(1, 1, 1, 0.1), 5, Color(0, 0, 0, 0), 0))

func _label(text: String, size := 17, color := INK, font: Font = null) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if font: l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _radial(c: Color) -> TextureRect:
	var g := Gradient.new(); g.set_color(0, Color(c, 0.0)); g.set_color(1, c); g.add_point(0.55, Color(c, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 1.0)
	var tr := TextureRect.new(); tr.texture = gt; tr.set_anchors_preset(Control.PRESET_FULL_RECT); tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _anchor(c: Control, preset: int, offset: Vector2) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	c.position += offset

# ---------------------------------------------------------------- HUD
func _build_stats() -> void:
	var p := PanelContainer.new(); root.add_child(p); stats_panel = p
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	for spec in [["hp", "Máu", HP_C], ["food", "No bụng", FOOD_C], ["mind", "Tinh thần", MIND_C]]:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); v.add_child(h)
		var l := _label(spec[1], 14); l.custom_minimum_size.x = 78; h.add_child(l)
		var pb := ProgressBar.new(); pb.custom_minimum_size = Vector2(150, 10); pb.show_percentage = false; pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.add_theme_stylebox_override("fill", _box(spec[2], 5, Color(0, 0, 0, 0), 0)); h.add_child(pb)
		var n := _label("100", 14, INK, font_bold); n.custom_minimum_size.x = 30; n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(n)
		bars[spec[0]] = [pb, n]

func _build_clock() -> void:
	var p := PanelContainer.new(); root.add_child(p); clock_panel = p
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); p.add_child(v)
	clock_time = _label("06:00", 32, INK, font_display); clock_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.add_child(clock_time)
	clock_day = _label("", 14, MUTED); clock_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.add_child(clock_day)
	gold_label = _label("", 19, WHEAT, font_display); gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.add_child(gold_label)
	p.custom_minimum_size.x = 230
	help_label = _label("C túi · H đàn thú · F cưỡi · Esc menu", 13, MUTED)
	root.add_child(help_label)

func _build_follower() -> void:
	follower_box = PanelContainer.new(); root.add_child(follower_box)
	follower_label = _label("", 14); follower_box.add_child(follower_label)

func _build_log() -> void:
	log_box = VBoxContainer.new(); log_box.add_theme_constant_override("separation", 4); log_box.custom_minimum_size.x = 420
	log_box.alignment = BoxContainer.ALIGNMENT_END; log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_box)

func _build_hotbar() -> void:
	var p := PanelContainer.new(); root.add_child(p); hotbar_panel = p
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); p.add_child(h)
	for i in Db.HOTBAR.size():
		var b := Button.new(); b.custom_minimum_size = Vector2(76, 64); b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): _slot_pressed(i))
		h.add_child(b); slots.append(b)

func _slot_pressed(i: int) -> void:
	if game.mode != game.Mode.PLAY: return
	if game.sel == i and Db.HOTBAR[i].id in ["seeds", "food"]: game.cycle_sel()
	else: game.select_slot(i)

func _build_prompt() -> void:
	prompt_panel = PanelContainer.new(); root.add_child(prompt_panel)
	prompt = _label("", 16, INK, font_bold); prompt_panel.add_child(prompt)

class TameBar extends Control:
	var ui
	func _draw() -> void:
		var t = ui.game.tame
		if t == null: return
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.1))
		var zc: float = t.zone_c; var zw: float = t.zone_w
		draw_rect(Rect2((zc - zw * 0.5) * w, 0, zw * w, h), Color("7fb069"))
		draw_rect(Rect2(float(t.marker) * w - 3, -6, 6, h + 12), Color("f3ead3"))
	func _process(_d: float) -> void: queue_redraw()

func _build_tame() -> void:
	tame_panel = PanelContainer.new(); root.add_child(tame_panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); tame_panel.add_child(v)
	tame_label = _label("", 17, INK, font_bold); tame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tame_label)
	tame_bar = TameBar.new(); tame_bar.ui = self; tame_bar.custom_minimum_size = Vector2(520, 26); v.add_child(tame_bar)
	var hint := _label("Space / nhấp chuột khi kim trắng nằm trong vùng xanh · Esc để thả dây", 13, MUTED); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(hint)
	tame_panel.visible = false

func _build_modal() -> void:
	modal = Control.new(); modal.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(modal)
	var dim := ColorRect.new(); dim.color = Color(0.02, 0.03, 0.025, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var panel := Panel.new(); modal.add_child(panel); modal_panel = panel
	var margin := MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); margin.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	modal_title = _label("", 30, INK, font_display); modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(modal_title)
	var x := Button.new(); x.text = "Đóng"; x.focus_mode = Control.FOCUS_NONE; x.pressed.connect(close_modal); head.add_child(x)
	x.name = "close"
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	modal_body = VBoxContainer.new(); modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; modal_body.add_theme_constant_override("separation", 8)
	scroll.add_child(modal_body)
	modal.visible = false

# ---------------------------------------------------------------- per-frame refresh
func _process(dt: float) -> void:
	if game == null: return
	_layout()
	_set_bar("hp", game.hp); _set_bar("food", game.hunger); _set_bar("mind", game.sanity)
	var h := int(game.hour); var m := int((game.hour - h) * 6) * 10
	clock_time.text = "%02d:%02d" % [h, m]
	var wx := ("Tuyết rơi" if game.season() == 3 else "Mưa") if game.rain else ("Đêm" if game.is_night() else "Nắng")
	clock_day.text = "Ngày %d · %s · %s" % [game.day, Db.SEASONS[game.season()].name, wx]
	gold_label.text = "%d G%s" % [game.gold, (" (+%d sáng mai)" % game.pending) if game.pending > 0 else ""]
	for i in slots.size():
		var b: Button = slots[i]
		var id: String = Db.HOTBAR[i].id
		b.text = "%d\n%s" % [(i + 1) % 10, _slot_text(id)]
		var locked: bool = (id == "axe" and not game.tools.axe) or (id == "pickaxe" and not game.tools.pickaxe)
		var sb := _box(WHEAT if i == game.sel else Color(1, 1, 1, 0.06), 9, WHEAT if i == game.sel else Color(1, 1, 1, 0.12), 6)
		b.add_theme_stylebox_override("normal", sb); b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", Color("2a1d05") if i == game.sel else (Color(0.9, 0.88, 0.8, 0.4) if locked else INK))
		b.add_theme_color_override("font_hover_color", Color("2a1d05") if i == game.sel else INK)
	var f = game.riding if game.riding != null else game.follower
	follower_box.visible = f != null
	if f != null:
		var job: String = Db.JOB_NAMES.get(f.def.get("job", "none"), "")
		follower_label.text = "%s %s · %s%s" % ["Đang cưỡi" if game.riding != null else "Đi cùng:", f.def.name, job, " · F để cưỡi" if game.riding == null and float(f.def.get("ride", 0.0)) > 0.0 else ""]
	vignette.modulate.a = (1.0 - game.sanity / 35.0) * 0.9 if game.sanity < 35 else 0.0
	tame_panel.visible = game.tame != null
	if game.tame != null:
		var t = game.tame
		tame_label.text = "Thuần hóa %s · %d/%d · dây %s" % [t.a.def.name, t.prog, t.need, "●".repeat(t.str) + "○".repeat(t.max_str - t.str)]
	prompt_t -= dt
	if prompt_t <= 0.0:
		prompt_t = 0.12
		var a = game.get_action() if game.mode == game.Mode.PLAY else null
		prompt_panel.visible = a != null
		if a != null: prompt.text = ("[Space] " if a.has("fn") else "") + String(a.label)

func _fit(c: Control) -> Vector2:
	c.size = c.get_combined_minimum_size()
	return c.size

func _layout() -> void:
	var vs := root.get_viewport_rect().size
	_fit(stats_panel); stats_panel.position = Vector2(14, 12)
	var fs := _fit(follower_box); follower_box.position = Vector2(14, 12 + stats_panel.size.y + 8)
	var cs := _fit(clock_panel); clock_panel.position = Vector2(vs.x - cs.x - 14, 12)
	var hs := _fit(help_label); help_label.position = Vector2(vs.x - hs.x - 16, 12 + cs.y + 6)
	var hb := _fit(hotbar_panel); hotbar_panel.position = Vector2((vs.x - hb.x) * 0.5, vs.y - hb.y - 12)
	var ps := _fit(prompt_panel); prompt_panel.position = Vector2((vs.x - ps.x) * 0.5, hotbar_panel.position.y - ps.y - 10)
	var ts := _fit(tame_panel); tame_panel.position = Vector2((vs.x - ts.x) * 0.5, hotbar_panel.position.y - ts.y - 60)
	log_box.size = Vector2(420, 260); log_box.position = Vector2(14, hotbar_panel.position.y - 270)
	if vs.x < 1100: log_box.position.y = prompt_panel.position.y - 270
	var ms := Vector2(minf(820, vs.x - 40), minf(640, vs.y - 40))
	modal_panel.size = ms; modal_panel.position = (vs - ms) * 0.5

func _set_bar(k: String, v: float) -> void:
	(bars[k][0] as ProgressBar).value = v
	(bars[k][1] as Label).text = str(int(round(v)))

func _slot_text(id: String) -> String:
	var inv: Dictionary = game.inv
	match id:
		"can": return "Nước %d" % game.water
		"axe": return "Rìu" if game.tools.axe else "Chưa có"
		"pickaxe": return "Rìu đá" if game.tools.pickaxe else "Chưa có"
		"seeds": return "%s %d" % [Db.CROPS[game.seed_sel].name, inv.get("seed_" + game.seed_sel, 0)]
		"food": return "%s %d" % [game.item_names[game.food_sel], inv.get(game.food_sel, 0)]
		"rope": return "Dây %d" % (inv.get("rope", 0) + inv.get("rope2", 0))
		"torch": return ("Cháy %ds" % int(game.torch_time)) if game.torch_time > 0 else "Đuốc %d" % inv.get("torch", 0)
		"campfire": return "Lửa %d" % inv.get("campfire", 0)
	for s in Db.HOTBAR:
		if s.id == id: return s.name
	return id

func msg(text: String, kind := "") -> void:
	var p := PanelContainer.new()
	var col := {"good": LEAF, "bad": HP_C, "mon": MIND_C}.get(kind, WHEAT) as Color
	var sb := _box(PANEL, 6, Color(0, 0, 0, 0), 8); sb.border_color = col; sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 15); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 380; p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_child(p)
	while log_box.get_child_count() > 6: log_box.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(5.5); tw.tween_property(p, "modulate:a", 0.0, 0.6); tw.tween_callback(p.queue_free)

func flash_hurt() -> void:
	hurt.modulate.a = 1.0
	create_tween().tween_property(hurt, "modulate:a", 0.0, 0.5)

func fade_out() -> void:
	var tw := create_tween(); tw.tween_property(fade, "modulate:a", 1.0, 0.7)
	await tw.finished

func fade_in() -> void:
	var tw := create_tween(); tw.tween_property(fade, "modulate:a", 0.0, 0.7)
	await tw.finished

# ---------------------------------------------------------------- modal helpers
func _open(title: String, closable := true) -> void:
	modal_title.text = title
	for c in modal_body.get_children(): c.free()
	modal.visible = true
	modal.find_child("close", true, false).visible = closable
	if game.mode == game.Mode.PLAY: game.mode = game.Mode.MODAL

func close_modal() -> void:
	modal.visible = false
	if game.mode == game.Mode.MODAL: game.mode = game.Mode.PLAY

func _note(text: String) -> Label:
	var l := _label(text, 15, MUTED); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; modal_body.add_child(l); return l

func _heading(text: String) -> void:
	var l := _label(text.to_upper(), 13, MUTED, font_bold); modal_body.add_child(l)

func _row(title: String, sub: String, buttons: Array) -> HBoxContainer:
	var bg := PanelContainer.new(); bg.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.04), 9, Color(0, 0, 0, 0), 10))
	modal_body.add_child(bg)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); bg.add_child(h)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	v.add_child(_label(title, 17, INK, font_bold))
	if sub != "":
		var s := _label(sub, 14, MUTED); s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(s)
	for spec in buttons:
		var b := Button.new(); b.text = spec[0]; b.focus_mode = Control.FOCUS_NONE; b.disabled = not spec[2]
		b.pressed.connect(spec[1]); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(b)
	return h

# ---------------------------------------------------------------- modals
func open_intro() -> void:
	_open("Nông Trại Hoang Dã", false)
	_note("Bạn thừa kế một nông trại bỏ hoang giữa rừng, cùng chú chó trung thành. Ban ngày trồng trọt, ban đêm sống sót, và dùng dây thừng thuần hóa thú hoang để chúng làm việc cho bạn.")
	_heading("Cách chơi")
	_row("Trồng trọt", "Cuốc đất (2), gieo hạt (6), tưới nước (3) mỗi ngày. Thu hoạch rồi bỏ vào thùng hàng để có tiền sáng hôm sau.", [])
	_row("Thuần hóa", "Chế dây thừng từ 3 sợi cỏ. Chọn Dây thừng (8), hướng về con thú hoang và bấm Space. Bấm đúng lúc kim nằm trong vùng xanh để ghì. Cho thú ăn món nó thích trước thì dễ hơn.", [])
	_row("Thú phụ việc", "Thú về chuồng sẽ làm việc mỗi sáng nếu được ăn: bò cho sữa, cừu cho len, heo tìm nấm, slime tưới cây, chó và sói gác đêm. Bỏ thức ăn vào máng ở chuồng (phím H).", [])
	_row("Cưỡi thú", "Ngựa, ngựa vằn, lạc đà, sói và rồng cưỡi được: đứng cạnh và bấm F.", [])
	_row("Sinh tồn", "Giữ no bụng và tinh thần. Đêm xuống, đứng trong bóng tối quá lâu sẽ bị tấn công: ở cạnh lửa trại, cầm đuốc, hoặc về nhà ngủ.", [])
	_row("Điều khiển", "WASD đi · Shift chạy · Space / chuột trái dùng · 1–0 chọn đồ · R đổi hạt, món ăn · Q/E hoặc chuột phải xoay camera · lăn chuột phóng to.", [])
	var b := Button.new(); b.text = "Bắt đầu"; b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_start_game)
	modal_body.add_child(b)

func open_bag() -> void:
	_open("Túi & chế tạo")
	var inv: Dictionary = game.inv
	_heading("Trong túi")
	var any := false
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 18); modal_body.add_child(grid)
	for k in inv:
		if inv[k] > 0:
			any = true
			grid.add_child(_label("%s × %d" % [game.item_names.get(k, k), inv[k]], 15))
	if not any: _note("Túi trống.")
	_note("Bình tưới: %d/20 · Công cụ: Tay, Cuốc, Bình tưới%s%s" % [game.water, ", Rìu" if game.tools.axe else "", ", Rìu đá" if game.tools.pickaxe else ""])
	_heading("Chế tạo")
	for r in Db.RECIPES:
		var need := []
		var ok := true
		for k in r.need:
			need.append("%d %s" % [r.need[k], game.item_names[k]])
			if inv.get(k, 0) < r.need[k]: ok = false
		var owned: bool = r.get("tool", false) and game.tools.get(r.id, false)
		_row(r.name, " + ".join(need) + " · " + r.desc, [["Đã có" if owned else "Làm", _craft.bind(r), ok and not owned]])

func _craft(r: Dictionary) -> void:
	for k in r.need: game.inv[k] -= r.need[k]
	if r.get("tool", false):
		game.tools[r.id] = true; msg("Đã chế tạo %s!" % r.name, "good")
	else:
		game.give(r.id, r.get("give", 1))
	game.show_tool()
	open_bag()

func open_shop() -> void:
	_open("Cửa hàng của bà Tư")
	_note("Hạt giống chỉ lớn khi được tưới mỗi ngày. Mùa đông cây không lớn. Bạn có %d G." % game.gold)
	for k in Db.CROPS:
		var c: Dictionary = Db.CROPS[k]
		_row("Hạt %s · %d G" % [String(c.name).to_lower(), c.seed], "Lớn trong %d ngày · bán %d G · đang có %d" % [c.days, c.sell, game.inv.get("seed_" + k, 0)],
			[["Mua 1", _buy.bind("seed_" + k, c.seed, 1), game.gold >= c.seed], ["Mua 5", _buy.bind("seed_" + k, c.seed, 5), game.gold >= c.seed * 5]])
	for spec in [["rope", 20, "Thuần hóa thú hoang."], ["berry", 10, "Ăn hoặc cho thú ăn."], ["torch", 15, "Ánh sáng mang theo người."]]:
		_row("%s · %d G" % [game.item_names[spec[0]], spec[1]], "%s Đang có %d." % [spec[2], game.inv.get(spec[0], 0)],
			[["Mua 1", _buy.bind(spec[0], spec[1], 1), game.gold >= spec[1]], ["Mua 5", _buy.bind(spec[0], spec[1], 5), game.gold >= spec[1] * 5]])

func _buy(item: String, price: int, n: int) -> void:
	if game.gold < price * n: return
	game.gold -= price * n; game.inv[item] = game.inv.get(item, 0) + n
	game.shop_cheer()
	open_shop()

func open_bin() -> void:
	_open("Thùng hàng")
	var bonus: bool = game.has_carrier()
	_note("Bỏ hàng vào thùng, người thu mua trả tiền sáng hôm sau.%s%s" % [" Lạc đà chở hàng: +15%." if bonus else "", (" Đang chờ: %d G." % game.pending) if game.pending > 0 else ""])
	var any := false
	for k in game.sell_prices:
		if game.inv.get(k, 0) > 0:
			any = true
			var price := int(round(game.sell_prices[k] * (1.15 if bonus else 1.0)))
			_row("%s × %d" % [game.item_names[k], game.inv[k]], "%d G mỗi cái" % price, [["Bỏ 1", _sell.bind(k, price, 1), true], ["Bỏ hết", _sell.bind(k, price, -1), true]])
	if not any: _note("Chưa có gì để bán. Trồng cây, nuôi thú, chặt gỗ rồi quay lại nhé.")

func _sell(item: String, price: int, n: int) -> void:
	var count: int = game.inv[item] if n < 0 else 1
	game.inv[item] -= count; game.pending += price * count
	open_bin()

func open_herd() -> void:
	_open("Chuồng thú & đàn thú")
	var tamed: Array = game.tamed_list()
	var need := 0
	for a in tamed: need += 2 if int(a.def.size) >= 2 else 1
	_note("Máng ăn: %d phần · đàn cần %d phần mỗi sáng. Thú được ăn sẽ làm việc; đói 3 ngày liền sẽ bỏ đi. Cho ăn tận tay (phím 7) cũng được." % [game.trough, need])
	_heading("Bỏ thức ăn vào máng")
	var hbox := HFlowContainer.new(); hbox.add_theme_constant_override("h_separation", 8); hbox.add_theme_constant_override("v_separation", 8); modal_body.add_child(hbox)
	for k in game.food_vals:
		if game.inv.get(k, 0) > 0:
			var units: int = game.food_vals[k].get("trough", 1)
			var b := Button.new(); b.text = "%s ×%d (+%d phần)" % [game.item_names[k], game.inv[k], units]; b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_to_trough.bind(k, units)); hbox.add_child(b)
	if hbox.get_child_count() == 0: _note("Không có gì để cho vào máng. Sợi cỏ, quả mọng, rau củ đều được.")
	_heading("Đàn thú (%d)" % tamed.size())
	if tamed.is_empty(): _note("Chưa có con nào. Chế dây thừng và đi thuần hóa thú hoang!")
	for a in tamed:
		var d: Dictionary = a.def
		var status := {"follow": "đi theo bạn", "farm": "ở nông trại", "ridden": "đang cưỡi"}.get(a.state, a.state) as String
		var hearts := "♥".repeat(a.happy) + "♡".repeat(5 - a.happy)
		var btns := []
		if a.state == "farm": btns.append(["Theo tôi", _set_follow.bind(a), true])
		elif a.state == "follow": btns.append(["Về chuồng", _send_farm.bind(a), true])
		btns.append(["Thả", _release.bind(a), a.state != "ridden"])
		var job_name: String = Db.JOB_NAMES.get(d.get("job", "none"), "")
		var fed_text := " · hôm nay đã ăn" if a.fed else ""
		var sub := "%s · %s · %s · thích: %s%s" % [hearts, job_name, d.text, game.diet_names(d.diet), fed_text]
		_row("%s · %s" % [d.name, status], sub, btns)

func _to_trough(k: String, units: int) -> void:
	game.inv[k] -= 1; game.trough += units
	open_herd()

func _set_follow(a: Dictionary) -> void:
	if game.follower != null: game.follower.state = "farm"
	a.state = "follow"; game.follower = a
	open_herd()

func _send_farm(a: Dictionary) -> void:
	a.state = "farm"
	if game.follower == a: game.follower = null
	open_herd()

func _release(a: Dictionary) -> void:
	a.state = "wild"; a.trust = 0; a.calm = 10.0
	if game.follower == a: game.follower = null
	msg("%s đã trở về tự nhiên." % a.def.name)
	open_herd()

func open_menu() -> void:
	_open("Menu")
	_row("Lưu game", "Tự lưu mỗi khi ngủ và mỗi 45 giây.", [["Lưu", _save_now, true]])
	_row("Chơi lại từ đầu", "Xóa tiến trình hiện tại.", [["Chơi lại", _confirm_new, true]])
	_row("Thoát game", "", [["Thoát", _quit, true]])
	_note("Model 3D: Quaternius (quaternius.com), giấy phép CC0. Font: Be Vietnam Pro, Baloo 2 (SIL OFL).")

func _confirm_new() -> void:
	_open("Chơi lại từ đầu?")
	_note("Toàn bộ nông trại, đàn thú và tiền sẽ mất.")
	_row("Chắc chắn", "", [["Xóa và chơi lại", _do_new, true], ["Quay lại", open_menu, true]])

func open_death() -> void:
	_open("Bạn đã ngất xỉu", false)
	_note(("Cơn đói đã quật ngã bạn." if game.hunger <= 0 else ("Bóng tối đã nuốt chửng bạn." if game.is_night() else "Bạn kiệt sức giữa đồng.")) + " Dân làng đưa bạn về nhà, nhưng làm rơi mất một phần tiền.")
	var b := Button.new(); b.text = "Tỉnh dậy ở nhà"; b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_wake)
	modal_body.add_child(b)

func _start_game() -> void:
	modal.visible = false
	game.mode = game.Mode.PLAY
	msg("Chọn Cuốc (phím 2), đứng trước ô cỏ và bấm Space để cuốc đất.")
	msg("Nhổ cỏ và nhặt khúc gỗ để chế tạo Rìu, dây thừng (phím C).")

func _save_now() -> void:
	msg("Đã lưu." if game.save_game() else "Không lưu được.", "good")

func _quit() -> void:
	game.save_game()
	game.get_tree().quit()

func _do_new() -> void:
	modal.visible = false
	DirAccess.remove_absolute(game.SAVE_PATH)
	game.new_game()

func _wake() -> void:
	modal.visible = false
	game.wake_up()
