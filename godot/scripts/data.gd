class_name Db
## Static game data: map, seasons, crops, items, recipes and the animal roster.

const W := 64
const H := 64
const PX := 8                     # ground texture pixels per tile
const DAY_SECONDS := 300.0        # one in-game day = 5 real minutes
const HX := 31                    # farmhouse centre tile
const HZ := 18

static func in_farm(i: int, j: int) -> bool:
	return i >= 22 and i <= 42 and j >= 12 and j <= 35

const SEASONS := [
	{"name": "Xuân", "grass": Color("6fae4a"), "grass2": Color("65a343"), "speck": Color("8cc35e"), "sky": Color("9fd8ff"), "suffix": ""},
	{"name": "Hạ",   "grass": Color("4e9a3a"), "grass2": Color("479034"), "speck": Color("6db352"), "sky": Color("86cdfb"), "suffix": ""},
	{"name": "Thu",  "grass": Color("8f8a45"), "grass2": Color("86803e"), "speck": Color("a89a50"), "sky": Color("b8d3e6"), "suffix": "_Autumn"},
	{"name": "Đông", "grass": Color("cfd8dc"), "grass2": Color("c6d0d4"), "speck": Color("e8eef0"), "sky": Color("c6d6e2"), "suffix": "_Snow"},
]

## days: growth days; model: Quaternius crop name (stages _1.._4)
const CROPS := {
	"carrot":     {"name": "Cà rốt",   "days": 3, "seed": 12, "sell": 35,  "model": "Carrot",     "food": {"h": 22, "trough": 2}},
	"lettuce":    {"name": "Xà lách",  "days": 4, "seed": 18, "sell": 55,  "model": "Lettuce",    "food": {"h": 18, "s": 4, "trough": 2}},
	"wheat":      {"name": "Lúa mì",   "days": 5, "seed": 22, "sell": 70,  "model": "Wheat",      "food": {"h": 10, "trough": 3}},
	"tomato":     {"name": "Cà chua",  "days": 5, "seed": 28, "sell": 85,  "model": "Tomato",     "food": {"h": 26, "s": 5, "trough": 2}},
	"corn":       {"name": "Ngô",      "days": 6, "seed": 35, "sell": 120, "model": "Corn",       "food": {"h": 35, "trough": 3}},
	"pumpkin":    {"name": "Bí ngô",   "days": 7, "seed": 55, "sell": 190, "model": "Pumpkin",    "food": {"h": 55, "hp": 12, "s": 8, "trough": 4}},
	"watermelon": {"name": "Dưa hấu",  "days": 9, "seed": 80, "sell": 300, "model": "Watermelon", "food": {"h": 45, "hp": 20, "s": 12, "trough": 4}},
}

const BASE_ITEMS := {
	"wood": "Gỗ", "stone": "Đá", "fiber": "Sợi cỏ", "berry": "Quả mọng", "rope": "Dây thừng", "rope2": "Dây thừng len",
	"torch": "Đuốc", "campfire": "Bộ lửa trại", "egg": "Trứng", "milk": "Sữa", "wool": "Len", "truffle": "Nấm truffle",
}
const BASE_SELL := {"wood": 2, "stone": 3, "fiber": 1, "berry": 6, "milk": 40, "wool": 30, "truffle": 120, "egg": 20}
const BASE_FOOD := {
	"berry": {"h": 12, "trough": 1}, "milk": {"h": 18, "s": 6, "trough": 2}, "truffle": {"h": 10, "hp": 5, "s": 15, "trough": 3},
	"egg": {"h": 15, "trough": 2}, "fiber": {"h": 0, "trough": 1},
}

static func item_names() -> Dictionary:
	var d := BASE_ITEMS.duplicate()
	for k in CROPS:
		d["seed_" + k] = "Hạt " + String(CROPS[k].name).to_lower()
		d[k] = CROPS[k].name
	return d

static func sell_prices() -> Dictionary:
	var d := BASE_SELL.duplicate()
	for k in CROPS: d[k] = CROPS[k].sell
	return d

