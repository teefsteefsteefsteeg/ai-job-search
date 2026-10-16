# Sow & Stack (tên tạm) - thiết kế

> Tên tạm. Phải tra Steam và nhãn hiệu trước khi dùng chính thức.

## Một câu
Game giải đố thư giãn: mỗi ngày bạn xếp các mảnh ruộng hình khối lên một mảnh đất nhỏ để
đạt sản lượng, rồi dùng nông sản xây căn nhà mơ ước bằng cách ghép từng phòng.

## Vì sao bán được trên Steam
- Dòng giải đố và xây dựng thư giãn có nhiều game thành công: Dorfromantik, Islanders,
  Townscaper, Tiny Glade, Unpacking. Người chơi dòng này thích ván ngắn, không áp lực,
  ảnh chụp màn hình đẹp.
- Trộn hai thứ người chơi dễ hiểu ngay (nông trại và xây nhà) với một cơ chế giải đố rõ
  ràng (xếp khối), nên trang Steam và trailer 30 giây nói được hết.
- Phạm vi hợp nhóm nhỏ: một màn chơi là một bàn cờ, không cần thế giới mở, không cần online.

## Vòng chơi
1. **Ngày mới:** bàn ruộng 6x6 đến 9x9 ô, có đá, nước, bóng râm tuỳ màn.
2. **Xếp ruộng (giải đố chính):** mỗi loại cây là một mảnh hình khối (cà rốt hình L, ngô
   thẳng 1x4, bí 2x2...). Đặt cạnh nhau sẽ cộng điểm theo quy tắc:
   - Đậu đặt cạnh cây khác: +điểm cho cây đó (cố định đạm).
   - Hướng dương cao che nắng: cây ưa bóng phía sau +điểm, cây ưa nắng -điểm.
   - Bù nhìn bảo vệ bán kính 1 ô khỏi chim.
   - Ô cạnh nước tự tưới.
3. **Thu hoạch:** đạt mục tiêu điểm thì qua ngày; dư điểm thành vật liệu (gỗ, gạch, kính).
4. **Xây nhà (giải đố thứ hai):** mỗi phòng là một khối hình trên nền đất nhà. Phòng đặt
   đúng vị trí có thưởng (bếp cạnh vườn, phòng ngủ hướng đông đón nắng). Mỗi phòng mới mở
   khoá thứ mới cho ruộng: bếp mở cây gia vị, kho mở thêm ô trong khay, nhà kính mở mùa đông.
5. **Bốn mùa:** mỗi mùa đổi luật bàn cờ. Xuân mưa làm ngập ô trũng, hạ hạn hán, thu có gió
   thổi lệch mảnh, đông có ô đóng băng.
6. **Khách ghé thăm:** mỗi chương có một vị khách đặt yêu cầu ("một căn phòng có cửa sổ
   nhìn ra vườn hoa"), hoàn thành thì mở chương tiếp.

## Chế độ
- Cốt truyện: 4 mùa x 10 màn thiết kế tay, có màn hướng dẫn.
- Thư giãn: bàn cờ ngẫu nhiên, không mục tiêu điểm.
- Thử thách hằng ngày: cùng một hạt giống ngẫu nhiên cho mọi người, có bảng xếp hạng Steam.
- Chế độ xem nhà: đi dạo, chụp ảnh căn nhà đã xây (dễ lan truyền trên mạng).

## Phong cách hình ảnh (chọn một)
- **A - Diorama vẽ tay:** cảm giác mô hình 3D nhỏ, ánh chiều ấm, nhìn cao cấp. Hợp
  Steam nhất nhưng tốn công hơn: nên làm 3D low-poly trong Unity, hoặc 2D isometric vẽ sẵn.
- **B - Pixel isometric:** rẻ và nhanh hơn, tận dụng được pipeline OpenRouter + sprite-gen.
  Pixel isometric phổ biến nên khó nổi bật hơn A.

## Bản thử đầu tiên (2-3 tuần)
- 1 bàn 7x7, 6 loại cây với 4 quy tắc kề nhau, khay 3 mảnh, xoay mảnh, hoàn tác.
- Nhà: 5 loại phòng, đặt trên nền 4x4.
- 1 mùa, 8 màn. Mục tiêu: kiểm tra phần xếp ruộng có vui không trước khi đầu tư art.

## Steam
- Trang Steam và demo sớm để gom wishlist. Tham gia Steam Next Fest khi có demo.
- Thẻ: Cozy, Puzzle, Farming Sim, City Builder, Relaxing, Casual.
