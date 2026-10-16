using System.Collections.Generic;
using UnityEngine;

namespace NongTrai
{
    public class CropDef
    {
        public string id, name, model; public int days, seed, sell; public string[] stages; public FoodVal food;
    }
    public class FoodVal { public float hunger, hp, sanity; public int trough; public FoodVal(float h, float hp = 0, float s = 0, int trough = 1) { hunger = h; this.hp = hp; sanity = s; this.trough = trough; } }
    public class Recipe { public string id, name, desc; public Dictionary<string, int> need; public int give = 1; public bool tool; }
    public class SeasonDef { public string name; public Color grass, grass2, speck, leafTint, sky; public float leafAmt; }

    public enum Size { Small, Medium, Big }
    public enum Job { None, Fiber, Egg, Milk, Truffle, Guard, Lumber, Pollinate, Harvest, Water, Warm, Fruit }
    public enum Habitat { Meadow, Forest, Water, Rocky, Any }

    public class AnimalDef
    {
        public string id, name, model, jobText;
        public Size size; public Job job; public int jobAmount;
        public string[] diet; public float rideSpeed, walkSpeed = 1.3f, height;
        public bool aggressive, hostile, nightOnly; public Habitat habitat; public float weight = 1f;
        public bool Rideable => rideSpeed > 0f;
    }

    public static class Db
    {
        public const int W = 64, H = 64;
        public const float DaySeconds = 300f;          // one in-game day = 5 real minutes
        public const int HX = 31, HZ = 18;             // house centre tile
        public static bool InFarm(int i, int j) => i >= 23 && i <= 41 && j >= 13 && j <= 34;

        public static readonly SeasonDef[] Seasons =
        {
            new SeasonDef { name = "Xuân", grass = C(0x6fae4a), grass2 = C(0x65a343), speck = C(0x8cc35e), leafTint = C(0x5aa83f), leafAmt = .42f, sky = C(0x9fd8ff) },
            new SeasonDef { name = "Hạ",   grass = C(0x4e9a3a), grass2 = C(0x479034), speck = C(0x6db352), leafTint = C(0x3f8a2e), leafAmt = .42f, sky = C(0x86cdfb) },
            new SeasonDef { name = "Thu",  grass = C(0xa49a48), grass2 = C(0x9a8e3f), speck = C(0xc2b05a), leafTint = C(0xd08a3a), leafAmt = .0f,  sky = C(0xb8d3e6) },
            new SeasonDef { name = "Đông", grass = C(0xdfe7ea), grass2 = C(0xd4dee2), speck = C(0xffffff), leafTint = C(0xf2f6f8), leafAmt = .8f,  sky = C(0xc6d6e2) },
        };

        public static readonly CropDef[] Crops =
        {
            new CropDef { id = "carrot",  name = "Cà rốt",  days = 3, seed = 12, sell = 35,  model = "crop_carrot",  food = new FoodVal(22, 0, 0, 2) },
            new CropDef { id = "turnip",  name = "Củ cải",  days = 4, seed = 20, sell = 60,  model = "crop_turnip",  food = new FoodVal(24, 0, 4, 2) },
            new CropDef { id = "corn",    name = "Ngô",     days = 6, seed = 35, sell = 120, stages = new[] { "crops_cornStageA", "crops_cornStageC", "crops_cornStageD" }, food = new FoodVal(35, 0, 0, 3) },
            new CropDef { id = "pumpkin", name = "Bí ngô",  days = 7, seed = 55, sell = 190, model = "crop_pumpkin", food = new FoodVal(55, 12, 8, 4) },
            new CropDef { id = "melon",   name = "Dưa hấu", days = 9, seed = 80, sell = 300, model = "crop_melon",   food = new FoodVal(45, 20, 12, 4) },
        };
        public static CropDef Crop(string id) { foreach (var c in Crops) if (c.id == id) return c; return Crops[0]; }

