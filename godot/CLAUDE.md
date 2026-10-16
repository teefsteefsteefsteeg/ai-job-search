# Nông Trại Hoang Dã — bàn giao dự án (Godot 4.7)

Tài liệu này tóm tắt toàn bộ quá trình làm game, để tiếp tục ở máy local. Claude Code tự đọc file này khi mở thư mục `godot/`.

## Người dùng muốn gì

- Game 3D nông trại, giao tiếp bằng tiếng Việt, kết hợp ba chất:
  - **Harvest Moon**: trồng trọt, mùa vụ, bán nông sản.
  - **Don't Starve**: đói, tinh thần, bóng tối giết người, lửa trại, chế tạo.
  - Phần sinh vật **ban đầu giống Pokémon, nhưng người dùng đã yêu cầu bỏ** đánh theo lượt và cầu bắt. Thay bằng:
    - **Dây thừng** quăng vào thú hoang để thuần hóa.
    - **Thú phụ việc** cho nông trại.
    - **Thú to cưỡi được**.
- **Có màn hình tạo nhân vật** ở đầu game: tên nhân vật, tên nông trại, tên chú chó, chọn ngoại hình.
- Ưu tiên **miễn phí**: model CC0, không dùng dịch vụ AI tốn phí.
- Engine: người dùng đã thử bản web (Three.js), rồi chọn **Godot**. Unity đã bỏ.

## Lịch sử quyết định

1. **Bản web Three.js** (`../game/index.html`) với model Kenney: vẫn còn trong repo và chơi được, nhưng không phát triển tiếp.
2. **Unity port**: bỏ, vì không chạy được Unity Editor trong môi trường cloud (cần license và giao diện). Code đã xóa khỏi nhánh, còn trong lịch sử git.
3. **Kie.ai**: người dùng hỏi, nhưng Kie.ai không có model tạo 3D (chỉ ảnh, video, nhạc) và tốn phí, nên không dùng.
4. **Quaternius (CC0)** được chọn làm nguồn model. Google Drive chặn tải tự động, nên tải các bộ từ **OpenGameArt**.
5. **Godot 4.7.2**: GDScript, toàn bộ thế giới và giao diện dựng bằng code từ `main.tscn`.
6. Bản web Godot **không publish thành link** được: file `.wasm` khoảng 40 MB, vượt giới hạn 15 MB mỗi file của Artifact. Người dùng chạy bằng Godot trên máy.

## Cấu trúc code

| File | Nội dung |
|---|---|
| `scripts/data.gd` (`class_name Db`) | Hằng số bản đồ, mùa, cây trồng, vật phẩm, công thức, **ANIMALS** (nghề, món thích ăn, tốc độ cưỡi, tên clip animation, `yaw` sửa hướng model), **CHARACTERS** (19 ngoại hình), HOTBAR |
| `scripts/models.gd` (`class_name Models`) | Nạp FBX, đo chiều cao theo xương (`measure`) để chuẩn hóa, `spawn(path, height, yaw)` cho thú và người, `spawn_scaled(path, scale)` cho đồ vật, `Pool` (MultiMesh cho cảnh vật), `AnimCtl` (loop/once/hold, chống đổi clip quá nhanh) |
| `scripts/world.gd` (`class_name World`) | Lưới 64×64 ô, texture mặt đất vẽ từng pixel, mặt nước, sinh cây/đá/cỏ, nhà cửa, cây trồng, va chạm (`can_stand`) |
| `scripts/main.gd` | Vòng lặp game: nhân vật, AI thú, thuần hóa bằng dây, cưỡi, hành động công cụ, sinh tồn, ngày đêm, bầu trời, qua ngày (`new_day`: thú làm việc, cây lớn, mọc lại), lưu/nạp JSON, tạo nhân vật (`apply_character`, `set_player_model`) |
| `scripts/ui.gd` (`class_name GameUI`) | HUD, thanh công cụ, thanh ghì dây, các bảng (túi, chế tạo, cửa hàng, thùng hàng, chuồng thú, menu, tạo nhân vật có xem trước 3D bằng SubViewport) |
| `tools/logic_test.gd` | Test không cần đồ họa, 25 mục. Lệnh: `godot --headless --fixed-fps 60 --path . -s tools/logic_test.gd` |
| `tools/play_test.gd`, `tools/creator_shot.gd` | Chạy kịch bản và chụp ảnh màn hình (cần màn hình thật hoặc Xvfb) |

Thú được lưu dạng **Dictionary** (không phải Node): `id, def, node, anim, pos, yaw, state (wild|follow|farm|ridden|tied), trust, happy, unfed, fed, rest, spd, nick, ...`. Đồ vật trong thế giới cũng là Dictionary: `kind, i, j, v, hp, berries, regrow, fuel, pool/slot/base` hoặc `node`.

