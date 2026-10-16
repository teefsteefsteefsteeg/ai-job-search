# Hòn Gió (tên tạm) - thiết kế game

Game nông trại đời sống trên một hòn đảo làng chài, pixel art 16-bit, Unity 2D.
Thể loại và cơ chế (trồng trọt, mùa vụ, kết bạn) là của chung thể loại; tên, nhân vật,
bối cảnh, hình ảnh và âm nhạc đều tự làm, không dùng gì của các series có sẵn.

## Ý tưởng
Bạn nhận lại mảnh vườn bỏ hoang của ông nội trên Hòn Gió, một đảo nhỏ có làng chài,
chợ phiên và ngọn hải đăng. Mỗi ngày trồng trọt, đánh bắt, đổi chác với dân làng,
và làm đảo đông vui trở lại qua bốn mùa.

## Vòng chơi một ngày
1. 6:00 thức dậy trong nhà (giường = lưu game).
2. Làm vườn, câu cá, hái lượm. Mỗi việc tốn **thể lực**.
3. Gặp dân làng: trò chuyện, tặng quà, nhận việc đổi đồ.
4. Bán hàng, mua hạt giống, đổi đồ.
5. Về nhà ngủ trước 2:00. Thức quá giờ sẽ ngất, sáng ra mất tiền và mệt.

## Hệ thống
| Hệ thống | Nội dung |
|---|---|
| Thời gian | 1 ngày game khoảng 14 phút thật, 28 ngày/mùa, 4 mùa/năm |
| Thể lực | Giảm khi dùng công cụ; ngủ thì hồi; ăn uống hồi một phần |
| Trồng trọt | Cuốc đất, gieo hạt, tưới, thu hoạch. Mỗi mùa có cây riêng; hết mùa thì cây héo; trời mưa tự tưới |
| Nhà | Giường (ngủ, lưu), rương đồ, bếp; nâng cấp nhà mở thêm phòng |
| Dân làng | Mỗi người có lịch sinh hoạt, đồ thích/ghét, sinh nhật. Thân thiết tăng khi nói chuyện mỗi ngày và tặng quà, mở ra sự kiện riêng |
| Trao đổi | Cửa hàng mua/bán bằng tiền; bảng đổi đồ ở chợ (dân làng cần món A, đổi món B) |
| Bốn mùa | Xuân, hạ, thu, đông: đổi bản đồ, cây trồng, cá, thời tiết; mỗi mùa có một lễ hội |
| Thời tiết | Nắng, mưa, gió mùa (hạ có bão: ở nhà, sửa vườn sau bão) |

## Bản sắc riêng
- Làng chài: thúng chai, ruộng muối, phơi cá, chợ phiên sáng sớm.
- Lễ hội: Xuân - Tết; Hạ - đua thuyền; Thu - Trung thu rước đèn; Đông - cầu ngư.
- Hải đăng là trung tâm đảo; sửa lại nó là mục tiêu dài hạn.

## Bản chơi đầu tiên (MVP)
- Bản đồ: vườn + nhà (có nội thất) + quảng trường làng.
- 3 loại cây mỗi mùa (12 loại), 4 dân làng, 1 cửa hàng, 1 bảng đổi đồ.
- Ngủ/lưu, thể lực, đủ vòng 4 mùa (có thể rút ngắn ngày để thử).

## Art cần cho MVP
- Nhân vật chính: đi 4 hướng, cuốc, tưới, gieo, thu hoạch, bê đồ, ngủ.
- 4 dân làng: đứng, đi 4 hướng, chân dung hội thoại.
- Tile 32px cho 4 mùa: cỏ, đất, đất đã cuốc, đất ướt, đường, nước, cát; nhà, hàng rào, cây.
- Cây trồng: 4-5 giai đoạn lớn × 12 loại; icon vật phẩm; UI (đồng hồ, thanh thể lực, túi đồ, hội thoại).

Pipeline: OpenRouter tạo ảnh trên nền magenta, sprite-gen tách nền và ép lưới pixel
(`fit.pixel_unfake`), ghép atlas kèm `manifest.json` để Unity đọc.

## Sinh vật đồng hành (linh thú)
Linh thú sống hoang trên đảo. Cách đưa về nhà (đã có trong `Prototype/web-gba/`):
1. Đứng sát linh thú, cho ăn **bánh cá**, mỗi ngày một lần: tin tưởng +1 (tối đa 3).
2. Đủ 3 tin tưởng thì dùng **dây buộc** ngay bên cạnh: minigame bấm đúng nhịp, 3 lần đúng là
   nó theo về; hụt 3 lần thì nó giật mình chạy và mất 1 tin tưởng.
3. **Huýt sáo** (Q) để gọi linh thú chạy từ ngoài vào đi theo; huýt lần nữa để đổi con hoặc cho nó chạy về.

Cố ý tránh các cơ chế trong bằng sáng chế Nintendo kiện Palworld: không ném vật để bắt, không
hiện tỉ lệ bắt thành công, không thả sinh vật bằng vật ném, không cưỡi hay bay. Đây là nhận
định chung, không phải tư vấn pháp lý; nên hỏi luật sư sở hữu trí tuệ trước khi phát hành, nhất là ở Nhật.

## Dân làng và trao đổi (đã có trong bản thử)
- **Ông Tư** (sạp hạt giống): trò chuyện, nhận quà; bán 5 hạt / 25 xu; đổi 2 củ cải lấy 4 hạt.
- **Cô Lan** (sạp cá): mua củ cải 12 xu; đổi 2 củ cải lấy 3 bánh cá; bán bánh cá 10 xu.
- Mỗi ngày nói chuyện +1 tim, tặng quà +2 tim (tối đa 5). Lời thoại đổi theo số tim.