        public static readonly Dictionary<string, string> ItemNames = new Dictionary<string, string>
        {
            { "wood", "Gỗ" }, { "stone", "Đá" }, { "fiber", "Sợi cỏ" }, { "berry", "Quả mọng" }, { "rope", "Dây thừng" },
            { "campfire", "Bộ lửa trại" }, { "egg", "Trứng" }, { "milk", "Sữa" }, { "truffle", "Nấm truffle" },
        };
        public static readonly Dictionary<string, int> Sell = new Dictionary<string, int>
        {
            { "wood", 2 }, { "stone", 3 }, { "fiber", 1 }, { "berry", 6 }, { "egg", 25 }, { "milk", 40 }, { "truffle", 120 },
        };
        public static readonly Dictionary<string, FoodVal> Food = new Dictionary<string, FoodVal>
        {
            { "berry", new FoodVal(12, 0, 0, 1) }, { "egg", new FoodVal(15, 0, 0, 2) }, { "milk", new FoodVal(18, 0, 6, 2) }, { "truffle", new FoodVal(10, 5, 15, 3) },
            { "fiber", new FoodVal(0, 0, 0, 1) },   // only animals eat grass
        };
        public static readonly List<string> Foods = new List<string> { "berry", "egg", "milk", "truffle" };

        static Db()
        {
            foreach (var c in Crops)
            {
                ItemNames["seed_" + c.id] = "Hạt " + c.name.ToLowerInvariant();
                ItemNames[c.id] = c.name; Sell[c.id] = c.sell; Food[c.id] = c.food; Foods.Add(c.id);
            }
        }
        public static string Name(string item) => ItemNames.TryGetValue(item, out var n) ? n : item;

        public static readonly Recipe[] Recipes =
        {
            new Recipe { id = "axe", name = "Rìu", tool = true, need = new Dictionary<string, int> { { "wood", 2 }, { "fiber", 3 } }, desc = "Chặt cây nhanh: 3 nhát, được 3 gỗ." },
            new Recipe { id = "pickaxe", name = "Cuốc chim", tool = true, need = new Dictionary<string, int> { { "wood", 3 }, { "fiber", 2 } }, desc = "Đập đá để lấy đá." },
            new Recipe { id = "rope", name = "Dây thừng", need = new Dictionary<string, int> { { "fiber", 3 } }, desc = "Quăng vào thú hoang để thuần hóa. Đứt nếu thú vùng thoát." },
            new Recipe { id = "campfire", name = "Bộ lửa trại", need = new Dictionary<string, int> { { "wood", 3 }, { "stone", 3 } }, desc = "Ánh lửa giữ bạn an toàn khỏi bóng tối." },
        };