static func food_values() -> Dictionary:
	var d := BASE_FOOD.duplicate()
	for k in CROPS: d[k] = CROPS[k].food
	return d

static func foods() -> Array:
	var a := ["berry", "milk", "egg", "truffle"]
	for k in CROPS: a.append(k)
	return a

const RECIPES := [
	{"id": "axe", "name": "Rìu", "tool": true, "need": {"wood": 2, "fiber": 3}, "desc": "Chặt cây nhanh: 3 nhát, được 3 gỗ."},
	{"id": "pickaxe", "name": "Rìu đá", "tool": true, "need": {"wood": 3, "fiber": 2}, "desc": "Đập đá lấy đá."},
	{"id": "rope", "name": "Dây thừng", "give": 1, "need": {"fiber": 3}, "desc": "Quăng vào thú hoang để thuần hóa. Chịu được 3 lần thú vùng."},
	{"id": "rope2", "name": "Dây thừng len", "give": 1, "need": {"wool": 2, "rope": 1}, "desc": "Dây chắc, chịu 5 lần vùng. Cần cho thú lớn và rồng."},
	{"id": "torch", "name": "Đuốc", "give": 2, "need": {"wood": 1, "fiber": 1}, "desc": "Cầm trên tay để có ánh sáng ban đêm. Mỗi cây cháy 90 giây."},
	{"id": "campfire", "name": "Bộ lửa trại", "give": 1, "need": {"wood": 3, "stone": 3}, "desc": "Đặt xuống đất. Ánh lửa xua bóng tối."},
]