## Luật chơi hiện tại

- **Trồng trọt:**
  - Cuốc đất, gieo hạt, tưới nước. Cây lớn qua đêm nếu đất ẩm. Khô 3 ngày thì héo.
  - Mùa đông cây không lớn. Mưa tự tưới.
  - Có 7 loại cây: cà rốt, xà lách, lúa mì, cà chua, ngô, bí ngô, dưa hấu.
- **Tài nguyên và chế tạo:**
  - Nhổ cỏ được sợi cỏ. Nhặt khúc gỗ, đá cuội.
  - Chặt cây (bằng tay hoặc rìu), cây chặt xong còn gốc. Đập đá cần rìu đá.
  - Chế tạo: rìu, rìu đá, dây thừng (3 sợi cỏ), dây thừng len (2 len + 1 dây), đuốc, lửa trại.
- **Thuần hóa bằng dây:**
  - Thanh có kim chạy qua lại. Bấm khi kim nằm trong vùng xanh để ghì. Trượt thì dây yếu dần, hết sức thì đứt.
  - Thú càng to thì vùng xanh càng hẹp và cần ghì nhiều lần hơn.
  - Cho thú hoang ăn món nó thích sẽ tăng độ quen, làm vùng xanh rộng hơn.
  - Rồng bắt buộc dùng dây thừng len.
- **Thú phụ việc:** mỗi sáng thú ăn từ máng ở chuồng (hoặc đã được cho ăn tận tay) rồi làm việc:
  - Bò cho sữa, cừu cho len, heo tìm nấm truffle, chó pug tìm hạt giống.
  - Slime tưới 12 ô, đại bàng hái quả, lạc đà tăng giá bán 15%.
  - Chó, sói, rồng gác đêm. Mèo giảm tốc độ mất tinh thần.
  - Đói 3 ngày liền thì thú bỏ đi. Đêm không có thú gác hoặc lửa trại trong nông trại thì có thể mất một con thú nhỏ.
- **Cưỡi:** ngựa, ngựa vằn, lạc đà, sói, rồng. Bấm F để lên hoặc xuống.
- **Sinh tồn:**
  - Có ba chỉ số: máu, no bụng, tinh thần.
  - Đứng trong bóng tối quá 5 giây sẽ bị cào. Ánh sáng đến từ ban ngày, lửa trại, đuốc (khi đang chọn đuốc), hoặc rồng đã thuần.
  - Ban đêm có dơi và bộ xương. Đuổi 3 lần thì chúng biến mất.
  - Ngất thì mất 30% tiền và tỉnh dậy ở nhà.
- **Bắt đầu game:** tạo nhân vật, có sẵn chú chó (mặc định tên Mực), 2 dây thừng, 1 đuốc, 6 hạt cà rốt, 150 G.

## Asset (đều CC0 trừ font)

- `assets/animals`: Cow, Horse, Llama, Pig, Pug, Sheep, Zebra (bộ Farm Animals); Cat, Dog, Wolf, Eagle (bộ Animal Pack Vol.2).
- `assets/monsters`: Bat, Dragon, Skeleton, Slime.
- `assets/chars`: 22 nhân vật thuộc bộ Ultimate Animated Character. Tất cả dùng chung bộ xương và clip: Idle, Walk, PickUp, Punch, Shoot_OneHanded, SitDown, Victory, Defeat, RecieveHit…
- `assets/nature`: cây và đá có bản `_Autumn` / `_Snow`, gốc cây, khúc gỗ, cỏ, hoa (bộ Ultimate Nature).
- `assets/crops`: cây trồng giai đoạn `_1`…`_4`, bụi quả mọng `_4` (có quả) và `_Harvested` (đã hái).
- `assets/village`: House_1, MarketStand_1, Well, Stable, Crate, Fence, Hay, Barrel, Cart, Bonfire(_Lit).
- `assets/survival`: Axe, Axe_Small, Shovel, WoodenTorch_Fire.
- `assets/fonts`: Be Vietnam Pro, Baloo 2 (SIL OFL), có đủ dấu tiếng Việt.
- Nguồn tải: trang OpenGameArt của Quaternius, ví dụ `opengameart.org/content/lowpoly-animated-farm-animal-pack`. Bộ *Ultimate Animated Animals* (hươu, bò tót, cáo, alpaca…) chỉ có trên Google Drive. Ở máy local có thể tải tay về nếu muốn thêm thú.

## Những điểm dễ sai (đã gặp và đã xử lý)

