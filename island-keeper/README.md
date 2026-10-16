# Island Keeper (working title)

Game sinh tồn / giữ đảo 2D phong cách Don't Starve, làm bằng Unity.

## Pipeline art

1. **Tạo ảnh**: `Tools/art/openrouter_gen.py` gọi OpenRouter (`OPENROUTER_API_KEY`), model mặc định
   `google/gemini-3-pro-image-preview`, luôn vẽ trên nền chroma magenta `#FF00FF`.
   Hỗ trợ `--ref` (ảnh tham chiếu giữ đúng thiết kế) và `--aspect` (vd. `2:3`).
2. **Tách nền / cắt sheet**: [aldegad/sprite-gen](https://github.com/aldegad/sprite-gen)
   - `sprite-gen cutout <img> --key magenta --decontam auto` → PNG trong suốt
   - `sprite-gen slice-sheet --sheet <sheet> --chroma-key magenta --grid 3x1` → từng view
   - Về sau: `prepare` / `extract` / `compose-atlas` cho atlas animation + `manifest.json`.
3. Tham khảo thêm luồng "một still được duyệt → cả bộ animation" của
   [0x0funky/agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge).

## Trạng thái

- [ ] Nhân vật chính "The Keeper" - chờ duyệt: `ArtSource/characters/keeper/review_board.png`
- [x] Web playtest `Prototype/web/` (canvas, đọc atlas + manifest): đi 4 hướng, tấn công, nhặt, đêm có đèn lồng
- [ ] Unity project (URP 2D), di chuyển 8 hướng, camera kiểu Don't Starve
- [x] Sprite set v1 (`ArtSource/characters/keeper/sprites/`): idle + walk cho 3 hướng (down/side/up, left = mirror side), gather, attack.
  Atlas `sprite-sheet-alpha.png` + `manifest.json`, preview `preview_all.gif`, QA `qa-notes.md`.