## size: 0 small, 1 medium, 2 big, 3 huge. height: metres. ride: riding speed (0 = cannot ride).
## anim: names of clips in the model (matched by suffix). hop: moves by looping Jump (model has no walk).
const ANIMALS := {
	"cho":     {"name": "Chó",        "model": "animals/Dog",       "height": 0.85, "yaw": -PI / 2, "size": 1, "job": "guard",   "diet": ["egg", "milk", "berry"], "habitat": "any",    "walk": "Walking", "text": "Gác đêm: đuổi quái vật, bảo vệ đàn thú."},
	"meo":     {"name": "Mèo",        "model": "animals/Cat",       "height": 0.5, "yaw": -PI / 2, "size": 0, "job": "comfort", "diet": ["milk", "berry"],        "habitat": "meadow", "walk": "Walking", "text": "Âu yếm: đi theo bạn thì tinh thần giảm chậm hơn."},
	"pug":     {"name": "Chó pug",    "model": "animals/Pug",       "height": 0.45, "size": 0, "job": "forage",  "diet": ["berry", "carrot"],      "habitat": "meadow", "hop": true,      "text": "Đánh hơi: mỗi sáng tìm được vài hạt giống."},
	"bo":      {"name": "Bò",         "model": "animals/Cow",       "height": 1.45, "size": 1, "job": "milk",    "diet": ["fiber", "carrot", "wheat", "corn"], "habitat": "meadow", "walk": "WalkSlow", "run": "Run", "text": "Cho 1 bình sữa mỗi sáng."},
	"cuu":     {"name": "Cừu",        "model": "animals/Sheep",     "height": 1.0,  "size": 1, "job": "wool",    "diet": ["fiber", "wheat", "lettuce"], "habitat": "meadow", "hop": true, "text": "Cho 1 cuộn len mỗi sáng (làm dây thừng len)."},
	"heo":     {"name": "Heo",        "model": "animals/Pig",       "height": 0.85, "size": 1, "job": "truffle", "diet": ["carrot", "pumpkin", "berry", "lettuce"], "habitat": "forest", "hop": true, "text": "Ủi đất: một nửa số ngày tìm được nấm truffle."},
	"slime":   {"name": "Slime nước", "model": "monsters/Slime",    "height": 0.6,  "size": 0, "job": "water",   "amount": 12, "diet": ["lettuce", "berry"], "habitat": "water", "walk": "Slime_Walk", "idle": "Slime_Idle", "text": "Tưới 12 ô đất mỗi sáng."},
	"daibang": {"name": "Đại bàng",   "model": "animals/Eagle",     "height": 0.9, "yaw": PI, "size": 1, "job": "fruit",   "amount": 3, "diet": ["berry", "corn"],   "habitat": "rocky",  "walk": "Flying", "fly": true, "skittish": true, "text": "Hái 3 quả mọng trên cao mỗi sáng."},
	"lacda":   {"name": "Lạc đà",     "model": "animals/Llama",     "height": 1.7,  "size": 2, "job": "carry",   "ride": 7.0, "diet": ["fiber", "lettuce", "wheat"], "habitat": "rocky", "hop": true, "text": "Cưỡi được. Chở hàng: bán ở thùng hàng được thêm 15%."},
	"ngua":    {"name": "Ngựa",       "model": "animals/Horse",     "height": 1.9,  "size": 2, "job": "none",    "ride": 10.0, "diet": ["carrot", "wheat", "fiber"], "habitat": "meadow", "walk": "Walk", "run": "Run", "text": "Cưỡi được, chạy nhanh."},
	"nguavan": {"name": "Ngựa vằn",   "model": "animals/Zebra",     "height": 1.85, "size": 2, "job": "none",    "ride": 11.5, "diet": ["fiber", "wheat"], "habitat": "meadow", "walk": "Walk", "run": "Run", "skittish": true, "weight": 0.5, "text": "Cưỡi được, nhanh nhất. Rất nhát, phải cho ăn trước."},
	"soi":     {"name": "Sói",        "model": "animals/Wolf",      "height": 1.1, "yaw": -PI / 2, "size": 2, "job": "guard",   "ride": 9.0, "aggressive": true, "diet": ["egg", "milk"], "habitat": "forest", "walk": "Walking", "weight": 0.6, "text": "Cưỡi được, gác đêm. Hoang dã thì hung dữ."},
	"rong":    {"name": "Rồng",       "model": "monsters/Dragon",   "height": 2.6,  "size": 3, "job": "dragon",  "ride": 12.5, "aggressive": true, "diet": ["pumpkin", "watermelon", "milk"], "habitat": "far", "walk": "Dragon_Flying", "idle": "Dragon_Flying", "attack": "Dragon_Attack", "weight": 0.12, "text": "Cưỡi được. Tỏa sáng ban đêm và gác nông trại. Cần dây thừng len."},
	"doi":     {"name": "Dơi",        "model": "monsters/Bat",      "height": 0.7,  "size": 0, "hostile": true, "night": true, "fly": true, "diet": [], "habitat": "any", "walk": "Bat_Flying", "idle": "Bat_Flying", "attack": "Bat_Attack", "text": "Quái vật bóng đêm."},
	"xuong":   {"name": "Bộ xương",   "model": "monsters/Skeleton", "height": 1.7,  "size": 1, "hostile": true, "night": true, "diet": [], "habitat": "any", "walk": "Skeleton_Running", "idle": "Skeleton_Idle", "attack": "Skeleton_Attack", "text": "Quái vật bóng đêm."},
}

const JOB_NAMES := {"guard": "Gác đêm", "comfort": "Âu yếm", "forage": "Đánh hơi", "milk": "Vắt sữa", "wool": "Cho len", "truffle": "Tìm nấm",
	"water": "Tưới cây", "fruit": "Hái quả", "carry": "Chở hàng", "none": "Thú cưỡi", "dragon": "Rồng"}

const HOTBAR := [
	{"id": "hand", "name": "Tay"}, {"id": "hoe", "name": "Cuốc"}, {"id": "can", "name": "Bình tưới"}, {"id": "axe", "name": "Rìu"},
	{"id": "pickaxe", "name": "Rìu đá"}, {"id": "seeds", "name": "Hạt giống"}, {"id": "food", "name": "Thức ăn"}, {"id": "rope", "name": "Dây thừng"},
	{"id": "torch", "name": "Đuốc"}, {"id": "campfire", "name": "Lửa trại"},
]