- **Hướng model:** Dog, Cat, Wolf quay mặt về +x, nên cần `yaw = -PI/2`. Eagle quay về −z, cần `yaw = PI`. Các model khác quay về +z.
- **Model Quaternius không cùng tỉ lệ.** Thú và người chuẩn hóa theo chiều cao đo được từ xương (`Models.measure`). Đồ vật dùng hệ số scale tay.
- **Xương FBX dùng đơn vị centimet:** đồ cầm tay gắn vào `BoneAttachment3D` phải chia cho scale của xương, nếu không sẽ to khổng lồ (`set_player_model`, `holder.scale`).
- **Các thú cùng loại dùng chung tài nguyên `Animation`.** `loop_mode` đổi ở một con là đổi cho tất cả. Đừng gọi `once()` với clip mà con khác đang loop. Các thú dùng nhảy làm bước đi (`hop`: Pig, Sheep, Llama, Pug) loop clip `Jump`.
- **Lỗi đơ chân:** do đổi idle/walk/run mỗi khung hình. Đã thêm `AnimCtl.switch_t` (giữ clip 0,3 giây), cho thú lách vật cản, đứng nghỉ có ngưỡng (`rest`), và chọn clip theo tốc độ thật (`spd`).
- **GDScript:**
  - `var x := dict.key` báo lỗi "Cannot infer type". Dùng `var x: Type = …` hoặc `var x = …`.
  - Đọc khóa Dictionary chưa tồn tại bằng dấu chấm sẽ lỗi lúc chạy. Dùng `.get("k", default)` hoặc khởi tạo khóa trong `make_animal`.
  - Lambda nhiều lệnh viết trên một dòng bên trong dictionary hoặc tham số hàm hay parse sai. Dùng hàm riêng kèm `.bind(...)`.
  - Không dùng Dictionary làm khóa của Dictionary khác, vì hash thay đổi khi nội dung đổi. Ví dụ `occluded` dùng chỉ số ô làm khóa.
- **Bố cục giao diện:** anchor của Control dưới CanvasLayer từng bị lệch, nên `GameUI._layout()` đặt vị trí thủ công mỗi khung hình.
- **Cây che nhân vật:** `update_occluders()` tạm thu nhỏ các cây nằm giữa camera và người chơi.
- **Renderer:** dự án mặc định Forward+. Trên cloud chỉ test được bằng `--rendering-method gl_compatibility` (llvmpipe), nên **chưa kiểm tra Forward+ trên GPU thật**. Nếu thấy lỗi hiển thị (SSAO, glow, sương mù), kiểm tra ở `_setup_env()` và `update_sky()` trong main.gd.

## Kiểm tra trước khi commit

```sh
cd godot
godot --headless --path . --import                        # sau khi thêm asset hoặc script có class_name
godot --headless --path . --check-only --script res://scripts/main.gd   # kiểm tra cú pháp từng file
godot --headless --fixed-fps 60 --path . -s tools/logic_test.gd         # phải in ra 25 dòng PASS và DONE
```

`--fixed-fps 60` cần thiết để mô phỏng đúng thời gian, vì khi chạy không đồ họa mỗi khung hình trôi rất nhanh.

## Việc còn mở / gợi ý làm tiếp

- Người dùng báo ngựa bị đơ chân. Đã sửa theo giả thuyết, nhưng **chưa xác nhận trên máy người dùng**. Hỏi lại xem lỗi xảy ra khi cưỡi, khi ngựa đi theo, hay với ngựa hoang.
- Kiểm tra đồ họa Forward+ trên GPU thật. Có thể chỉnh mức sáng, sương mù, SSAO.
- Ý tưởng người dùng có thể thích: tiến hóa hoặc nâng cấp thú, chuồng gà và trứng (cần model gà), câu cá, hang động hoặc boss, nhạc và âm thanh (chưa có âm thanh nào), xuất bản Windows (.exe).
- Model Quaternius thiếu gà, hươu, gấu. Bộ Ultimate Animated Animals trên Drive có hươu, cáo, alpaca, bò tót.
- `world.gd` hiện sinh rừng với mật độ 0.11 trong vùng rừng. Thử nghiệm trước đó với 0.24 thì quá dày, che hết nhân vật.

## Repo và git

- Repo: `teefsteefsteefsteeg/ai-job-search` (vốn là repo tìm việc, game nằm trong `godot/` và `game/`). Nhánh làm việc: `claude/fervent-turing-6c6wrx`.
- Commit message viết bằng tiếng Anh, theo dạng "Godot: …", kèm danh sách thay đổi.
- `CLAUDE.md` ở gốc repo là của công cụ tìm việc, không liên quan đến game.
