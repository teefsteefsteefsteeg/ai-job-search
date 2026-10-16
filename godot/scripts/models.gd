class_name Models
## Loads the Quaternius FBX models, normalises their size and batches static scenery into MultiMeshes.

static var _scenes := {}
static var _heights := {}
static var _templates := {}
static var pools := {}
static var pool_parent: Node3D

static func scene(path: String) -> PackedScene:
	if _scenes.has(path): return _scenes[path]
	var full := "res://assets/%s.fbx" % path
	var ps: PackedScene = load(full) if ResourceLoader.exists(full) else null
	if ps == null: push_warning("Missing model: " + full)
	_scenes[path] = ps
	return ps

## Posed height of a model at scale 1 (skeleton-aware, so skinned animals measure correctly).
static func measure(path: String) -> AABB:
	if _heights.has(path): return _heights[path]
	var ps := scene(path)
	var box := AABB(Vector3.ZERO, Vector3.ONE)
	if ps:
		var n: Node3D = ps.instantiate()
		box = _posed_aabb(n)
		n.free()
	_heights[path] = box
	return box

static func _xf_to(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != root:
		if cur is Node3D: t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

static func _posed_aabb(root: Node3D) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.mesh == null: continue
		var skel: Skeleton3D = null
		if m.skin != null and not m.skeleton.is_empty(): skel = m.get_node_or_null(m.skeleton) as Skeleton3D
		var mxf := _xf_to(m, root)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty(): continue
			var step: int = maxi(1, verts.size() / 400)
			if skel != null and arr[Mesh.ARRAY_BONES] != null:
				var bones = arr[Mesh.ARRAY_BONES]
				var weights = arr[Mesh.ARRAY_WEIGHTS]
				var per: int = bones.size() / verts.size()
				var sxf := _xf_to(skel, root)
				for vi in range(0, verts.size(), step):
					var p := Vector3.ZERO
					for k in per:
						var w: float = weights[vi * per + k]
						if w <= 0.0: continue
						var bi: int = bones[vi * per + k]
						var bidx := m.skin.get_bind_bone(bi)
						if bidx < 0: bidx = skel.find_bone(m.skin.get_bind_name(bi))
						if bidx < 0: continue
						p += (sxf * skel.get_bone_global_rest(bidx) * m.skin.get_bind_pose(bi) * verts[vi]) * w
					lo = lo.min(p); hi = hi.max(p)
			else:
				for vi in range(0, verts.size(), step):
					var p2 := mxf * verts[vi]
					lo = lo.min(p2); hi = hi.max(p2)
	if lo.x == INF: return AABB(Vector3.ZERO, Vector3.ONE)
	return AABB(lo, hi - lo)

## Instantiates a model inside an empty root, scaled so it is `height` metres tall and standing on y = 0.
static func spawn(path: String, height: float, yaw_offset := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = path.get_file()
	var ps := scene(path)
	if ps == null:
		var box := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.5, height, 0.5); box.mesh = bm
		box.position.y = height * 0.5; root.add_child(box)
		return root
	var n: Node3D = ps.instantiate()
	n.name = "model"
	var aabb := measure(path)
	var s := height / maxf(aabb.size.y, 0.0001)
	n.scale *= s
	n.position.y = -aabb.position.y * s
	n.rotation.y = yaw_offset
	root.add_child(n)
	return root

## Template = list of {mesh, xf} for a static (non-skinned) model at a raw scale (the kits share units).
static func template(path: String, scale: float) -> Array:
	var key := "%s@%.3f" % [path, scale]
	if _templates.has(key): return _templates[key]
	var parts := []
	var ps := scene(path)
	if ps:
		var n: Node3D = ps.instantiate()
		var base := Transform3D(Basis().scaled(Vector3.ONE * scale), Vector3.ZERO)
		for node in n.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			if m.mesh == null: continue
			var mesh: Mesh = m.mesh
			var overrides := false
			for si in mesh.get_surface_count():
				if m.get_surface_override_material(si) != null: overrides = true
			if overrides or m.material_override != null:
				mesh = mesh.duplicate()
				for si in mesh.get_surface_count():
					var mat := m.material_override if m.material_override else m.get_surface_override_material(si)
					if mat: mesh.surface_set_material(si, mat)
			parts.append({"mesh": mesh, "xf": base * _xf_to(m, n)})
		n.free()
	_templates[key] = parts
	return parts

static func pool(path: String, scale: float, shadows := true) -> Pool:
	var key := "%s@%.3f" % [path, scale]
	if not pools.has(key):
		pools[key] = Pool.new(template(path, scale), pool_parent, shadows)
	return pools[key]

## Instantiates a model at a raw scale (static props and buildings).
static func spawn_scaled(path: String, scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = path.get_file()
	var ps := scene(path)
	if ps:
		var n: Node3D = ps.instantiate()
		n.scale *= scale
		root.add_child(n)
	return root

static func clear_pools() -> void:
	for k in pools: (pools[k] as Pool).free_all()
	pools.clear()


## Batches many copies of one static model. Slots are reused; removed instances are scaled to zero.
class Pool:
	var parts: Array
	var mmis: Array = []
	var cap := 0
	var free_slots: Array = []
	var parent: Node3D
	var shadows: bool

	func _init(p: Array, par: Node3D, sh: bool) -> void:
		parts = p; parent = par; shadows = sh
		_grow(32)

	func _grow(n: int) -> void:
		var old := mmis
		mmis = []
		for k in parts.size():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = parts[k].mesh
			mm.instance_count = n
			for i in n:
				if k < old.size() and i < cap: mm.set_instance_transform(i, (old[k] as MultiMeshInstance3D).multimesh.get_instance_transform(i))
				else: mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)
			mmis.append(mmi)
		for o in old: (o as Node).queue_free()
		for i in range(n - 1, cap - 1, -1): free_slots.append(i)
		cap = n

	func add(xf: Transform3D) -> int:
		if free_slots.is_empty(): _grow(cap * 2)
		var s: int = free_slots.pop_back()
		set_xf(s, xf)
		return s

	func set_xf(s: int, xf: Transform3D) -> void:
		for k in parts.size():
			(mmis[k] as MultiMeshInstance3D).multimesh.set_instance_transform(s, xf * parts[k].xf)

	func remove(s: int) -> void:
		for m in mmis: (m as MultiMeshInstance3D).multimesh.set_instance_transform(s, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		free_slots.append(s)

	func free_all() -> void:
		for m in mmis: (m as Node).queue_free()
		mmis.clear()


## Plays the clips that ship inside a model ("Armature|Walk" is found as "walk").
class AnimCtl:
	var ap: AnimationPlayer
	var names := {}
	var lock := 0.0
	var cur := ""
	var hold := false

	func _init(root: Node) -> void:
		ap = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for n in ap.get_animation_list():
				var short := String(n).get_slice("|", String(n).get_slice_count("|") - 1).to_lower()
				names[short] = n

	func has(n: String) -> bool:
		return names.has(n.to_lower())

	func loop(n: String, speed := 1.0) -> void:
		if ap == null or lock > 0.0 or hold: return
		var full: String = names.get(n.to_lower(), "")
		if full == "": return
		ap.speed_scale = speed
		if cur == full: return
		var a := ap.get_animation(full)
		a.loop_mode = Animation.LOOP_LINEAR
		ap.play(full, 0.18)
		cur = full

	func once(n: String, speed := 1.0, keep := false) -> float:
		if ap == null: return 0.0
		var full: String = names.get(n.to_lower(), "")
		if full == "": return 0.0
		var a := ap.get_animation(full)
		a.loop_mode = Animation.LOOP_NONE
		ap.speed_scale = speed
		ap.play(full, 0.1)
		ap.seek(0.0, true)
		cur = full
		hold = keep
		lock = a.length / maxf(speed, 0.01)
		return lock

	func release() -> void:
		hold = false; lock = 0.0; cur = ""

	func tick(dt: float) -> void:
		if lock > 0.0:
			lock -= dt
			if lock <= 0.0 and not hold: cur = ""