        // Kenney "Cube Pets" models. height = normalised model height in metres.
        public static readonly AnimalDef[] Animals =
        {
            new AnimalDef { id = "tho",   name = "Thỏ",           model = "animal-bunny",    size = Size.Small,  height = .75f, job = Job.Fiber,     jobAmount = 4,  diet = new[] { "berry", "carrot" },          habitat = Habitat.Meadow, jobText = "Nhổ cỏ: mỗi sáng mang về vài sợi cỏ." },
            new AnimalDef { id = "ga",    name = "Gà con",        model = "animal-chick",    size = Size.Small,  height = .55f, job = Job.Egg,       jobAmount = 1,  diet = new[] { "berry", "corn", "fiber" },   habitat = Habitat.Meadow, jobText = "Đẻ 1 quả trứng mỗi sáng." },
            new AnimalDef { id = "bo",    name = "Bò",            model = "animal-cow",      size = Size.Medium, height = 1.0f, job = Job.Milk,      jobAmount = 1,  diet = new[] { "fiber", "turnip", "carrot" }, habitat = Habitat.Meadow, jobText = "Cho 1 bình sữa mỗi sáng." },
            new AnimalDef { id = "heo",   name = "Heo",           model = "animal-pig",      size = Size.Medium, height = .85f, job = Job.Truffle,   jobAmount = 1,  diet = new[] { "carrot", "pumpkin", "berry" }, habitat = Habitat.Forest, jobText = "Ủi đất: một nửa số ngày tìm được nấm truffle." },
            new AnimalDef { id = "cho",   name = "Chó",           model = "animal-dog",      size = Size.Medium, height = .85f, job = Job.Guard,     jobAmount = 1,  diet = new[] { "egg", "milk", "berry" },     habitat = Habitat.Any,    jobText = "Gác đêm: đuổi bóng đêm, bảo vệ đàn thú." },
            new AnimalDef { id = "haily", name = "Hải ly",        model = "animal-beaver",   size = Size.Small,  height = .7f,  job = Job.Lumber,    jobAmount = 3,  diet = new[] { "berry", "carrot" },          habitat = Habitat.Water,  jobText = "Gặm cây: mỗi sáng mang về 2–4 gỗ." },
            new AnimalDef { id = "ong",   name = "Ong",           model = "animal-bee",      size = Size.Small,  height = .6f,  job = Job.Pollinate, jobAmount = 1,  diet = new[] { "berry" },                    habitat = Habitat.Meadow, jobText = "Thụ phấn: cây trồng có cơ hội lớn nhanh thêm một ngày." },
            new AnimalDef { id = "khi",   name = "Khỉ",           model = "animal-monkey",   size = Size.Medium, height = .9f,  job = Job.Harvest,   jobAmount = 10, diet = new[] { "berry", "melon" },           habitat = Habitat.Forest, jobText = "Tự thu hoạch tới 10 cây chín mỗi sáng." },
            new AnimalDef { id = "canhcut", name = "Cánh cụt",    model = "animal-penguin",  size = Size.Small,  height = .7f,  job = Job.Water,     jobAmount = 12, diet = new[] { "berry", "turnip" },          habitat = Habitat.Water,  jobText = "Tưới 12 ô đất mỗi sáng." },
            new AnimalDef { id = "huou",  name = "Hươu",          model = "animal-deer",     size = Size.Big,    height = 1.35f, job = Job.None,     rideSpeed = 9.5f, diet = new[] { "berry", "carrot" },     habitat = Habitat.Forest, jobText = "Cưỡi được, chạy rất nhanh." },
            new AnimalDef { id = "voi",   name = "Voi",           model = "animal-elephant", size = Size.Big,    height = 1.5f, job = Job.Water,     jobAmount = 30, rideSpeed = 6.5f, diet = new[] { "pumpkin", "melon", "fiber" }, habitat = Habitat.Rocky, jobText = "Cưỡi được. Phun nước tưới 30 ô đất mỗi sáng." },
            new AnimalDef { id = "gau",   name = "Gấu băng",      model = "animal-polar",    size = Size.Big,    height = 1.35f, job = Job.Warm,     rideSpeed = 7.5f, diet = new[] { "egg", "milk" },        habitat = Habitat.Water,  jobText = "Cưỡi được. Giữ ấm: mùa đông không đói nhanh." },
            new AnimalDef { id = "caoco", name = "Hươu cao cổ",   model = "animal-giraffe",  size = Size.Big,    height = 1.9f, job = Job.Fruit,     jobAmount = 3, rideSpeed = 8f, diet = new[] { "berry", "melon" }, habitat = Habitat.Meadow, weight = .4f, jobText = "Cưỡi được. Hái 3 quả mọng trên cao mỗi sáng." },
            new AnimalDef { id = "sutu",  name = "Sư tử",         model = "animal-lion",     size = Size.Big,    height = 1.35f, job = Job.Guard,    rideSpeed = 9f, aggressive = true, diet = new[] { "egg", "milk" }, habitat = Habitat.Rocky, weight = .5f, jobText = "Cưỡi được. Gác đêm cực mạnh. Hoang dã thì rất hung dữ." },
            new AnimalDef { id = "ho",    name = "Hổ",            model = "animal-tiger",    size = Size.Big,    height = 1.35f, job = Job.Guard,    rideSpeed = 10.5f, aggressive = true, diet = new[] { "egg", "milk" }, habitat = Habitat.Forest, weight = .4f, jobText = "Cưỡi được, nhanh nhất. Hoang dã thì rất hung dữ." },
            new AnimalDef { id = "bongdem", name = "Bóng Đêm",    model = "animal-cat",      size = Size.Medium, height = .9f, hostile = true, nightOnly = true, walkSpeed = 2.4f, diet = new string[0], habitat = Habitat.Any, jobText = "Sinh vật của bóng tối. Không thể thuần hóa." },
        };
        public static AnimalDef Animal(string id) { foreach (var a in Animals) if (a.id == id) return a; return Animals[0]; }

        public static readonly string[] HotbarIds = { "hand", "hoe", "can", "axe", "pickaxe", "seeds", "food", "rope", "campfire" };
        public static readonly string[] HotbarNames = { "Tay", "Cuốc", "Bình tưới", "Rìu", "Cuốc chim", "Hạt giống", "Thức ăn", "Dây thừng", "Lửa trại" };

        public static Color C(int hex) => new Color(((hex >> 16) & 255) / 255f, ((hex >> 8) & 255) / 255f, (hex & 255) / 255f, 1f);
    }
}
