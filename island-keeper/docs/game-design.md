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
Thể loại sưu tầm sinh vật, nhưng theo cách riêng của game này: không ném bóng để bắt.
Linh thú sống hoang trên đảo; bạn làm quen bằng cách trò chuyện và cho ăn nông sản
mỗi ngày (thanh tim). Đủ thân thì chúng về nông trại ở và đi theo bạn.
Mỗi con có một việc giúp nông trại: Mạ tưới cây, Muối tìm đồ ở bãi biển, Đóm soi sáng
ban đêm và dụ côn trùng, Dừa xới đất. Có thể thêm hội thi linh thú ở lễ hội thay cho đánh nhau.

Lưu ý pháp lý (không phải tư vấn luật): tránh tên, hình và giao diện của Pokémon. Nintendo
từng kiện vụ Palworld dựa trên bằng sáng chế cơ chế bắt sinh vật bằng vật thể ném, nên
cơ chế làm quen ở đây cố ý khác hẳn.

Đã có: `ArtSource/creatures/` (Mạ, Muối, Đóm, Dừa), bản chơi thử `Prototype/web-farm/`.
